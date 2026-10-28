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

class LeadDirectoryScreen extends StatefulWidget {
  const LeadDirectoryScreen({super.key});

  @override
  State<LeadDirectoryScreen> createState() => _LeadDirectoryScreenState();
}

class _LeadDirectoryScreenState extends State<LeadDirectoryScreen> {
  final _searchController = TextEditingController();
  String _selectedStatus = 'ALL';
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
      context.read<LeadProvider>().fetchLeads();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    context.read<LeadProvider>().fetchLeads(
      status: _selectedStatus,
      search: query,
    );
  }

  void _onStatusChanged(String? status) {
    if (status == null) return;
    setState(() => _selectedStatus = status);
    context.read<LeadProvider>().fetchLeads(
      status: status,
      search: _searchController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final leadProvider = context.watch<LeadProvider>();
    final auth = context.watch<AuthProvider>();
    final isTelecaller = auth.currentUser?.isEmployee ?? true;
    final isMobile = ResponsiveLayout.isMobile(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Top Toolbar & Action Buttons
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Search Bar
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: _onSearchChanged,
                            decoration: InputDecoration(
                              hintText: 'Search by name, phone, city...',
                              prefixIcon: const Icon(Icons.search, size: 18),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 16),
                                      onPressed: () {
                                        _searchController.clear();
                                        _onSearchChanged('');
                                      },
                                    )
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Status Filter
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
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
                                  child: Text(st.replaceAll('_', ' '), style: GoogleFonts.inter(fontSize: 13)),
                                );
                              }).toList(),
                              onChanged: _onStatusChanged,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Admin Actions (Bulk Assign, Import Wizard, Add Lead)
                    if (!isTelecaller) ...[
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${_selectedLeadIds.length} leads selected',
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                              ),
                              if (_selectedLeadIds.isNotEmpty) ...[
                                const SizedBox(width: 10),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentViolet),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (_) => BulkAssignDialog(selectedLeadIds: _selectedLeadIds.toList()),
                                    );
                                  },
                                  icon: const Icon(Icons.assignment_ind, size: 16),
                                  label: const Text('Bulk Assign'),
                                ),
                              ],
                            ],
                          ),
                          Row(
                            children: [
                              OutlinedButton.icon(
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (_) => const ImportWizardDialog(),
                                  );
                                },
                                icon: const Icon(Icons.upload_file, size: 16),
                                label: const Text('Import Excel / CSV'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (_) => const AddLeadDialog(),
                                  );
                                },
                                icon: const Icon(Icons.add, size: 16),
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
            const SizedBox(height: 16),

            // Lead List / Table
            Expanded(
              child: Card(
                child: leadProvider.isLoading && leadProvider.leads.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : leadProvider.leads.isEmpty
                        ? EmptyState(
                            icon: Icons.person_off_outlined,
                            title: 'No leads found',
                            description: 'No leads match your current search and status filters.',
                            actionLabel: !isTelecaller ? 'Import Leads' : null,
                            onAction: () {
                              showDialog(
                                context: context,
                                builder: (_) => const ImportWizardDialog(),
                              );
                            },
                          )
                        : isMobile
                            ? _buildMobileList(leadProvider.leads)
                            : _buildDataTable(leadProvider.leads, isTelecaller),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataTable(List<LeadModel> leads, bool isTelecaller) {
    return SingleChildScrollView(
      child: DataTable(
        showCheckboxColumn: !isTelecaller,
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
          DataColumn(label: Text('Customer Name')),
          DataColumn(label: Text('Phone (E.164)')),
          DataColumn(label: Text('City')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Assigned Telecaller')),
          DataColumn(label: Text('Action')),
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
                  child: Text(
                    lead.fullName,
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.accentViolet),
                  ),
                ),
              ),
              DataCell(Text(lead.normalizedPhone, style: const TextStyle(fontFamily: 'monospace', fontSize: 12))),
              DataCell(Text(lead.city.isNotEmpty ? lead.city : '—')),
              DataCell(StatusBadge(status: lead.status)),
              DataCell(Text(lead.assignedToName ?? 'Unassigned', style: GoogleFonts.inter(fontSize: 12))),
              DataCell(
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios, size: 14),
                  onPressed: () => _openLeadDetail(lead.id),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMobileList(List<LeadModel> leads) {
    return ListView.separated(
      itemCount: leads.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final lead = leads[index];
        return ListTile(
          onTap: () => _openLeadDetail(lead.id),
          title: Text(lead.fullName, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
          subtitle: Text('${lead.normalizedPhone} • ${lead.city}', style: GoogleFonts.inter(fontSize: 12)),
          trailing: StatusBadge(status: lead.status),
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
