import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/article.dart';
import '../services/database_service.dart';
import '../services/extractor_service.dart';
import '../services/llm_service.dart';
import 'article_provider.dart';

/// 采集任务日志结构
class LogEntry {
  final String timestamp;
  final String type; // 'INFO', 'SUCCESS', 'WARNING', 'ERROR'
  final String message;

  LogEntry({required this.timestamp, required this.type, required this.message});

  @override
  String toString() => '[$timestamp] [$type] $message';
}

/// 网页文章自动采集与批量解析流程控制器 Provider
/// 
/// 支持单篇采集、列表采集（包括分页深度配置），利用 LlmService 与 ExtractorService 完成网页的智能抓取、大模型解析并写入数据库，同时提供任务进度和控制日志输出。
class CollectorProvider with ChangeNotifier {
  final _db = DatabaseService.instance;
  final _extractor = ExtractorService();
  final _llmService = LlmService();

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
  Future<bool> collectSingleArticle(String url, ArticleProvider articleProvider) async {
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
      final success = await _processSingleArticleUrl(url, useRandomDelay: false);
      if (success) {
        _completedTaskCount = 1;
        _addLog('SUCCESS', '单篇采集完成并已存入数据库！');
        await articleProvider.loadArticles();
        return true;
      }
      return false;
    } catch (e) {
      _addLog('ERROR', '采集失败: $e');
      return false;
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
    _addLog('INFO', '配置项：自动翻页 = $autoPage, 最大翻页数 = $maxPages');

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
            await _processSingleArticleUrl(currentUrl, useRandomDelay: false);
            await articleProvider.loadArticles();
            _isCollecting = false;
            _currentProcessingUrl = '';
            notifyListeners();
            return;
          }

          final cleanedHtml = _extractor.cleanHtmlForList(html);
          
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
      _addLog('INFO', '总计提取出有效文章链接 $_totalTaskCount 个，开始逐篇进行抓取解析...');

      // 逐篇抓取解析循环
      for (var i = 0; i < allArticleUrls.length; i++) {
        if (_cancelRequested) {
          _addLog('WARNING', '采集已由用户中止！已完成: $_completedTaskCount / $_totalTaskCount');
          break;
        }

        final targetUrl = allArticleUrls[i];
        _currentProcessingUrl = targetUrl;
        _addLog('INFO', '正在采集第 (${i + 1}/$_totalTaskCount) 篇: $targetUrl');

        try {
          final success = await _processSingleArticleUrl(targetUrl, useRandomDelay: true);
          if (success) {
            _completedTaskCount++;
            _addLog('SUCCESS', '采集成功: 第 (${i + 1}/$_totalTaskCount) 篇');
          } else {
            _addLog('WARNING', '采集跳过或失败: 第 (${i + 1}/$_totalTaskCount) 篇');
          }
        } catch (e) {
          _addLog('ERROR', '采集第 (${i + 1}/$_totalTaskCount) 篇出错: $e');
        }
        
        // 采集完一篇后立即刷新内容库，给用户及时的状态回馈
        await articleProvider.loadArticles();
      }

      _addLog('SUCCESS', '批量采集任务结束！成功采集并入库 $_completedTaskCount / $_totalTaskCount 篇文章');
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
  }) async {
    _isCollecting = true;

    // 动态加载并应用网络代理设置
    final proxyUrl = await _db.getSetting('network_proxy_url');
    _extractor.setProxy(proxyUrl);

    _cancelRequested = false;
    _totalTaskCount = urls.length;
    _completedTaskCount = 0;
    notifyListeners();

    _addLog('INFO', '开始执行分组网址批量采集，共计 ${urls.length} 个目标');

    try {
      for (var i = 0; i < urls.length; i++) {
        if (_cancelRequested) {
          _addLog('WARNING', '分组采集任务已被用户中止！已完成: $_completedTaskCount / $_totalTaskCount');
          break;
        }

        final targetUrl = urls[i].trim();
        if (targetUrl.isEmpty) continue;
        
        _currentProcessingUrl = targetUrl;
        _addLog('INFO', '正在处理第 (${i + 1}/${urls.length}): $targetUrl');

        try {
          final success = await _processSingleArticleUrl(targetUrl, useRandomDelay: true);
          if (success) {
            _completedTaskCount++;
            _addLog('SUCCESS', '处理完毕: 第 (${i + 1}/${urls.length}) 篇');
          } else {
            _addLog('WARNING', '处理失败: 第 (${i + 1}/${urls.length}) 篇');
          }
        } catch (e) {
          _addLog('ERROR', '采集链接 $targetUrl 出错: $e');
        }

        // 每次采集完毕刷新 UI 列表
        await articleProvider.loadArticles();
      }
      
      _addLog('SUCCESS', '分组批量采集任务结束！成功处理并入库 $_completedTaskCount / $_totalTaskCount 篇文章');
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
  Future<bool> _processSingleArticleUrl(String url, {bool useRandomDelay = false}) async {
    // 智能去重拦截逻辑：若库中已存在相同 sourceUrl，则直接跳过
    final isCollected = await _db.isUrlCollected(url);
    if (isCollected) {
      _addLog('INFO', '该网址已在内容库中存在，跳过采集: $url');
      return true; // 返回 true 表示处理完成
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
          continue;
        }

        _addLog('INFO', '开始处理订阅项: $title');

        // 如果正文丰富（全文本 Feed），直接进行本地 Markdown 转化并入库，100% 节省 LLM Token！
        if (rssContent.length > 500) {
          final markdownContent = _extractor.htmlToMarkdown(rssContent);
          final newArticle = Article(
            title: title,
            content: markdownContent,
            coverUrl: coverUrl,
            sourceUrl: itemUrl,
            createdAt: DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
          );
          await _db.insertArticle(newArticle);
          _addLog('SUCCESS', '内容充足！已直接解析 HTML 为 Markdown 存入内容库 (零 Token 消耗)');
          newImportedCount++;
        } else {
          // 如果 RSS 只有摘要没有完整正文，则对该具体详情页 URL 发起二次详情采集
          _addLog('INFO', 'RSS 正文不完整，自动发起网页详情提取...');
          try {
            final subSuccess = await _processSingleArticleUrl(itemUrl, useRandomDelay: true);
            if (subSuccess) {
              newImportedCount++;
            }
          } catch (e) {
            _addLog('ERROR', '处理订阅子项 $itemUrl 出错: $e');
          }
        }
      }

      _addLog('SUCCESS', '订阅源 $url 处理完毕！共新增入库 $newImportedCount 篇文章');
      return true;
    }

    // 2. 清洗 HTML，只保留必要的内容结构
    final cleanedHtml = _extractor.cleanHtmlForSingleArticle(html);

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
      return false;
    }

    // 4. 存入本地数据库
    final newArticle = Article(
      title: title,
      content: content,
      coverUrl: coverUrl,
      sourceUrl: url,
      createdAt: DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
    );

    await _db.insertArticle(newArticle);
    return true;
  }
}
