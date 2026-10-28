import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  final bool isCallback;

  const StatusBadge({
    super.key,
    required this.status,
    this.isCallback = false,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;

    switch (status.toUpperCase()) {
      case 'ASSIGNED':
      case 'QUALIFIED':
      case 'INTERESTED':
      case 'COMPLETED':
        bg = AppColors.successLight;
        fg = AppColors.success;
        break;
      case 'DUE':
      case 'CALLBACK_REQUESTED':
      case 'IN_PROGRESS':
        bg = AppColors.warningLight;
        fg = AppColors.warning;
        break;
      case 'OVERDUE':
      case 'BLOCKED':
      case 'NOT_INTERESTED':
        bg = AppColors.dangerLight;
        fg = AppColors.danger;
        break;
      case 'SCHEDULED':
      case 'RESCHEDULED':
        bg = AppColors.accentVioletLight;
        fg = AppColors.accentViolet;
        break;
      case 'UNASSIGNED':
      default:
        bg = AppColors.surfaceSecondary;
        fg = AppColors.textSecondary;
        break;
    }

    String label = status.replaceAll('_', ' ');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withValues(alpha: 0.25), width: 1),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}
