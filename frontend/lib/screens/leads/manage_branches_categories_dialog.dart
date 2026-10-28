import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/lead_provider.dart';

class ManageBranchesCategoriesDialog extends StatefulWidget {
  const ManageBranchesCategoriesDialog({super.key});

  @override
  State<ManageBranchesCategoriesDialog> createState() => _ManageBranchesCategoriesDialogState();
}

class _ManageBranchesCategoriesDialogState extends State<ManageBranchesCategoriesDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LeadProvider>().fetchBranches();
      context.read<LeadProvider>().fetchCategories();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showAddBranchDialog() {
    final nameController = TextEditingController();
    final codeController = TextEditingController();
    final addressController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add New Branch', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Branch Name *', hintText: 'e.g. Branch X or Downtown Campus'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: codeController,
              decoration: const InputDecoration(labelText: 'Branch Code (Optional)', hintText: 'e.g. BR-X'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: addressController,
              decoration: const InputDecoration(labelText: 'Location / Address', hintText: 'e.g. 101 Central Ave'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              final nav = Navigator.of(ctx);
              final success = await context.read<LeadProvider>().createBranch(
                    name: nameController.text.trim(),
                    code: codeController.text.trim(),
                    address: addressController.text.trim(),
                  );
              if (success) {
                nav.pop();
              }
            },
            child: const Text('Add Branch'),
          ),
        ],
      ),
    );
  }

  void _showAddCategoryDialog() {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    String selectedColor = '#6366F1';

    final colorOptions = [
      {'name': 'Indigo', 'hex': '#6366F1'},
      {'name': 'Emerald', 'hex': '#10B981'},
      {'name': 'Amber', 'hex': '#F59E0B'},
      {'name': 'Rose', 'hex': '#EF4444'},
      {'name': 'Sky', 'hex': '#0EA5E9'},
      {'name': 'Purple', 'hex': '#A855F7'},
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: Text('Add New Category', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Category Name *', hintText: 'e.g. Academy, Client, Customer'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: 'Description (Optional)', hintText: 'e.g. Corporate leads for sales team'),
              ),
              const SizedBox(height: 14),
              Text('Badge Color', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: colorOptions.map((opt) {
                  final hex = opt['hex']!;
                  final isSelected = selectedColor == hex;
                  final color = Color(int.parse(hex.replaceAll('#', '0xFF')));

                  return InkWell(
                    onTap: () => setDlgState(() => selectedColor = hex),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.black : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;
                final nav = Navigator.of(ctx);
                final success = await context.read<LeadProvider>().createCategory(
                      name: nameController.text.trim(),
                      colorCode: selectedColor,
                      description: descController.text.trim(),
                    );
                if (success) {
                  nav.pop();
                }
              },
              child: const Text('Add Category'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final leadProvider = context.watch<LeadProvider>();

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.accentVioletLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.category_outlined, color: AppColors.accentViolet, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Dynamic Branches & Categories', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                              Text('Configure dynamic departments, branches (Branch X/Y) and lead groups (Academy/Client)', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
                ],
              ),
              const SizedBox(height: 12),

              // TabBar
              TabBar(
                controller: _tabController,
                labelColor: AppColors.accentViolet,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.accentViolet,
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.store_mall_directory_outlined, size: 16),
                        const SizedBox(width: 6),
                        Text('Branches (${leadProvider.branches.length})'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.label_outline, size: 16),
                        const SizedBox(width: 6),
                        Text('Lead Categories (${leadProvider.categories.length})'),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Tab Content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Branches Tab
                    Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('All Registered Branches', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                              onPressed: _showAddBranchDialog,
                              icon: const Icon(Icons.add, size: 14),
                              label: const Text('Add Branch'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: leadProvider.branches.isEmpty
                              ? Center(
                                  child: Text('No branches configured. Add your first branch above.', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                                )
                              : ListView.separated(
                                  itemCount: leadProvider.branches.length,
                                  separatorBuilder: (_, __) => const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final branch = leadProvider.branches[index];
                                    return ListTile(
                                      leading: CircleAvatar(
                                        radius: 14,
                                        backgroundColor: AppColors.surfaceSecondary,
                                        child: const Icon(Icons.business, size: 14, color: AppColors.accentViolet),
                                      ),
                                      title: Text(branch.name, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                                      subtitle: Text(
                                        '${branch.code.isNotEmpty ? '[${branch.code}] ' : ''}${branch.address.isNotEmpty ? branch.address : 'No address'} • ${branch.leadCount} leads',
                                        style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary),
                                      ),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                                        onPressed: () => leadProvider.deleteBranch(branch.id),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),

                    // Categories Tab
                    Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('All Lead Categories', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                              onPressed: _showAddCategoryDialog,
                              icon: const Icon(Icons.add, size: 14),
                              label: const Text('Add Category'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: leadProvider.categories.isEmpty
                              ? Center(
                                  child: Text('No categories configured. Add your first category above.', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                                )
                              : ListView.separated(
                                  itemCount: leadProvider.categories.length,
                                  separatorBuilder: (_, __) => const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final cat = leadProvider.categories[index];
                                    Color catColor = AppColors.accentViolet;
                                    try {
                                      catColor = Color(int.parse(cat.colorCode.replaceAll('#', '0xFF')));
                                    } catch (_) {}

                                    return ListTile(
                                      leading: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: catColor.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          cat.name,
                                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: catColor),
                                        ),
                                      ),
                                      title: Text(cat.name, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                                      subtitle: Text(
                                        '${cat.description.isNotEmpty ? '${cat.description} • ' : ''}${cat.leadCount} leads',
                                        style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary),
                                      ),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                                        onPressed: () => leadProvider.deleteCategory(cat.id),
                                      ),
                                    );
                                  },
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
    );
  }
}
