import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/widgets/glass/glass_card.dart';
import '../../core/widgets/glass/gradient_button.dart';
import '../../core/widgets/glass/glass_text_field.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../providers/company_provider.dart';
import '../../providers/auth_provider.dart';

class SuperAdminManagementDialog extends StatefulWidget {
  final Function(String? superAdminId)? onSelectFilter;

  const SuperAdminManagementDialog({super.key, this.onSelectFilter});

  static Future<void> show(BuildContext context, {Function(String? superAdminId)? onSelectFilter}) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (_) => SuperAdminManagementDialog(onSelectFilter: onSelectFilter),
    );
  }

  @override
  State<SuperAdminManagementDialog> createState() => _SuperAdminManagementDialogState();
}

class _SuperAdminManagementDialogState extends State<SuperAdminManagementDialog> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CompanyProvider>().fetchSuperAdmins();
    });
  }

  void _showAddSuperAdminModal() {
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
              constraints: const BoxConstraints(maxWidth: 480),
              child: GlassCard(
                blur: 24,
                opacity: 0.98,
                borderRadius: BorderRadius.circular(20),
                borderColor: const Color(0xFF6366F1),
                padding: EdgeInsets.all(isMobile ? 18 : 28),
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
                          child: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF4F46E5), size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Add New Super Admin',
                                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                              ),
                              Text(
                                'Provision a partner or regional administrator',
                                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
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
                            hintText: 'e.g. Anandhu',
                            controller: firstNameCtrl,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GlassTextField(
                            label: 'Last Name',
                            hintText: 'e.g. Kumar',
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
                      label: 'Password (leave blank for auto-generate)',
                      hintText: '••••••••••',
                      controller: passwordCtrl,
                      obscureText: true,
                    ),
                    const SizedBox(height: 14),
                    // Role Picker
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Text('Administrative Tier:', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF475569))),
                          const Spacer(),
                          DropdownButton<String>(
                            value: role,
                            underline: const SizedBox.shrink(),
                            dropdownColor: Colors.white,
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)),
                            items: const [
                              DropdownMenuItem(value: 'SUPER_ADMIN', child: Text('Super Admin (Scoped)')),
                              DropdownMenuItem(value: 'MASTER_ADMIN', child: Text('Master Admin (Root)')),
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
                      text: isSaving ? 'Creating Super Admin...' : 'Create Super Admin',
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
                                _showCreatedCredentialsModal(
                                  email: email,
                                  fullName: '$firstName ${lastNameCtrl.text.trim()}'.trim(),
                                  tempPassword: res['temp_password'] ?? 'Generated',
                                );
                              } else if (mounted) {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(compProv.errorMessage ?? 'Failed to create Super Admin'),
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
          );
        },
      ),
    );
  }

  void _showCreatedCredentialsModal({
    required String email,
    required String fullName,
    required String tempPassword,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 24),
            const SizedBox(width: 10),
            Text('Super Admin Provisioned', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Credentials for $fullName:', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B))),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Email: $email', style: GoogleFonts.robotoMono(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  Text('Password: $tempPassword', style: GoogleFonts.robotoMono(fontWeight: FontWeight.bold, color: const Color(0xFF4F46E5), fontSize: 13)),
                ],
              ),
            ),
          ],
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
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A)),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done', style: TextStyle(color: Colors.white)),
          ),
        ],
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(isMobile ? 10 : 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 880, maxHeight: MediaQuery.of(context).size.height * 0.92),
        child: GlassCard(
          blur: 24,
          opacity: 0.98,
          borderRadius: BorderRadius.circular(24),
          borderColor: const Color(0xFFCBD5E1),
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFC7D2FE)),
                    ),
                    child: const Icon(Icons.shield_outlined, color: Color(0xFF4338CA), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Super Admin Directory',
                              style: GoogleFonts.inter(fontSize: isMobile ? 16 : 20, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFF818CF8)),
                              ),
                              child: Text(
                                'Master Oversight',
                                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF4338CA)),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Track partner tenant onboarding, capacity, and active quotas',
                          style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  GradientPrimaryButton(
                    text: isMobile ? '+ Add' : '+ Add Super Admin',
                    icon: Icons.person_add_alt_1_rounded,
                    onPressed: _showAddSuperAdminModal,
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 22),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // KPI Stats Grid
              Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      icon: Icons.shield_outlined,
                      label: 'Super Admins',
                      value: '${compProv.totalSuperAdmins}',
                      color: const Color(0xFF4338CA),
                      bg: const Color(0xFFEEF2FF),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricTile(
                      icon: Icons.apartment_rounded,
                      label: 'Platform Tenants',
                      value: '${compProv.totalPlatformTenants}',
                      color: const Color(0xFF059669),
                      bg: const Color(0xFFECFDF5),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricTile(
                      icon: Icons.groups_rounded,
                      label: 'Managed Staff',
                      value: '${compProv.superAdmins.fold<int>(0, (sum, a) => sum + (a['total_users'] as int? ?? 0))}',
                      color: const Color(0xFFD97706),
                      bg: const Color(0xFFFFFBEB),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Super Admin Cards List
              Expanded(
                child: compProv.isLoadingSuperAdmins
                    ? const Center(child: CircularProgressIndicator())
                    : compProv.superAdmins.isEmpty
                        ? Center(
                            child: Text('No Super Admins found.', style: GoogleFonts.inter(color: const Color(0xFF64748B))),
                          )
                        : ListView.separated(
                            itemCount: compProv.superAdmins.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, idx) {
                              final sa = compProv.superAdmins[idx];
                              final isSelf = sa['id'] == currentUserId;
                              final isMaster = sa['is_master_admin'] == true || sa['role'] == 'MASTER_ADMIN';
                              final isActive = sa['is_active'] != false;
                              final totalTenants = sa['total_tenants'] ?? 0;
                              final activeTenants = sa['active_tenants'] ?? 0;
                              final totalUsers = sa['total_users'] ?? 0;

                              return Container(
                                padding: EdgeInsets.all(isMobile ? 12 : 16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: isMaster ? const Color(0xFFC7D2FE) : const Color(0xFFE2E8F0)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.03),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 20,
                                          backgroundColor: isMaster ? const Color(0xFF4338CA) : const Color(0xFF0284C7),
                                          child: Text(
                                            (sa['first_name'] as String? ?? 'A').isNotEmpty ? (sa['first_name'] as String)[0].toUpperCase() : 'A',
                                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white),
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
                                                      sa['full_name'] ?? sa['email'],
                                                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  if (isSelf) ...[
                                                    const SizedBox(width: 6),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFFDCFCE7),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: Text('You', style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFF166534))),
                                                    ),
                                                  ],
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                                    decoration: BoxDecoration(
                                                      color: isMaster ? const Color(0xFFEEF2FF) : const Color(0xFFF0F9FF),
                                                      borderRadius: BorderRadius.circular(4),
                                                      border: Border.all(color: isMaster ? const Color(0xFFC7D2FE) : const Color(0xFFBAE6FD)),
                                                    ),
                                                    child: Text(
                                                      isMaster ? 'Master Admin' : 'Super Admin',
                                                      style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w700, color: isMaster ? const Color(0xFF4338CA) : const Color(0xFF0284C7)),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${sa['email']}${sa['phone'] != null && (sa['phone'] as String).isNotEmpty ? ' • ${sa['phone']}' : ''}',
                                                style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Status Pill
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: isActive ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            isActive ? 'Active' : 'Suspended',
                                            style: GoogleFonts.inter(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.bold,
                                              color: isActive ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    // Portfolio Metrics Bar
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                                        children: [
                                          _buildMiniStat(Icons.domain_rounded, '$totalTenants Tenants', '$activeTenants active'),
                                          Container(width: 1, height: 20, color: const Color(0xFFE2E8F0)),
                                          _buildMiniStat(Icons.people_outline_rounded, '$totalUsers Staff', 'across portfolio'),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    // Action Buttons Row
                                    Row(
                                      children: [
                                        OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                                          ),
                                          icon: const Icon(Icons.filter_alt_outlined, size: 14, color: Color(0xFF334155)),
                                          label: Text('View Tenants', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
                                          onPressed: () {
                                            widget.onSelectFilter?.call(sa['id']?.toString());
                                            Navigator.pop(context);
                                          },
                                        ),
                                        const SizedBox(width: 8),
                                        if (totalTenants > 0)
                                          OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              side: const BorderSide(color: Color(0xFF60A5FA)),
                                            ),
                                            icon: const Icon(Icons.swap_horiz_rounded, size: 14, color: Color(0xFF2563EB)),
                                            label: Text('Reassign', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF2563EB))),
                                            onPressed: () => _showReassignModal(sa, compProv.superAdmins),
                                          ),
                                        const Spacer(),
                                        if (!isSelf)
                                          TextButton.icon(
                                            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                                            icon: Icon(isActive ? Icons.block_rounded : Icons.check_circle_outline_rounded, size: 14, color: isActive ? const Color(0xFFDC2626) : const Color(0xFF059669)),
                                            label: Text(
                                              isActive ? 'Deactivate' : 'Activate',
                                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: isActive ? const Color(0xFFDC2626) : const Color(0xFF059669)),
                                            ),
                                            onPressed: () async {
                                              await compProv.toggleSuperAdminStatus(sa['id']?.toString() ?? '');
                                            },
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
          ),
        ),
      ),
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
              Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: color.withValues(alpha: 0.8))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String primary, String secondary) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF64748B)),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(primary, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B))),
            Text(secondary, style: GoogleFonts.inter(fontSize: 9.5, color: const Color(0xFF64748B))),
          ],
        ),
      ],
    );
  }
}

