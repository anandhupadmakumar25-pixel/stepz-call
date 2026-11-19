import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../core/widgets/glass/glass_card.dart';
import '../../core/widgets/glass/glass_text_field.dart';
import '../../core/widgets/glass/gradient_button.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/company_logo_view.dart';
import '../../providers/auth_provider.dart';
import '../../providers/company_provider.dart';
import '../../routes/app_routes.dart';

class MasterSuperAdminScreen extends StatefulWidget {
  const MasterSuperAdminScreen({super.key});

  @override
  State<MasterSuperAdminScreen> createState() => _MasterSuperAdminScreenState();
}

class _MasterSuperAdminScreenState extends State<MasterSuperAdminScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _activeTab = 'ALL'; // 'ALL', 'ACTIVE', 'SUSPENDED', 'MASTER'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final compProv = context.read<CompanyProvider>();
      compProv.fetchSuperAdmins();
      compProv.fetchCompanies();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showProvisionSuperAdminDialog() {
    final emailCtrl = TextEditingController();
    final firstNameCtrl = TextEditingController();
    final lastNameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final compProv = context.read<CompanyProvider>();
    final messenger = ScaffoldMessenger.of(context);
    bool isSaving = false;
    String role = 'SUPER_ADMIN';

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setModalState) {
          final isMobile = ResponsiveLayout.isMobile(dialogCtx);
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.all(isMobile ? 12 : 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: GlassCard(
                blur: 24,
                opacity: 0.98,
                borderRadius: BorderRadius.circular(22),
                borderColor: const Color(0xFF6366F1),
                padding: EdgeInsets.all(isMobile ? 18 : 28),
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
                              color: const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFC7D2FE)),
                            ),
                            child: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF4F46E5), size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Provision Super Admin',
                                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                                ),
                                Text(
                                  'Create a new onboarding partner or platform administrator',
                                  style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 20),
                            onPressed: () => Navigator.pop(dialogCtx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: GlassTextField(
                              label: 'First Name *',
                              hintText: 'e.g. John',
                              controller: firstNameCtrl,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GlassTextField(
                              label: 'Last Name',
                              hintText: 'e.g. Doe',
                              controller: lastNameCtrl,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      GlassTextField(
                        label: 'Email Address *',
                        hintText: 'partner@example.com',
                        controller: emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 12),
                      GlassTextField(
                        label: 'Phone Number',
                        hintText: '+91 9876543210',
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 12),
                      GlassTextField(
                        label: 'Password (leave blank to auto-generate)',
                        hintText: '••••••••••',
                        controller: passwordCtrl,
                        obscureText: true,
                      ),
                      const SizedBox(height: 14),
                      // Tier Selector
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Access Privilege Tier', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B))),
                                Text(
                                  role == 'MASTER_ADMIN' ? 'Global root access across all platform tenants' : 'Scoped only to companies they onboard',
                                  style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B)),
                                ),
                              ],
                            ),
                            const Spacer(),
                            DropdownButton<String>(
                              value: role,
                              underline: const SizedBox.shrink(),
                              dropdownColor: Colors.white,
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)),
                              items: const [
                                DropdownMenuItem(value: 'SUPER_ADMIN', child: Text('Super Admin')),
                                DropdownMenuItem(value: 'MASTER_ADMIN', child: Text('Master Admin')),
                              ],
                              onChanged: (v) {
                                if (v != null) setModalState(() => role = v);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      GradientPrimaryButton(
                        text: isSaving ? 'Provisioning...' : 'Provision Super Admin',
                        icon: Icons.check_circle_outline_rounded,
                        onPressed: isSaving
                            ? null
                            : () async {
                                final email = emailCtrl.text.trim();
                                final firstName = firstNameCtrl.text.trim();
                                if (email.isEmpty || firstName.isEmpty) {
                                  messenger.showSnackBar(
                                    const SnackBar(content: Text('First name and email are required.')),
                                  );
                                  return;
                                }
                                setModalState(() => isSaving = true);
                                final res = await compProv.createSuperAdmin({
                                  'email': email,
                                  'first_name': firstName,
                                  'last_name': lastNameCtrl.text.trim(),
                                  'phone': phoneCtrl.text.trim(),
                                  'password': passwordCtrl.text.trim(),
                                  'role': role,
                                });
                                setModalState(() => isSaving = false);
                                if (res != null && mounted) {
                                  Navigator.pop(dialogCtx);
                                  _showCredentialsModal(
                                    email: email,
                                    fullName: '$firstName ${lastNameCtrl.text.trim()}'.trim(),
                                    tempPassword: res['temp_password'] ?? 'Generated',
                                  );
                                } else if (mounted) {
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(compProv.errorMessage ?? 'Failed to provision Super Admin'),
                                      backgroundColor: const Color(0xFFDC2626),
                                    ),
                                  );
                                }
                              },
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

  void _showCredentialsModal({
    required String email,
    required String fullName,
    required String tempPassword,
    String title = 'Super Admin Provisioned',
  }) {
    showDialog(
      context: context,
      builder: (ctx) {
        final isMobile = ResponsiveLayout.isMobile(ctx);
        return AlertDialog(
          insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440, minWidth: 280),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Login credentials for $fullName:',
                    style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 72,
                              child: Text('Email:', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B), fontWeight: FontWeight.w600)),
                            ),
                            Expanded(
                              child: SelectableText(
                                email,
                                style: GoogleFonts.robotoMono(fontWeight: FontWeight.bold, fontSize: 13, color: const Color(0xFF0F172A)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 72,
                              child: Text('Password:', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B), fontWeight: FontWeight.w600)),
                            ),
                            Expanded(
                              child: SelectableText(
                                tempPassword,
                                style: GoogleFonts.robotoMono(fontWeight: FontWeight.bold, color: const Color(0xFF4F46E5), fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton.icon(
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('Copy Credentials'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: 'Stepz CRM Super Admin Login\nEmail: $email\nPassword: $tempPassword'));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Credentials copied to clipboard!')));
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Done', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showResetPasswordDialog(Map<String, dynamic> admin) {
    final passwordCtrl = TextEditingController();
    final compProv = context.read<CompanyProvider>();
    final messenger = ScaffoldMessenger.of(context);
    bool isResetting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.key_rounded, color: Color(0xFFD97706), size: 24),
                const SizedBox(width: 10),
                Text('Reset Password', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reset login password for ${admin['full_name']} (${admin['email']}).',
                  style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF475569)),
                ),
                const SizedBox(height: 14),
                GlassTextField(
                  label: 'New Password (or leave blank to auto-generate)',
                  hintText: '••••••••••',
                  controller: passwordCtrl,
                  obscureText: true,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706)),
                onPressed: isResetting
                    ? null
                    : () async {
                        setModalState(() => isResetting = true);
                        final res = await compProv.resetSuperAdminPassword(
                          admin['id'].toString(),
                          newPassword: passwordCtrl.text.trim(),
                        );
                        setModalState(() => isResetting = false);
                        if (res != null && mounted) {
                          Navigator.pop(dialogCtx);
                          _showCredentialsModal(
                            email: admin['email'],
                            fullName: admin['full_name'] ?? 'Super Admin',
                            tempPassword: res['temp_password'] ?? 'Updated',
                            title: 'Password Reset Successfully',
                          );
                        } else if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(content: Text(compProv.errorMessage ?? 'Failed to reset password')),
                          );
                        }
                      },
                child: Text(isResetting ? 'Resetting...' : 'Confirm Reset', style: const TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showPortfolioModal(Map<String, dynamic> admin) {
    final companies = List<Map<String, dynamic>>.from(admin['companies'] ?? []);
    final isMobile = ResponsiveLayout.isMobile(context);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(isMobile ? 12 : 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680, maxHeight: 600),
          child: GlassCard(
            blur: 24,
            opacity: 0.98,
            borderRadius: BorderRadius.circular(22),
            borderColor: const Color(0xFFCBD5E1),
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            child: Column(
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
                      child: const Icon(Icons.domain_rounded, color: Color(0xFF2563EB), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${admin['full_name']}\'s Portfolio',
                            style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                          ),
                          Text(
                            '${companies.length} Tenant Companies managed by ${admin['email']}',
                            style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: companies.isEmpty
                      ? Center(
                          child: Text('No companies onboarded yet by this Super Admin.', style: GoogleFonts.inter(color: const Color(0xFF64748B))),
                        )
                      : ListView.separated(
                          itemCount: companies.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (ctx, i) {
                            final comp = companies[i];
                            final isActive = comp['status'] == 'ACTIVE';
                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  CompanyLogoView(
                                    logo: comp['logo'] ?? '',
                                    companyName: comp['name'] ?? 'Company',
                                    size: 38,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          comp['name'] ?? 'Company',
                                          style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                                        ),
                                        Text(
                                          '${comp['subdomain'] != null && comp['subdomain'].toString().isNotEmpty ? "${comp['subdomain']}.stepzcrm.com • " : ""}${comp['contact_email'] ?? ""}',
                                          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF3C7),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFFD4AF37)),
                                    ),
                                    child: Text(
                                      comp['plan_name'] ?? 'Starter',
                                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF92400E)),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isActive ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      isActive ? 'Active' : 'Suspended',
                                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: isActive ? const Color(0xFF059669) : const Color(0xFFDC2626)),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showReassignModal(Map<String, dynamic> sourceAdmin, List<Map<String, dynamic>> allAdmins) {
    String? targetAdminId;
    final otherAdmins = allAdmins.where((a) => a['id'] != sourceAdmin['id']).toList();
    if (otherAdmins.isNotEmpty) {
      targetAdminId = otherAdmins.first['id']?.toString();
    }
    final compProv = context.read<CompanyProvider>();
    final messenger = ScaffoldMessenger.of(context);
    bool isReassigning = false;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.swap_horiz_rounded, color: Color(0xFF2563EB), size: 24),
                const SizedBox(width: 10),
                Text('Reassign Tenant Portfolio', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Transfer all ${sourceAdmin['total_tenants']} company tenants currently managed by ${sourceAdmin['full_name']} to another Super Admin.',
                  style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF475569)),
                ),
                const SizedBox(height: 16),
                Text('Transfer Portfolio To:', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF334155))),
                const SizedBox(height: 6),
                if (otherAdmins.isEmpty)
                  Text('No other Super Admins available to receive tenants.', style: GoogleFonts.inter(fontSize: 12, color: Colors.red))
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: targetAdminId,
                      underline: const SizedBox.shrink(),
                      dropdownColor: Colors.white,
                      items: otherAdmins.map((a) {
                        return DropdownMenuItem<String>(
                          value: a['id']?.toString(),
                          child: Text('${a['full_name']} (${a['email']})', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                        );
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) setModalState(() => targetAdminId = v);
                      },
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                onPressed: (isReassigning || otherAdmins.isEmpty || targetAdminId == null)
                    ? null
                    : () async {
                        setModalState(() => isReassigning = true);
                        final ok = await compProv.reassignTenants(
                          fromSuperAdminId: sourceAdmin['id'].toString(),
                          toSuperAdminId: targetAdminId!,
                        );
                        setModalState(() => isReassigning = false);
                        if (ok && mounted) {
                          Navigator.pop(dialogCtx);
                          messenger.showSnackBar(
                            const SnackBar(content: Text('Tenants reassigned successfully!'), backgroundColor: Color(0xFF059669)),
                          );
                        }
                      },
                child: Text(isReassigning ? 'Transferring...' : 'Confirm Reassignment', style: const TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final compProv = context.watch<CompanyProvider>();
    final currentUserId = context.watch<AuthProvider>().currentUser?.id;
    final isMobile = ResponsiveLayout.isMobile(context);

    // Filtering logic
    final query = _searchController.text.trim().toLowerCase();
    final filteredAdmins = compProv.superAdmins.where((sa) {
      final name = (sa['full_name'] ?? '').toString().toLowerCase();
      final email = (sa['email'] ?? '').toString().toLowerCase();
      final phone = (sa['phone'] ?? '').toString().toLowerCase();
      final matchesQuery = query.isEmpty || name.contains(query) || email.contains(query) || phone.contains(query);

      if (!matchesQuery) return false;

      final isMaster = sa['is_master_admin'] == true || sa['role'] == 'MASTER_ADMIN';
      final isActive = sa['is_active'] != false;

      if (_activeTab == 'ACTIVE') return isActive;
      if (_activeTab == 'SUSPENDED') return !isActive;
      if (_activeTab == 'MASTER') return isMaster;
      return true;
    }).toList();

    final totalAdmins = compProv.totalSuperAdmins;
    final hasCompaniesLoaded = compProv.companies.isNotEmpty;
    final totalCompanies = hasCompaniesLoaded ? compProv.companies.length : compProv.totalPlatformTenants;
    final activeCompaniesFromAdmins = compProv.superAdmins.fold<int>(0, (sum, a) => sum + (a['active_tenants'] as int? ?? 0));
    final activeCompanies = hasCompaniesLoaded
        ? compProv.companies.where((c) => c.isActive).length
        : activeCompaniesFromAdmins;
    final suspendedCompanies = hasCompaniesLoaded
        ? compProv.companies.where((c) => c.isSuspended).length
        : (totalCompanies - activeCompanies).clamp(0, totalCompanies);

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          isMobile ? 12 : 28,
          isMobile ? 8 : 16,
          isMobile ? 12 : 28,
          isMobile ? 12 : 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Header Bar
            LayoutBuilder(
              builder: (context, headerConstraints) {
                final headerLeft = Row(
                  children: [
                    const AppBackButton(fallbackRoute: AppRoutes.dashboard),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Master Super Admin',
                            style: GoogleFonts.inter(
                              fontSize: isMobile ? 18 : 24,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                              letterSpacing: -0.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Oversee onboarding partners, inspect multi-tenant quotas, and manage Super Admin credentials',
                            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                );

                final provisionButton = GradientPrimaryButton(
                  icon: Icons.person_add_alt_1_rounded,
                  text: 'Provision Super Admin',
                  onPressed: _showProvisionSuperAdminDialog,
                );

                if (!isMobile && headerConstraints.maxWidth >= 680) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(child: headerLeft),
                      const SizedBox(width: 16),
                      provisionButton,
                    ],
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    headerLeft,
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: provisionButton,
                    ),
                  ],
                );
              },
            ),
            SizedBox(height: isMobile ? 12 : 18),

            // Responsive 4-KPI Grid
            _buildResponsiveKpiGrid(
              isMobile: isMobile,
              totalAdmins: totalAdmins,
              totalCompanies: totalCompanies,
              activeCompanies: activeCompanies,
              suspendedCompanies: suspendedCompanies,
            ),
            SizedBox(height: isMobile ? 12 : 18),

            // Controls: Search & Filter Tabs
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Filter Tabs (Responsive Wrap — never overflows!)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _buildTabChip('ALL', 'All Admins (${compProv.superAdmins.length})'),
                    _buildTabChip('ACTIVE', 'Active (${compProv.superAdmins.where((a) => a['is_active'] != false).length})'),
                    _buildTabChip('SUSPENDED', 'Suspended (${compProv.superAdmins.where((a) => a['is_active'] == false).length})'),
                    _buildTabChip('MASTER', 'Masters (${compProv.superAdmins.where((a) => a['is_master_admin'] == true || a['role'] == 'MASTER_ADMIN').length})'),
                  ],
                ),
                // Search Input
                SizedBox(
                  width: isMobile ? double.infinity : 260,
                  height: 38,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    style: GoogleFonts.inter(fontSize: 12.5),
                    decoration: InputDecoration(
                      hintText: 'Search super admin...',
                      hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, size: 16),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Super Admins Directory List
            Expanded(
              child: compProv.isLoadingSuperAdmins
                  ? const Center(child: CircularProgressIndicator())
                  : filteredAdmins.isEmpty
                      ? Center(
                          child: GlassCard(
                            padding: const EdgeInsets.all(32),
                            opacity: 0.90,
                            child: Text('No Super Admins match the selected filters.', style: GoogleFonts.inter(color: const Color(0xFF64748B))),
                          ),
                        )
                      : ListView.separated(
                          itemCount: filteredAdmins.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (ctx, i) {
                            final admin = filteredAdmins[i];
                            return _buildSuperAdminCard(
                              admin: admin,
                              isSelf: admin['id'] == currentUserId,
                              isMobile: isMobile,
                              allAdmins: compProv.superAdmins,
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResponsiveKpiGrid({
    required bool isMobile,
    required int totalAdmins,
    required int totalCompanies,
    required int activeCompanies,
    required int suspendedCompanies,
  }) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final isNarrow = isMobile || constraints.maxWidth < 760;
        if (isNarrow) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: _buildMetricTile(icon: Icons.shield_outlined, label: 'Super Admins', value: '$totalAdmins', color: const Color(0xFF4338CA), bg: const Color(0xFFEEF2FF))),
                  const SizedBox(width: 8),
                  Expanded(child: _buildMetricTile(icon: Icons.apartment_rounded, label: 'Total Companies', value: '$totalCompanies', color: const Color(0xFF0284C7), bg: const Color(0xFFF0F9FF))),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _buildMetricTile(icon: Icons.check_circle_outline_rounded, label: 'Active Companies', value: '$activeCompanies', color: const Color(0xFF059669), bg: const Color(0xFFECFDF5))),
                  const SizedBox(width: 8),
                  Expanded(child: _buildMetricTile(icon: Icons.pause_circle_outline_rounded, label: 'Suspended Companies', value: '$suspendedCompanies', color: const Color(0xFFDC2626), bg: const Color(0xFFFEF2F2))),
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: _buildMetricTile(icon: Icons.shield_outlined, label: 'Super Admins', value: '$totalAdmins', color: const Color(0xFF4338CA), bg: const Color(0xFFEEF2FF))),
            const SizedBox(width: 12),
            Expanded(child: _buildMetricTile(icon: Icons.apartment_rounded, label: 'Total Companies', value: '$totalCompanies', color: const Color(0xFF0284C7), bg: const Color(0xFFF0F9FF))),
            const SizedBox(width: 12),
            Expanded(child: _buildMetricTile(icon: Icons.check_circle_outline_rounded, label: 'Active Companies', value: '$activeCompanies', color: const Color(0xFF059669), bg: const Color(0xFFECFDF5))),
            const SizedBox(width: 12),
            Expanded(child: _buildMetricTile(icon: Icons.pause_circle_outline_rounded, label: 'Suspended Companies', value: '$suspendedCompanies', color: const Color(0xFFDC2626), bg: const Color(0xFFFEF2F2))),
          ],
        );
      },
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w800, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(label, style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: color.withValues(alpha: 0.85)), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabChip(String key, String title) {
    final isSelected = _activeTab == key;
    return InkWell(
      onTap: () => setState(() => _activeTab = key),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0)),
        ),
        child: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildSuperAdminCard({
    required Map<String, dynamic> admin,
    required bool isSelf,
    required bool isMobile,
    required List<Map<String, dynamic>> allAdmins,
  }) {
    final isMaster = admin['is_master_admin'] == true || admin['role'] == 'MASTER_ADMIN';
    final isActive = admin['is_active'] != false;
    final totalTenants = admin['total_tenants'] ?? 0;
    final activeTenants = admin['active_tenants'] ?? 0;
    final totalUsers = admin['total_users'] ?? 0;
    final companies = List<Map<String, dynamic>>.from(admin['companies'] ?? []);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isMaster ? const Color(0xFFC7D2FE) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 14, vertical: 4),
          childrenPadding: EdgeInsets.fromLTRB(isMobile ? 10 : 14, 0, isMobile ? 10 : 14, 12),
          leading: CircleAvatar(
            radius: 17,
            backgroundColor: isMaster ? const Color(0xFF4338CA) : const Color(0xFF0284C7),
            child: Text(
              (admin['first_name'] as String? ?? 'A').isNotEmpty ? (admin['first_name'] as String)[0].toUpperCase() : 'A',
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          title: Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                admin['full_name'] ?? admin['email'],
                style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                overflow: TextOverflow.ellipsis,
              ),
              if (isSelf)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(4)),
                  child: Text('You', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF166534))),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isMaster ? const Color(0xFFEEF2FF) : const Color(0xFFF0F9FF),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: isMaster ? const Color(0xFFC7D2FE) : const Color(0xFFBAE6FD)),
                ),
                child: Text(
                  isMaster ? 'Master Admin' : 'Super Admin',
                  style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: isMaster ? const Color(0xFF4338CA) : const Color(0xFF0284C7)),
                ),
              ),
            ],
          ),
          subtitle: Text(
            '${admin['email']} · $totalTenants Companies · $totalUsers Staff',
            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isActive ? 'Active' : 'Suspended',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isActive ? const Color(0xFF059669) : const Color(0xFFDC2626),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.expand_more_rounded, size: 20, color: Color(0xFF64748B)),
            ],
          ),
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Flexible(child: _buildStatPill(Icons.apartment_rounded, '$totalTenants Companies', '$activeTenants active')),
                  Container(width: 1, height: 20, color: const Color(0xFFE2E8F0)),
                  Flexible(child: _buildStatPill(Icons.people_outline_rounded, '$totalUsers Staff', 'telecallers')),
                ],
              ),
            ),
            if (companies.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.domain_verification_rounded, size: 13, color: Color(0xFF475569)),
                        const SizedBox(width: 5),
                        Text(
                          'Assigned Tenants (${companies.length}):',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF334155)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: companies.take(6).map((c) {
                        final isCompActive = c['status'] == 'ACTIVE';
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Text(
                            '${c['name']} (${c['plan_name'] ?? "Starter"})',
                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: isCompActive ? const Color(0xFF0F172A) : const Color(0xFFDC2626)),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  icon: const Icon(Icons.remove_red_eye_outlined, size: 14, color: Color(0xFF334155)),
                  label: Text('View Portfolio ($totalTenants)', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
                  onPressed: () => _showPortfolioModal(admin),
                ),
                if (totalTenants > 0)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      side: const BorderSide(color: Color(0xFF93C5FD)),
                    ),
                    icon: const Icon(Icons.swap_horiz_rounded, size: 14, color: Color(0xFF2563EB)),
                    label: Text('Reassign', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF2563EB))),
                    onPressed: () => _showReassignModal(admin, allAdmins),
                  ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    side: const BorderSide(color: Color(0xFFFDE68A)),
                  ),
                  icon: const Icon(Icons.key_rounded, size: 14, color: Color(0xFFD97706)),
                  label: Text('Reset Password', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFD97706))),
                  onPressed: () => _showResetPasswordDialog(admin),
                ),
                if (!isSelf)
                  TextButton.icon(
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                    icon: Icon(isActive ? Icons.block_rounded : Icons.check_circle_outline_rounded, size: 14, color: isActive ? const Color(0xFFDC2626) : const Color(0xFF059669)),
                    label: Text(
                      isActive ? 'Deactivate' : 'Activate',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: isActive ? const Color(0xFFDC2626) : const Color(0xFF059669)),
                    ),
                    onPressed: () async {
                      await context.read<CompanyProvider>().toggleSuperAdminStatus(admin['id']?.toString() ?? '');
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatPill(IconData icon, String primary, String secondary) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF64748B)),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(primary, style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B))),
            Text(secondary, style: GoogleFonts.inter(fontSize: 9.5, color: const Color(0xFF64748B))),
          ],
        ),
      ],
    );
  }
}

