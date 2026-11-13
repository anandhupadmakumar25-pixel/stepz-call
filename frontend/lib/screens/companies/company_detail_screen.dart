import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass/app_background.dart';
import '../../core/widgets/glass/glass_card.dart';
import '../../core/widgets/glass/gradient_button.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../core/widgets/app_back_button.dart';
import '../../routes/app_routes.dart';
import '../../models/company_model.dart';
import '../../providers/company_provider.dart';
import '../../core/widgets/company_logo_view.dart';
import '../../providers/auth_provider.dart';
import 'edit_company_dialog.dart';
import 'renew_plan_dialog.dart';
import 'renewal_request_dialog.dart';

class CompanyDetailScreen extends StatefulWidget {
  final String companyId;
  final CompanyModel? initialCompany;

  const CompanyDetailScreen({
    super.key,
    required this.companyId,
    this.initialCompany,
  });

  @override
  State<CompanyDetailScreen> createState() => _CompanyDetailScreenState();
}

class _CompanyDetailScreenState extends State<CompanyDetailScreen> {
  final Map<String, _ModuleInfo> _allModules = const {
    'branches': _ModuleInfo(
      title: 'Branches & Multi-Office',
      desc: 'Add multiple regional campuses, office branches & codes',
      icon: Icons.storefront_rounded,
    ),
    'employees': _ModuleInfo(
      title: 'Telecaller Team & Staff',
      desc: 'Agent staff management, user roles & calling targets',
      icon: Icons.people_alt_rounded,
    ),
    'attendance': _ModuleInfo(
      title: 'Stepz Attendance & Geofencing',
      desc: 'GPS geofenced check-in, multi-branch office radius & field staff visit routes',
      icon: Icons.location_on_rounded,
    ),
    'leads': _ModuleInfo(
      title: 'Lead Workspace & Import',
      desc: 'Direct CRM lead entry, Excel batch import & phone deduplication',
      icon: Icons.contacts_rounded,
    ),
    'tasks': _ModuleInfo(
      title: 'Calling Tasks & Allocation',
      desc: 'Round-robin assignment & live queue execution studio',
      icon: Icons.assignment_turned_in_rounded,
    ),
    'recordings': _ModuleInfo(
      title: 'Audio Call Recordings',
      desc: '2-way audio capture, waveform review & voice logs',
      icon: Icons.mic_rounded,
    ),
    'callbacks': _ModuleInfo(
      title: 'Priority Callbacks & Reminders',
      desc: 'Scheduled follow-ups with automatic calendar alerts',
      icon: Icons.alarm_rounded,
    ),
    'call_history': _ModuleInfo(
      title: 'Call Logs & History',
      desc: 'Comprehensive telecom audit log, durations & outcomes',
      icon: Icons.history_rounded,
    ),
    'analytics': _ModuleInfo(
      title: 'Analytics & Reporting',
      desc: 'Executive conversion stats, telecaller leaderboards & KPIs',
      icon: Icons.insights_rounded,
    ),
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final compProv = context.read<CompanyProvider>();
      if (widget.initialCompany != null) {
        compProv.setActiveCompany(widget.initialCompany);
      }
      compProv.fetchCompanyDetail(widget.companyId);
      compProv.fetchPlans();
    });
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
        context.read<CompanyProvider>().fetchCompanyDetail(widget.companyId);
        context.read<CompanyProvider>().fetchCompanies();
      }
    });
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
              opacity: 0.98,
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
                                'Credentials generated successfully. Share these with the tenant administrator.',
                                style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF065F46), fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
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
                            OutlinedButton.icon(
                              onPressed: () {
                                final credentialsText = '''--- Stepz CRM Tenant Credentials ---
Company: $companyName
Admin Email: $adminEmail
Temporary Password: $tempPassword
Plan: $planName
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
                opacity: 0.98,
                borderRadius: BorderRadius.circular(20),
                padding: EdgeInsets.all(isMobile ? 16 : 24),
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
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: const Icon(Icons.tune_rounded, color: Color(0xFF2563EB), size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Manage Modules & Plan',
                                  style: GoogleFonts.inter(fontSize: isMobile ? 15 : 16, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                                ),
                                Text(
                                  company.name,
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
                                child: Text('${p.name} (\$${p.priceMonthly.toStringAsFixed(0)}/mo)', overflow: TextOverflow.ellipsis),
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
                          children: _allModules.entries.map((entry) {
                            final isChecked = selectedMenus.contains(entry.key);
                            return CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              title: Text(entry.value.title, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
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
                              text: 'Save Changes',
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

  @override
  Widget build(BuildContext context) {
    final compProv = context.watch<CompanyProvider>();
    final isMobile = ResponsiveLayout.isMobile(context);

    // Look up company in provider, fallback to widget's initialCompany
    final company = compProv.companies.firstWhere(
      (c) => c.id == widget.companyId,
      orElse: () => compProv.activeCompanyDetail ?? widget.initialCompany ?? CompanyModel(
        id: widget.companyId,
        name: 'Loading Company...',
        contactEmail: '',
        contactPhone: '',
        status: 'ACTIVE',
        defaultCountryCode: '+91',
        createdAt: '',
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: AppBackground(
        preset: AppBackgroundPreset.pastelSky,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              isMobile ? 12 : 28,
              isMobile ? 12 : 16,
              isMobile ? 12 : 28,
              isMobile ? 16 : 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Navigation Bar
                _buildHeaderBar(company, isMobile),
                SizedBox(height: isMobile ? 14 : 20),

                // Key Metric Cards (4 Cards)
                _buildMetricCards(company, isMobile),
                SizedBox(height: isMobile ? 14 : 20),

                // Company Administration & Contact Details Card
                _buildAdminContactCard(company, isMobile),
                SizedBox(height: isMobile ? 14 : 20),

                // Plan & Quota Capacity Card
                _buildPlanCapacityCard(company, isMobile),
                SizedBox(height: isMobile ? 14 : 20),

                // Permitted Feature Modules Matrix Card
                _buildModulesMatrixCard(company, isMobile),
                SizedBox(height: isMobile ? 14 : 20),

                // Danger / Workspace Control Section
                _buildWorkspaceControlCard(company, isMobile),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderBar(CompanyModel company, bool isMobile) {
    final isSuperAdmin = context.watch<AuthProvider>().currentUser?.isSuperAdmin ?? true;
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppBackButton(fallbackRoute: AppRoutes.companies),
              const SizedBox(width: 10),
              CompanyLogoView(
                logo: company.logo,
                companyName: company.name,
                size: 38,
                borderRadius: BorderRadius.circular(10),
                borderColor: const Color(0xFFCBD5E1),
              ),
              const SizedBox(width: 10),
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
                          company.name,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                            letterSpacing: -0.3,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: company.isActive ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: company.isActive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                            ),
                          ),
                          child: Text(
                            company.isActive ? 'Active' : 'Suspended',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: company.isActive ? const Color(0xFF047857) : const Color(0xFFDC2626),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      company.subdomain != null && company.subdomain!.isNotEmpty
                          ? '${company.subdomain}.stepzcrm.com'
                          : 'Tenant Organization Overview',
                      style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // Edit Profile & Logo
              OutlinedButton.icon(
                onPressed: () async {
                  final updated = await EditCompanyDialog.show(context, company);
                  if (updated == true && mounted) {
                    context.read<CompanyProvider>().fetchCompanyDetail(widget.companyId);
                  }
                },
                icon: const Icon(Icons.edit_rounded, size: 14, color: Color(0xFF4F46E5)),
                label: Text(
                  'Edit Profile & Logo',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF4F46E5)),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFC7D2FE)),
                  backgroundColor: const Color(0xFFEEF2FF),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),

              // Suspend / Activate Button
              OutlinedButton.icon(
                onPressed: () => _confirmToggleStatus(company),
                icon: Icon(
                  company.isActive ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded,
                  size: 14,
                  color: company.isActive ? const Color(0xFFDC2626) : const Color(0xFF047857),
                ),
                label: Text(
                  company.isActive ? 'Suspend' : 'Activate',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: company.isActive ? const Color(0xFFDC2626) : const Color(0xFF047857),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: company.isActive ? const Color(0xFFFECDD3) : const Color(0xFFBBF7D0),
                  ),
                  backgroundColor: company.isActive ? const Color(0xFFFFF1F2) : const Color(0xFFF0FDF4),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),

              // Permissions Button
              OutlinedButton.icon(
                onPressed: () => _showPermissionsDialog(company),
                icon: const Icon(Icons.tune_rounded, size: 14, color: Color(0xFF2563EB)),
                label: Text(
                  'Permissions',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF1D4ED8)),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFBFDBFE)),
                  backgroundColor: const Color(0xFFEFF6FF),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),

              if (isSuperAdmin)
                OutlinedButton.icon(
                  onPressed: () => _showRenewPlanDialog(company),
                  icon: const Icon(Icons.bolt_rounded, size: 14, color: Color(0xFF4F46E5)),
                  label: Text(
                    'Renew Plan',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF4338CA)),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFC7D2FE)),
                    backgroundColor: const Color(0xFFEEF2FF),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                )
              else
                OutlinedButton.icon(
                  onPressed: () => SubmitRenewalRequestDialog.show(context, company: company),
                  icon: const Icon(Icons.send_rounded, size: 14, color: Color(0xFF0F766E)),
                  label: Text(
                    'Request',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF0F766E)),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF99F6E4)),
                    backgroundColor: const Color(0xFFF0FDFA),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),

              // Reset Password Button
              OutlinedButton.icon(
                onPressed: () => _showResetPasswordDialog(company),
                icon: const Icon(Icons.lock_reset_rounded, size: 14, color: Color(0xFF92400E)),
                label: Text(
                  'Password',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF92400E)),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFD4AF37)),
                  backgroundColor: const Color(0xFFFEF3C7),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const AppBackButton(fallbackRoute: AppRoutes.companies),
        const SizedBox(width: 12),
        CompanyLogoView(
          logo: company.logo,
          companyName: company.name,
          size: 48,
          borderRadius: BorderRadius.circular(14),
          borderColor: const Color(0xFFCBD5E1),
        ),
        const SizedBox(width: 14),
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
                    company.name,
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                      letterSpacing: -0.3,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: company.isActive ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: company.isActive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      ),
                    ),
                    child: Text(
                      company.isActive ? 'Active' : 'Suspended',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: company.isActive ? const Color(0xFF047857) : const Color(0xFFDC2626),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                company.subdomain != null && company.subdomain!.isNotEmpty
                    ? '${company.subdomain}.stepzcrm.com • Registered ${company.createdAt.isNotEmpty ? company.createdAt.substring(0, 10) : 'Active'}'
                    : 'Tenant Organization Overview & Controls',
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),

        // Desktop Action Buttons Row
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () async {
                final updated = await EditCompanyDialog.show(context, company);
                if (updated == true && mounted) {
                  context.read<CompanyProvider>().fetchCompanyDetail(widget.companyId);
                }
              },
              icon: const Icon(Icons.edit_rounded, size: 16, color: Color(0xFF4F46E5)),
              label: Text(
                'Edit Profile & Logo',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF4F46E5)),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFC7D2FE)),
                backgroundColor: const Color(0xFFEEF2FF),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => _confirmToggleStatus(company),
              icon: Icon(
                company.isActive ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded,
                size: 16,
                color: company.isActive ? const Color(0xFFDC2626) : const Color(0xFF047857),
              ),
              label: Text(
                company.isActive ? 'Suspend' : 'Activate',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: company.isActive ? const Color(0xFFDC2626) : const Color(0xFF047857),
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: company.isActive ? const Color(0xFFFECDD3) : const Color(0xFFBBF7D0),
                ),
                backgroundColor: company.isActive ? const Color(0xFFFFF1F2) : const Color(0xFFF0FDF4),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => _showPermissionsDialog(company),
              icon: const Icon(Icons.tune_rounded, size: 16, color: Color(0xFF2563EB)),
              label: Text(
                'Permissions',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF1D4ED8)),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFBFDBFE)),
                backgroundColor: const Color(0xFFEFF6FF),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            if (isSuperAdmin)
              OutlinedButton.icon(
                onPressed: () => _showRenewPlanDialog(company),
                icon: const Icon(Icons.bolt_rounded, size: 16, color: Color(0xFF4F46E5)),
                label: Text(
                  'Extend / Renew Plan',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF4338CA)),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFC7D2FE)),
                  backgroundColor: const Color(0xFFEEF2FF),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              )
            else
              OutlinedButton.icon(
                onPressed: () => SubmitRenewalRequestDialog.show(context, company: company),
                icon: const Icon(Icons.send_rounded, size: 16, color: Color(0xFF0F766E)),
                label: Text(
                  'Request Plan Renewal',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF0F766E)),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF99F6E4)),
                  backgroundColor: const Color(0xFFF0FDFA),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            OutlinedButton.icon(
              onPressed: () => _showResetPasswordDialog(company),
              icon: const Icon(Icons.lock_reset_rounded, size: 16, color: Color(0xFF92400E)),
              label: Text(
                'Reset Password',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF92400E)),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFD4AF37)),
                backgroundColor: const Color(0xFFFEF3C7),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCards(CompanyModel company, bool isMobile) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = isMobile
            ? (constraints.maxWidth - 10) / 2
            : (constraints.maxWidth - 36) / 4;

        return Wrap(
          spacing: isMobile ? 10 : 12,
          runSpacing: isMobile ? 10 : 12,
          children: [
            _buildStatCard(
              title: 'STATUS',
              value: company.isActive ? 'Active' : 'Suspended',
              sub: company.isActive ? 'Operational' : 'Access locked',
              icon: company.isActive ? Icons.check_circle_outline_rounded : Icons.block_rounded,
              color: company.isActive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              width: cardWidth,
              isMobile: isMobile,
            ),
            _buildStatCard(
              title: 'PLAN',
              value: company.planName,
              sub: company.planPriceMonthly > 0 ? '${company.planCurrencySymbol}${company.planPriceMonthly.toStringAsFixed(0)}/mo' : 'Standard tier',
              icon: Icons.diamond_rounded,
              color: const Color(0xFF2563EB),
              width: cardWidth,
              isMobile: isMobile,
            ),
            _buildStatCard(
              title: 'TEAM',
              value: '${company.userCount} Users',
              sub: '${company.branchCount > 0 ? company.branchCount : 1} Branch${company.branchCount > 1 ? 'es' : ''}',
              icon: Icons.groups_rounded,
              color: const Color(0xFF8B5CF6),
              width: cardWidth,
              isMobile: isMobile,
            ),
            _buildStatCard(
              title: 'LEADS',
              value: '${company.leadCount} Leads',
              sub: '${company.taskCount} Tasks',
              icon: Icons.contact_phone_rounded,
              color: const Color(0xFFF59E0B),
              width: cardWidth,
              isMobile: isMobile,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String sub,
    required IconData icon,
    required Color color,
    required double width,
    required bool isMobile,
  }) {
    return Container(
      width: width,
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF94A3B8), letterSpacing: 0.4),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 14, color: color),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.inter(fontSize: isMobile ? 15 : 17, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildAdminContactCard(CompanyModel company, bool isMobile) {
    return GlassCard(
      padding: EdgeInsets.all(isMobile ? 14 : 22),
      opacity: 0.98,
      borderColor: const Color(0xFFE2E8F0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.badge_rounded, color: Color(0xFF2563EB), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Tenant Administrator & Contact',
                  style: GoogleFonts.inter(fontSize: isMobile ? 13 : 14, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: () => _showResetPasswordDialog(company),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.key_rounded, size: 13, color: Color(0xFF92400E)),
                      const SizedBox(width: 4),
                      Text(
                        'Reset Password',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF92400E)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Color(0xFFE2E8F0), height: 1),
          const SizedBox(height: 14),

          Wrap(
            spacing: isMobile ? 14 : 24,
            runSpacing: 14,
            children: [
              _buildInfoItem(
                label: 'ADMINISTRATOR NAME',
                value: company.adminName.isNotEmpty ? company.adminName : 'Tenant Admin',
                icon: Icons.person_outline_rounded,
                isMobile: isMobile,
              ),
              _buildCopyableInfoItem(
                label: 'LOGIN / CONTACT EMAIL',
                value: company.adminEmail,
                icon: Icons.email_outlined,
                isMobile: isMobile,
              ),
              _buildCopyableInfoItem(
                label: 'PHONE NUMBER',
                value: company.contactPhone.isNotEmpty ? company.contactPhone : 'Not Provided',
                icon: Icons.phone_outlined,
                isMobile: isMobile,
              ),
              _buildInfoItem(
                label: 'DEFAULT REGION',
                value: '${company.defaultCountryCode} (Default)',
                icon: Icons.public_rounded,
                isMobile: isMobile,
              ),
              if (company.subdomain != null && company.subdomain!.isNotEmpty)
                _buildCopyableInfoItem(
                  label: 'SUBDOMAIN PORTAL',
                  value: 'https://${company.subdomain}.stepzcrm.com',
                  icon: Icons.link_rounded,
                  isMobile: isMobile,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCapacityCard(CompanyModel company, bool isMobile) {
    final isSuperAdmin = context.watch<AuthProvider>().currentUser?.isSuperAdmin ?? true;
    final userPercent = company.planMaxUsers > 0 ? (company.userCount / company.planMaxUsers).clamp(0.0, 1.0) : 0.0;
    final leadPercent = company.planMaxLeads > 0 ? (company.leadCount / company.planMaxLeads).clamp(0.0, 1.0) : 0.0;

    return GlassCard(
      padding: EdgeInsets.all(isMobile ? 14 : 22),
      opacity: 0.98,
      borderColor: const Color(0xFFE2E8F0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.speed_rounded, color: Color(0xFF92400E), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Subscription Quotas & Allocation',
                  style: GoogleFonts.inter(fontSize: isMobile ? 13 : 14, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: () => _showPermissionsDialog(company),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.tune_rounded, size: 13, color: Color(0xFF2563EB)),
                      const SizedBox(width: 4),
                      Text(
                        'Change Plan',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF2563EB)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Color(0xFFE2E8F0), height: 1),
          const SizedBox(height: 14),

          // Subscription Plan Expiry & Status Banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: company.isPlanOverdue
                  ? const Color(0xFFFEF2F2)
                  : (company.isExpiringSoon ? const Color(0xFFFFFBEB) : const Color(0xFFF0FDF4)),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: company.isPlanOverdue
                    ? const Color(0xFFFCA5A5)
                    : (company.isExpiringSoon ? const Color(0xFFFCD34D) : const Color(0xFFBBF7D0)),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  company.isPlanOverdue
                      ? Icons.error_outline_rounded
                      : (company.isExpiringSoon ? Icons.warning_amber_rounded : Icons.verified_user_rounded),
                  color: company.isPlanOverdue
                      ? const Color(0xFFDC2626)
                      : (company.isExpiringSoon ? const Color(0xFFD97706) : const Color(0xFF16A34A)),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        company.isPlanOverdue
                            ? 'Subscription Expired - Access Suspended'
                            : (company.isExpiringSoon
                                ? 'Subscription Expiring Soon (${company.daysUntilExpiry} days left)'
                                : 'Active Subscription (${company.planBillingCycle} Billing)'),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: company.isPlanOverdue
                              ? const Color(0xFF991B1B)
                              : (company.isExpiringSoon ? const Color(0xFF92400E) : const Color(0xFF166534)),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        company.isPlanOverdue
                            ? 'The plan expired on ${company.expiryFormatted}. Login and CRM access are locked for this workspace.'
                            : 'Plan expires on ${company.expiryFormatted}${company.daysUntilExpiry != null ? ' (${company.daysUntilExpiry} days remaining)' : ''}.',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: company.isPlanOverdue
                              ? const Color(0xFFB91C1C)
                              : (company.isExpiringSoon ? const Color(0xFFB45309) : const Color(0xFF15803D)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (isSuperAdmin)
                  ElevatedButton.icon(
                    onPressed: () => _showRenewPlanDialog(company),
                    icon: const Icon(Icons.bolt_rounded, size: 14),
                    label: Text('Extend Plan', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: () => SubmitRenewalRequestDialog.show(context, company: company),
                    icon: const Icon(Icons.send_rounded, size: 13, color: Color(0xFF0F766E)),
                    label: Text('Request Renewal', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFF0F766E))),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF99F6E4)),
                      backgroundColor: const Color(0xFFF0FDFA),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (isMobile) ...[
            _buildQuotaProgress(
              title: 'Telecallers & Users Allowed',
              current: company.userCount,
              max: company.planMaxUsers,
              percent: userPercent,
              color: const Color(0xFF2563EB),
            ),
            const SizedBox(height: 14),
            _buildQuotaProgress(
              title: 'Lead Pool Storage',
              current: company.leadCount,
              max: company.planMaxLeads,
              percent: leadPercent,
              color: const Color(0xFF10B981),
            ),
          ] else
            Row(
              children: [
                Expanded(
                  child: _buildQuotaProgress(
                    title: 'Telecallers & Users Allowed',
                    current: company.userCount,
                    max: company.planMaxUsers,
                    percent: userPercent,
                    color: const Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: _buildQuotaProgress(
                    title: 'Lead Pool Storage',
                    current: company.leadCount,
                    max: company.planMaxLeads,
                    percent: leadPercent,
                    color: const Color(0xFF10B981),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildQuotaProgress({
    required String title,
    required int current,
    required int max,
    required double percent,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$current / $max (${(percent * 100).toInt()}%)',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: color),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: percent,
            minHeight: 8,
            backgroundColor: const Color(0xFFE2E8F0),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildModulesMatrixCard(CompanyModel company, bool isMobile) {
    return GlassCard(
      padding: EdgeInsets.all(isMobile ? 14 : 22),
      opacity: 0.98,
      borderColor: const Color(0xFFE2E8F0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.widgets_rounded, color: Color(0xFF047857), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Assigned Sidebar Modules Matrix',
                  style: GoogleFonts.inter(fontSize: isMobile ? 13 : 14, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF10B981)),
                ),
                child: Text(
                  '${company.allowedMenus.length}/${_allModules.length} Active',
                  style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: const Color(0xFF047857)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Color(0xFFE2E8F0), height: 1),
          const SizedBox(height: 14),

          LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = isMobile
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 12) / 2;

              return Wrap(
                spacing: 12,
                runSpacing: 10,
                children: _allModules.entries.map((entry) {
                  final isAllowed = company.allowedMenus.contains(entry.key);
                  final info = entry.value;

                  return Container(
                    width: itemWidth,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isAllowed ? Colors.white : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isAllowed ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isAllowed ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            info.icon,
                            size: 18,
                            color: isAllowed ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                info.title,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isAllowed ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                info.desc,
                                style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          isAllowed ? Icons.check_circle_rounded : Icons.remove_circle_outline_rounded,
                          size: 18,
                          color: isAllowed ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWorkspaceControlCard(CompanyModel company, bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 20),
      decoration: BoxDecoration(
        color: company.isActive ? const Color(0xFFFFF1F2) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: company.isActive ? const Color(0xFFFECDD3) : const Color(0xFFBBF7D0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: company.isActive ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  company.isActive ? Icons.warning_amber_rounded : Icons.verified_user_rounded,
                  color: company.isActive ? const Color(0xFFDC2626) : const Color(0xFF15803D),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      company.isActive ? 'Workspace Operational' : 'Workspace Suspended',
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: company.isActive ? const Color(0xFF991B1B) : const Color(0xFF166534),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      company.isActive
                          ? 'Suspending this tenant halts all telecaller dialing, lead processing, and portal sign-ins.'
                          : 'This tenant is currently offline. Reactivate to restore full access to their CRM workspace.',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: company.isActive ? const Color(0xFFB91C1C) : const Color(0xFF15803D),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: GradientPrimaryButton(
              text: company.isActive ? 'Suspend Company' : 'Reactivate Company',
              icon: company.isActive ? Icons.pause_circle_rounded : Icons.play_circle_rounded,
              gradient: company.isActive ? AppColors.coralGradient : AppColors.cyanGradient,
              onPressed: () => _confirmToggleStatus(company),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required String label,
    required String value,
    required IconData icon,
    required bool isMobile,
  }) {
    return SizedBox(
      width: isMobile ? double.infinity : 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF94A3B8))),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(icon, size: 14, color: const Color(0xFF64748B)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  value,
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCopyableInfoItem({
    required String label,
    required String value,
    required IconData icon,
    required bool isMobile,
  }) {
    return SizedBox(
      width: isMobile ? double.infinity : 260,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF94A3B8))),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(icon, size: 14, color: const Color(0xFF64748B)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  value,
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 14, color: Color(0xFF2563EB)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                splashRadius: 16,
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: value));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$label copied to clipboard!'), duration: const Duration(seconds: 1)),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModuleInfo {
  final String title;
  final String desc;
  final IconData icon;

  const _ModuleInfo({
    required this.title,
    required this.desc,
    required this.icon,
  });
}
