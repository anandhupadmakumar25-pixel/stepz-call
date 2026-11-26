import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../core/utils/region_detector.dart';
import '../../core/widgets/glass/glass_card.dart';
import '../../core/widgets/glass/gradient_button.dart';
import '../../providers/auth_provider.dart';
import '../../providers/lead_provider.dart';

class AddLeadDialog extends StatefulWidget {
  const AddLeadDialog({super.key});

  @override
  State<AddLeadDialog> createState() => _AddLeadDialogState();
}

class _AddLeadDialogState extends State<AddLeadDialog> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _cityController = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      setState(() => _errorMessage = 'Please fix the highlighted errors before saving.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final leadProvider = context.read<LeadProvider>();
    final success = await leadProvider.createLead({
      'raw_phone': _phoneController.text.trim(),
      'first_name': _firstNameController.text.trim(),
      'last_name': _lastNameController.text.trim(),
      'email': _emailController.text.trim(),
      'city': _cityController.text.trim(),
      'source': 'MANUAL',
    });

    setState(() => _isSubmitting = false);

    if (success && mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              const Expanded(child: Text('Lead registered successfully!')),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else if (mounted) {
      setState(() {
        _errorMessage = leadProvider.errorMessage ?? 'Failed to create lead. Please check input details.';
      });
    }
  }

  Widget _buildGlassInput({
    required TextEditingController controller,
    required String label,
    required String hint,
    IconData? prefixIcon,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    ValueChanged<String>? onFieldSubmitted,
    String? Function(String?)? validator,
    bool autofocus = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: textInputAction ?? TextInputAction.done,
          onFieldSubmitted: onFieldSubmitted ?? (_) { if (!_isSubmitting) _submit(); },
          autofocus: autofocus,
          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF0F172A)),
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
            prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 18, color: const Color(0xFF2563EB)) : null,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.danger),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveLayout.isMobile(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24,
        vertical: isMobile ? 16 : 24,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: GlassCard(
          blur: 24,
          opacity: 0.98,
          borderRadius: BorderRadius.circular(24),
          borderColor: const Color(0xFFE2E8F0),
          padding: EdgeInsets.all(isMobile ? 20 : 28),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Dialog Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Create New Lead',
                                    style: GoogleFonts.inter(
                                      fontSize: isMobile ? 16 : 18,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                  Text(
                                    'Enter lead contact details to get started',
                                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const DialogCloseButton(),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (_errorMessage != null) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFCA5A5), width: 1.2),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFFB91C1C),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => setState(() => _errorMessage = null),
                            child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF991B1B)),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Phone Number Field (ONLY Mandatory Field)
                  _buildGlassInput(
                    controller: _phoneController,
                    label: 'Phone Number *',
                    hint: 'e.g. ${RegionDetector.samplePhone(context.read<AuthProvider>().currentUser?.companyCountryIso)} or ${context.read<AuthProvider>().currentUser?.companyCountryCode ?? '+91'}${RegionDetector.samplePhone(context.read<AuthProvider>().currentUser?.companyCountryIso)}',
                    prefixIcon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    autofocus: true,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Phone number is required';
                      }
                      if (v.trim().length < 7) {
                        return 'Enter a valid phone number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Customer Name Fields (Optional)
                  if (isMobile) ...[
                    _buildGlassInput(
                      controller: _firstNameController,
                      label: 'First Name (Optional)',
                      hint: 'John',
                      prefixIcon: Icons.person_outline_rounded,
                    ),
                    const SizedBox(height: 14),
                    _buildGlassInput(
                      controller: _lastNameController,
                      label: 'Last Name (Optional)',
                      hint: 'Doe',
                      prefixIcon: Icons.person_outline_rounded,
                    ),
                  ] else
                    Row(
                      children: [
                        Expanded(
                          child: _buildGlassInput(
                            controller: _firstNameController,
                            label: 'First Name (Optional)',
                            hint: 'John',
                            prefixIcon: Icons.person_outline_rounded,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _buildGlassInput(
                            controller: _lastNameController,
                            label: 'Last Name (Optional)',
                            hint: 'Doe',
                            prefixIcon: Icons.person_outline_rounded,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),

                  // Email & City Fields (Optional)
                  if (isMobile) ...[
                    _buildGlassInput(
                      controller: _emailController,
                      label: 'Email Address (Optional)',
                      hint: 'john.doe@example.com',
                      prefixIcon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 14),
                    _buildGlassInput(
                      controller: _cityController,
                      label: 'City (Optional)',
                      hint: '${RegionDetector.sampleCity(context.read<AuthProvider>().currentUser?.companyCountryIso)}, ${RegionDetector.sampleSecondaryCity(context.read<AuthProvider>().currentUser?.companyCountryIso)}...',
                      prefixIcon: Icons.location_on_outlined,
                    ),
                  ] else
                    Row(
                      children: [
                        Expanded(
                          child: _buildGlassInput(
                            controller: _emailController,
                            label: 'Email Address (Optional)',
                            hint: 'john.doe@example.com',
                            prefixIcon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _buildGlassInput(
                            controller: _cityController,
                            label: 'City (Optional)',
                            hint: '${RegionDetector.sampleCity(context.read<AuthProvider>().currentUser?.companyCountryIso)}, ${RegionDetector.sampleSecondaryCity(context.read<AuthProvider>().currentUser?.companyCountryIso)}...',
                            prefixIcon: Icons.location_on_outlined,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 24),

                  // Dedicated Luxury Contrast Footer Section
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.25)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        GlassSecondaryButton(
                          text: 'Cancel',
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        GradientPrimaryButton(
                          text: 'Register Lead',
                          icon: Icons.check_rounded,
                          isLoading: _isSubmitting,
                          onPressed: _submit,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
