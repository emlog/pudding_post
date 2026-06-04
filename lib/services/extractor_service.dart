import 'package:dio/dio.dart';
import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart';

/// 网页内容抓取与 HTML 结构精简服务类
/// 
/// 负责对目标 URL 发起网络请求获取网页源代码，并使用 html 库对 DOM 树进行精简和标签清洗，以减少发送给大模型的 Token 数量。
class ExtractorService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    headers: {
      'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    },
  ));

  /// 根据提供的 URL 抓取网页 HTML 源代码
  /// 
  /// 使用 Dio 发起 HTTP GET 请求，获取网页源码并返回字符串。如果出错则抛出异常。
  Future<String> fetchHtml(String url) async {
    try {
      final response = await _dio.get(url);
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
}
