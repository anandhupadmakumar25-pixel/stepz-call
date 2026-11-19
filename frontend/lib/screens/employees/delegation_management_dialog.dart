import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/employee_provider.dart';
import '../../providers/role_provider.dart';

class DelegationManagementDialog extends StatefulWidget {
  const DelegationManagementDialog({super.key});

  @override
  State<DelegationManagementDialog> createState() => _DelegationManagementDialogState();
}

class _DelegationManagementDialogState extends State<DelegationManagementDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final roleProv = context.read<RoleProvider>();
      roleProv.fetchPermissionCatalog();
      roleProv.fetchDelegations();
      roleProv.fetchAuditLogs();
      context.read<EmployeeProvider>().fetchEmployees();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openCreateDelegationDialog() {
    final roleProv = context.read<RoleProvider>();
    final empProv = context.read<EmployeeProvider>();
    final currentUser = context.read<AuthProvider>().currentUser;
    final eligibleStaff = empProv.employees
        .where((e) => e.isActive && e.id != currentUser?.id)
        .toList();

    String? selectedEmployeeId = eligibleStaff.isNotEmpty ? eligibleStaff.first.id : null;
    final titleCtrl = TextEditingController(text: 'Acting In-Charge');
    final reasonCtrl = TextEditingController();
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now().add(const Duration(days: 3));
    final Set<String> selectedSections = {};
    final Set<String> selectedPerms = {};
    String? errorText;
    bool submitting = false;

    String fmtDate(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 660, maxHeight: 760),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEDE9FE),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.assignment_ind_rounded, color: Color(0xFF6D28D9), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Delegate Sections (Acting In-Charge)',
                              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                            ),
                            Text(
                              'Temporarily assign sections to an employee while you are on leave',
                              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (errorText != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Text(errorText!, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFB91C1C), fontWeight: FontWeight.w600)),
                    ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Assign To Employee *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF334155))),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            initialValue: selectedEmployeeId,
                            decoration: InputDecoration(
                              isDense: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            items: eligibleStaff.map<DropdownMenuItem<String>>((e) {
                              return DropdownMenuItem<String>(
                                value: e.id,
                                child: Text('${e.fullName} (${e.role})', style: GoogleFonts.inter(fontSize: 13)),
                              );
                            }).toList(),
                            onChanged: (v) => setDlgState(() => selectedEmployeeId = v),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Delegation Title', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF334155))),
                                    const SizedBox(height: 6),
                                    TextField(
                                      controller: titleCtrl,
                                      decoration: InputDecoration(
                                        isDense: true,
                                        hintText: 'e.g. Acting Billing & Leave In-Charge',
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Reason / Leave Note', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF334155))),
                                    const SizedBox(height: 6),
                                    TextField(
                                      controller: reasonCtrl,
                                      decoration: InputDecoration(
                                        isDense: true,
                                        hintText: 'e.g. Annual Leave',
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.calendar_today, size: 15),
                                  label: Text('From: ${fmtDate(startDate)}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                                  onPressed: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: startDate,
                                      firstDate: DateTime.now().subtract(const Duration(days: 1)),
                                      lastDate: DateTime.now().add(const Duration(days: 365)),
                                    );
                                    if (picked != null) {
                                      setDlgState(() {
                                        startDate = picked;
                                        if (endDate.isBefore(startDate)) endDate = startDate;
                                      });
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.event, size: 15),
                                  label: Text('Until: ${fmtDate(endDate)}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                                  onPressed: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: endDate.isBefore(startDate) ? startDate : endDate,
                                      firstDate: startDate,
                                      lastDate: DateTime.now().add(const Duration(days: 365)),
                                    );
                                    if (picked != null) setDlgState(() => endDate = picked);
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Select Sections & Permissions to Delegate *',
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 8),
                          ...roleProv.permissionCatalog.map((grp) {
                            final grpKeys = grp.permissions.map((p) => p.key).toSet();
                            final allSelected = grpKeys.isNotEmpty && grpKeys.every(selectedPerms.contains);
                            final someSelected = grpKeys.any(selectedPerms.contains);
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: someSelected ? const Color(0xFFF5F3FF) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: someSelected ? const Color(0xFFC4B5FD) : const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(grp.label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B))),
                                      TextButton(
                                        onPressed: () {
                                          setDlgState(() {
                                            if (allSelected) {
                                              selectedSections.remove(grp.key);
                                              selectedPerms.removeAll(grpKeys);
                                            } else {
                                              selectedSections.add(grp.key);
                                              selectedPerms.addAll(grpKeys);
                                            }
                                          });
                                        },
                                        child: Text(allSelected ? 'Deselect Section' : 'Select All', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700)),
                                      ),
                                    ],
                                  ),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: grp.permissions.map((p) {
                                      final checked = selectedPerms.contains(p.key);
                                      return FilterChip(
                                        selected: checked,
                                        label: Text(
                                          p.label,
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: checked ? FontWeight.w700 : FontWeight.w500,
                                            color: checked ? const Color(0xFF4C1D95) : const Color(0xFF1E293B),
                                          ),
                                        ),
                                        selectedColor: const Color(0xFFDDD6FE),
                                        onSelected: (val) {
                                          setDlgState(() {
                                            if (val) {
                                              selectedPerms.add(p.key);
                                              selectedSections.add(grp.key);
                                            } else {
                                              selectedPerms.remove(p.key);
                                              if (!grpKeys.any(selectedPerms.contains)) {
                                                selectedSections.remove(grp.key);
                                              }
                                            }
                                          });
                                        },
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6D28D9),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        ),
                        icon: submitting
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.check_circle_outline, size: 17),
                        label: const Text('Activate Delegation'),
                        onPressed: submitting
                            ? null
                            : () async {
                                if (selectedEmployeeId == null) {
                                  setDlgState(() => errorText = 'Please select an employee.');
                                  return;
                                }
                                if (selectedPerms.isEmpty) {
                                  setDlgState(() => errorText = 'Please select at least one section or permission.');
                                  return;
                                }
                                setDlgState(() {
                                  submitting = true;
                                  errorText = null;
                                });
                                final created = await roleProv.createDelegation(
                                  delegateeId: selectedEmployeeId!,
                                  title: titleCtrl.text.isEmpty ? 'Acting In-Charge' : titleCtrl.text,
                                  sections: selectedSections.toList(),
                                  permissions: selectedPerms.toList(),
                                  startDate: fmtDate(startDate),
                                  endDate: fmtDate(endDate),
                                  reason: reasonCtrl.text,
                                );
                                if (created != null && ctx.mounted) {
                                  roleProv.fetchAuditLogs();
                                  Navigator.pop(ctx);
                                } else {
                                  setDlgState(() {
                                    submitting = false;
                                    errorText = roleProv.errorMessage ?? 'Failed to create delegation.';
                                  });
                                }
                              },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final roleProv = context.watch<RoleProvider>();
    final canManage = context.watch<AuthProvider>().currentUser?.hasPermission('delegation.manage') ?? false;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 720),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                borderRadius: BorderRadius.only(topLeft: Radius.circular(18), topRight: Radius.circular(18)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.assignment_ind_rounded, color: Color(0xFFA78BFA), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Section Delegation & Security Audit',
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          'Assign temporary section ownership while on leave with automatic expiry',
                          style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  if (canManage)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _openCreateDelegationDialog,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('New Delegation'),
                    ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF6D28D9),
              unselectedLabelColor: const Color(0xFF64748B),
              indicatorColor: const Color(0xFF6D28D9),
              tabs: [
                Tab(text: 'Delegations (${roleProv.delegations.length})'),
                Tab(text: 'Audit Trail (${roleProv.auditLogs.length})'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildDelegationsList(roleProv, canManage),
                  _buildAuditLogList(roleProv),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDelegationsList(RoleProvider roleProv, bool canManage) {
    if (roleProv.isLoading && roleProv.delegations.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (roleProv.delegations.isEmpty) {
      return Center(
        child: Text(
          'No section delegations yet.\nUse "New Delegation" to assign sections while on leave.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 13),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: roleProv.delegations.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final d = roleProv.delegations[i];
        final statusColor = d.isCurrentlyEffective
            ? const Color(0xFF059669)
            : (d.isActive ? const Color(0xFFD97706) : const Color(0xFF64748B));
        final statusLabel = d.isCurrentlyEffective
            ? 'ACTIVE NOW'
            : (d.isActive ? 'SCHEDULED / ENDED' : 'REVOKED');

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(statusLabel, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: statusColor)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            d.title.isNotEmpty ? d.title : 'Acting In-Charge',
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${d.delegatorName}  →  ${d.delegateeName}   |   ${d.startDate} to ${d.endDate}',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sections: ${d.sections.join(", ")} (${d.permissions.length} permissions)${d.reason.isNotEmpty ? " · Note: ${d.reason}" : ""}',
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              if (canManage && d.isActive)
                OutlinedButton(
                  style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
                  onPressed: () async {
                    final ok = await roleProv.revokeDelegation(d.id);
                    if (ok) roleProv.fetchAuditLogs();
                  },
                  child: const Text('Revoke'),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAuditLogList(RoleProvider roleProv) {
    if (roleProv.auditLogs.isEmpty) {
      return Center(
        child: Text('No security audit events recorded yet.', style: GoogleFonts.inter(color: const Color(0xFF64748B))),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: roleProv.auditLogs.length,
      separatorBuilder: (_, __) => const Divider(height: 16),
      itemBuilder: (ctx, i) {
        final log = roleProv.auditLogs[i];
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.verified_user_outlined, size: 18, color: Color(0xFF475569)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${log.action} · ${log.actorName}',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                  ),
                  Text(
                    '${log.details} · ${log.createdAt.length >= 19 ? log.createdAt.substring(0, 19).replaceFirst("T", " ") : log.createdAt}',
                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

