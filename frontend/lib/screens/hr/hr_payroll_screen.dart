import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../../core/widgets/action_loader.dart';
import '../../providers/auth_provider.dart';
import '../../providers/billing_provider.dart';
import '../../providers/employee_provider.dart';
import '../../providers/hr_payroll_provider.dart';
import '../billing/template_designer_dialog.dart';
import 'salary_structure_screen.dart';

class HrPayrollScreen extends StatefulWidget {
  const HrPayrollScreen({super.key});

  @override
  State<HrPayrollScreen> createState() => _HrPayrollScreenState();
}

class _HrPayrollScreenState extends State<HrPayrollScreen> {
  String? _selectedRunId;
  int? _payslipFilterMonth;
  int? _payslipFilterYear;
  final Set<String> _selectedPayslipIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAll());
  }

  Future<void> _loadAll() async {
    final hr = context.read<HrPayrollProvider>();
    final user = context.read<AuthProvider>().currentUser;
    await Future.wait([
      hr.fetchLeaveTypes(),
      hr.fetchLeaveBalances(),
      hr.fetchLeaveRequests(),
      hr.fetchHolidays(),
      hr.fetchRegularizations(),
      hr.fetchMyPayslips(),
    ]);
    if (user?.hasPermission('payroll.manage_rules') ?? false) {
      hr.fetchSalaryStructures();
      if (mounted) context.read<EmployeeProvider>().fetchEmployees();
    }
    if (user?.hasPermission('payroll.process_salary') ?? false) {
      hr.fetchPayrollRuns();
      hr.checkPayrollReminders();
    }
    if (mounted) {
      context.read<BillingProvider>().fetchTemplates(docType: 'PAYSLIP');
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  PdfColor _resolvePayslipPrimaryColor() {
    final billing = context.read<BillingProvider>();
    final payslipTpl = billing.templates.where((t) => t.docType == 'PAYSLIP').isNotEmpty
        ? billing.templates.firstWhere((t) => t.docType == 'PAYSLIP' && t.isDefault,
            orElse: () => billing.templates.firstWhere((t) => t.docType == 'PAYSLIP'))
        : null;
    final primaryHex = payslipTpl?.layout.primaryColorHex.replaceAll('#', '') ?? '1E3A8A';
    return PdfColor.fromInt(int.tryParse('FF$primaryHex', radix: 16) ?? 0xFF1E3A8A);
  }

  void _addPayslipPage(pw.Document doc, Map<String, dynamic> slip, dynamic user, PdfColor primaryColor) {
    final curr = slip['currency']?.toString() ?? user?.companyCurrency ?? 'INR';
    final payments = (slip['payments'] as List<dynamic>?) ?? [];
    final rules = (slip['rule_breakdown'] as List<dynamic>?) ?? [];

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (ctx) => pw.Container(
          padding: const pw.EdgeInsets.all(20),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: primaryColor, width: 1.5),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text((user?.companyName ?? 'COMPANY').toUpperCase(), style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                      if (user?.companyAddress != null && user!.companyAddress!.isNotEmpty)
                        pw.Text(user.companyAddress!, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: pw.BoxDecoration(color: primaryColor, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))),
                    child: pw.Text('PAYSLIP ${slip['month']}/${slip['year']}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                  ),
                ],
              ),
              pw.Divider(color: primaryColor, height: 20),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Employee: ${slip['user_name'] ?? ''}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Email: ${slip['user_email'] ?? ''}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                      if ((slip['user_department'] ?? '').toString().isNotEmpty)
                        pw.Text('Department: ${slip['user_department']}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                      if ((slip['bank_name'] ?? '').toString().isNotEmpty)
                        pw.Text('Bank: ${slip['bank_name']} · ${slip['account_number'] ?? ''}', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Working Days: ${slip['working_days']}  |  Present: ${slip['present_days']}', style: const pw.TextStyle(fontSize: 9.5)),
                      pw.Text('Paid Leave: ${slip['paid_leave_days']}  |  LOP Days: ${slip['lop_days']}', style: const pw.TextStyle(fontSize: 9.5)),
                      if ((slip['due_date'] ?? '').toString().isNotEmpty)
                        pw.Text('Payday Due: ${slip['due_date']}', style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 14),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300)),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('EARNINGS', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                          pw.Divider(),
                          _pdfRow('Basic Salary', '$curr ${slip['basic_salary']}'),
                          _pdfRow('HRA', '$curr ${slip['hra']}'),
                          _pdfRow('Allowances', '$curr ${slip['allowances']}'),
                          _pdfRow('Overtime Pay', '$curr ${slip['overtime_pay'] ?? '0.00'}'),
                          _pdfRow('Bonus / Incentive', '$curr ${slip['bonus'] ?? '0.00'}'),
                          pw.Divider(),
                          _pdfRow('Gross Earnings', '$curr ${slip['gross_earnings']}', bold: true),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 14),
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300)),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('DEDUCTIONS', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.red800)),
                          pw.Divider(),
                          _pdfRow('LOP Deduction', '$curr ${slip['lop_deduction']}'),
                          _pdfRow('Late Deduction', '$curr ${slip['late_deduction']}'),
                          _pdfRow('Other / Rule Deductions', '$curr ${slip['other_deductions'] ?? '0.00'}'),
                          _pdfRow('Statutory (PF/ESI/Tax)', '$curr ${slip['statutory_deductions']}'),
                          pw.Divider(),
                          _pdfRow('Payment Status', '${slip['payment_status'] ?? slip['status']}', bold: true),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (rules.isNotEmpty) ...[
                pw.SizedBox(height: 10),
                pw.Text('APPLIED RULES & ADJUSTMENTS', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
                pw.SizedBox(height: 4),
                ...rules.map((r) => pw.Text(
                      '- ${r['rule_name']}: ${r['action_type']} (${r['amount']})',
                      style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
                    )),
              ],
              pw.SizedBox(height: 14),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: const pw.BoxDecoration(color: PdfColors.indigo50, borderRadius: pw.BorderRadius.all(pw.Radius.circular(6))),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('NET PAYABLE: $curr ${slip['net_pay']}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                        pw.Text('Paid: $curr ${slip['paid_amount'] ?? '0.00'}', style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.green800)),
                      ],
                    ),
                    pw.Text('BALANCE DUE: $curr ${slip['balance_due'] ?? '0.00'}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.red800)),
                  ],
                ),
              ),
              if (payments.isNotEmpty) ...[
                pw.SizedBox(height: 12),
                pw.Text('INSTALLMENT PAYMENT HISTORY', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                pw.SizedBox(height: 4),
                ...payments.map((p) => _pdfRow(
                      '${p['receipt_number']} · ${p['payment_mode_display'] ?? p['payment_mode']}',
                      '$curr ${p['amount']}',
                    )),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _downloadPayslipPdf(Map<String, dynamic> slip) async {
    final user = context.read<AuthProvider>().currentUser;
    final primaryColor = _resolvePayslipPrimaryColor();
    final doc = pw.Document();
    _addPayslipPage(doc, slip, user, primaryColor);
    await Printing.layoutPdf(onLayout: (_) async => doc.save(), name: 'Payslip_${slip['month']}_${slip['year']}.pdf');
  }

  Future<void> _downloadBulkPayslipsPdf(List<Map<String, dynamic>> slips, {String filename = 'Payslips_Bulk.pdf'}) async {
    if (slips.isEmpty) return;
    final user = context.read<AuthProvider>().currentUser;
    final primaryColor = _resolvePayslipPrimaryColor();
    final doc = pw.Document();
    for (final slip in slips) {
      _addPayslipPage(doc, slip, user, primaryColor);
    }
    await Printing.layoutPdf(onLayout: (_) async => doc.save(), name: filename);
  }

  pw.Widget _pdfRow(String l, String v, {bool bold = false}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(l, style: pw.TextStyle(fontSize: 9.5, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
            pw.Text(v, style: pw.TextStyle(fontSize: 9.5, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final hr = context.watch<HrPayrollProvider>();
    final canManagePayroll = (user?.isCompanyAdmin ?? false) ||
        (user?.isSuperAdmin ?? false) ||
        (user?.hasAnyPermission(['payroll.manage_rules', 'payroll.process_salary']) ?? false);
    final tabs = <Tab>[
      const Tab(text: 'Leaves & Holidays'),
      const Tab(text: 'Regularization'),
      if (canManagePayroll) const Tab(text: 'Payroll Runs'),
      const Tab(text: 'My Payslips'),
    ];
    final tabViews = <Widget>[
      _buildLeavesHolidaysTab(hr, user),
      _buildRegularizationTab(hr, user),
      if (canManagePayroll) _buildPayrollTab(hr, user),
      _buildMyPayslipsTab(hr),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('HR, Leave & Payroll Management', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
              Text('Leave balances, holiday calendar, attendance regularization, payroll & payslips', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
              const SizedBox(height: 14),
              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
                child: TabBar(
                  isScrollable: true,
                  labelColor: const Color(0xFF1E3A8A),
                  unselectedLabelColor: const Color(0xFF64748B),
                  indicatorColor: const Color(0xFF1E3A8A),
                  tabs: tabs,
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: TabBarView(
                  children: tabViews,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeavesHolidaysTab(HrPayrollProvider hr, dynamic user) {
    final canApprove = user?.hasPermission('leave.approve') ?? false;
    final canManageTypes = user?.hasPermission('leave.manage_types') ?? false;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: hr.leaveBalances.map((b) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${b['leave_type_name']} (${b['leave_type_code']})', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF475569))),
                        Text('${b['remaining']} / ${b['allocated']} left', style: GoogleFonts.robotoMono(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF059669))),
                      ],
                    ),
                  );
                }).toList(),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (canManageTypes)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.celebration_outlined, size: 16),
                      label: const Text('+ Holiday'),
                      onPressed: () => _openHolidayDialog(hr),
                    ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A), foregroundColor: Colors.white),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Apply Leave'),
                    onPressed: () => _openApplyLeaveDialog(hr),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Leave Requests', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (hr.leaveRequests.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: Text('No leave requests yet.', style: GoogleFonts.inter(color: const Color(0xFF64748B))),
            )
          else
            ...hr.leaveRequests.map((lr) {
              final st = lr['status']?.toString() ?? 'PENDING';
              final color = st == 'APPROVED' ? const Color(0xFF059669) : (st == 'REJECTED' ? const Color(0xFFDC2626) : const Color(0xFFD97706));
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text('${lr['user_name']} · ${lr['leave_type_name']} (${lr['days_count']} days)', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700)),
                  subtitle: Text('${lr['start_date']} to ${lr['end_date']} · ${lr['reason']}', style: GoogleFonts.inter(fontSize: 12)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Chip(label: Text(st, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: color))),
                      if (canApprove && st == 'PENDING') ...[
                        IconButton(icon: const Icon(Icons.check_circle, color: Color(0xFF059669)), onPressed: () => hr.actionLeave(lr['id'].toString(), 'APPROVE')),
                        IconButton(icon: const Icon(Icons.cancel, color: Color(0xFFDC2626)), onPressed: () => hr.actionLeave(lr['id'].toString(), 'REJECT')),
                      ],
                    ],
                  ),
                ),
              );
            }),
          if (hr.holidays.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Company Holidays', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: hr.holidays.map((h) => Chip(
                    label: Text('${h['date']} — ${h['name']}', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
                    onDeleted: canManageTypes ? () => hr.deleteHoliday(h['id'].toString()) : null,
                  )).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRegularizationTab(HrPayrollProvider hr, dynamic user) {
    final canApprove = user?.hasPermission('attendance.approve_corrections') ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A), foregroundColor: Colors.white),
            icon: const Icon(Icons.edit_calendar_rounded, size: 16),
            label: const Text('Request Missed Punch Correction'),
            onPressed: () => _openRegularizationDialog(hr),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: hr.regularizations.isEmpty
              ? Center(child: Text('No attendance regularization requests.', style: GoogleFonts.inter(color: const Color(0xFF64748B))))
              : ListView.builder(
                  itemCount: hr.regularizations.length,
                  itemBuilder: (ctx, i) {
                    final r = hr.regularizations[i];
                    final st = r['status']?.toString() ?? 'PENDING';
                    return Card(
                      child: ListTile(
                        title: Text('${r['user_name']} · ${r['date']} (${r['requested_check_in']} - ${r['requested_check_out'] ?? '-'})', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700)),
                        subtitle: Text('${r['reason']} · Status: $st', style: GoogleFonts.inter(fontSize: 12)),
                        trailing: (canApprove && st == 'PENDING')
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(icon: const Icon(Icons.check_circle, color: Color(0xFF059669)), onPressed: () => hr.actionRegularization(r['id'].toString(), 'APPROVE')),
                                  IconButton(icon: const Icon(Icons.cancel, color: Color(0xFFDC2626)), onPressed: () => hr.actionRegularization(r['id'].toString(), 'REJECT')),
                                ],
                              )
                            : null,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPayrollTab(HrPayrollProvider hr, dynamic user) {
    final canRules = user?.hasPermission('payroll.manage_rules') ?? false;
    final canProcess = user?.hasPermission('payroll.process_salary') ?? false;
    if (!canRules && !canProcess) {
      return Center(child: Text('Payroll management requires HR Payroll permissions.', style: GoogleFonts.inter(color: const Color(0xFF64748B))));
    }
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (canRules)
                OutlinedButton.icon(
                  icon: const Icon(Icons.account_balance_wallet_outlined, size: 16),
                  label: const Text('Configure Employee Salary'),
                  onPressed: () => _openSalaryStructureDialog(hr),
                ),
              if (canProcess)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white),
                  icon: const Icon(Icons.play_arrow_rounded, size: 17),
                  label: const Text('Generate Monthly Payroll'),
                  onPressed: () => _openGeneratePayrollDialog(hr),
                ),
              if (canProcess)
                OutlinedButton.icon(
                  icon: const Icon(Icons.notifications_active_outlined, size: 16),
                  label: const Text('Check Salary Reminders'),
                  onPressed: () async {
                    final count = await hr.checkPayrollReminders();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(count > 0
                              ? 'Dispatched $count salary reminder notification(s).'
                              : 'All salary reminders are up to date.'),
                        ),
                      );
                    }
                  },
                ),
              if (canRules || canProcess)
                OutlinedButton.icon(
                  icon: const Icon(Icons.design_services_outlined, size: 16),
                  label: const Text('Payslip PDF Design'),
                  onPressed: () {
                    final billing = context.read<BillingProvider>();
                    final existing = billing.templates.where((t) => t.docType == 'PAYSLIP').isNotEmpty
                        ? billing.templates.firstWhere((t) => t.docType == 'PAYSLIP' && t.isDefault,
                            orElse: () => billing.templates.firstWhere((t) => t.docType == 'PAYSLIP'))
                        : null;
                    showDialog(
                      context: context,
                      builder: (_) => TemplateDesignerDialog(
                        initialDocType: 'PAYSLIP',
                        templateToEdit: existing,
                      ),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (hr.salaryStructures.isNotEmpty) ...[
            Text('Configured Salary Structures (${hr.salaryStructures.length})', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            ...hr.salaryStructures.map((s) => Card(
                  child: ListTile(
                    title: Text('${s['user_name']}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700)),
                    subtitle: Text(
                      'Gross: ${s['currency']} ${s['gross_salary']}  |  Deductions: ${s['currency']} ${s['total_fixed_deductions']}'
                      '${s['salary_day_override'] != null ? '  |  Payday: ${s['salary_day_override']}' : ''}',
                      style: GoogleFonts.inter(fontSize: 12),
                    ),
                    trailing: TextButton.icon(
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Edit'),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SalaryStructureScreen(initialUserId: s['user']?.toString()),
                        ),
                      ),
                    ),
                  ),
                )),
            const SizedBox(height: 14),
          ],
          if (hr.payrollRuns.isNotEmpty) ...[
            Text('Payroll Runs', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            ...hr.payrollRuns.map((run) {
              final rid = run['id'].toString();
              final st = run['status']?.toString() ?? 'DRAFT';
              return Card(
                child: ListTile(
                  title: Text('Payroll ${run['month']}/${run['year']} · Net Total: ${run['total_net_pay']}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    '${run['payslip_count']} Payslips · Status: $st · Paid: ${run['total_paid'] ?? 0} · Balance Due: ${run['total_balance_due'] ?? run['total_net_pay']}',
                    style: GoogleFonts.inter(fontSize: 12),
                  ),
                  trailing: Wrap(
                    spacing: 6,
                    children: [
                      TextButton(
                        onPressed: () {
                          setState(() => _selectedRunId = rid);
                          hr.fetchPayrollRunDetail(rid);
                        },
                        child: const Text('View Slips'),
                      ),
                      if (st == 'DRAFT')
                        ElevatedButton(onPressed: () => hr.actionPayrollRun(rid, 'FINALIZE'), child: const Text('Finalize')),
                      if (st == 'FINALIZED')
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white),
                          onPressed: () => _openMarkRunPaidDialog(hr, rid),
                          child: const Text('Mark Paid'),
                        ),
                    ],
                  ),
                ),
              );
            }),
          ],
          if (_selectedRunId != null && hr.activeRunPayslips.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Generated Payslips', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800)),
                OutlinedButton.icon(
                  icon: const Icon(Icons.download_for_offline_outlined, size: 16),
                  label: const Text('Bulk Download All PDF'),
                  onPressed: () => ActionLoader.run(
                    context,
                    message: 'Generating Bulk Payslips PDF...',
                    task: () => _downloadBulkPayslipsPdf(
                      hr.activeRunPayslips,
                      filename: 'Payroll_Run_Payslips.pdf',
                    ),
                  ),
                ),
              ],
            ),
            ...hr.activeRunPayslips.map((slip) {
              final statusStr = slip['status']?.toString() ?? 'DRAFT';
              final payStatus = slip['payment_status']?.toString() ?? 'UNPAID';
              final balDue = double.tryParse(slip['balance_due']?.toString() ?? '0') ?? 0.0;
              final payments = (slip['payments'] as List<dynamic>?) ?? [];
              final rules = (slip['rule_breakdown'] as List<dynamic>?) ?? [];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${slip['user_name']} — Net: ${slip['currency']} ${slip['net_pay']}',
                                  style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Due: ${slip['due_date'] ?? '-'} · Paid: ${slip['currency']} ${slip['paid_amount'] ?? 0} · Balance Due: ${slip['currency']} ${slip['balance_due'] ?? slip['net_pay']} · $payStatus',
                                  style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: balDue > 0 ? const Color(0xFFB45309) : const Color(0xFF047857)),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Present: ${slip['present_days']}/${slip['working_days']} · Paid Leave: ${slip['paid_leave_days']} · Unpaid Leave: ${slip['unpaid_leave_days'] ?? 0} · Absent: ${slip['absent_days'] ?? 0} · Late: ${slip['late_days'] ?? 0}',
                                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          Wrap(
                            spacing: 6,
                            children: [
                              if (statusStr == 'DRAFT')
                                OutlinedButton(
                                  onPressed: () => _openAdjustPayslipDialog(hr, slip),
                                  child: const Text('Adjust'),
                                ),
                              if (balDue > 0)
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white),
                                  onPressed: () => _openPayInstallmentDialog(hr, slip, _selectedRunId!),
                                  child: const Text('Pay / Installment'),
                                ),
                              IconButton(
                                icon: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF1E3A8A)),
                                onPressed: () => ActionLoader.run(
                                  context,
                                  message: 'Generating Payslip PDF...',
                                  task: () => _downloadPayslipPdf(slip),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (rules.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: rules.map((r) => Chip(
                                visualDensity: VisualDensity.compact,
                                label: Text('${r['rule_name']}: ${r['amount']}', style: GoogleFonts.inter(fontSize: 10.5)),
                              )).toList(),
                        ),
                      ],
                      if (payments.isNotEmpty) ...[
                        const Divider(height: 14),
                        Text('Installment History', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF334155))),
                        const SizedBox(height: 4),
                        ...payments.map((p) => Text(
                              '• ${p['receipt_number']} — ${slip['currency']} ${p['amount']} (${p['payment_mode_display'] ?? p['payment_mode']})${(p['transaction_ref'] ?? '').toString().isNotEmpty ? ' · Ref: ${p['transaction_ref']}' : ''}',
                              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF475569)),
                            )),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildMyPayslipsTab(HrPayrollProvider hr) {
    final allSlips = hr.myPayslips;
    final years = allSlips
        .map((s) => int.tryParse(s['year']?.toString() ?? ''))
        .whereType<int>()
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));

    final filtered = allSlips.where((s) {
      final m = int.tryParse(s['month']?.toString() ?? '');
      final y = int.tryParse(s['year']?.toString() ?? '');
      if (_payslipFilterMonth != null && m != _payslipFilterMonth) return false;
      if (_payslipFilterYear != null && y != _payslipFilterYear) return false;
      return true;
    }).toList();

    final selectedSlips = filtered.where((s) => _selectedPayslipIds.contains(s['id']?.toString())).toList();
    final bulkTarget = selectedSlips.isNotEmpty ? selectedSlips : filtered;
    final allSelected = filtered.isNotEmpty && filtered.every((s) => _selectedPayslipIds.contains(s['id']?.toString()));

    const monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];

    return RefreshIndicator(
      onRefresh: () => hr.fetchMyPayslips(),
      child: allSlips.isEmpty
          ? ListView(
              children: [
                const SizedBox(height: 60),
                Center(
                  child: Column(
                    children: [
                      Text('No finalized or paid payslips available yet.', style: GoogleFonts.inter(color: const Color(0xFF64748B))),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () => hr.fetchMyPayslips(),
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Refresh Payslips'),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Monthly Filter & Bulk Download Bar
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 150,
                      child: DropdownButtonFormField<int?>(
                        initialValue: _payslipFilterMonth,
                        decoration: InputDecoration(
                          isDense: true,
                          labelText: 'Month',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        items: [
                          const DropdownMenuItem<int?>(value: null, child: Text('All Months')),
                          ...List.generate(
                            12,
                            (idx) => DropdownMenuItem<int?>(value: idx + 1, child: Text(monthNames[idx])),
                          ),
                        ],
                        onChanged: (v) => setState(() => _payslipFilterMonth = v),
                      ),
                    ),
                    SizedBox(
                      width: 140,
                      child: DropdownButtonFormField<int?>(
                        initialValue: years.contains(_payslipFilterYear) ? _payslipFilterYear : null,
                        decoration: InputDecoration(
                          isDense: true,
                          labelText: 'Year',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        items: [
                          const DropdownMenuItem<int?>(value: null, child: Text('All Years')),
                          ...years.map((y) => DropdownMenuItem<int?>(value: y, child: Text('$y'))),
                        ],
                        onChanged: (v) => setState(() => _payslipFilterYear = v),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: filtered.isEmpty
                          ? null
                          : () {
                              setState(() {
                                if (allSelected) {
                                  _selectedPayslipIds.clear();
                                } else {
                                  _selectedPayslipIds.addAll(filtered.map((s) => s['id'].toString()));
                                }
                              });
                            },
                      icon: Icon(allSelected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded, size: 18),
                      label: Text(allSelected ? 'Clear Selection' : 'Select All (${filtered.length})'),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A8A),
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.download_for_offline_rounded, size: 17),
                      label: Text(
                        selectedSlips.isNotEmpty
                            ? 'Bulk Download (${selectedSlips.length})'
                            : 'Bulk Download All (${filtered.length})',
                      ),
                      onPressed: bulkTarget.isEmpty
                          ? null
                          : () => ActionLoader.run(
                                context,
                                message: 'Generating Bulk Payslips PDF...',
                                task: () => _downloadBulkPayslipsPdf(
                                  bulkTarget,
                                  filename: 'My_Payslips_${_payslipFilterYear ?? 'All'}_${_payslipFilterMonth ?? 'All'}.pdf',
                                ),
                              ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Text(
                            'No payslips match the selected month/year.',
                            style: GoogleFonts.inter(color: const Color(0xFF64748B)),
                          ),
                        )
                      : ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (ctx, i) {
                            final slip = filtered[i];
                            final sid = slip['id'].toString();
                            final isSelected = _selectedPayslipIds.contains(sid);
                            final payments = (slip['payments'] as List<dynamic>?) ?? [];
                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: Checkbox(
                                        value: isSelected,
                                        onChanged: (val) {
                                          setState(() {
                                            if (val == true) {
                                              _selectedPayslipIds.add(sid);
                                            } else {
                                              _selectedPayslipIds.remove(sid);
                                            }
                                          });
                                        },
                                      ),
                                      title: Text('Payslip ${slip['month']}/${slip['year']} — Net Pay: ${slip['currency']} ${slip['net_pay']}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700)),
                                      subtitle: Text(
                                        'Status: ${slip['payment_status'] ?? slip['status']} · Paid: ${slip['currency']} ${slip['paid_amount'] ?? 0} · Balance Due: ${slip['currency']} ${slip['balance_due'] ?? 0} · Present: ${slip['present_days']} days',
                                        style: GoogleFonts.inter(fontSize: 12),
                                      ),
                                      trailing: ElevatedButton.icon(
                                        icon: const Icon(Icons.download_rounded, size: 16),
                                        label: const Text('PDF'),
                                        onPressed: () => ActionLoader.run(
                                          context,
                                          message: 'Generating Payslip PDF...',
                                          task: () => _downloadPayslipPdf(slip),
                                        ),
                                      ),
                                    ),
                                    if (payments.isNotEmpty) ...[
                                      const Divider(height: 10),
                                      ...payments.map((p) => Text(
                                            '• ${p['receipt_number']} — ${slip['currency']} ${p['amount']} via ${p['payment_mode_display'] ?? p['payment_mode']}',
                                            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF475569)),
                                          )),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  void _openMarkRunPaidDialog(HrPayrollProvider hr, String runId) {
    String mode = 'BANK_TRANSFER';
    final refCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setDlg) => AlertDialog(
          title: const Text('Mark Full Payroll Run as Paid'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: mode,
                decoration: const InputDecoration(labelText: 'Payment Mode'),
                items: const [
                  DropdownMenuItem(value: 'BANK_TRANSFER', child: Text('Bank Transfer')),
                  DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                  DropdownMenuItem(value: 'CARD', child: Text('Card')),
                  DropdownMenuItem(value: 'CHEQUE', child: Text('Cheque')),
                  DropdownMenuItem(value: 'ONLINE_TRANSFER', child: Text('Online Transfer')),
                ],
                onChanged: (v) => setDlg(() => mode = v ?? 'BANK_TRANSFER'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: refCtrl,
                decoration: const InputDecoration(labelText: 'Reference / Receipt ID (Optional)'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white),
              onPressed: () async {
                final ok = await hr.actionPayrollRun(runId, 'MARK_PAID', paymentReference: refCtrl.text.trim(), paymentMode: mode);
                if (ok && ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Confirm Payout'),
            ),
          ],
        ),
      ),
    );
  }

  void _openAdjustPayslipDialog(HrPayrollProvider hr, Map<String, dynamic> slip) {
    final otCtrl = TextEditingController(text: (slip['overtime_pay'] ?? '0').toString());
    final bonusCtrl = TextEditingController(text: (slip['bonus'] ?? '0').toString());
    final otherDedCtrl = TextEditingController(text: (slip['other_deductions'] ?? '0').toString());
    final notesCtrl = TextEditingController(text: (slip['notes'] ?? '').toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Adjust Payslip — ${slip['user_name']}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: otCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Overtime Pay')),
              TextField(controller: bonusCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Bonus / Incentive')),
              TextField(controller: otherDedCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Other Deductions')),
              TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: 'Notes (Optional)'), maxLines: 2),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final ok = await hr.updatePayslip(slip['id'].toString(), _selectedRunId!, {
                'overtime_pay': double.tryParse(otCtrl.text) ?? 0,
                'bonus': double.tryParse(bonusCtrl.text) ?? 0,
                'other_deductions': double.tryParse(otherDedCtrl.text) ?? 0,
                'notes': notesCtrl.text.trim(),
              });
              if (ok && ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  void _openPayInstallmentDialog(HrPayrollProvider hr, Map<String, dynamic> slip, String runId) {
    final balDue = double.tryParse(slip['balance_due']?.toString() ?? '0') ?? 0.0;
    final amtCtrl = TextEditingController(text: balDue.toStringAsFixed(2));
    String mode = 'BANK_TRANSFER';
    final refCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setDlg) => AlertDialog(
          title: Text('Record Salary Installment — ${slip['user_name']}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Remaining Balance Due: ${slip['currency']} ${balDue.toStringAsFixed(2)}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFFB45309))),
                const SizedBox(height: 10),
                TextField(
                  controller: amtCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Installment Amount'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: mode,
                  decoration: const InputDecoration(labelText: 'Payment Mode'),
                  items: const [
                    DropdownMenuItem(value: 'BANK_TRANSFER', child: Text('Bank Transfer')),
                    DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                    DropdownMenuItem(value: 'CARD', child: Text('Card')),
                    DropdownMenuItem(value: 'CHEQUE', child: Text('Cheque')),
                    DropdownMenuItem(value: 'ONLINE_TRANSFER', child: Text('Online Transfer')),
                  ],
                  onChanged: (v) => setDlg(() => mode = v ?? 'BANK_TRANSFER'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: refCtrl,
                  decoration: const InputDecoration(labelText: 'Reference / Receipt ID (Optional)'),
                ),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(labelText: 'Notes (Optional)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white),
              onPressed: () async {
                final amt = double.tryParse(amtCtrl.text) ?? 0;
                if (amt <= 0 || amt > balDue) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Enter an amount between 0.01 and ${balDue.toStringAsFixed(2)}')),
                  );
                  return;
                }
                final res = await hr.payPayslipInstallment(
                  slip['id'].toString(),
                  runId,
                  amount: amt,
                  paymentMode: mode,
                  transactionRef: refCtrl.text.trim(),
                  notes: notesCtrl.text.trim(),
                );
                if (res != null && ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Record Payment'),
            ),
          ],
        ),
      ),
    );
  }

  void _openApplyLeaveDialog(HrPayrollProvider hr) {
    if (hr.leaveTypes.isEmpty) return;
    String selectedType = hr.leaveTypes.first['id'].toString();
    DateTime start = DateTime.now();
    DateTime end = DateTime.now();
    bool halfDay = false;
    final reasonCtrl = TextEditingController();
    String? err;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setDlg) => AlertDialog(
          title: const Text('Apply for Leave'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (err != null) Text(err!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              DropdownButtonFormField<String>(
                initialValue: selectedType,
                items: hr.leaveTypes.map((lt) => DropdownMenuItem(value: lt['id'].toString(), child: Text('${lt['name']} (${lt['code']})'))).toList(),
                onChanged: (v) => setDlg(() => selectedType = v!),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final p = await showDatePicker(context: c, initialDate: start, firstDate: DateTime(2024), lastDate: DateTime(2030));
                        if (p != null) setDlg(() { start = p; if (end.isBefore(start)) end = start; });
                      },
                      child: Text('From: ${_fmtDate(start)}', style: const TextStyle(fontSize: 11)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final p = await showDatePicker(context: c, initialDate: end, firstDate: start, lastDate: DateTime(2030));
                        if (p != null) setDlg(() => end = p);
                      },
                      child: Text('To: ${_fmtDate(end)}', style: const TextStyle(fontSize: 11)),
                    ),
                  ),
                ],
              ),
              CheckboxListTile(dense: true, value: halfDay, title: const Text('Half Day'), onChanged: (v) => setDlg(() => halfDay = v ?? false)),
              TextField(controller: reasonCtrl, decoration: const InputDecoration(labelText: 'Reason')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final ok = await hr.applyLeave(
                  leaveTypeId: selectedType,
                  startDate: _fmtDate(start),
                  endDate: _fmtDate(end),
                  isHalfDay: halfDay,
                  reason: reasonCtrl.text,
                );
                if (ok && ctx.mounted) {
                  Navigator.pop(ctx);
                } else {
                  setDlg(() => err = hr.errorMessage ?? 'Failed to apply');
                }
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  void _openHolidayDialog(HrPayrollProvider hr) {
    final nameCtrl = TextEditingController();
    DateTime d = DateTime.now();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setDlg) => AlertDialog(
          title: const Text('Add Company Holiday'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Holiday Name')),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () async {
                  final p = await showDatePicker(context: c, initialDate: d, firstDate: DateTime(2024), lastDate: DateTime(2030));
                  if (p != null) setDlg(() => d = p);
                },
                child: Text('Date: ${_fmtDate(d)}'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                final ok = await hr.createHoliday(name: nameCtrl.text, date: _fmtDate(d));
                if (ok && ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _openRegularizationDialog(HrPayrollProvider hr) {
    DateTime d = DateTime.now();
    final inCtrl = TextEditingController(text: '09:30');
    final outCtrl = TextEditingController(text: '18:30');
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setDlg) => AlertDialog(
          title: const Text('Attendance Regularization'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton(
                onPressed: () async {
                  final p = await showDatePicker(context: c, initialDate: d, firstDate: DateTime(2024), lastDate: DateTime.now());
                  if (p != null) setDlg(() => d = p);
                },
                child: Text('Date: ${_fmtDate(d)}'),
              ),
              TextField(controller: inCtrl, decoration: const InputDecoration(labelText: 'Check-In (HH:MM)')),
              TextField(controller: outCtrl, decoration: const InputDecoration(labelText: 'Check-Out (HH:MM)')),
              TextField(controller: reasonCtrl, decoration: const InputDecoration(labelText: 'Reason *')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (reasonCtrl.text.trim().isEmpty) return;
                final ok = await hr.submitRegularization(date: _fmtDate(d), checkIn: inCtrl.text, checkOut: outCtrl.text, reason: reasonCtrl.text);
                if (ok && ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  void _openGeneratePayrollDialog(HrPayrollProvider hr) {
    final now = DateTime.now();
    int selectedMonth = now.month;
    int selectedYear = now.year;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setDlg) => AlertDialog(
          title: const Text('Generate Monthly Payroll'),
          content: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: selectedMonth,
                  decoration: const InputDecoration(labelText: 'Month'),
                  items: List.generate(
                    12,
                    (i) => DropdownMenuItem<int>(value: i + 1, child: Text('Month ${i + 1}')),
                  ),
                  onChanged: (v) {
                    if (v != null) setDlg(() => selectedMonth = v);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: selectedYear,
                  decoration: const InputDecoration(labelText: 'Year'),
                  items: [now.year - 1, now.year, now.year + 1]
                      .map((y) => DropdownMenuItem<int>(value: y, child: Text('$y')))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDlg(() => selectedYear = v);
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(ctx);
                final ok = await ActionLoader.run(
                  context,
                  message: 'Calculating Payroll...',
                  task: () => hr.generatePayrollRun(selectedMonth, selectedYear),
                );
                if (ok != true && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(hr.errorMessage ?? 'Failed to generate payroll'),
                      backgroundColor: const Color(0xFFDC2626),
                    ),
                  );
                }
              },
              child: const Text('Generate'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSalaryStructureDialog(HrPayrollProvider hr) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SalaryStructureScreen()),
    );
  }
}
