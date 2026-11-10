import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass/glass_card.dart';
import '../../core/widgets/glass/gradient_button.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/lead_provider.dart';
import '../../providers/employee_provider.dart';
import '../../models/lead_model.dart';
import '../../models/dashboard_model.dart';
import '../leads/import_wizard_dialog.dart';
import '../leads/add_lead_dialog.dart';
import '../branches/branch_management_screen.dart';
import '../employees/employee_management_screen.dart';
import '../employees/employee_activity_detail_dialog.dart';
import '../../providers/billing_provider.dart';
import '../../routes/app_routes.dart';
import '../quotations/quotation_form_dialog.dart';
import '../leads/bulk_assign_dialog.dart';

class CompanyAdminDashboardScreen extends StatefulWidget {
  const CompanyAdminDashboardScreen({super.key});

  @override
  State<CompanyAdminDashboardScreen> createState() => _CompanyAdminDashboardScreenState();
}

class _CompanyAdminDashboardScreenState extends State<CompanyAdminDashboardScreen> {
  String _teamSearchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().fetchAdminDashboard();
      context.read<LeadProvider>().fetchBranches();
      context.read<LeadProvider>().fetchCategories();
      context.read<EmployeeProvider>().fetchEmployees();
      context.read<BillingProvider>().fetchBillingOverview();
    });
  }

  void _showAddBranchDialog() {
    final authUser = context.read<AuthProvider>().currentUser;
    final canAddBranch = authUser?.canManageBranches ?? (authUser?.hasMenuPermission('branches') ?? false);
    if (!canAddBranch) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Branch management is locked for your company. Super Admin permission required.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final addressCtrl = TextEditingController();

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (ctx) {
        final isMobile = ResponsiveLayout.isMobile(ctx);
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: isMobile ? 16 : 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: GlassCard(
              blur: 24,
              opacity: 0.96,
              borderRadius: BorderRadius.circular(20),
              padding: EdgeInsets.all(isMobile ? 18 : 28),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF06B6D4).withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.storefront_rounded, color: Color(0xFF06B6D4), size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Add Company Branch',
                            style: GoogleFonts.inter(fontSize: isMobile ? 16 : 18, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                          ),
                        ),
                        DialogCloseButton(onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: nameCtrl,
                      style: GoogleFonts.inter(color: const Color(0xFF0F172A), fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Branch Name *',
                        labelStyle: GoogleFonts.inter(color: const Color(0xFF64748B)),
                        hintText: 'e.g. Downtown Regional Branch',
                        hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: codeCtrl,
                      style: GoogleFonts.inter(color: const Color(0xFF0F172A), fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Branch Code',
                        labelStyle: GoogleFonts.inter(color: const Color(0xFF64748B)),
                        hintText: 'e.g. BR-HQ-01',
                        hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: addressCtrl,
                      style: GoogleFonts.inter(color: const Color(0xFF0F172A), fontSize: 13),
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Branch Location / Address',
                        labelStyle: GoogleFonts.inter(color: const Color(0xFF64748B)),
                        hintText: 'Physical address or territory notes',
                        hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.only(top: 14),
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: Color(0x33D4AF37), width: 1.0)),
                      ),
                      child: Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          GlassSecondaryButton(
                            text: 'Cancel',
                            onPressed: () => Navigator.pop(ctx),
                          ),
                          GradientPrimaryButton(
                            text: 'Create Branch',
                            icon: Icons.check_rounded,
                            onPressed: () async {
                              if (nameCtrl.text.trim().isEmpty) return;
                              final messenger = ScaffoldMessenger.of(context);
                              final nav = Navigator.of(ctx);
                              final branchName = nameCtrl.text.trim();
                              final ok = await context.read<LeadProvider>().createBranch(
                                name: branchName,
                                code: codeCtrl.text.trim(),
                                address: addressCtrl.text.trim(),
                              );
                              nav.pop();
                              if (ok) {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text('Branch "$branchName" created successfully!'),
                                    backgroundColor: const Color(0xFF10B981),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final dash = context.watch<DashboardProvider>();
    final leadP = context.watch<LeadProvider>();
    final kpis = dash.adminKpis;
    final branches = leadP.branches;
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final isMobile = ResponsiveLayout.isMobile(context);

    final companyName = user?.companyName ?? 'Acme Telecallers Corp';
    final branchCount = branches.length;
    final activeAgents = kpis.totalEmployees > 0 ? kpis.totalEmployees : dash.employeePerformance.length;
    final canManageBranches = user?.canManageBranches ?? (user?.hasMenuPermission('branches') ?? false);

    return RefreshIndicator(
      color: const Color(0xFF06B6D4),
      onRefresh: () async {
        await Future.wait([
          context.read<DashboardProvider>().fetchAdminDashboard(),
          context.read<LeadProvider>().fetchBranches(),
          context.read<EmployeeProvider>().fetchEmployees(),
          context.read<BillingProvider>().fetchBillingOverview(),
        ]);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          isMobile ? 12 : 24,
          isMobile ? 8 : 18,
          isMobile ? 12 : 24,
          isMobile ? 16 : 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. EXECUTIVE COMMAND HEADER
            _buildCompanyWorkspaceHeader(
              companyName: companyName,
              userFullName: user?.fullName ?? 'Company Admin',
              branchCount: branchCount,
              agentCount: activeAgents,
              isDesktop: isDesktop,
              isMobile: isMobile,
              canManageBranches: canManageBranches,
            ),
            const SizedBox(height: 20),

            // 2. UNIFIED OPERATIONAL KPI DECK
            _buildCompanyStatCards(kpis, isDesktop),
            const SizedBox(height: 20),

            // 3. SALES & BILLING REVENUE PIPELINE
            _buildSalesAndBillingSection(context, isDesktop),
            const SizedBox(height: 20),

            // 4. BRANCHES & CALLING DESKS (IF PERMISSIONED)
            if (canManageBranches) ...[
              _buildCompanyBranchesSection(branches, isDesktop),
              const SizedBox(height: 20),
            ],

            // 5. LIVE FLOOR TELECALLER TEAM PERFORMANCE & OUTCOMES RADAR
            if (isDesktop)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 7, child: _buildTeamPerformanceTable(dash.employeePerformance)),
                  const SizedBox(width: 18),
                  Expanded(flex: 5, child: _buildCompanyCallOutcomesCard(dash.outcomeCounts)),
                ],
              )
            else ...[
              _buildTeamPerformanceTable(dash.employeePerformance),
              const SizedBox(height: 18),
              _buildCompanyCallOutcomesCard(dash.outcomeCounts),
            ],
            const SizedBox(height: 20),

            // 6. CALL VOLUME VELOCITY TREND
            _buildCallingTimelineSection(dash.activityTimeline, isDesktop),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 1. EXECUTIVE COMMAND HEADER
  // ==========================================
  Widget _buildCompanyWorkspaceHeader({
    required String companyName,
    required String userFullName,
    required int branchCount,
    required int agentCount,
    required bool isDesktop,
    required bool isMobile,
    required bool canManageBranches,
  }) {
    return GlassCard(
      padding: EdgeInsets.all(isMobile ? 16 : 22),
      borderRadius: BorderRadius.circular(20),
      borderColor: const Color(0xFFE2E8F0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: isMobile ? 48 : 56,
                height: isMobile ? 48 : 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F766E), Color(0xFF0D9488), Color(0xFF14B8A6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0D9488).withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(Icons.corporate_fare_rounded, color: Colors.white, size: 28),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          companyName,
                          style: GoogleFonts.inter(
                            fontSize: isMobile ? 18 : 22,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                            letterSpacing: -0.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF047857).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF047857).withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            'ENTERPRISE CONTROL CENTER',
                            style: GoogleFonts.inter(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF047857),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Signed in as $userFullName · Real-time operational monitoring & sales management',
                      style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFFE2E8F0), height: 1),
          const SizedBox(height: 14),

          // Operational Status Badges & Quick Action Command Bar
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Agent Count Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.headset_mic_rounded, size: 15, color: Color(0xFF047857)),
                    const SizedBox(width: 6),
                    Text(
                      '$agentCount Active Telecallers',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                    ),
                  ],
                ),
              ),
              // Branch Count Badge
              if (canManageBranches)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.storefront_rounded, size: 15, color: Color(0xFF0284C7)),
                      const SizedBox(width: 6),
                      Text(
                        '$branchCount Calling Branches',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                ),

              // Button: + Add Lead (Prominent)
              ElevatedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => const AddLeadDialog(),
                  );
                },
                icon: const Icon(Icons.person_add_rounded, size: 16),
                label: Text('Add Lead', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF047857),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              ),

              // Button: ⚡ Bulk Assign
              OutlinedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => const BulkAssignDialog(selectedLeadIds: []),
                  );
                },
                icon: const Icon(Icons.bolt_rounded, size: 16, color: Color(0xFF7C3AED)),
                label: Text('Bulk Assign', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF6D28D9))),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFDDD6FE), width: 1.0),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  backgroundColor: const Color(0xFFF5F3FF),
                ),
              ),

              // Button: 📥 Import Leads CSV
              OutlinedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => const ImportWizardDialog(),
                  );
                },
                icon: const Icon(Icons.upload_file_rounded, size: 16, color: Color(0xFF2563EB)),
                label: Text('Import CSV', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF1D4ED8))),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFBFDBFE), width: 1.0),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  backgroundColor: const Color(0xFFEFF6FF),
                ),
              ),

              // Button: 📄 New Quotation
              OutlinedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => const QuotationFormDialog(),
                  );
                },
                icon: const Icon(Icons.request_quote_rounded, size: 16, color: Color(0xFF059669)),
                label: Text('New Quotation', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF047857))),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFA7F3D0), width: 1.0),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  backgroundColor: const Color(0xFFECFDF5),
                ),
              ),

              // Button: 💳 Invoices & Billing
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, AppRoutes.billing);
                },
                icon: const Icon(Icons.receipt_long_rounded, size: 16, color: Color(0xFF0284C7)),
                label: Text('Invoices & Billing', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0369A1))),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFBAE6FD), width: 1.0),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  backgroundColor: const Color(0xFFF0F9FF),
                ),
              ),

              // Button: Add Branch (If permissioned)
              if (canManageBranches)
                OutlinedButton.icon(
                  onPressed: _showAddBranchDialog,
                  icon: const Icon(Icons.add_business_rounded, size: 16, color: Color(0xFF0D9488)),
                  label: Text('Add Branch', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0F766E))),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF99F6E4), width: 1.0),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    backgroundColor: const Color(0xFFF0FDFA),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 2. 4 CORE OPERATIONAL METRIC STAT CARDS
  // ==========================================
  Widget _buildCompanyStatCards(DashboardKpis kpis, bool isDesktop) {
    final cards = [
      _buildSingleStatCard(
        title: 'Total Company Leads',
        value: '${kpis.totalRegisteredLeads}',
        subtitle: '${kpis.assignedLeads} assigned · ${kpis.unassignedLeads} in pool',
        icon: Icons.groups_rounded,
        gradient: const [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
        badgeText: '+${kpis.newlyImportedLeads} new',
        badgeColor: const Color(0xFF0284C7),
      ),
      _buildSingleStatCard(
        title: 'Calls Dialed Today',
        value: '${kpis.callsLoggedToday}',
        subtitle: '${kpis.callsLoggedTotal} company total dials',
        icon: Icons.phone_in_talk_rounded,
        gradient: const [Color(0xFF06B6D4), Color(0xFF0284C7)],
        badgeText: 'Active Today',
        badgeColor: const Color(0xFF10B981),
      ),
      _buildSingleStatCard(
        title: 'Won / Converted Leads',
        value: '${kpis.completedLeads}',
        subtitle: 'Successfully closed sales deals',
        icon: Icons.verified_rounded,
        gradient: const [Color(0xFF10B981), Color(0xFF047857)],
        badgeText: 'Converted',
        badgeColor: const Color(0xFF047857),
      ),
      _buildSingleStatCard(
        title: 'Scheduled Callbacks',
        value: '${kpis.scheduledCallbacks}',
        subtitle: '${kpis.completedCallbacks} closed · ${kpis.overdueCallbacks} overdue',
        icon: Icons.event_available_rounded,
        gradient: const [Color(0xFFF59E0B), Color(0xFFD97706)],
        badgeText: kpis.overdueCallbacks > 0 ? '${kpis.overdueCallbacks} Overdue' : 'On Track',
        badgeColor: kpis.overdueCallbacks > 0 ? const Color(0xFFDC2626) : const Color(0xFFD97706),
      ),
    ];

    if (isDesktop) {
      return Row(
        children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 5), child: c))).toList(),
      );
    } else {
      return Column(
        children: cards.map((c) => Padding(padding: const EdgeInsets.only(bottom: 12), child: c)).toList(),
      );
    }
  }

  Widget _buildSingleStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required List<Color> gradient,
    required String badgeText,
    required Color badgeColor,
  }) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      borderRadius: BorderRadius.circular(18),
      borderColor: const Color(0xFFE2E8F0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: gradient),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(color: gradient.first.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 3)),
                  ],
                ),
                child: Center(child: Icon(icon, color: Colors.white, size: 20)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  badgeText,
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: badgeColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A), letterSpacing: -0.5),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 3. SALES & BILLING PIPELINE
  // ==========================================
  Widget _buildSalesAndBillingSection(BuildContext context, bool isDesktop) {
    final billing = context.watch<BillingProvider>();
    final kpi = billing.billingOverview;

    return GlassCard(
      blur: 20,
      opacity: 0.95,
      borderRadius: BorderRadius.circular(20),
      borderColor: const Color(0xFFE2E8F0),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF059669), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sales & Revenue Pipeline',
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                      ),
                      Text(
                        'Quotations sent, billed revenue, collections & receivables',
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      side: const BorderSide(color: Color(0xFF059669)),
                      backgroundColor: const Color(0xFFECFDF5),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 16, color: Color(0xFF059669)),
                    label: Text('Create Quotation', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF059669))),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => const QuotationFormDialog(),
                      );
                    },
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 15),
                    label: Text('Invoices Ledger', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700)),
                    onPressed: () => Navigator.pushNamed(context, AppRoutes.billing),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(color: Color(0xFFF1F5F9), height: 1),
          const SizedBox(height: 18),

          Wrap(
            spacing: 16,
            runSpacing: 14,
            children: [
              _buildPipelineStatCard(
                title: 'Active Quotations',
                value: '₹${(kpi?.totalQuotationValue ?? 0.0).toStringAsFixed(2)}',
                subtitle: '${kpi?.quotationCount ?? 0} estimates generated',
                icon: Icons.request_quote_rounded,
                accentColor: const Color(0xFF8B5CF6),
                bgColor: const Color(0xFFF5F3FF),
              ),
              _buildPipelineStatCard(
                title: 'Total Invoiced',
                value: '₹${(kpi?.totalBilled ?? 0.0).toStringAsFixed(2)}',
                subtitle: '${kpi?.invoiceCount ?? 0} invoices billed',
                icon: Icons.receipt_rounded,
                accentColor: const Color(0xFF2563EB),
                bgColor: const Color(0xFFEFF6FF),
              ),
              _buildPipelineStatCard(
                title: 'Collected Revenue',
                value: '₹${(kpi?.totalCollected ?? 0.0).toStringAsFixed(2)}',
                subtitle: '${kpi?.paidInvoiceCount ?? 0} fully cleared',
                icon: Icons.check_circle_rounded,
                accentColor: const Color(0xFF10B981),
                bgColor: const Color(0xFFECFDF5),
              ),
              _buildPipelineStatCard(
                title: 'Pending Receivables',
                value: '₹${(kpi?.pendingReceivables ?? 0.0).toStringAsFixed(2)}',
                subtitle: '${kpi?.pendingInvoiceCount ?? 0} bills pending payment',
                icon: Icons.hourglass_top_rounded,
                accentColor: (kpi?.pendingReceivables ?? 0.0) > 0 ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                bgColor: (kpi?.pendingReceivables ?? 0.0) > 0 ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPipelineStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required Color bgColor,
  }) {
    return Container(
      width: 230,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF475569))),
              Icon(icon, size: 18, color: accentColor),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: GoogleFonts.robotoMono(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
          const SizedBox(height: 4),
          Text(subtitle, style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B))),
        ],
      ),
    );
  }

  // ==========================================
  // 4. TELECALLER TEAM PERFORMANCE TABLE
  // ==========================================
  Widget _buildTeamPerformanceTable(List<dynamic> employees) {
    final isMobile = MediaQuery.of(context).size.width < 650;

    final filtered = employees.where((emp) {
      if (_teamSearchQuery.isEmpty) return true;
      final query = _teamSearchQuery.toLowerCase();
      final name = (emp.name ?? '').toString().toLowerCase();
      final email = (emp.email ?? '').toString().toLowerCase();
      return name.contains(query) || email.contains(query);
    }).toList();

    return GlassCard(
      padding: EdgeInsets.all(isMobile ? 16 : 22),
      borderRadius: BorderRadius.circular(20),
      borderColor: const Color(0xFFE2E8F0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.leaderboard_rounded, color: Color(0xFF047857), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Telecaller Team Performance',
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                      ),
                      Text(
                        'Daily dials, win rates & 1-tap live task audit',
                        style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const EmployeeManagementScreen()),
                  );
                },
                icon: const Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF047857)),
                label: Text('Manage Team', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF047857))),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Team Search Filter
          TextField(
            onChanged: (val) => setState(() => _teamSearchQuery = val.trim()),
            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF0F172A)),
            decoration: InputDecoration(
              hintText: 'Search telecaller by name or email...',
              hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 12),
              prefixIcon: const Icon(Icons.search_rounded, size: 16, color: Color(0xFF64748B)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            ),
          ),
          const SizedBox(height: 14),

          if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Center(
                child: Text('No telecaller records found matching search', style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 13)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.take(6).length,
              separatorBuilder: (_, __) => const Divider(color: Color(0xFFE2E8F0), height: 16),
              itemBuilder: (ctx, i) {
                final emp = filtered[i];
                final callsToday = emp.callsToday as int? ?? 0;
                final dailyTarget = emp.dailyTarget as int? ?? 50;
                final pct = dailyTarget > 0 ? (callsToday / dailyTarget).clamp(0.0, 1.0) : 0.0;
                final empId = emp.employeeId ?? '';

                void openActivity() {
                  showDialog(
                    context: context,
                    builder: (_) => EmployeeActivityDetailDialog(
                      employee: {
                        'id': empId,
                        'first_name': emp.name,
                        'email': emp.email,
                        'calls_today': callsToday,
                        'daily_target': dailyTarget,
                        'completed_leads': emp.completedLeads,
                      },
                    ),
                  );
                }

                return InkWell(
                  onTap: openActivity,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: isMobile
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 17,
                                    backgroundColor: const Color(0xFF047857),
                                    child: Text(
                                      emp.name.isNotEmpty ? emp.name[0].toUpperCase() : 'A',
                                      style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 13),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(emp.name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)), maxLines: 1, overflow: TextOverflow.ellipsis),
                                        Text(emp.email, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '${emp.completedLeads} Won',
                                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF047857)),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('$callsToday / $dailyTarget calls (${(pct * 100).toInt()}%)', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF047857))),
                                  Text('Tasks & Activity →', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF2563EB))),
                                ],
                              ),
                              const SizedBox(height: 4),
                              LinearProgressIndicator(
                                value: pct,
                                backgroundColor: const Color(0xFFE2E8F0),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  pct >= 1.0 ? const Color(0xFF047857) : const Color(0xFF0284C7),
                                ),
                                minHeight: 5,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: const Color(0xFF047857),
                                child: Text(
                                  emp.name.isNotEmpty ? emp.name[0].toUpperCase() : 'A',
                                  style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 13),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(emp.name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                                    Text(emp.email, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Dial Target', style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B))),
                                        Text('$callsToday / $dailyTarget (${(pct * 100).toInt()}%)', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF047857))),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    LinearProgressIndicator(
                                      value: pct,
                                      backgroundColor: const Color(0xFFE2E8F0),
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        pct >= 1.0 ? const Color(0xFF047857) : const Color(0xFF0284C7),
                                      ),
                                      minHeight: 5,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 14),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${emp.completedLeads} Won',
                                  style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: const Color(0xFF047857)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              OutlinedButton.icon(
                                onPressed: openActivity,
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  side: const BorderSide(color: Color(0xFFBFDBFE)),
                                  backgroundColor: const Color(0xFFEFF6FF),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.analytics_outlined, size: 13, color: Color(0xFF1D4ED8)),
                                label: Text(
                                  'Activity',
                                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF1D4ED8)),
                                ),
                              ),
                            ],
                          ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ==========================================
  // 5. CALL OUTCOMES DISTRIBUTION
  // ==========================================
  Widget _buildCompanyCallOutcomesCard(List<dynamic> outcomes) {
    int totalDials = 0;
    for (var o in outcomes) {
      totalDials += (o['count'] ?? 0) as int;
    }

    return GlassCard(
      padding: const EdgeInsets.all(22),
      borderRadius: BorderRadius.circular(20),
      borderColor: const Color(0xFFE2E8F0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.pie_chart_rounded, color: Color(0xFFD97706), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Call Outcomes Distribution',
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                    ),
                    Text(
                      totalDials > 0 ? '$totalDials total outbound call dispositions' : 'Company telecalling dispositions',
                      style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (outcomes.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Center(
                child: Text('No call disposition records yet', style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 13)),
              ),
            )
          else
            Column(
              children: outcomes.map((o) {
                final outcomeName = (o['outcome'] ?? 'UNKNOWN').toString().replaceAll('_', ' ');
                final count = (o['count'] ?? 0) as int;
                final color = _getOutcomeColor(o['outcome']?.toString() ?? '');
                final ratio = totalDials > 0 ? (count / totalDials) : 0.0;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              outcomeName,
                              style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                            ),
                          ),
                          Text(
                            '$count dials (${(ratio * 100).toStringAsFixed(0)}%)',
                            style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: color),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: ratio,
                          backgroundColor: const Color(0xFFF1F5F9),
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                          minHeight: 4,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Color _getOutcomeColor(String outcome) {
    switch (outcome.toUpperCase()) {
      case 'INTERESTED':
        return const Color(0xFF047857);
      case 'CALLBACK_REQUESTED':
      case 'CALLBACK':
        return const Color(0xFFD97706);
      case 'NOT_INTERESTED':
        return const Color(0xFFDC2626);
      case 'BUSY':
      case 'NO_ANSWER':
        return const Color(0xFF0284C7);
      case 'WRONG_NUMBER':
      case 'INVALID':
        return const Color(0xFF64748B);
      default:
        return const Color(0xFF7C3AED);
    }
  }

  // ==========================================
  // 6. CALLING ACTIVITY TIMELINE (LAST 7 DAYS)
  // ==========================================
  Widget _buildCallingTimelineSection(List<dynamic> timeline, bool isDesktop) {
    return GlassCard(
      padding: const EdgeInsets.all(22),
      borderRadius: BorderRadius.circular(20),
      borderColor: const Color(0xFFE2E8F0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF047857).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.bar_chart_rounded, color: Color(0xFF047857), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Weekly Call Volume Trend',
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                    ),
                    Text(
                      'Daily outbound telecalling volume across all company desks',
                      style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (timeline.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Center(
                child: Text('Activity data is generating...', style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 13)),
              ),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: timeline.map((item) {
                final day = item['day'] ?? '';
                final calls = (item['calls'] ?? 0) as int;
                final height = (calls * 2.5).clamp(24.0, 110.0);

                return Expanded(
                  child: Column(
                    children: [
                      Text('$calls', style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: const Color(0xFF047857))),
                      const SizedBox(height: 6),
                      Container(
                        width: isDesktop ? 36 : 20,
                        height: height,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF047857), Color(0xFF10B981)],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(color: const Color(0xFF047857).withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 2)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        day,
                        style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  // ==========================================
  // 7. COMPANY BRANCHES SECTION
  // ==========================================
  Widget _buildCompanyBranchesSection(List<BranchModel> branches, bool isDesktop) {
    final isMobile = MediaQuery.of(context).size.width < 650;
    return GlassCard(
      padding: EdgeInsets.all(isMobile ? 16 : 22),
      borderRadius: BorderRadius.circular(20),
      borderColor: const Color(0xFFE2E8F0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D9488).withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.storefront_rounded, color: Color(0xFF0F766E), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Company Branches & Desks',
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                      ),
                      Text(
                        'Individual office locations, telecaller allocation & lead pools',
                        style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BranchManagementScreen()),
                  );
                },
                icon: const Icon(Icons.settings_suggest_rounded, size: 16, color: Color(0xFF047857)),
                label: Text('Manage Branches', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF047857))),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (branches.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.store_mall_directory_outlined, color: Color(0xFF94A3B8), size: 40),
                    const SizedBox(height: 8),
                    Text('No branches created yet for this company', style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 13)),
                    const SizedBox(height: 12),
                    GradientPrimaryButton(
                      text: 'Add First Branch',
                      icon: Icons.add_rounded,
                      onPressed: _showAddBranchDialog,
                    ),
                  ],
                ),
              ),
            )
          else
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: branches.map((b) => _buildBranchMiniCard(b, isMobile)).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildBranchMiniCard(BranchModel branch, bool isMobile) {
    return Container(
      width: isMobile ? double.infinity : 260,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  branch.name,
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (branch.code.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF047857).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    branch.code,
                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF047857)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (branch.address.isNotEmpty)
            Text(
              branch.address,
              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.people_alt_outlined, size: 13, color: Color(0xFF047857)),
                  const SizedBox(width: 4),
                  Text('${branch.employeeCount} Agents', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                ],
              ),
              Row(
                children: [
                  const Icon(Icons.folder_shared_outlined, size: 13, color: Color(0xFFB45309)),
                  const SizedBox(width: 4),
                  Text('${branch.leadCount} Leads', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
