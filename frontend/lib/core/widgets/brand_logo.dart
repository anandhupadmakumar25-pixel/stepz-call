import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TelecallerLogo extends StatelessWidget {
  final bool isDark;
  final double iconSize;
  final double titleSize;
  final bool showSubtitle;

  const TelecallerLogo({
    super.key,
    this.isDark = false,
    this.iconSize = 24,
    this.titleSize = 17,
    this.showSubtitle = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Luxury Imperial Emerald & Champagne Gold Shield
        Container(
          width: iconSize * 1.55,
          height: iconSize * 1.55,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF065F46), Color(0xFF047857), Color(0xFF022C22)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(iconSize * 0.45),
            border: Border.all(
              color: const Color(0xFFD4AF37),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFD4AF37).withValues(alpha: 0.35),
                blurRadius: 12,
                spreadRadius: -2,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: SizedBox(
              height: iconSize * 0.95,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildBar(const Color(0xFFFEF3C7), iconSize * 0.40),
                  const SizedBox(width: 2.2),
                  _buildBar(const Color(0xFFF59E0B), iconSize * 0.72),
                  const SizedBox(width: 2.2),
                  _buildBar(const Color(0xFFD4AF37), iconSize * 0.96),
                  const SizedBox(width: 2.2),
                  _buildBar(const Color(0xFF10B981), iconSize * 0.62),
                  const SizedBox(width: 2.2),
                  _buildBar(const Color(0xFF34D399), iconSize * 0.42),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Brand Title & Champagne Gold Badge
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'TELECALLER',
                  style: GoogleFonts.inter(
                    fontSize: titleSize,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 2),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF59E0B), Color(0xFFD4AF37)],
                    ),
                    borderRadius: BorderRadius.circular(5),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.4),
                        blurRadius: 6,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Text(
                    'PRO',
                    style: GoogleFonts.inter(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF064E3B),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            if (showSubtitle)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'ENTERPRISE CRM',
                    style: GoogleFonts.inter(
                      fontSize: titleSize * 0.48,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF047857),
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 3.5,
                    height: 3.5,
                    decoration: const BoxDecoration(
                      color: Color(0xFFD4AF37),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'CLOUD SAAS',
                    style: GoogleFonts.inter(
                      fontSize: titleSize * 0.48,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFB45309),
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildBar(Color color, double height) {
    return Container(
      width: 2.8,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.5),
            blurRadius: 4,
          ),
        ],
      ),
    );
  }
}
