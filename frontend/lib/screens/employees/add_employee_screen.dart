import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/glass/app_background.dart';
import '../../core/widgets/glass/glass_card.dart';
import '../../core/widgets/glass/glass_text_field.dart';
import '../../core/widgets/glass/gradient_button.dart';
import '../../models/role_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/company_provider.dart';
import '../../providers/department_provider.dart';
import '../../providers/employee_provider.dart';
import '../../providers/lead_provider.dart';
import '../../providers/role_provider.dart';
import '../../routes/app_routes.dart';

class AddEmployeeScreen extends StatefulWidget {
  const AddEmployeeScreen({super.key});

  @override
  State<AddEmployeeScreen> createState() => _AddEmployeeScreenState();
}

class _AddEmployeeScreenState extends State<AddEmployeeScreen> {
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _targetCtrl = TextEditingController(text: '50');
  final _shiftStartCtrl = TextEditingController(text: '09:00:00');
  final _shiftEndCtrl = TextEditingController(text: '18:00:00');
  final _graceCtrl = TextEditingController(text: '15');

  String? _selectedDepartmentId;
  String? _selectedBranchId;
  List<String> _selectedAllowedBranches = [];
  final List<String> _selectedRoleIds = [];
  bool _isSubmitting = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authUser = context.read<AuthProvider>().currentUser;
      if (authUser?.branchId != null && _selectedBranchId == null) {
        setState(() {
          _selectedBranchId = authUser!.branchId;
          _selectedAllowedBranches = [authUser.branchId!];
        });
      }
      context.read<LeadProvider>().fetchBranches();
      context.read<RoleProvider>().fetchRoles();
      context.read<DepartmentProvider>().fetchDepartments();
      context.read<CompanyProvider>().fetchFeatureCatalog();
    });
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _targetCtrl.dispose();
    _shiftStartCtrl.dispose();
    _shiftEndCtrl.dispose();
    _graceCtrl.dispose();
    super.dispose();
  }

  bool get _isCompanyAdmin {
    final u = context.read<AuthProvider>().currentUser;
    return u?.role == 'COMPANY_ADMIN' || (u?.isMasterAdmin ?? false);
  }

  bool get _canCreateBranch {
    final u = context.read<AuthProvider>().currentUser;
    if (u == null) return false;
    final companyHasBranches = u.companyAllowedMenus.contains('branches');
    return companyHasBranches &&
        (_isCompanyAdmin ||
            u.canManageBranches ||
            u.resolvedPermissions.contains('branches.manage') ||
            u.resolvedPermissions.contains('settings.manage'));
  }

  bool get _canCreateRole {
    final u = context.read<AuthProvider>().currentUser;
    if (u == null) return false;
    return _isCompanyAdmin || u.resolvedPermissions.contains('roles.manage');
  }

  bool get _canCreateDepartment {
    final u = context.read<AuthProvider>().currentUser;
    if (u == null) return false;
    return _isCompanyAdmin ||
        u.resolvedPermissions.contains('employees.manage') ||
        u.resolvedPermissions.contains('settings.manage');
  }

  Future<void> _submitEmployee() async {
    if (_firstNameCtrl.text.trim().isEmpty ||
        _emailCtrl.text.trim().isEmpty ||
        _passwordCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('First name, email, and password are required'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final empP = context.read<EmployeeProvider>();
    final ok = await empP.createEmployee({
      'email': _emailCtrl.text.trim(),
      'password': _passwordCtrl.text,
      'first_name': _firstNameCtrl.text.trim(),
      'last_name': _lastNameCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'role': 'EMPLOYEE',
      'branch': _selectedBranchId,
      'department_id': _selectedDepartmentId,
      'allowed_branches': _selectedAllowedBranches,
      'custom_role_ids': _selectedRoleIds,
      'daily_call_target': int.tryParse(_targetCtrl.text) ?? 50,
      'shift_start_time': _shiftStartCtrl.text.trim(),
      'shift_end_time': _shiftEndCtrl.text.trim(),
      'grace_period_minutes': int.tryParse(_graceCtrl.text) ?? 15,
    });
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Employee onboarded successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(empP.errorMessage ?? 'Failed to create employee'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _showQuickDepartmentDialog() async {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    String attendanceMode = 'GEOFENCE';
    bool saving = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              const Icon(Icons.apartment_rounded, color: AppColors.neonViolet),
              const SizedBox(width: 8),
              Text('Quick Create Department',
                  style: GoogleFonts.inter(
                      fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GlassTextField(
                  label: 'Department Name *',
                  hintText: 'e.g. Inside Sales / Field Team',
                  controller: nameCtrl,
                ),
                const SizedBox(height: 10),
                GlassTextField(
                  label: 'Department Code',
                  hintText: 'e.g. SALES-01',
                  controller: codeCtrl,
                ),
                const SizedBox(height: 12),
                Text('Attendance Tracking Mode',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B))),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: attendanceMode,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(
                            value: 'GEOFENCE',
                            child: Text('Office Geo-fence (Fixed Branch)')),
                        DropdownMenuItem(
                            value: 'FIELD',
                            child: Text('Field Staff (Dynamic GPS)')),
                      ],
                      onChanged: (v) =>
                          setDlgState(() => attendanceMode = v ?? 'GEOFENCE'),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.neonViolet,
                foregroundColor: Colors.white,
              ),
              onPressed: saving
                  ? null
                  : () async {
                      if (nameCtrl.text.trim().isEmpty) return;
                      setDlgState(() => saving = true);
                      final deptP = context.read<DepartmentProvider>();
                      final messenger = ScaffoldMessenger.of(context);
                      final created = await deptP.createDepartment(
                        name: nameCtrl.text.trim(),
                        code: codeCtrl.text.trim(),
                        attendanceMode: attendanceMode,
                        allowedBranches: _selectedAllowedBranches,
                      );
                      if (!ctx.mounted) return;
                      setDlgState(() => saving = false);
                      if (created != null) {
                        setState(() => _selectedDepartmentId = created.id);
                        Navigator.pop(ctx);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                                'Department "${created.name}" created & selected'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      }
                    },
              child: Text(saving ? 'Saving...' : 'Create & Select'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showQuickBranchDialog() async {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    bool saving = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              const Icon(Icons.store_rounded, color: AppColors.neonViolet),
              const SizedBox(width: 8),
              Text('Quick Create Branch',
                  style: GoogleFonts.inter(
                      fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GlassTextField(
                  label: 'Branch Name *',
                  hintText: 'e.g. Kochi Main Branch',
                  controller: nameCtrl,
                ),
                const SizedBox(height: 10),
                GlassTextField(
                  label: 'Branch Code',
                  hintText: 'e.g. KCH-01',
                  controller: codeCtrl,
                ),
                const SizedBox(height: 10),
                GlassTextField(
                  label: 'Address / Location',
                  hintText: 'City, street or landmark',
                  controller: addressCtrl,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.neonViolet,
                foregroundColor: Colors.white,
              ),
              onPressed: saving
                  ? null
                  : () async {
                      if (nameCtrl.text.trim().isEmpty) return;
                      setDlgState(() => saving = true);
                      final leadP = context.read<LeadProvider>();
                      final messenger = ScaffoldMessenger.of(context);
                      final ok = await leadP.createBranch(
                        name: nameCtrl.text.trim(),
                        code: codeCtrl.text.trim(),
                        address: addressCtrl.text.trim(),
                      );
                      if (!ctx.mounted) return;
                      setDlgState(() => saving = false);
                      if (ok && leadP.branches.isNotEmpty) {
                        final created = leadP.branches.last;
                        setState(() {
                          _selectedBranchId = created.id;
                          if (!_selectedAllowedBranches.contains(created.id)) {
                            _selectedAllowedBranches.add(created.id);
                          }
                        });
                        Navigator.pop(ctx);
                        messenger.showSnackBar(
                          SnackBar(
                            content:
                                Text('Branch "${created.name}" created & selected'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      }
                    },
              child: Text(saving ? 'Saving...' : 'Create & Select'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showQuickRoleDialog() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final selectedPerms = <String>{};
    bool saving = false;

    final authUser = context.read<AuthProvider>().currentUser;
    final isAdmin = _isCompanyAdmin;

    const presets = <String, List<String>>{
      'Telecaller': [
        'leads.view',
        'calls.make',
        'callbacks.manage',
        'tasks.view',
        'attendance.view',
      ],
      'Field Executive': [
        'leads.view',
        'leads.edit',
        'tasks.view',
        'attendance.view',
        'quotations.create',
      ],
      'Billing Staff': [
        'leads.view',
        'quotations.view',
        'quotations.create',
        'billing.view',
        'billing.create',
      ],
      'Branch Manager': [
        'employees.view',
        'employees.manage',
        'leads.view',
        'leads.assign',
        'tasks.manage',
        'analytics.view',
      ],
    };

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              const Icon(Icons.security_rounded, color: AppColors.neonCyan),
              const SizedBox(width: 8),
              Text('Quick Create Functional Role',
                  style: GoogleFonts.inter(
                      fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GlassTextField(
                    label: 'Role Name *',
                    hintText: 'e.g. Senior Telecaller',
                    controller: nameCtrl,
                  ),
                  const SizedBox(height: 10),
                  GlassTextField(
                    label: 'Description',
                    hintText: 'Short summary of responsibilities',
                    controller: descCtrl,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Quick Presets',
                    style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF475569)),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: presets.entries.map((entry) {
                      return ActionChip(
                        label: Text(entry.key,
                            style: GoogleFonts.inter(fontSize: 11)),
                        onPressed: () {
                          setDlgState(() {
                            if (nameCtrl.text.trim().isEmpty) {
                              nameCtrl.text = entry.key;
                            }
                            selectedPerms.clear();
                            for (final p in entry.value) {
                              if (isAdmin ||
                                  (authUser?.resolvedPermissions.contains(p) ??
                                      false)) {
                                selectedPerms.add(p);
                              }
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Permissions (${selectedPerms.length} selected)',
                    style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF475569)),
                  ),
                  const SizedBox(height: 6),
                  ...PermissionCatalog.categorizedPermissions.entries.map((cat) {
                    final allowedItems = cat.value.where((item) {
                      if (isAdmin) return true;
                      return authUser?.resolvedPermissions
                              .contains(item['key']) ??
                          false;
                    }).toList();
                    if (allowedItems.isEmpty) return const SizedBox.shrink();
                    return ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Text(cat.key,
                          style: GoogleFonts.inter(
                              fontSize: 12.5, fontWeight: FontWeight.w700)),
                      children: allowedItems.map((perm) {
                        final key = perm['key']!;
                        return CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          value: selectedPerms.contains(key),
                          title: Text(perm['label']!,
                              style: GoogleFonts.inter(
                                  fontSize: 12, fontWeight: FontWeight.w600)),
                          subtitle: Text(perm['desc']!,
                              style: GoogleFonts.inter(
                                  fontSize: 10.5,
                                  color: const Color(0xFF64748B))),
                          onChanged: (v) {
                            setDlgState(() {
                              if (v == true) {
                                selectedPerms.add(key);
                              } else {
                                selectedPerms.remove(key);
                              }
                            });
                          },
                        );
                      }).toList(),
                    );
                  }),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.neonCyan,
                foregroundColor: Colors.white,
              ),
              onPressed: saving
                  ? null
                  : () async {
                      if (nameCtrl.text.trim().isEmpty) return;
                      setDlgState(() => saving = true);
                      final roleP = context.read<RoleProvider>();
                      final messenger = ScaffoldMessenger.of(context);
                      final created = await roleP.createRole(
                        name: nameCtrl.text.trim(),
                        description: descCtrl.text.trim(),
                        permissions: selectedPerms.toList(),
                      );
                      if (!ctx.mounted) return;
                      setDlgState(() => saving = false);
                      if (created != null) {
                        setState(() {
                          if (!_selectedRoleIds.contains(created.id)) {
                            _selectedRoleIds.add(created.id);
                          }
                        });
                        Navigator.pop(ctx);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                                'Role "${created.name}" created & assigned'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      }
                    },
              child: Text(saving ? 'Creating...' : 'Create & Assign'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showFeatureDetailsDialog(
    Map<String, dynamic> feature, {
    String requestType = 'COMPANY_FEATURE',
  }) async {
    final noteCtrl = TextEditingController();
    final isEnabled = feature['is_enabled'] == true;
    final hasPending = feature['has_pending_request'] == true;
    final highlights = (feature['highlights'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    bool sending = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              Icon(
                isEnabled && requestType == 'COMPANY_FEATURE'
                    ? Icons.verified_rounded
                    : Icons.extension_rounded,
                color: isEnabled && requestType == 'COMPANY_FEATURE'
                    ? AppColors.success
                    : AppColors.neonViolet,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  feature['name']?.toString() ?? 'Feature Details',
                  style: GoogleFonts.inter(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      feature['category']?.toString() ?? 'Module',
                      style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF475569)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    feature['description']?.toString() ?? '',
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF334155),
                        height: 1.45),
                  ),
                  if (highlights.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'What this unlocks:',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 6),
                    ...highlights.map((h) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_outline_rounded,
                                  size: 14, color: AppColors.emeraldDark),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(h,
                                    style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: const Color(0xFF475569))),
                              ),
                            ],
                          ),
                        )),
                  ],
                  if (!isEnabled || requestType == 'USER_PERMISSION') ...[
                    const SizedBox(height: 14),
                    if (hasPending)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: Colors.amber.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.hourglass_top_rounded,
                                size: 16, color: Colors.amber),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'A request for this feature is already pending approval.',
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF92400E)),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      GlassTextField(
                        label: requestType == 'COMPANY_FEATURE'
                            ? 'Reason / Note for Super Admin (Optional)'
                            : 'Reason / Note for Company Admin (Optional)',
                        hintText:
                            'Explain why your team needs this feature...',
                        controller: noteCtrl,
                        maxLines: 2,
                      ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: sending ? null : () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
            if ((!isEnabled || requestType == 'USER_PERMISSION') && !hasPending)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.neonViolet,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.send_rounded, size: 16),
                label: Text(sending
                    ? 'Sending...'
                    : (requestType == 'COMPANY_FEATURE'
                        ? 'Request Feature'
                        : 'Request Permission')),
                onPressed: sending
                    ? null
                    : () async {
                        setDlgState(() => sending = true);
                        final compP = context.read<CompanyProvider>();
                        final messenger = ScaffoldMessenger.of(context);
                        final ok = await compP.submitFeatureRequest(
                          featureKey: feature['key'].toString(),
                          featureName: feature['name'].toString(),
                          requestType: requestType,
                          note: noteCtrl.text,
                        );
                        if (!ctx.mounted) return;
                        setDlgState(() => sending = false);
                        Navigator.pop(ctx);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(ok
                                ? 'Request submitted! Admin has been notified.'
                                : (compP.errorMessage ??
                                    'Could not submit request')),
                            backgroundColor:
                                ok ? AppColors.success : AppColors.danger,
                          ),
                        );
                      },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveLayout.isMobile(context);
    final leadProvider = context.watch<LeadProvider>();
    final roleProvider = context.watch<RoleProvider>();
    final deptProvider = context.watch<DepartmentProvider>();
    final companyProvider = context.watch<CompanyProvider>();
    final authUser = context.watch<AuthProvider>().currentUser;

    final canBranch = _canCreateBranch;
    final canRole = _canCreateRole;

    final chosenDept = _selectedDepartmentId != null
        ? deptProvider.departments
            .where((d) => d.id == _selectedDepartmentId)
            .firstOrNull
        : null;

    final activePerms = <String>{};
    for (final rid in _selectedRoleIds) {
      final matching = roleProvider.roles.where((r) => r.id == rid);
      if (matching.isNotEmpty) {
        activePerms.addAll(matching.first.permissions);
      }
    }

    final leftColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildIdentityCard(),
        const SizedBox(height: 14),
        _buildWorkAndShiftCard(deptProvider, chosenDept),
      ],
    );

    final rightColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildBranchCard(leadProvider, authUser, canBranch),
        const SizedBox(height: 14),
        _buildRolesCard(roleProvider, activePerms, canRole),
        const SizedBox(height: 14),
        _buildFeatureCatalogCard(companyProvider, authUser),
      ],
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        preset: AppBackgroundPreset.cleanEnterprise,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                    isMobile ? 12 : 22, isMobile ? 12 : 18, isMobile ? 12 : 22, 8),
                child: Row(
                  children: [
                    const AppBackButton(fallbackRoute: AppRoutes.employees),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add Employee',
                            style: GoogleFonts.inter(
                              fontSize: isMobile ? 18 : 22,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'Onboard staff, assign branches & functional roles, or request additional features',
                            style: GoogleFonts.inter(
                                fontSize: 11.5, color: const Color(0xFF64748B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (!isMobile)
                      GradientPrimaryButton(
                        text: _isSubmitting ? 'Creating...' : 'Create Employee',
                        icon: Icons.check_rounded,
                        isLoading: _isSubmitting,
                        onPressed: _isSubmitting ? null : _submitEmployee,
                      ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                      isMobile ? 12 : 22, 6, isMobile ? 12 : 22, 24),
                  child: LayoutBuilder(
                    builder: (ctx, constraints) {
                      if (constraints.maxWidth >= 900) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 5, child: leftColumn),
                            const SizedBox(width: 16),
                            Expanded(flex: 6, child: rightColumn),
                          ],
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          leftColumn,
                          const SizedBox(height: 14),
                          rightColumn,
                        ],
                      );
                    },
                  ),
                ),
              ),
              if (isMobile)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GlassSecondaryButton(
                          text: 'Cancel',
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: GradientPrimaryButton(
                          text:
                              _isSubmitting ? 'Creating...' : 'Create Employee',
                          icon: Icons.check_rounded,
                          isLoading: _isSubmitting,
                          onPressed: _isSubmitting ? null : _submitEmployee,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIdentityCard() {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(18),
      borderColor: const Color(0xFFE2E8F0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Identity & Login Credentials',
            style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GlassTextField(
                  label: 'First Name *',
                  hintText: 'e.g. Arjun',
                  controller: _firstNameCtrl,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GlassTextField(
                  label: 'Last Name',
                  hintText: 'e.g. Nair',
                  controller: _lastNameCtrl,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          GlassTextField(
            label: 'Work Email *',
            hintText: 'employee@company.com',
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 10),
          GlassTextField(
            label: 'Phone Number',
            hintText: '+91 9876543210',
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 10),
          GlassTextField(
            label: 'Initial Password *',
            hintText: 'Minimum 6 characters',
            controller: _passwordCtrl,
            obscureText: _obscurePassword,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                size: 18,
                color: const Color(0xFF64748B),
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkAndShiftCard(
      DepartmentProvider deptProvider, dynamic chosenDept) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(18),
      borderColor: const Color(0xFFE2E8F0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Department & Shift Rules',
            style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A)),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Department & Tracking Mode',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B))),
              if (_canCreateDepartment)
                TextButton.icon(
                  onPressed: _showQuickDepartmentDialog,
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 15),
                  label: const Text('+ New Department'),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: deptProvider.departments
                        .any((d) => d.id == _selectedDepartmentId)
                    ? _selectedDepartmentId
                    : null,
                isExpanded: true,
                items: [
                  const DropdownMenuItem(
                      value: null, child: Text('No Department (Default)')),
                  ...deptProvider.departments.map((d) => DropdownMenuItem(
                        value: d.id,
                        child: Text(
                          '${d.name} (${d.isGeofenceMode ? 'Office Fence' : 'Field Staff'})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      )),
                ],
                onChanged: (v) {
                  setState(() {
                    _selectedDepartmentId = v;
                    if (v != null) {
                      final d = deptProvider.departments
                          .firstWhere((item) => item.id == v);
                      _selectedAllowedBranches =
                          List<String>.from(d.allowedBranches);
                    }
                  });
                },
              ),
            ),
          ),
          if (chosenDept != null) ...[
            const SizedBox(height: 8),
            Text(
              chosenDept.isGeofenceMode
                  ? 'Tracking: Fixed Office Geo-fence'
                  : 'Tracking: Field Staff (Dynamic GPS check-in)',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: chosenDept.isGeofenceMode
                    ? AppColors.neonViolet
                    : AppColors.neonCyan,
              ),
            ),
          ],
          const SizedBox(height: 12),
          GlassTextField(
            label: 'Daily Call Target',
            hintText: '50',
            controller: _targetCtrl,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GlassTextField(
                  label: 'Shift Start',
                  hintText: '09:00:00',
                  controller: _shiftStartCtrl,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GlassTextField(
                  label: 'Shift End',
                  hintText: '18:00:00',
                  controller: _shiftEndCtrl,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GlassTextField(
                  label: 'Grace (mins)',
                  hintText: '15',
                  controller: _graceCtrl,
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBranchCard(
      LeadProvider leadProvider, dynamic authUser, bool canCreateBranch) {
    final companyHasBranches =
        authUser?.companyAllowedMenus.contains('branches') ?? false;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(18),
      borderColor: const Color(0xFFE2E8F0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Branch Assignment',
                style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A)),
              ),
              if (canCreateBranch)
                TextButton.icon(
                  onPressed: _showQuickBranchDialog,
                  icon: const Icon(Icons.add_business_rounded, size: 16),
                  label: const Text('+ New Branch'),
                )
              else
                TextButton.icon(
                  onPressed: () => _showFeatureDetailsDialog(
                    {
                      'key': 'branches',
                      'name': 'Multi-Branch Management',
                      'category': 'Organization',
                      'description':
                          'Create and manage office branches, branch logos, and multi-branch geo-fence check-ins.',
                      'highlights': [
                        'Create new branches inline',
                        'Assign employees to specific branches',
                      ],
                      'is_enabled': companyHasBranches,
                      'has_pending_request': false,
                    },
                    requestType: companyHasBranches
                        ? 'USER_PERMISSION'
                        : 'COMPANY_FEATURE',
                  ),
                  icon: const Icon(Icons.lock_outline_rounded, size: 15),
                  label: Text(companyHasBranches
                      ? 'Request Branch Access'
                      : 'Request Branches Feature'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (!companyHasBranches)
            Text(
              'Multi-branch management is not enabled on your current plan. Employees will be assigned to Headquarters.',
              style: GoogleFonts.inter(
                  fontSize: 12, color: const Color(0xFF64748B)),
            )
          else ...[
            Text('Primary Branch / Base Office',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B))),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: leadProvider.branches
                          .any((b) => b.id == _selectedBranchId)
                      ? _selectedBranchId
                      : null,
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('No Branch (Headquarters)')),
                    ...leadProvider.branches.map((b) => DropdownMenuItem(
                          value: b.id,
                          child: Text(b.name, overflow: TextOverflow.ellipsis),
                        )),
                  ],
                  onChanged: canCreateBranch || _isCompanyAdmin
                      ? (v) {
                          setState(() {
                            _selectedBranchId = v;
                            if (v != null &&
                                !_selectedAllowedBranches.contains(v)) {
                              _selectedAllowedBranches.add(v);
                            }
                          });
                        }
                      : null,
                ),
              ),
            ),
            if (leadProvider.branches.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Allowed Check-in Branches (${_selectedAllowedBranches.length}/${leadProvider.branches.length})',
                style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B)),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: leadProvider.branches.map((b) {
                  final isSelected = _selectedAllowedBranches.contains(b.id);
                  return FilterChip(
                    selected: isSelected,
                    label:
                        Text(b.name, style: GoogleFonts.inter(fontSize: 11.5)),
                    onSelected: (val) {
                      setState(() {
                        if (val) {
                          _selectedAllowedBranches.add(b.id);
                        } else {
                          _selectedAllowedBranches.remove(b.id);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildRolesCard(
      RoleProvider roleProvider, Set<String> activePerms, bool canCreateRole) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(18),
      borderColor: const Color(0xFFE2E8F0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Functional Roles & RBAC',
                style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A)),
              ),
              if (canCreateRole)
                TextButton.icon(
                  onPressed: _showQuickRoleDialog,
                  icon: const Icon(Icons.add_moderator_rounded, size: 16),
                  label: const Text('+ New Role'),
                )
              else
                TextButton.icon(
                  onPressed: () => _showFeatureDetailsDialog(
                    {
                      'key': 'roles.manage',
                      'name': 'Manage Functional Roles (RBAC)',
                      'category': 'Organization',
                      'description':
                          'Create custom functional roles and assign granular module permissions.',
                      'highlights': [
                        'Build custom team roles',
                        'Use role presets & permission toggles',
                      ],
                      'is_enabled': false,
                      'has_pending_request': false,
                    },
                    requestType: 'USER_PERMISSION',
                  ),
                  icon: const Icon(Icons.lock_outline_rounded, size: 15),
                  label: const Text('Request Role Permission'),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (roleProvider.roles.isEmpty)
            Text(
              'No custom roles yet. Create one with "+ New Role" or assign default employee access.',
              style: GoogleFonts.inter(
                  fontSize: 12, color: const Color(0xFF64748B)),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: roleProvider.roles.map((r) {
                final isSelected = _selectedRoleIds.contains(r.id);
                return FilterChip(
                  selected: isSelected,
                  avatar: Icon(Icons.security_rounded,
                      size: 14,
                      color: isSelected
                          ? AppColors.emeraldDark
                          : const Color(0xFF64748B)),
                  label: Text('${r.name} (${r.permissions.length} perms)',
                      style: GoogleFonts.inter(fontSize: 12)),
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        _selectedRoleIds.add(r.id);
                      } else {
                        _selectedRoleIds.remove(r.id);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.neonCyan.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Effective Permissions Selected: ${activePerms.length}',
              style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.neonCyan),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCatalogCard(
      CompanyProvider companyProvider, dynamic authUser) {
    final catalog = companyProvider.featureCatalog;
    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(18),
      borderColor: const Color(0xFFE2E8F0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.apps_rounded,
                  size: 18, color: AppColors.neonViolet),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Company Features & Request Access',
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Click any feature to view details. Locked features can be requested directly.',
            style:
                GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
          ),
          const SizedBox(height: 10),
          if (companyProvider.isLoadingFeatureCatalog && catalog.isEmpty)
            const Center(
                child: Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(strokeWidth: 2),
            ))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: catalog.map((feat) {
                final enabled = feat['is_enabled'] == true;
                final pending = feat['has_pending_request'] == true;
                return InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _showFeatureDetailsDialog(
                    feat,
                    requestType:
                        _isCompanyAdmin ? 'COMPANY_FEATURE' : 'USER_PERMISSION',
                  ),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: enabled
                          ? AppColors.success.withValues(alpha: 0.08)
                          : (pending
                              ? Colors.amber.withValues(alpha: 0.1)
                              : const Color(0xFFF8FAFC)),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: enabled
                            ? AppColors.success.withValues(alpha: 0.3)
                            : (pending
                                ? Colors.amber.withValues(alpha: 0.45)
                                : const Color(0xFFE2E8F0)),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          enabled
                              ? Icons.check_circle_rounded
                              : (pending
                                  ? Icons.hourglass_top_rounded
                                  : Icons.lock_outline_rounded),
                          size: 14,
                          color: enabled
                              ? AppColors.success
                              : (pending
                                  ? Colors.amber[800]
                                  : const Color(0xFF64748B)),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          feat['name']?.toString() ?? '',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}
