import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/article.dart';

/// 本地 SQLite 数据库服务类
/// 
/// 管理应用程序的生命周期数据库连接，初始化 SQLite 引擎并提供对文章及配置表的操作。
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  Database? _database;

  /// 内部构造函数，实现单例模式
  DatabaseService._internal();

  /// 获取数据库服务单例实例
  static DatabaseService get instance => _instance;

  /// 获取或初始化数据库连接对象
  /// 
  /// 采用懒加载方式获取数据库连接，如果尚未连接则调用初始化方法。
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// 初始化本地 SQLite 数据库
  /// 
  /// 适配 Windows 与 macOS 桌面平台，调用 sqflite_ffi 初始化驱动并创建数据表。
  Future<Database> _initDatabase() async {
    // 桌面端初始化 sqflite
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = p.join(documentsDirectory.path, 'pudding_post.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  /// 创建数据库表结构
  /// 
  /// 在数据库首次被创建时执行，建立 articles 库和 settings 库。
  Future<void> _onCreate(Database db, int version) async {
    // 创建文章表
    await db.execute('''
      CREATE TABLE articles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        content TEXT,
        cover_url TEXT,
        source_url TEXT,
        created_at TEXT,
        publish_status INTEGER DEFAULT 0,
        publish_url TEXT,
        publish_platform TEXT
      )
    ''');

    // 创建配置项表
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    // 写入默认的 Prompt 配置
    await db.execute('''
      INSERT INTO settings (key, value) VALUES 
      ('llm_base_url', 'https://api.deepseek.com/v1'),
      ('llm_api_key', ''),
      ('llm_model', 'deepseek-chat'),
      ('emlog_site_url', ''),
      ('emlog_api_key', ''),
      ('prompt_single', '你是一个专业的网页文章结构提取器。请将我提供给你的网页HTML源码（或清理后的文本结构）进行深度分析，提取文章的【标题】、【正文内容】和【首图链接/封面图链接】。
要求：
1. 【正文内容】请保留排版，并转换成优雅简洁的 Markdown 格式输出。
2. 封面图如果有多张，请选择最相关的一张，如果没有可以返回空字符串。
3. 请严格按照以下 JSON 格式输出，不要包含任何额外的Markdown包裹（如 ```json）或解释文字：
{
  "title": "文章标题",
  "content": "这里是Markdown格式的正文内容",
  "cover_url": "封面图片URL"
}'),
      ('prompt_list', '你是一个专业的网页文章列表与分页解析器。请分析我提供给你的网页HTML源码（或清理后的文本结构），提取文章列表中的文章链接（必须是完整的 URL 或者是能跟原网站拼接的相对路径）以及下一页/分页的链接。
要求：
1. 提取所有文章的详情页链接。
2. 提取下一页（如果有的话）的链接。
3. 请严格按照以下 JSON 格式输出，不要包含任何额外的Markdown包裹或解释文字：
{
  "article_urls": [
    "http://example.com/article/1",
    "http://example.com/article/2"
  ],
  "next_page_url": "http://example.com/list?page=2"
}')
    ''');
  }

  // --- 配置项管理方法 ---

  /// 获取指定键的系统配置值
  /// 
  /// 如果数据库中存在则返回对应值，否则返回 defaultValue。
  Future<String> getSetting(String key, {String defaultValue = ''}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
    );

    if (maps.isNotEmpty) {
      return maps.first['value'] as String? ?? defaultValue;
    }
    return defaultValue;
  }

  /// 插入或更新系统配置键值对
  /// 
  /// 若键已存在则更新对应的配置值，若不存在则插入。
  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // --- 文章管理 CRUD 方法 ---

  /// 向数据库中插入新采集的文章
  /// 
  /// 传入 Article 实例，将其映射后存入 articles 表，并返回自动生成的自增 ID。
  Future<int> insertArticle(Article article) async {
    final db = await database;
    return await db.insert(
      'articles',
      article.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 更新数据库中已有的文章信息
  /// 
  /// 传入包含 ID 的 Article 实例，更新该文章的所有可编辑字段。
  Future<int> updateArticle(Article article) async {
    final db = await database;
    return await db.update(
      'articles',
      article.toMap(),
      where: 'id = ?',
      whereArgs: [article.id],
    );
  }

  /// 根据 ID 删除数据库中的文章
  /// 
  /// 传入文章的唯一自增主键，从数据库中物理删除该记录。
  Future<int> deleteArticle(int id) async {
    final db = await database;
    return await db.delete(
      'articles',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 获取数据库中存储的所有文章
  /// 
  /// 按照主键 ID 倒序（即最新采集的排在最前）查询 articles 表，并返回 Article 列表。
  Future<List<Article>> getAllArticles() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('articles', orderBy: 'id DESC');
    return List.generate(maps.length, (i) {
      return Article.fromMap(maps[i]);
    });
  }

  /// 清空数据库中的所有文章
  /// 
  /// 清理 articles 表中的所有数据，一般用于调试或清空缓存。
  Future<int> clearAllArticles() async {
    final db = await database;
    return await db.delete('articles');
  }

  /// 检查指定网址 (URL) 是否已经被成功采集入库过
  /// 
  /// 传入网址字符串，查询 articles 表是否已存在相同 source_url 的记录。
  Future<bool> isUrlCollected(String url) async {
    final db = await database;
    final List<Map<String, dynamic>> res = await db.query(
      'articles',
      columns: ['id'],
      where: 'source_url = ?',
      whereArgs: [url.trim()],
      limit: 1,
    );
    return res.isNotEmpty;
  }
}
