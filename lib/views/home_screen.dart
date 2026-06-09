import 'dart:ui';
import 'package:flutter/material.dart';
import 'collector_view.dart';
import 'library_view.dart';
import 'publish_management_view.dart';
import 'model_settings_view.dart';

/// 应用程序主框架 Home 页面
/// 
/// 提供左侧悬浮毛玻璃导航边栏，管理“内容采集”、“内容管理”、“发布管理”和“模型设置”的切换。
/// 背景融合了霓虹光晕渲染动效，展现出极其现代化的智能视觉设计，默认采用暗黑风格。
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // 页面列表定义，包括内容采集、内容管理、发布管理和模型设置
  final List<Widget> _pages = const [
    CollectorView(),
    LibraryView(),
    PublishManagementView(),
    ModelSettingsView(),
  ];

  /// 弹出软件关于对话框，展示版本信息与 GitHub 仓库地址。
  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF14161E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(
              color: Color(0xFF2E3245),
              width: 1.5,
            ),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Color(0xFF00C9FF),
              ),
              SizedBox(width: 8),
              Text(
                '关于布丁发布',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '布丁发布 - 基于 AI 的文章智能采集与发布桌面助手。',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
                const SizedBox(height: 16),
                const Divider(color: Color(0xFF2E3245)),
                const SizedBox(height: 8),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '软件版本',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    Text(
                      'v1.0.0',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                '关闭',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. 底层极光霓虹光晕效果
          _buildNeonBackground(),

          // 2. 主页面内容
          SafeArea(
            child: Row(
              children: [
                // 左侧悬浮侧边导航栏
                _buildSidebar(),
                // 右侧主内容区域
                Expanded(
                  child: IndexedStack(
                    index: _selectedIndex,
                    children: _pages,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 绘制暗黑主题下的极光微光背景。
  Widget _buildNeonBackground() {
    return Container(
      color: const Color(0xFF0B0C10), // 基底背景色
      child: Stack(
        children: [
          // 右上角蓝绿霓虹光晕
          Positioned(
            right: -100,
            top: -100,
            child: Container(
              width: 450,
              height: 450,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00F2FE).withOpacity(0.08),
              ),
            ),
          ),
          // 左下角紫红霓虹光晕
          Positioned(
            left: -150,
            bottom: -150,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF9B51E0).withOpacity(0.08),
              ),
            ),
          ),
          // 全局应用轻微高斯模糊，使得边缘完全晕染融入深色背景
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: const SizedBox(),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建左侧悬浮毛玻璃导航边栏，锁定暗黑配饰效果。
  Widget _buildSidebar() {
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: const Color(0xFF14161E).withOpacity(0.4),
        border: const Border(
          right: BorderSide(
            color: Color(0xFF2E3245),
            width: 1.5,
          ),
        ),
      ),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo 标题栏
                _buildLogoHeader(),
                const SizedBox(height: 40),

                // 导航选项组
                Expanded(
                  child: Column(
                    children: [
                      _SidebarItem(
                        index: 0,
                        icon: Icons.rocket_launch_outlined,
                        activeIcon: Icons.rocket_launch,
                        title: '内容采集',
                        isSelected: _selectedIndex == 0,
                        onTap: () => setState(() => _selectedIndex = 0),
                      ),
                      const SizedBox(height: 12),
                      _SidebarItem(
                        index: 1,
                        icon: Icons.folder_open,
                        activeIcon: Icons.folder,
                        title: '内容管理',
                        isSelected: _selectedIndex == 1,
                        onTap: () => setState(() => _selectedIndex = 1),
                      ),
                      const SizedBox(height: 12),
                      _SidebarItem(
                        index: 2,
                        icon: Icons.rss_feed_outlined,
                        activeIcon: Icons.rss_feed,
                        title: '发布管理',
                        isSelected: _selectedIndex == 2,
                        onTap: () => setState(() => _selectedIndex = 2),
                      ),
                      const SizedBox(height: 12),
                      _SidebarItem(
                        index: 3,
                        icon: Icons.auto_awesome_outlined,
                        activeIcon: Icons.auto_awesome,
                        title: '模型设置',
                        isSelected: _selectedIndex == 3,
                        onTap: () => setState(() => _selectedIndex = 3),
                      ),
                    ],
                  ),
                ),

                // 边栏底部关于信息图标按钮
                _buildSidebarFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建导航栏的 Logo 部分。
  Widget _buildLogoHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF00C9FF), Color(0xFF8B5CF6)],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.auto_awesome,
            color: Colors.black,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShaderMask(
              shaderCallback: _createGradientShader,
              child: const Text(
                '布丁发布',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const Text(
              'v1.0.0 Desktop',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 创建标题颜色渐变着色器。
  static Shader _createGradientShader(Rect bounds) {
    return const LinearGradient(
      colors: [Color(0xFF00C9FF), Color(0xFF8B5CF6)],
    ).createShader(bounds);
  }

  /// 构建导航栏底部信息栏，仅包含展示关于信息的“i”图标按钮。
  Widget _buildSidebarFooter() {
    return Align(
      alignment: Alignment.centerLeft,
      child: IconButton(
        icon: const Icon(
          Icons.info_outline, 
          color: Color(0xFFA0A5C0),
        ),
        onPressed: () => _showAboutDialog(context),
        tooltip: '关于系统',
      ),
    );
  }
}

/// 构建侧边栏单个导航项，自适应暗黑视觉规范。
/// 
/// 该组件独立管理 Hover 悬停状态，并在悬停时提供平滑的背景发光及图标弹性微移（2 像素）交互。
class _SidebarItem extends StatefulWidget {
  final int index;
  final IconData icon;
  final IconData activeIcon;
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.index,
    required this.icon,
    required this.activeIcon,
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color borderColor;

    // 根据是否选中和是否悬停计算背景色和边框颜色
    if (widget.isSelected) {
      backgroundColor = const Color(0xFF2E3245).withOpacity(0.5);
      borderColor = const Color(0xFF2E3245).withOpacity(0.9);
    } else if (_isHovered) {
      backgroundColor = const Color(0xFF2E3245).withOpacity(0.2);
      borderColor = const Color(0xFF2E3245).withOpacity(0.4);
    } else {
      backgroundColor = Colors.transparent;
      borderColor = Colors.transparent;
    }

    final Color textColor = widget.isSelected
        ? Colors.white
        : (_isHovered ? Colors.white.withOpacity(0.9) : const Color(0xFFA0A5C0));

    final Color iconColor = widget.isSelected
        ? const Color(0xFF00C9FF)
        : (_isHovered ? const Color(0xFF00C9FF).withOpacity(0.8) : const Color(0xFFA0A5C0));

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: borderColor,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // 使用 AnimatedSlide 使得 Hover 时图标右移 2 像素，增加灵动交互体验
              AnimatedSlide(
                offset: _isHovered && !widget.isSelected
                    ? const Offset(0.08, 0)
                    : Offset.zero,
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOutCubic,
                child: Icon(
                  widget.isSelected ? widget.activeIcon : widget.icon,
                  color: iconColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              // 文字也加上缓动颜色切换
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 150),
                style: TextStyle(
                  color: textColor,
                  fontSize: 13,
                  fontWeight: widget.isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                child: Text(widget.title),
              ),
              if (widget.isSelected) ...[
                const Spacer(),
                // 激活状态下的发光右侧指示条
                Container(
                  width: 4,
                  height: 12,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C9FF),
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00C9FF).withOpacity(0.5),
                        blurRadius: 4,
                        offset: const Offset(0, 0),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
