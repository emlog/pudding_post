import 'dart:ui';
import 'package:flutter/material.dart';
import 'collector_view.dart';
import 'library_view.dart';
import 'publish_management_view.dart';
import 'model_settings_view.dart';

/// 应用程序主框架 Home 页面
/// 
/// 提供左侧悬浮毛玻璃导航边栏，管理“内容采集”、“内容管理”、“发布管理”和“模型设置”的切换。
/// 背景融合了霓虹光晕渲染动效，展现出极其现代化的暗黑科技视觉设计。
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

  /// 绘制炫酷的暗黑极光微光背景
  /// 
  /// 使用两处带径向渐变、高斯模糊的彩色模糊圆形，模拟 macOS/Windows11 极光背景。
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

  /// 构建左侧毛玻璃导航边栏
  /// 
  /// 精美的竖向导航栏，支持 hover 和选中状态高亮，附带应用程序渐变文字 Logo。
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
                      _buildSidebarItem(
                        index: 0,
                        icon: Icons.rocket_launch_outlined,
                        activeIcon: Icons.rocket_launch,
                        title: '内容采集',
                      ),
                      const SizedBox(height: 12),
                      _buildSidebarItem(
                        index: 1,
                        icon: Icons.folder_open,
                        activeIcon: Icons.folder,
                        title: '内容管理',
                      ),
                      const SizedBox(height: 12),
                      _buildSidebarItem(
                        index: 2,
                        icon: Icons.rss_feed_outlined,
                        activeIcon: Icons.rss_feed,
                        title: '发布管理',
                      ),
                      const SizedBox(height: 12),
                      _buildSidebarItem(
                        index: 3,
                        icon: Icons.auto_awesome_outlined,
                        activeIcon: Icons.auto_awesome,
                        title: '模型设置',
                      ),
                    ],
                  ),
                ),

                // 边栏底部状态栏
                _buildSidebarFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建导航栏的 Logo 部分
  /// 
  /// 展示应用程序的名称与炫酷的渐变颜色文字。
  Widget _buildLogoHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF00C9FF), Color(0xFF92FE9D)],
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
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShaderMask(
              shaderCallback: _createGradientShader,
              child: Text(
                '布丁发布',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            Text(
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

  /// 创建标题颜色渐变着色器
  /// 
  /// 为 Logo 文本生成漂亮的蓝绿过渡渐变色。
  static Shader _createGradientShader(Rect bounds) {
    return const LinearGradient(
      colors: [Color(0xFF00C9FF), Color(0xFF92FE9D)],
    ).createShader(bounds);
  }

  /// 构建侧边栏单个导航项
  /// 
  /// 拥有 hover、选中微动效、状态字体变化及激活的高亮装饰块。
  Widget _buildSidebarItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String title,
  }) {
    final isSelected = _selectedIndex == index;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedIndex = index;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF2E3245).withOpacity(0.4)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF2E3245).withOpacity(0.8)
                  : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? activeIcon : icon,
                color: isSelected ? const Color(0xFF00C9FF) : const Color(0xFFA0A5C0),
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFFA0A5C0),
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              if (isSelected) ...[
                const Spacer(),
                Container(
                  width: 4,
                  height: 12,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C9FF),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 构建导航栏底部信息栏
  /// 
  /// 显示系统运行状态，增加面板真实感与亲和度。
  Widget _buildSidebarFooter() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E212A).withOpacity(0.3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF2E3245).withOpacity(0.5),
        ),
      ),
      child: const Row(
        children: [
          Icon(Icons.circle, color: Color(0xFF92FE9D), size: 8),
          SizedBox(width: 8),
          Text(
            '本地数据库运行正常',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
