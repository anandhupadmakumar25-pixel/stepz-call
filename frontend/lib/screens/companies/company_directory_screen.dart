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
import '../../models/company_renewal_request_model.dart';
import '../../models/company_subscription_history_model.dart';
import 'renewal_request_dialog.dart';

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

  int _selectedTabIndex = 0; // 0 = Tenants, 1 = Renewal Requests, 2 = Renewal History
  String _selectedRequestStatusFilter = 'ALL'; // ALL, PENDING, APPROVED, REJECTED
  String _selectedHistoryCycleFilter = 'ALL'; // ALL, YEARLY, MONTHLY, DAYS, CUSTOM_DATE

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
                            value: selectedPlanId,
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
                            value: selectedPlanId,
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
                              value: selectedTargetAdminId,
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

            // Tab Switcher: Tenants | Renewal Requests | Renewal History
            _buildTabNavigationBar(compProvider, isMobile),
            SizedBox(height: isMobile ? 12 : 16),

            // Tab Content Body
            Expanded(
              child: _selectedTabIndex == 0
                  ? _buildTenantsListView(compProvider, isMasterAdmin, isMobile)
                  : (_selectedTabIndex == 1
                      ? _buildRenewalRequestsView(compProvider, isMasterAdmin, isMobile)
                      : _buildRenewalHistoryView(compProvider, isMasterAdmin, isMobile)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab Bar Navigation ─────────────────────────────────────────────────────

  Widget _buildTabNavigationBar(CompanyProvider compProvider, bool isMobile) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildTabItem(
            index: 0,
            title: 'Tenants Directory',
            count: compProvider.companies.length,
            icon: Icons.domain_rounded,
          ),
          const SizedBox(width: 8),
          _buildTabItem(
            index: 1,
            title: 'Renewal Requests',
            count: compProvider.pendingRenewalCount,
            icon: Icons.mark_email_unread_rounded,
            isAlert: compProvider.pendingRenewalCount > 0,
            badgeLabel: compProvider.pendingRenewalCount > 0 ? '${compProvider.pendingRenewalCount} PENDING' : '0',
          ),
          const SizedBox(width: 8),
          _buildTabItem(
            index: 2,
            title: 'Renewal History & Breakdown',
            count: compProvider.historyMetrics.totalRenewals,
            icon: Icons.history_edu_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem({
    required int index,
    required String title,
    required int count,
    required IconData icon,
    bool isAlert = false,
    String? badgeLabel,
  }) {
    final isSelected = _selectedTabIndex == index;
    return InkWell(
      onTap: () {
        setState(() => _selectedTabIndex = index);
        if (index == 1) {
          context.read<CompanyProvider>().fetchRenewalRequests();
        } else if (index == 2) {
          context.read<CompanyProvider>().fetchSubscriptionHistory();
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF0F172A)
              : Colors.white.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? Colors.white
                  : (isAlert ? const Color(0xFFDC2626) : const Color(0xFF64748B)),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF334155),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.2)
                    : (isAlert ? const Color(0xFFFEF2F2) : const Color(0xFFF1F5F9)),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.3)
                      : (isAlert ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0)),
                ),
              ),
              child: Text(
                badgeLabel ?? count.toString(),
                style: GoogleFonts.inter(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? Colors.white
                      : (isAlert ? const Color(0xFFDC2626) : const Color(0xFF475569)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab 0: Tenants List View ───────────────────────────────────────────────

  Widget _buildTenantsListView(CompanyProvider compProvider, bool isMasterAdmin, bool isMobile) {
    if (compProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (compProvider.companies.isEmpty) {
      return Center(
        child: GlassCard(
          padding: const EdgeInsets.all(36),
          opacity: 0.90,
          child: Text('No tenant companies registered yet.', style: GoogleFonts.inter(color: const Color(0xFF64748B))),
        ),
      );
    }

    return ListView.separated(
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
                            IconButton(
                              tooltip: isMasterAdmin ? 'Reassign Super Admin' : 'Super Admin Request',
                              icon: Icon(isMasterAdmin ? Icons.swap_horiz_rounded : Icons.contact_support_outlined, size: 20, color: const Color(0xFF6366F1)),
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
                            IconButton(
                              tooltip: isMasterAdmin ? 'Reassign Super Admin' : 'Super Admin Request',
                              icon: Icon(isMasterAdmin ? Icons.swap_horiz_rounded : Icons.contact_support_outlined, size: 18, color: const Color(0xFF6366F1)),
                              onPressed: () => _showSuperAdminRequestDialog(comp),
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
    );
  }

  // ── Tab 1: Renewal Requests View ───────────────────────────────────────────

  Widget _buildRenewalRequestsView(CompanyProvider compProvider, bool isMasterAdmin, bool isMobile) {
    if (compProvider.isLoadingRenewalRequests) {
      return const Center(child: CircularProgressIndicator());
    }

    final allReqs = compProvider.renewalRequests;
    final filteredReqs = _selectedRequestStatusFilter == 'ALL'
        ? allReqs
        : allReqs.where((r) => r.status == _selectedRequestStatusFilter).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Status filter bar
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildRequestFilterChip('ALL', 'All Requests (${allReqs.length})'),
            _buildRequestFilterChip('PENDING', 'Pending (${compProvider.pendingRenewalCount})', alert: compProvider.pendingRenewalCount > 0),
            _buildRequestFilterChip('APPROVED', 'Approved (${compProvider.renewalRequestMetrics['approved_count'] ?? 0})'),
            _buildRequestFilterChip('REJECTED', 'Rejected (${compProvider.renewalRequestMetrics['rejected_count'] ?? 0})'),
          ],
        ),
        const SizedBox(height: 14),

        // List
        Expanded(
          child: filteredReqs.isEmpty
              ? Center(
                  child: GlassCard(
                    padding: const EdgeInsets.all(36),
                    opacity: 0.92,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.inbox_rounded, size: 44, color: Color(0xFF94A3B8)),
                        const SizedBox(height: 12),
                        Text(
                          'No renewal requests in this category.',
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  itemCount: filteredReqs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, i) {
                    final req = filteredReqs[i];
                    return _buildRenewalRequestCard(req, isMobile);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildRequestFilterChip(String key, String label, {bool alert = false}) {
    final isSelected = _selectedRequestStatusFilter == key;
    return InkWell(
      onTap: () => setState(() => _selectedRequestStatusFilter = key),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF0F172A)
              : (alert ? const Color(0xFFFEF2F2) : Colors.white),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF0F172A)
                : (alert ? const Color(0xFFFCA5A5) : const Color(0xFFCBD5E1)),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected
                ? Colors.white
                : (alert ? const Color(0xFFDC2626) : const Color(0xFF334155)),
          ),
        ),
      ),
    );
  }

  Widget _buildRenewalRequestCard(CompanyRenewalRequestModel req, bool isMobile) {
    Color statusBg;
    Color statusBorder;
    Color statusColor;
    IconData statusIcon;

    if (req.isPending) {
      statusBg = const Color(0xFFFEF3C7);
      statusBorder = const Color(0xFFFCD34D);
      statusColor = const Color(0xFF92400E);
      statusIcon = Icons.pending_actions_rounded;
    } else if (req.isApproved) {
      statusBg = const Color(0xFFECFDF5);
      statusBorder = const Color(0xFFA7F3D0);
      statusColor = const Color(0xFF047857);
      statusIcon = Icons.check_circle_rounded;
    } else {
      statusBg = const Color(0xFFFEF2F2);
      statusBorder = const Color(0xFFFCA5A5);
      statusColor = const Color(0xFFB91C1C);
      statusIcon = Icons.cancel_rounded;
    }

    return GlassCard(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 20, vertical: 16),
      opacity: 0.96,
      borderColor: req.isPending ? const Color(0xFFFCD34D) : const Color(0xFFE2E8F0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFC7D2FE)),
                ),
                child: const Icon(Icons.autorenew_rounded, color: Color(0xFF4338CA), size: 22),
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
                            req.companyName,
                            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: Text(
                            req.cycleDisplay,
                            style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: const Color(0xFF1D4ED8)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Requested by: ${req.requestedByName} • ${req.requestedByEmail} • Super Admin: ${req.assignedSuperAdminName}',
                      style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: statusBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 13, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      req.status,
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (req.paymentReference.isNotEmpty || req.notes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (req.paymentReference.isNotEmpty)
                    Text(
                      'Payment Ref: ${req.paymentReference}',
                      style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFF0F766E)),
                    ),
                  if (req.notes.isNotEmpty)
                    Text(
                      'Customer Note: ${req.notes}',
                      style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF475569)),
                    ),
                ],
              ),
            ),
          ],
          if (req.adminNotes.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Admin Note: ${req.adminNotes}',
              style: GoogleFonts.inter(fontSize: 11, fontStyle: FontStyle.italic, color: const Color(0xFF059669)),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Submitted: ${req.formattedCreatedAt}',
                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
              ),
              if (req.isPending)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFDC2626),
                        side: const BorderSide(color: Color(0xFFFCA5A5)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _showRejectDialog(req),
                      child: Text('Reject', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.check_circle_rounded, size: 14),
                      label: Text('Approve (Zero-Day Calc)', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700)),
                      onPressed: () => ApproveRenewalRequestDialog.show(context, request: req),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(CompanyRenewalRequestModel req) {
    final noteCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reject Renewal Request', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to reject the renewal request for ${req.companyName}?', style: GoogleFonts.inter(fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(
                hintText: 'Reason for rejection (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<CompanyProvider>().rejectRenewalRequest(req.id, adminNotes: noteCtrl.text.trim());
            },
            child: const Text('Reject Request'),
          ),
        ],
      ),
    );
  }

  // ── Tab 2: Renewal History View ────────────────────────────────────────────

  Widget _buildRenewalHistoryView(CompanyProvider compProvider, bool isMasterAdmin, bool isMobile) {
    if (compProvider.isLoadingHistory) {
      return const Center(child: CircularProgressIndicator());
    }

    final metrics = compProvider.historyMetrics;
    final allHistory = compProvider.subscriptionHistory;
    final filteredHistory = _selectedHistoryCycleFilter == 'ALL'
        ? allHistory
        : allHistory.where((h) => h.billingCycle == _selectedHistoryCycleFilter).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Analytics Breakdown Row (Yearly, Monthly, Days, Custom Date)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildHistoryMetricCard('Total Renewals', metrics.totalRenewals.toString(), Icons.history_rounded, const Color(0xFF0F172A), const Color(0xFFF1F5F9)),
              const SizedBox(width: 10),
              _buildHistoryMetricCard('Yearly Paid', metrics.yearlyCount.toString(), Icons.verified_rounded, const Color(0xFF4338CA), const Color(0xFFEEF2FF)),
              const SizedBox(width: 10),
              _buildHistoryMetricCard('Monthly Paid', metrics.monthlyCount.toString(), Icons.calendar_view_month_rounded, const Color(0xFF047857), const Color(0xFFECFDF5)),
              const SizedBox(width: 10),
              _buildHistoryMetricCard('Custom Days', metrics.daysCount.toString(), Icons.timelapse_rounded, const Color(0xFFD97706), const Color(0xFFFFFBEB)),
              const SizedBox(width: 10),
              _buildHistoryMetricCard('Custom Date', metrics.customDateCount.toString(), Icons.event_available_rounded, const Color(0xFF0891B2), const Color(0xFFECFEFF)),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // History cycle filters
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildHistoryFilterChip('ALL', 'All Cycles (${allHistory.length})'),
            _buildHistoryFilterChip('YEARLY', 'Yearly (${metrics.yearlyCount})'),
            _buildHistoryFilterChip('MONTHLY', 'Monthly (${metrics.monthlyCount})'),
            _buildHistoryFilterChip('DAYS', 'Custom Days (${metrics.daysCount})'),
            _buildHistoryFilterChip('CUSTOM_DATE', 'Custom Date (${metrics.customDateCount})'),
          ],
        ),
        const SizedBox(height: 14),

        // History list
        Expanded(
          child: filteredHistory.isEmpty
              ? Center(
                  child: GlassCard(
                    padding: const EdgeInsets.all(36),
                    opacity: 0.92,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.history_toggle_off_rounded, size: 44, color: Color(0xFF94A3B8)),
                        const SizedBox(height: 12),
                        Text(
                          'No subscription renewal history recorded yet.',
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  itemCount: filteredHistory.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final item = filteredHistory[i];
                    return _buildHistoryCard(item, isMobile);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildHistoryMetricCard(String title, String value, IconData icon, Color color, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
              Text(value, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryFilterChip(String key, String label) {
    final isSelected = _selectedHistoryCycleFilter == key;
    return InkWell(
      onTap: () => setState(() => _selectedHistoryCycleFilter = key),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1)),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF334155),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryCard(CompanySubscriptionHistoryModel item, bool isMobile) {
    Color cycleColor;
    Color cycleBg;

    if (item.billingCycle == 'YEARLY') {
      cycleColor = const Color(0xFF4338CA);
      cycleBg = const Color(0xFFEEF2FF);
    } else if (item.billingCycle == 'MONTHLY') {
      cycleColor = const Color(0xFF047857);
      cycleBg = const Color(0xFFECFDF5);
    } else if (item.billingCycle == 'DAYS') {
      cycleColor = const Color(0xFFD97706);
      cycleBg = const Color(0xFFFFFBEB);
    } else {
      cycleColor = const Color(0xFF0891B2);
      cycleBg = const Color(0xFFECFEFF);
    }

    return GlassCard(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 18, vertical: 14),
      opacity: 0.96,
      borderColor: const Color(0xFFE2E8F0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: cycleBg, borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.history_rounded, color: cycleColor, size: 20),
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
                        item.companyName,
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: cycleBg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: cycleColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        item.billingCycleDisplay,
                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: cycleColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Valid until: ${item.formattedNewExpiry} (+${item.extensionDays} days) • Approved by ${item.approvedByName}',
                  style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                ),
                if (item.notes.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Notes: ${item.notes}',
                    style: GoogleFonts.inter(fontSize: 11, fontStyle: FontStyle.italic, color: const Color(0xFF94A3B8)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            item.formattedCreatedAt,
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }
}
