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
                clipBehavior: Clip.antiAlias,
                child: compProvider.isLoading && compProvider.companies.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : compProvider.companies.isEmpty
                        ? const EmptyState(
                            icon: Icons.business,
                            title: 'No companies found',
                            description: 'Create a tenant company to invite the first Company Admin.',
                          )
                        : isMobile
                            ? _buildMobileList(compProvider.companies)
                            : _buildDataTable(compProvider.companies),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataTable(List<dynamic> companies) {
    final horizontalScrollController = ScrollController();

    return Scrollbar(
      controller: horizontalScrollController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: horizontalScrollController,
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 800),
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: DataTable(
              headingRowHeight: 46,
              dataRowMinHeight: 52,
              dataRowMaxHeight: 60,
              columns: const [
                DataColumn(label: Text('TENANT COMPANY', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 0.5))),
                DataColumn(label: Text('CONTACT EMAIL', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 0.5))),
                DataColumn(label: Text('USERS', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 0.5))),
                DataColumn(label: Text('LEAD POOL', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 0.5))),
                DataColumn(label: Text('TENANT STATUS', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 0.5))),
                DataColumn(label: Text('ACTIONS', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 0.5))),
              ],
              rows: companies.map((comp) {
                return DataRow(
                  cells: [
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: AppColors.navBackground,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.business, color: Colors.white, size: 14),
                          ),
                          const SizedBox(width: 10),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 180),
                            child: Text(
                              comp.name,
                              style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    DataCell(Text(comp.contactEmail, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary))),
                    DataCell(Text('${comp.userCount}', style: GoogleFonts.inter(fontWeight: FontWeight.w600))),
                    DataCell(Text('${comp.leadCount}', style: GoogleFonts.inter(fontWeight: FontWeight.w600))),
                    DataCell(StatusBadge(status: comp.status)),
                    DataCell(
                      PopupMenuButton<String>(
                        tooltip: 'Manage Tenant',
                        icon: const Icon(Icons.more_vert, size: 18),
                        onSelected: (val) {
                          context.read<CompanyProvider>().updateCompanyStatus(comp.id, val);
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'ACTIVE', child: Text('Set Active')),
                          const PopupMenuItem(value: 'SUSPENDED', child: Text('Suspend Company')),
                          const PopupMenuItem(value: 'TRIAL', child: Text('Set Trial')),
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

  Widget _buildMobileList(List<dynamic> companies) {
    return ListView.separated(
      itemCount: companies.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final comp = companies[index];
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
    );
  }
}
