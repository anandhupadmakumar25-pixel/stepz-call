import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../providers/company_provider.dart';

class CompanyDirectoryScreen extends StatefulWidget {
  const CompanyDirectoryScreen({super.key});

  @override
  State<CompanyDirectoryScreen> createState() => _CompanyDirectoryScreenState();
}

class _CompanyDirectoryScreenState extends State<CompanyDirectoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CompanyProvider>().fetchCompanies();
    });
  }

  void _showCreateCompanyDialog() {
    final compNameController = TextEditingController();
    final contactEmailController = TextEditingController();
    final adminEmailController = TextEditingController();
    final adminPasswordController = TextEditingController();
    final adminFirstNameController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Create Tenant Company', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: compNameController, decoration: const InputDecoration(labelText: 'Company Name *')),
              const SizedBox(height: 10),
              TextField(controller: contactEmailController, decoration: const InputDecoration(labelText: 'Contact Email *')),
              const SizedBox(height: 10),
              TextField(controller: adminFirstNameController, decoration: const InputDecoration(labelText: 'Company Admin First Name *')),
              const SizedBox(height: 10),
              TextField(controller: adminEmailController, decoration: const InputDecoration(labelText: 'Company Admin Login Email *')),
              const SizedBox(height: 10),
              TextField(controller: adminPasswordController, obscureText: true, decoration: const InputDecoration(labelText: 'Company Admin Initial Password *')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (compNameController.text.trim().isEmpty || adminEmailController.text.trim().isEmpty) return;
              final nav = Navigator.of(ctx);
              final scaffold = ScaffoldMessenger.of(context);
              final success = await context.read<CompanyProvider>().createCompany({
                'name': compNameController.text.trim(),
                'contact_email': contactEmailController.text.trim(),
                'admin_email': adminEmailController.text.trim(),
                'admin_password': adminPasswordController.text,
                'admin_first_name': adminFirstNameController.text.trim(),
                'status': 'ACTIVE',
              });
              if (success) {
                nav.pop();
                scaffold.showSnackBar(
                  const SnackBar(content: Text('Company and Admin created successfully!'), backgroundColor: AppColors.success),
                );
              }
            },
            child: const Text('Create Company'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final compProvider = context.watch<CompanyProvider>();
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
                      Text('Tenant Companies Directory', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
                      Text(
                        'Super Admin platform tenant control and provisioning',
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
                  onPressed: _showCreateCompanyDialog,
                  icon: const Icon(Icons.add_business, size: 16),
                  label: const Text('New Company'),
                ),
              ],
            ),
            const SizedBox(height: 14),

            Expanded(
              child: Card(
                child: compProvider.isLoading && compProvider.companies.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : compProvider.companies.isEmpty
                        ? const EmptyState(
                            icon: Icons.business,
                            title: 'No companies found',
                            description: 'Create a tenant company to invite the first Company Admin.',
                          )
                        : ListView.separated(
                            itemCount: compProvider.companies.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final comp = compProvider.companies[index];
                              return ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.navBackground,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.business, color: Colors.white, size: 18),
                                ),
                                title: Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    Text(comp.name, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                                    StatusBadge(status: comp.status),
                                  ],
                                ),
                                subtitle: Text(
                                  '${comp.contactEmail} • ${comp.userCount} users • ${comp.leadCount} leads in pool',
                                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                                ),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (val) {
                                    context.read<CompanyProvider>().updateCompanyStatus(comp.id, val);
                                  },
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(value: 'ACTIVE', child: Text('Set Active')),
                                    const PopupMenuItem(value: 'SUSPENDED', child: Text('Suspend Company')),
                                    const PopupMenuItem(value: 'TRIAL', child: Text('Set Trial')),
                                  ],
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
