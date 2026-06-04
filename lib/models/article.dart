/// 文章实体模型，用于数据库映射及内存数据传递
class Article {
  final int? id;
  final String title;
  final String content;
  final String coverUrl;
  final String sourceUrl;
  final String createdAt;
  final int publishStatus; // 0: 未发布, 1: 已发布
  final String publishUrl;
  final String publishPlatform;

  Article({
    this.id,
    required this.title,
    required this.content,
    required this.coverUrl,
    required this.sourceUrl,
    required this.createdAt,
    this.publishStatus = 0,
    this.publishUrl = '',
    this.publishPlatform = '',
  });

  /// 从 Map 转换为 Article 对象
  /// 
  /// 用于从 SQLite 数据库读取数据并实例化为模型对象。
  factory Article.fromMap(Map<String, dynamic> map) {
    return Article(
      id: map['id'] as int?,
      title: map['title'] as String? ?? '',
      content: map['content'] as String? ?? '',
      coverUrl: map['cover_url'] as String? ?? '',
      sourceUrl: map['source_url'] as String? ?? '',
      createdAt: map['created_at'] as String? ?? '',
      publishStatus: map['publish_status'] as int? ?? 0,
      publishUrl: map['publish_url'] as String? ?? '',
      publishPlatform: map['publish_platform'] as String? ?? '',
    );
  }

  /// 将 Article 对象转换为 Map 结构
  /// 
  /// 用于在插入或更新 SQLite 数据库时将模型属性映射为 SQL 字段键值对。
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'title': title,
      'content': content,
      'cover_url': coverUrl,
      'source_url': sourceUrl,
      'created_at': createdAt,
      'publish_status': publishStatus,
      'publish_url': publishUrl,
      'publish_platform': publishPlatform,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  /// 复制并生成新的 Article 实例
  /// 
  /// 用于更新局部状态，保留未修改的字段并生成新的不可变对象。
  Article copyWith({
    int? id,
    String? title,
    String? content,
    String? coverUrl,
    String? sourceUrl,
    String? createdAt,
    int? publishStatus,
    String? publishUrl,
    String? publishPlatform,
  }) {
    return Article(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      coverUrl: coverUrl ?? this.coverUrl,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      createdAt: createdAt ?? this.createdAt,
      publishStatus: publishStatus ?? this.publishStatus,
      publishUrl: publishUrl ?? this.publishUrl,
      publishPlatform: publishPlatform ?? this.publishPlatform,
    );
  }
}
