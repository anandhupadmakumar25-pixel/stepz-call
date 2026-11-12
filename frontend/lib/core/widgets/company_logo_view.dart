import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Renders a corporate company logo from base64 data URI, plain base64, or network URL.
/// Falls back smoothly to a premium corporate avatar with initial or business icon.
class CompanyLogoView extends StatelessWidget {
  final String? logo;
  final String? companyName;
  final double size;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final Color? borderColor;
  final BoxFit fit;

  const CompanyLogoView({
    super.key,
    this.logo,
    this.companyName,
    this.size = 48,
    this.width,
    this.height,
    this.borderRadius,
    this.backgroundColor,
    this.borderColor,
    this.fit = BoxFit.contain,
  });

  static Uint8List? decodeBase64Safe(String raw) {
    try {
      String clean = raw.trim().replaceAll('"', '').replaceAll("'", "");
      if (clean.contains(',')) {
        clean = clean.split(',').last.trim();
      }
      clean = clean.replaceAll(RegExp(r'\s+'), '');
      if (clean.isEmpty) return null;
      final remainder = clean.length % 4;
      if (remainder != 0) {
        clean = clean.padRight(clean.length + (4 - remainder), '=');
      }
      return base64Decode(clean);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = width ?? size;
    final h = height ?? size;
    final radius = borderRadius ?? BorderRadius.circular(12);
    final border = borderColor ?? const Color(0xFFE2E8F0);
    final bg = backgroundColor ?? Colors.white;

    String cleanLogo = (logo ?? '').trim().replaceAll('"', '').replaceAll("'", "");

    Widget? imageWidget;

    if (cleanLogo.isNotEmpty) {
      if (cleanLogo.startsWith('http://') || cleanLogo.startsWith('https://')) {
        imageWidget = Image.network(
          cleanLogo,
          fit: fit,
          errorBuilder: (_, __, ___) => _buildFallback(),
        );
      } else if (cleanLogo.startsWith('/media/') || cleanLogo.startsWith('media/')) {
        final fullUrl = 'https://web-production-4e39b.up.railway.app${cleanLogo.startsWith('/') ? cleanLogo : '/$cleanLogo'}';
        imageWidget = Image.network(
          fullUrl,
          fit: fit,
          errorBuilder: (_, __, ___) => _buildFallback(),
        );
      } else {
        final bytes = decodeBase64Safe(cleanLogo);
        if (bytes != null && bytes.isNotEmpty) {
          imageWidget = Image.memory(
            bytes,
            fit: fit,
            errorBuilder: (_, __, ___) => _buildFallback(),
          );
        }
      }
    }

    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: radius,
        border: Border.all(color: border, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: SizedBox.expand(
            child: imageWidget ?? _buildFallback(),
          ),
        ),
      ),
    );
  }

  Widget _buildFallback() {
    final initial = (companyName != null && companyName!.trim().isNotEmpty)
        ? companyName!.trim().substring(0, 1).toUpperCase()
        : '';

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F766E), Color(0xFF047857), Color(0xFF065F46)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: initial.isNotEmpty
            ? Text(
                initial,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              )
            : const Icon(
                Icons.apartment_rounded,
                size: 20,
                color: Colors.white,
              ),
      ),
    );
  }
}
