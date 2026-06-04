import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/glass_container.dart';
import '../widgets/custom_button.dart';

/// 配置设置页面 View
/// 
/// 管理并展示大语言模型 (LLM) API 配置、Emlog 博客配置以及 AI 规则 Prompt。提供配置保存及单向连接性测试。
class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _llmBaseUrlController;
  late TextEditingController _llmApiKeyController;
  late TextEditingController _llmModelController;
  late TextEditingController _emlogSiteUrlController;
  late TextEditingController _emlogApiKeyController;
  late TextEditingController _promptSingleController;
  late TextEditingController _promptListController;

  @override
  void initState() {
    super.initState();
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    _llmBaseUrlController = TextEditingController(text: settings.llmBaseUrl);
    _llmApiKeyController = TextEditingController(text: settings.llmApiKey);
    _llmModelController = TextEditingController(text: settings.llmModel);
    _emlogSiteUrlController = TextEditingController(text: settings.emlogSiteUrl);
    _emlogApiKeyController = TextEditingController(text: settings.emlogApiKey);
    _promptSingleController = TextEditingController(text: settings.promptSingle);
    _promptListController = TextEditingController(text: settings.promptList);
  }

  @override
  void dispose() {
    _llmBaseUrlController.dispose();
    _llmApiKeyController.dispose();
    _llmModelController.dispose();
    _emlogSiteUrlController.dispose();
    _emlogApiKeyController.dispose();
    _promptSingleController.dispose();
    _promptListController.dispose();
    super.dispose();
  }

  /// 显示信息通知 SnackBar
  /// 
  /// 在操作成功或失败时在底部弹出气泡进行状态反馈。
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

  /// 测试大模型接口连通性
  /// 
  /// 调用 SettingsProvider 进行连通性校验，测试完成后使用弹窗提醒连接结果。
  Future<void> _testLlm() async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final success = await settings.testLlmConnection(
      _llmBaseUrlController.text,
      _llmApiKeyController.text,
      _llmModelController.text,
    );

    if (success) {
      _showSnackBar('大模型 API 连接测试成功！', false);
    } else {
      _showSnackBar('大模型 API 连接失败，请检查配置参数及网络！', true);
    }
  }

  /// 测试 emlog 分类接口连通性
  /// 
  /// 调用 SettingsProvider 进行 emlog 校验，测试完成后使用弹窗提醒连接结果。
  Future<void> _testEmlog() async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final success = await settings.testEmlogConnection(
      _emlogSiteUrlController.text,
      _emlogApiKeyController.text,
    );

    if (success) {
      _showSnackBar('Emlog 博客 API 连接测试成功！', false);
    } else {
      _showSnackBar('Emlog 连接失败，请检查站点 URL 或 API 密钥！', true);
    }
  }

  /// 保存当前表单的设置
  /// 
  /// 进行表单验证后，调用 SettingsProvider 写入本地 SQLite 存储。
  Future<void> _saveAll() async {
    if (_formKey.currentState!.validate()) {
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      await settings.saveSettings(
        llmBaseUrl: _llmBaseUrlController.text,
        llmApiKey: _llmApiKeyController.text,
        llmModel: _llmModelController.text,
        emlogSiteUrl: _emlogSiteUrlController.text,
        emlogApiKey: _emlogApiKeyController.text,
        promptSingle: _promptSingleController.text,
        promptList: _promptListController.text,
      );
      _showSnackBar('全部配置已成功保存并同步！', false);
    }
  }

  /// 构建系统设置界面的 UI，包括标题、保存按钮以及大模型和 Prompt 的配置表单
  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 页面标题
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '系统设置 & 配置中心',
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
                    text: '保存全部配置',
                    icon: Icons.save,
                    width: 150,
                    onPressed: _saveAll,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 左右分栏：左侧是 API 配置，右侧是 Prompt 配置
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 左栏配置 API
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 大模型 API 配置卡片
                        GlassContainer(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.auto_awesome, color: Color(0xFF00C9FF), size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'AI 大模型 API 配置',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(color: Color(0xFF2E3245), height: 24),
                              _buildTextField(
                                label: 'API 接口地址 (Base URL)',
                                controller: _llmBaseUrlController,
                                hint: '例如: https://api.deepseek.com/v1 或 https://api.openai.com/v1',
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                label: 'API 密钥 (API Key)',
                                controller: _llmApiKeyController,
                                hint: '输入您大模型的 Api Key',
                                isObscure: true,
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                label: '模型名称 (Model Name)',
                                controller: _llmModelController,
                                hint: '例如: deepseek-chat, gpt-4o 等',
                              ),
                              const SizedBox(height: 20),
                              CustomButton(
                                text: '测试 AI 接口连通性',
                                icon: Icons.sync_alt,
                                width: 180,
                                isSecondary: true,
                                isLoading: settings.isTestingLlm,
                                onPressed: _testLlm,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Emlog 博客配置卡片
                        GlassContainer(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.rss_feed, color: Color(0xFF92FE9D), size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Emlog 博客发布配置',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(color: Color(0xFF2E3245), height: 24),
                              _buildTextField(
                                label: '站点网址 (Site URL)',
                                controller: _emlogSiteUrlController,
                                hint: '例如: http://www.myblog.com',
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                label: 'API 密钥 (API Token)',
                                controller: _emlogApiKeyController,
                                hint: '在 emlog 后台系统设置/API 中生成的密钥',
                                isObscure: true,
                              ),
                              const SizedBox(height: 20),
                              CustomButton(
                                text: '测试 Emlog 连通性',
                                icon: Icons.cloud_done_outlined,
                                width: 180,
                                isSecondary: true,
                                isLoading: settings.isTestingEmlog,
                                onPressed: _testEmlog,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),

                  // 右栏配置 Prompt
                  Expanded(
                    flex: 5,
                    child: GlassContainer(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.psychology_alt, color: Color(0xFF9B51E0), size: 20),
                              SizedBox(width: 8),
                              Text(
                                'AI 提取规则 Prompt 配置',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const Divider(color: Color(0xFF2E3245), height: 24),
                          _buildTextField(
                            label: '单篇文章提取 Prompt 模板',
                            controller: _promptSingleController,
                            hint: '编写指导 AI 提取正文 Markdown 结构的 Prompt 规则',
                            maxLines: 8,
                          ),
                          const SizedBox(height: 20),
                          _buildTextField(
                            label: '列表与分页提取 Prompt 模板',
                            controller: _promptListController,
                            hint: '编写指导 AI 解析列表 JSON 格式的 Prompt 规则',
                            maxLines: 8,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 封装的文本输入框组件
  /// 
  /// 拥有暗色底色、柔和圆角及高亮发光框效果，可用于单行输入或多行 Prompt 输入。
  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    bool isObscure = false,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFA0A5C0),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: isObscure,
          maxLines: isObscure ? 1 : maxLines,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF4A4E69), fontSize: 13),
            filled: true,
            fillColor: const Color(0xFF14161E),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF2E3245), width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF2E3245), width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF00C9FF), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
