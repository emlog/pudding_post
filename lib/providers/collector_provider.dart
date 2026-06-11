import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/article.dart';
import '../services/database_service.dart';
import '../services/extractor_service.dart';
import '../services/llm_service.dart';
import 'article_provider.dart';
import '../services/translation_service.dart';

/// 采集任务日志结构
class LogEntry {
  final String timestamp;
  final String type; // 'INFO', 'SUCCESS', 'WARNING', 'ERROR'
  final String message;

  LogEntry({required this.timestamp, required this.type, required this.message});

  @override
  String toString() => '[$timestamp] [$type] $message';
}

/// 采集处理结果计数
/// 
/// 记录每次采集任务中成功入库、跳过和失败的文章数量，并支持通过加法运算符进行累加。
class CollectResult {
  final int successCount;
  final int skippedCount;
  final int failedCount;

  CollectResult({
    this.successCount = 0,
    this.skippedCount = 0,
    this.failedCount = 0,
  });

  CollectResult operator +(CollectResult other) {
    return CollectResult(
      successCount: successCount + other.successCount,
      skippedCount: skippedCount + other.skippedCount,
      failedCount: failedCount + other.failedCount,
    );
  }
}

/// 网页文章自动采集与批量解析流程控制器 Provider
/// 
/// 支持单篇采集、列表采集（包括分页深度配置），利用 LlmService 与 ExtractorService 完成网页的智能抓取、大模型解析并写入数据库，同时提供任务进度和控制日志输出。
class CollectorProvider with ChangeNotifier {
  final _db = DatabaseService.instance;
  final _extractor = ExtractorService();
  final _llmService = LlmService();
  final _translationService = TranslationService();

  bool _isCollecting = false;
  List<LogEntry> _logs = [];
  int _totalTaskCount = 0;
  int _completedTaskCount = 0;
  String _currentProcessingUrl = '';
  bool _cancelRequested = false;

  // Getter 字段定义
  bool get isCollecting => _isCollecting;
  List<LogEntry> get logs => _logs;
  int get totalTaskCount => _totalTaskCount;
  int get completedTaskCount => _completedTaskCount;
  String get currentProcessingUrl => _currentProcessingUrl;
  bool get cancelRequested => _cancelRequested;
  double get progress => _totalTaskCount == 0 ? 0.0 : _completedTaskCount / _totalTaskCount;

  /// 添加一条带时间戳和类型的采集日志
  /// 
  /// 在采集任务的各个步骤中记录进度，并触发界面监听器刷新。
  void _addLog(String type, String message) {
    final timeStr = DateFormat('HH:mm:ss').format(DateTime.now());
    _logs.add(LogEntry(timestamp: timeStr, type: type, message: message));
    notifyListeners();
  }

  /// 清空当前日志列表
  /// 
  /// 在启动新一轮采集任务时执行重置。
  void clearLogs() {
    _logs.clear();
    notifyListeners();
  }

  /// 请求中止当前正在执行的批量采集任务
  /// 
  /// 当用户在界面上点击“停止采集”时，将该状态标志置为 true，以中止循环。
  void requestCancel() {
    if (_isCollecting) {
      _cancelRequested = true;
      _addLog('WARNING', '正在请求停止采集任务，请稍候...');
    }
  }

  /// 执行单篇网页文章采集任务
  /// 
  /// 抓取单个 URL 页面 HTML，调用大模型分析并写入本地数据库，最后刷新内容库列表。
  /// 返回 CollectResult 结果以便 UI 进行精准的消息提示。
  Future<CollectResult> collectSingleArticle(String url, ArticleProvider articleProvider, {bool deepCollect = false}) async {
    _isCollecting = true;
    
    // 动态加载并应用网络代理设置，增强抓取兼容性
    final proxyUrl = await _db.getSetting('network_proxy_url');
    _extractor.setProxy(proxyUrl);

    _cancelRequested = false;
    _totalTaskCount = 1;
    _completedTaskCount = 0;
    _currentProcessingUrl = url;
    notifyListeners();

    _addLog('INFO', '开始单篇采集任务，目标 URL: $url');
    
    try {
      final result = await _processSingleArticleUrl(url, useRandomDelay: false, deepCollect: deepCollect);
      if (result.successCount > 0) {
        _completedTaskCount = result.successCount;
        _addLog('SUCCESS', '单篇采集完成并已存入数据库！');
        await articleProvider.loadArticles();
        return result;
      } else if (result.skippedCount > 0) {
        _completedTaskCount = 0;
        _addLog('WARNING', '该网址已在内容库中存在，跳过采集');
        return result;
      } else {
        _addLog('WARNING', '单篇采集未能成功解析出正文内容');
        return result;
      }
    } catch (e) {
      _addLog('ERROR', '采集失败: $e');
      return CollectResult(failedCount: 1);
    } finally {
      _isCollecting = false;
      _currentProcessingUrl = '';
      notifyListeners();
    }
  }

  /// 批量采集列表页及其深度分页下的文章
  /// 
  /// 1. 抓取列表页 HTML 并让大模型解析出文章 URL 集合与下一页 URL。
  /// 2. 依次单篇抓取解析队列中的文章。
  /// 3. 若配置了自动翻页且未到达最大翻页数，将继续请求下一页。
  Future<void> collectListArticles({
    required String listUrl,
    required ArticleProvider articleProvider,
    required bool autoPage,
    required int maxPages,
    bool deepCollect = false,
  }) async {
    _isCollecting = true;

    // 动态加载并应用网络代理设置，增强抓取兼容性
    final proxyUrl = await _db.getSetting('network_proxy_url');
    _extractor.setProxy(proxyUrl);

    _cancelRequested = false;
    _totalTaskCount = 0;
    _completedTaskCount = 0;
    _currentProcessingUrl = listUrl;
    notifyListeners();

    _addLog('INFO', '开始列表批量采集任务，列表 URL: $listUrl');
    _addLog('INFO', '配置项：自动翻页 = $autoPage, 最大翻页数 = $maxPages, 深入采集 = $deepCollect');

    try {
      final promptList = await _db.getSetting('prompt_list');
      var currentUrl = listUrl;
      var currentPage = 1;
      final List<String> allArticleUrls = [];

      // 翻页提取链接循环
      while (currentUrl.isNotEmpty && currentPage <= maxPages) {
        if (_cancelRequested) break;
        
        _addLog('INFO', '正在解析列表页 (第 $currentPage 页): $currentUrl');
        
        try {
          final html = await _extractor.fetchHtml(currentUrl, useRandomDelay: true);
          
          // 自动判定并流转 RSS/Atom 订阅源列表解析
          if (_extractor.isRssContent(html)) {
            _addLog('INFO', '检测到列表 URL 为 RSS/Atom 订阅源，自动跳转至结构化解析分支...');
            await _processSingleArticleUrl(currentUrl, useRandomDelay: false, deepCollect: deepCollect);
            await articleProvider.loadArticles();
            _isCollecting = false;
            _currentProcessingUrl = '';
            notifyListeners();
            return;
          }

          final cleanedHtml = await _extractor.cleanHtmlForList(html);
          
          final result = await _llmService.extractList(cleanedHtml, promptList);
          final List<dynamic> urls = result['article_urls'] ?? [];
          final String nextPage = result['next_page_url']?.toString() ?? '';

          _addLog('INFO', '第 $currentPage 页解析完毕，发现 ${urls.length} 篇文章链接');

          for (var u in urls) {
            final absoluteUrl = _extractor.resolveUrl(currentUrl, u.toString());
            if (!allArticleUrls.contains(absoluteUrl)) {
              allArticleUrls.add(absoluteUrl);
            }
          }

          if (autoPage && nextPage.isNotEmpty) {
            currentUrl = _extractor.resolveUrl(currentUrl, nextPage);
            currentPage++;
          } else {
            break;
          }
        } catch (e) {
          _addLog('ERROR', '解析第 $currentPage 网页列表出错: $e');
          break;
        }
      }

      if (_cancelRequested) {
        _addLog('WARNING', '采集已由用户中止！提取到 ${allArticleUrls.length} 条待采链接，尚未开始采集正文');
        _isCollecting = false;
        notifyListeners();
        return;
      }

      _totalTaskCount = allArticleUrls.length;
      _addLog('INFO', '总计提取出有效文章链接 $_totalTaskCount 个，开始并发进行抓取解析...');

      final concurrencyStr = await _db.getSetting('max_concurrency', defaultValue: '3');
      final maxConcurrency = int.tryParse(concurrencyStr) ?? 3;
      _addLog('INFO', '并发线程配置：最大并发 = $maxConcurrency');

      var successCount = 0;
      var skippedCount = 0;
      var failedCount = 0;

      // 并发抓取解析队列
      await _runConcurrentTasks<String>(
        inputs: allArticleUrls,
        maxConcurrency: maxConcurrency,
        task: (targetUrl, index) async {
          _currentProcessingUrl = targetUrl;
          _addLog('INFO', '[任务 #${index + 1}] 正在采集: $targetUrl');

          try {
            final result = await _processSingleArticleUrl(targetUrl, useRandomDelay: true, deepCollect: deepCollect);
            _completedTaskCount++;
            if (result.successCount > 0) {
              successCount += result.successCount;
              _addLog('SUCCESS', '[任务 #${index + 1}] 采集成功并入库');
            } else if (result.skippedCount > 0) {
              skippedCount += result.skippedCount;
              _addLog('WARNING', '[任务 #${index + 1}] 采集跳过（已存在）');
            } else {
              failedCount += result.failedCount;
              _addLog('WARNING', '[任务 #${index + 1}] 采集失败（无有效正文）');
            }
          } catch (e) {
            _completedTaskCount++;
            failedCount++;
            _addLog('ERROR', '[任务 #${index + 1}] 采集出错: $e');
          }
          
          // 并发回刷 UI，通知进度
          await articleProvider.loadArticles();
        },
      );

      _addLog('SUCCESS', '批量采集任务结束！共处理 ${successCount + skippedCount + failedCount} 篇文章，成功入库 $successCount 篇，跳过（已存在）$skippedCount 篇，失败 $failedCount 篇');
    } catch (e) {
      _addLog('ERROR', '列表批量任务发生严重异常: $e');
    } finally {
      _isCollecting = false;
      _currentProcessingUrl = '';
      notifyListeners();
    }
  }

  /// 批量采集选定网址分组中的所有内容
  /// 
  /// 依次处理分组中的各个 URL 链接，若网址已被采集过则自动跳过。
  Future<void> collectGroupUrls({
    required List<String> urls,
    required ArticleProvider articleProvider,
    bool deepCollect = false,
  }) async {
    _isCollecting = true;

    // 动态加载并应用网络代理设置
    final proxyUrl = await _db.getSetting('network_proxy_url');
    _extractor.setProxy(proxyUrl);

    _cancelRequested = false;
    _totalTaskCount = urls.length;
    _completedTaskCount = 0;
    notifyListeners();

    final concurrencyStr = await _db.getSetting('max_concurrency', defaultValue: '3');
    final maxConcurrency = int.tryParse(concurrencyStr) ?? 3;
    _addLog('INFO', '开始执行分组网址并发采集，共计 ${urls.length} 个目标，最大并发 = $maxConcurrency');

    try {
      var successCount = 0;
      var skippedCount = 0;
      var failedCount = 0;

      await _runConcurrentTasks<String>(
        inputs: urls,
        maxConcurrency: maxConcurrency,
        task: (rawUrl, index) async {
          final targetUrl = rawUrl.trim();
          if (targetUrl.isEmpty) {
            _completedTaskCount++;
            return;
          }
          
          _currentProcessingUrl = targetUrl;
          _addLog('INFO', '[任务 #${index + 1}] 正在处理: $targetUrl');

          try {
            final result = await _processSingleArticleUrl(targetUrl, useRandomDelay: true, deepCollect: deepCollect);
            _completedTaskCount++;
            if (result.successCount > 0) {
              successCount += result.successCount;
              _addLog('SUCCESS', '[任务 #${index + 1}] 处理完毕，成功入库');
            } else if (result.skippedCount > 0) {
              skippedCount += result.skippedCount;
              _addLog('WARNING', '[任务 #${index + 1}] 因已存在跳过');
            } else {
              failedCount += result.failedCount;
              _addLog('WARNING', '[任务 #${index + 1}] 采集提取失败');
            }
          } catch (e) {
            _completedTaskCount++;
            failedCount++;
            _addLog('ERROR', '[任务 #${index + 1}] 采集出错: $e');
          }

          // 每次采集完毕刷新 UI 列表
          await articleProvider.loadArticles();
        },
      );
      
      _addLog('SUCCESS', '分组批量采集任务结束！共处理 ${successCount + skippedCount + failedCount} 篇文章，成功入库 $successCount 篇，跳过（已存在）$skippedCount 篇，失败 $failedCount 篇');
    } catch (e) {
      _addLog('ERROR', '分组批量任务发生严重异常: $e');
    } finally {
      _isCollecting = false;
      _currentProcessingUrl = '';
      notifyListeners();
    }
  }

  /// 封装单篇 URL 的核心处理逻辑（网页抓取 -> 清洗 -> 大模型提取 -> 存入数据库）
  /// 
  /// 供单篇和批量采集方法共同调用。
  Future<CollectResult> _processSingleArticleUrl(String url, {bool useRandomDelay = false, bool deepCollect = false}) async {
    // 智能去重拦截逻辑：若库中已存在相同 sourceUrl，则直接跳过
    final isCollected = await _db.isUrlCollected(url);
    if (isCollected) {
      _addLog('INFO', '该网址已在内容库中存在，跳过采集: $url');
      return CollectResult(skippedCount: 1);
    }

    final promptSingle = await _db.getSetting('prompt_single');

    // 1. 抓取 HTML 源码
    final html = await _extractor.fetchHtml(url, useRandomDelay: useRandomDelay);

    // 1.5 智能探测 RSS / Atom 结构化订阅源并处理
    if (_extractor.isRssContent(html)) {
      _addLog('INFO', '探测到目标网址为 RSS/Atom 结构化订阅源，开启高效提取流...');
      final items = _extractor.parseRss(html, url);
      _addLog('INFO', '成功从订阅源解析出 ${items.length} 篇文章');

      var newImportedCount = 0;
      var skippedCount = 0;
      var failedCount = 0;
      for (var item in items) {
        if (_cancelRequested) {
          _addLog('WARNING', '采集流程已被用户中止！');
          break;
        }

        final itemUrl = item['link'] ?? '';
        final title = item['title'] ?? '未命名文章';
        final rssContent = item['content'] ?? '';
        final coverUrl = item['cover_url'] ?? '';

        if (itemUrl.isEmpty) continue;

        // 检查子项是否已采集
        final subCollected = await _db.isUrlCollected(itemUrl);
        if (subCollected) {
          skippedCount++;
          continue;
        }

        _addLog('INFO', '开始处理订阅项: $title');

        if (deepCollect) {
          _addLog('INFO', '开启深入详情采集，正在获取 $title 的网页原文...');
          try {
            final subResult = await _processSingleArticleUrl(itemUrl, useRandomDelay: true, deepCollect: true);
            newImportedCount += subResult.successCount;
            skippedCount += subResult.skippedCount;
            failedCount += subResult.failedCount;
          } catch (e) {
            _addLog('ERROR', '处理订阅子项 $itemUrl 出错: $e');
            failedCount++;
          }
        } else {
          // 只采集标题和 RSS 提供的内容（直接解析 HTML 为 Markdown 存入，零大模型 Token 消耗）
          final markdownContent = rssContent.isNotEmpty
              ? await _extractor.htmlToMarkdown(rssContent)
              : '';
          final translated = await _translateArticleIfNeeded(title, markdownContent);
          final newArticle = Article(
            title: translated['title']!,
            content: translated['content']!,
            coverUrl: coverUrl,
            sourceUrl: itemUrl,
            createdAt: DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
          );
          await _db.insertArticle(newArticle);
          _addLog('SUCCESS', '解析完毕！已将标题和 RSS 订阅内容存入内容库 (零大模型 Token 消耗)');
          newImportedCount++;
        }
      }

      _addLog('SUCCESS', '订阅源 $url 处理完毕！共新增入库 $newImportedCount 篇文章，跳过 $skippedCount 篇，失败 $failedCount 篇');
      return CollectResult(
        successCount: newImportedCount,
        skippedCount: skippedCount,
        failedCount: failedCount,
      );
    }

    // 1.6 智能探测普通 HTML 文章列表页并依次采集
    if (_extractor.isListContent(html)) {
      _addLog('INFO', '探测到目标网址为普通 HTML 文章列表页，开启智能列表提取流...');
      
      final promptList = await _db.getSetting('prompt_list');
      final cleanedListHtml = await _extractor.cleanHtmlForList(html);
      
      try {
        final extractResult = await _llmService.extractList(cleanedListHtml, promptList);
        final List<dynamic> urls = extractResult['article_urls'] ?? [];
        _addLog('INFO', '成功从列表页中提取出 ${urls.length} 篇文章链接');

        var newImportedCount = 0;
        var skippedCount = 0;
        var failedCount = 0;

        for (var itemRawUrl in urls) {
          if (_cancelRequested) {
            _addLog('WARNING', '采集流程已被用户中止！');
            break;
          }

          final itemUrl = _extractor.resolveUrl(url, itemRawUrl.toString());
          if (itemUrl.isEmpty) continue;

          // 检查子项是否已采集，实现主要不要重复入库
          final subCollected = await _db.isUrlCollected(itemUrl);
          if (subCollected) {
            skippedCount++;
            continue;
          }

          _addLog('INFO', '开始处理列表子项网址: $itemUrl');
          try {
            final subResult = await _processSingleArticleUrl(itemUrl, useRandomDelay: true);
            newImportedCount += subResult.successCount;
            skippedCount += subResult.skippedCount;
            failedCount += subResult.failedCount;
          } catch (e) {
            _addLog('ERROR', '处理列表子项 $itemUrl 出错: $e');
            failedCount++;
          }
        }

        _addLog('SUCCESS', '列表页 $url 处理完毕！共新增入库 $newImportedCount 篇文章，跳过 $skippedCount 篇，失败 $failedCount 篇');
        return CollectResult(
          successCount: newImportedCount,
          skippedCount: skippedCount,
          failedCount: failedCount,
        );
      } catch (e) {
        _addLog('ERROR', '大模型解析列表项失败: $e');
        return CollectResult(failedCount: 1);
      }
    }

    if (_cancelRequested) {
      _addLog('WARNING', '采集流程已被用户中止，跳过大模型提取。');
      return CollectResult();
    }

    // 2. 清洗 HTML，只保留必要的内容结构
    final cleanedHtml = await _extractor.cleanHtmlForSingleArticle(html);

    // 3. 调用 LLM 提炼 JSON
    final result = await _llmService.extractArticle(cleanedHtml, promptSingle);

    final title = result['title']?.toString() ?? '未命名文章';
    final content = result['content']?.toString() ?? '';
    var coverUrl = result['cover_url']?.toString() ?? '';

    if (coverUrl.isNotEmpty) {
      coverUrl = _extractor.resolveUrl(url, coverUrl);
    }

    if (content.trim().isEmpty) {
      _addLog('WARNING', '大模型未提取出有效正文内容，放弃入库：$url');
      return CollectResult(failedCount: 1);
    }

    final translated = await _translateArticleIfNeeded(title, content);

    // 4. 存入本地数据库
    final newArticle = Article(
      title: translated['title']!,
      content: translated['content']!,
      coverUrl: coverUrl,
      sourceUrl: url,
      createdAt: DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
    );

    await _db.insertArticle(newArticle);
    return CollectResult(successCount: 1);
  }

  /// 如果内容为英文，自动调用 Google 免费翻译接口将其翻译为简体中文
  Future<Map<String, String>> _translateArticleIfNeeded(String title, String content) async {
    if (_translationService.isEnglish(content)) {
      _addLog('INFO', '检测到网页内容为英文，正在调用 Google 免费翻译接口将其翻译为简体中文...');
      try {
        final translatedTitle = await _translationService.translateToChinese(title);
        final translatedContent = await _translationService.translateToChinese(content);
        _addLog('SUCCESS', '英文内容成功翻译为简体中文并已入库。');
        return {
          'title': translatedTitle,
          'content': translatedContent,
        };
      } catch (e) {
        _addLog('ERROR', '自动翻译失败: $e，保留英文原文入库');
      }
    }
    return {
      'title': title,
      'content': content,
    };
  }

  /// 并发执行任务的辅助方法，限制最大并发数
  /// 
  /// 利用事件竞争队列模型，动态消化任务列表，防卡顿与连接池阻塞。
  Future<void> _runConcurrentTasks<I>({
    required List<I> inputs,
    required int maxConcurrency,
    required Future<void> Function(I input, int index) task,
  }) async {
    var nextIndex = 0;

    Future<void> worker() async {
      while (true) {
        int currentIndex;
        if (nextIndex >= inputs.length || _cancelRequested) {
          return;
        }
        currentIndex = nextIndex;
        nextIndex++;

        final input = inputs[currentIndex];
        try {
          await task(input, currentIndex);
        } catch (_) {
          // 容错捕获单个异常，保证并发池中其他 Worker 正常流转
        }
      }
    }

    final List<Future<void>> workers = [];
    final actualConcurrency = maxConcurrency.clamp(1, inputs.length);
    for (var i = 0; i < actualConcurrency; i++) {
      workers.add(worker());
    }

    await Future.wait(workers);
  }
}
