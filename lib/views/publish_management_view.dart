import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/settings_provider.dart';
import '../widgets/glass_container.dart';
import '../widgets/custom_button.dart';

/// 发布管理页面 View
/// 
/// 展示发布平台渠道卡片（已支持 EMLOG），支持点击卡片弹出对应 API 配置表单。
class PublishManagementView extends StatefulWidget {
  const PublishManagementView({super.key});

  @override
  State<PublishManagementView> createState() => _PublishManagementViewState();
}

class _PublishManagementViewState extends State<PublishManagementView> {
  final _emlogFormKey = GlobalKey<FormState>();
  
  late TextEditingController _emlogSiteUrlController;
  late TextEditingController _emlogApiKeyController;

  @override
  void initState() {
    super.initState();
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    _emlogSiteUrlController = TextEditingController(text: settings.emlogSiteUrl);
    _emlogApiKeyController = TextEditingController(text: settings.emlogApiKey);
  }

  @override
  void dispose() {
    _emlogSiteUrlController.dispose();
    _emlogApiKeyController.dispose();
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
  Future<void> _testEmlogConnectionInDialog(StateSetter setDialogState, SettingsProvider settings) async {
    setDialogState(() {}); 
    final success = await settings.testEmlogConnection(
      _emlogSiteUrlController.text,
      _emlogApiKeyController.text,
    );
    _showSnackBar(
      success ? 'Emlog 博客 API 连接测试成功！' : 'Emlog 连接失败，请检查站点 URL 或 API 密钥！',
      !success,
    );
    setDialogState(() {}); 
  }

  /// 保存 Emlog API 配置
  Future<void> _saveEmlogConfig(SettingsProvider settings) async {
    if (_emlogFormKey.currentState!.validate()) {
      await settings.saveSettings(
        llmBaseUrl: settings.llmBaseUrl,
        llmApiKey: settings.llmApiKey,
        llmModel: settings.llmModel,
        emlogSiteUrl: _emlogSiteUrlController.text,
        emlogApiKey: _emlogApiKeyController.text,
        promptSingle: settings.promptSingle,
        promptList: settings.promptList,
      );
      Navigator.of(context).pop();
      _showSnackBar('Emlog 配置已成功保存！', false);
    }
  }

  /// 弹出 Emlog API 具体的配置对话框表单
  void _showEmlogConfigDialog(SettingsProvider settings) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF14161E) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: isDark ? const Color(0xFF2E3245) : const Color(0xFFD2D6DC), width: 1.5),
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
                  Text(
                    '配置 EMLOG 博客发布接口',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87, 
                      fontSize: 18, 
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 450,
                child: Form(
                  key: _emlogFormKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTextField(
                        label: '站点网址 (Site URL)',
                        controller: _emlogSiteUrlController,
                        hint: '例如: http://www.myblog.com',
                        isDark: isDark,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        label: 'API 密钥 (API Token)',
                        controller: _emlogApiKeyController,
                        hint: '在 emlog 后台系统设置/API 中生成的密钥',
                        isObscure: true,
                        isDark: isDark,
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
                  child: Text('取消', style: TextStyle(color: isDark ? Colors.grey : Colors.black54)),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final hasEmlogConfig = settings.emlogSiteUrl.isNotEmpty && settings.emlogApiKey.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 页面标题及顶部说明
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '发布渠道管理',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 单栏自适应宽屏卡片列表
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. EMLOG 卡片
                _buildPlatformCard(
                  title: 'EMLOG',
                  hasConfig: hasEmlogConfig,
                  configInfo: hasEmlogConfig ? '已对接: ${settings.emlogSiteUrl}' : '点击配置并连接测试 EMLOG api 发布接口。',
                  icon: Icons.rss_feed,
                  iconColor: const Color(0xFF92FE9D),
                  iconBgColor: isDark ? const Color(0xFF1E2D24) : const Color(0xFFE2FBE9),
                  isDark: isDark,
                  showWebsiteLink: true,
                  onTap: () => _showEmlogConfigDialog(settings),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 构建发布平台的横幅卡片，响应多主题交互。
  Widget _buildPlatformCard({
    required String title,
    required bool hasConfig,
    required String configInfo,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required bool isDark,
    bool showWebsiteLink = false,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: GlassContainer(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // 平台 Icon 背景圈
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: iconColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
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
                          Text(
                            title,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // 状态标识
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: hasConfig
                                  ? const Color(0xFF103020)
                                  : const Color(0xFF331515),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              hasConfig ? '已配置' : '未配置',
                              style: TextStyle(
                                color: hasConfig
                                    ? const Color(0xFF92FE9D)
                                    : const Color(0xFFFFA0A0),
                                fontSize: 10,
                              ),
                            ),
                          ),
                          if (showWebsiteLink) ...[
                            const SizedBox(width: 12),
                            InkWell(
                              onTap: () async {
                                final url = Uri.parse('https://www.emlog.net');
                                if (await canLaunchUrl(url)) {
                                  await launchUrl(url);
                                }
                              },
                              child: Text(
                                'emlog官网',
                                style: TextStyle(
                                  color: isDark ? const Color(0xFF00C9FF) : const Color(0xFF00A2D8),
                                  fontSize: 12,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        configInfo,
                        style: TextStyle(
                          color: isDark ? Colors.grey : Colors.black54,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: isDark ? Colors.grey : Colors.black38,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 封装的文本输入框组件
  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    bool isObscure = false,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark ? const Color(0xFFA0A5C0) : Colors.black54,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: isObscure,
          maxLines: 1,
          style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: isDark ? const Color(0xFF4A4E69) : Colors.black38, fontSize: 13),
            filled: true,
            fillColor: isDark ? const Color(0xFF14161E) : Colors.white,
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
