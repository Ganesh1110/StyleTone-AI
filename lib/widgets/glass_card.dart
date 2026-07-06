import 'dart:ui';
import 'package:flutter/material.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final BoxBorder? border;

  const GlassCard({
    super.key,
    required this.child,
    this.blur = 10.0,
    this.opacity = 0.18,
    this.borderRadius,
    this.padding,
    this.margin,
    this.color,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final defaultRadius = borderRadius ?? BorderRadius.circular(20);
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: defaultRadius,
        border: border ?? Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 30,
            spreadRadius: -5,
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: defaultRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding ?? const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: color ?? Colors.white.withOpacity(opacity),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
