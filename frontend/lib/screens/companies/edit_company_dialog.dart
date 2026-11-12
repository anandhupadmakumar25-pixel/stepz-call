import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass/glass_card.dart';
import '../../core/widgets/glass/gradient_button.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../models/company_model.dart';
import '../../providers/company_provider.dart';
import '../../providers/auth_provider.dart';

class EditCompanyDialog extends StatefulWidget {
  final CompanyModel company;

  const EditCompanyDialog({
    super.key,
    required this.company,
  });

  static Future<bool?> show(BuildContext context, CompanyModel company) {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (_) => EditCompanyDialog(company: company),
    );
  }

  @override
  State<EditCompanyDialog> createState() => _EditCompanyDialogState();
}

class _EditCompanyDialogState extends State<EditCompanyDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;
  late TextEditingController _gstinController;
  late TextEditingController _websiteController;
  late TextEditingController _logoUrlController;

  String _logoData = '';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.company.name);
    _phoneController = TextEditingController(text: widget.company.contactPhone);
    _emailController = TextEditingController(text: widget.company.contactEmail);
    _addressController = TextEditingController(text: widget.company.address);
    _gstinController = TextEditingController(text: widget.company.gstin);
    _websiteController = TextEditingController(text: widget.company.website);
    _logoData = widget.company.logo;
    _logoUrlController = TextEditingController(text: widget.company.logo.startsWith('http') ? widget.company.logo : '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _gstinController.dispose();
    _websiteController.dispose();
    _logoUrlController.dispose();
    super.dispose();
  }

  Future<void> _pickLogoFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null) {
          final ext = (file.extension ?? 'png').toLowerCase();
          final mime = (ext == 'jpg' || ext == 'jpeg') ? 'image/jpeg' : 'image/png';
          final base64String = base64Encode(file.bytes!);
          setState(() {
            _logoData = 'data:$mime;base64,$base64String';
            _logoUrlController.clear();
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking logo: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    }
  }

  Widget _buildLogoPreview() {
    Widget imageWidget;
    if (_logoData.isEmpty) {
      imageWidget = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.add_photo_alternate_outlined, size: 32, color: Color(0xFF94A3B8)),
          const SizedBox(height: 6),
          Text('No Logo Added', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8), fontWeight: FontWeight.w500)),
        ],
      );
    } else if (_logoData.startsWith('data:image')) {
      try {
        final base64Content = _logoData.split(',').last;
        final bytes = base64Decode(base64Content);
        imageWidget = Image.memory(bytes, fit: BoxFit.contain);
      } catch (_) {
        imageWidget = const Icon(Icons.broken_image_rounded, size: 32, color: Color(0xFFEF4444));
      }
    } else if (_logoData.startsWith('http')) {
      imageWidget = Image.network(
        _logoData,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_rounded, size: 32, color: Color(0xFFEF4444)),
      );
    } else {
      imageWidget = const Icon(Icons.business_rounded, size: 32, color: Color(0xFF94A3B8));
    }

    return Container(
      width: 140,
      height: 90,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(child: imageWidget),
    );
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final compProv = context.read<CompanyProvider>();
    final authProv = context.read<AuthProvider>();

    final payload = {
      'name': _nameController.text.trim(),
      'contact_phone': _phoneController.text.trim(),
      'contact_email': _emailController.text.trim(),
      'address': _addressController.text.trim(),
      'gstin': _gstinController.text.trim(),
      'website': _websiteController.text.trim(),
      'logo': _logoData.trim(),
    };

    final ok = widget.company.id.isNotEmpty
        ? await compProv.updateCompany(widget.company.id, payload)
        : await compProv.updateMyCompany(payload);

    if (ok) {
      authProv.updateCurrentUserCompanyInfo(
        name: _nameController.text.trim(),
        logo: _logoData.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        address: _addressController.text.trim(),
        gstin: _gstinController.text.trim(),
        website: _websiteController.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Company profile & standard bill logo updated successfully!'),
            backgroundColor: Color(0xFF059669),
          ),
        );
      }
    } else {
      setState(() => _isSaving = false);
      if (mounted) {
        final err = compProv.errorMessage ?? 'Failed to update company details.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveLayout.isMobile(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: isMobile ? 16 : 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: GlassCard(
          blur: 24,
          opacity: 0.98,
          borderRadius: BorderRadius.circular(24),
          borderColor: const Color(0xFFCBD5E1),
          padding: EdgeInsets.all(isMobile ? 16 : 28),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.business_rounded, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Edit Company Profile & Bill Header',
                              style: GoogleFonts.inter(
                                fontSize: isMobile ? 16 : 18,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              'Set brand logo, address, and GSTIN for all official bills & quotations',
                              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: Color(0xFFE2E8F0), height: 1),
                  const SizedBox(height: 20),

                  // Brand Logo Section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.image_rounded, size: 18, color: Color(0xFF2563EB)),
                            const SizedBox(width: 8),
                            Text(
                              'Official Company Logo',
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                            ),
                            const Spacer(),
                            if (_logoData.isNotEmpty)
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFFEF4444),
                                  visualDensity: VisualDensity.compact,
                                ),
                                icon: const Icon(Icons.delete_outline_rounded, size: 16),
                                label: const Text('Remove Logo', style: TextStyle(fontSize: 11)),
                                onPressed: () {
                                  setState(() {
                                    _logoData = '';
                                    _logoUrlController.clear();
                                  });
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLogoPreview(),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'This logo appears on official Bills, Tax Invoices, Quotations, and WhatsApp receipts.',
                                    style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                                  ),
                                  const SizedBox(height: 10),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2563EB),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    onPressed: _pickLogoFile,
                                    icon: const Icon(Icons.upload_file_rounded, size: 16),
                                    label: Text(
                                      _logoData.isEmpty ? 'Upload Logo Image' : 'Change Image',
                                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _logoUrlController,
                                    style: GoogleFonts.inter(fontSize: 11.5),
                                    decoration: InputDecoration(
                                      hintText: 'Or paste external image URL...',
                                      hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    onChanged: (val) {
                                      setState(() {
                                        _logoData = val.trim();
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Company Legal Details
                  Text('Company Name *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _nameController,
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'e.g. Stepz Digital Solutions Pvt Ltd',
                      prefixIcon: const Icon(Icons.business_outlined, size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Company Name is required' : null,
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Contact Phone *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _phoneController,
                              style: GoogleFonts.inter(fontSize: 13),
                              decoration: InputDecoration(
                                hintText: '+91 9876543210',
                                prefixIcon: const Icon(Icons.phone_outlined, size: 18),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty ? 'Phone is required' : null,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Contact Email *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _emailController,
                              style: GoogleFonts.inter(fontSize: 13),
                              decoration: InputDecoration(
                                hintText: 'billing@company.com',
                                prefixIcon: const Icon(Icons.email_outlined, size: 18),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty ? 'Email is required' : null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('GSTIN / Tax Identification No.', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _gstinController,
                              style: GoogleFonts.robotoMono(fontSize: 13, fontWeight: FontWeight.w600),
                              decoration: InputDecoration(
                                hintText: 'e.g. 32AAAAA0000A1Z5',
                                prefixIcon: const Icon(Icons.badge_outlined, size: 18),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Official Website', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _websiteController,
                              style: GoogleFonts.inter(fontSize: 13),
                              decoration: InputDecoration(
                                hintText: 'https://company.com',
                                prefixIcon: const Icon(Icons.language_rounded, size: 18),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  Text('Registered Office Address', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _addressController,
                    maxLines: 2,
                    style: GoogleFonts.inter(fontSize: 12.5),
                    decoration: InputDecoration(
                      hintText: 'e.g. Suite 400, Techno Park, Phase 1, Kochi, Kerala 682030',
                      prefixIcon: const Icon(Icons.location_on_outlined, size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      GradientPrimaryButton(
                        text: _isSaving ? 'Saving Changes...' : 'Save Company Profile',
                        icon: Icons.check_circle_rounded,
                        gradient: AppColors.primaryGradient,
                        onPressed: _isSaving ? null : _handleSave,
                      ),
                    ],
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
