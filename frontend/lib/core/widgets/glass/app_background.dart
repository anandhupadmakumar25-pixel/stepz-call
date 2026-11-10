import 'dart:math' as math;
import 'package:flutter/material.dart';

enum AppBackgroundPreset {
  pastelSky,
  abstractGradient,
  communicationWaves,
  recordingWave,
  mobileGradient,
  cleanEnterprise,
}

class AppBackground extends StatefulWidget {
  final Widget child;
  final AppBackgroundPreset preset;
  final bool animateBlobs;
  final bool showArtworkOverlay;
  final String? customArtworkAsset;
  final String? backgroundImageAsset;
  final double backgroundImageOpacity;

  const AppBackground({
    super.key,
    required this.child,
    this.preset = AppBackgroundPreset.cleanEnterprise,
    this.animateBlobs = true,
    this.showArtworkOverlay = false,
    this.customArtworkAsset,
    this.backgroundImageAsset,
    this.backgroundImageOpacity = 0.12,
  });

  @override
  State<AppBackground> createState() => _AppBackgroundState();
}

class _AppBackgroundState extends State<AppBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    );
    if (widget.animateBlobs) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Base Luxury Light Pearl Canvas
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFF8FAFC),
                    Color(0xFFF1F5F9),
                    Color(0xFFE2E8F0),
                  ],
                  stops: [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),

          // 2. High-Resolution Ambient Photographic Backdrop (if provided)
          if (widget.backgroundImageAsset != null)
            Positioned.fill(
              child: Opacity(
                opacity: widget.backgroundImageOpacity.clamp(0.04, 0.18),
                child: Image.asset(
                  widget.backgroundImageAsset!,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  errorBuilder: (_, __, ___) => const SizedBox(),
                ),
              ),
            ),

          // 3. LIVING EMERALD GREEN & ROYAL CHAMPAGNE GOLD LIQUID DROPS & ORBS
          // Placed strategically across the workspace so every glass card catches iridescent reflections
          if (widget.animateBlobs)
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final t = _controller.value;
                final phase1 = math.sin(t * math.pi);
                final phase2 = math.cos(t * math.pi);

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    // --- DROP 1: Top-Left Regal Emerald Light Reservoir ---
                    _buildGlowOrb(
                      top: -100 + (phase1 * 30),
                      left: -80 + (phase2 * 25),
                      size: 520,
                      innerColor: const Color(0xFF10B981).withValues(alpha: 0.40),
                      midColor: const Color(0xFF34D399).withValues(alpha: 0.22),
                      outerColor: const Color(0xFF6EE7B7).withValues(alpha: 0.05),
                    ),

                    // --- DROP 2: Top-Center Champagne Gold Dewdrop ---
                    _buildGlowOrb(
                      top: 40 + (phase2 * -28),
                      left: 180 + (phase1 * 35),
                      size: 380,
                      innerColor: const Color(0xFFF59E0B).withValues(alpha: 0.45),
                      midColor: const Color(0xFFFBBF24).withValues(alpha: 0.25),
                      outerColor: const Color(0xFFFEF3C7).withValues(alpha: 0.06),
                    ),

                    // --- DROP 3: Top-Right Golden Sunburst Orb ---
                    _buildGlowOrb(
                      top: -70 + (phase1 * -35),
                      right: -60 + (phase2 * -20),
                      size: 500,
                      innerColor: const Color(0xFFD4AF37).withValues(alpha: 0.42),
                      midColor: const Color(0xFFFDE68A).withValues(alpha: 0.24),
                      outerColor: const Color(0xFFFEF3C7).withValues(alpha: 0.05),
                    ),

                    // --- DROP 4: Mid-Left Imperial Emerald Glowing Drop ---
                    _buildGlowOrb(
                      top: 320 + (phase2 * 40),
                      left: -30 + (phase1 * 30),
                      size: 440,
                      innerColor: const Color(0xFF059669).withValues(alpha: 0.42),
                      midColor: const Color(0xFF10B981).withValues(alpha: 0.20),
                      outerColor: const Color(0xFFA7F3D0).withValues(alpha: 0.04),
                    ),

                    // --- DROP 5: Mid-Workspace Core Champagne Gold Pool ---
                    // Sits right behind the middle KPI metrics & chart cards
                    Positioned(
                      top: 260 + (phase1 * -35),
                      left: 280 + (phase2 * 45),
                      child: IgnorePointer(
                        child: Container(
                          width: 480,
                          height: 480,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                const Color(0xFFF59E0B).withValues(alpha: 0.38),
                                const Color(0xFFD4AF37).withValues(alpha: 0.22),
                                const Color(0xFFFEF3C7).withValues(alpha: 0.08),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.35, 0.70, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // --- DROP 6: Mid-Right Vivid Emerald Crystal Orb ---
                    _buildGlowOrb(
                      top: 290 + (phase2 * -30),
                      right: 120 + (phase1 * -35),
                      size: 400,
                      innerColor: const Color(0xFF10B981).withValues(alpha: 0.40),
                      midColor: const Color(0xFF34D399).withValues(alpha: 0.20),
                      outerColor: const Color(0xFFD1FAE5).withValues(alpha: 0.05),
                    ),

                    // --- DROP 7: Lower-Left Radiant Gold Droplet ---
                    _buildGlowOrb(
                      bottom: 80 + (phase1 * 25),
                      left: 140 + (phase2 * -25),
                      size: 380,
                      innerColor: const Color(0xFFD4AF37).withValues(alpha: 0.42),
                      midColor: const Color(0xFFFCD34D).withValues(alpha: 0.22),
                      outerColor: Colors.transparent,
                    ),

                    // --- DROP 8: Bottom-Center Mint Emerald Drop ---
                    _buildGlowOrb(
                      bottom: -60 + (phase2 * 30),
                      left: 360 + (phase1 * 40),
                      size: 460,
                      innerColor: const Color(0xFF047857).withValues(alpha: 0.38),
                      midColor: const Color(0xFF10B981).withValues(alpha: 0.18),
                      outerColor: Colors.transparent,
                    ),

                    // --- DROP 9: Bottom-Right Royal Gold & Amber Aura ---
                    _buildGlowOrb(
                      bottom: -90 + (phase1 * -25),
                      right: -50 + (phase2 * 30),
                      size: 520,
                      innerColor: const Color(0xFFF59E0B).withValues(alpha: 0.40),
                      midColor: const Color(0xFFD4AF37).withValues(alpha: 0.22),
                      outerColor: Colors.transparent,
                    ),

                    // --- FLOATING MICRO-DROPS (Lively shimmering bubbles) ---
                    // Micro Drop A: Gold Pearl near top-center
                    _buildMicroDrop(
                      top: 140 + (phase1 * -18),
                      left: 340 + (phase2 * 20),
                      size: 55,
                      color: const Color(0xFFD4AF37),
                    ),

                    // Micro Drop B: Emerald Pearl near upper-right
                    _buildMicroDrop(
                      top: 210 + (phase2 * 22),
                      right: 280 + (phase1 * -15),
                      size: 65,
                      color: const Color(0xFF10B981),
                    ),

                    // Micro Drop C: Golden Dewdrop near center-right
                    _buildMicroDrop(
                      top: 480 + (phase1 * 24),
                      right: 360 + (phase2 * 18),
                      size: 48,
                      color: const Color(0xFFF59E0B),
                    ),

                    // Micro Drop D: Emerald Dewdrop near lower-left
                    _buildMicroDrop(
                      bottom: 220 + (phase2 * -20),
                      left: 380 + (phase1 * -22),
                      size: 58,
                      color: const Color(0xFF059669),
                    ),
                  ],
                );
              },
            ),

          // 4. Subtle Specular Satin Vignette
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.10),
                    Colors.transparent,
                    const Color(0xFFE2E8F0).withValues(alpha: 0.18),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),

          // 5. Custom Artwork Overlay (if requested)
          if (widget.showArtworkOverlay && widget.customArtworkAsset != null)
            Positioned(
              top: 0,
              right: 0,
              child: IgnorePointer(
                child: Image.asset(
                  widget.customArtworkAsset!,
                  height: 160,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox(),
                ),
              ),
            ),

          // 6. Child Content Layer (Holds the translucent frosted glass cards)
          Positioned.fill(
            child: widget.child,
          ),
        ],
      ),
    );
  }

  Widget _buildGlowOrb({
    double? top,
    double? bottom,
    double? left,
    double? right,
    required double size,
    required Color innerColor,
    required Color midColor,
    required Color outerColor,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                innerColor,
                midColor,
                outerColor,
                Colors.transparent,
              ],
              stops: const [0.0, 0.38, 0.72, 1.0],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMicroDrop({
    double? top,
    double? bottom,
    double? left,
    double? right,
    required double size,
    required Color color,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                color.withValues(alpha: 0.55),
                color.withValues(alpha: 0.28),
                Colors.transparent,
              ],
              stops: const [0.0, 0.45, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.25),
                blurRadius: 18,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
