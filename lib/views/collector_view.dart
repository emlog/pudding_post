import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/collector_provider.dart';
import '../providers/article_provider.dart';
import '../widgets/glass_container.dart';
import '../widgets/custom_button.dart';

/// 采集工作台页面 View
/// 
/// 提供目标 URL 抓取表单，支持切换“单篇采集”与“批量列表采集”模式。拥有实时控制台日志面板与渐变进度条反馈。
class CollectorView extends StatefulWidget {
  const CollectorView({super.key});

  @override
  State<CollectorView> createState() => _CollectorViewState();
}

class _CollectorViewState extends State<CollectorView> {
  final _urlController = TextEditingController();
  final _scrollController = ScrollController();
  
  bool _isListMode = false;
  bool _autoPage = true;
  int _maxPages = 3;

  @override
  void dispose() {
    _urlController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// 自动滚动日志控制台到最底部
  /// 
  /// 保证用户能实时看到最新的一行日志输出。
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  /// 执行采集任务
  /// 
  /// 校验 URL 后，根据当前模式调用单篇采集或列表批量采集。
  Future<void> _startCollection() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      _showSnackBar('请输入需要采集的目标网址 URL！', true);
      return;
    }

    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      _showSnackBar('请输入以 http:// 或 https:// 开头的合法网址！', true);
      return;
    }

    final collector = Provider.of<CollectorProvider>(context, listen: false);
    final articleProvider = Provider.of<ArticleProvider>(context, listen: false);

    collector.clearLogs();

    if (_isListMode) {
      // 开启列表批量采集
      await collector.collectListArticles(
        listUrl: url,
        articleProvider: articleProvider,
        autoPage: _autoPage,
        maxPages: _maxPages,
      );
    } else {
      // 开启单篇采集
      final success = await collector.collectSingleArticle(url, articleProvider);
      if (success) {
        _showSnackBar('单篇文章采集入库成功！可前往内容库查看', false);
      }
    }
  }

  /// 显示 SnackBar 提示
  /// 
  /// 提示用户当前的输入验证或错误情况。
  void _showSnackBar(String message, bool isError) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.teal,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  int _lastLogCount = 0;

  @override
  Widget build(BuildContext context) {
    final collector = Provider.of<CollectorProvider>(context);
    
    // 只有当日志长度真实增加（即新追加日志）时，才自动滚动到底部，防止频繁重绘打断用户的翻阅操作
    if (collector.logs.length > _lastLogCount) {
      _lastLogCount = collector.logs.length;
      _scrollToBottom();
    } else if (collector.logs.isEmpty && _lastLogCount > 0) {
      _lastLogCount = 0;
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 头部标题与副标题
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '智能采集工作台',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '输入目标文章 URL 或列表页 URL，大模型将自动结构化并抓取文章内容',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 主体输入区域卡片
            GlassContainer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 模式选择与输入框
                  Row(
                    children: [
                      // 模式选择 Tab 按钮
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF14161E),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF2E3245)),
                        ),
                        child: Row(
                          children: [
                            _buildModeTab(text: '单篇采集', isSelected: !_isListMode, isLeft: true),
                            _buildModeTab(text: '列表批量采集', isSelected: _isListMode, isLeft: false),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // URL 输入框
                      Expanded(
                        child: TextField(
                          controller: _urlController,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: _isListMode ? '请输入文章列表页 URL...' : '请输入单篇文章详情页 URL...',
                            hintStyle: const TextStyle(color: Color(0xFF4A4E69), fontSize: 13),
                            filled: true,
                            fillColor: const Color(0xFF14161E),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFF2E3245), width: 1),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFF2E3245), width: 1),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFF00C9FF), width: 1.5),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // 列表采集的高级翻页设置
                  if (_isListMode) ...[
                    const SizedBox(height: 16),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF14161E).withOpacity(0.5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF2E3245).withOpacity(0.5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.tune, color: Color(0xFF00C9FF), size: 18),
                          const SizedBox(width: 8),
                          const Text(
                            '自动分页提取设置：',
                            style: TextStyle(color: Colors.white, fontSize: 13),
                          ),
                          const SizedBox(width: 16),
                          Row(
                            children: [
                              const Text('自动向后翻页', style: TextStyle(color: Colors.grey, fontSize: 12)),
                              Checkbox(
                                value: _autoPage,
                                activeColor: const Color(0xFF00C9FF),
                                checkColor: Colors.black,
                                onChanged: (val) {
                                  setState(() {
                                    _autoPage = val ?? true;
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(width: 24),
                          if (_autoPage) ...[
                            const Text('最大翻页数：', style: TextStyle(color: Colors.grey, fontSize: 12)),
                            const SizedBox(width: 8),
                            DropdownButton<int>(
                              value: _maxPages,
                              dropdownColor: const Color(0xFF1E212A),
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              underline: const SizedBox(),
                              items: [1, 2, 3, 5, 10, 15, 20].map((int val) {
                                return DropdownMenuItem<int>(
                                  value: val,
                                  child: Text('$val 页'),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setState(() {
                                    _maxPages = val ?? 3;
                                });
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // 操作按钮
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (collector.isCollecting) ...[
                        CustomButton(
                          text: '停止采集',
                          icon: Icons.stop_circle_outlined,
                          isSecondary: true,
                          onPressed: collector.requestCancel,
                        ),
                        const SizedBox(width: 16),
                      ],
                      CustomButton(
                        text: collector.isCollecting ? '采集处理中...' : '开始执行采集',
                        icon: Icons.rocket_launch,
                        isLoading: collector.isCollecting,
                        onPressed: collector.isCollecting ? null : _startCollection,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 任务进度与控制台日志区
            Expanded(
              child: GlassContainer(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 控制台顶部 Bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: const BoxDecoration(
                        color: Color(0xFF14161E),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.terminal, color: Color(0xFF00C9FF), size: 18),
                              const SizedBox(width: 8),
                              const Text(
                                '采集任务控制台',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              if (collector.isCollecting && collector.currentProcessingUrl.isNotEmpty) ...[
                                const SizedBox(width: 16),
                                SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.cyanAccent),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  constraints: const BoxConstraints(maxWidth: 350),
                                  child: Text(
                                    '正在处理: ${collector.currentProcessingUrl}',
                                    style: const TextStyle(color: Colors.cyanAccent, fontSize: 11),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Row(
                            children: [
                              if (collector.totalTaskCount > 0) ...[
                                Text(
                                  '进度: ${collector.completedTaskCount} / ${collector.totalTaskCount}',
                                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                                ),
                                const SizedBox(width: 16),
                              ],
                              TextButton.icon(
                                onPressed: collector.isCollecting ? null : collector.clearLogs,
                                icon: const Icon(Icons.cleaning_services, size: 14, color: Colors.grey),
                                label: const Text('清空控制台', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // 进度条
                    if (collector.isCollecting)
                      LinearProgressIndicator(
                        value: collector.progress,
                        backgroundColor: const Color(0xFF1E212A),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00C9FF)),
                        minHeight: 3,
                      ),

                    // 日志输出区域
                    Expanded(
                      child: Container(
                        color: const Color(0xFF0C0D12),
                        padding: const EdgeInsets.all(16),
                        child: collector.logs.isEmpty
                            ? const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.terminal_outlined, color: Color(0xFF2E3245), size: 48),
                                    SizedBox(height: 12),
                                    Text(
                                      '控制台暂无日志输出，请输入网址开始采集',
                                      style: TextStyle(color: Color(0xFF4A4E69), fontSize: 13),
                                    ),
                                  ],
                                ),
                              )
                            : SingleChildScrollView(
                                controller: _scrollController,
                                child: SelectableText.rich(
                                  TextSpan(
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 12,
                                      height: 1.5,
                                    ),
                                    children: collector.logs.map((entry) {
                                      return TextSpan(
                                        children: [
                                          TextSpan(
                                            text: '[${entry.timestamp}] ',
                                            style: const TextStyle(color: Colors.grey),
                                          ),
                                          TextSpan(
                                            text: '[${entry.type}] ',
                                            style: TextStyle(
                                              color: _getLogTypeColor(entry.type),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          TextSpan(
                                            text: '${entry.message}\n',
                                            style: const TextStyle(color: Color(0xFFD0D5E0)),
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 模式切换选项按钮
  /// 
  /// 用来切换单篇或批量，包含过渡特效。
  Widget _buildModeTab({
    required String text,
    required bool isSelected,
    required bool isLeft,
  }) {
    return InkWell(
      onTap: () {
        setState(() {
          _isListMode = !isLeft;
        });
      },
      borderRadius: BorderRadius.horizontal(
        left: isLeft ? const Radius.circular(8) : Radius.circular(0),
        right: !isLeft ? const Radius.circular(8) : Radius.circular(0),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2E3245) : Colors.transparent,
          borderRadius: BorderRadius.horizontal(
            left: isLeft ? const Radius.circular(8) : Radius.circular(0),
            right: !isLeft ? const Radius.circular(8) : Radius.circular(0),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFFA0A5C0),
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  /// 获取日志类型的视觉配色
  /// 
  /// 根据 INFO / SUCCESS / WARNING / ERROR 返回相配的原色，强化终端可读性。
  Color _getLogTypeColor(String type) {
    switch (type) {
      case 'SUCCESS':
        return const Color(0xFF92FE9D);
      case 'WARNING':
        return const Color(0xFFFFD200);
      case 'ERROR':
        return const Color(0xFFFA6262);
      case 'INFO':
      default:
        return const Color(0xFF00C9FF);
    }
  }
}
