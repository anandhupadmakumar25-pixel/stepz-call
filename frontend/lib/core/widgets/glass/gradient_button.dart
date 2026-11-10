import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

class GradientPrimaryButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final dynamic icon;
  final String text;
  final LinearGradient? gradient;
  final bool isLoading;
  final double height;
  final double borderRadius;
  final EdgeInsetsGeometry padding;

  const GradientPrimaryButton({
    super.key,
    required this.onPressed,
    required this.text,
    this.icon,
    this.gradient,
    this.isLoading = false,
    this.height = 44.0,
    this.borderRadius = 10.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
  });

  @override
  State<GradientPrimaryButton> createState() => _GradientPrimaryButtonState();
}

class _GradientPrimaryButtonState extends State<GradientPrimaryButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  Widget? _buildIconWidget() {
    if (widget.icon == null) return null;
    if (widget.icon is IconData) {
      return Icon(widget.icon as IconData, size: 18, color: Colors.white);
    }
    if (widget.icon is Widget) {
      return widget.icon as Widget;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onPressed != null && !widget.isLoading;
    final activeGradient = widget.gradient ?? AppColors.primaryGradient;
    final iconWidget = _buildIconWidget();

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() {
        _isHovered = false;
        _isPressed = false;
      }),
      cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: isEnabled ? widget.onPressed : null,
        child: AnimatedScale(
          scale: _isPressed ? 0.97 : (_isHovered && isEnabled ? 1.02 : 1.0),
          duration: const Duration(milliseconds: 150),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: widget.height,
            padding: widget.padding,
            decoration: BoxDecoration(
              gradient: isEnabled
                  ? activeGradient
                  : LinearGradient(
                      colors: [Colors.grey.shade700, Colors.grey.shade800],
                    ),
              borderRadius: BorderRadius.circular(widget.borderRadius),
              boxShadow: [
                if (isEnabled)
                  BoxShadow(
                    color: (_isHovered
                            ? activeGradient.colors.first
                            : activeGradient.colors.first)
                        .withValues(alpha: _isHovered ? 0.45 : 0.25),
                    blurRadius: _isHovered ? 16 : 8,
                    offset: Offset(0, _isHovered ? 4 : 2),
                  ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.isLoading) ...[
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 10),
                ] else if (iconWidget != null) ...[
                  iconWidget,
                  const SizedBox(width: 8),
                ],
                Text(
                  widget.text,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// GOLDEN GLASS LITE BUTTON (Back / Cancel)
// Features warm champagne gold glass with gold drops glow
// ==========================================
class GlassSecondaryButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final dynamic icon;
  final String text;
  final double height;
  final double borderRadius;
  final Color? textColor;
  final Color? borderColor;
  final bool showGoldDrop;

  const GlassSecondaryButton({
    super.key,
    required this.onPressed,
    required this.text,
    this.icon,
    this.height = 42.0,
    this.borderRadius = 10.0,
    this.textColor,
    this.borderColor,
    this.showGoldDrop = true,
  });

  @override
  State<GlassSecondaryButton> createState() => _GlassSecondaryButtonState();
}

class _GlassSecondaryButtonState extends State<GlassSecondaryButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  Widget? _buildIconWidget() {
    if (widget.icon == null) return null;
    final iconColor = widget.textColor ?? const Color(0xFF92400E);
    if (widget.icon is IconData) {
      return Icon(widget.icon as IconData, size: 16, color: iconColor);
    }
    if (widget.icon is Widget) {
      return widget.icon as Widget;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final iconWidget = _buildIconWidget();
    final effectiveTextColor = widget.textColor ?? const Color(0xFF92400E);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() {
        _isHovered = false;
        _isPressed = false;
      }),
      cursor: widget.onPressed != null ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _isPressed ? 0.97 : (_isHovered ? 1.02 : 1.0),
          duration: const Duration(milliseconds: 150),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: widget.height,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFFFEF3C7).withValues(alpha: _isHovered ? 0.95 : 0.82),
                  const Color(0xFFFDE68A).withValues(alpha: _isHovered ? 0.85 : 0.68),
                ],
              ),
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: Border.all(
                color: widget.borderColor ??
                    const Color(0xFFD4AF37).withValues(alpha: _isHovered ? 0.85 : 0.45),
                width: 1.1,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD4AF37).withValues(alpha: _isHovered ? 0.28 : 0.12),
                  blurRadius: _isHovered ? 12 : 6,
                  offset: const Offset(0, 2),
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.90),
                  blurRadius: 1,
                  offset: const Offset(0, -0.5),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.showGoldDrop) ...[
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFD4AF37),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.60),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (iconWidget != null) ...[
                  iconWidget,
                  const SizedBox(width: 7),
                ],
                Text(
                  widget.text,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: effectiveTextColor,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Alias for explicit GoldenGlassButton usage
typedef GoldenGlassButton = GlassSecondaryButton;

// ==========================================
// CIRCULAR GOLDEN GLASS CLOSE BUTTON (For Dialog Headers)
// ==========================================
class DialogCloseButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final double size;

  const DialogCloseButton({
    super.key,
    this.onPressed,
    this.size = 32.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7).withValues(alpha: 0.75),
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFFD4AF37).withValues(alpha: 0.45),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.12),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF92400E)),
        onPressed: onPressed ?? () => Navigator.of(context).pop(),
        tooltip: 'Close',
      ),
    );
  }
}

// ==========================================
// CONTRAST DIALOG FOOTER SECTION
// Gives every popup a dedicated luxury action bar
// ==========================================
class DialogFooterSection extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  const DialogFooterSection({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(20, 14, 20, 14),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        border: Border(
          top: BorderSide(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.20),
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: children,
      ),
    );
  }
}
