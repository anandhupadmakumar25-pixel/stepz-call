import 'dart:math';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass/glass_card.dart';
import '../../core/widgets/glass/gradient_button.dart';
import '../../core/widgets/glass/glass_text_field.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../core/widgets/app_back_button.dart';
import '../../routes/app_routes.dart';
import '../../models/company_model.dart';
import '../../providers/company_provider.dart';
import '../../providers/auth_provider.dart';
import '../admin/super_admin_management_dialog.dart';
import '../../core/widgets/company_logo_view.dart';
import 'renew_plan_dialog.dart';
import 'renewal_request_dialog.dart';
import '../../models/company_subscription_history_model.dart';
import '../../models/company_renewal_request_model.dart';

class CompanyDirectoryScreen extends StatefulWidget {
  const CompanyDirectoryScreen({super.key});

  @override
  State<CompanyDirectoryScreen> createState() => _CompanyDirectoryScreenState();
}

class _CompanyDirectoryScreenState extends State<CompanyDirectoryScreen> {
  final Map<String, String> _availableMenus = {
    'branches': 'Branches & Multi-Office',
    'employees': 'Telecaller Team & Staff',
    'attendance': 'Stepz Attendance & Geofencing',
    'leads': 'Lead Workspace & Import',
    'tasks': 'Calling Tasks & Allocation',
    'recordings': 'Audio Call Recordings',
    'callbacks': 'Priority Callbacks & Reminders',
    'call_history': 'Call Logs & History',
    'analytics': 'Analytics & Performance Reports',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final compProv = context.read<CompanyProvider>();
      compProv.fetchCompanies();
      compProv.fetchPlans();
      compProv.fetchSuperAdmins();
      compProv.fetchRenewalRequests();
      compProv.fetchSubscriptionHistory();
    });
  }

  String _generateTempPassword() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#\$';
    final rnd = Random.secure();
    return List.generate(10, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  void _showCredentialsModal({
    required String companyName,
    required String adminEmail,
    required String tempPassword,
    required String planName,
    required List<String> allowedMenus,
  }) {
    bool obscurePassword = false;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) {
        final isMobile = ResponsiveLayout.isMobile(ctx);
        return StatefulBuilder(
          builder: (context, setModalState) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: isMobile ? 16 : 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: GlassCard(
                blur: 24,
                opacity: 0.96,
                borderRadius: BorderRadius.circular(24),
                borderColor: const Color(0xFFD4AF37),
                padding: EdgeInsets.all(isMobile ? 16 : 28),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFD4AF37)),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: const Icon(Icons.key_rounded, color: Color(0xFF92400E), size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tenant Admin Credentials',
                                  style: GoogleFonts.inter(fontSize: isMobile ? 15 : 18, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                                ),
                                Text(
                                  'Temporary login credentials for $companyName',
                                  style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          DialogCloseButton(onPressed: () => Navigator.pop(ctx)),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Notice
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Color(0xFF047857), size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Company created successfully. Share these temporary login details with the tenant administrator.',
                                style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF065F46), fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Credentials Box
                      Container(
                        padding: EdgeInsets.all(isMobile ? 12 : 18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('LOGIN EMAIL', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF94A3B8))),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    adminEmail,
                                    style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy_rounded, size: 16, color: Color(0xFF2563EB)),
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: adminEmail));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Admin email copied to clipboard!'), duration: Duration(seconds: 1)),
                                    );
                                  },
                                ),
                              ],
                            ),
                            const Divider(color: Color(0xFFE2E8F0), height: 14),

                            Text('TEMPORARY PASSWORD', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF94A3B8))),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    obscurePassword ? '••••••••••••' : tempPassword,
                                    style: GoogleFonts.robotoMono(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF92400E),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(obscurePassword ? Icons.visibility_rounded : Icons.visibility_off_rounded, size: 18, color: const Color(0xFF64748B)),
                                  onPressed: () => setModalState(() => obscurePassword = !obscurePassword),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy_rounded, size: 16, color: Color(0xFFD4AF37)),
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: tempPassword));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Temporary password copied!'), duration: Duration(seconds: 1)),
                                    );
                                  },
                                ),
                              ],
                            ),
                            const Divider(color: Color(0xFFE2E8F0), height: 14),

                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('SUBSCRIPTION PLAN', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF94A3B8))),
                                    const SizedBox(height: 3),
                                    Text(planName, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFD4AF37)),
                                  ),
                                  child: Text(
                                    '${allowedMenus.length} Modules Allowed',
                                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF92400E)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Permitted modules tags
                      const SizedBox(height: 14),
                      Text('Permitted Sidebar Modules:', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF64748B))),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: allowedMenus.map((m) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: Text(_availableMenus[m] ?? m, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF1D4ED8))),
                          );
                        }).toList(),
                      ),

                      // Footer actions
                      Container(
                        margin: const EdgeInsets.only(top: 20),
                        padding: const EdgeInsets.only(top: 14),
                        decoration: const BoxDecoration(
                          border: Border(top: BorderSide(color: Color(0x33D4AF37), width: 1.0)),
                        ),
                        child: Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () {
                                final credentialsText = '''--- Stepz CRM Tenant Credentials ---
Company: $companyName
Admin Email: $adminEmail
Temporary Password: $tempPassword
Plan: $planName
Permitted Modules: ${allowedMenus.join(', ')}
Login URL: https://app.stepzcrm.com
------------------------------------''';
                                Clipboard.setData(ClipboardData(text: credentialsText));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('All credentials copied formatted to clipboard!'), backgroundColor: AppColors.success),
                                );
                              },
                              icon: const Icon(Icons.copy_all_rounded, size: 15, color: Color(0xFF92400E)),
                              label: Text('Copy All', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF92400E))),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFD4AF37)),
                                backgroundColor: const Color(0xFFFEF3C7),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                            GradientPrimaryButton(
                              text: 'Done',
                              icon: Icons.check_rounded,
                              onPressed: () => Navigator.pop(ctx),
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
      },
    );
  }

  void _showCreateCompanyDialog() {
    final compProv = context.read<CompanyProvider>();
    final compNameController = TextEditingController();
    final adminEmailController = TextEditingController();
    final phoneController = TextEditingController();
    final subdomainController = TextEditingController();
    final adminNameController = TextEditingController();
    final addressController = TextEditingController();
    final gstinController = TextEditingController();
    final websiteController = TextEditingController();
    final tempPasswordController = TextEditingController(text: _generateTempPassword());
    String logoData = '';

    String selectedPlanId = compProv.plans.isNotEmpty ? compProv.plans.first.code : 'starter';
    final Set<String> selectedMenus = {'branches', 'employees', 'leads', 'tasks', 'recordings', 'callbacks', 'call_history', 'analytics'};
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (ctx) {
        final isMobile = ResponsiveLayout.isMobile(ctx);
        return StatefulBuilder(
          builder: (context, setDlgState) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: isMobile ? 16 : 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 580),
              child: GlassCard(
                blur: 24,
                opacity: 0.96,
                borderRadius: BorderRadius.circular(24),
                padding: EdgeInsets.all(isMobile ? 16 : 28),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.business_rounded, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Provision New Company Tenant',
                              style: GoogleFonts.inter(fontSize: isMobile ? 15 : 16, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          DialogCloseButton(onPressed: () => Navigator.of(ctx).pop()),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Creates tenant workspace, initial admin credentials, temporary password, and assigned menu permissions.',
                        style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 16),

                      // Basic Info
                      if (isMobile) ...[
                        GlassTextField(label: 'Company Name *', hintText: 'e.g. Apex Global', controller: compNameController),
                        const SizedBox(height: 12),
                        GlassTextField(label: 'Subdomain / Slug', hintText: 'apex', controller: subdomainController),
                      ] else
                        Row(
                          children: [
                            Expanded(child: GlassTextField(label: 'Company Name *', hintText: 'e.g. Apex Global', controller: compNameController)),
                            const SizedBox(width: 12),
                            Expanded(child: GlassTextField(label: 'Subdomain / Slug', hintText: 'apex', controller: subdomainController)),
                          ],
                        ),
                      const SizedBox(height: 12),

                      if (isMobile) ...[
                        GlassTextField(label: 'Admin Email Address *', hintText: 'admin@company.com', controller: adminEmailController),
                        const SizedBox(height: 12),
                        GlassTextField(label: 'Admin Full Name', hintText: 'John Doe', controller: adminNameController),
                      ] else
                        Row(
                          children: [
                            Expanded(child: GlassTextField(label: 'Admin Email Address *', hintText: 'admin@company.com', controller: adminEmailController)),
                            const SizedBox(width: 12),
                            Expanded(child: GlassTextField(label: 'Admin Full Name', hintText: 'John Doe', controller: adminNameController)),
                          ],
                        ),
                      const SizedBox(height: 12),
                      GlassTextField(label: 'Contact Phone', hintText: '+91 9876543210', controller: phoneController),
                      const SizedBox(height: 14),

                      // Company Logo Image Picker
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.image_outlined, size: 16, color: Color(0xFF2563EB)),
                                const SizedBox(width: 6),
                                Text('Company Brand Logo (Appears on Bills)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                                const Spacer(),
                                if (logoData.isNotEmpty)
                                  InkWell(
                                    onTap: () => setDlgState(() => logoData = ''),
                                    child: Text('Clear', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFEF4444), fontWeight: FontWeight.w600)),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                CompanyLogoView(
                                  logo: logoData,
                                  companyName: compNameController.text,
                                  size: 52,
                                  borderRadius: BorderRadius.circular(10),
                                  borderColor: const Color(0xFFCBD5E1),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    onPressed: () async {
                                      try {
                                        final res = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
                                        if (res != null && res.files.isNotEmpty && res.files.first.bytes != null) {
                                          final f = res.files.first;
                                          final ext = (f.extension ?? 'png').toLowerCase();
                                          final mime = (ext == 'jpg' || ext == 'jpeg') ? 'image/jpeg' : 'image/png';
                                          final b64 = base64Encode(f.bytes!);
                                          setDlgState(() => logoData = 'data:$mime;base64,$b64');
                                        }
                                      } catch (_) {}
                                    },
                                    icon: const Icon(Icons.upload_file_rounded, size: 15),
                                    label: Text(logoData.isEmpty ? 'Upload Logo' : 'Change Logo', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      if (isMobile) ...[
                        GlassTextField(label: 'GSTIN / Tax ID', hintText: '32AAAAA0000A1Z5', controller: gstinController),
                        const SizedBox(height: 12),
                        GlassTextField(label: 'Website', hintText: 'https://company.com', controller: websiteController),
                      ] else
                        Row(
                          children: [
                            Expanded(child: GlassTextField(label: 'GSTIN / Tax ID', hintText: '32AAAAA0000A1Z5', controller: gstinController)),
                            const SizedBox(width: 12),
                            Expanded(child: GlassTextField(label: 'Website', hintText: 'https://company.com', controller: websiteController)),
                          ],
                        ),
                      const SizedBox(height: 12),
                      GlassTextField(label: 'Registered Office Address', hintText: 'Full business address for invoice header...', controller: addressController, maxLines: 2),
                      const SizedBox(height: 14),

                      // Temporary Password Field with Regenerate Button
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: GlassTextField(
                              label: 'Temporary Password (Auto-Generated) *',
                              hintText: '••••••••',
                              controller: tempPasswordController,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: OutlinedButton.icon(
                              onPressed: () {
                                setDlgState(() {
                                  tempPasswordController.text = _generateTempPassword();
                                });
                              },
                              icon: const Icon(Icons.refresh_rounded, size: 15, color: Color(0xFF92400E)),
                              label: Text('Regen', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF92400E))),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFD4AF37)),
                                backgroundColor: const Color(0xFFFEF3C7),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Subscription Plan Selector
                      Text('Subscription Plan Tier *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: compProv.plans.any((p) => p.code == selectedPlanId)
                                ? selectedPlanId
                                : (compProv.plans.isNotEmpty ? compProv.plans.first.code : null),
                            isExpanded: true,
                            dropdownColor: Colors.white,
                            style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF0F172A), fontWeight: FontWeight.w600),
                            items: compProv.plans.map((p) {
                              return DropdownMenuItem<String>(
                                value: p.code,
                                child: Row(
                                  children: [
                                    Flexible(child: Text(p.name, overflow: TextOverflow.ellipsis)),
                                    const SizedBox(width: 8),
                                    Text('(${p.currencySymbol}${p.priceMonthly.toStringAsFixed(0)}/mo)', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF047857), fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setDlgState(() {
                                  selectedPlanId = val;
                                  final plan = compProv.plans.firstWhere((p) => p.code == val, orElse: () => compProv.plans.first);
                                  if (plan.allowedMenus.isNotEmpty) {
                                    selectedMenus.clear();
                                    selectedMenus.addAll(plan.allowedMenus);
                                  }
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Allowed Menus Checkboxes
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Allowed Sidebar Modules (Permissions)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                              Text('Control which menus and features this company can access', style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B))),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(
                                onPressed: () => setDlgState(() => selectedMenus.addAll(_availableMenus.keys)),
                                child: Text('All', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF2563EB))),
                              ),
                              TextButton(
                                onPressed: () => setDlgState(() => selectedMenus.clear()),
                                child: Text('None', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFFDC2626))),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: _availableMenus.entries.map((entry) {
                            final isChecked = selectedMenus.contains(entry.key);
                            return CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              title: Text(entry.value, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
                              subtitle: entry.key == 'branches'
                                  ? Text('Required for company to create and manage branches', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF047857), fontWeight: FontWeight.w600))
                                  : null,
                              value: isChecked,
                              activeColor: const Color(0xFF047857),
                              onChanged: (val) {
                                setDlgState(() {
                                  if (val == true) {
                                    selectedMenus.add(entry.key);
                                  } else {
                                    selectedMenus.remove(entry.key);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ),

                      // Actions Footer
                      Container(
                        margin: const EdgeInsets.only(top: 20),
                        padding: const EdgeInsets.only(top: 14),
                        decoration: const BoxDecoration(
                          border: Border(top: BorderSide(color: Color(0x33D4AF37), width: 1.0)),
                        ),
                        child: Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            GlassSecondaryButton(
                              text: 'Cancel',
                              onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(),
                            ),
                            GradientPrimaryButton(
                              text: isSubmitting ? 'Provisioning...' : 'Provision Company',
                              icon: isSubmitting ? Icons.hourglass_top_rounded : Icons.check_rounded,
                              onPressed: isSubmitting
                                  ? null
                                  : () async {
                                      final compName = compNameController.text.trim();
                                      final adminEmail = adminEmailController.text.trim();
                                      final adminPass = tempPasswordController.text.trim();

                                      final messenger = ScaffoldMessenger.of(context);
                                      if (compName.isEmpty || adminEmail.isEmpty || adminPass.isEmpty) {
                                        messenger.showSnackBar(
                                          const SnackBar(content: Text('Please fill Company Name, Admin Email, and Temporary Password.'), backgroundColor: AppColors.danger),
                                        );
                                        return;
                                      }

                                      setDlgState(() => isSubmitting = true);
                                      final nav = Navigator.of(ctx);
                                      final companyProvider = context.read<CompanyProvider>();

                                      final result = await companyProvider.createCompanyWithCredentials({
                                        'name': compName,
                                        'admin_email': adminEmail,
                                        'admin_password': adminPass,
                                        'admin_first_name': adminNameController.text.trim().isNotEmpty ? adminNameController.text.trim() : 'Admin',
                                        if (phoneController.text.trim().isNotEmpty) 'contact_phone': phoneController.text.trim(),
                                        if (subdomainController.text.trim().isNotEmpty) 'subdomain': subdomainController.text.trim(),
                                        if (logoData.trim().isNotEmpty) 'logo': logoData.trim(),
                                        if (addressController.text.trim().isNotEmpty) 'address': addressController.text.trim(),
                                        if (gstinController.text.trim().isNotEmpty) 'gstin': gstinController.text.trim(),
                                        if (websiteController.text.trim().isNotEmpty) 'website': websiteController.text.trim(),
                                        'plan_id': selectedPlanId,
                                        'allowed_menus': selectedMenus.toList(),
                                      });

                                      if (result != null && mounted) {
                                        nav.pop();
                                        final company = result['company'] as CompanyModel;
                                        final plan = compProv.plans.firstWhere((p) => p.code == selectedPlanId, orElse: () => compProv.plans.first);
                                        _showCredentialsModal(
                                          companyName: company.name,
                                          adminEmail: result['admin_email'] ?? adminEmail,
                                          tempPassword: result['temp_password'] ?? adminPass,
                                          planName: plan.name,
                                          allowedMenus: selectedMenus.toList(),
                                        );
                                      } else if (mounted) {
                                        setDlgState(() => isSubmitting = false);
                                        final err = companyProvider.errorMessage ?? 'Failed to provision company. Please check input values.';
                                        messenger.showSnackBar(
                                          SnackBar(
                                            content: Text(err),
                                            backgroundColor: AppColors.danger,
                                            duration: const Duration(seconds: 4),
                                          ),
                                        );
                                      }
                                    },
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
      },
    );
  }

  void _showPermissionsDialog(CompanyModel company) {
    final compProv = context.read<CompanyProvider>();
    final Set<String> selectedMenus = Set.from(company.allowedMenus);
    String selectedPlanId = company.planCode;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (ctx) {
        final isMobile = ResponsiveLayout.isMobile(ctx);
        return StatefulBuilder(
          builder: (context, setPermState) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: isMobile ? 16 : 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: GlassCard(
                blur: 24,
                opacity: 0.96,
                borderRadius: BorderRadius.circular(24),
                padding: EdgeInsets.all(isMobile ? 16 : 26),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.tune_rounded, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Manage Module Permissions',
                                  style: GoogleFonts.inter(fontSize: isMobile ? 15 : 16, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                                ),
                                Text(
                                  'Tenant: ${company.name}',
                                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          DialogCloseButton(onPressed: () => Navigator.pop(ctx)),
                        ],
                      ),
                      const SizedBox(height: 16),

                      Text('Subscription Tier', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: compProv.plans.any((p) => p.code == selectedPlanId)
                                ? selectedPlanId
                                : (compProv.plans.isNotEmpty ? compProv.plans.first.code : null),
                            isExpanded: true,
                            dropdownColor: Colors.white,
                            style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF0F172A), fontWeight: FontWeight.w600),
                            items: compProv.plans.map((p) {
                              return DropdownMenuItem<String>(
                                value: p.code,
                                child: Text('${p.name} (${p.currencySymbol}${p.priceMonthly.toStringAsFixed(0)}/mo)', overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setPermState(() => selectedPlanId = val);
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Text('Allowed Sidebar Menus:', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: _availableMenus.entries.map((entry) {
                            final isChecked = selectedMenus.contains(entry.key);
                            return CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              title: Text(entry.value, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
                              subtitle: entry.key == 'branches'
                                  ? Text('Enable multi-branch addition for this company', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF047857), fontWeight: FontWeight.w600))
                                  : null,
                              value: isChecked,
                              activeColor: const Color(0xFF047857),
                              onChanged: (val) {
                                setPermState(() {
                                  if (val == true) {
                                    selectedMenus.add(entry.key);
                                  } else {
                                    selectedMenus.remove(entry.key);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ),

                      // Actions
                      Container(
                        margin: const EdgeInsets.only(top: 20),
                        padding: const EdgeInsets.only(top: 14),
                        decoration: const BoxDecoration(
                          border: Border(top: BorderSide(color: Color(0x33D4AF37), width: 1.0)),
                        ),
                        child: Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            GlassSecondaryButton(text: 'Cancel', onPressed: () => Navigator.pop(ctx)),
                            GradientPrimaryButton(
                              text: 'Save Permissions',
                              icon: Icons.check_circle_rounded,
                              onPressed: () async {
                                final nav = Navigator.of(ctx);
                                final messenger = ScaffoldMessenger.of(context);
                                final success = await compProv.updateCompanyPermissions(
                                  company.id,
                                  selectedMenus.toList(),
                                  planId: selectedPlanId,
                                );
                                if (success && mounted) {
                                  nav.pop();
                                  messenger.showSnackBar(
                                    SnackBar(content: Text('Permissions updated for ${company.name}!'), backgroundColor: AppColors.success),
                                  );
                                }
                              },
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
      },
    );
  }

  void _showResetPasswordDialog(CompanyModel company) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (ctx) {
        final isMobile = ResponsiveLayout.isMobile(ctx);
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 20, vertical: 20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: GlassCard(
              blur: 24,
              opacity: 0.96,
              borderRadius: BorderRadius.circular(20),
              padding: EdgeInsets.all(isMobile ? 18 : 24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFD4AF37)),
                          ),
                          child: const Icon(Icons.lock_reset_rounded, color: Color(0xFF92400E), size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Generate New Temp Password',
                            style: GoogleFonts.inter(fontSize: isMobile ? 15 : 16, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                          ),
                        ),
                        DialogCloseButton(onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'This will generate a fresh secure temporary password for the admin of "${company.name}" (${company.adminEmail}).',
                      style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
                    ),
                    Container(
                      margin: const EdgeInsets.only(top: 20),
                      padding: const EdgeInsets.only(top: 14),
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: Color(0x33D4AF37), width: 1.0)),
                      ),
                      child: Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          GlassSecondaryButton(text: 'Cancel', onPressed: () => Navigator.pop(ctx)),
                          GradientPrimaryButton(
                            text: 'Generate Password',
                            icon: Icons.key_rounded,
                            onPressed: () async {
                              final nav = Navigator.of(ctx);
                              final res = await context.read<CompanyProvider>().resetCompanyAdminPassword(company.id);
                              if (res != null && mounted) {
                                nav.pop();
                                _showCredentialsModal(
                                  companyName: company.name,
                                  adminEmail: res['admin_email'] ?? company.adminEmail,
                                  tempPassword: res['temp_password'] ?? '',
                                  planName: company.planName,
                                  allowedMenus: company.allowedMenus,
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _confirmToggleStatus(CompanyModel company) {
    final willSuspend = company.isActive;
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (ctx) {
        final isMobile = ResponsiveLayout.isMobile(ctx);
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 20, vertical: 20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: GlassCard(
              blur: 24,
              opacity: 0.98,
              borderRadius: BorderRadius.circular(20),
              borderColor: willSuspend ? const Color(0xFFEF4444) : const Color(0xFF10B981),
              padding: EdgeInsets.all(isMobile ? 18 : 24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: willSuspend ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: willSuspend ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                            ),
                          ),
                          child: Icon(
                            willSuspend ? Icons.block_rounded : Icons.check_circle_rounded,
                            color: willSuspend ? const Color(0xFFDC2626) : const Color(0xFF047857),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            willSuspend ? 'Suspend Company Access?' : 'Activate Company Workspace?',
                            style: GoogleFonts.inter(
                              fontSize: isMobile ? 15 : 17,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        DialogCloseButton(onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      willSuspend
                          ? 'Are you sure you want to suspend "${company.name}"? All administrators, team managers, and telecallers belonging to this tenant will be immediately blocked from signing in until re-activated.'
                          : 'Activate "${company.name}"? Administrators and telecallers will regain immediate access to sign in and execute CRM operations.',
                      style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF475569), height: 1.4),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: willSuspend ? const Color(0xFFFFF1F2) : const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: willSuspend ? const Color(0xFFFECDD3) : const Color(0xFFBBF7D0),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            willSuspend ? Icons.info_outline_rounded : Icons.verified_user_rounded,
                            size: 16,
                            color: willSuspend ? const Color(0xFFBE123C) : const Color(0xFF15803D),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              willSuspend
                                  ? 'Current active sessions will be terminated upon token expiration.'
                                  : 'Company status will switch to ACTIVE immediately.',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: willSuspend ? const Color(0xFF9F1239) : const Color(0xFF166534),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(top: 20),
                      padding: const EdgeInsets.only(top: 14),
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: Color(0x33D4AF37), width: 1.0)),
                      ),
                      child: Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          GlassSecondaryButton(text: 'Cancel', onPressed: () => Navigator.pop(ctx)),
                          GradientPrimaryButton(
                            text: willSuspend ? 'Suspend Company' : 'Activate Company',
                            icon: willSuspend ? Icons.pause_circle_rounded : Icons.check_circle_rounded,
                            gradient: willSuspend ? AppColors.coralGradient : AppColors.cyanGradient,
                            onPressed: () async {
                              final nav = Navigator.of(ctx);
                              final messenger = ScaffoldMessenger.of(context);
                              final newStatus = willSuspend ? 'SUSPENDED' : 'ACTIVE';
                              final ok = await context.read<CompanyProvider>().updateCompanyStatus(company.id, newStatus);
                              if (ok && mounted) {
                                nav.pop();
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text('${company.name} is now $newStatus!'),
                                    backgroundColor: willSuspend ? AppColors.danger : AppColors.success,
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showRenewPlanDialog(CompanyModel company) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => RenewPlanDialog(company: company),
    ).then((val) {
      if (val == true && mounted) {
        context.read<CompanyProvider>().fetchCompanies();
      }
    });
  }

  void _showSuperAdminRequestDialog(CompanyModel comp) {
    final compProv = context.read<CompanyProvider>();
    final currentUser = context.read<AuthProvider>().currentUser;
    final isMasterAdmin = currentUser?.isRootMasterAdmin ?? false;
    final superAdmins = compProv.superAdmins;

    String? selectedTargetAdminId = comp.assignedSuperAdminId ?? (superAdmins.isNotEmpty ? superAdmins.first['id']?.toString() : null);
    String selectedRequestType = 'REASSIGNMENT';
    final notesController = TextEditingController();
    bool isSubmitting = false;

    final requestTypes = [
      {'key': 'REASSIGNMENT', 'title': 'Tenant Reassignment', 'desc': 'Request transfer to another Super Admin'},
      {'key': 'PLAN_EXTENSION', 'title': 'Plan Extension & Grace', 'desc': 'Request renewal grace period or approval'},
      {'key': 'QUOTA_UPGRADE', 'title': 'Quota & User Upgrade', 'desc': 'Request higher telecaller or lead storage capacity'},
      {'key': 'SUPPORT', 'title': 'Support & General Inquiry', 'desc': 'Send note or question directly to Master Admin'},
    ];

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.70),
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setModalState) {
          final isMobile = ResponsiveLayout.isMobile(dialogCtx);
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 20, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: GlassCard(
                blur: 24,
                opacity: 0.98,
                borderRadius: BorderRadius.circular(20),
                padding: EdgeInsets.all(isMobile ? 18 : 24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.shield_rounded, color: Color(0xFF4F46E5), size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isMasterAdmin ? 'Reassign Tenant Super Admin' : 'Super Admin Request Option',
                                  style: GoogleFonts.inter(
                                    fontSize: isMobile ? 15 : 17,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  comp.name,
                                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Current Attribution Card
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.account_balance_rounded, size: 16, color: Color(0xFF64748B)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Managing Admin: ${comp.assignedSuperAdminName.isNotEmpty ? comp.assignedSuperAdminName : (comp.createdByName.isNotEmpty ? comp.createdByName : "Platform Master")}',
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      if (isMasterAdmin) ...[
                        Text(
                          'Select Target Super Admin:',
                          style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: superAdmins.any((sa) => sa['id']?.toString() == selectedTargetAdminId)
                                  ? selectedTargetAdminId
                                  : null,
                              isExpanded: true,
                              hint: const Text('Select Super Admin'),
                              items: superAdmins.map((sa) {
                                return DropdownMenuItem<String>(
                                  value: sa['id']?.toString(),
                                  child: Text(
                                    '${sa['full_name']} (${sa['email']})',
                                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setModalState(() => selectedTargetAdminId = val);
                                }
                              },
                            ),
                          ),
                        ),
                      ] else ...[
                        Text(
                          'Request Category:',
                          style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 8),
                        ...requestTypes.map((rt) {
                          final isSelected = selectedRequestType == rt['key'];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: InkWell(
                              onTap: () => setModalState(() => selectedRequestType = rt['key']!),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFFEEF2FF) : Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected ? const Color(0xFF6366F1) : const Color(0xFFE2E8F0),
                                    width: isSelected ? 1.6 : 1.0,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                                      size: 18,
                                      color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFCBD5E1),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            rt['title']!,
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                              color: const Color(0xFF0F172A),
                                            ),
                                          ),
                                          Text(
                                            rt['desc']!,
                                            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ],

                      const SizedBox(height: 12),
                      Text(
                        'Request Notes / Details:',
                        style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: notesController,
                        maxLines: 3,
                        style: GoogleFonts.inter(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: isMasterAdmin
                              ? 'Optional notes regarding this reassignment...'
                              : 'Explain reason for reassignment, quota request, or inquiry...',
                          hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        ),
                      ),

                      const SizedBox(height: 20),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                            child: Text('Cancel', style: GoogleFonts.inter(color: const Color(0xFF64748B), fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton.icon(
                            onPressed: isSubmitting
                                ? null
                                : () async {
                                    setModalState(() => isSubmitting = true);
                                    final messenger = ScaffoldMessenger.of(context);
                                    final ok = await compProv.sendSuperAdminRequest(
                                      comp.id,
                                      requestType: isMasterAdmin ? 'REASSIGNMENT' : selectedRequestType,
                                      notes: notesController.text.trim(),
                                      targetSuperAdminId: isMasterAdmin ? selectedTargetAdminId : null,
                                    );
                                    if (mounted) {
                                      Navigator.pop(ctx);
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            isMasterAdmin
                                                ? 'Tenant reassigned successfully!'
                                                : 'Request submitted to Master Admin!',
                                          ),
                                          backgroundColor: ok ? AppColors.success : AppColors.danger,
                                        ),
                                      );
                                    }
                                  },
                            icon: const Icon(Icons.send_rounded, size: 16),
                            label: Text(
                              isMasterAdmin ? 'Confirm Reassign' : 'Submit Request',
                              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4F46E5),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showRenewalRequestsManagerDialog() {
    context.read<CompanyProvider>().fetchRenewalRequests();
    context.read<CompanyProvider>().fetchSubscriptionHistory();

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.70),
      builder: (ctx) {
        final isMobile = ResponsiveLayout.isMobile(ctx);
        int selectedTab = 0; // 0: Pending, 1: All Requests, 2: History

        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final compProv = dialogCtx.watch<CompanyProvider>();
            final pendingRequests = compProv.renewalRequests.where((r) => r.status == 'PENDING').toList();
            final allRequests = compProv.renewalRequests;
            final history = compProv.subscriptionHistory;
            final metrics = compProv.historyMetrics;

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24, vertical: isMobile ? 14 : 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 880, maxHeight: MediaQuery.of(dialogCtx).size.height * 0.88),
                child: GlassCard(
                  blur: 24,
                  opacity: 0.98,
                  borderRadius: BorderRadius.circular(20),
                  padding: EdgeInsets.all(isMobile ? 16 : 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFFDE68A)),
                            ),
                            child: const Icon(Icons.pending_actions_rounded, color: Color(0xFFD97706), size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        'Tenant Renewal Requests & Billing',
                                        style: GoogleFonts.inter(fontSize: isMobile ? 16 : 19, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (pendingRequests.isNotEmpty) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFDC2626),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          '${pendingRequests.length} Pending',
                                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Review customer renewal requests, approve plan extensions, and track payment history',
                                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(dialogCtx),
                            icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                            splashRadius: 20,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Tabs
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildRequestTabItem(
                              label: 'Pending',
                              count: pendingRequests.length,
                              isSelected: selectedTab == 0,
                              onTap: () => setDialogState(() => selectedTab = 0),
                              badgeColor: const Color(0xFFDC2626),
                            ),
                            const SizedBox(width: 8),
                            _buildRequestTabItem(
                              label: 'All Requests',
                              count: allRequests.length,
                              isSelected: selectedTab == 1,
                              onTap: () => setDialogState(() => selectedTab = 1),
                              badgeColor: const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 8),
                            _buildRequestTabItem(
                              label: 'Payment & Plan History',
                              count: history.length,
                              isSelected: selectedTab == 2,
                              onTap: () => setDialogState(() => selectedTab = 2),
                              badgeColor: const Color(0xFF059669),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Divider(color: Color(0xFFE2E8F0), height: 1),
                      const SizedBox(height: 14),

                      // Tab Content
                      Expanded(
                        child: selectedTab == 2
                            ? _buildHistoryTabView(history, metrics, isMobile)
                            : _buildRequestsTabView(
                                selectedTab == 0 ? pendingRequests : allRequests,
                                isPendingOnly: selectedTab == 0,
                                isMobile: isMobile,
                                onActionComplete: () {
                                  compProv.fetchRenewalRequests();
                                  compProv.fetchCompanies();
                                  compProv.fetchSubscriptionHistory();
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRequestTabItem({
    required String label,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
    required Color badgeColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEEF2FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF6366F1) : const Color(0xFFCBD5E1),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? const Color(0xFF4338CA) : const Color(0xFF475569),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? badgeColor : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.inter(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestsTabView(
    List<CompanyRenewalRequestModel> requests, {
    required bool isPendingOnly,
    required bool isMobile,
    required VoidCallback onActionComplete,
  }) {
    if (requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_rounded, size: 48, color: const Color(0xFFCBD5E1)),
            const SizedBox(height: 12),
            Text(
              isPendingOnly ? 'No pending renewal requests' : 'No renewal requests submitted yet',
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 4),
            Text(
              'Customer requests from expired or active companies will appear here.',
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: requests.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        final req = requests[i];
        final isPending = req.status == 'PENDING';
        final isApproved = req.status == 'APPROVED';

        Color statusColor;
        Color statusBg;
        if (isApproved) {
          statusColor = const Color(0xFF047857);
          statusBg = const Color(0xFFD1FAE5);
        } else if (isPending) {
          statusColor = const Color(0xFFD97706);
          statusBg = const Color(0xFFFEF3C7);
        } else {
          statusColor = const Color(0xFFDC2626);
          statusBg = const Color(0xFFFEE2E2);
        }

        return Container(
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isPending ? const Color(0xFFFDE68A) : const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                req.companyName,
                                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(6)),
                              child: Text(
                                req.status,
                                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: statusColor),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Requested: ${req.billingCycleDisplay} • Plan: ${req.planName.isNotEmpty ? req.planName : 'Current'}',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF4338CA)),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    req.formattedCreatedAt,
                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Details row
              Wrap(
                spacing: 16,
                runSpacing: 6,
                children: [
                  if (req.currentExpiry != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.event_outlined, size: 14, color: Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Text(
                          'Current Expiry: ${req.currentExpiry!.length >= 10 ? req.currentExpiry!.substring(0, 10) : req.currentExpiry}',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: req.isCompanyExpired ? const Color(0xFFDC2626) : const Color(0xFF475569),
                            fontWeight: req.isCompanyExpired ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  if (req.paymentReference.isNotEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.receipt_long_rounded, size: 14, color: Color(0xFF047857)),
                        const SizedBox(width: 4),
                        Text(
                          'Ref: ${req.paymentReference}',
                          style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF047857), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                ],
              ),
              if (req.notes.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                  ),
                  child: Text(
                    'Notes: "${req.notes}"',
                    style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF475569), fontStyle: FontStyle.italic),
                  ),
                ),
              ],
              if (isPending) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFFECDD3)),
                        foregroundColor: const Color(0xFFDC2626),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _confirmRejectRenewal(req, onActionComplete),
                      child: Text('Reject', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF047857),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.verified_rounded, size: 15),
                      label: Text('Approve & Extend Plan', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700)),
                      onPressed: () {
                        ApproveRenewalRequestDialog.show(context, request: req).then((ok) {
                          if (ok == true) onActionComplete();
                        });
                      },
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _confirmRejectRenewal(CompanyRenewalRequestModel req, VoidCallback onActionComplete) {
    final notesCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: Text('Reject Renewal Request', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Provide optional rejection reason for ${req.companyName}:', style: GoogleFonts.inter(fontSize: 13)),
            const SizedBox(height: 10),
            TextField(
              controller: notesCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'e.g. Payment not verified, invalid UTR...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dlgCtx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(dlgCtx);
              await context.read<CompanyProvider>().rejectRenewalRequest(req.id, adminNotes: notesCtrl.text.trim());
              onActionComplete();
            },
            child: const Text('Confirm Reject'),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTabView(
    List<CompanySubscriptionHistoryModel> history,
    SubscriptionHistoryMetrics metrics,
    bool isMobile,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // KPI row: Breakdown of how many paid Yearly, Monthly, Days, Custom Date
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _buildHistoryKpiCard('Total Renewals', '${metrics.totalRenewals}', const Color(0xFF4F46E5), const Color(0xFFEEF2FF)),
            _buildHistoryKpiCard('Yearly (Annual)', '${metrics.yearlyCount}', const Color(0xFF047857), const Color(0xFFD1FAE5)),
            _buildHistoryKpiCard('Monthly', '${metrics.monthlyCount}', const Color(0xFF0284C7), const Color(0xFFE0F2FE)),
            _buildHistoryKpiCard('Days / Custom', '${metrics.daysCount + metrics.customDateCount}', const Color(0xFFD97706), const Color(0xFFFEF3C7)),
            _buildHistoryKpiCard('Total Paid', '₹${metrics.totalRevenue.toStringAsFixed(0)}', const Color(0xFF0F766E), const Color(0xFFCCFBF1)),
          ],
        ),
        const SizedBox(height: 14),

        // History list
        Expanded(
          child: history.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history_toggle_off_rounded, size: 48, color: const Color(0xFFCBD5E1)),
                      const SizedBox(height: 10),
                      Text('No subscription extension history recorded yet.', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B))),
                    ],
                  ),
                )
              : ListView.separated(
                  itemCount: history.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final item = history[i];
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Center(
                              child: Icon(Icons.receipt_rounded, size: 18, color: Color(0xFF475569)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        item.companyName,
                                        style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEEF2FF),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        item.billingCycleDisplay,
                                        style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w700, color: const Color(0xFF4338CA)),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Plan: ${item.planName} (+${item.extensionDays} days) • New Expiry: ${item.formattedNewExpiry}',
                                  style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${item.currency} ${item.amountPaid.toStringAsFixed(0)}',
                                style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w800, color: const Color(0xFF047857)),
                              ),
                              Text(
                                item.formattedCreatedAt,
                                style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF94A3B8)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildHistoryKpiCard(String title, String value, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: textColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: textColor.withValues(alpha: 0.9))),
          const SizedBox(height: 2),
          Text(value, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: textColor)),
        ],
      ),
    );
  }

  Widget _buildCenterLifecycleBlock(CompanyModel comp, bool isMasterAdmin, {bool isMobile = false}) {
    final statusColor = comp.isPlanOverdue
        ? const Color(0xFFDC2626)
        : (comp.isExpiringSoon ? const Color(0xFFD97706) : const Color(0xFF16A34A));
    final statusBg = comp.isPlanOverdue
        ? const Color(0xFFFEF2F2)
        : (comp.isExpiringSoon ? const Color(0xFFFFFBEB) : const Color(0xFFF0FDF4));
    final statusBorder = comp.isPlanOverdue
        ? const Color(0xFFFCA5A5)
        : (comp.isExpiringSoon ? const Color(0xFFFCD34D) : const Color(0xFFBBF7D0));
    final daysText = comp.isPlanOverdue
        ? 'Subscription Expired'
        : (comp.daysUntilExpiry != null ? '${comp.daysUntilExpiry} days remaining' : 'Active Plan');

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 14, vertical: isMobile ? 6 : 8),
      margin: isMobile ? const EdgeInsets.only(top: 6, bottom: 4) : EdgeInsets.zero,
      decoration: BoxDecoration(
        color: statusBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: statusBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            comp.isPlanOverdue ? Icons.error_outline_rounded : Icons.timer_outlined,
            size: isMobile ? 14 : 16,
            color: statusColor,
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Plan Expiry: ${comp.expiryFormatted}',
                style: GoogleFonts.inter(
                  fontSize: isMobile ? 10.5 : 11.5,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                daysText,
                style: GoogleFonts.inter(
                  fontSize: isMobile ? 10 : 11,
                  fontWeight: FontWeight.w600,
                  color: statusColor.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final compProvider = context.watch<CompanyProvider>();
    final currentUser = context.watch<AuthProvider>().currentUser;
    final isMasterAdmin = currentUser?.isRootMasterAdmin ?? false;
    final isMobile = ResponsiveLayout.isMobile(context);

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          isMobile ? 12 : 28,
          isMobile ? 6 : 16,
          isMobile ? 12 : 28,
          isMobile ? 10 : 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Bar with Back Button
            Wrap(
              spacing: 10,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AppBackButton(fallbackRoute: AppRoutes.dashboard),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'Company Directory',
                                style: GoogleFonts.inter(
                                  fontSize: isMobile ? 17 : 24,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0F172A),
                                  letterSpacing: -0.5,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFD4AF37)),
                                ),
                                child: Text(
                                  '${compProvider.companies.length} Tenants',
                                  style: GoogleFonts.inter(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF92400E),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Manage tenant organizations, module permissions, and credentials',
                            style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (isMasterAdmin)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 14, vertical: isMobile ? 8 : 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          side: const BorderSide(color: Color(0xFF6366F1)),
                          backgroundColor: const Color(0xFFEEF2FF),
                        ),
                        icon: const Icon(Icons.shield_outlined, size: 16, color: Color(0xFF4338CA)),
                        label: Text(
                          isMobile ? 'Super Admins' : 'Super Admins (${compProvider.totalSuperAdmins})',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF4338CA)),
                        ),
                        onPressed: () {
                          SuperAdminManagementDialog.show(
                            context,
                            onSelectFilter: (selectedId) {
                              compProvider.setSelectedSuperAdminFilter(selectedId);
                            },
                          );
                        },
                      ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 14, vertical: isMobile ? 8 : 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        side: BorderSide(
                          color: compProvider.pendingRenewalCount > 0 ? const Color(0xFFF59E0B) : const Color(0xFFCBD5E1),
                          width: compProvider.pendingRenewalCount > 0 ? 1.5 : 1.0,
                        ),
                        backgroundColor: compProvider.pendingRenewalCount > 0 ? const Color(0xFFFFFBEB) : Colors.white,
                      ),
                      icon: Icon(
                        Icons.pending_actions_rounded,
                        size: 16,
                        color: compProvider.pendingRenewalCount > 0 ? const Color(0xFFD97706) : const Color(0xFF475569),
                      ),
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Renewal Requests',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: compProvider.pendingRenewalCount > 0 ? const Color(0xFF92400E) : const Color(0xFF334155),
                            ),
                          ),
                          if (compProvider.pendingRenewalCount > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDC2626),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${compProvider.pendingRenewalCount}',
                                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white),
                              ),
                            ),
                          ],
                        ],
                      ),
                      onPressed: _showRenewalRequestsManagerDialog,
                    ),
                    GradientPrimaryButton(
                      icon: Icons.add_rounded,
                      text: 'Create Company',
                      onPressed: _showCreateCompanyDialog,
                      gradient: AppColors.primaryGradient,
                    ),
                  ],
                ),
              ],
            ),
            if (isMasterAdmin && compProvider.selectedSuperAdminFilter != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFC7D2FE)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.filter_alt_rounded, size: 14, color: Color(0xFF4338CA)),
                    const SizedBox(width: 6),
                    Text(
                      'Filtered by Super Admin: ${compProvider.superAdmins.firstWhere((a) => a['id'] == compProvider.selectedSuperAdminFilter, orElse: () => {'full_name': 'Selected Super Admin'})['full_name']}',
                      style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFF4338CA)),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => compProvider.setSelectedSuperAdminFilter(null),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Color(0xFFC7D2FE),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded, size: 12, color: Color(0xFF312E81)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            SizedBox(height: isMobile ? 10 : 18),

            // Companies List
            Expanded(
              child: compProvider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : compProvider.companies.isEmpty
                      ? Center(
                          child: GlassCard(
                            padding: const EdgeInsets.all(36),
                            opacity: 0.90,
                            child: Text('No tenant companies registered yet.', style: GoogleFonts.inter(color: const Color(0xFF64748B))),
                          ),
                        )
                      : ListView.separated(
                          itemCount: compProvider.companies.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (ctx, i) {
                            final comp = compProvider.companies[i];
                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => Navigator.pushNamed(context, AppRoutes.companyDetail, arguments: comp),
                                borderRadius: BorderRadius.circular(20),
                                child: GlassCard(
                                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 20, vertical: 16),
                                  opacity: 0.95,
                                  borderColor: const Color(0xFFE2E8F0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          CompanyLogoView(
                                            logo: comp.logo,
                                            companyName: comp.name,
                                            size: 46,
                                            borderRadius: BorderRadius.circular(12),
                                            borderColor: const Color(0xFFCBD5E1),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Flexible(
                                                      child: Text(
                                                        comp.name,
                                                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFFFEF3C7),
                                                        borderRadius: BorderRadius.circular(6),
                                                        border: Border.all(color: const Color(0xFFD4AF37)),
                                                      ),
                                                      child: Text(
                                                        comp.planName,
                                                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF92400E)),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '${comp.subdomain != null && comp.subdomain!.isNotEmpty ? "${comp.subdomain}.stepzcrm.com • " : ""}${comp.adminEmail}',
                                                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                                                  overflow: TextOverflow.ellipsis,
                                                  maxLines: 1,
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (!isMobile) ...[
                                            const SizedBox(width: 16),
                                            _buildCenterLifecycleBlock(comp, isMasterAdmin),
                                            const SizedBox(width: 16),
                                            Wrap(
                                              spacing: 8,
                                              crossAxisAlignment: WrapCrossAlignment.center,
                                              children: [
                                                // View Company Button
                                                OutlinedButton.icon(
                                                  onPressed: () => Navigator.pushNamed(context, AppRoutes.companyDetail, arguments: comp),
                                                  icon: const Icon(Icons.remove_red_eye_outlined, size: 14, color: Color(0xFF0F172A)),
                                                  label: Text('View Details', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                                                  style: OutlinedButton.styleFrom(
                                                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                                                    backgroundColor: Colors.white,
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                  ),
                                                ),
                                                // Suspend / Activate Action Button
                                                OutlinedButton.icon(
                                                  onPressed: () => _confirmToggleStatus(comp),
                                                  icon: Icon(
                                                    comp.isActive ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded,
                                                    size: 14,
                                                    color: comp.isActive ? const Color(0xFFDC2626) : const Color(0xFF047857),
                                                  ),
                                                  label: Text(
                                                    comp.isActive ? 'Suspend' : 'Activate',
                                                    style: GoogleFonts.inter(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w700,
                                                      color: comp.isActive ? const Color(0xFFDC2626) : const Color(0xFF047857),
                                                    ),
                                                  ),
                                                  style: OutlinedButton.styleFrom(
                                                    side: BorderSide(
                                                      color: comp.isActive ? const Color(0xFFFECDD3) : const Color(0xFFBBF7D0),
                                                    ),
                                                    backgroundColor: comp.isActive ? const Color(0xFFFFF1F2) : const Color(0xFFF0FDF4),
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                  ),
                                                ),
                                                // Permissions Button
                                                OutlinedButton.icon(
                                                  onPressed: () => _showPermissionsDialog(comp),
                                                  icon: const Icon(Icons.tune_rounded, size: 14, color: Color(0xFF2563EB)),
                                                  label: Text('Permissions', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF1D4ED8))),
                                                  style: OutlinedButton.styleFrom(
                                                    side: const BorderSide(color: Color(0xFFBFDBFE)),
                                                    backgroundColor: const Color(0xFFEFF6FF),
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                  ),
                                                ),
                                                // Renew Plan Button
                                                OutlinedButton.icon(
                                                  onPressed: () => _showRenewPlanDialog(comp),
                                                  icon: const Icon(Icons.bolt_rounded, size: 14, color: Color(0xFF4F46E5)),
                                                  label: Text('Renew Plan', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF4338CA))),
                                                  style: OutlinedButton.styleFrom(
                                                    side: const BorderSide(color: Color(0xFFC7D2FE)),
                                                    backgroundColor: const Color(0xFFEEF2FF),
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                  ),
                                                ),
                                                IconButton(
                                                  tooltip: 'Generate New Temporary Password',
                                                  icon: const Icon(Icons.lock_reset_rounded, size: 20, color: Color(0xFFD4AF37)),
                                                  onPressed: () => _showResetPasswordDialog(comp),
                                                ),
                                                if (isMasterAdmin)
                                                  IconButton(
                                                    tooltip: 'Reassign Super Admin',
                                                    icon: const Icon(Icons.swap_horiz_rounded, size: 20, color: Color(0xFF4338CA)),
                                                    onPressed: () => _showSuperAdminRequestDialog(comp),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                      if (isMobile) ...[
                                        _buildCenterLifecycleBlock(comp, isMasterAdmin, isMobile: true),
                                        const SizedBox(height: 6),
                                        const Divider(color: Color(0xFFE2E8F0), height: 1),
                                        const SizedBox(height: 10),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          alignment: WrapAlignment.spaceBetween,
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          children: [
                                            // View Details button
                                            OutlinedButton.icon(
                                              onPressed: () => Navigator.pushNamed(context, AppRoutes.companyDetail, arguments: comp),
                                              icon: const Icon(Icons.remove_red_eye_outlined, size: 13, color: Color(0xFF0F172A)),
                                              label: Text('View', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                                              style: OutlinedButton.styleFrom(
                                                side: const BorderSide(color: Color(0xFFE2E8F0)),
                                                backgroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                            ),
                                            // Suspend / Activate Toggle
                                            OutlinedButton.icon(
                                              onPressed: () => _confirmToggleStatus(comp),
                                              icon: Icon(
                                                comp.isActive ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded,
                                                size: 13,
                                                color: comp.isActive ? const Color(0xFFDC2626) : const Color(0xFF047857),
                                              ),
                                              label: Text(
                                                comp.isActive ? 'Suspend' : 'Activate',
                                                style: GoogleFonts.inter(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: comp.isActive ? const Color(0xFFDC2626) : const Color(0xFF047857),
                                                ),
                                              ),
                                              style: OutlinedButton.styleFrom(
                                                side: BorderSide(
                                                  color: comp.isActive ? const Color(0xFFFECDD3) : const Color(0xFFBBF7D0),
                                                ),
                                                backgroundColor: comp.isActive ? const Color(0xFFFFF1F2) : const Color(0xFFF0FDF4),
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                            ),
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                OutlinedButton.icon(
                                                  onPressed: () => _showRenewPlanDialog(comp),
                                                  icon: const Icon(Icons.bolt_rounded, size: 13, color: Color(0xFF4F46E5)),
                                                  label: Text('Renew', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF4338CA))),
                                                  style: OutlinedButton.styleFrom(
                                                    side: const BorderSide(color: Color(0xFFC7D2FE)),
                                                    backgroundColor: const Color(0xFFEEF2FF),
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                OutlinedButton.icon(
                                                  onPressed: () => _showPermissionsDialog(comp),
                                                  icon: const Icon(Icons.tune_rounded, size: 13, color: Color(0xFF2563EB)),
                                                  label: Text('Perms', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF1D4ED8))),
                                                  style: OutlinedButton.styleFrom(
                                                    side: const BorderSide(color: Color(0xFFBFDBFE)),
                                                    backgroundColor: const Color(0xFFEFF6FF),
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                  ),
                                                ),
                                                IconButton(
                                                  tooltip: 'Generate New Temporary Password',
                                                  icon: const Icon(Icons.lock_reset_rounded, size: 18, color: Color(0xFFD4AF37)),
                                                  onPressed: () => _showResetPasswordDialog(comp),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
