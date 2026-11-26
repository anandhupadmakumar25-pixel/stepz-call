import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass/glass_scaffold.dart';
import '../../core/widgets/glass/glass_card.dart';
import '../../core/widgets/glass/gradient_button.dart';
import '../../core/widgets/glass/animated_status_badge.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/date_range_filter_bar.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../routes/app_routes.dart';
import '../../providers/lead_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/lead_model.dart';
import 'import_wizard_dialog.dart';
import 'bulk_assign_dialog.dart';
import 'reassign_leads_dialog.dart';
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
  String? _dateFrom;
  String? _dateTo;
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
      search: _searchController.text,
      dateFrom: _dateFrom,
      dateTo: _dateTo,
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Header Bar with Uniform Action Buttons (Flush Left & Right)
            LayoutBuilder(
              builder: (ctx, headerConstraints) {
                final titleBlock = Row(
                  children: [
                    const AppBackButton(fallbackRoute: AppRoutes.dashboard),
                    const SizedBox(width: 12),
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
                              const SizedBox(width: 8),
                              AnimatedStatusBadge(
                                label: '${leadProvider.totalCount} Leads',
                                statusColor: AppColors.neonCyan,
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Manage leads, branch filters, and staff assignment',
                            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                );

                final actionButtons = (!isTelecaller || canCreateLead || canImportLeads || canManageBranches)
                    ? Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (canManageBranches)
                            SizedBox(
                              height: 36,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (_) => const ManageBranchesCategoriesDialog(),
                                  );
                                },
                                icon: const Icon(Icons.storefront_outlined, size: 15, color: Color(0xFF334155)),
                                label: Text('Branches', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF334155))),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                                  backgroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                          if (canImportLeads)
                            SizedBox(
                              height: 36,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (_) => const ImportWizardDialog(),
                                  );
                                },
                                icon: const Icon(Icons.upload_file_rounded, size: 15, color: Color(0xFF1D4ED8)),
                                label: Text(isMobile ? 'Import' : 'Import CSV', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF1D4ED8))),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Color(0xFFBFDBFE)),
                                  backgroundColor: const Color(0xFFEFF6FF),
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                          if (canCreateLead)
                            GradientPrimaryButton(
                              text: 'Add Lead',
                              icon: Icons.add_rounded,
                              height: 36,
                              borderRadius: 10,
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => const AddLeadDialog(),
                                );
                              },
                            ),
                        ],
                      )
                    : null;

                if (!isMobile && headerConstraints.maxWidth >= 720) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(child: titleBlock),
                      if (actionButtons != null) ...[
                        const SizedBox(width: 16),
                        actionButtons,
                      ],
                    ],
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleBlock,
                    if (actionButtons != null) ...[
                      const SizedBox(height: 10),
                      actionButtons,
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 14),

            // Filter & Selection Toolbar Card
            GlassCard(
              blur: 18,
              opacity: 0.96,
              borderRadius: BorderRadius.circular(16),
              borderColor: const Color(0xFFE2E8F0),
              padding: EdgeInsets.all(isMobile ? 12 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DateRangeFilterBar(
                    onChanged: (from, to) {
                      _dateFrom = from;
                      _dateTo = to;
                      _triggerFilter();
                    },
                  ),
                  const SizedBox(height: 10),
                  LayoutBuilder(
                    builder: (ctx, filterConstraints) {
                      final searchField = SizedBox(
                        height: 38,
                        child: TextField(
                          controller: _searchController,
                          onChanged: (_) => _triggerFilter(),
                          style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF0F172A), fontWeight: FontWeight.w500),
                          decoration: InputDecoration(
                            hintText: 'Search name, phone, city...',
                            hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                            prefixIcon: const Icon(Icons.search_rounded, size: 17, color: Color(0xFF64748B)),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
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
                              borderSide: const BorderSide(color: Color(0xFF047857), width: 1.5),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                      );

                      final branchDrop = _buildDropdownFilter(
                        width: double.infinity,
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
                      );

                      final statusDrop = _buildDropdownFilter(
                        width: double.infinity,
                        value: _selectedStatus,
                        items: _statusOptions.map((s) => DropdownMenuItem(value: s, child: Text(s.replaceAll('_', ' '), overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (val) {
                          if (val == null) return;
                          setState(() => _selectedStatus = val);
                          _triggerFilter();
                        },
                      );

                      if (!isMobile && filterConstraints.maxWidth >= 680) {
                        return Row(
                          children: [
                            Expanded(flex: 3, child: searchField),
                            const SizedBox(width: 10),
                            Expanded(flex: 2, child: branchDrop),
                            const SizedBox(width: 10),
                            Expanded(flex: 2, child: statusDrop),
                          ],
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          searchField,
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(child: branchDrop),
                              const SizedBox(width: 8),
                              Expanded(child: statusDrop),
                            ],
                          ),
                        ],
                      );
                    },
                  ),

                  // Selection Action Bar (shown only when leads are checked)
                  if (canAssignLeads && _selectedLeadIds.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Divider(color: Color(0xFFE2E8F0), height: 1),
                    const SizedBox(height: 10),
                    Builder(builder: (_) {
                      final selectedLeads = leadProvider.leads
                          .where((l) => _selectedLeadIds.contains(l.id))
                          .toList();
                      final unassignedIds = selectedLeads
                          .where((l) => l.assignedTo == null || l.assignedTo!.isEmpty)
                          .map((l) => l.id)
                          .toList();
                      final assignedLeads = selectedLeads
                          .where((l) => l.assignedTo != null && l.assignedTo!.isNotEmpty)
                          .toList();

                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '${_selectedLeadIds.length} Selected'
                            '${unassignedIds.isNotEmpty ? " · ${unassignedIds.length} Unassigned" : ""}'
                            '${assignedLeads.isNotEmpty ? " · ${assignedLeads.length} Assigned" : ""}',
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (unassignedIds.isNotEmpty)
                                GradientPrimaryButton(
                                  text: 'Bulk Assign (${unassignedIds.length})',
                                  icon: Icons.assignment_ind_rounded,
                                  gradient: AppColors.sunsetGradient,
                                  height: 34,
                                  borderRadius: 9,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (_) => BulkAssignDialog(selectedLeadIds: unassignedIds),
                                    ).then((_) {
                                      setState(() => _selectedLeadIds.clear());
                                      _triggerFilter();
                                    });
                                  },
                                ),
                              if (assignedLeads.isNotEmpty)
                                GradientPrimaryButton(
                                  text: 'Reassign (${assignedLeads.length})',
                                  icon: Icons.swap_horiz_rounded,
                                  gradient: AppColors.primaryGradient,
                                  height: 34,
                                  borderRadius: 9,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (_) => ReassignLeadsDialog(assignedLeads: assignedLeads),
                                    ).then((res) {
                                      if (res == true) {
                                        setState(() => _selectedLeadIds.clear());
                                        _triggerFilter();
                                      }
                                    });
                                  },
                                ),
                              SizedBox(
                                height: 34,
                                child: TextButton(
                                  onPressed: () => setState(() => _selectedLeadIds.clear()),
                                  child: Text('Clear', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFF64748B))),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    }),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Leads Directory List / Table
            Expanded(
              child: GlassCard(
                blur: 18,
                opacity: 0.96,
                borderRadius: BorderRadius.circular(16),
                borderColor: const Color(0xFFE2E8F0),
                padding: EdgeInsets.all(isMobile ? 10 : 14),
                child: leadProvider.isLoading && leadProvider.leads.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : leadProvider.leads.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.person_off_rounded, size: 46, color: Color(0xFF94A3B8)),
                                const SizedBox(height: 10),
                                Text(
                                  'No Leads Found',
                                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'No records match your selected branch, date, or status filter.',
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

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final tableMinWidth = constraints.maxWidth > 900 ? constraints.maxWidth : 900.0;
        return Scrollbar(
          controller: horizontalScrollController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: horizontalScrollController,
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: tableMinWidth),
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: DataTable(
                  showCheckboxColumn: !isTelecaller,
                  headingRowHeight: 44,
                  dataRowMinHeight: 52,
                  dataRowMaxHeight: 60,
                  headingTextStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 11, color: const Color(0xFF475569), letterSpacing: 0.6),
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
                DataColumn(label: Text('STATUS')),
                DataColumn(label: Text('ASSIGNED TO')),
                DataColumn(label: Text('ACTIONS')),
              ],
              rows: leads.map((lead) {
                final isSelected = _selectedLeadIds.contains(lead.id);

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
                              lead.branchName ?? (lead.assignedToName != null ? 'Main Branch' : '—'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: lead.branchName != null ? const Color(0xFF334155) : const Color(0xFF94A3B8),
                              ),
                            ),
                          ),
                        ],
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
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (lead.assignedTo != null &&
                              lead.assignedTo!.isNotEmpty &&
                              (context.read<AuthProvider>().currentUser?.isCompanyAdmin == true ||
                                  (context.read<AuthProvider>().currentUser?.hasPermission('leads.assign') ?? false)))
                            IconButton(
                              icon: const Icon(Icons.swap_horiz_rounded, size: 18, color: Color(0xFF4338CA)),
                              tooltip: 'Reassign to another employee',
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => ReassignLeadsDialog(assignedLeads: [lead]),
                                ).then((res) {
                                  if (res == true) _triggerFilter();
                                });
                              },
                            ),
                          IconButton(
                            icon: const Icon(Icons.arrow_forward_rounded, size: 18, color: Color(0xFF818CF8)),
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
      },
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

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFFEFF6FF)
                : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF2563EB)
                  : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
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
                    if (lead.assignedToName != null) ...[
                      Text(
                        '👤 ${lead.assignedToName}',
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                      ),
                      if (context.read<AuthProvider>().currentUser?.isCompanyAdmin == true ||
                          (context.read<AuthProvider>().currentUser?.hasPermission('leads.assign') ?? false))
                        InkWell(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (_) => ReassignLeadsDialog(assignedLeads: [lead]),
                            ).then((res) {
                              if (res == true) _triggerFilter();
                            });
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFC7D2FE)),
                            ),
                            child: Text(
                              'Reassign',
                              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF4338CA)),
                            ),
                          ),
                        ),
                    ],
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
