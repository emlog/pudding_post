import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';

/// 微信公众号文章排版与发布服务
/// 
/// 负责将 Markdown 格式内容转化为符合微信公众号富文本粘贴规范的 HTML，
/// 以及在 macOS 上通过原生 NSPasteboard 写入富文本 HTML。
class WeChatFormatService {
  
  /// 将 Markdown 文本转换为符合微信公众号行内排版样式的 HTML 字符串
  static String markdownToWeChatHtml(String markdown) {
    final lines = markdown.split('\n');
    final htmlBuffer = StringBuffer();
    
    // 微信公众号正文外层容器样式，适配淡灰/暗色系或默认底色
    htmlBuffer.write('<div style="background-color: #0B0C10; padding: 20px; font-family: -apple-system, BlinkMacSystemFont, \'Segoe UI\', Roboto, Helvetica, Arial, sans-serif; border-radius: 8px;">');
    
    var inList = false;

    for (var line in lines) {
      var trimmed = line.trim();
      if (trimmed.isEmpty) {
        if (inList) {
          htmlBuffer.write('</ul>\n');
          inList = false;
        }
        continue;
      }

      // 1. 解析 H1 / 标题
      if (trimmed.startsWith('# ')) {
        if (inList) { htmlBuffer.write('</ul>\n'); inList = false; }
        final text = trimmed.substring(2).trim();
        htmlBuffer.write('<h1 style="text-align: center; color: #ffffff; font-size: 20px; font-weight: bold; margin-top: 24px; margin-bottom: 20px; padding-bottom: 10px; border-bottom: 2px solid #00b578; letter-spacing: 1px;">$text</h1>\n');
        continue;
      }

      // 2. 解析 H2
      if (trimmed.startsWith('## ')) {
        if (inList) { htmlBuffer.write('</ul>\n'); inList = false; }
        final text = trimmed.substring(3).trim();
        htmlBuffer.write('<div style="text-align: center; margin-top: 28px; margin-bottom: 20px;">\n');
        htmlBuffer.write('  <span style="display: inline-block; background-color: #00b578; color: #ffffff; font-size: 15px; font-weight: bold; padding: 8px 18px; border-radius: 4px; letter-spacing: 1.5px; box-shadow: 0 2px 8px rgba(0, 181, 120, 0.3);">$text</span>\n');
        htmlBuffer.write('</div>\n');
        continue;
      }

      // 3. 解析 H3
      if (trimmed.startsWith('### ')) {
        if (inList) { htmlBuffer.write('</ul>\n'); inList = false; }
        final text = trimmed.substring(4).trim();
        htmlBuffer.write('<h3 style="color: #ffffff; font-size: 16px; font-weight: bold; margin-top: 20px; margin-bottom: 12px; border-left: 4px solid #00b578; padding-left: 10px; letter-spacing: 1px;">$text</h3>\n');
        continue;
      }

      // 4. 解析列表项
      if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
        if (!inList) {
          htmlBuffer.write('<ul style="color: #d2d7e5; font-size: 14px; line-height: 1.8; margin-bottom: 16px; padding-left: 20px; list-style-type: disc;">\n');
          inList = true;
        }
        var text = trimmed.substring(2).trim();
        text = _parseInlineStyles(text);
        htmlBuffer.write('  <li style="margin-bottom: 8px; letter-spacing: 0.5px;">$text</li>\n');
        continue;
      }

      // 5. 其它普通行段落
      if (inList) {
        htmlBuffer.write('</ul>\n');
        inList = false;
      }

      // 图片处理
      final imgRegex = RegExp(r'!\[(.*?)\]\((.*?)\)');
      if (imgRegex.hasMatch(trimmed)) {
        final match = imgRegex.firstMatch(trimmed);
        final alt = match?.group(1) ?? '';
        final src = match?.group(2) ?? '';
        htmlBuffer.write('<div style="text-align: center; margin: 20px 0;">\n');
        htmlBuffer.write('  <img src="$src" alt="$alt" style="max-width: 100%; border-radius: 8px; box-shadow: 0 4px 12px rgba(0,0,0,0.15);" />\n');
        htmlBuffer.write('</div>\n');
        continue;
      }

      var text = trimmed;
      text = _parseInlineStyles(text);
      htmlBuffer.write('<p style="color: #d2d7e5; font-size: 14px; line-height: 1.8; letter-spacing: 0.8px; margin-bottom: 20px; text-align: justify; text-justify: inter-ideograph;">$text</p>\n');
    }

    if (inList) {
      htmlBuffer.write('</ul>\n');
    }

    htmlBuffer.write('</div>');
    return htmlBuffer.toString();
  }

  /// 解析 HTML 行内粗体、斜体、代码等样式
  static String _parseInlineStyles(String text) {
    var result = text;
    
    // 粗体
    result = result.replaceAllMapped(RegExp(r'\*\*(.*?)\*\*'), (match) {
      final t = match.group(1) ?? '';
      return '<strong style="color: #ffffff; font-weight: bold;">$t</strong>';
    });

    // 行内代码
    result = result.replaceAllMapped(RegExp(r'`([^`]+)`'), (match) {
      final t = match.group(1) ?? '';
      return '<code style="color: #FF9D00; background-color: #14161E; padding: 2px 6px; border-radius: 4px; font-family: monospace; font-size: 12px; border: 1px solid #2E3245;">$t</code>';
    });

    // 链接
    result = result.replaceAllMapped(RegExp(r'\[(.*?)\]\((.*?)\)'), (match) {
      final linkText = match.group(1) ?? '';
      final url = match.group(2) ?? '';
      return '<a href="$url" style="color: #00C9FF; text-decoration: underline;">$linkText</a>';
    });

    return result;
  }

  /// 将 HTML 复制为剪贴板富文本（适配 macOS）
  static Future<void> copyHtmlToClipboard(String htmlContent) async {
    try {
      final base64Html = base64.encode(utf8.encode(htmlContent));
      final swiftScript = '''
import Cocoa
import Foundation

if let base64Data = Data(base64Encoded: "$base64Html"),
   let htmlString = String(data: base64Data, encoding: .utf8) {
    let pb = NSPasteboard.general
    pb.clearContents()
    let htmlType = NSPasteboard.PasteboardType.html
    pb.declareTypes([htmlType, .string], owner: nil)
    pb.setString(htmlString, forType: htmlType)
    pb.setString(htmlString, forType: .string)
}
''';

      final process = await Process.start('swift', ['-']);
      process.stdin.write(swiftScript);
      await process.stdin.close();
      
      final exitCode = await process.exitCode;
      if (exitCode != 0) {
        throw Exception('Native clipboard write failed with code \$exitCode');
      }
    } catch (e) {
      // 回退机制：如果平台不支持或写入失败，则拷贝为普通纯文本 HTML 源码
      await Clipboard.setData(ClipboardData(text: htmlContent));
    }
  }
}
