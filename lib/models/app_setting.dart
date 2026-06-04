/// 应用配置项实体模型，用于在 SQLite 数据库中以键值对形式存储系统配置
class AppSetting {
  final String key;
  final String value;

  AppSetting({
    required this.key,
    required this.value,
  });

  /// 从 Map 转换为 AppSetting 对象
  /// 
  /// 用于从数据库加载配置项并实例化。
  factory AppSetting.fromMap(Map<String, dynamic> map) {
    return AppSetting(
      key: map['key'] as String? ?? '',
      value: map['value'] as String? ?? '',
    );
  }

  /// 将 AppSetting 对象转换为 Map 结构
  /// 
  /// 用于将配置项写入或更新到数据库中。
  Map<String, dynamic> toMap() {
    return {
      'key': key,
      'value': value,
    };
  }
}
