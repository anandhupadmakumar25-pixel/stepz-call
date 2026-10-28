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
    final adminEmailController = TextEditingController();
    final adminPasswordController = TextEditingController();
    final phoneController = TextEditingController();
    final subdomainController = TextEditingController();
    final adminNameController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
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
              child: const Icon(Icons.business, color: AppColors.accentViolet, size: 20),
            ),
            const SizedBox(width: 10),
            Text('Create Tenant Company', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Only Company Name, Admin Email, and Admin Password are required. The tenant will receive its own isolated lead pool, branch manager, and calling task features.',
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: compNameController,
                  decoration: const InputDecoration(
                    labelText: 'Company Name *',
                    hintText: 'e.g. Apex Global or Zenith Academy',
                    prefixIcon: Icon(Icons.storefront, size: 18),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: adminEmailController,
                  decoration: const InputDecoration(
                    labelText: 'Admin Login Email *',
                    hintText: 'admin@company.com',
                    prefixIcon: Icon(Icons.email_outlined, size: 18),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: adminPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Admin Initial Password *',
                    hintText: 'Minimum 6 characters',
                    prefixIcon: Icon(Icons.lock_outline, size: 18),
                  ),
                ),
                const SizedBox(height: 14),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text('Optional Company Details', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.accentViolet)),
                  children: [
                    const SizedBox(height: 8),
                    TextField(
                      controller: adminNameController,
                      decoration: const InputDecoration(labelText: 'Admin First Name (Optional)', hintText: 'Admin'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: phoneController,
                      decoration: const InputDecoration(labelText: 'Contact Phone (Optional)', hintText: '+91 9876543210'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: subdomainController,
                      decoration: const InputDecoration(labelText: 'Subdomain / Slug (Optional)', hintText: 'e.g. apex'),
                    ),
                    const SizedBox(height: 10),
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
              final compName = compNameController.text.trim();
              final adminEmail = adminEmailController.text.trim();
              final adminPass = adminPasswordController.text;

              if (compName.isEmpty || adminEmail.isEmpty || adminPass.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill Company Name, Admin Email, and Admin Password.'), backgroundColor: AppColors.danger),
                );
                return;
              }

              final nav = Navigator.of(ctx);
              final scaffold = ScaffoldMessenger.of(context);
              final success = await context.read<CompanyProvider>().createCompany({
                'name': compName,
                'admin_email': adminEmail,
                'admin_password': adminPass,
                'admin_first_name': adminNameController.text.trim().isNotEmpty ? adminNameController.text.trim() : 'Admin',
                'contact_email': adminEmail,
                'contact_phone': phoneController.text.trim(),
                'subdomain': subdomainController.text.trim().isNotEmpty ? subdomainController.text.trim() : null,
                'status': 'ACTIVE',
              });

              if (success) {
                nav.pop();
                scaffold.showSnackBar(
                  SnackBar(
                    content: Text('Company "$compName" and Admin credentials created successfully!'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            },
            child: const Text('Create Company & Admin'),
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
