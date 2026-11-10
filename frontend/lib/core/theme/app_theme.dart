import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Prestige Light Grey & Ivory Canvas Palette (Zero heavy black)
  static const Color canvasLightGrey = Color(0xFFF1F5F9);
  static const Color pearlWhite = Color(0xFFF8FAFC);
  static const Color softGrey = Color(0xFFE2E8F0);
  static const Color background = Color(0xFFF1F5F9);
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color sidebarBackground = Color(0xFFFFFFFF);
  static const Color sidebarNavy = Color(0xFFFFFFFF);
  static const Color navBackground = Color(0xFFFFFFFF);

  // Pristine Surfaces & Pure White Elevations
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSecondary = Color(0xFFF8FAFC);
  static const Color surfaceElevated = Color(0xFFFFFFFF);
  static const Color cardWhite = Color(0xFFFFFFFF);

  // Subtle Champagne Gold & Platinum Borders
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderThin = Color(0xFFEDE8E0);
  static const Color borderSubtle = Color(0xFFF1EFEA);
  static const Color cardBorder = Color(0x33D4AF37); // 0.20 subtle champagne gold border

  // Glassmorphism Tokens for Light Palette (Crisp Frosted Milk Glass)
  static const Color glassSurface = Color(0xF5FFFFFF); // 0.96 white milk glass
  static const Color glassSurfaceLight = Color(0xFAFFFFFF);
  static const Color glassCard = Color(0xFFFFFFFF);
  static const Color glassCardSubtle = Color(0xF2FFFFFF);
  static const Color glassCardFill = Color(0xFFFFFFFF);
  static const Color glassCardHover = Color(0xFFFFFFFF);
  static const Color glassBorder = Color(0x33D4AF37); // Champagne Gold Hairline
  static const Color glassCardBorder = Color(0x2BD4AF37);
  static const Color glassBorderHighlight = Color(0x66D4AF37);
  static const Color glassBorderGold = Color(0x80D4AF37);
  static const Color glassBorderCyan = Color(0x40047857);

  // Imperial Emerald Green Jewel Tones
  static const Color emerald = Color(0xFF047857);
  static const Color emeraldDark = Color(0xFF064E3B);
  static const Color emeraldLight = Color(0xFFECFDF5);
  static const Color emeraldMint = Color(0xFF10B981);
  static const Color indigo = Color(0xFF047857); // Primary Action is Imperial Emerald
  static const Color indigoAccent = Color(0xFF059669);
  static const Color accentViolet = Color(0xFF065F46);
  static const Color accentVioletLight = Color(0xFFD1FAE5);
  static const Color accentVioletDark = Color(0xFF022C22);

  // Royal Champagne & Brushed Gold Jewel Tones
  static const Color goldLuxury = Color(0xFFD4AF37); // Royal Metallic Gold
  static const Color goldLuxuryDark = Color(0xFFB45309); // Deep Amber Gold
  static const Color goldLuxuryLight = Color(0xFFFEF3C7); // Soft Champagne Tint
  static const Color goldAccent = Color(0xFFF59E0B);
  static const Color sapphireRoyal = Color(0xFF1D4ED8);
  static const Color sapphireGlow = Color(0xFF0284C7);

  // Neon Aliases mapped to Emerald & Gold System
  static const Color neonViolet = Color(0xFFD4AF37); // Gold
  static const Color neonCyan = Color(0xFF047857); // Imperial Emerald
  static const Color neonTeal = Color(0xFF059669);
  static const Color neonCoral = Color(0xFFDC2626);
  static const Color neonPeach = Color(0xFFD97706);
  static const Color neonSunset = Color(0xFFD97706);
  static const Color neonPink = Color(0xFFBE185D);
  static const Color neonLavender = Color(0xFF047857);

  // High-Contrast Executive Charcoal & Slate Typography (Crisp readability on light grey)
  static const Color textPrimary = Color(0xFF0F172A); // Deep Executive Charcoal
  static const Color textSecondary = Color(0xFF334155); // Rich Slate
  static const Color textMuted = Color(0xFF64748B); // Soft Slate
  static const Color textDark = Color(0xFF0F172A);
  static const Color textDarkSecondary = Color(0xFF334155);
  static const Color textDarkMuted = Color(0xFF64748B);
  static const Color charcoal = Color(0xFF0F172A);
  static const Color charcoalBody = Color(0xFF334155);
  static const Color charcoalMuted = Color(0xFF64748B);

  // Status Indicators
  static const Color mint = Color(0xFF059669); // Active / Success
  static const Color success = Color(0xFF059669);
  static const Color successLight = Color(0xFFECFDF5);
  static const Color coral = Color(0xFFDC2626); // Suspended / Error
  static const Color danger = Color(0xFFDC2626);
  static const Color dangerLight = Color(0xFFFEF2F2);
  static const Color amber = Color(0xFFD97706); // Pending / Warning
  static const Color warning = Color(0xFFD97706);
  static const Color warningLight = Color(0xFFFFFBEB);
  static const Color cyan = Color(0xFF0284C7); // Info / Audio
  static const Color info = Color(0xFF0284C7);
  static const Color infoLight = Color(0xFFF0F9FF);

  // Navigation
  static const Color navHover = Color(0x0F047857);
  static const Color navActive = Color(0xFF047857);
  static const Color primaryDark = Color(0xFF064E3B);
  static const Color secondaryDark = Color(0xFF022C22);

  // Flowing Luxury Emerald & Champagne Gold Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF065F46), Color(0xFF047857), Color(0xFF059669)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient luxuryGoldGradient = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFD4AF37), Color(0xFFB45309)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient emeraldGoldGradient = LinearGradient(
    colors: [Color(0xFF064E3B), Color(0xFF047857), Color(0xFFD4AF37)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient sapphireGradient = LinearGradient(
    colors: [Color(0xFF0284C7), Color(0xFF0369A1), Color(0xFF075985)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient coralGradient = LinearGradient(
    colors: [Color(0xFFF87171), Color(0xFFDC2626), Color(0xFFB91C1C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cyanGradient = LinearGradient(
    colors: [Color(0xFF059669), Color(0xFF047857), Color(0xFF065F46)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient emeraldGradient = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF059669), Color(0xFF047857)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient sunsetGradient = LinearGradient(
    colors: [Color(0xFFD97706), Color(0xFFD4AF37), Color(0xFF047857)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient glassCardGradient = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFF8FAFC)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppTheme {
  static ThemeData get lightTheme {
    final textTheme = GoogleFonts.interTextTheme(ThemeData.light().textTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.canvasLightGrey,
      primaryColor: AppColors.emerald,
      colorScheme: const ColorScheme.light(
        primary: AppColors.emerald,
        secondary: AppColors.goldLuxury,
        surface: AppColors.surface,
        error: AppColors.coral,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.textPrimary,
      ),
      textTheme: textTheme.copyWith(
        displayLarge: GoogleFonts.inter(
          fontSize: 30,
          fontWeight: FontWeight.w900,
          color: AppColors.textPrimary,
          letterSpacing: -1.0,
        ),
        displayMedium: GoogleFonts.inter(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
          letterSpacing: -0.7,
        ),
        headlineMedium: GoogleFonts.inter(
          fontSize: 19,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          letterSpacing: -0.4,
        ),
        titleLarge: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          letterSpacing: -0.2,
        ),
        titleMedium: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.textSecondary,
          height: 1.5,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: AppColors.textSecondary,
          height: 1.45,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: AppColors.textMuted,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
          letterSpacing: 0.1,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0x33D4AF37), width: 1.0),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
        labelStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.emerald, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.coral, width: 1.0),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.emerald,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.2),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.emerald,
          elevation: 0,
          side: const BorderSide(color: AppColors.goldLuxury, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE2E8F0),
        thickness: 1,
        space: 1,
      ),
    );
  }

  // Set darkTheme alias to lightTheme so the entire app is fully Light Grey & Champagne Gold / Emerald Green
  static ThemeData get darkTheme => lightTheme;
}
