import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass/glass_card.dart';
import '../../core/widgets/glass/gradient_button.dart';
import '../../core/widgets/company_logo_view.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../providers/auth_provider.dart';
import '../../providers/company_provider.dart';
import '../../models/company_model.dart';
import '../companies/edit_company_dialog.dart';

class CompanyProfileTab extends StatefulWidget {
  const CompanyProfileTab({super.key});

  @override
  State<CompanyProfileTab> createState() => _CompanyProfileTabState();
}

class _CompanyProfileTabState extends State<CompanyProfileTab> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCompanyData();
    });
  }

  Future<void> _loadCompanyData() async {
    setState(() => _isLoading = true);
    try {
      await context.read<CompanyProvider>().fetchMyCompany();
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _openEditDialog(CompanyModel company) async {
    final updated = await EditCompanyDialog.show(context, company);
    if (updated == true && mounted) {
      _loadCompanyData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveLayout.isMobile(context);
    final compProv = context.watch<CompanyProvider>();
    final authUser = context.watch<AuthProvider>().currentUser;

    // Use active company or reconstruct from authUser
    final comp = compProv.activeCompanyDetail ??
        CompanyModel(
          id: authUser?.companyId ?? '',
          name: authUser?.companyName ?? 'My Company',
          logo: authUser?.companyLogo ?? '',
          contactPhone: authUser?.companyPhone ?? '',
          contactEmail: authUser?.companyEmail ?? '',
          address: authUser?.companyAddress ?? '',
          gstin: authUser?.companyGstin ?? '',
          website: authUser?.companyWebsite ?? '',
        );

    final canEdit = authUser?.isSuperAdmin == true ||
        authUser?.role == 'COMPANY_ADMIN' ||
        authUser?.role == 'ADMIN' ||
        (authUser?.hasMenuPermission('companies') ?? false);

    if (_isLoading && compProv.activeCompanyDetail == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.neonCyan),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 16,
        vertical: 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Corporate Brand Card
          GlassCard(
            borderRadius: BorderRadius.circular(20),
            borderColor: const Color(0xFFE2E8F0),
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Brand Logo
                    CompanyLogoView(
                      logo: comp.logo,
                      companyName: comp.name,
                      size: isMobile ? 64 : 80,
                      borderRadius: BorderRadius.circular(16),
                      borderColor: const Color(0xFFCBD5E1),
                    ),
                    const SizedBox(width: 16),
                    // Company Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                comp.name.isNotEmpty ? comp.name : 'Untitled Company',
                                style: GoogleFonts.inter(
                                  fontSize: isMobile ? 18 : 22,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0F172A),
                                  letterSpacing: -0.5,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF047857).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFF047857).withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  comp.status.toUpperCase(),
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF047857),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            comp.website.isNotEmpty ? comp.website : 'Official Corporate Account',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                          if (comp.gstin.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'GSTIN: ${comp.gstin}',
                              style: GoogleFonts.robotoMono(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F766E),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (canEdit && !isMobile)
                      GradientPrimaryButton(
                        text: 'Edit Profile & Logo',
                        icon: Icons.edit_rounded,
                        onPressed: () => _openEditDialog(comp),
                      ),
                  ],
                ),
                if (canEdit && isMobile) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: GradientPrimaryButton(
                      text: 'Edit Profile & Logo',
                      icon: Icons.edit_rounded,
                      onPressed: () => _openEditDialog(comp),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                const Divider(color: Color(0xFFE2E8F0), height: 1),
                const SizedBox(height: 18),

                // Corporate Details Grid
                Wrap(
                  spacing: 24,
                  runSpacing: 14,
                  children: [
                    _buildDetailItem(
                      Icons.phone_rounded,
                      'Contact Phone',
                      comp.contactPhone.isNotEmpty ? comp.contactPhone : 'Not provided',
                      const Color(0xFF0284C7),
                    ),
                    _buildDetailItem(
                      Icons.email_rounded,
                      'Contact Email',
                      comp.contactEmail.isNotEmpty ? comp.contactEmail : 'Not provided',
                      const Color(0xFF7C3AED),
                    ),
                    _buildDetailItem(
                      Icons.language_rounded,
                      'Official Website',
                      comp.website.isNotEmpty ? comp.website : 'Not provided',
                      const Color(0xFF059669),
                    ),
                    _buildDetailItem(
                      Icons.receipt_long_rounded,
                      'GSTIN / Tax ID',
                      comp.gstin.isNotEmpty ? comp.gstin : 'Not registered',
                      const Color(0xFFD97706),
                    ),
                    _buildDetailItem(
                      Icons.location_on_rounded,
                      'Registered Business Address',
                      comp.address.isNotEmpty ? comp.address : 'Not provided',
                      const Color(0xFFDC2626),
                      fullWidth: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 2. Standard Bill & Quotation Header Preview Card
          GlassCard(
            borderRadius: BorderRadius.circular(20),
            borderColor: const Color(0xFFCBD5E1),
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.preview_rounded, color: Color(0xFF4F46E5), size: 20),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Standard Bill & Quotation Header Preview',
                              style: GoogleFonts.inter(
                                fontSize: isMobile ? 14 : 16,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              'Live preview of how your brand appears on customer bills and quotes',
                              style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B), size: 20),
                      tooltip: 'Refresh',
                      onPressed: _loadCompanyData,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Visual Representation of Corporate Document Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CompanyLogoView(
                            logo: comp.logo,
                            companyName: comp.name,
                            size: 56,
                            borderRadius: BorderRadius.circular(10),
                            borderColor: const Color(0xFFCBD5E1),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  comp.name.isNotEmpty ? comp.name : 'Your Company Name',
                                  style: GoogleFonts.inter(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF1E1B4B),
                                  ),
                                ),
                                if (comp.gstin.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'GSTIN: ${comp.gstin}',
                                    style: GoogleFonts.robotoMono(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF312E81),
                                    ),
                                  ),
                                ],
                                if (comp.address.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    comp.address,
                                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF475569)),
                                  ),
                                ],
                                const SizedBox(height: 2),
                                Wrap(
                                  spacing: 12,
                                  children: [
                                    if (comp.contactPhone.isNotEmpty)
                                      Text('Phone: ${comp.contactPhone}', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                                    if (comp.contactEmail.isNotEmpty)
                                      Text('Email: ${comp.contactEmail}', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                                    if (comp.website.isNotEmpty)
                                      Text(comp.website, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF4338CA), fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFC7D2FE)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'TAX INVOICE',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF4338CA),
                                  ),
                                ),
                                Text(
                                  'INV-2026-0001',
                                  style: GoogleFonts.robotoMono(
                                    fontSize: 10,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Divider(color: Color(0xFFE2E8F0), thickness: 1, height: 1),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Sample Corporate Bill Branding',
                            style: GoogleFonts.inter(fontSize: 11, fontStyle: FontStyle.italic, color: const Color(0xFF94A3B8)),
                          ),
                          Text(
                            'Verified Corporate Layout',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF059669)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value, Color accentColor, {bool fullWidth = false}) {
    return SizedBox(
      width: fullWidth ? double.infinity : 240,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: accentColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

