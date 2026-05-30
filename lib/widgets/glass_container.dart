import 'dart:ui';
import 'package:flutter/material.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final Color color;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BoxBorder? border;
  final List<BoxShadow>? boxShadow;
  final double? width;
  final double? height;
  final Gradient? gradientBorder;
  final Gradient? gradient;

  const GlassContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.blur = 20.0,
    this.opacity = 0.07,
    this.color = Colors.white,
    this.borderRadius,
    this.padding,
    this.margin,
    this.border,
    this.gradientBorder,
    this.boxShadow,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        boxShadow: boxShadow,
        borderRadius: borderRadius,
      ),
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.zero,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: color.withOpacity(opacity),
              borderRadius: borderRadius,
              border: gradientBorder == null
                  ? (border ??
                      Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1.0,
                      ))
                  : null,
              gradient: gradient ??
                  LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color.withOpacity(opacity),
                      color.withOpacity(opacity * 0.5),
                    ],
                  ),
            ),
            child: gradientBorder != null
                ? Container(
                    decoration: BoxDecoration(
                      borderRadius: borderRadius,
                      border: Border.all(color: Colors.transparent),
                      gradient: gradientBorder,
                    ),
                    child: child,
                  )
                : child,
          ),
        ),
      ),
    );
  }
}
