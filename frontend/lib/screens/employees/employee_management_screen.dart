import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass/glass_card.dart';
import '../../core/widgets/glass/gradient_button.dart';
import '../../core/widgets/glass/glass_text_field.dart';
import '../../core/widgets/glass/animated_status_badge.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../routes/app_routes.dart';
import '../../providers/employee_provider.dart';
import '../../providers/lead_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/department_provider.dart';
import '../../providers/role_provider.dart';
import '../../models/department_model.dart';
import 'package:intl/intl.dart';
import 'employee_activity_detail_dialog.dart';

class EmployeeManagementScreen extends StatefulWidget {
  const EmployeeManagementScreen({super.key});

  @override
  State<EmployeeManagementScreen> createState() => _EmployeeManagementScreenState();
}

class _EmployeeManagementScreenState extends State<EmployeeManagementScreen> {
  String _selectedBranch = 'ALL';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() {
    context.read<LeadProvider>().fetchBranches();
    context.read<DepartmentProvider>().fetchDepartments();
    context.read<RoleProvider>().fetchRoles();
    context.read<EmployeeProvider>().fetchEmployees(
      branchId: _selectedBranch,
      search: _searchQuery,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showEmployeeActivityDialog(Map<String, dynamic> emp) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (_) => EmployeeActivityDetailDialog(employee: emp),
    );
  }

  void _showAddEmployeeDialog() {
    final leadProvider = context.read<LeadProvider>();
    final deptProvider = context.read<DepartmentProvider>();
    final roleProvider = context.read<RoleProvider>();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();
    final phoneController = TextEditingController();
    final targetController = TextEditingController(text: '50');
    final shiftStartController = TextEditingController(text: '09:00:00');
    final shiftEndController = TextEditingController(text: '18:00:00');
    final graceController = TextEditingController(text: '15');

    String role = 'EMPLOYEE';
    String? selectedBranchId;
    String? selectedDepartmentId;
    List<String> selectedAllowedBranches = [];
    List<String> selectedRoleIds = [];
    if (roleProvider.roles.isNotEmpty) {
      final defaultRole = roleProvider.roles.where((r) => r.code == 'TELECALLER');
      if (defaultRole.isNotEmpty) {
        selectedRoleIds.add(defaultRole.first.id);
      }
    }

    final authUser = context.read<AuthProvider>().currentUser;
    final canManageBranches = authUser?.canManageBranches ?? (authUser?.hasMenuPermission('branches') ?? false);

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (ctx) {
        final isMobile = ResponsiveLayout.isMobile(ctx);
        return StatefulBuilder(
          builder: (context, setDialogState) {
            DepartmentModel? chosenDept;
            if (selectedDepartmentId != null) {
              final matches = deptProvider.departments.where((d) => d.id == selectedDepartmentId);
              if (matches.isNotEmpty) chosenDept = matches.first;
            }

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: isMobile ? 16 : 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: GlassCard(
                  blur: 24,
                  opacity: 0.96,
                  borderRadius: BorderRadius.circular(20),
                  borderColor: AppColors.glassBorderHighlight,
                  padding: EdgeInsets.all(isMobile ? 18 : 26),
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
                              child: const Icon(Icons.person_add_rounded, color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Onboard Employee & Assign Department',
                                style: GoogleFonts.inter(fontSize: isMobile ? 15 : 16, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                              ),
                            ),
                            DialogCloseButton(onPressed: () => Navigator.of(ctx).pop()),
                          ],
                        ),
                        const SizedBox(height: 18),
                        GlassTextField(label: 'Email Address *', hintText: 'caller@company.com', controller: emailController),
                        const SizedBox(height: 12),
                        GlassTextField(label: 'Initial Password *', hintText: '••••••••', obscureText: true, controller: passwordController),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: GlassTextField(label: 'First Name *', hintText: 'Jane', controller: firstNameController)),
                            const SizedBox(width: 10),
                            Expanded(child: GlassTextField(label: 'Last Name', hintText: 'Doe', controller: lastNameController)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        GlassTextField(label: 'Phone Number', hintText: '+91 9876543210', controller: phoneController),
                        const SizedBox(height: 14),

                        // Department Selector
                        Text('Department & Attendance Track Mode', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
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
                              isExpanded: true,
                              value: selectedDepartmentId,
                              dropdownColor: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF0F172A)),
                              icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
                              items: [
                                const DropdownMenuItem(value: null, child: Text('No Department (Default)', overflow: TextOverflow.ellipsis)),
                                ...deptProvider.departments.map((d) => DropdownMenuItem(
                                  value: d.id,
                                  child: Row(
                                    children: [
                                      Icon(
                                        d.isGeofenceMode ? Icons.business_rounded : Icons.directions_car_rounded,
                                        size: 14,
                                        color: d.isGeofenceMode ? AppColors.neonViolet : AppColors.neonCyan,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text('${d.name} (${d.isGeofenceMode ? 'Office Fence' : 'Field Staff'})', overflow: TextOverflow.ellipsis)),
                                    ],
                                  ),
                                )),
                              ],
                              onChanged: (v) {
                                setDialogState(() {
                                  selectedDepartmentId = v;
                                  if (v != null) {
                                    final d = deptProvider.departments.firstWhere((item) => item.id == v);
                                    selectedAllowedBranches = List<String>.from(d.allowedBranches);
                                  }
                                });
                              },
                            ),
                          ),
                        ),

                        if (chosenDept != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: (chosenDept.isGeofenceMode ? AppColors.neonViolet : AppColors.neonCyan).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: (chosenDept.isGeofenceMode ? AppColors.neonViolet : AppColors.neonCyan).withValues(alpha: 0.2)),
                            ),
                            child: Row(
                              children: [
                                Icon(chosenDept.isGeofenceMode ? Icons.pin_drop_rounded : Icons.route_rounded, size: 14, color: chosenDept.isGeofenceMode ? AppColors.neonViolet : AppColors.neonCyan),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    chosenDept.isGeofenceMode
                                        ? 'Tracking: Fixed Office Geo-fence (Must check in within allowed branches radius)'
                                        : 'Tracking: Field Staff (Dynamic GPS check-in + multiple field stops)',
                                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: chosenDept.isGeofenceMode ? AppColors.neonViolet : AppColors.neonCyan),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 14),

                        if (canManageBranches) ...[
                          // Primary Branch Selector
                          Text('Primary Branch / Base Office', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
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
                                isExpanded: true,
                                value: selectedBranchId,
                                dropdownColor: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF0F172A)),
                                icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
                                items: [
                                  const DropdownMenuItem(value: null, child: Text('No Branch (Headquarters)', overflow: TextOverflow.ellipsis)),
                                  ...leadProvider.branches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name, overflow: TextOverflow.ellipsis))),
                                ],
                                onChanged: (v) {
                                  setDialogState(() {
                                    selectedBranchId = v;
                                    if (v != null && !selectedAllowedBranches.contains(v)) {
                                      selectedAllowedBranches.add(v);
                                    }
                                  });
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Allowed Branches Multi-Select Chips
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Multi-Branch Check-in Permissions (${selectedAllowedBranches.length}/${leadProvider.branches.length})',
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                              ),
                              TextButton(
                                onPressed: () {
                                  setDialogState(() {
                                    if (selectedAllowedBranches.length == leadProvider.branches.length) {
                                      selectedAllowedBranches.clear();
                                    } else {
                                      selectedAllowedBranches = leadProvider.branches.map((b) => b.id).toList();
                                    }
                                  });
                                },
                                child: Text(
                                  selectedAllowedBranches.length == leadProvider.branches.length ? 'Clear All' : 'Select All',
                                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.neonCyan),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: leadProvider.branches.map((b) {
                              final isSelected = selectedAllowedBranches.contains(b.id);
                              return FilterChip(
                                selected: isSelected,
                                label: Text(b.name, style: GoogleFonts.inter(fontSize: 11, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400)),
                                selectedColor: AppColors.neonViolet.withValues(alpha: 0.15),
                                checkmarkColor: AppColors.neonViolet,
                                backgroundColor: Colors.white,
                                side: BorderSide(color: isSelected ? AppColors.neonViolet : const Color(0xFFE2E8F0)),
                                onSelected: (val) {
                                  setDialogState(() {
                                    if (val) {
                                      selectedAllowedBranches.add(b.id);
                                    } else {
                                      selectedAllowedBranches.remove(b.id);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Custom Dynamic Roles & Functional Permissions
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Functional Roles & Access (RBAC)',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                            ),
                            Builder(
                              builder: (_) {
                                final activePerms = <String>{};
                                for (final rid in selectedRoleIds) {
                                  final matching = roleProvider.roles.where((r) => r.id == rid);
                                  if (matching.isNotEmpty) {
                                    activePerms.addAll(matching.first.permissions);
                                  }
                                }
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.neonCyan.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    '${activePerms.length} Active Permissions',
                                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.neonCyan),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (roleProvider.roles.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Text(
                              'No custom roles created yet. Default permissions will apply.',
                              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                            ),
                          )
                        else
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: roleProvider.roles.map((r) {
                              final isSelected = selectedRoleIds.contains(r.id);
                              return FilterChip(
                                selected: isSelected,
                                avatar: Icon(Icons.security_rounded, size: 14, color: isSelected ? AppColors.neonCyan : const Color(0xFF64748B)),
                                label: Text('${r.name} (${r.permissions.length} perms)'),
                                selectedColor: AppColors.neonCyan.withValues(alpha: 0.15),
                                checkmarkColor: AppColors.neonCyan,
                                backgroundColor: Colors.white,
                                side: BorderSide(color: isSelected ? AppColors.neonCyan : const Color(0xFFE2E8F0)),
                                onSelected: (val) {
                                  setDialogState(() {
                                    if (val) {
                                      selectedRoleIds.add(r.id);
                                    } else {
                                      selectedRoleIds.remove(r.id);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        const SizedBox(height: 14),

                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Role Level', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
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
                                        isExpanded: true,
                                        value: role,
                                        dropdownColor: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF0F172A)),
                                        icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
                                        items: const [
                                          DropdownMenuItem(value: 'EMPLOYEE', child: Text('Telecaller / Field Rep')),
                                          DropdownMenuItem(value: 'MANAGER', child: Text('Team Manager')),
                                        ],
                                        onChanged: (v) => setDialogState(() => role = v!),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: GlassTextField(
                                label: 'Daily Call Target',
                                hintText: '50',
                                controller: targetController,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Shift Timings Row
                        Row(
                          children: [
                            Expanded(
                              child: GlassTextField(
                                label: 'Shift Start',
                                hintText: '09:00:00',
                                controller: shiftStartController,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: GlassTextField(
                                label: 'Shift End',
                                hintText: '18:00:00',
                                controller: shiftEndController,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: GlassTextField(
                                label: 'Grace (mins)',
                                hintText: '15',
                                controller: graceController,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),

                        Container(
                          margin: const EdgeInsets.only(top: 20),
                          padding: const EdgeInsets.only(top: 14),
                          decoration: const BoxDecoration(
                            border: Border(top: BorderSide(color: Color(0x33D4AF37), width: 1)),
                          ),
                          child: Wrap(
                            alignment: WrapAlignment.end,
                            spacing: 10,
                            runSpacing: 8,
                            children: [
                              GlassSecondaryButton(text: 'Cancel', onPressed: () => Navigator.of(ctx).pop()),
                              GradientPrimaryButton(
                                text: 'Create Employee',
                                icon: Icons.check_rounded,
                                onPressed: () async {
                                  if (emailController.text.trim().isEmpty || passwordController.text.isEmpty || firstNameController.text.isEmpty) {
                                    return;
                                  }
                                  final empP = context.read<EmployeeProvider>();
                                  final nav = Navigator.of(ctx);
                                  final scaf = ScaffoldMessenger.of(context);
                                  final ok = await empP.createEmployee({
                                    'email': emailController.text.trim(),
                                    'password': passwordController.text,
                                    'first_name': firstNameController.text.trim(),
                                    'last_name': lastNameController.text.trim(),
                                    'phone': phoneController.text.trim(),
                                    'role': role,
                                    'branch': selectedBranchId,
                                    'department_id': selectedDepartmentId,
                                    'allowed_branches': selectedAllowedBranches,
                                    'custom_role_ids': selectedRoleIds,
                                    'daily_call_target': int.tryParse(targetController.text) ?? 50,
                                    'shift_start_time': shiftStartController.text.trim(),
                                    'shift_end_time': shiftEndController.text.trim(),
                                    'grace_period_minutes': int.tryParse(graceController.text) ?? 15,
                                  });
                                  if (ok) {
                                    nav.pop();
                                    scaf.showSnackBar(
                                      const SnackBar(content: Text('Employee onboarded successfully!'), backgroundColor: AppColors.success),
                                    );
                                    _loadData();
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
      },
    );
  }

  void _showEditEmployeeDialog(Map<String, dynamic> emp) {
    final leadProvider = context.read<LeadProvider>();
    final deptProvider = context.read<DepartmentProvider>();
    final roleProvider = context.read<RoleProvider>();
    final firstNameController = TextEditingController(text: emp['first_name'] ?? '');
    final lastNameController = TextEditingController(text: emp['last_name'] ?? '');
    final phoneController = TextEditingController(text: emp['phone'] ?? '');
    final targetController = TextEditingController(text: (emp['daily_call_target'] ?? 50).toString());

    final profile = emp['employee_profile'] as Map<String, dynamic>? ?? {};
    final shiftStartController = TextEditingController(text: profile['shift_start_time'] ?? '09:00:00');
    final shiftEndController = TextEditingController(text: profile['shift_end_time'] ?? '18:00:00');
    final graceController = TextEditingController(text: (profile['grace_period_minutes'] ?? 15).toString());

    String role = emp['role'] ?? 'EMPLOYEE';
    String? selectedBranchId = emp['branch_id']?.toString() ?? emp['branch']?.toString();
    String? selectedDepartmentId = emp['department_id']?.toString() ?? profile['department']?.toString();

    final rawBranchIds = profile['allowed_branch_ids'] as List<dynamic>?;
    List<String> selectedAllowedBranches = rawBranchIds != null
        ? rawBranchIds.map((e) => e.toString()).toList()
        : [];

    final rawRoleIds = emp['custom_role_ids'] as List<dynamic>?;
    List<String> selectedRoleIds = rawRoleIds != null
        ? rawRoleIds.map((e) => e.toString()).toList()
        : [];

    String status = profile['status'] ?? 'ACTIVE';

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (ctx) {
        final isMobile = ResponsiveLayout.isMobile(ctx);
        return StatefulBuilder(
          builder: (context, setDialogState) {
            DepartmentModel? chosenDept;
            if (selectedDepartmentId != null) {
              final matches = deptProvider.departments.where((d) => d.id == selectedDepartmentId);
              if (matches.isNotEmpty) chosenDept = matches.first;
            }

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: isMobile ? 16 : 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: GlassCard(
                  blur: 24,
                  opacity: 0.96,
                  borderRadius: BorderRadius.circular(20),
                  borderColor: AppColors.glassBorderHighlight,
                  padding: EdgeInsets.all(isMobile ? 18 : 26),
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
                              child: const Icon(Icons.manage_accounts_rounded, color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Edit Employee Profile & Branch Access',
                                style: GoogleFonts.inter(fontSize: isMobile ? 15 : 16, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                              ),
                            ),
                            DialogCloseButton(onPressed: () => Navigator.of(ctx).pop()),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(child: GlassTextField(label: 'First Name', hintText: 'Jane', controller: firstNameController)),
                            const SizedBox(width: 10),
                            Expanded(child: GlassTextField(label: 'Last Name', hintText: 'Doe', controller: lastNameController)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        GlassTextField(label: 'Phone Number', hintText: '+91 9876543210', controller: phoneController),
                        const SizedBox(height: 14),

                        // Department Selector
                        Text('Department & Attendance Track Mode', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
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
                              isExpanded: true,
                              value: selectedDepartmentId,
                              dropdownColor: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF0F172A)),
                              icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
                              items: [
                                const DropdownMenuItem(value: null, child: Text('No Department (Default)', overflow: TextOverflow.ellipsis)),
                                ...deptProvider.departments.map((d) => DropdownMenuItem(
                                  value: d.id,
                                  child: Text('${d.name} (${d.isGeofenceMode ? 'Office Fence' : 'Field Staff'})', overflow: TextOverflow.ellipsis),
                                )),
                              ],
                              onChanged: (v) {
                                setDialogState(() {
                                  selectedDepartmentId = v;
                                  if (v != null) {
                                    final d = deptProvider.departments.firstWhere((item) => item.id == v);
                                    for (final bid in d.allowedBranches) {
                                      if (!selectedAllowedBranches.contains(bid)) selectedAllowedBranches.add(bid);
                                    }
                                  }
                                });
                              },
                            ),
                          ),
                        ),

                        if (chosenDept != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: (chosenDept.isGeofenceMode ? AppColors.neonViolet : AppColors.neonCyan).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(chosenDept.isGeofenceMode ? Icons.pin_drop_rounded : Icons.route_rounded, size: 14, color: chosenDept.isGeofenceMode ? AppColors.neonViolet : AppColors.neonCyan),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    chosenDept.isGeofenceMode
                                        ? 'Tracking: Fixed Office Geo-fence (Enforced branch perimeter)'
                                        : 'Tracking: Field Staff (Dynamic GPS check-in + client visit tracking)',
                                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: chosenDept.isGeofenceMode ? AppColors.neonViolet : AppColors.neonCyan),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 14),

                        // Primary Branch
                        Text('Primary Branch', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
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
                              isExpanded: true,
                              value: selectedBranchId,
                              dropdownColor: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF0F172A)),
                              icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
                              items: [
                                const DropdownMenuItem(value: null, child: Text('No Branch (Headquarters)', overflow: TextOverflow.ellipsis)),
                                ...leadProvider.branches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name, overflow: TextOverflow.ellipsis))),
                              ],
                              onChanged: (v) => setDialogState(() => selectedBranchId = v),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Allowed Branches Multi-Select
                        Text(
                          'Allowed Check-in Branches (${selectedAllowedBranches.length}/${leadProvider.branches.length})',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: leadProvider.branches.map((b) {
                            final isSelected = selectedAllowedBranches.contains(b.id);
                            return FilterChip(
                              selected: isSelected,
                              label: Text(b.name, style: GoogleFonts.inter(fontSize: 11, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400)),
                              selectedColor: AppColors.neonViolet.withValues(alpha: 0.15),
                              checkmarkColor: AppColors.neonViolet,
                              backgroundColor: Colors.white,
                              side: BorderSide(color: isSelected ? AppColors.neonViolet : const Color(0xFFE2E8F0)),
                              onSelected: (val) {
                                setDialogState(() {
                                  if (val) {
                                    selectedAllowedBranches.add(b.id);
                                  } else {
                                    selectedAllowedBranches.remove(b.id);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 14),

                        // Custom Dynamic Roles & Functional Permissions
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Functional Roles & Access (RBAC)',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                            ),
                            Builder(
                              builder: (_) {
                                final activePerms = <String>{};
                                for (final rid in selectedRoleIds) {
                                  final matching = roleProvider.roles.where((r) => r.id == rid);
                                  if (matching.isNotEmpty) {
                                    activePerms.addAll(matching.first.permissions);
                                  }
                                }
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.neonCyan.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    '${activePerms.length} Active Permissions',
                                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.neonCyan),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (roleProvider.roles.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Text(
                              'No custom roles created yet. Default permissions will apply.',
                              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                            ),
                          )
                        else
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: roleProvider.roles.map((r) {
                              final isSelected = selectedRoleIds.contains(r.id);
                              return FilterChip(
                                selected: isSelected,
                                avatar: Icon(Icons.security_rounded, size: 14, color: isSelected ? AppColors.neonCyan : const Color(0xFF64748B)),
                                label: Text('${r.name} (${r.permissions.length} perms)'),
                                selectedColor: AppColors.neonCyan.withValues(alpha: 0.15),
                                checkmarkColor: AppColors.neonCyan,
                                backgroundColor: Colors.white,
                                side: BorderSide(color: isSelected ? AppColors.neonCyan : const Color(0xFFE2E8F0)),
                                onSelected: (val) {
                                  setDialogState(() {
                                    if (val) {
                                      selectedRoleIds.add(r.id);
                                    } else {
                                      selectedRoleIds.remove(r.id);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        const SizedBox(height: 14),

                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Role Level', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
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
                                        isExpanded: true,
                                        value: role,
                                        dropdownColor: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF0F172A)),
                                        icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
                                        items: const [
                                          DropdownMenuItem(value: 'EMPLOYEE', child: Text('Telecaller / Field Rep')),
                                          DropdownMenuItem(value: 'MANAGER', child: Text('Team Manager')),
                                        ],
                                        onChanged: (v) => setDialogState(() => role = v!),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: GlassTextField(
                                label: 'Daily Call Target',
                                hintText: '50',
                                controller: targetController,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Shift Timings Row
                        Row(
                          children: [
                            Expanded(
                              child: GlassTextField(
                                label: 'Shift Start',
                                hintText: '09:00:00',
                                controller: shiftStartController,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: GlassTextField(
                                label: 'Shift End',
                                hintText: '18:00:00',
                                controller: shiftEndController,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: GlassTextField(
                                label: 'Grace (mins)',
                                hintText: '15',
                                controller: graceController,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Status Dropdown
                        Text('Employee Status', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
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
                              isExpanded: true,
                              value: status,
                              dropdownColor: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF0F172A)),
                              icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
                              items: const [
                                DropdownMenuItem(value: 'ACTIVE', child: Text('Active')),
                                DropdownMenuItem(value: 'ON_LEAVE', child: Text('On Leave')),
                                DropdownMenuItem(value: 'INACTIVE', child: Text('Inactive')),
                              ],
                              onChanged: (v) => setDialogState(() => status = v!),
                            ),
                          ),
                        ),

                        Container(
                          margin: const EdgeInsets.only(top: 20),
                          padding: const EdgeInsets.only(top: 14),
                          decoration: const BoxDecoration(
                            border: Border(top: BorderSide(color: Color(0x33D4AF37), width: 1)),
                          ),
                          child: Wrap(
                            alignment: WrapAlignment.end,
                            spacing: 10,
                            runSpacing: 8,
                            children: [
                              GlassSecondaryButton(text: 'Cancel', onPressed: () => Navigator.of(ctx).pop()),
                              GradientPrimaryButton(
                                text: 'Save Updates',
                                icon: Icons.check_rounded,
                                onPressed: () async {
                                  final empP = context.read<EmployeeProvider>();
                                  final nav = Navigator.of(ctx);
                                  final scaf = ScaffoldMessenger.of(context);
                                  final ok = await empP.updateEmployee(emp['id'], {
                                    'first_name': firstNameController.text.trim(),
                                    'last_name': lastNameController.text.trim(),
                                    'phone': phoneController.text.trim(),
                                    'role': role,
                                    'branch_id': selectedBranchId,
                                    'department_id': selectedDepartmentId,
                                    'allowed_branches': selectedAllowedBranches,
                                    'custom_role_ids': selectedRoleIds,
                                    'daily_call_target': int.tryParse(targetController.text) ?? 50,
                                    'shift_start_time': shiftStartController.text.trim(),
                                    'shift_end_time': shiftEndController.text.trim(),
                                    'grace_period_minutes': int.tryParse(graceController.text) ?? 15,
                                    'status': status,
                                  });
                                  if (ok) {
                                    nav.pop();
                                    scaf.showSnackBar(
                                      const SnackBar(content: Text('Employee profile updated!'), backgroundColor: AppColors.success),
                                    );
                                    _loadData();
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final empProvider = context.watch<EmployeeProvider>();
    final leadProvider = context.watch<LeadProvider>();
    final isMobile = ResponsiveLayout.isMobile(context);

    final authUser = context.watch<AuthProvider>().currentUser;
    final canManageBranches = authUser?.canManageBranches ?? (authUser?.hasMenuPermission('branches') ?? false);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            isMobile ? 12 : 24,
            isMobile ? 6 : 16,
            isMobile ? 12 : 24,
            isMobile ? 10 : 20,
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
                      const SizedBox(width: 14),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Telecalling Staff & Branch Assignments',
                              style: GoogleFonts.inter(
                                fontSize: isMobile ? 18 : 22,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A),
                                letterSpacing: -0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Manage telecallers, assign branch campuses, set daily call quotas',
                              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  GradientPrimaryButton(
                    text: 'Add Telecaller',
                    icon: Icons.person_add_rounded,
                    onPressed: _showAddEmployeeDialog,
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Toolbar
              GlassCard(
                blur: 16,
                opacity: 0.12,
                borderRadius: BorderRadius.circular(16),
                borderColor: AppColors.glassBorder,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: isMobile ? double.infinity : 260,
                      height: 40,
                      child: TextField(
                        controller: _searchController,
                        style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          hintText: 'Search staff by name or email...',
                          hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
                          prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          isDense: true,
                        ),
                        onChanged: (v) {
                          setState(() => _searchQuery = v.trim());
                          _loadData();
                        },
                      ),
                    ),
                    if (canManageBranches)
                      Container(
                        width: isMobile ? double.infinity : 200,
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedBranch,
                            isExpanded: true,
                            dropdownColor: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF0F172A)),
                            icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
                            items: [
                              const DropdownMenuItem(value: 'ALL', child: Text('All Branches', overflow: TextOverflow.ellipsis)),
                              ...leadProvider.branches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name, overflow: TextOverflow.ellipsis))),
                            ],
                            onChanged: (v) {
                              setState(() => _selectedBranch = v ?? 'ALL');
                              _loadData();
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Employee List
              Expanded(
                child: empProvider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : empProvider.employees.isEmpty
                        ? Center(
                            child: GlassCard(
                              blur: 16,
                              opacity: 0.12,
                              borderColor: AppColors.glassBorder,
                              padding: const EdgeInsets.all(32),
                              child: Text('No employees found matching filter.', style: GoogleFonts.inter(color: const Color(0xFF64748B))),
                            ),
                          )
                        : ListView.separated(
                            itemCount: empProvider.employees.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (ctx, i) {
                              final emp = empProvider.employees[i];
                              final name = '${emp['first_name'] ?? ''} ${emp['last_name'] ?? ''}'.trim();
                              final email = emp['email'] ?? '';
                              final branchName = emp['branch_name'] as String?;
                              final target = emp['daily_call_target'] ?? 50;

                              return GlassCard(
                                blur: 18,
                                opacity: 0.12,
                                borderRadius: BorderRadius.circular(16),
                                borderColor: AppColors.glassBorder,
                                padding: const EdgeInsets.all(16),
                                child: Wrap(
                                  spacing: 12,
                                  runSpacing: 10,
                                  alignment: WrapAlignment.spaceBetween,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () => _showEmployeeActivityDialog(emp),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 40,
                                            height: 40,
                                          decoration: BoxDecoration(
                                            gradient: AppColors.primaryGradient,
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: AppColors.neonViolet.withValues(alpha: 0.35),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Center(
                                            child: Text(
                                              name.isNotEmpty ? name[0].toUpperCase() : 'E',
                                              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Flexible(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                name.isNotEmpty ? name : email,
                                                style: GoogleFonts.inter(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w800,
                                                  color: const Color(0xFF0F172A),
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              Text(
                                                email,
                                                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        // Department badge
                                        if (emp['department_name'] != null && (emp['department_name'] as String).isNotEmpty)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: (emp['department_attendance_mode'] == 'FIELD_STAFF' ? AppColors.neonCyan : AppColors.neonViolet).withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: (emp['department_attendance_mode'] == 'FIELD_STAFF' ? AppColors.neonCyan : AppColors.neonViolet).withValues(alpha: 0.3)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  emp['department_attendance_mode'] == 'FIELD_STAFF' ? Icons.directions_car_rounded : Icons.business_rounded,
                                                  size: 13,
                                                  color: emp['department_attendance_mode'] == 'FIELD_STAFF' ? AppColors.neonCyan : AppColors.neonViolet,
                                                ),
                                                const SizedBox(width: 5),
                                                Text(
                                                  emp['department_name'],
                                                  style: GoogleFonts.inter(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: emp['department_attendance_mode'] == 'FIELD_STAFF' ? AppColors.neonCyan : AppColors.neonViolet,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                        // Branch badge
                                        if (branchName != null)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF64748B).withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.storefront_rounded, size: 12, color: Color(0xFF64748B)),
                                                const SizedBox(width: 4),
                                                Text(
                                                  branchName,
                                                  style: GoogleFonts.inter(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: const Color(0xFF64748B),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                        // Custom Functional Roles Badges
                                        Builder(
                                          builder: (_) {
                                            final roleNames = (emp['custom_role_names'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
                                            if (roleNames.isEmpty) return const SizedBox.shrink();
                                            return Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: AppColors.neonCyan.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.3)),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.shield_rounded, size: 12, color: AppColors.neonCyan),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    roleNames.join(' • '),
                                                    style: GoogleFonts.inter(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w700,
                                                      color: AppColors.neonCyan,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),

                                        // Attendance status pill
                                        Builder(
                                          builder: (_) {
                                            final att = emp['today_attendance'] as Map<String, dynamic>?;
                                            if (att == null) {
                                              return Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.grey)),
                                                    const SizedBox(width: 5),
                                                    Text('Not Checked In', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
                                                  ],
                                                ),
                                              );
                                            }

                                            final st = att['status'] as String? ?? 'PRESENT';
                                            final timeStr = att['check_in_time'] != null
                                                ? DateFormat('hh:mm a').format(DateTime.parse(att['check_in_time'].toString()).toLocal())
                                                : '';
                                            final visits = att['field_visits_count'] as int? ?? 0;

                                            Color pillColor = const Color(0xFF10B981);
                                            String label = 'Present $timeStr';
                                            if (st == 'LATE') {
                                              pillColor = const Color(0xFFF59E0B);
                                              label = 'Late ($timeStr)';
                                            } else if (st == 'OUT_OF_FENCE') {
                                              pillColor = const Color(0xFFEF4444);
                                              label = 'Out of Fence ($timeStr)';
                                            }

                                            if (visits > 0) {
                                              label += ' • $visits stops';
                                            }

                                            return Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: pillColor.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: pillColor.withValues(alpha: 0.3)),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: pillColor)),
                                                  const SizedBox(width: 5),
                                                  Text(label, style: GoogleFonts.inter(fontSize: 11, color: pillColor, fontWeight: FontWeight.w700)),
                                                ],
                                              ),
                                            );
                                          },
                                        ),

                                        AnimatedStatusBadge(label: 'Target: $target/day', statusColor: const Color(0xFF10B981)),

                                        // Tasks & Activity Tracker Button
                                        TextButton.icon(
                                          style: TextButton.styleFrom(
                                            backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                            foregroundColor: const Color(0xFF2563EB),
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          icon: const Icon(Icons.analytics_outlined, size: 14),
                                          label: Text('Tasks & Activity', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700)),
                                          onPressed: () => _showEmployeeActivityDialog(emp),
                                        ),

                                        // Action buttons
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, color: AppColors.neonCyan, size: 18),
                                          tooltip: 'Edit Staff Profile',
                                          onPressed: () => _showEditEmployeeDialog(emp),
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            (emp['is_active'] ?? true) ? Icons.check_circle_rounded : Icons.pause_circle_outline_rounded,
                                            color: (emp['is_active'] ?? true) ? const Color(0xFF10B981) : Colors.grey,
                                            size: 18,
                                          ),
                                          tooltip: (emp['is_active'] ?? true) ? 'Active Account' : 'Inactive Account',
                                          onPressed: () async {
                                            await empProvider.toggleEmployeeStatus(emp['id'], !(emp['is_active'] ?? true));
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
}
