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

  Uint8List? _tryDecodeBase64(String raw) {
    try {
      String clean = raw.trim();
      if (clean.contains(',')) {
        clean = clean.split(',').last.trim();
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

    final trimmedLogo = logo?.trim() ?? '';

    Widget? imageContent;

    if (trimmedLogo.isNotEmpty) {
      if (trimmedLogo.startsWith('http://') || trimmedLogo.startsWith('https://')) {
        imageContent = Image.network(
          trimmedLogo,
          width: w,
          height: h,
          fit: fit,
          errorBuilder: (_, __, ___) => _buildFallback(w, h),
        );
      } else {
        final bytes = _tryDecodeBase64(trimmedLogo);
        if (bytes != null && bytes.isNotEmpty) {
          imageContent = Image.memory(
            bytes,
            width: w,
            height: h,
            fit: fit,
            errorBuilder: (_, __, ___) => _buildFallback(w, h),
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
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: imageContent ?? _buildFallback(w, h),
        ),
      ),
    );
  }

  Widget _buildFallback(double w, double h) {
    final initial = (companyName != null && companyName!.trim().isNotEmpty)
        ? companyName!.trim().substring(0, 1).toUpperCase()
        : '';

    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
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
                  fontSize: w * 0.42,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              )
            : Icon(
                Icons.corporate_fare_rounded,
                size: w * 0.45,
                color: const Color(0xFF94A3B8),
              ),
      ),
    );
  }
}

