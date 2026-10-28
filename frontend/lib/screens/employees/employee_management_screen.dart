import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../providers/employee_provider.dart';
import '../../providers/lead_provider.dart';

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

  void _showAddEmployeeDialog() {
    final leadProvider = context.read<LeadProvider>();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();
    final targetController = TextEditingController(text: '50');
    String role = 'EMPLOYEE';
    String? selectedBranchId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accentVioletLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.person_add_outlined, color: AppColors.accentViolet, size: 20),
              ),
              const SizedBox(width: 10),
              Text('Add New Employee / Telecaller', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email Address *')),
                  const SizedBox(height: 12),
                  TextField(controller: passwordController, obscureText: true, decoration: const InputDecoration(labelText: 'Initial Password *')),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: firstNameController, decoration: const InputDecoration(labelText: 'First Name *'))),
                      const SizedBox(width: 10),
                      Expanded(child: TextField(controller: lastNameController, decoration: const InputDecoration(labelText: 'Last Name'))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Dynamic Branch Assignment
                  DropdownButtonFormField<String?>(
                    initialValue: selectedBranchId,
                    decoration: const InputDecoration(
                      labelText: 'Assigned Branch (Optional)',
                      prefixIcon: Icon(Icons.storefront, size: 18),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('No Branch (Headquarters)')),
                      ...leadProvider.branches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))),
                    ],
                    onChanged: (v) => setDialogState(() => selectedBranchId = v),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: role,
                          decoration: const InputDecoration(labelText: 'Role'),
                          items: const [
                            DropdownMenuItem(value: 'EMPLOYEE', child: Text('Employee / Telecaller')),
                            DropdownMenuItem(value: 'MANAGER', child: Text('Team Manager')),
                          ],
                          onChanged: (v) => setDialogState(() => role = v!),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: targetController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Daily Call Target'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (emailController.text.trim().isEmpty || passwordController.text.isEmpty || firstNameController.text.isEmpty) {
                  return;
                }
                final nav = Navigator.of(ctx);
                final scaffold = ScaffoldMessenger.of(context);
                final success = await context.read<EmployeeProvider>().createEmployee({
                  'email': emailController.text.trim(),
                  'password': passwordController.text,
                  'first_name': firstNameController.text.trim(),
                  'last_name': lastNameController.text.trim(),
                  'role': role,
                  'branch_id': selectedBranchId,
                  'daily_call_target': int.tryParse(targetController.text) ?? 50,
                });
                if (success) {
                  nav.pop();
                  scaffold.showSnackBar(
                    const SnackBar(content: Text('Employee created & assigned to branch successfully.'), backgroundColor: AppColors.success),
                  );
                }
              },
              child: const Text('Create Employee'),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangeBranchDialog(Map<String, dynamic> emp) {
    final leadProvider = context.read<LeadProvider>();
    String? currentBranchId = emp['branch']?.toString() ?? emp['branch_id']?.toString();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text('Assign Branch for ${emp['full_name'] ?? emp['email']}', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Select the branch location this employee will be calling for:', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: currentBranchId,
                decoration: const InputDecoration(labelText: 'Branch'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('No Branch (Headquarters)')),
                  ...leadProvider.branches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))),
                ],
                onChanged: (v) => setDlgState(() => currentBranchId = v),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final nav = Navigator.of(ctx);
                final scaf = ScaffoldMessenger.of(context);
                final ok = await context.read<EmployeeProvider>().updateEmployeeBranch(emp['id'], currentBranchId);
                if (ok) {
                  nav.pop();
                  scaf.showSnackBar(
                    const SnackBar(content: Text('Employee branch updated!'), backgroundColor: AppColors.success),
                  );
                }
              },
              child: const Text('Save Branch'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final empProvider = context.watch<EmployeeProvider>();
    final leadProvider = context.watch<LeadProvider>();
    final isMobile = ResponsiveLayout.isMobile(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 20),
        child: Column(
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Employee & Telecaller Team', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
                      Text(
                        'Manage telecallers, assign branch locations, and monitor targets',
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    backgroundColor: AppColors.accentViolet,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _showAddEmployeeDialog,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Employee'),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Toolbar with Branch Filter & Search
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: isMobile ? double.infinity : 220,
                    height: 38,
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search employees...',
                        prefixIcon: const Icon(Icons.search, size: 16),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                        isDense: true,
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 14),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                  _loadData();
                                },
                              )
                            : null,
                      ),
                      onChanged: (val) {
                        setState(() => _searchQuery = val.trim());
                        _loadData();
                      },
                    ),
                  ),
                  SizedBox(
                    width: 170,
                    height: 38,
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedBranch,
                      decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                      items: [
                        const DropdownMenuItem(value: 'ALL', child: Text('All Branches')),
                        ...leadProvider.branches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name, overflow: TextOverflow.ellipsis))),
                      ],
                      onChanged: (v) {
                        setState(() => _selectedBranch = v ?? 'ALL');
                        _loadData();
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            Expanded(
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: empProvider.isLoading && empProvider.employees.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : empProvider.employees.isEmpty
                        ? EmptyState(
                            icon: Icons.badge_outlined,
                            title: 'No employees found',
                            description: 'Add your first telecaller or manager and assign them to a branch.',
                            actionLabel: 'Add Employee',
                            onAction: _showAddEmployeeDialog,
                          )
                        : isMobile
                            ? _buildMobileList(empProvider.employees)
                            : _buildDataTable(empProvider.employees),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataTable(List<dynamic> employees) {
    final horizontalScrollController = ScrollController();

    return Scrollbar(
      controller: horizontalScrollController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: horizontalScrollController,
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 950),
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: DataTable(
              headingRowHeight: 46,
              dataRowMinHeight: 52,
              dataRowMaxHeight: 60,
              columns: const [
                DataColumn(label: Text('EMPLOYEE', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 0.5))),
                DataColumn(label: Text('ROLE', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 0.5))),
                DataColumn(label: Text('BRANCH', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 0.5))),
                DataColumn(label: Text('ASSIGNED LEADS', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 0.5))),
                DataColumn(label: Text('CALLS TODAY', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 0.5))),
                DataColumn(label: Text('DAILY TARGET', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 0.5))),
                DataColumn(label: Text('STATUS / ACCESS', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 0.5))),
              ],
              rows: employees.map((emp) {
                final isActive = emp['is_active'] == true;
                final branchName = emp['branch_name'];

                return DataRow(
                  cells: [
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: isActive ? AppColors.accentVioletLight : AppColors.surfaceSecondary,
                            child: Text(
                              emp['first_name'] != null && emp['first_name'].isNotEmpty
                                  ? emp['first_name'][0].toUpperCase()
                                  : 'E',
                              style: TextStyle(
                                color: isActive ? AppColors.accentViolet : AppColors.textMuted,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 180),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  emp['full_name'] ?? emp['email'],
                                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  emp['email'],
                                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: emp['role'] == 'MANAGER' ? AppColors.accentVioletLight : AppColors.surfaceSecondary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          emp['role']?.replaceAll('_', ' ') ?? 'EMPLOYEE',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: emp['role'] == 'MANAGER' ? AppColors.accentViolet : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    // Branch Column with Click-to-Reassign
                    DataCell(
                      InkWell(
                        onTap: () => _showChangeBranchDialog(emp),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: branchName != null ? AppColors.accentVioletLight : AppColors.surfaceSecondary,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: branchName != null ? AppColors.accentViolet.withValues(alpha: 0.3) : AppColors.border,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.storefront, size: 12, color: branchName != null ? AppColors.accentViolet : AppColors.textMuted),
                              const SizedBox(width: 4),
                              Text(
                                branchName ?? 'Unassigned',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: branchName != null ? AppColors.accentViolet : AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.edit, size: 10, color: AppColors.textMuted),
                            ],
                          ),
                        ),
                      ),
                    ),
                    DataCell(Text('${emp['assigned_leads_count'] ?? 0}', style: GoogleFonts.inter(fontWeight: FontWeight.w600))),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (emp['calls_today_count'] ?? 0) >= (emp['daily_call_target'] ?? 50)
                              ? AppColors.successLight
                              : AppColors.surfaceSecondary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${emp['calls_today_count'] ?? 0}',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            color: (emp['calls_today_count'] ?? 0) >= (emp['daily_call_target'] ?? 50)
                                ? AppColors.success
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    DataCell(Text('${emp['daily_call_target'] ?? 50}', style: GoogleFonts.inter(color: AppColors.textSecondary))),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: isActive,
                            activeTrackColor: AppColors.accentViolet,
                            onChanged: (val) {
                              context.read<EmployeeProvider>().toggleEmployeeStatus(emp['id'], val);
                            },
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isActive ? 'Active' : 'Disabled',
                            style: GoogleFonts.inter(fontSize: 12, color: isActive ? AppColors.success : AppColors.textMuted, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileList(List<dynamic> employees) {
    return ListView.separated(
      itemCount: employees.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final emp = employees[index];
        final isActive = emp['is_active'] == true;
        final branchName = emp['branch_name'];

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: isActive ? AppColors.accentVioletLight : AppColors.surfaceSecondary,
            child: Text(
              emp['first_name'] != null && emp['first_name'].isNotEmpty
                  ? emp['first_name'][0].toUpperCase()
                  : 'E',
              style: TextStyle(
                color: isActive ? AppColors.accentViolet : AppColors.textMuted,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 4,
            children: [
              Text(
                emp['full_name'] ?? emp['email'],
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              if (branchName != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.accentVioletLight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    branchName,
                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.accentViolet),
                  ),
                ),
            ],
          ),
          subtitle: Text(
            '${emp['email']} • Assigned: ${emp['assigned_leads_count'] ?? 0} • Calls: ${emp['calls_today_count'] ?? 0}',
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
          ),
          trailing: Switch(
            value: isActive,
            activeTrackColor: AppColors.accentViolet,
            onChanged: (val) {
              context.read<EmployeeProvider>().toggleEmployeeStatus(emp['id'], val);
            },
          ),
        );
      },
    );
  }
}
