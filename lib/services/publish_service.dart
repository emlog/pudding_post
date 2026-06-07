import 'package:dio/dio.dart';
import 'database_service.dart';

/// 文章发布服务类
/// 
/// 目前主要支持对接 emlog 系统，通过配置的 API 地址及密钥将采集的文章推送到站点中，后续可扩展其他发布渠道。
class PublishService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 20),
  ));

  /// 获取 emlog 的配置参数
  /// 
  /// 从本地数据库读取 emlog 的站点网址和 API 密钥。
  Future<Map<String, String>> _getEmlogConfig() async {
    final db = DatabaseService.instance;
    final siteUrl = await db.getSetting('emlog_site_url', defaultValue: '');
    final apiKey = await db.getSetting('emlog_api_key', defaultValue: '');
    return {
      'siteUrl': siteUrl,
      'apiKey': apiKey,
    };
  }

  /// 测试 emlog API 连接及密钥有效性
  /// 
  /// 尝试获取分类列表。若能成功获取，则说明站点 URL 和 API 密钥配置正确。
  Future<bool> testConnection(String siteUrl, String apiKey) async {
    if (siteUrl.isEmpty || apiKey.isEmpty) return false;
    try {
      final cleanUrl = siteUrl.endsWith('/') ? siteUrl.substring(0, siteUrl.length - 1) : siteUrl;
      // 尝试访问 emlog 官方标准分类 API 接口
      final response = await _dio.get(
        '$cleanUrl/content/api/sort.php',
        queryParameters: {'token': apiKey},
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// 获取 emlog 系统的文章分类列表
  /// 
  /// 用于发布文章时让用户选择对应的分类。返回分类 ID 与分类名称的 Map 列表。
  Future<List<Map<String, dynamic>>> fetchCategories() async {
    final config = await _getEmlogConfig();
    final siteUrl = config['siteUrl']!;
    final apiKey = config['apiKey']!;

    if (siteUrl.isEmpty || apiKey.isEmpty) {
      throw Exception('请先配置 emlog 的站点网址和 API 密钥');
    }

    try {
      final cleanUrl = siteUrl.endsWith('/') ? siteUrl.substring(0, siteUrl.length - 1) : siteUrl;
      final response = await _dio.get(
        '$cleanUrl/content/api/sort.php',
        queryParameters: {'token': apiKey},
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is List) {
          return data.map((item) {
            return {
              'id': item['sid']?.toString() ?? item['id']?.toString() ?? '',
              'name': item['sortname']?.toString() ?? item['name']?.toString() ?? '',
            };
          }).toList();
        } else if (data is Map && data.containsKey('data')) {
          // 有些接口将分类列表包裹在 data 字段下
          final list = data['data'] as List;
          return list.map((item) {
            return {
              'id': item['sid']?.toString() ?? item['id']?.toString() ?? '',
              'name': item['sortname']?.toString() ?? item['name']?.toString() ?? '',
            };
          }).toList();
        }
      }
      return [];
    } catch (e) {
      throw Exception('获取 emlog 分类列表失败: $e');
    }
  }

  /// 发布单篇文章至 emlog 系统
  /// 
  /// 传入文章标题、Markdown 内容、分类 ID 以及封面图 URL。发布成功后返回文章在系统中的绝对 URL 地址。
  Future<String> publishToEmlog({
    required String title,
    required String content,
    required String sortId,
    required String coverUrl,
  }) async {
    final config = await _getEmlogConfig();
    final siteUrl = config['siteUrl']!;
    final apiKey = config['apiKey']!;

    if (siteUrl.isEmpty || apiKey.isEmpty) {
      throw Exception('请先配置 emlog 的站点网址和 API 密钥');
    }

    final cleanUrl = siteUrl.endsWith('/') ? siteUrl.substring(0, siteUrl.length - 1) : siteUrl;

    try {
      // 构造 emlog 的文章发布 API 数据格式
      final response = await _dio.post(
        '$cleanUrl/content/api/post.php',
        queryParameters: {'token': apiKey},
        data: {
          'title': title,
          'content': content,
          'sort': sortId,
          'cover': coverUrl,
          'markdown': '1', // 标识为 Markdown 格式内容
          'status': 'active', // 默认直接发布为公开文章，或者是 'draft'
        },
        options: Options(
          contentType: Headers.jsonContentType,
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        // 如果发布成功，emlog 接口一般会返回文章 ID 或文章 URL
        // 例如 {"code": 200, "msg": "success", "id": 123} 或者是直接返回 URL
        if (data is Map) {
          final articleId = data['id']?.toString() ?? data['data']?['id']?.toString() ?? '';
          if (articleId.isNotEmpty) {
            // 拼接成前台访问的地址，具体根据 emlog 的链接结构（如 /?post=123 或 /post-123.html）
            // 这里返回一个相对稳妥的默认地址，用户可以通过它查看
            return '$cleanUrl/?post=$articleId';
          }
        }
        return '$cleanUrl/';
      } else {
        throw Exception('emlog 接口返回异常，HTTP 状态码: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('发布文章到 emlog 失败: $e');
    }
  }
}
