import 'package:flutter/material.dart';

/// 炫酷渐变动效按钮 Widget
/// 
/// 具有渐变背景色（极光绿与深蓝紫渐变）、悬浮反馈及水波纹动效的高阶按钮，提升应用的整体高级设计感。
class CustomButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final double width;
  final double height;
  final bool isSecondary;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.width = 160.0,
    this.height = 45.0,
    this.isSecondary = false,
  });

  @override
  State<CustomButton> createState() => _CustomButtonState();
}

class _CustomButtonState extends State<CustomButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final buttonDisabled = widget.onPressed == null || widget.isLoading;

    // 配置非激活、次要按钮与主渐变色按钮的颜色配置
    final gradientColors = widget.isSecondary
        ? [const Color(0xFF2E3245), const Color(0xFF1E212A)]
        : buttonDisabled
            ? [const Color(0xFF2D2F39), const Color(0xFF2D2F39)]
            : _isHovered
                ? [const Color(0xFF00F2FE), const Color(0xFF9B51E0)] // 悬浮颜色发生微微位移
                : [const Color(0xFF00C9FF), const Color(0xFF92FE9D)]; // 极光绿与水绿渐变

    return MouseRegion(
      cursor: buttonDisabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onEnter: (_) {
        if (!buttonDisabled) {
          setState(() {
            _isHovered = true;
          });
        }
      },
      onExit: (_) {
        if (!buttonDisabled) {
          setState(() {
            _isHovered = false;
          });
        }
      },
      child: AnimatedScale(
        scale: _isHovered ? 1.03 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOutCubic,
        child: InkWell(
          onTap: buttonDisabled ? null : widget.onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: widget.isSecondary
                  ? Border.all(color: const Color(0xFF3E435E), width: 1.2)
                  : null,
              boxShadow: _isHovered && !buttonDisabled
                  ? [
                      BoxShadow(
                        color: gradientColors[0].withOpacity(0.4),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      )
                    ]
                  : [],
            ),
            child: Center(
              child: widget.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.icon != null) ...[
                          Icon(
                            widget.icon,
                            color: widget.isSecondary ? Colors.grey[300] : Colors.black87,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          widget.text,
                          style: TextStyle(
                            color: widget.isSecondary ? Colors.grey[200] : Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
