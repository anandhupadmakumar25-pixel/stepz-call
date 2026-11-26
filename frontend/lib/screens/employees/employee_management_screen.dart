import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass/glass_card.dart';
import '../../core/widgets/glass/gradient_button.dart';
import '../../core/widgets/glass/animated_status_badge.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../routes/app_routes.dart';
import '../../providers/employee_provider.dart';
import '../../providers/lead_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/department_provider.dart';
import '../../providers/role_provider.dart';
import 'package:intl/intl.dart';
import 'employee_activity_detail_dialog.dart';
import 'delegation_management_dialog.dart';
import 'add_employee_screen.dart';

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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EmployeeActivityDetailDialog(employee: emp, asPage: true),
      ),
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
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      if (context.watch<AuthProvider>().currentUser?.hasAnyPermission(['delegation.manage', 'roles.manage']) ?? false)
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF6D28D9),
                            side: const BorderSide(color: Color(0xFFC4B5FD)),
                            backgroundColor: const Color(0xFFF5F3FF),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.assignment_ind_rounded, size: 18),
                          label: Text('Delegate Sections', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => const DelegationManagementDialog(),
                            );
                          },
                        ),
                      if (context.watch<AuthProvider>().currentUser?.hasPermission('employees.create') ?? false)
                        GradientPrimaryButton(
                          text: 'Add Employee',
                          icon: Icons.person_add_rounded,
                          onPressed: () async {
                            final created = await Navigator.pushNamed(context, AppRoutes.addEmployee);
                            if (created == true && mounted) {
                              _loadData();
                            }
                          },
                        ),
                    ],
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
                              final profile = emp['employee_profile'] as Map<String, dynamic>? ?? {};
                              final target = profile['daily_call_target'] ?? emp['daily_call_target'] ?? 50;

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
                                          onPressed: () async {
                                            final updated = await Navigator.push<bool>(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => AddEmployeeScreen(employee: emp),
                                              ),
                                            );
                                            if (updated == true && mounted) {
                                              _loadData();
                                            }
                                          },
                                        ),
                                        if (emp['id']?.toString() != context.read<AuthProvider>().currentUser?.id)
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
