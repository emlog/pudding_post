import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as parser;
import 'package:pudding_post/services/translation_service.dart';
import 'package:pudding_post/services/wechat_format_service.dart';


/// 测试 RSS 内容抓取及解析
void main() {
  // 注册翻译服务测试
  runTranslationTests();
  // 注册微信排版转换测试
  runWeChatTests();
  test('Debug RSS URLs fetching and parsing', () async {
    final dio = Dio();
    final urls = [
      'https://www.williamlong.info/rss.xml?utm_source=chatgpt.com',
      'https://feeds.feedburner.com/TheHackersNews',
      'https://searchengineland.com/feed?utm_source=chatgpt.com',
    ];

    for (var url in urls) {
      print('\n=======================================');
      print('Fetching URL: $url');
      try {
        final response = await dio.get(
          url,
          options: Options(
            headers: {
              'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
              'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            },
            followRedirects: true,
            validateStatus: (status) => true,
          ),
        );
        final String content = response.data.toString();
        print('Status Code: ${response.statusCode}');
        print('Content Length: ${content.length}');
        
        final isRss = isRssContent(content);
        print('Detected as RSS? $isRss');
        
        if (content.length > 500) {
          print('Snippet:\n${content.substring(0, 500)}');
        } else {
          print('Snippet:\n$content');
        }

        final document = parser.parse(content);
        var items = document.querySelectorAll('item');
        print('Found <item> tags: ${items.length}');
        
        for (var i = 0; i < items.length && i < 3; i++) {
          final item = items[i];
          final title = item.querySelector('title')?.text.trim() ?? '未命名文章';
          final linkText = extractLinkFromItem(item, false);
          print('  - Item $i: title="$title", link="$linkText"');
          if (i == 0) {
            print('    OuterHTML: ${item.outerHtml}');
          }
        }
        
        var entries = document.querySelectorAll('entry');
        print('Found <entry> tags: ${entries.length}');
        for (var i = 0; i < entries.length && i < 3; i++) {
          final entry = entries[i];
          final title = entry.querySelector('title')?.text.trim() ?? '未命名文章';
          final linkText = extractLinkFromItem(entry, true);
          print('  - Entry $i: title="$title", link="$linkText"');
        }
        
      } catch (e) {
        print('Error: $e');
      }
    }
  });
}

/// 启发式判断内容是否是 RSS
bool isRssContent(String content) {
  final trimmed = content.trim();
  return trimmed.startsWith('<?xml') || 
         trimmed.contains('<rss') || 
         trimmed.contains('<feed') || 
         trimmed.contains('<channel') ||
         trimmed.contains('<item') ||
         trimmed.contains('<entry');
}

/// 兼容提取 RSS 或 Atom 里的链接，突破 HTML 解析器把 link 标签当做自闭合标签的缺陷
String extractLinkFromItem(dynamic item, bool isAtom) {
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
    if (rawHref.isNotEmpty) {
      return rawHref;
    }
  }
  
  // 3. 尝试匹配 <link href='...' /> (单引号)
  final hrefSingleRegExp = RegExp(r"<link[^>]+href='([^']*)'", caseSensitive: false);
  final hrefSingleMatch = hrefSingleRegExp.firstMatch(outerHtml);
  if (hrefSingleMatch != null) {
    final rawHref = hrefSingleMatch.group(1)?.trim() ?? '';
    if (rawHref.isNotEmpty) {
      return rawHref;
    }
  }

  return item.querySelector('link')?.text.trim() ?? '';
}

/// 翻译服务的单元测试
void runTranslationTests() {
  test('TranslationService - Language detection and Google translation test', () async {
    final translationService = TranslationService();

    // 1. 语言检测测试
    final englishText = "This is a simple text containing english words to test detection.";
    final chineseText = "这是一段用来测试语言检测是否工作的普通中文字符串。";
    final mixedText = "这是一篇关于 Flutter 桌面端开发的中文技术文章，Hello World.";

    expect(translationService.isEnglish(englishText), isTrue);
    expect(translationService.isEnglish(chineseText), isFalse);
    expect(translationService.isEnglish(mixedText), isFalse); // 中文为主或中英混合非纯英文应当返回 false

    // 2. 免费翻译服务测试
    final translationResult = await translationService.translateToChinese("Hello World! Let us test Google Translate service.");
    print('Translation result: "$translationResult"');
    
    // 翻译结果应当包含“你好”或“世界”或“服务”等字词
    expect(translationResult.contains('你好') || translationResult.contains('世界') || translationResult.contains('翻译') || translationResult.contains('服务'), isTrue);
  });
}

/// 微信排版转换的单元测试
void runWeChatTests() {
  test('WeChatFormatService - Markdown to HTML with custom style sheets', () {
    final markdown = '''# 第一标题
## 第二小标题
### 第三小标题
这是一段普通正文，包含了**加粗文字**和`行内代码`。
[Google](https://google.com) 是一个搜索引擎。
- 列表第一项
- 列表第二项
''';

    final htmlResult = WeChatFormatService.markdownToWeChatHtml(markdown);
    
    // 验证核心样式是否存在以确保排版美观且符合规范
    // 1. 验证 H1 样式：居中且有绿色下横线
    expect(htmlResult, contains('text-align: center;'));
    expect(htmlResult, contains('border-bottom: 2px solid #00b578;'));
    
    // 2. 验证 H2 样式：绿底白字圆角阴影
    expect(htmlResult, contains('background-color: #00b578;'));
    expect(htmlResult, contains('color: #ffffff;'));
    expect(htmlResult, contains('border-radius: 4px;'));

    // 3. 验证 H3 样式：带绿色左侧边框
    expect(htmlResult, contains('border-left: 4px solid #00b578;'));

    // 4. 验证段落样式：行高 1.8，两端对齐
    expect(htmlResult, contains('line-height: 1.8;'));
    expect(htmlResult, contains('text-align: justify;'));

    // 5. 验证行内元素样式：加粗和代码块
    expect(htmlResult, contains('<strong style="color: #ffffff; font-weight: bold;">加粗文字</strong>'));
    expect(htmlResult, contains('<code style="color: #FF9D00;'));

    // 6. 验证链接样式
    expect(htmlResult, contains('<a href="https://google.com" style="color: #00C9FF; text-decoration: underline;">Google</a>'));

    // 7. 验证无序列表样式
    expect(htmlResult, contains('<ul style="color: #d2d7e5; font-size: 14px; line-height: 1.8;'));
    expect(htmlResult, contains('<li style="margin-bottom: 8px; letter-spacing: 0.5px;">列表第一项</li>'));
  });
}

