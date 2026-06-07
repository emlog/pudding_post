import 'package:flutter/material.dart';
import '../models/article.dart';
import '../services/database_service.dart';
import '../services/publish_service.dart';

/// 内容库中文章管理及发布状态管理 Provider
/// 
/// 提供本地文章列表的加载、搜索过滤、编辑修改、删除归档，并集成发布服务完成将文章同步至 emlog 系统的功能。
class ArticleProvider with ChangeNotifier {
  final _db = DatabaseService.instance;
  final _publishService = PublishService();

  List<Article> _articles = [];
  List<Article> _filteredArticles = [];
  bool _isLoading = false;
  String _searchQuery = '';

  List<Map<String, dynamic>> _categories = [];
  bool _isLoadingCategories = false;

  // Getter 字段定义
  List<Article> get articles => _filteredArticles;
  List<Article> get allArticles => _articles;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;

  List<Map<String, dynamic>> get categories => _categories;
  bool get isLoadingCategories => _isLoadingCategories;

  /// 从数据库加载所有已采集文章列表
  /// 
  /// 异步读取 SQLite 数据库，并刷新内存缓存。同时应用当前已有的搜索过滤词。
  Future<void> loadArticles() async {
    _isLoading = true;
    notifyListeners();
    try {
      _articles = await _db.getAllArticles();
      _applyFilter();
    } catch (_) {
      // 容错处理
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 搜索并过滤文章列表
  /// 
  /// 传入关键词，对文章标题或来源 URL 进行模糊搜索，更新显示列表。
  void searchArticles(String query) {
    _searchQuery = query;
    _applyFilter();
    notifyListeners();
  }

  /// 执行过滤逻辑
  /// 
  /// 根据 _searchQuery 对全量文章数据进行筛选，结果放入 _filteredArticles 中。
  void _applyFilter() {
    if (_searchQuery.trim().isEmpty) {
      _filteredArticles = List.from(_articles);
    } else {
      final query = _searchQuery.toLowerCase().trim();
      _filteredArticles = _articles.where((article) {
        return article.title.toLowerCase().contains(query) ||
            article.sourceUrl.toLowerCase().contains(query);
      }).toList();
    }
  }

  /// 更新已有的文章信息
  /// 
  /// 用于内容库中的“文章编辑”功能。更新数据库，并刷新本地列表状态。
  Future<void> updateArticle(Article article) async {
    await _db.updateArticle(article);
    final index = _articles.indexWhere((element) => element.id == article.id);
    if (index != -1) {
      _articles[index] = article;
      _applyFilter();
      notifyListeners();
    }
  }

  /// 删除单篇文章
  /// 
  /// 从数据库物理删除该文章，并从内存列表中移除。
  Future<void> deleteArticle(int id) async {
    await _db.deleteArticle(id);
    _articles.removeWhere((element) => element.id == id);
    _applyFilter();
    notifyListeners();
  }

  /// 清空所有已采集的文章记录
  /// 
  /// 用于重置内容库。
  Future<void> clearAllArticles() async {
    await _db.clearAllArticles();
    _articles.clear();
    _filteredArticles.clear();
    notifyListeners();
  }

  /// 加载 emlog 系统的分类列表
  /// 
  /// 供发布对话框调用，展示并选择分类。
  Future<void> loadCategories() async {
    _isLoadingCategories = true;
    notifyListeners();
    try {
      _categories = await _publishService.fetchCategories();
    } catch (e) {
      _categories = [];
      rethrow;
    } finally {
      _isLoadingCategories = false;
      notifyListeners();
    }
  }

  /// 发布单篇文章至 emlog 系统
  /// 
  /// 传入文章 ID 和分类 ID。发布成功后，自动将数据库及内存中对应的文章状态更新为“已发布”，并保存返回的链接。
  Future<void> publishArticle(int articleId, String sortId) async {
    final index = _articles.indexWhere((element) => element.id == articleId);
    if (index == -1) return;
    
    final article = _articles[index];

    try {
      final publishUrl = await _publishService.publishToEmlog(
        title: article.title,
        content: article.content,
        sortId: sortId,
        coverUrl: article.coverUrl,
      );

      final updatedArticle = article.copyWith(
        publishStatus: 1,
        publishUrl: publishUrl,
        publishPlatform: 'emlog',
      );

      await updateArticle(updatedArticle);
    } catch (e) {
      rethrow;
    }
  }

  /// 批量发布多篇文章至 emlog
  /// 
  /// 传入选中的文章 ID 列表及分类 ID，循环调用单个发布流程，适用于批量操作。
  Future<Map<int, String>> batchPublishArticles(List<int> articleIds, String sortId) async {
    final results = <int, String>{}; // 保存每篇文章发布的结果（空代表成功，否则为错误信息）
    for (var id in articleIds) {
      try {
        await publishArticle(id, sortId);
        results[id] = '';
      } catch (e) {
        results[id] = e.toString();
      }
    }
    return results;
  }
}
