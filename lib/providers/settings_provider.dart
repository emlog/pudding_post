import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/llm_service.dart';
import '../services/publish_service.dart';

/// 大语言模型单个配置项实体
class LlmModelConfig {
  final String id;
  final String name;
  final String baseUrl;
  final String apiKey;
  final String model;
  final bool isEnabled;

  LlmModelConfig({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.apiKey,
    required this.model,
    required this.isEnabled,
  });

  /// 拷贝并创建新的模型配置对象
  LlmModelConfig copyWith({
    String? id,
    String? name,
    String? baseUrl,
    String? apiKey,
    String? model,
    bool? isEnabled,
  }) {
    return LlmModelConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  /// 序列化为 Map 数据格式
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'baseUrl': baseUrl,
      'apiKey': apiKey,
      'model': model,
      'isEnabled': isEnabled,
    };
  }

  /// 从 Map 反序列化构建模型配置对象
  factory LlmModelConfig.fromMap(Map<String, dynamic> map) {
    return LlmModelConfig(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      baseUrl: map['baseUrl'] ?? '',
      apiKey: map['apiKey'] ?? '',
      model: map['model'] ?? '',
      isEnabled: map['isEnabled'] == true || map['isEnabled'] == 1,
    );
  }
}

/// 采集网址分组配置项实体
class UrlGroup {
  final String id;
  final String name;
  final List<String> urls;
  final String createdAt;

  UrlGroup({
    required this.id,
    required this.name,
    required this.urls,
    required this.createdAt,
  });

  /// 拷贝并创建新的 UrlGroup 对象
  UrlGroup copyWith({
    String? id,
    String? name,
    List<String>? urls,
    String? createdAt,
  }) {
    return UrlGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      urls: urls ?? this.urls,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// 序列化为 Map 数据格式
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'urls': urls,
      'createdAt': createdAt,
    };
  }

  /// 从 Map 反序列化构建 UrlGroup 对象
  factory UrlGroup.fromMap(Map<String, dynamic> map) {
    return UrlGroup(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      urls: List<String>.from(map['urls'] ?? []),
      createdAt: map['createdAt'] ?? '',
    );
  }
}

/// 应用程序配置状态管理 Provider
/// 
/// 负责在内存中维护大模型 API 配置列表、Emlog 配置以及 AI 提取 Prompt，并提供一键保存及连接测试接口。
class SettingsProvider with ChangeNotifier {
  final _db = DatabaseService.instance;
  final _llmService = LlmService();
  final _publishService = PublishService();

  String _llmBaseUrl = '';
  String _llmApiKey = '';
  String _llmModel = '';
  String _emlogSiteUrl = '';
  String _emlogApiKey = '';
  String _promptSingle = '';
  String _promptList = '';
  String _networkProxyUrl = '';
  int _maxConcurrency = 3;

  List<LlmModelConfig> _llmModels = [];
  List<UrlGroup> _urlGroups = [];

  bool _isTestingLlm = false;
  bool _isTestingEmlog = false;

  // Getter 字段定义
  String get llmBaseUrl => _llmBaseUrl;
  String get llmApiKey => _llmApiKey;
  String get llmModel => _llmModel;
  String get emlogSiteUrl => _emlogSiteUrl;
  String get emlogApiKey => _emlogApiKey;
  String get promptSingle => _promptSingle;
  String get promptList => _promptList;
  String get networkProxyUrl => _networkProxyUrl;
  int get maxConcurrency => _maxConcurrency;

  List<LlmModelConfig> get llmModels => _llmModels;
  List<UrlGroup> get urlGroups => _urlGroups;

  bool get isTestingLlm => _isTestingLlm;
  bool get isTestingEmlog => _isTestingEmlog;

  /// 初始化并从数据库加载所有配置参数
  /// 
  /// 在 App 启动或配置页面初始化时调用，读取 SQLite 中的持久化配置。
  Future<void> loadSettings() async {
    _llmBaseUrl = await _db.getSetting('llm_base_url', defaultValue: 'https://api.deepseek.com/v1');
    _llmApiKey = await _db.getSetting('llm_api_key', defaultValue: '');
    _llmModel = await _db.getSetting('llm_model', defaultValue: 'deepseek-chat');
    _emlogSiteUrl = await _db.getSetting('emlog_site_url', defaultValue: '');
    _emlogApiKey = await _db.getSetting('emlog_api_key', defaultValue: '');
    _promptSingle = await _db.getSetting('prompt_single', defaultValue: '');
    _promptList = await _db.getSetting('prompt_list', defaultValue: '');
    _networkProxyUrl = await _db.getSetting('network_proxy_url', defaultValue: '');
    
    // 加载最大并发数配置
    final concurrencyStr = await _db.getSetting('max_concurrency', defaultValue: '3');
    _maxConcurrency = int.tryParse(concurrencyStr) ?? 3;

    // 加载多模型列表配置
    final modelsJson = await _db.getSetting('llm_models_list', defaultValue: '');
    if (modelsJson.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(modelsJson);
        _llmModels = list.map((item) => LlmModelConfig.fromMap(item as Map<String, dynamic>)).toList();
      } catch (_) {
        _llmModels = [];
      }
    }

    // 若配置列表为空，则使用当前默认参数初始化首个默认大模型
    if (_llmModels.isEmpty) {
      _llmModels = [
        LlmModelConfig(
          id: 'default_deepseek',
          name: '默认 DeepSeek',
          baseUrl: _llmBaseUrl,
          apiKey: _llmApiKey,
          model: _llmModel,
          isEnabled: true,
        )
      ];
      await _db.setSetting('llm_models_list', jsonEncode(_llmModels.map((m) => m.toMap()).toList()));
    }

    // 加载网址分组列表配置
    final urlGroupsJson = await _db.getSetting('collector_url_groups', defaultValue: '');
    if (urlGroupsJson.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(urlGroupsJson);
        _urlGroups = list.map((item) => UrlGroup.fromMap(item as Map<String, dynamic>)).toList();
      } catch (_) {
        _urlGroups = [];
      }
    }

    notifyListeners();
  }

  /// 保存并序列化大模型配置列表到本地数据库，同时同步首个启用的大模型为当前默认接口
  /// 
  /// 此处加入了防空保护：若没有一个模型处于开启状态且配置列表不为空，则强制启用第一个大模型。
  Future<void> saveLlmModels(List<LlmModelConfig> models) async {
    _llmModels = models;
    
    // 防御性保护：确保列表中至少有一个模型被启用
    if (_llmModels.isNotEmpty && !_llmModels.any((m) => m.isEnabled)) {
      _llmModels[0] = _llmModels[0].copyWith(isEnabled: true);
    }

    final jsonStr = jsonEncode(_llmModels.map((m) => m.toMap()).toList());
    await _db.setSetting('llm_models_list', jsonStr);

    // 寻找第一个开启的模型并更新系统当前使用的默认模型
    final enabledModelIndex = _llmModels.indexWhere((m) => m.isEnabled);
    if (enabledModelIndex != -1) {
      final enabledModel = _llmModels[enabledModelIndex];
      _llmBaseUrl = enabledModel.baseUrl;
      _llmApiKey = enabledModel.apiKey;
      _llmModel = enabledModel.model;

      await _db.setSetting('llm_base_url', _llmBaseUrl);
      await _db.setSetting('llm_api_key', _llmApiKey);
      await _db.setSetting('llm_model', _llmModel);
    }
    notifyListeners();
  }

  /// 快捷更新指定大模型的开启/关闭启用状态
  /// 
  /// 采用单选互斥模式：若开启某一模型，则其余模型将自动关闭。
  Future<void> toggleModelStatus(String id, bool isEnabled) async {
    // 防空保护：如果尝试关闭当前唯一启用的模型，直接拦截
    if (!isEnabled) {
      final currentlyEnabledCount = _llmModels.where((m) => m.isEnabled).length;
      final targetModelIndex = _llmModels.indexWhere((m) => m.id == id);
      if (targetModelIndex != -1 && _llmModels[targetModelIndex].isEnabled && currentlyEnabledCount <= 1) {
        return;
      }
    }

    final updatedList = _llmModels.map((m) {
      if (m.id == id) {
        return m.copyWith(isEnabled: isEnabled);
      }
      // 互斥协调：若当前目标模型被开启(isEnabled为true)，其它模型全部置为禁用
      return isEnabled ? m.copyWith(isEnabled: false) : m;
    }).toList();
    await saveLlmModels(updatedList);
  }

  /// 向模型配置列表中追加添加一个新的大模型
  Future<void> addLlmModel(LlmModelConfig model) async {
    final updatedList = List<LlmModelConfig>.from(_llmModels)..add(model);
    await saveLlmModels(updatedList);
  }

  /// 根据唯一 ID 物理删除一个大模型配置项
  Future<void> deleteLlmModel(String id) async {
    final updatedList = _llmModels.where((m) => m.id != id).toList();
    await saveLlmModels(updatedList);
  }

  /// 修改并保存一个已有大模型的各项配置信息
  Future<void> updateLlmModel(LlmModelConfig updatedModel) async {
    final updatedList = _llmModels.map((m) {
      return m.id == updatedModel.id ? updatedModel : m;
    }).toList();
    await saveLlmModels(updatedList);
  }

  /// 保存更新后的博客与 Prompt 等通用配置项
  /// 
  /// 将通用配置写入 SQLite 数据库，并刷新内存中的状态。
  Future<void> saveSettings({
    required String llmBaseUrl,
    required String llmApiKey,
    required String llmModel,
    required String emlogSiteUrl,
    required String emlogApiKey,
    required String promptSingle,
    required String promptList,
    required String networkProxyUrl,
    required int maxConcurrency,
  }) async {
    _llmBaseUrl = llmBaseUrl.trim();
    _llmApiKey = llmApiKey.trim();
    _llmModel = llmModel.trim();
    _emlogSiteUrl = emlogSiteUrl.trim();
    _emlogApiKey = emlogApiKey.trim();
    _promptSingle = promptSingle;
    _promptList = promptList;
    _networkProxyUrl = networkProxyUrl.trim();
    _maxConcurrency = maxConcurrency;

    await _db.setSetting('llm_base_url', _llmBaseUrl);
    await _db.setSetting('llm_api_key', _llmApiKey);
    await _db.setSetting('llm_model', _llmModel);
    await _db.setSetting('emlog_site_url', _emlogSiteUrl);
    await _db.setSetting('emlog_api_key', _emlogApiKey);
    await _db.setSetting('prompt_single', _promptSingle);
    await _db.setSetting('prompt_list', _promptList);
    await _db.setSetting('network_proxy_url', _networkProxyUrl);
    await _db.setSetting('max_concurrency', _maxConcurrency.toString());

    notifyListeners();
  }

  /// 测试当前配置的大模型连接状态
  /// 
  /// 传入需要测试的参数，调用 LlmService 进行连通性验证。
  Future<bool> testLlmConnection(String baseUrl, String apiKey, String model) async {
    _isTestingLlm = true;
    notifyListeners();
    try {
      final success = await _llmService.testConnection(baseUrl.trim(), apiKey.trim(), model.trim());
      _isTestingLlm = false;
      notifyListeners();
      return success;
    } catch (_) {
      _isTestingLlm = false;
      notifyListeners();
      return false;
    }
  }

  /// 测试当前配置的 emlog 站点连接状态
  /// 
  /// 传入需要测试的参数，调用 LlmService 获取分类接口进行连通性验证。
  Future<bool> testEmlogConnection(String siteUrl, String apiKey) async {
    _isTestingEmlog = true;
    notifyListeners();
    try {
      final success = await _publishService.testConnection(siteUrl.trim(), apiKey.trim());
      _isTestingEmlog = false;
      notifyListeners();
      return success;
    } catch (_) {
      _isTestingEmlog = false;
      notifyListeners();
      return false;
    }
  }

  // --- 网址分组管理方法 ---

  /// 保存并序列化网址分组列表到本地数据库
  Future<void> saveUrlGroups(List<UrlGroup> groups) async {
    _urlGroups = groups;
    final jsonStr = jsonEncode(_urlGroups.map((g) => g.toMap()).toList());
    await _db.setSetting('collector_url_groups', jsonStr);
    notifyListeners();
  }

  /// 新建并保存一个网址分组
  Future<void> addUrlGroup(UrlGroup group) async {
    final updatedList = List<UrlGroup>.from(_urlGroups)..add(group);
    await saveUrlGroups(updatedList);
  }

  /// 根据 ID 删除指定的网址分组
  Future<void> deleteUrlGroup(String id) async {
    final updatedList = _urlGroups.where((g) => g.id != id).toList();
    await saveUrlGroups(updatedList);
  }

  /// 更新指定的网址分组配置项（如重命名等）
  Future<void> updateUrlGroup(UrlGroup updatedGroup) async {
    final updatedList = _urlGroups.map((g) {
      return g.id == updatedGroup.id ? updatedGroup : g;
    }).toList();
    await saveUrlGroups(updatedList);
  }

  /// 快速向指定分组追加一个新的目标采集网址（若网址已存在则不重复添加）
  Future<void> addUrlToGroup(String groupId, String url) async {
    final trimmedUrl = url.trim();
    if (trimmedUrl.isEmpty) return;

    final updatedList = _urlGroups.map((g) {
      if (g.id == groupId) {
        if (!g.urls.contains(trimmedUrl)) {
          return g.copyWith(urls: List<String>.from(g.urls)..add(trimmedUrl));
        }
      }
      return g;
    }).toList();
    await saveUrlGroups(updatedList);
  }

  /// 快速从指定分组中移除一个采集网址
  Future<void> removeUrlFromGroup(String groupId, String url) async {
    final updatedList = _urlGroups.map((g) {
      if (g.id == groupId) {
        final newUrls = g.urls.where((u) => u != url).toList();
        return g.copyWith(urls: newUrls);
      }
      return g;
    }).toList();
    await saveUrlGroups(updatedList);
  }
}
