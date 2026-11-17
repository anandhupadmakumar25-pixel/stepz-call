import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GlassTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String? labelText;
  final String? label;
  final String? hintText;
  final String? errorText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType keyboardType;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;
  final AutovalidateMode? autovalidateMode;
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
    this.errorText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.autovalidateMode,
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
    return FormField<String>(
      initialValue: widget.controller?.text,
      validator: widget.validator,
      autovalidateMode: widget.autovalidateMode ?? AutovalidateMode.onUserInteraction,
      builder: (fieldState) {
        final currentError = widget.errorText ?? fieldState.errorText;
        final hasError = currentError != null && currentError.isNotEmpty;

        final displayLabel = widget.label ?? widget.labelText;
        final effectiveTextColor = widget.textColor ?? const Color(0xFF0F172A);
        final effectiveLabelColor = hasError
            ? const Color(0xFFDC2626)
            : (_isFocused ? (widget.focusedBorderColor ?? const Color(0xFF047857)) : (widget.labelColor ?? const Color(0xFF334155)));
        final effectiveHintColor = widget.hintColor ?? const Color(0xFF94A3B8);
        final effectiveFillColor = hasError
            ? const Color(0xFFFFF1F2)
            : (widget.fillColor ?? (_isFocused ? const Color(0xFFFFFFFF) : const Color(0xFFF8FAFC)));
        final effectiveBorderColor = hasError
            ? const Color(0xFFEF4444)
            : (_isFocused
                ? (widget.focusedBorderColor ?? const Color(0xFF047857))
                : (widget.borderColor ?? const Color(0xFFCBD5E1)));

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
                  color: effectiveLabelColor,
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
                      width: hasError || _isFocused ? 1.5 : 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: hasError
                            ? const Color(0xFFEF4444).withValues(alpha: 0.12)
                            : (_isFocused
                                ? const Color(0xFF047857).withValues(alpha: 0.12)
                                : Colors.black.withValues(alpha: 0.03)),
                        blurRadius: _isFocused || hasError ? 8 : 3,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focusNode,
                    obscureText: widget.obscureText,
                    keyboardType: widget.keyboardType,
                    onChanged: (val) {
                      fieldState.didChange(val);
                      if (widget.onChanged != null) widget.onChanged!(val);
                    },
                    onSubmitted: widget.onSubmitted,
                    maxLines: widget.maxLines,
                    enabled: widget.enabled,
                    cursorColor: hasError ? const Color(0xFFDC2626) : const Color(0xFF047857),
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
                                color: hasError
                                    ? const Color(0xFFDC2626)
                                    : (_isFocused ? const Color(0xFF047857) : const Color(0xFF64748B)),
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
            if (hasError) ...[
              const SizedBox(height: 5),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 13, color: Color(0xFFDC2626)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        currentError,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFDC2626),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
