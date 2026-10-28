import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../providers/employee_provider.dart';

class EmployeeManagementScreen extends StatefulWidget {
  const EmployeeManagementScreen({super.key});

  @override
  State<EmployeeManagementScreen> createState() => _EmployeeManagementScreenState();
}

class _EmployeeManagementScreenState extends State<EmployeeManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EmployeeProvider>().fetchEmployees();
    });
  }

  void _showAddEmployeeDialog() {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();
    final targetController = TextEditingController(text: '50');
    String role = 'EMPLOYEE';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text('Add New Employee / Telecaller', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(
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
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: const [
                    DropdownMenuItem(value: 'EMPLOYEE', child: Text('Employee / Telecaller')),
                    DropdownMenuItem(value: 'MANAGER', child: Text('Team Manager')),
                  ],
                  onChanged: (v) => setDialogState(() => role = v!),
                ),
                const SizedBox(height: 12),
                TextField(controller: targetController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Daily Call Target')),
              ],
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
                  'daily_call_target': int.tryParse(targetController.text) ?? 50,
                });
                if (success) {
                  nav.pop();
                  scaffold.showSnackBar(
                    const SnackBar(content: Text('Employee created successfully.'), backgroundColor: AppColors.success),
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

  @override
  Widget build(BuildContext context) {
    final empProvider = context.watch<EmployeeProvider>();
    final isMobile = ResponsiveLayout.isMobile(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Employee & Telecaller Team', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
                      Text(
                        'Manage telecallers, managers, and monitor targets',
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onPressed: _showAddEmployeeDialog,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Employee'),
                ),
              ],
            ),
            const SizedBox(height: 14),

            Expanded(
              child: Card(
                child: empProvider.isLoading && empProvider.employees.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : empProvider.employees.isEmpty
                        ? EmptyState(
                            icon: Icons.badge_outlined,
                            title: 'No employees created yet',
                            description: 'Add your first telecaller or manager to begin assigning leads.',
                            actionLabel: 'Add Employee',
                            onAction: _showAddEmployeeDialog,
                          )
                        : ListView.separated(
                            itemCount: empProvider.employees.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final emp = empProvider.employees[index];
                              final isActive = emp['is_active'] == true;

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
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceSecondary,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        emp['role']?.replaceAll('_', ' ') ?? '',
                                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Text(
                                  '${emp['email']} • Assigned: ${emp['assigned_leads_count'] ?? 0} • Calls Today: ${emp['calls_today_count'] ?? 0}',
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
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
