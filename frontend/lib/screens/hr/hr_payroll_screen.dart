import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/employee_provider.dart';
import '../../providers/hr_payroll_provider.dart';

class HrPayrollScreen extends StatefulWidget {
  const HrPayrollScreen({super.key});

  @override
  State<HrPayrollScreen> createState() => _HrPayrollScreenState();
}

class _HrPayrollScreenState extends State<HrPayrollScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedRunId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _downloadPayslipPdf(Map<String, dynamic> slip) async {
    final user = context.read<AuthProvider>().currentUser;
    final curr = slip['currency']?.toString() ?? user?.companyCurrency ?? 'INR';
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (ctx) => pw.Container(
          padding: const pw.EdgeInsets.all(20),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.indigo900, width: 1.5),
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
                      pw.Text((user?.companyName ?? 'COMPANY').toUpperCase(), style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                      if (user?.companyAddress != null && user!.companyAddress!.isNotEmpty)
                        pw.Text(user.companyAddress!, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: const pw.BoxDecoration(color: PdfColors.indigo900, borderRadius: pw.BorderRadius.all(pw.Radius.circular(4))),
                    child: pw.Text('PAYSLIP ${slip['month']}/${slip['year']}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                  ),
                ],
              ),
              pw.Divider(color: PdfColors.indigo900, height: 22),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Employee: ${slip['user_name'] ?? ''}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Email: ${slip['user_email'] ?? ''}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Working Days: ${slip['working_days']}  |  Present: ${slip['present_days']}', style: const pw.TextStyle(fontSize: 9.5)),
                      pw.Text('Paid Leave: ${slip['paid_leave_days']}  |  LOP Days: ${slip['lop_days']}', style: const pw.TextStyle(fontSize: 9.5)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 18),
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
                          _pdfRow('Statutory (PF/ESI/Tax)', '$curr ${slip['statutory_deductions']}'),
                          pw.Divider(),
                          _pdfRow('Status', '${slip['status']}', bold: true),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 18),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: const pw.BoxDecoration(color: PdfColors.indigo50, borderRadius: pw.BorderRadius.all(pw.Radius.circular(6))),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('NET PAYABLE', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                    pw.Text('$curr ${slip['net_pay']}', style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await Printing.layoutPdf(onLayout: (_) async => doc.save(), name: 'Payslip_${slip['month']}_${slip['year']}.pdf');
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

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('HR & Leave Management', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
            Text('Leave balances, holiday calendar & attendance regularization', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
              child: TabBar(
                controller: _tabController,
                labelColor: const Color(0xFF1E3A8A),
                unselectedLabelColor: const Color(0xFF64748B),
                indicatorColor: const Color(0xFF1E3A8A),
                tabs: const [
                  Tab(text: 'Leaves & Holidays'),
                  Tab(text: 'Regularization'),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildLeavesHolidaysTab(hr, user),
                  _buildRegularizationTab(hr, user),
                ],
              ),
            ),
          ],
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

  // ignore: unused_element
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
                  label: const Text('Generate Current Month Payroll'),
                  onPressed: () async {
                    final now = DateTime.now();
                    final ok = await hr.generatePayrollRun(now.month, now.year);
                    if (!ok && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(hr.errorMessage ?? 'Failed to generate payroll'), backgroundColor: const Color(0xFFDC2626)));
                    }
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
                    subtitle: Text('Gross: ${s['currency']} ${s['gross_salary']}  |  Deductions: ${s['currency']} ${s['total_fixed_deductions']}', style: GoogleFonts.inter(fontSize: 12)),
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
                  subtitle: Text('${run['payslip_count']} Payslips · Status: $st', style: GoogleFonts.inter(fontSize: 12)),
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
                          onPressed: () => hr.actionPayrollRun(rid, 'MARK_PAID'),
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
            Text('Generated Payslips', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800)),
            ...hr.activeRunPayslips.map((slip) => Card(
                  child: ListTile(
                    title: Text('${slip['user_name']} — Net: ${slip['currency']} ${slip['net_pay']}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700)),
                    subtitle: Text('Present: ${slip['present_days']} | Paid Leave: ${slip['paid_leave_days']} | LOP: ${slip['lop_days']}', style: GoogleFonts.inter(fontSize: 11)),
                    trailing: IconButton(
                      icon: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF1E3A8A)),
                      onPressed: () => _downloadPayslipPdf(slip),
                    ),
                  ),
                )),
          ],
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildMyPayslipsTab(HrPayrollProvider hr) {
    if (hr.myPayslips.isEmpty) {
      return Center(child: Text('No finalized payslips available yet.', style: GoogleFonts.inter(color: const Color(0xFF64748B))));
    }
    return ListView.builder(
      itemCount: hr.myPayslips.length,
      itemBuilder: (ctx, i) {
        final slip = hr.myPayslips[i];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.receipt_long_rounded, color: Color(0xFF1E3A8A)),
            title: Text('Payslip ${slip['month']}/${slip['year']} — Net Pay: ${slip['currency']} ${slip['net_pay']}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700)),
            subtitle: Text('Status: ${slip['status']} · Present: ${slip['present_days']} days', style: GoogleFonts.inter(fontSize: 12)),
            trailing: ElevatedButton.icon(
              icon: const Icon(Icons.download_rounded, size: 16),
              label: const Text('PDF'),
              onPressed: () => _downloadPayslipPdf(slip),
            ),
          ),
        );
      },
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

  void _openSalaryStructureDialog(HrPayrollProvider hr) {
    final emps = context.read<EmployeeProvider>().employees;
    if (emps.isEmpty) return;
    String empId = emps.first.id;
    final basicCtrl = TextEditingController(text: '15000');
    final hraCtrl = TextEditingController(text: '5000');
    final allowCtrl = TextEditingController(text: '3000');
    final pfCtrl = TextEditingController(text: '1800');
    final taxCtrl = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setDlg) => AlertDialog(
          title: const Text('Configure Employee Salary Structure'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: empId,
                  items: emps.map<DropdownMenuItem<String>>((e) => DropdownMenuItem<String>(value: e.id, child: Text(e.fullName))).toList(),
                  onChanged: (v) => setDlg(() => empId = v!),
                ),
                TextField(controller: basicCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Basic Salary')),
                TextField(controller: hraCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'HRA')),
                TextField(controller: allowCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Allowances')),
                TextField(controller: pfCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'PF / Statutory Deduction')),
                TextField(controller: taxCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Tax Deduction')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final ok = await hr.saveSalaryStructure({
                  'user': empId,
                  'basic_salary': double.tryParse(basicCtrl.text) ?? 0,
                  'hra': double.tryParse(hraCtrl.text) ?? 0,
                  'allowances': double.tryParse(allowCtrl.text) ?? 0,
                  'pf_deduction': double.tryParse(pfCtrl.text) ?? 0,
                  'tax_deduction': double.tryParse(taxCtrl.text) ?? 0,
                });
                if (ok && ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save Structure'),
            ),
          ],
        ),
      ),
    );
  }
}
