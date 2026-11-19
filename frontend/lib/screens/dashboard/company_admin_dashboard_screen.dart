import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/company_logo_view.dart';
import '../../core/widgets/glass/glass_card.dart';
import '../../core/widgets/glass/gradient_button.dart';
import '../../models/attendance_model.dart';
import '../../models/company_model.dart';
import '../../models/dashboard_model.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/billing_provider.dart';
import '../../providers/company_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/employee_provider.dart';
import '../../providers/lead_provider.dart';
import '../../routes/app_routes.dart';
import '../companies/edit_company_dialog.dart';
import '../companies/renewal_request_dialog.dart';
import '../employees/employee_management_screen.dart';
import '../leads/import_wizard_dialog.dart';
import '../quotations/quotation_form_dialog.dart';

class CompanyAdminDashboardScreen extends StatefulWidget {
  const CompanyAdminDashboardScreen({super.key});

  @override
  State<CompanyAdminDashboardScreen> createState() =>
      _CompanyAdminDashboardScreenState();
}

class _CompanyAdminDashboardScreenState
    extends State<CompanyAdminDashboardScreen> {
  String _attendanceFilter = 'ALL'; // ALL, PRESENT, LATE, ABSENT

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshAll();
    });
  }

  Future<void> _refreshAll() async {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await Future.wait([
      context.read<AuthProvider>().refreshUserProfile(),
      context.read<CompanyProvider>().fetchMyCompany(),
      context.read<DashboardProvider>().fetchAdminDashboard(),
      context.read<LeadProvider>().fetchBranches(),
      context.read<EmployeeProvider>().fetchEmployees(),
      context.read<BillingProvider>().fetchBillingOverview(),
      context.read<AttendanceProvider>().fetchAdminRecords(date: todayStr),
    ]);
  }

  void _showAddBranchDialog() {
    final authUser = context.read<AuthProvider>().currentUser;
    final canAddBranch = authUser?.canManageBranches ??
        (authUser?.hasMenuPermission('branches') ?? false);
    if (!canAddBranch) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Branch management is locked for your company. Super Admin permission required.'),
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
          insetPadding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 20, vertical: isMobile ? 16 : 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: GlassCard(
              blur: 24,
              opacity: 0.96,
              borderRadius: BorderRadius.circular(20),
              padding: EdgeInsets.all(isMobile ? 18 : 24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF06B6D4).withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.storefront_rounded,
                              color: Color(0xFF06B6D4), size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Add Company Branch',
                            style: GoogleFonts.inter(
                                fontSize: isMobile ? 15.5 : 17,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F172A)),
                          ),
                        ),
                        DialogCloseButton(onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameCtrl,
                      style: GoogleFonts.inter(
                          color: const Color(0xFF0F172A), fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Branch Name *',
                        hintText: 'e.g. Downtown Regional Branch',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: Color(0xFFE2E8F0))),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: codeCtrl,
                      style: GoogleFonts.inter(
                          color: const Color(0xFF0F172A), fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Branch Code',
                        hintText: 'e.g. BR-HQ-01',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: Color(0xFFE2E8F0))),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: addressCtrl,
                      style: GoogleFonts.inter(
                          color: const Color(0xFF0F172A), fontSize: 13),
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Branch Location / Address',
                        hintText: 'Physical address or territory notes',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: Color(0xFFE2E8F0))),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        GlassSecondaryButton(
                          text: 'Cancel',
                          onPressed: () => Navigator.pop(ctx),
                        ),
                        const SizedBox(width: 10),
                        GradientPrimaryButton(
                          text: 'Create Branch',
                          icon: Icons.check_rounded,
                          height: 38,
                          onPressed: () async {
                            if (nameCtrl.text.trim().isEmpty) return;
                            final messenger = ScaffoldMessenger.of(context);
                            final nav = Navigator.of(ctx);
                            final branchName = nameCtrl.text.trim();
                            final ok = await context
                                .read<LeadProvider>()
                                .createBranch(
                                  name: branchName,
                                  code: codeCtrl.text.trim(),
                                  address: addressCtrl.text.trim(),
                                );
                            nav.pop();
                            if (ok) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'Branch "$branchName" created successfully!'),
                                  backgroundColor: const Color(0xFF10B981),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
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
        );
      },
    );
  }

  void _showChangePasswordDialog() {
    final formKey = GlobalKey<FormState>();
    final oldPasswordCtrl = TextEditingController();
    final newPasswordCtrl = TextEditingController();
    final confirmPasswordCtrl = TextEditingController();

    bool obscureOld = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool isSubmitting = false;
    String? localError;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (ctx) {
        final isMobile = ResponsiveLayout.isMobile(ctx);
        return StatefulBuilder(
          builder: (context, setDlgState) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : 20, vertical: isMobile ? 16 : 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: GlassCard(
                blur: 24,
                opacity: 0.98,
                borderRadius: BorderRadius.circular(20),
                padding: EdgeInsets.all(isMobile ? 18 : 24),
                child: Form(
                  key: formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(10),
                                border:
                                    Border.all(color: const Color(0xFFFDE68A)),
                              ),
                              child: const Icon(Icons.lock_reset_rounded,
                                  color: Color(0xFFD97706), size: 20),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Change Password',
                                style: GoogleFonts.inter(
                                  fontSize: isMobile ? 15.5 : 17,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            DialogCloseButton(
                                onPressed: () => Navigator.pop(ctx)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (localError != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(10),
                              border:
                                  Border.all(color: const Color(0xFFFCA5A5)),
                            ),
                            child: Text(
                              localError!,
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFFB91C1C)),
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                        TextFormField(
                          controller: oldPasswordCtrl,
                          obscureText: obscureOld,
                          style: GoogleFonts.inter(
                              color: const Color(0xFF0F172A), fontSize: 13),
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Current password is required'
                              : null,
                          decoration: InputDecoration(
                            labelText: 'Current / Temporary Password *',
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            prefixIcon: const Icon(Icons.key_rounded, size: 18),
                            suffixIcon: IconButton(
                              icon: Icon(
                                  obscureOld
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  size: 18),
                              onPressed: () =>
                                  setDlgState(() => obscureOld = !obscureOld),
                            ),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: newPasswordCtrl,
                          obscureText: obscureNew,
                          style: GoogleFonts.inter(
                              color: const Color(0xFF0F172A), fontSize: 13),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'New password is required';
                            }
                            if (v.trim().length < 6) {
                              return 'Minimum 6 characters';
                            }
                            return null;
                          },
                          decoration: InputDecoration(
                            labelText: 'New Password *',
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            prefixIcon:
                                const Icon(Icons.lock_outline_rounded, size: 18),
                            suffixIcon: IconButton(
                              icon: Icon(
                                  obscureNew
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  size: 18),
                              onPressed: () =>
                                  setDlgState(() => obscureNew = !obscureNew),
                            ),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: confirmPasswordCtrl,
                          obscureText: obscureConfirm,
                          style: GoogleFonts.inter(
                              color: const Color(0xFF0F172A), fontSize: 13),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Please confirm new password';
                            }
                            if (v.trim() != newPasswordCtrl.text.trim()) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                          decoration: InputDecoration(
                            labelText: 'Confirm New Password *',
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            prefixIcon:
                                const Icon(Icons.lock_rounded, size: 18),
                            suffixIcon: IconButton(
                              icon: Icon(
                                  obscureConfirm
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  size: 18),
                              onPressed: () => setDlgState(
                                  () => obscureConfirm = !obscureConfirm),
                            ),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: isSubmitting
                                  ? null
                                  : () => Navigator.pop(ctx),
                              child: Text('Cancel',
                                  style: GoogleFonts.inter(
                                      color: const Color(0xFF64748B),
                                      fontWeight: FontWeight.w600)),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: isSubmitting
                                  ? null
                                  : () async {
                                      if (!formKey.currentState!.validate()) {
                                        return;
                                      }
                                      setDlgState(() {
                                        isSubmitting = true;
                                        localError = null;
                                      });
                                      final res = await context
                                          .read<AuthProvider>()
                                          .changePassword(
                                            oldPassword:
                                                oldPasswordCtrl.text.trim(),
                                            newPassword:
                                                newPasswordCtrl.text.trim(),
                                          );
                                      if (!mounted) return;
                                      if (res['success'] == true) {
                                        if (ctx.mounted) Navigator.pop(ctx);
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                'Password updated successfully!'),
                                            backgroundColor: AppColors.success,
                                          ),
                                        );
                                      } else {
                                        setDlgState(() {
                                          isSubmitting = false;
                                          localError =
                                              res['error']?.toString() ??
                                                  'Failed to change password.';
                                        });
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF047857),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              child: Text(
                                  isSubmitting ? 'Updating...' : 'Update'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openEditCompanyDialog() async {
    final compProv = context.read<CompanyProvider>();
    final authProv = context.read<AuthProvider>();
    CompanyModel? comp = compProv.activeCompanyDetail;
    if (comp == null || comp.name.isEmpty) {
      comp = await compProv.fetchMyCompany();
    }
    if (comp == null) {
      final u = authProv.currentUser;
      comp = CompanyModel(
        id: u?.companyId ?? '',
        name: u?.companyName ?? '',
        logo: u?.companyLogo ?? '',
        contactPhone: u?.companyPhone ?? '',
        contactEmail: u?.companyEmail ?? '',
        address: u?.companyAddress ?? '',
        gstin: u?.companyGstin ?? '',
        website: u?.companyWebsite ?? '',
      );
    }
    if (!mounted) return;
    await EditCompanyDialog.show(context, comp);
  }

  void _openRenewalRequestDialog(BuildContext context, CompanyModel? company) {
    SubmitRenewalRequestDialog.show(context, company: company).then((val) {
      if (val == true && mounted) {
        context.read<CompanyProvider>().fetchMyCompany();
      }
    });
  }

  String _formatExpiry(CompanyModel? company, String? userPlanExpiry) {
    final exp = company?.expiryFormatted ?? '';
    if (exp.isNotEmpty && exp != 'No expiry set') return exp;
    final raw = company?.planExpiresAt ?? userPlanExpiry;
    if (raw != null && raw.isNotEmpty) {
      try {
        final dt = DateTime.parse(raw);
        const months = [
          'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
        ];
        return '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]} ${dt.year}';
      } catch (_) {
        return raw.length >= 10 ? raw.substring(0, 10) : raw;
      }
    }
    return 'Active';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final dash = context.watch<DashboardProvider>();
    final compProv = context.watch<CompanyProvider>();
    final activeComp = compProv.activeCompanyDetail;
    final kpis = dash.adminKpis;
    final isMobile = ResponsiveLayout.isMobile(context);

    final companyName = (activeComp != null && activeComp.name.isNotEmpty)
        ? activeComp.name
        : (user?.companyName ?? 'Company Workspace');
    final companyLogo = (activeComp != null && activeComp.logo.isNotEmpty)
        ? activeComp.logo
        : (user?.companyLogo ?? '');
    final planName = (activeComp != null && activeComp.planName.isNotEmpty)
        ? activeComp.planName
        : (user?.companyPlanName ?? 'Standard');
    final isOverdue =
        activeComp != null ? activeComp.isPlanOverdue : (user?.companyIsPlanExpired ?? false);
    final daysLeft =
        activeComp != null ? activeComp.daysUntilExpiry : user?.companyDaysUntilExpiry;
    final isExpiringSoon = !isOverdue && daysLeft != null && daysLeft <= 7;
    final expiryText = _formatExpiry(activeComp, user?.companyPlanExpiresAt);
    final canManageBranches = user?.canManageBranches ??
        (user?.hasMenuPermission('branches') ?? false);

    return RefreshIndicator(
      color: const Color(0xFF047857),
      onRefresh: _refreshAll,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          isMobile ? 12 : 24,
          isMobile ? 8 : 16,
          isMobile ? 12 : 24,
          isMobile ? 16 : 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Compact Header
            _buildCompactHeader(
              companyName: companyName,
              companyLogo: companyLogo,
              planName: planName,
              expiryText: expiryText,
              daysLeft: daysLeft,
              isMobile: isMobile,
              canManageBranches: canManageBranches,
              activeComp: activeComp,
            ),

            // Only show subscription alert banner if expired or expiring soon
            if (isOverdue || isExpiringSoon) ...[
              const SizedBox(height: 12),
              _buildUrgentRenewalAlert(
                isOverdue: isOverdue,
                daysLeft: daysLeft,
                expiryText: expiryText,
                activeComp: activeComp,
              ),
            ],
            const SizedBox(height: 14),

            // 2. 4 Essential Small KPI Tiles
            _buildCompactKpiGrid(kpis),
            const SizedBox(height: 14),

            // 3. Slim Sales & Billing Strip
            _buildSlimSalesBillingStrip(context),
            const SizedBox(height: 14),

            // 4. Employee Attendance Summary (Present / Absent / Late)
            _buildEmployeeAttendanceSection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactHeader({
    required String companyName,
    required String companyLogo,
    required String planName,
    required String expiryText,
    required int? daysLeft,
    required bool isMobile,
    required bool canManageBranches,
    required CompanyModel? activeComp,
  }) {
    return GlassCard(
      padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 18, vertical: isMobile ? 12 : 14),
      borderRadius: BorderRadius.circular(16),
      borderColor: const Color(0xFFE2E8F0),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CompanyLogoView(
                logo: companyLogo,
                companyName: companyName,
                size: 40,
                borderRadius: BorderRadius.circular(10),
                borderColor: const Color(0xFFCBD5E1),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      companyName,
                      style: GoogleFonts.inter(
                        fontSize: isMobile ? 16 : 19,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$planName · Valid until $expiryText${daysLeft != null ? " ($daysLeft d left)" : ""}',
                      style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF64748B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 34,
                child: OutlinedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => const ImportWizardDialog(),
                    );
                  },
                  icon: const Icon(Icons.upload_file_rounded,
                      size: 15, color: Color(0xFF1D4ED8)),
                  label: Text('Import CSV',
                      style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1D4ED8))),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFBFDBFE)),
                    backgroundColor: const Color(0xFFEFF6FF),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 34,
                child: OutlinedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => const QuotationFormDialog(),
                    );
                  },
                  icon: const Icon(Icons.request_quote_rounded,
                      size: 15, color: Color(0xFF047857)),
                  label: Text('New Quotation',
                      style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF047857))),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFA7F3D0)),
                    backgroundColor: const Color(0xFFECFDF5),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9)),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                height: 34,
                width: 34,
                child: PopupMenuButton<String>(
                  tooltip: 'More Options',
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  icon: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Icon(Icons.more_vert_rounded,
                        size: 18, color: Color(0xFF334155)),
                  ),
                  onSelected: (val) {
                    if (val == 'edit') _openEditCompanyDialog();
                    if (val == 'password') _showChangePasswordDialog();
                    if (val == 'renew') {
                      _openRenewalRequestDialog(context, activeComp);
                    }
                    if (val == 'branch') _showAddBranchDialog();
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_rounded,
                              size: 16, color: Color(0xFF4338CA)),
                          SizedBox(width: 8),
                          Text('Edit Profile & Logo'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'password',
                      child: Row(
                        children: [
                          Icon(Icons.lock_reset_rounded,
                              size: 16, color: Color(0xFFD97706)),
                          SizedBox(width: 8),
                          Text('Change Password'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'renew',
                      child: Row(
                        children: [
                          Icon(Icons.autorenew_rounded,
                              size: 16, color: Color(0xFF0F766E)),
                          SizedBox(width: 8),
                          Text('Request Renewal'),
                        ],
                      ),
                    ),
                    if (canManageBranches)
                      const PopupMenuItem(
                        value: 'branch',
                        child: Row(
                          children: [
                            Icon(Icons.add_business_rounded,
                                size: 16, color: Color(0xFF0284C7)),
                            SizedBox(width: 8),
                            Text('Add Branch'),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUrgentRenewalAlert({
    required bool isOverdue,
    required int? daysLeft,
    required String expiryText,
    required CompanyModel? activeComp,
  }) {
    final bg = isOverdue ? const Color(0xFFFEF2F2) : const Color(0xFFFFFBEB);
    final border =
        isOverdue ? const Color(0xFFFCA5A5) : const Color(0xFFFCD34D);
    final accent =
        isOverdue ? const Color(0xFFDC2626) : const Color(0xFFD97706);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isOverdue ? Icons.error_rounded : Icons.hourglass_top_rounded,
                color: accent,
                size: 18,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  isOverdue
                      ? 'Subscription expired on $expiryText. Renew to keep full access.'
                      : 'Plan expiring in ${daysLeft ?? 0}d ($expiryText).',
                  style: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.w600, color: accent),
                ),
              ),
            ],
          ),
          SizedBox(
            height: 32,
            child: ElevatedButton(
              onPressed: () => _openRenewalRequestDialog(context, activeComp),
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: Text('Renew Now',
                  style: GoogleFonts.inter(
                      fontSize: 11.5, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactKpiGrid(DashboardKpis kpis) {
    final c1 = _buildSmallKpiTile(
      icon: Icons.groups_rounded,
      label: 'Total Leads',
      value: '${kpis.totalRegisteredLeads}',
      subtitle: '${kpis.assignedLeads} assigned · ${kpis.unassignedLeads} pool',
      color: const Color(0xFF2563EB),
      bg: const Color(0xFFEFF6FF),
    );
    final c2 = _buildSmallKpiTile(
      icon: Icons.phone_in_talk_rounded,
      label: 'Calls Today',
      value: '${kpis.callsLoggedToday}',
      subtitle: '${kpis.callsLoggedTotal} total dials',
      color: const Color(0xFF0284C7),
      bg: const Color(0xFFF0F9FF),
    );
    final c3 = _buildSmallKpiTile(
      icon: Icons.verified_rounded,
      label: 'Won Leads',
      value: '${kpis.completedLeads}',
      subtitle: 'Converted deals',
      color: const Color(0xFF059669),
      bg: const Color(0xFFECFDF5),
    );
    final c4 = _buildSmallKpiTile(
      icon: Icons.event_available_rounded,
      label: 'Callbacks',
      value: '${kpis.scheduledCallbacks}',
      subtitle: kpis.overdueCallbacks > 0
          ? '${kpis.overdueCallbacks} overdue'
          : '${kpis.completedCallbacks} closed',
      color: kpis.overdueCallbacks > 0
          ? const Color(0xFFDC2626)
          : const Color(0xFFD97706),
      bg: kpis.overdueCallbacks > 0
          ? const Color(0xFFFEF2F2)
          : const Color(0xFFFFFBEB),
    );

    return LayoutBuilder(
      builder: (ctx, constraints) {
        if (constraints.maxWidth >= 760) {
          return Row(
            children: [
              Expanded(child: c1),
              const SizedBox(width: 10),
              Expanded(child: c2),
              const SizedBox(width: 10),
              Expanded(child: c3),
              const SizedBox(width: 10),
              Expanded(child: c4),
            ],
          );
        }
        return Column(
          children: [
            Row(
              children: [
                Expanded(child: c1),
                const SizedBox(width: 8),
                Expanded(child: c2),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: c3),
                const SizedBox(width: 8),
                Expanded(child: c4),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildSmallKpiTile({
    required IconData icon,
    required String label,
    required String value,
    required String subtitle,
    required Color color,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlimSalesBillingStrip(BuildContext context) {
    final kpi = context.watch<BillingProvider>().billingOverview;

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      borderRadius: BorderRadius.circular(14),
      borderColor: const Color(0xFFE2E8F0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_outlined,
                  size: 17, color: Color(0xFF059669)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Sales & Billing',
                  style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A)),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, AppRoutes.billing),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text('Open Billing →',
                    style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF2563EB))),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (ctx, constraints) {
              final s1 = _buildMiniBillingCell(
                'Quotations (${kpi?.quotationCount ?? 0})',
                '₹${(kpi?.totalQuotationValue ?? 0.0).toStringAsFixed(0)}',
                const Color(0xFF7C3AED),
                const Color(0xFFF5F3FF),
              );
              final s2 = _buildMiniBillingCell(
                'Invoiced (${kpi?.invoiceCount ?? 0})',
                '₹${(kpi?.totalBilled ?? 0.0).toStringAsFixed(0)}',
                const Color(0xFF2563EB),
                const Color(0xFFEFF6FF),
              );
              final s3 = _buildMiniBillingCell(
                'Collected (${kpi?.paidInvoiceCount ?? 0})',
                '₹${(kpi?.totalCollected ?? 0.0).toStringAsFixed(0)}',
                const Color(0xFF059669),
                const Color(0xFFECFDF5),
              );
              final s4 = _buildMiniBillingCell(
                'Pending (${kpi?.pendingInvoiceCount ?? 0})',
                '₹${(kpi?.pendingReceivables ?? 0.0).toStringAsFixed(0)}',
                (kpi?.pendingReceivables ?? 0.0) > 0
                    ? const Color(0xFFDC2626)
                    : const Color(0xFF64748B),
                (kpi?.pendingReceivables ?? 0.0) > 0
                    ? const Color(0xFFFEF2F2)
                    : const Color(0xFFF8FAFC),
              );

              if (constraints.maxWidth >= 680) {
                return Row(
                  children: [
                    Expanded(child: s1),
                    const SizedBox(width: 8),
                    Expanded(child: s2),
                    const SizedBox(width: 8),
                    Expanded(child: s3),
                    const SizedBox(width: 8),
                    Expanded(child: s4),
                  ],
                );
              }
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: s1),
                      const SizedBox(width: 8),
                      Expanded(child: s2),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: s3),
                      const SizedBox(width: 8),
                      Expanded(child: s4),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMiniBillingCell(
      String label, String value, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF475569)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.robotoMono(
                fontSize: 14, fontWeight: FontWeight.w800, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeAttendanceSection(BuildContext context) {
    final attProv = context.watch<AttendanceProvider>();
    final empProv = context.watch<EmployeeProvider>();
    final summary = attProv.adminSummary;
    final records = attProv.adminRecords;

    final int totalStaff = (summary['total_employees'] as num?)?.toInt() ??
        empProv.employees.length;
    final int presentCount = (summary['present_count'] as num?)?.toInt() ?? 0;
    final int lateCount = (summary['late_count'] as num?)?.toInt() ?? 0;
    final int absentCount = (summary['absent_count'] as num?)?.toInt() ??
        (totalStaff - presentCount - lateCount).clamp(0, totalStaff);

    final filtered = records.where((r) {
      final st = r.status.toUpperCase();
      if (_attendanceFilter == 'PRESENT') return st == 'PRESENT';
      if (_attendanceFilter == 'LATE') return st == 'LATE';
      if (_attendanceFilter == 'ABSENT') return st == 'ABSENT' || st == 'ON_LEAVE';
      return true;
    }).toList();

    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(16),
      borderColor: const Color(0xFFE2E8F0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.fingerprint_rounded,
                  size: 18, color: Color(0xFF047857)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Employee Attendance (Today)',
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const EmployeeManagementScreen()),
                  );
                },
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text('Manage Team →',
                    style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF047857))),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Present / Absent / Late / Total Strip
          LayoutBuilder(
            builder: (ctx, constraints) {
              final s1 = _buildMiniBillingCell(
                'Total Staff',
                '$totalStaff',
                const Color(0xFF334155),
                const Color(0xFFF8FAFC),
              );
              final s2 = _buildMiniBillingCell(
                'Present',
                '$presentCount',
                const Color(0xFF059669),
                const Color(0xFFECFDF5),
              );
              final s3 = _buildMiniBillingCell(
                'Late',
                '$lateCount',
                const Color(0xFFD97706),
                const Color(0xFFFFFBEB),
              );
              final s4 = _buildMiniBillingCell(
                'Absent',
                '$absentCount',
                const Color(0xFFDC2626),
                const Color(0xFFFEF2F2),
              );

              if (constraints.maxWidth >= 680) {
                return Row(
                  children: [
                    Expanded(child: s1),
                    const SizedBox(width: 8),
                    Expanded(child: s2),
                    const SizedBox(width: 8),
                    Expanded(child: s3),
                    const SizedBox(width: 8),
                    Expanded(child: s4),
                  ],
                );
              }
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: s1),
                      const SizedBox(width: 8),
                      Expanded(child: s2),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: s3),
                      const SizedBox(width: 8),
                      Expanded(child: s4),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),

          // Filter Chips
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildAttFilterChip('ALL', 'All (${records.length})'),
              _buildAttFilterChip('PRESENT', 'Present ($presentCount)'),
              _buildAttFilterChip('LATE', 'Late ($lateCount)'),
              _buildAttFilterChip('ABSENT', 'Absent ($absentCount)'),
            ],
          ),
          const SizedBox(height: 10),

          if (attProv.isLoading && records.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Text(
                  'No attendance records for this filter today.',
                  style: GoogleFonts.inter(
                      color: const Color(0xFF64748B), fontSize: 12),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (ctx, i) => _buildAttendanceTile(filtered[i]),
            ),
        ],
      ),
    );
  }

  Widget _buildAttFilterChip(String key, String label) {
    final isSelected = _attendanceFilter == key;
    return InkWell(
      onTap: () => setState(() => _attendanceFilter = key),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF0F172A)
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildAttendanceTile(AttendanceModel rec) {
    final st = rec.status.toUpperCase();
    final Color statusColor;
    final Color statusBg;
    if (st == 'PRESENT') {
      statusColor = const Color(0xFF059669);
      statusBg = const Color(0xFFECFDF5);
    } else if (st == 'LATE') {
      statusColor = const Color(0xFFD97706);
      statusBg = const Color(0xFFFFFBEB);
    } else {
      statusColor = const Color(0xFFDC2626);
      statusBg = const Color(0xFFFEF2F2);
    }

    final checkInStr = rec.checkInTime != null
        ? DateFormat('hh:mm a').format(rec.checkInTime!.toLocal())
        : 'Not checked in';
    final checkOutStr = rec.checkOutTime != null
        ? DateFormat('hh:mm a').format(rec.checkOutTime!.toLocal())
        : '—';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
          collapsedShape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
          leading: CircleAvatar(
            radius: 15,
            backgroundColor: statusColor,
            child: Text(
              rec.userName.isNotEmpty ? rec.userName[0].toUpperCase() : 'E',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  fontSize: 12),
            ),
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  rec.userName.isNotEmpty ? rec.userName : 'Employee',
                  style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  st.replaceAll('_', ' '),
                  style: GoogleFonts.inter(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: statusColor),
                ),
              ),
            ],
          ),
          subtitle: Text(
            'In: $checkInStr${rec.matchedBranchName.isNotEmpty ? " · ${rec.matchedBranchName}" : ""}',
            style: GoogleFonts.inter(
                fontSize: 11, color: const Color(0xFF64748B)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          children: [
            const Divider(color: Color(0xFFE2E8F0), height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                if (rec.userEmail.isNotEmpty)
                  Text('Email: ${rec.userEmail}',
                      style: GoogleFonts.inter(
                          fontSize: 11, color: const Color(0xFF475569))),
                Text('Check-out: $checkOutStr',
                    style: GoogleFonts.inter(
                        fontSize: 11, color: const Color(0xFF475569))),
                Text('Hours: ${rec.workingHours.toStringAsFixed(1)}h',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF047857))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
