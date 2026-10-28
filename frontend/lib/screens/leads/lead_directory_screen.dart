import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../providers/lead_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/lead_model.dart';
import 'import_wizard_dialog.dart';
import 'bulk_assign_dialog.dart';
import 'add_lead_dialog.dart';
import 'lead_detail_screen.dart';
import 'manage_branches_categories_dialog.dart';

class LeadDirectoryScreen extends StatefulWidget {
  const LeadDirectoryScreen({super.key});

  @override
  State<LeadDirectoryScreen> createState() => _LeadDirectoryScreenState();
}

class _LeadDirectoryScreenState extends State<LeadDirectoryScreen> {
  final _searchController = TextEditingController();
  String _selectedStatus = 'ALL';
  String _selectedBranch = 'ALL';
  String _selectedCategory = 'ALL';
  final Set<String> _selectedLeadIds = {};

  final List<String> _statusOptions = [
    'ALL',
    'UNASSIGNED',
    'ASSIGNED',
    'IN_PROGRESS',
    'CALLBACK_REQUESTED',
    'QUALIFIED',
    'COMPLETED',
    'BLOCKED',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<LeadProvider>();
      p.fetchBranches();
      p.fetchCategories();
      p.fetchLeads();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _triggerFilter() {
    context.read<LeadProvider>().fetchLeads(
      status: _selectedStatus,
      branchId: _selectedBranch,
      categoryId: _selectedCategory,
      search: _searchController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final leadProvider = context.watch<LeadProvider>();
    final auth = context.watch<AuthProvider>();
    final isTelecaller = auth.currentUser?.isEmployee ?? true;
    final isMobile = ResponsiveLayout.isMobile(context);

    final branches = leadProvider.branches;
    final categories = leadProvider.categories;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 20),
        child: Column(
          children: [
            // Top Toolbar & Action Controls
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    // Search & Dynamic Filter Controls
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // Search Input
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: isMobile ? double.infinity : 240,
                            maxWidth: isMobile ? double.infinity : 320,
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (_) => _triggerFilter(),
                            decoration: InputDecoration(
                              hintText: 'Search name, phone, city...',
                              prefixIcon: const Icon(Icons.search, size: 18),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 16),
                                      onPressed: () {
                                        _searchController.clear();
                                        _triggerFilter();
                                      },
                                    )
                                  : null,
                            ),
                          ),
                        ),

                        // Dynamic Branch Filter Dropdown
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedBranch,
                              hint: const Text('Branch'),
                              items: [
                                const DropdownMenuItem(value: 'ALL', child: Text('All Branches', style: TextStyle(fontSize: 12))),
                                ...branches.map((b) => DropdownMenuItem(
                                      value: b.id,
                                      child: Text(b.name, style: const TextStyle(fontSize: 12)),
                                    )),
                              ],
                              onChanged: (val) {
                                if (val == null) return;
                                setState(() => _selectedBranch = val);
                                _triggerFilter();
                              },
                            ),
                          ),
                        ),

                        // Dynamic Category Filter Dropdown
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedCategory,
                              hint: const Text('Category'),
                              items: [
                                const DropdownMenuItem(value: 'ALL', child: Text('All Categories', style: TextStyle(fontSize: 12))),
                                ...categories.map((c) => DropdownMenuItem(
                                      value: c.id,
                                      child: Text(c.name, style: const TextStyle(fontSize: 12)),
                                    )),
                              ],
                              onChanged: (val) {
                                if (val == null) return;
                                setState(() => _selectedCategory = val);
                                _triggerFilter();
                              },
                            ),
                          ),
                        ),

                        // Status Filter Dropdown
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedStatus,
                              items: _statusOptions.map((st) {
                                return DropdownMenuItem(
                                  value: st,
                                  child: Text(st.replaceAll('_', ' '), style: GoogleFonts.inter(fontSize: 12)),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val == null) return;
                                setState(() => _selectedStatus = val);
                                _triggerFilter();
                              },
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Actions Bar (Branches & Categories, Bulk Assign, Import Wizard, Add Lead)
                    if (!isTelecaller) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${_selectedLeadIds.length} selected',
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                              ),
                              if (_selectedLeadIds.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.accentViolet,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (_) => BulkAssignDialog(selectedLeadIds: _selectedLeadIds.toList()),
                                    );
                                  },
                                  icon: const Icon(Icons.assignment_ind, size: 15),
                                  label: const Text('Bulk Assign'),
                                ),
                              ],
                            ],
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (_) => const ManageBranchesCategoriesDialog(),
                                  );
                                },
                                icon: const Icon(Icons.tune, size: 15),
                                label: const Text('Branches & Categories'),
                              ),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (_) => const ImportWizardDialog(),
                                  );
                                },
                                icon: const Icon(Icons.upload_file, size: 15),
                                label: const Text('Import Excel/CSV'),
                              ),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  backgroundColor: AppColors.accentViolet,
                                ),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (_) => const AddLeadDialog(),
                                  );
                                },
                                icon: const Icon(Icons.add, size: 15),
                                label: const Text('Add Lead'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Leads Directory List / Table
            Expanded(
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: leadProvider.isLoading && leadProvider.leads.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : leadProvider.leads.isEmpty
                        ? EmptyState(
                            icon: Icons.person_off_outlined,
                            title: 'No leads found',
                            description: 'No leads match your current search, branch, and category filters.',
                            actionLabel: !isTelecaller ? 'Add Lead' : null,
                            onAction: () {
                              showDialog(
                                context: context,
                                builder: (_) => const AddLeadDialog(),
                              );
                            },
                          )
                        : isMobile
                            ? _buildMobileList(leadProvider.leads, isTelecaller)
                            : _buildDataTable(leadProvider.leads, isTelecaller),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataTable(List<LeadModel> leads, bool isTelecaller) {
    final horizontalScrollController = ScrollController();

    return Scrollbar(
      controller: horizontalScrollController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: horizontalScrollController,
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 1050),
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: DataTable(
              showCheckboxColumn: !isTelecaller,
              headingRowHeight: 46,
              dataRowMinHeight: 52,
              dataRowMaxHeight: 58,
              onSelectAll: !isTelecaller
                  ? (selected) {
                      setState(() {
                        if (selected == true) {
                          _selectedLeadIds.addAll(leads.map((l) => l.id));
                        } else {
                          _selectedLeadIds.clear();
                        }
                      });
                    }
                  : null,
              columns: const [
                DataColumn(label: Text('CUSTOMER NAME', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 0.5))),
                DataColumn(label: Text('PHONE (E.164)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 0.5))),
                DataColumn(label: Text('BRANCH', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 0.5))),
                DataColumn(label: Text('CATEGORY', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 0.5))),
                DataColumn(label: Text('STATUS', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 0.5))),
                DataColumn(label: Text('ASSIGNED TO', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 0.5))),
                DataColumn(label: Text('ACTIONS', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 0.5))),
              ],
              rows: leads.map((lead) {
                final isSelected = _selectedLeadIds.contains(lead.id);

                Color catColor = AppColors.accentViolet;
                if (lead.categoryColor != null) {
                  try {
                    catColor = Color(int.parse(lead.categoryColor!.replaceAll('#', '0xFF')));
                  } catch (_) {}
                }

                return DataRow(
                  selected: isSelected,
                  onSelectChanged: !isTelecaller
                      ? (selected) {
                          setState(() {
                            if (selected == true) {
                              _selectedLeadIds.add(lead.id);
                            } else {
                              _selectedLeadIds.remove(lead.id);
                            }
                          });
                        }
                      : null,
                  cells: [
                    DataCell(
                      InkWell(
                        onTap: () => _openLeadDetail(lead.id),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: AppColors.accentVioletLight,
                              child: Text(
                                lead.fullName.isNotEmpty ? lead.fullName[0].toUpperCase() : 'L',
                                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.accentViolet),
                              ),
                            ),
                            const SizedBox(width: 10),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 170),
                              child: Text(
                                lead.fullName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.accentViolet, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSecondary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          lead.normalizedPhone,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.store_mall_directory_outlined, size: 14, color: AppColors.textMuted),
                          const SizedBox(width: 5),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 140),
                            child: Text(
                              lead.branchName ?? 'Unassigned Branch',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: lead.branchName != null ? FontWeight.w600 : FontWeight.w400,
                                color: lead.branchName != null ? AppColors.textPrimary : AppColors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: catColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          lead.categoryName ?? 'General',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: catColor),
                        ),
                      ),
                    ),
                    DataCell(StatusBadge(status: lead.status)),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            lead.assignedToName != null ? Icons.person_outline : Icons.person_off_outlined,
                            size: 14,
                            color: lead.assignedToName != null ? AppColors.accentViolet : AppColors.textMuted,
                          ),
                          const SizedBox(width: 6),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 130),
                            child: Text(
                              lead.assignedToName ?? 'Unassigned Pool',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: lead.assignedToName != null ? FontWeight.w500 : FontWeight.w400,
                                color: lead.assignedToName != null ? AppColors.textPrimary : AppColors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_forward, size: 16, color: AppColors.textSecondary),
                            tooltip: 'View Profile',
                            onPressed: () => _openLeadDetail(lead.id),
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

  Widget _buildMobileList(List<LeadModel> leads, bool isTelecaller) {
    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: leads.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final lead = leads[index];
        final isSelected = _selectedLeadIds.contains(lead.id);

        Color catColor = AppColors.accentViolet;
        if (lead.categoryColor != null) {
          try {
            catColor = Color(int.parse(lead.categoryColor!.replaceAll('#', '0xFF')));
          } catch (_) {}
        }

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: isSelected ? AppColors.accentViolet : AppColors.border,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: InkWell(
            onTap: () => _openLeadDetail(lead.id),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.accentVioletLight,
                        child: Text(
                          lead.fullName.isNotEmpty ? lead.fullName[0].toUpperCase() : 'L',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.accentViolet),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lead.fullName,
                              style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              lead.normalizedPhone,
                              style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      StatusBadge(status: lead.status),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (lead.branchName != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSecondary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '📍 ${lead.branchName}',
                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          ),
                        ),
                      if (lead.categoryName != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: catColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '🏷 ${lead.categoryName}',
                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: catColor),
                          ),
                        ),
                      if (lead.assignedToName != null)
                        Text(
                          '👤 ${lead.assignedToName}',
                          style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _openLeadDetail(String leadId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LeadDetailScreen(leadId: leadId),
      ),
    );
  }
}
