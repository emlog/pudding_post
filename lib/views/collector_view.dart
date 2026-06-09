import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/collector_provider.dart';
import '../providers/article_provider.dart';
import '../providers/settings_provider.dart';
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
  
  bool _autoPage = true;
  int _maxPages = 3;

  // 采集模式：0 = 单篇采集，1 = 列表批量采集，2 = 网址分组批量采集
  int _collectMode = 0;
  String? _selectedGroupId;

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
  /// 开始采集任务
  /// 
  /// 根据当前模式调用单篇采集、列表批量采集或分组去重批量采集。
  Future<void> _startCollection() async {
    final collector = Provider.of<CollectorProvider>(context, listen: false);
    final articleProvider = Provider.of<ArticleProvider>(context, listen: false);

    collector.clearLogs();

    if (_collectMode == 2) {
      // 分组采集模式
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      final groups = settings.urlGroups;
      if (groups.isEmpty || _selectedGroupId == null) {
        _showSnackBar('请先选择或管理网址分组！', true);
        return;
      }
      
      final currentGroup = groups.firstWhere((g) => g.id == _selectedGroupId);
      if (currentGroup.urls.isEmpty) {
        _showSnackBar('选中的分组下没有任何采集网址！', true);
        return;
      }

      // 开启分组去重批量采集
      await collector.collectGroupUrls(
        urls: currentGroup.urls,
        articleProvider: articleProvider,
      );
    } else if (_collectMode == 1) {
      // 列表批量采集模式
      final url = _urlController.text.trim();
      if (url.isEmpty) {
        _showSnackBar('请输入需要采集的目标网址 URL！', true);
        return;
      }
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        _showSnackBar('请输入以 http:// 或 https:// 开头的合法网址！', true);
        return;
      }
      await collector.collectListArticles(
        listUrl: url,
        articleProvider: articleProvider,
        autoPage: _autoPage,
        maxPages: _maxPages,
      );
    } else {
      // 单篇采集模式
      final url = _urlController.text.trim();
      if (url.isEmpty) {
        _showSnackBar('请输入需要采集的目标网址 URL！', true);
        return;
      }
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        _showSnackBar('请输入以 http:// 或 https:// 开头的合法网址！', true);
        return;
      }
      final result = await collector.collectSingleArticle(url, articleProvider);
      if (result.successCount > 0) {
        _showSnackBar('单篇文章采集入库成功！可前往内容库查看', false);
      } else if (result.skippedCount > 0) {
        _showSnackBar('该网址已在内容库中存在，跳过采集', true);
      } else {
        _showSnackBar('单篇采集失败，请查看日志获取详细错误信息', true);
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
              ],
            ),
            const SizedBox(height: 24),

            // 主体输入区域卡片
            GlassContainer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 模式选择与输入区
                  Row(
                    children: [
                      // 模式选择 Tab 按钮
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF14161E),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF2E3245)),
                        ),
                        child: Row(
                          children: [
                            _buildModeTab(text: '单篇采集', mode: 0),
                            const SizedBox(width: 4),
                            _buildModeTab(text: '列表采集', mode: 1),
                            const SizedBox(width: 4),
                            _buildModeTab(text: '分组采集', mode: 2),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // URL 输入框或分组选择下拉框
                      if (_collectMode == 2) ...[
                        // 分组选择下拉框
                        Expanded(
                          child: Consumer<SettingsProvider>(
                            builder: (context, settings, child) {
                              final groups = settings.urlGroups;
                              if (groups.isEmpty) {
                                return Container(
                                  height: 48,
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF14161E),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFF2E3245)),
                                  ),
                                  alignment: Alignment.centerLeft,
                                  child: const Text('暂无网址分组，请先创建分组', style: TextStyle(color: Colors.grey, fontSize: 13)),
                                );
                              }
                              
                              if (_selectedGroupId == null || !groups.any((g) => g.id == _selectedGroupId)) {
                                _selectedGroupId = groups.first.id;
                              }

                              return Container(
                                height: 48,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF14161E),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFF2E3245)),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selectedGroupId,
                                    dropdownColor: const Color(0xFF1E212A),
                                    style: const TextStyle(color: Colors.white, fontSize: 14),
                                    isExpanded: true,
                                    icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
                                    items: groups.map((g) {
                                      return DropdownMenuItem<String>(
                                        value: g.id,
                                        child: Text('${g.name} (${g.urls.length} 个网址)'),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      setState(() {
                                        _selectedGroupId = val;
                                      });
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        // 管理分组按钮
                        CustomButton(
                          text: '管理分组',
                          icon: Icons.folder_open,
                          isSecondary: true,
                          onPressed: _showGroupManagerDialog,
                        ),
                      ] else ...[
                        // URL 输入框
                        Expanded(
                          child: TextField(
                            controller: _urlController,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: _collectMode == 1 ? '请输入文章列表页 URL...' : '请输入单篇文章详情页 URL...',
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
                    ],
                  ),

                  // 列表采集的高级翻页设置
                  if (_collectMode == 1) ...[
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
  /// 用来切换单篇、列表或分组模式，包含过渡效果。
  Widget _buildModeTab({
    required String text,
    required int mode,
  }) {
    final isSelected = _collectMode == mode;
    return InkWell(
      onTap: () {
        setState(() {
          _collectMode = mode;
        });
      },
      mouseCursor: SystemMouseCursors.click,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2E3245) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
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

  /// 打开网址采集分组管理对话框
  /// 
  /// 承载分组的 CRUD 以及分组内 URL 的 CRUD，采用双栏暗黑拟物化风格设计。
  void _showGroupManagerDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final newGroupController = TextEditingController();
        final newUrlController = TextEditingController();
        String? activeGroupId;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final settings = Provider.of<SettingsProvider>(context);
            final groups = settings.urlGroups;

            // 初始化活动分组 ID
            if (groups.isNotEmpty) {
              if (activeGroupId == null || !groups.any((g) => g.id == activeGroupId)) {
                activeGroupId = groups.first.id;
              }
            } else {
              activeGroupId = null;
            }

            final activeGroup = activeGroupId != null
                ? groups.firstWhere((g) => g.id == activeGroupId)
                : null;

            const double elementHeight = 38.0;

            return Dialog(
              backgroundColor: const Color(0xFF161922),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFF2E3245), width: 1),
              ),
              child: Container(
                width: 720,
                height: 520,
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 18,
                              decoration: BoxDecoration(
                                color: const Color(0xFF00C9FF),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              '网址采集分组管理',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Color(0xFFA0A5C0), size: 20),
                          splashRadius: 20,
                          onPressed: () => Navigator.of(context).pop(),
                        )
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: Color(0xFF25293A), height: 1),
                    const SizedBox(height: 20),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 左栏：分组管理
                          Expanded(
                            flex: 2,
                            child: Container(
                              decoration: const BoxDecoration(
                                border: Border(right: BorderSide(color: Color(0xFF25293A), width: 1)),
                              ),
                              padding: const EdgeInsets.only(right: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '网址分组',
                                    style: TextStyle(
                                      color: Color(0xFFA0A5C0),
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: Focus(
                                          onFocusChange: (hasFocus) => setDialogState(() {}),
                                          child: Builder(
                                            builder: (context) {
                                              final hasFocus = Focus.of(context).hasFocus;
                                              return AnimatedContainer(
                                                duration: const Duration(milliseconds: 150),
                                                height: elementHeight,
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF0F111A),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: hasFocus ? const Color(0xFF00C9FF) : const Color(0xFF2E3245),
                                                    width: hasFocus ? 1.5 : 1.0,
                                                  ),
                                                  boxShadow: hasFocus
                                                      ? [
                                                          BoxShadow(
                                                            color: const Color(0xFF00C9FF).withOpacity(0.15),
                                                            blurRadius: 6,
                                                            spreadRadius: 0,
                                                          )
                                                        ]
                                                      : [],
                                                ),
                                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                                alignment: Alignment.centerLeft,
                                                child: TextField(
                                                  controller: newGroupController,
                                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                                  decoration: const InputDecoration(
                                                    isCollapsed: true,
                                                    hintText: '输入新分组名称...',
                                                    hintStyle: TextStyle(color: Color(0xFF4A4E69), fontSize: 12),
                                                    border: InputBorder.none,
                                                  ),
                                                  onSubmitted: (_) async {
                                                    final name = newGroupController.text.trim();
                                                    if (name.isNotEmpty) {
                                                      final newGroup = UrlGroup(
                                                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                                                        name: name,
                                                        urls: [],
                                                        createdAt: DateTime.now().toIso8601String(),
                                                      );
                                                      await settings.addUrlGroup(newGroup);
                                                      newGroupController.clear();
                                                      setDialogState(() {
                                                        activeGroupId = newGroup.id;
                                                      });
                                                    }
                                                  },
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () async {
                                            final name = newGroupController.text.trim();
                                            if (name.isNotEmpty) {
                                              final newGroup = UrlGroup(
                                                id: DateTime.now().millisecondsSinceEpoch.toString(),
                                                name: name,
                                                urls: [],
                                                createdAt: DateTime.now().toIso8601String(),
                                              );
                                              await settings.addUrlGroup(newGroup);
                                              newGroupController.clear();
                                              setDialogState(() {
                                                activeGroupId = newGroup.id;
                                              });
                                            }
                                          },
                                          borderRadius: BorderRadius.circular(8),
                                          child: Container(
                                            width: elementHeight,
                                            height: elementHeight,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF0F111A),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: const Color(0xFF00C9FF), width: 1.2),
                                            ),
                                            child: const Icon(Icons.add_rounded, color: Color(0xFF00C9FF), size: 20),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Expanded(
                                    child: groups.isEmpty
                                        ? const Center(
                                            child: Text(
                                              '暂无分组',
                                              style: TextStyle(color: Color(0xFF4A4E69), fontSize: 12),
                                            ),
                                          )
                                        : ListView.builder(
                                            itemCount: groups.length,
                                            itemBuilder: (context, index) {
                                              final g = groups[index];
                                              final isSelected = g.id == activeGroupId;
                                              return Padding(
                                                padding: const EdgeInsets.only(bottom: 6),
                                                child: Material(
                                                  color: Colors.transparent,
                                                  child: InkWell(
                                                    onTap: () {
                                                      setDialogState(() {
                                                        activeGroupId = g.id;
                                                      });
                                                    },
                                                    borderRadius: BorderRadius.circular(8),
                                                    child: AnimatedContainer(
                                                      duration: const Duration(milliseconds: 150),
                                                      height: 38,
                                                      padding: const EdgeInsets.symmetric(horizontal: 10),
                                                      decoration: BoxDecoration(
                                                        color: isSelected ? const Color(0xFF25293A) : Colors.transparent,
                                                        borderRadius: BorderRadius.circular(8),
                                                        border: Border.all(
                                                          color: isSelected ? const Color(0xFF00C9FF).withOpacity(0.3) : Colors.transparent,
                                                          width: 1.0,
                                                        ),
                                                      ),
                                                      child: Row(
                                                        children: [
                                                          Icon(
                                                            Icons.folder_open_rounded,
                                                            size: 16,
                                                            color: isSelected ? const Color(0xFF00C9FF) : const Color(0xFFA0A5C0),
                                                          ),
                                                          const SizedBox(width: 8),
                                                          Expanded(
                                                            child: Text(
                                                              g.name,
                                                              style: TextStyle(
                                                                color: isSelected ? Colors.white : const Color(0xFFA0A5C0),
                                                                fontSize: 13,
                                                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                                              ),
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                          ),
                                                          IconButton(
                                                            icon: const Icon(Icons.delete_outline_rounded, size: 16),
                                                            color: const Color(0xFFFF5252).withOpacity(0.8),
                                                            padding: EdgeInsets.zero,
                                                            constraints: const BoxConstraints(),
                                                            splashRadius: 16,
                                                            onPressed: () async {
                                                              await settings.deleteUrlGroup(g.id);
                                                              setDialogState(() {});
                                                            },
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // 右栏：网址管理
                          Expanded(
                            flex: 3,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 16),
                              child: activeGroup == null
                                  ? const Center(
                                      child: Text(
                                        '请先创建并选择一个分组',
                                        style: TextStyle(color: Color(0xFF4A4E69), fontSize: 13),
                                      ),
                                    )
                                  : Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.edit_note_rounded, color: Color(0xFFA0A5C0), size: 16),
                                            const SizedBox(width: 6),
                                            Text(
                                              '管理分组: ${activeGroup.name}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            Expanded(
                                              child: Focus(
                                                onFocusChange: (hasFocus) => setDialogState(() {}),
                                                child: Builder(
                                                  builder: (context) {
                                                    final hasFocus = Focus.of(context).hasFocus;
                                                    return AnimatedContainer(
                                                      duration: const Duration(milliseconds: 150),
                                                      height: elementHeight,
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFF0F111A),
                                                        borderRadius: BorderRadius.circular(8),
                                                        border: Border.all(
                                                          color: hasFocus ? const Color(0xFF00C9FF) : const Color(0xFF2E3245),
                                                          width: hasFocus ? 1.5 : 1.0,
                                                        ),
                                                        boxShadow: hasFocus
                                                            ? [
                                                                BoxShadow(
                                                                  color: const Color(0xFF00C9FF).withOpacity(0.15),
                                                                  blurRadius: 6,
                                                                  spreadRadius: 0,
                                                                )
                                                              ]
                                                            : [],
                                                      ),
                                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                                      alignment: Alignment.centerLeft,
                                                      child: TextField(
                                                        controller: newUrlController,
                                                        style: const TextStyle(color: Colors.white, fontSize: 13),
                                                        decoration: const InputDecoration(
                                                          isCollapsed: true,
                                                          hintText: '输入添加的目标网址 URL...',
                                                          hintStyle: TextStyle(color: Color(0xFF4A4E69), fontSize: 12),
                                                          border: InputBorder.none,
                                                        ),
                                                        onSubmitted: (_) async {
                                                          final url = newUrlController.text.trim();
                                                          if (url.isNotEmpty && (url.startsWith('http://') || url.startsWith('https://'))) {
                                                            await settings.addUrlToGroup(activeGroupId!, url);
                                                            newUrlController.clear();
                                                            setDialogState(() {});
                                                          }
                                                        },
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                onTap: () async {
                                                  final url = newUrlController.text.trim();
                                                  if (url.isNotEmpty && (url.startsWith('http://') || url.startsWith('https://'))) {
                                                    await settings.addUrlToGroup(activeGroupId!, url);
                                                    newUrlController.clear();
                                                    setDialogState(() {});
                                                  }
                                                },
                                                borderRadius: BorderRadius.circular(8),
                                                child: Ink(
                                                  decoration: BoxDecoration(
                                                    gradient: const LinearGradient(
                                                      colors: [Color(0xFF00C9FF), Color(0xFF00B0FF)],
                                                      begin: Alignment.topLeft,
                                                      end: Alignment.bottomRight,
                                                    ),
                                                    borderRadius: BorderRadius.circular(8),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: const Color(0xFF00C9FF).withOpacity(0.2),
                                                        blurRadius: 6,
                                                        offset: const Offset(0, 2),
                                                      )
                                                    ],
                                                  ),
                                                  child: Container(
                                                    height: elementHeight,
                                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                                    alignment: Alignment.center,
                                                    child: const Text(
                                                      '添加',
                                                      style: TextStyle(
                                                        color: Color(0xFF0F111A),
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.bold,
                                                        letterSpacing: 0.5,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        Expanded(
                                          child: activeGroup.urls.isEmpty
                                              ? const Center(
                                                  child: Text(
                                                    '该分组下暂无网址，请在上方添加',
                                                    style: TextStyle(color: Color(0xFF4A4E69), fontSize: 12),
                                                  ),
                                                )
                                              : ListView.builder(
                                                  itemCount: activeGroup.urls.length,
                                                  itemBuilder: (context, index) {
                                                    final u = activeGroup.urls[index];
                                                    return Container(
                                                      margin: const EdgeInsets.only(bottom: 6),
                                                      height: 38,
                                                      padding: const EdgeInsets.symmetric(horizontal: 10),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFF0F111A),
                                                        borderRadius: BorderRadius.circular(8),
                                                        border: Border.all(color: const Color(0xFF25293A)),
                                                      ),
                                                      child: Row(
                                                        children: [
                                                          const Icon(
                                                            Icons.link_rounded,
                                                            size: 14,
                                                            color: Color(0xFF00C9FF),
                                                          ),
                                                          const SizedBox(width: 8),
                                                          Expanded(
                                                            child: Text(
                                                              u,
                                                              style: const TextStyle(
                                                                color: Color(0xFFCFD4E6),
                                                                fontSize: 12,
                                                              ),
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                          ),
                                                          const SizedBox(width: 8),
                                                          IconButton(
                                                            icon: const Icon(Icons.copy_rounded, size: 15),
                                                            color: const Color(0xFF00C9FF).withOpacity(0.8),
                                                            padding: EdgeInsets.zero,
                                                            constraints: const BoxConstraints(),
                                                            splashRadius: 14,
                                                            tooltip: '复制网址',
                                                            onPressed: () async {
                                                              await Clipboard.setData(ClipboardData(text: u));
                                                              if (!context.mounted) return;
                                                              ScaffoldMessenger.of(context).showSnackBar(
                                                                const SnackBar(
                                                                  content: Text('已复制网址到剪贴板'),
                                                                  duration: Duration(seconds: 1),
                                                                ),
                                                              );
                                                            },
                                                          ),
                                                          const SizedBox(width: 10),
                                                          IconButton(
                                                            icon: const Icon(Icons.remove_circle_outline_rounded, size: 15),
                                                            color: const Color(0xFFFF5252).withOpacity(0.8),
                                                            padding: EdgeInsets.zero,
                                                            constraints: const BoxConstraints(),
                                                            splashRadius: 14,
                                                            tooltip: '删除网址',
                                                            onPressed: () async {
                                                              await settings.removeUrlFromGroup(activeGroupId!, u);
                                                              setDialogState(() {});
                                                            },
                                                          )
                                                        ],
                                                      ),
                                                    );
                                                  },
                                                ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25293A),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: const BorderSide(color: Color(0xFF2D3142)),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text(
                            '关闭',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      setState(() {});
    });
  }
}
