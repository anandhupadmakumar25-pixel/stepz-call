import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass/glass_scaffold.dart';
import '../../core/widgets/glass/glass_card.dart';
import '../../core/widgets/glass/gradient_button.dart';
import '../../core/widgets/glass/animated_status_badge.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../routes/app_routes.dart';
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
    'BUSY',
    'NO_ANSWER',
    'QUALIFIED',
    'COMPLETED',
    'NOT_INTERESTED',
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

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'QUALIFIED':
      case 'COMPLETED':
        return AppColors.neonCyan;
      case 'CALLBACK_REQUESTED':
      case 'IN_PROGRESS':
        return AppColors.neonSunset;
      case 'BUSY':
      case 'NO_ANSWER':
        return const Color(0xFFF97316);
      case 'UNASSIGNED':
        return AppColors.neonViolet;
      case 'BLOCKED':
      case 'NOT_INTERESTED':
        return AppColors.neonCoral;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final leadProvider = context.watch<LeadProvider>();
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final isSuperAdmin = user?.isSuperAdmin ?? false;
    final canViewAll = isSuperAdmin || (user?.hasPermission('leads.view_all') ?? false);
    final isTelecaller = (user?.isEmployee ?? true) && !canViewAll;
    final canCreateLead = isSuperAdmin || (user?.hasPermission('leads.create') ?? false);
    final canImportLeads = isSuperAdmin || (user?.hasPermission('leads.import') ?? false);
    final canAssignLeads = isSuperAdmin || (user?.hasPermission('leads.assign') ?? false);
    final canManageBranches = isSuperAdmin || (user?.hasPermission('branches.manage') ?? false);
    final isMobile = ResponsiveLayout.isMobile(context);

    final branches = leadProvider.branches;
    final categories = leadProvider.categories;

    return GlassScaffold(
      backgroundImage: 'assets/images/telecaller_workspace_bg.jpg',
      body: Padding(
        padding: EdgeInsets.fromLTRB(
          isMobile ? 12 : 24,
          isMobile ? 6 : 16,
          isMobile ? 12 : 24,
          isMobile ? 10 : 20,
        ),
        child: Column(
          children: [
            // Top Header Bar with Prominent Back Button
            Row(
              children: [
                const AppBackButton(fallbackRoute: AppRoutes.dashboard),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              isTelecaller ? 'My Assigned Leads' : 'Company Lead Directory',
                              style: GoogleFonts.inter(
                                fontSize: isMobile ? 18 : 22,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A),
                                letterSpacing: -0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 10),
                          AnimatedStatusBadge(
                            label: '${leadProvider.totalCount} Leads',
                            statusColor: AppColors.neonCyan,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Centralized lead management directory with branch, category, and pipeline status filters',
                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Top Toolbar Glass Card
            GlassCard(
              blur: 20,
              opacity: 0.16,
              borderRadius: BorderRadius.circular(20),
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  // Search & Dynamic Filter Controls
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Search Input
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: isMobile ? double.infinity : 220,
                          maxWidth: isMobile ? double.infinity : 300,
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (_) => _triggerFilter(),
                          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF0F172A), fontWeight: FontWeight.w500),
                          decoration: InputDecoration(
                            hintText: 'Search name, phone, city...',
                            hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
                            prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            isDense: true,
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 16, color: Color(0xFF94A3B8)),
                                    onPressed: () {
                                      _searchController.clear();
                                      _triggerFilter();
                                    },
                                  )
                                : null,
                          ),
                        ),
                      ),

                      // Branch Filter
                      _buildDropdownFilter(
                        width: isMobile ? double.infinity : 160,
                        value: _selectedBranch,
                        items: [
                          const DropdownMenuItem(value: 'ALL', child: Text('All Branches', overflow: TextOverflow.ellipsis)),
                          ...branches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name, overflow: TextOverflow.ellipsis))),
                        ],
                        onChanged: (val) {
                          if (val == null) return;
                          setState(() => _selectedBranch = val);
                          _triggerFilter();
                        },
                      ),

                      // Category Filter
                      _buildDropdownFilter(
                        width: isMobile ? double.infinity : 160,
                        value: _selectedCategory,
                        items: [
                          const DropdownMenuItem(value: 'ALL', child: Text('All Categories', overflow: TextOverflow.ellipsis)),
                          ...categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis))),
                        ],
                        onChanged: (val) {
                          if (val == null) return;
                          setState(() => _selectedCategory = val);
                          _triggerFilter();
                        },
                      ),

                      // Status Filter
                      _buildDropdownFilter(
                        width: isMobile ? double.infinity : 165,
                        value: _selectedStatus,
                        items: _statusOptions.map((s) => DropdownMenuItem(value: s, child: Text(s.replaceAll('_', ' '), overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (val) {
                          if (val == null) return;
                          setState(() => _selectedStatus = val);
                          _triggerFilter();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Actions Area: Count Badges & Action Buttons
                  isMobile
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                AnimatedStatusBadge(
                                  label: '${leadProvider.totalCount} Leads',
                                  statusColor: AppColors.neonCyan,
                                ),
                                if (_selectedLeadIds.isNotEmpty) ...[
                                  const SizedBox(width: 10),
                                  AnimatedStatusBadge(
                                    label: '${_selectedLeadIds.length} Selected',
                                    statusColor: AppColors.neonViolet,
                                  ),
                                ],
                              ],
                            ),
                            if (!isTelecaller || canCreateLead || canImportLeads || canAssignLeads) ...[
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (canAssignLeads && _selectedLeadIds.isNotEmpty)
                                    GradientPrimaryButton(
                                      text: 'Bulk Assign (${_selectedLeadIds.length})',
                                      icon: Icons.assignment_ind_rounded,
                                      gradient: AppColors.sunsetGradient,
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (_) => BulkAssignDialog(selectedLeadIds: _selectedLeadIds.toList()),
                                        ).then((_) {
                                          setState(() => _selectedLeadIds.clear());
                                          _triggerFilter();
                                        });
                                      },
                                    ),
                                  if (canManageBranches)
                                    GlassSecondaryButton(
                                      text: 'Categories',
                                      icon: Icons.tune_rounded,
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (_) => const ManageBranchesCategoriesDialog(),
                                        );
                                      },
                                    ),
                                  if (canImportLeads)
                                    GlassSecondaryButton(
                                      text: 'Import',
                                      icon: Icons.upload_file_rounded,
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (_) => const ImportWizardDialog(),
                                        );
                                      },
                                    ),
                                  if (canCreateLead)
                                    GradientPrimaryButton(
                                      text: 'Add Lead',
                                      icon: Icons.add_rounded,
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (_) => const AddLeadDialog(),
                                        );
                                      },
                                    ),
                                ],
                              ),
                            ],
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                AnimatedStatusBadge(
                                  label: '${leadProvider.totalCount} Leads Found',
                                  statusColor: AppColors.neonCyan,
                                ),
                                if (_selectedLeadIds.isNotEmpty) ...[
                                  const SizedBox(width: 10),
                                  AnimatedStatusBadge(
                                    label: '${_selectedLeadIds.length} Selected',
                                    statusColor: AppColors.neonViolet,
                                  ),
                                ],
                              ],
                            ),
                            if (!isTelecaller || canCreateLead || canImportLeads || canAssignLeads)
                              Wrap(
                                spacing: 10,
                                runSpacing: 8,
                                children: [
                                  if (canAssignLeads && _selectedLeadIds.isNotEmpty)
                                    GradientPrimaryButton(
                                      text: 'Bulk Assign (${_selectedLeadIds.length})',
                                      icon: Icons.assignment_ind_rounded,
                                      gradient: AppColors.sunsetGradient,
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (_) => BulkAssignDialog(selectedLeadIds: _selectedLeadIds.toList()),
                                        ).then((_) {
                                          setState(() => _selectedLeadIds.clear());
                                          _triggerFilter();
                                        });
                                      },
                                    ),
                                  if (canManageBranches)
                                    GlassSecondaryButton(
                                      text: 'Branches & Categories',
                                      icon: Icons.tune_rounded,
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (_) => const ManageBranchesCategoriesDialog(),
                                        );
                                      },
                                    ),
                                  if (canImportLeads)
                                    GlassSecondaryButton(
                                      text: 'Import CSV / Excel',
                                      icon: Icons.upload_file_rounded,
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (_) => const ImportWizardDialog(),
                                        );
                                      },
                                    ),
                                  if (canCreateLead)
                                    GradientPrimaryButton(
                                      text: 'Add Lead',
                                      icon: Icons.add_rounded,
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (_) => const AddLeadDialog(),
                                        );
                                      },
                                    ),
                                ],
                              ),
                          ],
                        ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Leads Directory List / Table
            Expanded(
              child: GlassCard(
                blur: 20,
                opacity: 0.16,
                borderRadius: BorderRadius.circular(20),
                padding: const EdgeInsets.all(16),
                child: leadProvider.isLoading && leadProvider.leads.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : leadProvider.leads.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.person_off_rounded, size: 52, color: Colors.white24),
                                const SizedBox(height: 12),
                                Text(
                                  'No Leads Found',
                                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'No records match your selected branch, category, or status query.',
                                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                                ),
                              ],
                            ),
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

  Widget _buildDropdownFilter({
    required double width,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      width: width,
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(12),
          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF0F172A), fontWeight: FontWeight.w600),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B), size: 18),
          items: items,
          onChanged: onChanged,
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
              dataRowMaxHeight: 60,
              headingTextStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 11, color: const Color(0xFFCBD5E1), letterSpacing: 0.6),
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
                DataColumn(label: Text('CUSTOMER NAME')),
                DataColumn(label: Text('PHONE (E.164)')),
                DataColumn(label: Text('BRANCH')),
                DataColumn(label: Text('CATEGORY')),
                DataColumn(label: Text('STATUS')),
                DataColumn(label: Text('ASSIGNED TO')),
                DataColumn(label: Text('ACTIONS')),
              ],
              rows: leads.map((lead) {
                final isSelected = _selectedLeadIds.contains(lead.id);

                Color catColor = const Color(0xFF8B5CF6);
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
                            Container(
                              width: 30,
                              height: 30,
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  lead.fullName.isNotEmpty ? lead.fullName[0].toUpperCase() : 'L',
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 170),
                              child: Text(
                                lead.fullName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: const Color(0xFF0F172A), fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF06B6D4).withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF06B6D4).withValues(alpha: 0.35)),
                        ),
                        child: Text(
                          lead.normalizedPhone,
                          style: GoogleFonts.robotoMono(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF06B6D4)),
                        ),
                      ),
                    ),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.storefront_rounded, size: 14, color: Color(0xFF818CF8)),
                          const SizedBox(width: 6),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 140),
                            child: Text(
                              lead.branchName ?? 'Unassigned Branch',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF64748B),
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
                          color: catColor.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: catColor.withValues(alpha: 0.35)),
                        ),
                        child: Text(
                          lead.categoryName ?? 'General',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: catColor),
                        ),
                      ),
                    ),
                    DataCell(
                      AnimatedStatusBadge(label: lead.status, statusColor: _getStatusColor(lead.status)),
                    ),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            lead.assignedToName != null ? Icons.person_rounded : Icons.person_off_rounded,
                            size: 14,
                            color: lead.assignedToName != null ? const Color(0xFF818CF8) : const Color(0xFF94A3B8),
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
                                fontWeight: FontWeight.w600,
                                color: lead.assignedToName != null ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    DataCell(
                      IconButton(
                        icon: const Icon(Icons.arrow_forward_rounded, size: 18, color: Color(0xFF818CF8)),
                        tooltip: 'View Profile',
                        onPressed: () => _openLeadDetail(lead.id),
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
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final lead = leads[index];
        final isSelected = _selectedLeadIds.contains(lead.id);

        Color catColor = const Color(0xFF8B5CF6);
        if (lead.categoryColor != null) {
          try {
            catColor = Color(int.parse(lead.categoryColor!.replaceAll('#', '0xFF')));
          } catch (_) {}
        }

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF6366F1).withValues(alpha: 0.20)
                : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF6366F1)
                  : Colors.white.withValues(alpha: 0.16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: InkWell(
            onTap: () => _openLeadDetail(lead.id),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          lead.fullName.isNotEmpty ? lead.fullName[0].toUpperCase() : 'L',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lead.fullName,
                            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: const Color(0xFF0F172A)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            lead.normalizedPhone,
                            style: GoogleFonts.robotoMono(fontSize: 11, color: AppColors.neonCyan),
                          ),
                        ],
                      ),
                    ),
                    AnimatedStatusBadge(label: lead.status, statusColor: _getStatusColor(lead.status)),
                  ],
                ),
                const SizedBox(height: 10),
                Divider(color: const Color(0xFFE2E8F0), height: 1),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (lead.branchName != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '📍 ${lead.branchName}',
                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
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
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                      ),
                  ],
                ),
              ],
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
