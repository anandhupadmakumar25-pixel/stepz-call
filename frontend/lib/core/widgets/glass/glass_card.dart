import 'dart:ui';
import 'package:flutter/material.dart';

class GlassCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final dynamic borderRadius;
  final double blur;
  final double? opacity;
  final Color? backgroundColor;
  final Color? borderColor;
  final Border? customBorder;
  final VoidCallback? onTap;
  final bool enableHoverEffect;
  final double? width;
  final double? height;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin,
    this.borderRadius = 18.0,
    this.blur = 16.0,
    this.opacity,
    this.backgroundColor,
    this.borderColor,
    this.customBorder,
    this.onTap,
    this.enableHoverEffect = true,
    this.width,
    this.height,
  });

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard> {
  bool _isHovered = false;

  BorderRadius _resolveRadius() {
    if (widget.borderRadius is BorderRadius) {
      return widget.borderRadius as BorderRadius;
    }
    if (widget.borderRadius is double) {
      return BorderRadius.circular(widget.borderRadius as double);
    }
    return BorderRadius.circular(18.0);
  }

  @override
  Widget build(BuildContext context) {
    final isClickable = widget.onTap != null;
    final hover = widget.enableHoverEffect && _isHovered;
    final radius = _resolveRadius();

    // Frosted Translucent Milk Glass with Champagne Gold specular framing
    final double defaultOpacity = (widget.opacity == null || widget.opacity! < 0.65) ? 0.86 : widget.opacity!;
    final Color effectiveBg = widget.backgroundColor ?? Colors.white.withValues(alpha: defaultOpacity);

    final Border effectiveBorder = widget.customBorder ??
        Border.all(
          color: widget.borderColor ??
              (hover
                  ? const Color(0xFFD4AF37).withValues(alpha: 0.70)
                  : const Color(0xFFD4AF37).withValues(alpha: 0.30)),
          width: hover ? 1.3 : 1.0,
        );

    Widget cardContent = AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: widget.width,
      height: widget.height,
      margin: widget.margin,
      transform: hover ? Matrix4.translationValues(0, -2.5, 0) : Matrix4.identity(),
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          // Soft ambient drop shadow
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: hover ? 0.08 : 0.035),
            blurRadius: hover ? 24 : 14,
            offset: Offset(0, hover ? 8 : 4),
          ),
          // Subtle warm champagne gold glow on hover
          if (hover)
            BoxShadow(
              color: const Color(0xFFD4AF37).withValues(alpha: 0.25),
              blurRadius: 18,
              spreadRadius: 1,
            ),
          // Specular crisp top highlight
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.9),
            blurRadius: 1,
            spreadRadius: 0.5,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: widget.blur, sigmaY: widget.blur),
          child: Container(
            padding: widget.padding,
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: widget.backgroundColor == null
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: (defaultOpacity + 0.08).clamp(0.0, 0.94)),
                        Colors.white.withValues(alpha: (defaultOpacity - 0.06).clamp(0.0, 0.94)),
                      ],
                    )
                  : null,
              color: widget.backgroundColor != null ? effectiveBg : null,
              border: effectiveBorder,
            ),
            child: widget.child,
          ),
        ),
      ),
    );

    if (widget.enableHoverEffect || isClickable) {
      return MouseRegion(
        cursor: isClickable ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: isClickable ? GestureDetector(onTap: widget.onTap, child: cardContent) : cardContent,
      );
    }

    return cardContent;
  }
}

class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color? color;
  final Border? border;
  final double blur;

  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 16.0,
    this.color,
    this.border,
    this.blur = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            gradient: color == null
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.88),
                      Colors.white.withValues(alpha: 0.74),
                    ],
                  )
                : null,
            color: color,
            border: border ??
                Border.all(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.28),
                  width: 1.0,
                ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.035),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
