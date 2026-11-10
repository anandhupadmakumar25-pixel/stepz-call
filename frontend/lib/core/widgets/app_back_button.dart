import 'package:flutter/material.dart';
import '../../screens/layout/main_layout.dart';

class AppBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String? fallbackRoute;
  final String tooltip;
  final Color? color;

  const AppBackButton({
    super.key,
    this.onPressed,
    this.fallbackRoute,
    this.tooltip = 'Back',
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        icon: Icon(
          Icons.arrow_back_ios_new_rounded,
          color: color ?? const Color(0xFF0F172A),
          size: 14,
        ),
        tooltip: tooltip,
        onPressed: () {
          if (onPressed != null) {
            onPressed!();
          } else if (Navigator.canPop(context)) {
            Navigator.pop(context);
          } else if (MainLayout.goToDashboard(context)) {
            return;
          } else if (fallbackRoute != null) {
            Navigator.pushReplacementNamed(context, fallbackRoute!);
          } else {
            Navigator.pushReplacementNamed(context, '/dashboard');
          }
        },
      ),
    );
  }
}
