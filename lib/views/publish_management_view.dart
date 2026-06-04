import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/glass_container.dart';
import '../widgets/custom_button.dart';

/// 发布管理页面 View
/// 
/// 展示发布平台渠道卡片（默认 Emlog），支持点击卡片弹出 API 配置表单，并支持管理 AI 提取 Prompt 规则。
class PublishManagementView extends StatefulWidget {
  const PublishManagementView({super.key});

  @override
  State<PublishManagementView> createState() => _PublishManagementViewState();
}

class _PublishManagementViewState extends State<PublishManagementView> {
  final _formKey = GlobalKey<FormState>();
  final _promptFormKey = GlobalKey<FormState>();
  
  late TextEditingController _emlogSiteUrlController;
  late TextEditingController _emlogApiKeyController;
  late TextEditingController _promptSingleController;
  late TextEditingController _promptListController;

  @override
  void initState() {
    super.initState();
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    _emlogSiteUrlController = TextEditingController(text: settings.emlogSiteUrl);
    _emlogApiKeyController = TextEditingController(text: settings.emlogApiKey);
    _promptSingleController = TextEditingController(text: settings.promptSingle);
    _promptListController = TextEditingController(text: settings.promptList);
  }

  @override
  void dispose() {
    _emlogSiteUrlController.dispose();
    _emlogApiKeyController.dispose();
    _promptSingleController.dispose();
    _promptListController.dispose();
    super.dispose();
  }

  /// 显示反馈通知 SnackBar
  /// 
  /// [message] 为通知的文本内容，[isError] 标记是否为错误类型（以红色背景提示）
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

  /// 测试 Emlog 接口的连通性
  /// 
  /// 读取输入框临时配置参数，调用 Provider 发送测试请求
  Future<void> _testEmlogConnectionInDialog(StateSetter setDialogState, SettingsProvider settings) async {
    setDialogState(() {}); // 触发弹窗内部 Loading 状态更新
    final success = await settings.testEmlogConnection(
      _emlogSiteUrlController.text,
      _emlogApiKeyController.text,
    );
    _showSnackBar(
      success ? 'Emlog 博客 API 连接测试成功！' : 'Emlog 连接失败，请检查站点 URL 或 API 密钥！',
      !success,
    );
    setDialogState(() {}); // 测试完毕更新 Loading
  }

  /// 保存 Emlog API 配置
  /// 
  /// 验证输入格式正确后，同步至 SettingsProvider 写入本地持久化存储
  Future<void> _saveEmlogConfig(SettingsProvider settings) async {
    if (_formKey.currentState!.validate()) {
      await settings.saveSettings(
        llmBaseUrl: settings.llmBaseUrl,
        llmApiKey: settings.llmApiKey,
        llmModel: settings.llmModel,
        emlogSiteUrl: _emlogSiteUrlController.text,
        emlogApiKey: _emlogApiKeyController.text,
        promptSingle: _promptSingleController.text,
        promptList: _promptListController.text,
      );
      Navigator.of(context).pop();
      _showSnackBar('Emlog 配置已成功保存！', false);
    }
  }

  /// 保存 AI 提取规则 Prompt 的修改
  /// 
  /// 读取输入框最新规则，写入本地 SQLite 存储
  Future<void> _savePromptSettings(SettingsProvider settings) async {
    await settings.saveSettings(
      llmBaseUrl: settings.llmBaseUrl,
      llmApiKey: settings.llmApiKey,
      llmModel: settings.llmModel,
      emlogSiteUrl: _emlogSiteUrlController.text,
      emlogApiKey: _emlogApiKeyController.text,
      promptSingle: _promptSingleController.text,
      promptList: _promptListController.text,
    );
    _showSnackBar('AI 提取规则 Prompt 已成功保存！', false);
  }

  /// 弹出 Emlog API 具体的配置对话框表单
  /// 
  /// 含有 API 接口地址、Token 填写框以及连接测试按钮
  void _showEmlogConfigDialog(SettingsProvider settings) {
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
              title: Row(
                children: [
                  Image.network(
                    'https://www.emlog.net/views/default/images/logo.png',
                    width: 24,
                    height: 24,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.rss_feed,
                      color: Color(0xFF92FE9D),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '配置 Emlog 博客发布接口',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: SizedBox(
                width: 450,
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                    ],
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              actions: [
                CustomButton(
                  text: '测试连通性',
                  icon: Icons.cloud_done_outlined,
                  width: 130,
                  isSecondary: true,
                  isLoading: settings.isTestingEmlog,
                  onPressed: () => _testEmlogConnectionInDialog(setDialogState, settings),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消', style: TextStyle(color: Colors.grey)),
                ),
                CustomButton(
                  text: '保存配置',
                  icon: Icons.check,
                  width: 110,
                  onPressed: () => _saveEmlogConfig(settings),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final hasEmlogConfig = settings.emlogSiteUrl.isNotEmpty && settings.emlogApiKey.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 页面标题及 Prompt 保存按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '发布渠道 & AI 提取规则管理',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '在此管理您的博客发布渠道 API，并可定制专门用来提取文章信息的 AI 提取指令 Prompt。',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                CustomButton(
                  text: '保存 AI 规则配置',
                  icon: Icons.save,
                  width: 180,
                  onPressed: () => _savePromptSettings(settings),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 分栏布局：左侧发布卡片，右侧为 Prompt 配置卡片
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 左侧发布渠道展示（emlog 卡片）
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '支持的发布渠道',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFA0A5C0),
                        ),
                      ),
                      const SizedBox(height: 12),
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () => _showEmlogConfigDialog(settings),
                          child: GlassContainer(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  // Emlog Logo 背景圈
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E2D24),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0xFF2B4D36),
                                        width: 1,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.rss_feed,
                                      color: Color(0xFF92FE9D),
                                      size: 32,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Text(
                                              'Emlog 博客系统',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            // 状态标识
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: hasEmlogConfig
                                                    ? const Color(0xFF103020)
                                                    : const Color(0xFF331515),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                hasEmlogConfig ? '已配置' : '未配置',
                                                style: TextStyle(
                                                  color: hasEmlogConfig
                                                      ? const Color(0xFF92FE9D)
                                                      : const Color(0xFFFFA0A0),
                                                  fontSize: 10,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          hasEmlogConfig
                                              ? '已对接: ${settings.emlogSiteUrl}'
                                              : '点击此处即可具体配置并连接测试 emlog api 发布接口。',
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 12,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.arrow_forward_ios,
                                    color: Colors.grey,
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),

                // 右侧 AI 提取规则 Prompt 配置卡片
                Expanded(
                  flex: 5,
                  child: Form(
                    key: _promptFormKey,
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
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 封装的文本输入框组件
  /// 
  /// [label] 标题，[controller] 控制器，[hint] 占位说明文字，[isObscure] 是否密码输入，[maxLines] 最大行数
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
