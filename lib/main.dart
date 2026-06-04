import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/database_service.dart';
import 'providers/settings_provider.dart';
import 'providers/article_provider.dart';
import 'providers/collector_provider.dart';
import 'views/home_screen.dart';

/// 应用程序入口主函数
/// 
/// 负责初始化 Flutter 引擎绑定、预加载本地 SQLite 数据库，并启动主应用。
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 预先初始化数据库连接，在应用启动前保证表结构准备完毕
  final dbService = DatabaseService.instance;
  await dbService.database;

  runApp(const MyApp());
}

/// 应用程序根 Widget
/// 
/// 配置全局状态管理器 MultiProvider、整合多渠道业务逻辑并定义统一的暗黑视觉主题包。
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => SettingsProvider()..loadSettings(),
        ),
        ChangeNotifierProvider(
          create: (_) => ArticleProvider()..loadArticles(),
        ),
        ChangeNotifierProvider(
          create: (_) => CollectorProvider(),
        ),
      ],
      child: MaterialApp(
        title: '布丁发布 - AI文章智能采集发布助手',
        debugShowCheckedModeBanner: false,
        theme: _buildDarkTheme(),
        home: const HomeScreen(),
      ),
    );
  }

  /// 构建全局高雅暗黑风格的主题配置
  /// 
  /// 优化按钮、输入框、卡片等核心控件样式，融入极光绿和魅紫的双端桌面色调表现力。
  ThemeData _buildDarkTheme() {
    return ThemeData.dark(useMaterial3: true).copyWith(
      scaffoldBackgroundColor: const Color(0xFF0B0C10),
      cardColor: const Color(0xFF1E212A),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF00C9FF),
        secondary: Color(0xFF92FE9D),
        surface: Color(0xFF14161E),
        error: Color(0xFFFA6262),
      ),
      // 优化输入框默认形态
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF14161E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF2E3245)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF00C9FF), width: 1.5),
        ),
      ),
      // 优化全局文本排版
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: Color(0xFFE2E8F0), fontSize: 14),
        bodyLarge: TextStyle(color: Colors.white, fontSize: 16),
        titleMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }
}
