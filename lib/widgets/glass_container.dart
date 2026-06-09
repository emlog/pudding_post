import 'dart:ui';
import 'package:flutter/material.dart';

/// 现代毛玻璃效果卡片容器 Widget
/// 
/// 提供具有高斯模糊背景、精致边框和柔和阴影的卡片效果，适合用于暗黑科技风界面的模块化分栏。
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double blur;
  final double opacity;
  final Color? borderColor;
  final Gradient? borderGradient;
  final List<BoxShadow>? shadow;

  const GlassContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.borderRadius = 16.0,
    this.blur = 12.0,
    this.opacity = 0.1,
    this.borderColor,
    this.borderGradient,
    this.shadow,
  });

  @override
  Widget build(BuildContext context) {
    // 默认的渐变边框，从左上角的浅亮极光蓝淡入到右下角的暗灰，创造立体光源感
    final defaultGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        const Color(0xFF00C9FF).withOpacity(0.4),
        const Color(0xFF2E3245).withOpacity(0.15),
      ],
    );

    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: shadow ??
            [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Stack(
            children: [
              // 内容容器主体，去除原有的 Container border 以免干扰
              Container(
                padding: padding,
                width: width,
                height: height,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E212A).withOpacity(opacity),
                  borderRadius: BorderRadius.circular(borderRadius),
                ),
                child: child,
              ),
              // 上覆的渐变/单色高精度边框绘制层
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _GlassBorderPainter(
                      width: 1.5,
                      radius: borderRadius,
                      borderColor: borderColor,
                      borderGradient: borderGradient ?? (borderColor == null ? defaultGradient : null),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 用于在毛玻璃容器上绘制高精度渐变边框或单色边框的画笔类
class _GlassBorderPainter extends CustomPainter {
  final double width;
  final double radius;
  final Color? borderColor;
  final Gradient? borderGradient;

  _GlassBorderPainter({
    required this.width,
    required this.radius,
    this.borderColor,
    this.borderGradient,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 对绘制区域做半个线宽 (width/2) 的内缩调整，避免圆角边缘线溢出 ClipRRect 边界导致部分缺失
    final rect = Offset(width / 2, width / 2) & Size(size.width - width, size.height - width);
    final RRect rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius - width / 2));
    
    final paint = Paint()
      ..strokeWidth = width
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    if (borderGradient != null) {
      paint.shader = borderGradient!.createShader(Offset.zero & size);
    } else {
      paint.color = borderColor ?? const Color(0xFF2E3245).withOpacity(0.4);
    }

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _GlassBorderPainter oldDelegate) {
    return oldDelegate.width != width ||
        oldDelegate.radius != radius ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.borderGradient != borderGradient;
  }
}
