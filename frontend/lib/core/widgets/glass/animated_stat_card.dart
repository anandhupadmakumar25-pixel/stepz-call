import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

class AnimatedStatCard extends StatefulWidget {
  final String title;
  final num value;
  final num? targetValue;
  final String? prefix;
  final String? suffix;
  final IconData icon;
  final LinearGradient gradient;
  final Color? accentColor;
  final String? subtitle;
  final String? trendBadge;
  final Color? trendBadgeColor;
  final double? trendPercent;
  final VoidCallback? onTap;
  final bool isLightCard;

  LinearGradient get effectiveGradient => accentColor != null
      ? LinearGradient(
          colors: [accentColor!, accentColor!.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        )
      : gradient;

  num get effectiveValue => targetValue ?? value;

  const AnimatedStatCard({
    super.key,
    required this.title,
    this.value = 0,
    this.targetValue,
    required this.icon,
    this.gradient = AppColors.primaryGradient,
    this.accentColor,
    this.prefix,
    this.suffix,
    this.subtitle,
    this.trendBadge,
    this.trendBadgeColor,
    this.trendPercent,
    this.onTap,
    this.isLightCard = false,
  });

  @override
  State<AnimatedStatCard> createState() => _AnimatedStatCardState();
}

class _AnimatedStatCardState extends State<AnimatedStatCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animation = Tween<double>(begin: 0, end: widget.effectiveValue.toDouble()).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant AnimatedStatCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.effectiveValue != widget.effectiveValue) {
      _animation = Tween<double>(
        begin: _animation.value,
        end: widget.effectiveValue.toDouble(),
      ).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryIconColor = widget.accentColor ?? AppColors.neonCyan;
    final badgeColor = widget.trendBadgeColor ?? primaryIconColor;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _isHovered ? 0.08 : 0.04),
              blurRadius: _isHovered ? 16 : 10,
              offset: Offset(0, _isHovered ? 4 : 2),
            ),
            if (_isHovered)
              BoxShadow(
                color: primaryIconColor.withValues(alpha: 0.15),
                blurRadius: 14,
                spreadRadius: 1,
              ),
            BoxShadow(
              color: const Color(0xFFD4AF37).withValues(alpha: _isHovered ? 0.15 : 0.06),
              blurRadius: 1,
              spreadRadius: 0.5,
              offset: const Offset(0, -1),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: _isHovered ? 0.95 : 0.88),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isHovered
                      ? const Color(0xFFD4AF37).withValues(alpha: 0.5)
                      : const Color(0xFFE2E8F0),
                  width: _isHovered ? 1.2 : 1.0,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: primaryIconColor.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: primaryIconColor.withValues(alpha: 0.35),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: primaryIconColor.withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          widget.icon,
                          color: primaryIconColor,
                          size: 20,
                        ),
                      ),
                      if (widget.trendBadge != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: badgeColor.withValues(alpha: 0.35),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            widget.trendBadge!,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: badgeColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) {
                      final displayed = widget.value is int
                          ? _animation.value.round().toString()
                          : _animation.value.toStringAsFixed(1);
                      return Text(
                        '${widget.prefix ?? ""}$displayed${widget.suffix ?? ""}',
                        style: GoogleFonts.inter(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                          letterSpacing: -0.6,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.title,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle!,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
