import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GlassTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String? labelText;
  final String? label;
  final String? hintText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType keyboardType;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;
  final int maxLines;
  final bool enabled;
  final FocusNode? focusNode;

  final Color? textColor;
  final Color? fillColor;
  final Color? labelColor;
  final Color? borderColor;
  final Color? focusedBorderColor;
  final Color? hintColor;

  const GlassTextField({
    super.key,
    this.controller,
    this.labelText,
    this.label,
    this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.maxLines = 1,
    this.enabled = true,
    this.focusNode,
    this.textColor,
    this.fillColor,
    this.labelColor,
    this.borderColor,
    this.focusedBorderColor,
    this.hintColor,
  });

  @override
  State<GlassTextField> createState() => _GlassTextFieldState();
}

class _GlassTextFieldState extends State<GlassTextField> {
  late FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    if (mounted) {
      setState(() => _isFocused = _focusNode.hasFocus);
    }
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayLabel = widget.label ?? widget.labelText;
    final effectiveTextColor = widget.textColor ?? const Color(0xFF0F172A);
    final effectiveLabelColor = widget.labelColor ?? const Color(0xFF334155);
    final effectiveHintColor = widget.hintColor ?? const Color(0xFF94A3B8);
    final effectiveFillColor = widget.fillColor ??
        (_isFocused ? const Color(0xFFFFFFFF) : const Color(0xFFF8FAFC));
    final effectiveBorderColor = _isFocused
        ? (widget.focusedBorderColor ?? const Color(0xFF047857))
        : (widget.borderColor ?? const Color(0xFFCBD5E1));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (displayLabel != null && displayLabel.isNotEmpty) ...[
          Text(
            displayLabel,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _isFocused ? const Color(0xFF047857) : effectiveLabelColor,
            ),
          ),
          const SizedBox(height: 6),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: effectiveFillColor,
                border: Border.all(
                  color: effectiveBorderColor,
                  width: _isFocused ? 1.5 : 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _isFocused
                        ? const Color(0xFF047857).withValues(alpha: 0.12)
                        : Colors.black.withValues(alpha: 0.03),
                    blurRadius: _isFocused ? 8 : 3,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextFormField(
                controller: widget.controller,
                focusNode: _focusNode,
                obscureText: widget.obscureText,
                keyboardType: widget.keyboardType,
                onChanged: widget.onChanged,
                onFieldSubmitted: widget.onSubmitted,
                validator: widget.validator,
                maxLines: widget.maxLines,
                enabled: widget.enabled,
                cursorColor: const Color(0xFF047857),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: effectiveTextColor,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  hintStyle: GoogleFonts.inter(
                    fontSize: 13,
                    color: effectiveHintColor,
                    fontWeight: FontWeight.w400,
                  ),
                  prefixIcon: widget.prefixIcon != null
                      ? IconTheme(
                          data: IconThemeData(
                            color: _isFocused ? const Color(0xFF047857) : const Color(0xFF64748B),
                            size: 18,
                          ),
                          child: widget.prefixIcon!,
                        )
                      : null,
                  suffixIcon: widget.suffixIcon,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
