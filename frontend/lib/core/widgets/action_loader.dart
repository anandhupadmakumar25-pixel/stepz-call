import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Displays a sleek modal progress indicator while an async action (PDF
/// generation, WhatsApp sharing, CSV/PDF export, etc.) is running.
class ActionLoader {
  static Future<T?> run<T>(
    BuildContext context, {
    required String message,
    required Future<T> Function() task,
  }) async {
    final nav = Navigator.of(context, rootNavigator: true);
    bool dialogShown = true;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      useRootNavigator: true,
      builder: (_) => PopScope(
        canPop: false,
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(minWidth: 210, maxWidth: 300),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.16),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Color(0xFF047857),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Please wait...',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ).then((_) {
      dialogShown = false;
    });

    try {
      return await task();
    } finally {
      if (dialogShown && nav.canPop()) {
        nav.pop();
      }
    }
  }
}
