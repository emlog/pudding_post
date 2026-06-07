import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/article.dart';
import '../providers/article_provider.dart';
import '../widgets/glass_container.dart';
import '../widgets/custom_button.dart';

/// 内容库页面 View
/// 
/// 展示已采集的文章列表，支持模糊检索、文章在线 Markdown 编辑、单篇物理删除及发布至 emlog 系统的交互操作。
class LibraryView extends StatefulWidget {
  const LibraryView({super.key});

  @override
  State<LibraryView> createState() => _LibraryViewState();
}

class _LibraryViewState extends State<LibraryView> {
  final _searchController = TextEditingController();
  Article? _selectedArticle;
  
  // 编辑模式相关控制器
  bool _isEditing = false;
  late TextEditingController _editTitleController;
  late TextEditingController _editCoverController;
  late TextEditingController _editContentController;

  // 批量操作相关的状态
  bool _isBatchMode = false;
  final Set<int> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _editTitleController = TextEditingController();
    _editCoverController = TextEditingController();
    _editContentController = TextEditingController();
    
    // 页面加载时自动从数据库更新文章列表
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ArticleProvider>(context, listen: false).loadArticles();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _editTitleController.dispose();
    _editCoverController.dispose();
    _editContentController.dispose();
    super.dispose();
  }

  /// 在系统默认浏览器中打开指定链接
  /// 
  /// 用于用户点击“查看原文”或“访问已发布文章”时的页面跳转。
  Future<void> _launchUrl(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.parse(url);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        _showSnackBar('无法打开链接: $url', true);
      }
    } catch (e) {
      _showSnackBar('链接跳转出错: $e', true);
    }
  }

  /// 显示操作状态反馈 SnackBar
  /// 
  /// 弹出通知气泡以反馈成功或错误状态。
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

  /// 进入或初始化编辑模式
  /// 
  /// 将选中文章的各项属性值同步到 TextEditingController 中，并切换编辑状态。
  void _startEditing() {
    if (_selectedArticle == null) return;
    setState(() {
      _editTitleController.text = _selectedArticle!.title;
      _editCoverController.text = _selectedArticle!.coverUrl;
      _editContentController.text = _selectedArticle!.content;
      _isEditing = true;
    });
  }

  /// 退出编辑模式且不保存修改
  /// 
  /// 重置编辑控制器状态。
  void _cancelEditing() {
    setState(() {
      _isEditing = false;
    });
  }

  /// 保存编辑后的文章修改
  /// 
  /// 读取控制器值生成新的 Article 实例，通过 ArticleProvider 更新数据库。
  Future<void> _saveEditing() async {
    if (_selectedArticle == null) return;
    
    final updated = _selectedArticle!.copyWith(
      title: _editTitleController.text.trim(),
      coverUrl: _editCoverController.text.trim(),
      content: _editContentController.text,
    );

    final provider = Provider.of<ArticleProvider>(context, listen: false);
    await provider.updateArticle(updated);

    setState(() {
      _selectedArticle = updated;
      _isEditing = false;
    });

    _showSnackBar('文章修改保存成功！', false);
  }

  /// 删除当前选中的文章
  /// 
  /// 双重确认后，调用数据库物理删除该文章记录，并清空当前选中项。
  Future<void> _deleteSelectedArticle() async {
    if (_selectedArticle == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E212A),
        title: const Text('删除文章确认', style: TextStyle(color: Colors.white)),
        content: const Text('确定要删除这篇已采集的文章吗？此操作无法撤销。', style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确定删除', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final id = _selectedArticle!.id!;
      final provider = Provider.of<ArticleProvider>(context, listen: false);
      await provider.deleteArticle(id);
      
      if (!mounted) return;
      setState(() {
        _selectedArticle = null;
        _isEditing = false;
      });
      _showSnackBar('文章已成功删除！', false);
    }
  }

  /// 弹出 emlog 发布对话框
  /// 
  /// 唤醒分类拉取，让用户选择要发布的 emlog 栏目，开始执行发布并将结果反馈至界面。
  Future<void> _showPublishDialog() async {
    if (_selectedArticle == null) return;

    final provider = Provider.of<ArticleProvider>(context, listen: false);

    // 触发异步拉取分类
    try {
      await provider.loadCategories();
    } catch (e) {
      _showSnackBar('无法读取博客分类列表，请检查博客配置: $e', true);
      return;
    }

    if (!mounted) return;

    // 弹出毛玻璃弹窗
    String? selectedCategoryId;
    if (provider.categories.isNotEmpty) {
      selectedCategoryId = provider.categories.first['id']?.toString();
    }

    await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final providerWatch = Provider.of<ArticleProvider>(context);
            final hasCategories = providerWatch.categories.isNotEmpty;

            return AlertDialog(
              backgroundColor: const Color(0xFF191C24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.rocket_launch, color: Color(0xFF00C9FF), size: 20),
                  SizedBox(width: 8),
                  Text('发布文章到 Emlog', style: TextStyle(color: Colors.white, fontSize: 16)),
                ],
              ),
              content: SizedBox(
                width: 320,
                child: providerWatch.isLoadingCategories
                    ? const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00C9FF))),
                          SizedBox(height: 16),
                          Text('正在拉取博客分类列表中...', style: TextStyle(color: Colors.grey, fontSize: 13)),
                        ],
                      )
                    : !hasCategories
                        ? const Text('没有获取到可用分类，请在设置中先测试 Emlog 连接状态。', style: TextStyle(color: Colors.redAccent))
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('选择博客发布栏目/分类：', style: TextStyle(color: Colors.grey, fontSize: 13)),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0E1015),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF2E3245)),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: selectedCategoryId,
                                    dropdownColor: const Color(0xFF191C24),
                                    isExpanded: true,
                                    style: const TextStyle(color: Colors.white, fontSize: 14),
                                    items: providerWatch.categories.map((cat) {
                                      return DropdownMenuItem<String>(
                                        value: cat['id']?.toString(),
                                        child: Text(cat['name']?.toString() ?? '未命名分类'),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      setDialogState(() {
                                        selectedCategoryId = val;
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('取消', style: TextStyle(color: Colors.grey)),
                ),
                if (hasCategories && !providerWatch.isLoadingCategories)
                  TextButton(
                    onPressed: () async {
                      if (selectedCategoryId == null) return;
                      // 启动发布 Loading 并在发布结束后关闭 Dialog
                      try {
                        Navigator.of(context).pop(true); // 返回需要执行发布
                        await provider.publishArticle(_selectedArticle!.id!, selectedCategoryId!);
                        _showSnackBar('文章发布成功！已同步状态', false);
                        // 更新右侧选中的文章渲染状态
                        setState(() {
                          _selectedArticle = provider.allArticles.firstWhere((e) => e.id == _selectedArticle!.id);
                        });
                      } catch (e) {
                        _showSnackBar('发布出错: $e', true);
                      }
                    },
                    child: const Text('立即发布', style: TextStyle(color: Color(0xFF00C9FF))),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  /// 批量发布选中文章至 emlog
  /// 
  /// 获取 emlog 分类列表并弹出精美 Dialog。确认后循环执行发布任务。
  Future<void> _showBatchPublishDialog() async {
    if (_selectedIds.isEmpty) {
      _showSnackBar('请先在列表中勾选要发布的文章！', true);
      return;
    }

    final provider = Provider.of<ArticleProvider>(context, listen: false);

    try {
      await provider.loadCategories();
    } catch (e) {
      _showSnackBar('无法读取博客分类列表: $e', true);
      return;
    }

    if (!mounted) return;

    String? selectedCategoryId;
    if (provider.categories.isNotEmpty) {
      selectedCategoryId = provider.categories.first['id']?.toString();
    }

    await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final providerWatch = Provider.of<ArticleProvider>(context);
            final hasCategories = providerWatch.categories.isNotEmpty;

            return AlertDialog(
              backgroundColor: const Color(0xFF191C24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.rocket_launch, color: Color(0xFF00C9FF), size: 20),
                  const SizedBox(width: 8),
                  Text('批量发布文章到 Emlog (已选 ${_selectedIds.length} 篇)', style: const TextStyle(color: Colors.white, fontSize: 16)),
                ],
              ),
              content: SizedBox(
                width: 320,
                child: providerWatch.isLoadingCategories
                    ? const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00C9FF))),
                          SizedBox(height: 16),
                          Text('正在拉取博客分类列表中...', style: TextStyle(color: Colors.grey, fontSize: 13)),
                        ],
                      )
                    : !hasCategories
                        ? const Text('没有获取到可用分类，请在设置中先测试 Emlog 连接状态。', style: TextStyle(color: Colors.redAccent))
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('选择批量发布到的博客分类：', style: TextStyle(color: Colors.grey, fontSize: 13)),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0E1015),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF2E3245)),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: selectedCategoryId,
                                    dropdownColor: const Color(0xFF191C24),
                                    isExpanded: true,
                                    style: const TextStyle(color: Colors.white, fontSize: 14),
                                    items: providerWatch.categories.map((cat) {
                                      return DropdownMenuItem<String>(
                                        value: cat['id']?.toString(),
                                        child: Text(cat['name']?.toString() ?? '未命名分类'),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      setDialogState(() {
                                        selectedCategoryId = val;
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('取消', style: TextStyle(color: Colors.grey)),
                ),
                if (hasCategories && !providerWatch.isLoadingCategories)
                  TextButton(
                    onPressed: () async {
                      if (selectedCategoryId == null) return;
                      Navigator.of(context).pop(true);
                      _showSnackBar('正在批量推送文章，请稍候...', false);
                      
                      final results = await provider.batchPublishArticles(
                        _selectedIds.toList(),
                        selectedCategoryId!,
                      );
                      
                      int successCount = 0;
                      int failCount = 0;
                      results.forEach((id, err) {
                        if (err.isEmpty) {
                          successCount++;
                        } else {
                          failCount++;
                        }
                      });

                      _showSnackBar('批量发布完成！成功 $successCount 篇，失败 $failCount 篇。', false);
                      
                      setState(() {
                        _selectedIds.clear();
                        _isBatchMode = false;
                        if (_selectedArticle != null) {
                          try {
                            _selectedArticle = provider.allArticles.firstWhere((e) => e.id == _selectedArticle!.id);
                          } catch (_) {}
                        }
                      });
                    },
                    child: const Text('立即批量发布', style: TextStyle(color: Color(0xFF00C9FF))),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  /// 批量删除选中的文章
  /// 
  /// 二次弹窗确认后循环物理删除，并退出批量选择模式。
  Future<void> _batchDeleteArticles() async {
    if (_selectedIds.isEmpty) {
      _showSnackBar('请先在列表中勾选要删除的文章！', true);
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E212A),
        title: const Text('确认批量删除', style: TextStyle(color: Colors.white)),
        content: Text('确认要彻底删除这 ${_selectedIds.length} 篇文章吗？此操作无法撤销。', style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确定', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final provider = Provider.of<ArticleProvider>(context, listen: false);
      for (var id in _selectedIds.toList()) {
        await provider.deleteArticle(id);
      }
      
      setState(() {
        _selectedIds.clear();
        _isBatchMode = false;
        _selectedArticle = null;
        _isEditing = false;
      });
      
      _showSnackBar('选中的文章已成功批量删除！', false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ArticleProvider>(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 左半栏：文章列表
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 头部标题与清空
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          _isBatchMode ? '批量选择中 (${_selectedIds.length})' : '采集内容库',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Row(
                        children: [
                          if (provider.allArticles.isNotEmpty) ...[
                            if (!_isBatchMode) ...[
                              TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _isBatchMode = true;
                                    _selectedIds.clear();
                                  });
                                },
                                icon: const Icon(Icons.checklist, color: Colors.cyanAccent, size: 14),
                                label: const Text('批量模式', style: TextStyle(color: Colors.cyanAccent, fontSize: 12)),
                              ),
                              const SizedBox(width: 8),
                              TextButton.icon(
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      backgroundColor: const Color(0xFF1E212A),
                                      title: const Text('确认清空库', style: TextStyle(color: Colors.white)),
                                      content: const Text('这将会删除本地数据库中的所有文章，是否确认？', style: TextStyle(color: Colors.grey)),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.of(context).pop(false),
                                          child: const Text('取消', style: TextStyle(color: Colors.grey)),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.of(context).pop(true),
                                          child: const Text('一键清空', style: TextStyle(color: Colors.redAccent)),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    await provider.clearAllArticles();
                                    setState(() {
                                      _selectedArticle = null;
                                      _isEditing = false;
                                    });
                                    _showSnackBar('所有文章已从本地库中清空', false);
                                  }
                                },
                                icon: const Icon(Icons.delete_sweep, color: Colors.grey, size: 14),
                                label: const Text('清空库', style: TextStyle(color: Colors.grey, fontSize: 11)),
                              ),
                            ] else ...[
                              TextButton(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () {
                                  final allIds = provider.articles.map((e) => e.id!).toList();
                                  setState(() {
                                    if (_selectedIds.length == allIds.length) {
                                      _selectedIds.clear();
                                    } else {
                                      _selectedIds.addAll(allIds);
                                    }
                                  });
                                },
                                child: Text(
                                  _selectedIds.length == provider.articles.length ? '取消全选' : '全选',
                                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                                ),
                              ),
                              const SizedBox(width: 4),
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: _showBatchPublishDialog,
                                icon: const Icon(Icons.rocket_launch, color: Color(0xFF00C9FF), size: 14),
                                label: const Text('发布', style: TextStyle(color: Color(0xFF00C9FF), fontSize: 11)),
                              ),
                              const SizedBox(width: 4),
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: _batchDeleteArticles,
                                icon: const Icon(Icons.delete_outline, color: Color(0xFFFA6262), size: 14),
                                label: const Text('删除', style: TextStyle(color: Color(0xFFFA6262), fontSize: 11)),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                tooltip: '退出批量',
                                icon: const Icon(Icons.close, color: Colors.grey, size: 14),
                                onPressed: () {
                                  setState(() {
                                    _isBatchMode = false;
                                    _selectedIds.clear();
                                  });
                                },
                              ),
                            ],
                          ],
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 搜索栏
                  TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    onChanged: provider.searchArticles,
                    decoration: InputDecoration(
                      hintText: '按标题或来源 URL 搜索...',
                      hintStyle: const TextStyle(color: Color(0xFF4A4E69), fontSize: 12),
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF4A4E69), size: 18),
                      filled: true,
                      fillColor: const Color(0xFF14161E),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                        borderSide: const BorderSide(color: Color(0xFF00C9FF), width: 1.2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 文章列表
                  Expanded(
                    child: provider.isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00C9FF)),
                            ),
                          )
                        : provider.articles.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.folder_open_outlined, color: const Color(0xFF2E3245), size: 48),
                                    const SizedBox(height: 12),
                                    Text(
                                      _searchController.text.isNotEmpty ? '没有搜索到相关文章' : '暂无采集文章，请前往工作台采集',
                                      style: const TextStyle(color: Color(0xFF4A4E69), fontSize: 12),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                itemCount: provider.articles.length,
                                itemBuilder: (context, index) {
                                  final article = provider.articles[index];
                                  final isSelected = _selectedArticle?.id == article.id;

                                  // 从 URL 中解析简短的 Host 域名显示
                                  String host = '';
                                  try {
                                    host = Uri.parse(article.sourceUrl).host;
                                  } catch (_) {}

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12.0),
                                    child: MouseRegion(
                                      cursor: SystemMouseCursors.click,
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            if (_isBatchMode) {
                                              final id = article.id!;
                                              if (_selectedIds.contains(id)) {
                                                _selectedIds.remove(id);
                                              } else {
                                                _selectedIds.add(id);
                                              }
                                            } else {
                                              _selectedArticle = article;
                                              _isEditing = false;
                                            }
                                          });
                                        },
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 200),
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? const Color(0xFF2E3245).withOpacity(0.5)
                                                : const Color(0xFF1E212A).withOpacity(0.3),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: isSelected
                                                  ? const Color(0xFF00C9FF)
                                                  : const Color(0xFF2E3245).withOpacity(0.5),
                                              width: isSelected ? 1.5 : 1,
                                            ),
                                          ),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              if (_isBatchMode) ...[
                                                Checkbox(
                                                  value: _selectedIds.contains(article.id),
                                                  activeColor: const Color(0xFF00C9FF),
                                                  checkColor: Colors.black,
                                                  onChanged: (val) {
                                                    setState(() {
                                                      final id = article.id!;
                                                      if (val == true) {
                                                        _selectedIds.add(id);
                                                      } else {
                                                        _selectedIds.remove(id);
                                                      }
                                                    });
                                                  },
                                                ),
                                                const SizedBox(width: 8),
                                              ],
                                              // 封面图缩略图
                                              if (article.coverUrl.isNotEmpty) ...[
                                                ClipRRect(
                                                  borderRadius: BorderRadius.circular(6),
                                                  child: Image.network(
                                                    article.coverUrl,
                                                    width: 60,
                                                    height: 60,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (c, e, s) => Container(
                                                      width: 60,
                                                      height: 60,
                                                      color: const Color(0xFF0F1116),
                                                      child: const Icon(Icons.image_not_supported_outlined, color: Colors.grey, size: 18),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                              ],
                                              // 文章基础信息
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      article.title,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 13,
                                                      ),
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        Expanded(
                                                          child: Text(
                                                            host.isNotEmpty ? host : '未知来源',
                                                            style: const TextStyle(color: Colors.grey, fontSize: 11),
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                        Text(
                                                          article.createdAt.substring(5, 16), // 显示 MM-dd HH:mm
                                                          style: const TextStyle(color: Colors.grey, fontSize: 11),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 6),
                                                    // 发布状态小标签
                                                    Row(
                                                      children: [
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                          decoration: BoxDecoration(
                                                            color: article.publishStatus == 1
                                                                ? const Color(0xFF92FE9D).withOpacity(0.15)
                                                                : const Color(0xFFFA6262).withOpacity(0.15),
                                                            borderRadius: BorderRadius.circular(4),
                                                          ),
                                                          child: Text(
                                                            article.publishStatus == 1
                                                                ? '已发布 (${article.publishPlatform})'
                                                                : '待发布',
                                                            style: TextStyle(
                                                              color: article.publishStatus == 1
                                                                  ? const Color(0xFF92FE9D)
                                                                  : const Color(0xFFFA6262),
                                                              fontSize: 10,
                                                              fontWeight: FontWeight.bold,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
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
            const SizedBox(width: 24),

            // 右半栏：详情预览 / 编辑区域
            Expanded(
              flex: 6,
              child: GlassContainer(
                padding: EdgeInsets.zero,
                child: _selectedArticle == null
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.menu_book, color: Color(0xFF2E3245), size: 64),
                            SizedBox(height: 16),
                            Text(
                              '请在左侧列表中选择一篇文章进行查看或编辑',
                              style: TextStyle(color: Color(0xFF4A4E69), fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 顶部工具栏
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
                                // 预览 / 编辑状态按钮
                                Row(
                                  children: [
                                    _buildActionTab(text: '详情预览', isActive: !_isEditing, onTap: _cancelEditing),
                                    _buildActionTab(text: '编辑', isActive: _isEditing, onTap: _startEditing),
                                  ],
                                ),
                                // 发布与删除工具
                                Row(
                                  children: [
                                    if (_selectedArticle!.publishStatus == 1) ...[
                                      IconButton(
                                        tooltip: '访问发布链接',
                                        icon: const Icon(Icons.open_in_new, color: Color(0xFF00C9FF), size: 18),
                                        onPressed: () => _launchUrl(_selectedArticle!.publishUrl),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    if (!_isEditing) ...[
                                      IconButton(
                                        tooltip: '删除该文章',
                                        icon: const Icon(Icons.delete_outline, color: Color(0xFFFA6262), size: 18),
                                        onPressed: _deleteSelectedArticle,
                                      ),
                                      const SizedBox(width: 12),
                                      CustomButton(
                                        text: _selectedArticle!.publishStatus == 1 ? '重新发布' : '发布',
                                        icon: Icons.upload_file,
                                        width: 120,
                                        height: 36,
                                        onPressed: _showPublishDialog,
                                      ),
                                    ] else ...[
                                      IconButton(
                                        tooltip: '取消编辑',
                                        icon: const Icon(Icons.cancel_outlined, color: Colors.grey, size: 18),
                                        onPressed: _cancelEditing,
                                      ),
                                      const SizedBox(width: 12),
                                      CustomButton(
                                        text: '保存修改',
                                        icon: Icons.save,
                                        width: 100,
                                        height: 36,
                                        onPressed: _saveEditing,
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // 正文内容区域
                          Expanded(
                            child: Container(
                              color: const Color(0xFF0C0D12),
                              padding: const EdgeInsets.all(20),
                              child: _isEditing
                                  ? _buildEditorForm()
                                  : _buildPreviewContent(),
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

  /// 详情工具栏左侧 Tab 块
  /// 
  /// 切换编辑与排版预览。
  Widget _buildActionTab({
    required String text,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      mouseCursor: SystemMouseCursors.click,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF2E3245) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isActive ? Colors.white : const Color(0xFFA0A5C0),
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  /// 渲染文章的 Markdown 及首图内容
  /// 
  /// 使用 MarkdownBody 完成渲染，配色为白灰色以在暗色背景下保持极高的可读性。
  Widget _buildPreviewContent() {
    return ListView(
      children: [
        // 标题
        SelectableText(
          _selectedArticle!.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        // 来源与采集时间
        Row(
          children: [
            const Icon(Icons.link, size: 14, color: Colors.grey),
            const SizedBox(width: 4),
            Expanded(
              child: InkWell(
                onTap: () => _launchUrl(_selectedArticle!.sourceUrl),
                mouseCursor: SystemMouseCursors.click,
                child: Text(
                  _selectedArticle!.sourceUrl,
                  style: const TextStyle(color: Colors.cyanAccent, fontSize: 11, decoration: TextDecoration.underline),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 16),
            const Icon(Icons.access_time, size: 14, color: Colors.grey),
            const SizedBox(width: 4),
            Text(
              '采集时间: ${_selectedArticle!.createdAt}',
              style: const TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ],
        ),
        const Divider(color: Color(0xFF2E3245), height: 32),

        // 封面大图
        if (_selectedArticle!.coverUrl.isNotEmpty) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              _selectedArticle!.coverUrl,
              height: 200,
              fit: BoxFit.cover,
              errorBuilder: (c, e, s) => const SizedBox(),
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Markdown 渲染
        MarkdownBody(
          data: _selectedArticle!.content,
          selectable: true,
          onTapLink: (text, href, title) {
            if (href != null) {
              _launchUrl(href);
            }
          },
          styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
            p: const TextStyle(color: Color(0xFFD2D7E5), fontSize: 14, height: 1.6),
            h1: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, height: 2),
            h2: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, height: 1.8),
            h3: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, height: 1.6),
            code: const TextStyle(
              color: Color(0xFFFF9D00),
              backgroundColor: Color(0xFF14161E),
              fontFamily: 'monospace',
              fontSize: 12,
            ),
            codeblockPadding: const EdgeInsets.all(12),
            codeblockDecoration: BoxDecoration(
              color: const Color(0xFF14161E),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF2E3245)),
            ),
          ),
        ),
      ],
    );
  }

  /// 渲染编辑表单
  /// 
  /// 包含标题、封面图、正文 Markdown 内容的文本域，方便修改正文并保存。
  Widget _buildEditorForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 标题编辑
        const Text('文章标题', style: TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 6),
        TextField(
          controller: _editTitleController,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF14161E),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2E3245))),
          ),
        ),
        const SizedBox(height: 12),

        // 封面图编辑
        const Text('封面图链接 URL', style: TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 6),
        TextField(
          controller: _editCoverController,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF14161E),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2E3245))),
          ),
        ),
        const SizedBox(height: 12),

        // 正文 Markdown 编辑
        const Text('正文 Markdown 源码', style: TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 6),
        Expanded(
          child: TextField(
            controller: _editContentController,
            maxLines: null,
            minLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            keyboardType: TextInputType.multiline,
            style: const TextStyle(color: Color(0xFFD2D7E5), fontFamily: 'monospace', fontSize: 13, height: 1.5),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF14161E),
              contentPadding: const EdgeInsets.all(16),
              alignLabelWithHint: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2E3245))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF00C9FF), width: 1.5)),
            ),
          ),
        ),
      ],
    );
  }
}
