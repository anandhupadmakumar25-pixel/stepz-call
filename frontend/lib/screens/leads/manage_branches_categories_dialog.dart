import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../core/widgets/glass/glass_card.dart';
import '../../core/widgets/glass/gradient_button.dart';
import '../../core/widgets/glass/animated_status_badge.dart';
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
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: GlassCard(
            blur: 24,
            opacity: 0.22,
            borderRadius: BorderRadius.circular(22),
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Create Branch',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white),
                        ),
                      ),
                      DialogCloseButton(onPressed: () => Navigator.of(ctx).pop()),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildGlassDialogInput(controller: nameController, label: 'Branch Name *', hint: 'e.g. Branch X or Downtown'),
                  const SizedBox(height: 12),
                  _buildGlassDialogInput(controller: codeController, label: 'Branch Code', hint: 'e.g. BR-X'),
                  const SizedBox(height: 12),
                  _buildGlassDialogInput(controller: addressController, label: 'Location / City', hint: 'e.g. 101 Marine Drive, Mumbai'),
                  Container(
                    margin: const EdgeInsets.only(top: 22),
                    padding: const EdgeInsets.only(top: 16),
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
                          text: 'Add Branch',
                          icon: Icons.add_rounded,
                          onPressed: () async {
                            if (nameController.text.trim().isEmpty) return;
                            final nav = Navigator.of(ctx);
                            final success = await context.read<LeadProvider>().createBranch(
                                  name: nameController.text.trim(),
                                  code: codeController.text.trim(),
                                  address: addressController.text.trim(),
                                );
                            if (success) nav.pop();
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
      ),
    );
  }

  void _showAddCategoryDialog() {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    String selectedColor = '#8B5CF6';

    final colorOptions = [
      {'name': 'Violet', 'hex': '#8B5CF6'},
      {'name': 'Cyan', 'hex': '#06B6D4'},
      {'name': 'Emerald', 'hex': '#10B981'},
      {'name': 'Amber', 'hex': '#F59E0B'},
      {'name': 'Rose', 'hex': '#EF4444'},
      {'name': 'Pink', 'hex': '#EC4899'},
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: GlassCard(
              blur: 24,
              opacity: 0.22,
              borderRadius: BorderRadius.circular(22),
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Create Category',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white),
                          ),
                        ),
                        DialogCloseButton(onPressed: () => Navigator.of(ctx).pop()),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildGlassDialogInput(controller: nameController, label: 'Category Name *', hint: 'e.g. Academy, VIP, Wholesale'),
                    const SizedBox(height: 12),
                    _buildGlassDialogInput(controller: descController, label: 'Description', hint: 'Lead segmentation notes'),
                    const SizedBox(height: 14),
                    Text('Accent Color', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      children: colorOptions.map((opt) {
                        final hex = opt['hex']!;
                        final color = Color(int.parse(hex.replaceFirst('#', '0xFF')));
                        final isSel = selectedColor == hex;

                        return InkWell(
                          onTap: () => setDlgState(() => selectedColor = hex),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSel ? Colors.white : Colors.transparent,
                                width: 2.5,
                              ),
                              boxShadow: isSel
                                  ? [
                                      BoxShadow(
                                        color: color.withValues(alpha: 0.5),
                                        blurRadius: 8,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: isSel ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                          ),
                        );
                      }).toList(),
                    ),
                    Container(
                      margin: const EdgeInsets.only(top: 22),
                      padding: const EdgeInsets.only(top: 16),
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
                            text: 'Add Category',
                            icon: Icons.add_rounded,
                            onPressed: () async {
                              if (nameController.text.trim().isEmpty) return;
                              final nav = Navigator.of(ctx);
                              final success = await context.read<LeadProvider>().createCategory(
                                    name: nameController.text.trim(),
                                    colorCode: selectedColor,
                                    description: descController.text.trim(),
                                  );
                              if (success) nav.pop();
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
        ),
      ),
    );
  }

  Widget _buildGlassDialogInput({required TextEditingController controller, required String label, required String hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
            filled: true,
            fillColor: Colors.black.withValues(alpha: 0.35),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.neonCyan)),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final leadProvider = context.watch<LeadProvider>();
    final isMobile = ResponsiveLayout.isMobile(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 14 : 24,
        vertical: isMobile ? 16 : 24,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 620),
        child: GlassCard(
          blur: 24,
          opacity: 0.2,
          borderRadius: BorderRadius.circular(24),
          padding: EdgeInsets.all(isMobile ? 18 : 24),
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
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.neonViolet.withValues(alpha: 0.4),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.category_rounded, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Branches & Categories',
                                style: GoogleFonts.inter(
                                  fontSize: isMobile ? 16 : 18,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                'Manage organization branches and multi-tier lead tags',
                                style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  DialogCloseButton(
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Glass Tabs
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: Colors.white,
                  unselectedLabelColor: AppColors.textSecondary,
                  labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                  dividerColor: Colors.transparent,
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.storefront_rounded, size: 16),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Branches (${leadProvider.branches.length})',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.local_offer_rounded, size: 16),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Categories (${leadProvider.categories.length})',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Tab View Content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildBranchesTab(leadProvider),
                    _buildCategoriesTab(leadProvider),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBranchesTab(LeadProvider leadProvider) {
    final branches = leadProvider.branches;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                '${branches.length} Registered Branches',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
              ),
            ),
            GradientPrimaryButton(
              text: 'Add Branch',
              icon: Icons.add_rounded,
              gradient: AppColors.cyanGradient,
              onPressed: _showAddBranchDialog,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: branches.isEmpty
              ? Center(child: Text('No branches added yet.', style: GoogleFonts.inter(color: AppColors.textMuted)))
              : ListView.separated(
                  itemCount: branches.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final b = branches[index];
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.neonCyan.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.storefront_rounded, size: 18, color: AppColors.neonCyan),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(b.name, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white)),
                                    if (b.code.isNotEmpty)
                                      AnimatedStatusBadge(label: b.code, statusColor: AppColors.neonCyan),
                                  ],
                                ),
                                if (b.address.isNotEmpty)
                                  Text(b.address, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                              ],
                            ),
                          ),
                          AnimatedStatusBadge(label: '${b.leadCount} Leads', statusColor: AppColors.neonViolet),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCategoriesTab(LeadProvider leadProvider) {
    final categories = leadProvider.categories;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                '${categories.length} Categories',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
              ),
            ),
            GradientPrimaryButton(
              text: 'Add Category',
              icon: Icons.add_rounded,
              gradient: AppColors.primaryGradient,
              onPressed: _showAddCategoryDialog,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: categories.isEmpty
              ? Center(child: Text('No categories added yet.', style: GoogleFonts.inter(color: AppColors.textMuted)))
              : ListView.separated(
                  itemCount: categories.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final c = categories[index];
                    Color dotColor = AppColors.neonViolet;
                    if (c.colorCode.startsWith('#')) {
                      try {
                        dotColor = Color(int.parse(c.colorCode.replaceFirst('#', '0xFF')));
                      } catch (_) {}
                    }

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: dotColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(color: dotColor.withValues(alpha: 0.4), blurRadius: 6),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(c.name, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white)),
                                if (c.description.isNotEmpty)
                                  Text(c.description, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                              ],
                            ),
                          ),
                          AnimatedStatusBadge(label: '${c.leadCount} Leads', statusColor: dotColor),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
