import 'package:flutter_test/flutter_test.dart';
import 'package:pudding_post/providers/collector_provider.dart';
import 'package:pudding_post/services/extractor_service.dart';

/// 自动化单元测试
/// 
/// 验证自定义的 CollectResult 类的属性以及加法运算符行为，并测试 HTML 列表页判断启发式规则。
void main() {
  test('CollectResult initialization and addition test', () {
    // 初始化测试
    final initialResult = CollectResult();
    expect(initialResult.successCount, 0);
    expect(initialResult.skippedCount, 0);
    expect(initialResult.failedCount, 0);

    // 加法运算符重载测试
    final resultA = CollectResult(successCount: 2, skippedCount: 1, failedCount: 0);
    final resultB = CollectResult(successCount: 1, skippedCount: 3, failedCount: 2);
    
    final combined = resultA + resultB;
    
    expect(combined.successCount, 3);
    expect(combined.skippedCount, 4);
    expect(combined.failedCount, 2);
  });

  test('ExtractorService.isListContent test', () {
    final extractor = ExtractorService();

    // 1. 模拟一个详情页 HTML (含有多个长段落，超链接较少)
    final detailHtml = '''
      <html>
        <body>
          <h1>探索大语言模型的未来发展</h1>
          <p>这是第一个比较长的段落。大语言模型（LLM）是指通过在海量文本数据上进行预训练而获得的具有数十亿或数千亿参数的深度学习网络。它们能够理解人类的日常语言并生成流畅的文章，这在各种自然语言处理场景中展现了极强的通用能力和表现力。</p>
          <p>这是第二个很长的段落。除了自然语言理解和文字处理，当前大模型正在向着多模态的方向进行演进。人们可以通过输入文字生成高质量的图片，甚至生成精美的短视频以及实现逼真的语音合成。这些技术正在潜移默化地改变许多知识密集型行业的生产流程。</p>
          <p>这是第三个长段落。在日常应用开发中，通过与 SQLite 数据库等本地轻量级数据库进行结合，可以方便地将大模型推理出的结构化数据进行持久化存储。比如我们可以利用大模型自动清洗并解析任意网页的正文内容，并自动保存到内容库以供后续的发布 and 编辑。</p>
          <a href="/about">关于我们</a>
          <a href="/contact">联系我们</a>
        </body>
      </html>
    ''';
    expect(extractor.isListContent(detailHtml), isFalse);

    // 2. 模拟一个列表页 HTML (包含大量的超链接，且基本没有长段落)
    final listHtml = '''
      <html>
        <body>
          <h1>最新资讯列表</h1>
          <ul>
            <li><a href="/post/1">首发：AI 智能助手 3.5 版本今日正式开启测试，新架构体验惊艳</a></li>
            <li><a href="/post/2">解析：SQLite 数据库核心调优指南与多线程写入最佳实践分享</a></li>
            <li><a href="/post/3">Flutter 桌面端高难度毛玻璃 UI 混合渐变背景实现方案全解析</a></li>
            <li><a href="/post/4">深度好文：如何利用大语言模型自动提取复杂 HTML 正文结构</a></li>
            <li><a href="/post/5">每周周刊第 88 期：技术人的自我迭代与副业探索之路</a></li>
            <li><a href="/post/6">突发：知名开源编辑器全新推出极速编译版本，首发适配 Mac</a></li>
            <li><a href="/post/7">探讨：未来的 web3 与 AI 技术混合应用会给我们带来哪些颠覆</a></li>
            <li><a href="/post/8">教程：从零开始使用 Dio 抓取目标站点 HTML 的防反爬高级技巧</a></li>
            <li><a href="/post/9">开源：一套超高颜值的 Flutter 现代化暗黑风格主题包推荐</a></li>
            <li><a href="/post/10">实战：使用 Provider 优雅管理复杂桌面端软件的状态生命周期</a></li>
            <li><a href="/post/11">新闻：首届国际智能体开发者大会今日在硅谷正式开幕</a></li>
            <li><a href="/post/12">专访：前沿大模型独角兽团队的技术成长史与商业化探索</a></li>
            <li><a href="/post/13">分享：十个能极大提升程序员工作幸福感的桌面小物件推荐</a></li>
            <li><a href="/post/14">指南：如何为你的 Emlog 或 WordPress 博客对接自动化采集插件</a></li>
            <li><a href="/post/15">回顾：大模型在过去三年中取得的技术突破及未来面临的挑战</a></li>
            <li><a href="/post/16">公告：关于社区版块部分敏感词拦截策略更新及违规账号处罚公告</a></li>
          </ul>
        </body>
      </html>
    ''';
    expect(extractor.isListContent(listHtml), isTrue);
  });
}
