import 'dart:convert';
import 'package:dio/dio.dart';
import 'database_service.dart';

/// 大语言模型 (LLM) 服务对接类
/// 
/// 提供与 OpenAI 格式兼容的 LLM 接口通信，通过预设 Prompt 提取单篇文章的内容或文章列表及分页链接。
class LlmService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 45), // LLM 响应可能较慢，给足超时时间
    receiveTimeout: const Duration(seconds: 45),
  ));

  /// 获取当前配置的 LLM 配置参数
  /// 
  /// 从本地数据库中动态读取 Base URL, API Key 和 Model Name。
  Future<Map<String, String>> _getLlmConfig() async {
    final db = DatabaseService.instance;
    final baseUrl = await db.getSetting('llm_base_url', defaultValue: 'https://api.deepseek.com/v1');
    final apiKey = await db.getSetting('llm_api_key', defaultValue: '');
    final model = await db.getSetting('llm_model', defaultValue: 'deepseek-chat');
    return {
      'baseUrl': baseUrl,
      'apiKey': apiKey,
      'model': model,
    };
  }

  /// 测试 LLM API 的连通性
  /// 
  /// 使用当前配置的参数向大模型发送一个简单的问候，若能正常返回说明连接成功。
  Future<bool> testConnection(String baseUrl, String apiKey, String model) async {
    try {
      final response = await _dio.post(
        '$baseUrl/chat/completions',
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
        ),
        data: {
          'model': model,
          'messages': [
            {'role': 'user', 'content': 'Hi'}
          ],
          'max_tokens': 10,
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// 调用大模型提取单篇文章详情
  /// 
  /// 传入精简后的网页 HTML 和 Prompt 模板，调用 LLM 返回 JSON 字符串并解析出标题、Markdown 正文及封面图 URL。
  Future<Map<String, dynamic>> extractArticle(String cleanedHtml, String promptTemplate) async {
    final config = await _getLlmConfig();
    final baseUrl = config['baseUrl']!;
    final apiKey = config['apiKey']!;
    final model = config['model']!;

    if (apiKey.isEmpty) {
      throw Exception('请先配置大模型的 API Key');
    }

    try {
      final response = await _dio.post(
        '$baseUrl/chat/completions',
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
        ),
        data: {
          'model': model,
          'messages': [
            {'role': 'system', 'content': promptTemplate},
            {'role': 'user', 'content': '下面是需要提取文章详情的网页HTML源码：\n\n$cleanedHtml'}
          ],
          'temperature': 0.1, // 低温度，确保 JSON 格式稳定
        },
      );

      if (response.statusCode != 200) {
        throw Exception('LLM 接口返回异常，HTTP 状态码: ${response.statusCode}');
      }

      final choices = response.data['choices'] as List;
      if (choices.isEmpty) {
        throw Exception('LLM 没有返回有效内容');
      }

      final content = choices[0]['message']['content'].toString().trim();
      return _parseJsonFromMarkdown(content);
    } catch (e) {
      throw Exception('调用大模型提取文章失败: $e');
    }
  }

  /// 调用大模型解析文章列表页
  /// 
  /// 传入列表页的 HTML 及列表解析 Prompt，调用 LLM 返回 JSON 字符串并解析出文章 URL 列表及分页链接。
  Future<Map<String, dynamic>> extractList(String cleanedHtml, String promptTemplate) async {
    final config = await _getLlmConfig();
    final baseUrl = config['baseUrl']!;
    final apiKey = config['apiKey']!;
    final model = config['model']!;

    if (apiKey.isEmpty) {
      throw Exception('请先配置大模型的 API Key');
    }

    try {
      final response = await _dio.post(
        '$baseUrl/chat/completions',
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
        ),
        data: {
          'model': model,
          'messages': [
            {'role': 'system', 'content': promptTemplate},
            {'role': 'user', 'content': '下面是需要提取列表和分页信息的网页HTML源码：\n\n$cleanedHtml'}
          ],
          'temperature': 0.1,
        },
      );

      if (response.statusCode != 200) {
        throw Exception('LLM 接口返回异常，HTTP 状态码: ${response.statusCode}');
      }

      final choices = response.data['choices'] as List;
      if (choices.isEmpty) {
        throw Exception('LLM 没有返回有效内容');
      }

      final content = choices[0]['message']['content'].toString().trim();
      return _parseJsonFromMarkdown(content);
    } catch (e) {
      throw Exception('调用大模型解析列表失败: $e');
    }
  }

  /// 从返回的文本中提取并解析 JSON
  /// 
  /// 大模型有时会用 ```json ... ``` 包裹 JSON 内容，此处使用正则提取并进行 JSON 反序列化。
  Map<String, dynamic> _parseJsonFromMarkdown(String text) {
    var rawJson = text;
    // 匹配 ```json ... ``` 或者 ``` ... ```
    final regExp = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```');
    final match = regExp.firstMatch(text);
    if (match != null) {
      rawJson = match.group(1)!;
    }

    rawJson = rawJson.trim();
    try {
      return jsonDecode(rawJson) as Map<String, dynamic>;
    } catch (e) {
      // 容错处理：如果直接解析失败，尝试清洗掉一些可能破坏 JSON 的控制字符
      try {
        final sanitized = rawJson
            .replaceAll('\n', '\\n')
            .replaceAll('\r', '\\r')
            .replaceAll('\t', '\\t');
        return jsonDecode(sanitized) as Map<String, dynamic>;
      } catch (_) {
        throw Exception('无法解析 LLM 返回的 JSON 格式。原始返回数据:\n$text');
      }
    }
  }
}
