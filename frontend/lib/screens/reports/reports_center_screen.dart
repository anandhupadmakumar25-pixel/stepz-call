import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../../core/network/api_client.dart';
import '../../core/widgets/date_range_filter_bar.dart';
import '../../core/widgets/glass/glass_card.dart';
import '../../providers/auth_provider.dart';

class ReportsCenterScreen extends StatefulWidget {
  const ReportsCenterScreen({super.key});

  @override
  State<ReportsCenterScreen> createState() => _ReportsCenterScreenState();
}

class _ReportsCenterScreenState extends State<ReportsCenterScreen> {
  String? _dateFrom;
  String? _dateTo;
  bool _isLoading = false;
  String? _error;
  int _selectedTabIndex = 0;

  Map<String, dynamic> _salesData = {};
  Map<String, dynamic> _callsData = {};
  Map<String, dynamic> _leadsData = {};
  Map<String, dynamic> _attendanceData = {};

  List<String> _visibleReportTabs(BuildContext context) {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return [];
    final tabs = <String>[];
    if (user.hasPermission('reports.sales_billing')) tabs.add('sales');
    if (user.hasPermission('reports.calls_telecaller')) tabs.add('calls');
    if (user.hasPermission('reports.leads_conversion')) tabs.add('leads');
    if (user.hasPermission('reports.hr_attendance')) tabs.add('attendance');
    return tabs;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchActiveReport());
  }

  Future<void> _fetchActiveReport() async {
    final tabs = _visibleReportTabs(context);
    if (tabs.isEmpty) return;
    if (_selectedTabIndex >= tabs.length) _selectedTabIndex = 0;
    final key = tabs[_selectedTabIndex];

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final params = <String>[];
    if (_dateFrom != null) params.add('date_from=$_dateFrom');
    if (_dateTo != null) params.add('date_to=$_dateTo');
    final query = params.isNotEmpty ? '?${params.join('&')}' : '';

    try {
      final res = await ApiClient.get('/analytics/reports/$key/$query');
      if (res is Map<String, dynamic>) {
        setState(() {
          if (key == 'sales') _salesData = res;
          if (key == 'calls') _callsData = res;
          if (key == 'leads') _leadsData = res;
          if (key == 'attendance') _attendanceData = res;
        });
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _exportCsv(String activeKey) async {
    final rows = _getRowsFor(activeKey);
    if (rows.isEmpty) return;
    final headers = rows.first.keys.toList();
    final buf = StringBuffer();
    buf.writeln(headers.join(','));
    for (final r in rows) {
      buf.writeln(headers.map((h) => '"${(r[h] ?? '').toString().replaceAll('"', '""')}"').join(','));
    }
    await Clipboard.setData(ClipboardData(text: buf.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Report CSV copied to clipboard! Ready to paste into Excel / Sheets.'),
        backgroundColor: Color(0xFF059669),
      ),
    );
  }

  Future<void> _exportPdf(String activeKey) async {
    final user = context.read<AuthProvider>().currentUser;
    final rows = _getRowsFor(activeKey);
    final doc = pw.Document();
    final title = {
      'sales': 'Sales & Billing Report',
      'calls': 'Telecaller & Call Performance Report',
      'leads': 'Lead Pipeline Report',
      'attendance': 'HR & Attendance Report',
    }[activeKey] ?? 'Report';

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (ctx) {
          final headers = rows.isNotEmpty ? rows.first.keys.toList() : <String>[];
          return [
            pw.Text(user?.companyName ?? 'Company Report', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
            pw.SizedBox(height: 4),
            pw.Text('$title  |  Range: ${_dateFrom ?? "All Time"} to ${_dateTo ?? "Present"}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
            pw.SizedBox(height: 14),
            if (rows.isEmpty)
              pw.Text('No records found for selected date range.')
            else
              pw.TableHelper.fromTextArray(
                headers: headers.map((h) => h.toUpperCase().replaceAll('_', ' ')).toList(),
                data: rows.map((r) => headers.map((h) => '${r[h] ?? ''}').toList()).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo900),
                cellStyle: const pw.TextStyle(fontSize: 8),
              ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (_) async => doc.save(), name: '${activeKey}_report.pdf');
  }

  List<Map<String, dynamic>> _getRowsFor(String key) {
    if (key == 'sales') return ((_salesData['rows'] as List?) ?? []).whereType<Map<String, dynamic>>().toList();
    if (key == 'calls') return ((_callsData['rows'] as List?) ?? []).whereType<Map<String, dynamic>>().toList();
    if (key == 'leads') return ((_leadsData['by_status'] as List?) ?? []).whereType<Map<String, dynamic>>().toList();
    if (key == 'attendance') return ((_attendanceData['rows'] as List?) ?? []).whereType<Map<String, dynamic>>().toList();
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final tabs = _visibleReportTabs(context);
    final canExport = user?.hasPermission('reports.export') ?? false;

    if (tabs.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Text('You do not have permission to view reports.', style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748B))),
        ),
      );
    }
    if (_selectedTabIndex >= tabs.length) _selectedTabIndex = 0;
    final activeKey = tabs[_selectedTabIndex];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 10,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Reports & Analytics Center', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
                    Text('Date-filtered operational insights across Sales, Calls, Leads & Attendance', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                  ],
                ),
                if (canExport)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _exportCsv(activeKey),
                        icon: const Icon(Icons.table_view_rounded, size: 16),
                        label: const Text('Copy CSV'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A), foregroundColor: Colors.white),
                        onPressed: () => _exportPdf(activeKey),
                        icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                        label: const Text('Export PDF'),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 14),
            GlassCard(
              padding: const EdgeInsets.all(14),
              borderRadius: BorderRadius.circular(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DateRangeFilterBar(
                    onChanged: (from, to) {
                      _dateFrom = from;
                      _dateTo = to;
                      _fetchActiveReport();
                    },
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: tabs.asMap().entries.map((e) {
                      final selected = e.key == _selectedTabIndex;
                      final label = {
                        'sales': 'Sales & Billing',
                        'calls': 'Calls & Telecallers',
                        'leads': 'Lead Pipeline',
                        'attendance': 'HR & Attendance',
                      }[e.value]!;
                      return ChoiceChip(
                        selected: selected,
                        label: Text(
                          label,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                            color: selected ? const Color(0xFF065F46) : const Color(0xFF334155),
                          ),
                        ),
                        selectedColor: const Color(0xFFD1FAE5),
                        onSelected: (_) {
                          setState(() => _selectedTabIndex = e.key);
                          _fetchActiveReport();
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(_error!, style: GoogleFonts.inter(color: const Color(0xFFDC2626), fontWeight: FontWeight.w600)),
              ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildReportBody(activeKey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportBody(String key) {
    final summary = (key == 'sales'
            ? _salesData['summary']
            : key == 'calls'
                ? _callsData['summary']
                : key == 'leads'
                    ? _leadsData['summary']
                    : _attendanceData['summary']) as Map<String, dynamic>? ??
        {};
    final rows = _getRowsFor(key);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (summary.isNotEmpty)
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: summary.entries
                .where((e) => e.key != 'can_view_cst' && e.key != 'currency')
                .map((e) => Container(
                      width: 175,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.key.toUpperCase().replaceAll('_', ' '),
                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${e.value}',
                            style: GoogleFonts.robotoMono(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                    ))
                .toList(),
          ),
        const SizedBox(height: 14),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: rows.isEmpty
                ? Center(child: Text('No records for the selected date range.', style: GoogleFonts.inter(color: const Color(0xFF64748B))))
                : SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                        columns: rows.first.keys
                            .map((k) => DataColumn(
                                  label: Text(
                                    k.toUpperCase().replaceAll('_', ' '),
                                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF334155)),
                                  ),
                                ))
                            .toList(),
                        rows: rows
                            .map((r) => DataRow(
                                  cells: rows.first.keys
                                      .map((k) => DataCell(Text('${r[k] ?? '-'}', style: GoogleFonts.inter(fontSize: 12))))
                                      .toList(),
                                ))
                            .toList(),
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
