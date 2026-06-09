import 'dart:io';
import 'dart:isolate';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart';

/// 网页内容抓取与 HTML 结构精简服务类
/// 
/// 负责对目标 URL 发起网络请求获取网页源代码，并使用 html 库对 DOM 树进行精简和标签清洗，以减少发送给大模型的 Token 数量。
class ExtractorService {
  // 预置的常见真实浏览器 User-Agent 及对应的 Client Hints 头，用于规避反爬检测
  static final List<Map<String, dynamic>> _uaTemplates = [
    {
      'ua': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
      'hints': {
        'sec-ch-ua': '"Chromium";v="122", "Not(A:Brand";v="24", "Google Chrome";v="122"',
        'sec-ch-ua-mobile': '?0',
        'sec-ch-ua-platform': '"Windows"',
      }
    },
    {
      'ua': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
      'hints': {
        'sec-ch-ua': '"Chromium";v="122", "Not(A:Brand";v="24", "Google Chrome";v="122"',
        'sec-ch-ua-mobile': '?0',
        'sec-ch-ua-platform': '"macOS"',
      }
    },
    {
      'ua': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Edge/122.0.0.0',
      'hints': {
        'sec-ch-ua': '"Chromium";v="122", "Microsoft Edge";v="122", "Not(A:Brand";v="24"',
        'sec-ch-ua-mobile': '?0',
        'sec-ch-ua-platform': '"Windows"',
      }
    },
    {
      'ua': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.3 Safari/605.1.15',
      'hints': <String, String>{}
    },
    {
      'ua': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:123.0) Gecko/20100101 Firefox/123.0',
      'hints': <String, String>{}
    }
  ];

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  ));

  /// 根据提供的 URL 抓取网页 HTML 源代码
  /// 
  /// 使用 Dio 发起 HTTP GET 请求，获取网页源码并返回字符串。如果出错则抛出异常。
  /// 支持随机生成拟真 Headers 规避封禁，并支持随机退避延时。
  Future<String> fetchHtml(String url, {bool useRandomDelay = false}) async {
    if (useRandomDelay) {
      // 随机延迟 1 到 3 秒，模拟真人阅读延时，防频率封锁
      final delayMs = 1000 + (DateTime.now().millisecondsSinceEpoch % 2000);
      await Future.delayed(Duration(milliseconds: delayMs));
    }
    try {
      // 动态生成符合该 URL 域名的随机 UA 及 Client Hints Headers，伪装浏览器请求特征
      final headers = _generateRandomHeaders(url);
      final response = await _dio.get(
        url,
        options: Options(headers: headers),
      );
      return response.data.toString();
    } catch (e) {
      throw Exception('网页抓取失败: $e');
    }
  }

  /// 针对单篇文章提取清洗 HTML
  /// 
  /// 去除无用的 script、style、head 标签以及导航、侧边栏和页脚，并剥离标签的冗余属性，保留核心的 h1-h6、p、img、article 等，以节省大模型 Token。
  String cleanHtmlForSingleArticle(String htmlContent) {
    try {
      final document = parser.parse(htmlContent);

      // 移除无关的全局标签
      document.querySelectorAll('script, style, iframe, noscript, svg, header, footer, nav, aside').forEach((element) {
        element.remove();
      });

      final body = document.body;
      if (body == null) return '';

      // 递归清理所有节点的属性，只保留 img 的 src
      _cleanNodeAttributes(body);

      // 返回精简后的 html 字符串
      return body.innerHtml.replaceAll(RegExp(r'\s+'), ' ').trim();
    } catch (e) {
      return htmlContent; // 如果解析失败，则返回原内容
    }
  }

  /// 针对列表页提取清洗 HTML
  /// 
  /// 主要保留链接（a 标签）和包含文本的结构，删除无关标签，帮助大模型快速精准识别文章列表和分页结构。
  String cleanHtmlForList(String htmlContent) {
    try {
      final document = parser.parse(htmlContent);

      // 移除无关标签
      document.querySelectorAll('script, style, iframe, noscript, svg, header, footer').forEach((element) {
        element.remove();
      });

      final body = document.body;
      if (body == null) return '';

      // 清理属性，但保留 a 标签的 href 属性
      _cleanNodeAttributesForList(body);

      return body.innerHtml.replaceAll(RegExp(r'\s+'), ' ').trim();
    } catch (e) {
      return htmlContent;
    }
  }

  /// 递归清理节点及其子节点的属性（针对单篇）
  /// 
  /// 仅保留 img 标签的 src 属性以供封面图解析，其余属性一律删除，减少无用字符。
  void _cleanNodeAttributes(Element element) {
    // 复制属性名列表，避免在遍历时修改 Map 导致异常
    final keys = listFrom(element.attributes.keys);
    for (var key in keys) {
      if (element.localName == 'img' && key == 'src') {
        continue;
      }
      element.attributes.remove(key);
    }

    for (var child in element.children) {
      _cleanNodeAttributes(child);
    }
  }

  /// 递归清理节点及其子节点的属性（针对列表）
  /// 
  /// 仅保留 a 标签的 href 属性和 img 的 src 属性，其余属性一律删除。
  void _cleanNodeAttributesForList(Element element) {
    final keys = listFrom(element.attributes.keys);
    for (var key in keys) {
      if ((element.localName == 'a' && key == 'href') || (element.localName == 'img' && key == 'src')) {
        continue;
      }
      element.attributes.remove(key);
    }

    for (var child in element.children) {
      _cleanNodeAttributesForList(child);
    }
  }

  /// 转换 List 的辅助方法
  /// 
  /// 从 Iterable 复制生成 List，规避直接遍历 keys 时修改它的冲突问题。
  List<T> listFrom<T>(Iterable<T> iterable) {
    return List<T>.from(iterable);
  }

  /// 解析并拼接 URL
  /// 
  /// 将抓取到的相对路径 URL 与基础路径（原网站）进行拼接，返回完整的绝对路径 URL。
  String resolveUrl(String baseUrl, String relativeUrl) {
    if (relativeUrl.startsWith('http://') || relativeUrl.startsWith('https://')) {
      return relativeUrl;
    }
    
    final uri = Uri.parse(baseUrl);
    if (relativeUrl.startsWith('//')) {
      return '${uri.scheme}:$relativeUrl';
    }
    
    if (relativeUrl.startsWith('/')) {
      return '${uri.scheme}://${uri.host}${uri.port != 80 && uri.port != 443 && uri.port != 0 ? ":${uri.port}" : ""}$relativeUrl';
    }

    // 相对路径拼接
    final pathSegments = List<String>.from(uri.pathSegments);
    if (pathSegments.isNotEmpty) {
      pathSegments.removeLast(); // 移除文件名
    }
    
    final relativeSegments = relativeUrl.split('/');
    for (var segment in relativeSegments) {
      if (segment == '.') continue;
      if (segment == '..') {
        if (pathSegments.isNotEmpty) {
          pathSegments.removeLast();
        }
      } else {
        pathSegments.add(segment);
      }
    }

    return Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.port == 0 ? null : uri.port,
      pathSegments: pathSegments,
    ).toString();
  }

  /// 随机获取一个浏览器的完整请求头，包括 User-Agent 和相匹配的 Client Hints，以提高反爬通过率
  Map<String, String> _generateRandomHeaders(String targetUrl) {
    final random = DateTime.now().millisecondsSinceEpoch % _uaTemplates.length;
    final template = _uaTemplates[random];
    final String ua = template['ua'] as String;
    final Map<String, String> hints = Map<String, String>.from(template['hints'] as Map? ?? {});

    final uri = Uri.parse(targetUrl);

    final headers = {
      'User-Agent': ua,
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7',
      'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
      'Accept-Encoding': 'gzip, deflate, br',
      'Connection': 'keep-alive',
      'Upgrade-Insecure-Requests': '1',
      'Sec-Fetch-Dest': 'document',
      'Sec-Fetch-Mode': 'navigate',
      'Sec-Fetch-Site': 'none',
      'Sec-Fetch-User': '?1',
    };

    if (hints.isNotEmpty) {
      headers.addAll(hints);
    }

    // 自动添加 Host 和 Referer，进一步增强真实性
    headers['Host'] = uri.host;
    
    return headers;
  }

  /// 设置代理服务器，格式为 "host:port"，例如 "127.0.0.1:7890"
  /// 
  /// 传入空值（null 或空字符串）则恢复直连模式
  void setProxy(String? proxyUrl) {
    if (proxyUrl == null || proxyUrl.isEmpty) {
      _dio.httpClientAdapter = IOHttpClientAdapter(); // 恢复默认直连
      return;
    }
    _dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.findProxy = (uri) {
          return 'PROXY $proxyUrl';
        };
        // 忽略 SSL 证书校验，防止因为代理导致证书报错
        client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
        return client;
      },
    );
  }

  /// 判断抓取到的文本内容是否是 RSS 或 Atom 结构化订阅源
  /// 
  /// 传入内容文本，通过前缀和特定 XML 标签关键字进行嗅探。
  bool isRssContent(String content) {
    final trimmed = content.trim();
    return trimmed.startsWith('<?xml') || 
           trimmed.contains('<rss') || 
           trimmed.contains('<feed') || 
           trimmed.contains('<channel') ||
           trimmed.contains('<item') ||
           trimmed.contains('<entry');
  }

  /// 解析 RSS 或 Atom 结构化订阅源中的文章项列表
  /// 
  /// 自动兼容并解析 RSS 的 <item> 和 Atom 的 <entry> 标签，并尝试提取标题、文章详情链接、正文内容、发布日期以及正文首图。
  List<Map<String, String>> parseRss(String rssContent, String baseUrl) {
    final List<Map<String, String>> articles = [];
    try {
      final document = parser.parse(rssContent);
      
      // 兼容 RSS 2.0 的 <item> 和 Atom Feed 的 <entry>
      var items = document.querySelectorAll('item');
      final isAtom = items.isEmpty;
      if (isAtom) {
        items = document.querySelectorAll('entry');
      }

      for (var item in items) {
        // 1. 提取标题
        final title = item.querySelector('title')?.text.trim() ?? '未命名文章';

        // 2. 提取文章详情链接
        var link = _extractLinkFromItem(item, isAtom);
        if (link.isEmpty) continue;
        link = resolveUrl(baseUrl, link);

        // 3. 提取正文内容
        var content = '';
        // 查找 content:encoded
        final encodedElements = item.children.where((e) => e.localName == 'encoded');
        if (encodedElements.isNotEmpty) {
          content = encodedElements.first.text.trim();
        }
        if (content.isEmpty) {
          content = item.querySelector('content')?.text.trim() ?? '';
        }
        if (content.isEmpty) {
          content = item.querySelector('description')?.text.trim() ?? '';
        }

        // 4. 提取首图作为封面图
        var coverUrl = '';
        if (content.isNotEmpty) {
          try {
            final contentDoc = parser.parse(content);
            final firstImg = contentDoc.querySelector('img');
            if (firstImg != null) {
              final src = firstImg.attributes['src'] ?? '';
              if (src.isNotEmpty) {
                coverUrl = resolveUrl(link, src);
              }
            }
          } catch (_) {}
        }

        // 5. 提取发布时间
        final date = item.querySelector('pubDate')?.text.trim() ?? 
                     item.querySelector('published')?.text.trim() ?? 
                     item.querySelector('updated')?.text.trim() ?? '';

        articles.add({
          'title': title,
          'link': link,
          'content': content,
          'cover_url': coverUrl,
          'date': date,
        });
      }
    } catch (_) {}
    return articles;
  }

  /// 将 HTML 文本极简转换为简洁 of Markdown 排版格式
  /// 
  /// 使用 Isolate 转移至后台计算线程，防止大文本解析堵塞主 UI 线程。
  Future<String> htmlToMarkdown(String html) async {
    return await Isolate.run(() => _htmlToMarkdownSync(html));
  }

  /// 同步转换 HTML 为 Markdown 逻辑，供 Isolate 调用
  static String _htmlToMarkdownSync(String html) {
    try {
      final document = parser.parse(html);
      final body = document.body;
      if (body == null) return html;

      final buffer = StringBuffer();
      
      void convertNode(Node node) {
        if (node.nodeType == Node.TEXT_NODE) {
          final text = node.text?.trim() ?? '';
          if (text.isNotEmpty) {
            buffer.write(text);
          }
        } else if (node is Element) {
          final localName = node.localName;
          
          if (localName == 'p') {
            buffer.write('\n\n');
            for (var child in node.nodes) {
              convertNode(child);
            }
            buffer.write('\n\n');
          } else if (localName == 'br') {
            buffer.write('\n');
          } else if (localName == 'h1' || localName == 'h2' || localName == 'h3' || localName == 'h4') {
            final tag = localName!;
            var headingLevel = 2;
            if (tag.length > 1) {
              headingLevel = int.tryParse(tag.substring(1)) ?? 2;
            }
            final prefix = '#' * headingLevel;
            buffer.write('\n\n$prefix ');
            for (var child in node.nodes) {
              convertNode(child);
            }
            buffer.write('\n\n');
          } else if (localName == 'strong' || localName == 'b') {
            buffer.write(' **');
            for (var child in node.nodes) {
              convertNode(child);
            }
            buffer.write('** ');
          } else if (localName == 'em' || localName == 'i') {
            buffer.write(' *');
            for (var child in node.nodes) {
              convertNode(child);
            }
            buffer.write('* ');
          } else if (localName == 'img') {
            final src = node.attributes['src'] ?? '';
            final alt = node.attributes['alt'] ?? '图片';
            if (src.isNotEmpty) {
              buffer.write('\n\n![$alt]($src)\n\n');
            }
          } else if (localName == 'a') {
            final href = node.attributes['href'] ?? '';
            buffer.write(' [');
            for (var child in node.nodes) {
              convertNode(child);
            }
            buffer.write(']($href) ');
          } else {
            for (var child in node.nodes) {
              convertNode(child);
            }
          }
        }
      }

      for (var node in body.nodes) {
        convertNode(node);
      }

      return buffer.toString()
          .replaceAll(RegExp(r'\n{3,}'), '\n\n')
          .trim();
    } catch (_) {
      return html;
    }
  }

  /// 判断抓取到的 HTML 内容是否是一个文章列表页而非单篇文章详情页
  /// 
  /// 结合 HTML 文本长度、链接密度以及特定文本标签（如 <p> 标签）的占比来进行启发式评估。
  bool isListContent(String htmlContent) {
    if (htmlContent.isEmpty) return false;
    try {
      final document = parser.parse(htmlContent);
      final body = document.body;
      if (body == null) return false;

      // 1. 提取出所有文本和所有超链接
      final textLength = body.text.replaceAll(RegExp(r'\s+'), '').length;
      if (textLength == 0) return false;

      // 2. 统计所有 <a> 标签内文字的长度
      final aElements = body.querySelectorAll('a');
      var aTextLength = 0;
      for (var a in aElements) {
        aTextLength += a.text.replaceAll(RegExp(r'\s+'), '').length;
      }

      // 3. 统计 <a> 标签的数量
      final totalLinks = aElements.length;

      // 4. 链接文本占整个页面文本的占比（Link Density）
      final linkDensity = aTextLength / textLength;

      // 5. 页面中长段落的数量。详情页通常会有多个含有较长文本的段落（比如包含很多字符的 <p> 标签）
      final pElements = body.querySelectorAll('p');
      var longParagraphCount = 0;
      for (var p in pElements) {
        if (p.text.trim().length > 80) {
          longParagraphCount++;
        }
      }

      // 启发式逻辑判定：
      // 如果长段落较少，并且链接总数较多，或者链接文本占比高，则判定为列表页。
      if (longParagraphCount < 3 && (totalLinks > 15 || linkDensity > 0.45)) {
        return true;
      }
      
      // 如果链接密度极大（大于 60%），即便有一些长段落，也大概率是列表/导航页
      if (linkDensity > 0.6) {
        return true;
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  /// 兼容提取 RSS 或 Atom 里的链接，突破 HTML 解析器把 link 标签当做自闭合标签的缺陷
  String _extractLinkFromItem(Element item, bool isAtom) {
    if (isAtom) {
      final href = item.querySelector('link')?.attributes['href'] ?? '';
      if (href.isNotEmpty) return href;
    }
    
    final outerHtml = item.outerHtml;
    
    // 1. 优先尝试提取 <link> 标签后面的文本直到下一个标签 < 开始
    final linkRegExp = RegExp(r'<link[^>]*>([^<]+)', caseSensitive: false);
    final match = linkRegExp.firstMatch(outerHtml);
    if (match != null) {
      final rawLink = match.group(1)?.trim() ?? '';
      if (rawLink.isNotEmpty) {
        return rawLink;
      }
    }
    
    // 2. 尝试匹配 <link href="..." /> (双引号)
    final hrefDoubleRegExp = RegExp(r'<link[^>]+href="([^"]*)"', caseSensitive: false);
    final hrefDoubleMatch = hrefDoubleRegExp.firstMatch(outerHtml);
    if (hrefDoubleMatch != null) {
      final rawHref = hrefDoubleMatch.group(1)?.trim() ?? '';
      if (rawHref.isNotEmpty) return rawHref;
    }
    
    // 3. 尝试匹配 <link href='...' /> (单引号)
    final hrefSingleRegExp = RegExp(r"<link[^>]+href='([^']*)'", caseSensitive: false);
    final hrefSingleMatch = hrefSingleRegExp.firstMatch(outerHtml);
    if (hrefSingleMatch != null) {
      final rawHref = hrefSingleMatch.group(1)?.trim() ?? '';
      if (rawHref.isNotEmpty) return rawHref;
    }

    return item.querySelector('link')?.text.trim() ?? '';
  }
}
