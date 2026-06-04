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

/// 应用程序配置状态管理 Provider
/// 
/// 负责在内存中维护大模型 API 配置列表、Emlog 博客配置以及 AI 提取 Prompt，并提供一键保存及连接测试接口。
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

  List<LlmModelConfig> _llmModels = [];

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

  List<LlmModelConfig> get llmModels => _llmModels;

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

    notifyListeners();
  }

  /// 保存并序列化大模型配置列表到本地数据库，同时同步首个启用的大模型为当前默认接口
  Future<void> saveLlmModels(List<LlmModelConfig> models) async {
    _llmModels = models;
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
  Future<void> toggleModelStatus(String id, bool isEnabled) async {
    final updatedList = _llmModels.map((m) {
      if (m.id == id) {
        return m.copyWith(isEnabled: isEnabled);
      }
      return m;
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
  }) async {
    _llmBaseUrl = llmBaseUrl.trim();
    _llmApiKey = llmApiKey.trim();
    _llmModel = llmModel.trim();
    _emlogSiteUrl = emlogSiteUrl.trim();
    _emlogApiKey = emlogApiKey.trim();
    _promptSingle = promptSingle;
    _promptList = promptList;

    await _db.setSetting('llm_base_url', _llmBaseUrl);
    await _db.setSetting('llm_api_key', _llmApiKey);
    await _db.setSetting('llm_model', _llmModel);
    await _db.setSetting('emlog_site_url', _emlogSiteUrl);
    await _db.setSetting('emlog_api_key', _emlogApiKey);
    await _db.setSetting('prompt_single', _promptSingle);
    await _db.setSetting('prompt_list', _promptList);

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
}
