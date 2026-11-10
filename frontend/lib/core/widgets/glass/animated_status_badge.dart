import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

class AnimatedStatusBadge extends StatefulWidget {
  final String? status;
  final String? label;
  final String? customLabel;
  final Color? statusColor;
  final bool animateDot;

  const AnimatedStatusBadge({
    super.key,
    this.status,
    this.label,
    this.customLabel,
    this.statusColor,
    this.animateDot = true,
  });

  @override
  State<AnimatedStatusBadge> createState() => _AnimatedStatusBadgeState();
}

class _AnimatedStatusBadgeState extends State<AnimatedStatusBadge> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    if (widget.animateDot) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Color _getStatusColor(String s) {
    switch (s.toUpperCase()) {
      case 'QUALIFIED':
      case 'COMPLETED':
      case 'ACTIVE':
      case 'INTERESTED':
        return AppColors.success;
      case 'IN_PROGRESS':
      case 'CONTACTED':
      case 'BUSY':
        return AppColors.neonCyan;
      case 'CALLBACK_REQUESTED':
      case 'SCHEDULED':
      case 'DUE':
        return AppColors.warning;
      case 'NOT_INTERESTED':
      case 'NO_ANSWER':
      case 'CANCELLED':
      case 'OVERDUE':
        return AppColors.danger;
      case 'BLOCKED':
        return const Color(0xFFEF4444);
      case 'ASSIGNED':
        return AppColors.accentViolet;
      case 'UNASSIGNED':
      default:
        return const Color(0xFF94A3B8);
    }
  }

  String _formatStatus(String s) {
    return s.replaceAll('_', ' ');
  }

  @override
  Widget build(BuildContext context) {
    final effectiveStatus = widget.status ?? widget.label ?? 'STATUS';
    final color = widget.statusColor ?? _getStatusColor(effectiveStatus);
    final textLabel = widget.label ?? widget.customLabel ?? _formatStatus(effectiveStatus);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.35),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: widget.animateDot ? _pulseAnimation.value : 1.0),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.6),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 6),
          Text(
            textLabel,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
