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
    Color fg;

    switch (status.toUpperCase()) {
      case 'ASSIGNED':
      case 'QUALIFIED':
      case 'INTERESTED':
      case 'COMPLETED':
      case 'ACTIVE':
        fg = AppColors.neonTeal;
        break;
      case 'DUE':
      case 'CALLBACK_REQUESTED':
      case 'IN_PROGRESS':
        fg = AppColors.neonSunset;
        break;
      case 'OVERDUE':
      case 'BLOCKED':
      case 'NOT_INTERESTED':
        fg = AppColors.neonCoral;
        break;
      case 'SCHEDULED':
      case 'RESCHEDULED':
        fg = AppColors.neonViolet;
        break;
      case 'UNASSIGNED':
      default:
        fg = const Color(0xFF94A3B8);
        break;
    }

    String label = status.replaceAll('_', ' ');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: fg.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withValues(alpha: 0.35), width: 0.9),
        boxShadow: [
          BoxShadow(
            color: fg.withValues(alpha: 0.15),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
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
