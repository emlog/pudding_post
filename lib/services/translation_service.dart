import 'package:dio/dio.dart';

/// 网页内容翻译服务
/// 
/// 提供自动判断语言是否为英文，并调用 Google 免费翻译接口将其翻译为简体中文的功能。
/// 内置长文本自动分段翻译能力，规避 GET 请求 URL 长度超限的问题。
class TranslationService {
  final _dio = Dio();

  /// 判定文本是否为英文内容
  /// 
  /// 通过统计清理后的字母文本中英文字母所占的比例，如果超过 50% 则判定为英文文本。
  bool isEnglish(String text) {
    if (text.isEmpty) return false;
    // 过滤掉空白和常见标点符号
    final cleaned = text.replaceAll(RegExp(r'[\s\p{P}]+', unicode: true), '');
    if (cleaned.isEmpty) return false;
    
    // 统计英文字母的总个数
    final englishChars = RegExp(r'[a-zA-Z]').allMatches(cleaned).length;
    
    // 英文字符占比超过 50% 判定为英文内容
    return englishChars / cleaned.length > 0.5;
  }

  /// 调用 Google 免费接口将文本翻译为简体中文
  /// 
  /// 内部对长文本进行分片（每片最大 1500 字符），分片调用以防 GET 请求因超长被阻断。
  Future<String> translateToChinese(String text) async {
    if (text.isEmpty) return text;

    final lines = text.split('\n');
    final List<String> chunks = [];
    var currentChunk = StringBuffer();

    for (var line in lines) {
      if (currentChunk.length + line.length > 1500) {
        chunks.add(currentChunk.toString());
        currentChunk = StringBuffer();
      }
      currentChunk.write(line + '\n');
    }
    if (currentChunk.isNotEmpty) {
      chunks.add(currentChunk.toString());
    }

    final List<String> translatedChunks = [];
    for (var chunk in chunks) {
      try {
        final translated = await _translateChunk(chunk.trim());
        translatedChunks.add(translated);
      } catch (_) {
        // 若某个分块翻译失败，则容错保留原文分块，避免整篇文字丢失
        translatedChunks.add(chunk);
      }
    }

    return translatedChunks.join('\n');
  }

  /// 翻译单片字符内容
  Future<String> _translateChunk(String chunk) async {
    if (chunk.isEmpty) return chunk;

    const url = 'https://translate.googleapis.com/translate_a/single';
    final response = await _dio.get(
      url,
      queryParameters: {
        'client': 'gtx',
        'sl': 'auto',
        'tl': 'zh-CN',
        'dt': 't',
        'q': chunk,
      },
      options: Options(
        headers: {
          'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        },
      ),
    );

    if (response.statusCode == 200 && response.data != null) {
      final List<dynamic> data = response.data;
      if (data.isNotEmpty && data[0] is List) {
        final List<dynamic> sentences = data[0];
        final buffer = StringBuffer();
        for (var sentence in sentences) {
          if (sentence is List && sentence.isNotEmpty) {
            buffer.write(sentence[0]?.toString() ?? '');
          }
        }
        return buffer.toString();
      }
    }
    throw Exception('Google 翻译返回了无效数据');
  }
}
