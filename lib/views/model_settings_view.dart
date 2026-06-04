import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/glass_container.dart';
import '../widgets/custom_button.dart';

/// 大语言模型管理页面 View
/// 
/// 提供多个大模型的列表管理界面，支持添加、修改、物理删除，并且能够实时通过 Switch 开关来启用或禁用指定模型。
class ModelSettingsView extends StatefulWidget {
  const ModelSettingsView({super.key});

  @override
  State<ModelSettingsView> createState() => _ModelSettingsViewState();
}

class _ModelSettingsViewState extends State<ModelSettingsView> {
  final _dialogFormKey = GlobalKey<FormState>();
  
  late TextEditingController _nameController;
  late TextEditingController _baseUrlController;
  late TextEditingController _apiKeyController;
  late TextEditingController _modelController;

  // 正在测试连接的模型 ID
  String _testingModelId = '';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _baseUrlController = TextEditingController();
    _apiKeyController = TextEditingController();
    _modelController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  /// 显示操作状态通知 SnackBar
  /// 
  /// [message] 通知内容，[isError] 是否是红色背景的错误提示
  void _showSnackBar(String message, bool isError) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: isError ? Colors.redAccent : Colors.teal,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// 测试指定大模型配置的接口连通性
  /// 
  /// 传入 [modelConfig]，调用 Provider 进行异步连通性校验，测试完成后气泡弹窗提示。
  Future<void> _testModelConnection(LlmModelConfig modelConfig) async {
    setState(() {
      _testingModelId = modelConfig.id;
    });

    final provider = Provider.of<SettingsProvider>(context, listen: false);
    final success = await provider.testLlmConnection(
      modelConfig.baseUrl,
      modelConfig.apiKey,
      modelConfig.model,
    );

    setState(() {
      _testingModelId = '';
    });

    _showSnackBar(
      success ? '【${modelConfig.name}】接口测试成功！' : '【${modelConfig.name}】测试连接失败，请检查配置参数及网络！',
      !success,
    );
  }

  /// 测试弹窗中临时填写的大模型配置连通性
  /// 
  /// 配合弹窗中的局部更新 State，在保存前完成校验
  Future<void> _testModelConnectionInDialog(StateSetter setDialogState, SettingsProvider settings) async {
    setDialogState(() {}); // 触发弹窗的 Loading 状态更新
    final success = await settings.testLlmConnection(
      _baseUrlController.text,
      _apiKeyController.text,
      _modelController.text,
    );
    _showSnackBar(
      success ? '接口连接测试成功！' : '测试连接失败，请检查配置参数或 API Key！',
      !success,
    );
    setDialogState(() {});
  }

  /// 打开大模型新增或编辑的对话框表单
  /// 
  /// 若 [existingModel] 不为空则为编辑模式，反之为新增模式。
  void _showModelFormDialog({LlmModelConfig? existingModel}) {
    final provider = Provider.of<SettingsProvider>(context, listen: false);
    final isEdit = existingModel != null;

    if (isEdit) {
      _nameController.text = existingModel.name;
      _baseUrlController.text = existingModel.baseUrl;
      _apiKeyController.text = existingModel.apiKey;
      _modelController.text = existingModel.model;
    } else {
      _nameController.text = '';
      _baseUrlController.text = 'https://api.deepseek.com/v1';
      _apiKeyController.text = '';
      _modelController.text = 'deepseek-chat';
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF14161E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFF2E3245), width: 1.5),
              ),
              title: Text(
                isEdit ? '编辑大模型配置' : '新增大模型配置',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: 450,
                child: SingleChildScrollView(
                  child: Form(
                    key: _dialogFormKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTextField(
                          label: '模型显示名称',
                          controller: _nameController,
                          hint: '例如: DeepSeek-V3 生产环境',
                        ),
                        const SizedBox(height: 12),
                        _buildTextField(
                          label: 'API 接口地址 (Base URL)',
                          controller: _baseUrlController,
                          hint: '例如: https://api.deepseek.com/v1',
                        ),
                        const SizedBox(height: 12),
                        _buildTextField(
                          label: 'API 密钥 (API Key)',
                          controller: _apiKeyController,
                          hint: '输入该大模型的 API 访问密钥',
                          isObscure: true,
                        ),
                        const SizedBox(height: 12),
                        _buildTextField(
                          label: '模型标识 (Model Name)',
                          controller: _modelController,
                          hint: '例如: deepseek-chat, gpt-4o 等',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              actions: [
                CustomButton(
                  text: '测试连通性',
                  icon: Icons.sync_alt,
                  width: 130,
                  isSecondary: true,
                  isLoading: provider.isTestingLlm,
                  onPressed: () => _testModelConnectionInDialog(setDialogState, provider),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消', style: TextStyle(color: Colors.grey)),
                ),
                CustomButton(
                  text: '保存',
                  icon: Icons.check,
                  width: 90,
                  onPressed: () async {
                    if (_dialogFormKey.currentState!.validate()) {
                      if (isEdit) {
                        final updated = existingModel.copyWith(
                          name: _nameController.text.trim(),
                          baseUrl: _baseUrlController.text.trim(),
                          apiKey: _apiKeyController.text.trim(),
                          model: _modelController.text.trim(),
                        );
                        await provider.updateLlmModel(updated);
                        _showSnackBar('模型配置已成功修改', false);
                      } else {
                        final newModel = LlmModelConfig(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          name: _nameController.text.trim(),
                          baseUrl: _baseUrlController.text.trim(),
                          apiKey: _apiKeyController.text.trim(),
                          model: _modelController.text.trim(),
                          isEnabled: true,
                        );
                        await provider.addLlmModel(newModel);
                        _showSnackBar('新模型配置已成功添加', false);
                      }
                      Navigator.of(context).pop();
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 确认并物理删除指定的模型配置
  /// 
  /// 弹框二次确认，避免误操作
  Future<void> _confirmDeleteModel(LlmModelConfig modelConfig) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E212A),
        title: const Text('确认删除模型', style: TextStyle(color: Colors.white)),
        content: Text('确定要删除大模型“${modelConfig.name}”配置吗？此操作不可恢复。', style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确认删除', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final provider = Provider.of<SettingsProvider>(context, listen: false);
      await provider.deleteLlmModel(modelConfig.id);
      _showSnackBar('模型配置已物理删除', false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final models = settings.llmModels;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 页面标题及新增模型按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI 大模型设置',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                CustomButton(
                  text: '添加大模型配置',
                  icon: Icons.add_circle_outline,
                  width: 170,
                  onPressed: () => _showModelFormDialog(),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 模型卡片列表布局
            if (models.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 80.0),
                  child: Column(
                    children: [
                      Icon(Icons.auto_awesome, size: 48, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        '暂无模型配置，请点击右上角按钮添加',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 24,
                  mainAxisSpacing: 24,
                  mainAxisExtent: 245,
                ),
                itemCount: models.length,
                itemBuilder: (context, index) {
                  final model = models[index];
                  final isTestingThis = _testingModelId == model.id;
                  
                  return GlassContainer(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 标题行与开关控制按钮
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.auto_awesome,
                                      color: Color(0xFF00C9FF),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        model.name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    model.isEnabled ? '已开启' : '已关闭',
                                    style: TextStyle(
                                      color: model.isEnabled ? const Color(0xFF92FE9D) : Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Switch(
                                    value: model.isEnabled,
                                    activeColor: const Color(0xFF00C9FF),
                                    activeTrackColor: const Color(0xFF00C9FF).withOpacity(0.3),
                                    inactiveThumbColor: Colors.grey,
                                    inactiveTrackColor: Colors.grey.withOpacity(0.2),
                                    onChanged: (val) async {
                                      await settings.toggleModelStatus(model.id, val);
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const Divider(color: Color(0xFF2E3245), height: 16),
                          
                          // 参数说明区
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildParamRow('接口地址', model.baseUrl),
                                const SizedBox(height: 6),
                                _buildParamRow('模型标识', model.model),
                                const SizedBox(height: 6),
                                _buildParamRow('API 密钥', '••••••••••••••••'),
                              ],
                            ),
                          ),
                          
                          // 底部控制按钮组
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              CustomButton(
                                text: '测试连接',
                                icon: Icons.sync_alt,
                                width: 100,
                                isSecondary: true,
                                isLoading: isTestingThis,
                                onPressed: () => _testModelConnection(model),
                              ),
                              const SizedBox(width: 12),
                              IconButton(
                                icon: const Icon(Icons.edit_note, color: Colors.grey, size: 22),
                                tooltip: '编辑配置',
                                onPressed: () => _showModelFormDialog(existingModel: model),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                tooltip: '删除配置',
                                onPressed: () => _confirmDeleteModel(model),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  /// 渲染键值对参数展示行
  Widget _buildParamRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: const TextStyle(color: Color(0xFFA0A5C0), fontSize: 12),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// 封装的对话框表单文本输入框
  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    bool isObscure = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFA0A5C0),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: isObscure,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF4A4E69), fontSize: 12),
            filled: true,
            fillColor: const Color(0xFF0F111A),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF2E3245), width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF2E3245), width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF00C9FF), width: 1.5),
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return '请输入$label';
            }
            return null;
          },
        ),
      ],
    );
  }
}
