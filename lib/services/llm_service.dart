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

  /// 调用大模型对文章内容进行扩写与补充
  /// 
  /// 根据提供的文章标题与现有简短内容/摘要，利用大语言模型进行知识背景、细节细节的扩写。
  Future<String> enrichContent(String title, String currentContent) async {
    final config = await _getLlmConfig();
    final baseUrl = config['baseUrl']!;
    final apiKey = config['apiKey']!;
    final model = config['model']!;

    if (apiKey.isEmpty) {
      throw Exception('请先配置大模型的 API Key');
    }

    final prompt = '你是一个专业的文章内容扩写与补充助手。请根据我提供的文章标题和现有的简短内容/摘要，对内容进行扩写和丰富。你可以补充背景知识、详细过程、原理解释、多角度分析和结论总结，使其成为一篇逻辑严密、详实且可读性强的完整文章。\n'
        '要求：\n'
        '1. 直接输出扩写后的完整正文，使用优雅、清晰的 Markdown 格式排版。\n'
        '2. 保持原意不变，但要丰富其细节与深度。\n'
        '3. 绝对不要包含任何开头说明、解释性文字或 Markdown 代码块包裹（如 ```markdown 或 ```）。';

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
            {'role': 'system', 'content': prompt},
            {'role': 'user', 'content': '【文章标题】：$title\n\n【现有内容】：\n$currentContent'}
          ],
          'temperature': 0.7,
        },
      );

      if (response.statusCode != 200) {
        throw Exception('LLM 接口返回异常，HTTP 状态码: ${response.statusCode}');
      }

      final choices = response.data['choices'] as List;
      if (choices.isEmpty) {
        throw Exception('LLM 没有返回有效内容');
      }

      var content = choices[0]['message']['content'].toString().trim();
      if (content.startsWith('```markdown')) {
        content = content.replaceFirst('```markdown', '');
        if (content.endsWith('```')) {
          content = content.substring(0, content.length - 3);
        }
      } else if (content.startsWith('```')) {
        content = content.replaceFirst('```', '');
        if (content.endsWith('```')) {
          content = content.substring(0, content.length - 3);
        }
      }
      return content.trim();
    } catch (e) {
      throw Exception('调用大模型扩写失败: $e');
    }
  }

  /// 调用大模型将多篇文章融合成一篇公众号文章
  /// 
  /// 接收包含标题与正文的一组文章数据，融合成一篇逻辑严密、结构新颖的公众号风格文章。
  Future<Map<String, String>> mergeArticles(List<Map<String, String>> sourceArticles) async {
    final config = await _getLlmConfig();
    final baseUrl = config['baseUrl']!;
    final apiKey = config['apiKey']!;
    final model = config['model']!;

    if (apiKey.isEmpty) {
      throw Exception('请先配置大模型的 API Key');
    }

    final articlesJson = jsonEncode(sourceArticles);

    final prompt = '你是一个自媒体内容专家和微信公众号主笔。请将多篇相关的参考文章融合成一篇观点清晰、结构完整、行文流畅的微信公众号文章。\n'
        '要求：\n'
        '1. 提炼并整合这几篇文章的核心观点，进行深度逻辑融合，不要简单地拼凑。要给出一个引人入胜的公众号风格标题。\n'
        '2. 融合后的正文必须使用优雅、适合手机阅读的 Markdown 格式排版（包含适当的层级标题、重点加粗等），字数在 1000 - 2500 字左右。\n'
        '3. 严格按照以下 JSON 格式输出，不要包含任何额外的Markdown包裹（如 ```json）或解释文字：\n'
        '{\n'
        '  "title": "融合后的文章标题",\n'
        '  "content": "这里是融合后的 Markdown 格式正文内容"\n'
        '}';

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
            {'role': 'system', 'content': prompt},
            {'role': 'user', 'content': '下面是需要融合的多篇文章数据（标题及正文）：\n\n$articlesJson'}
          ],
          'temperature': 0.7,
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
      final parsed = _parseJsonFromMarkdown(content);
      
      return {
        'title': parsed['title']?.toString() ?? '未命名融合文章',
        'content': parsed['content']?.toString() ?? '',
      };
    } catch (e) {
      throw Exception('调用大模型融合文章失败: $e');
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
    
    // 双重加固：自动寻找首个 '{' 与最后一个 '}'，以剥离大模型返回的引导用语或多余废话
    final start = rawJson.indexOf('{');
    final end = rawJson.lastIndexOf('}');
    if (start != -1 && end != -1 && end > start) {
      rawJson = rawJson.substring(start, end + 1);
    }

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
