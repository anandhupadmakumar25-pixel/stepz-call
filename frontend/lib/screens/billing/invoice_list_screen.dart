import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/widgets/glass/app_background.dart';
import '../../core/widgets/glass/glass_card.dart';
import '../../core/widgets/glass/gradient_button.dart';
import '../../core/services/pdf_invoice_service.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../models/invoice_model.dart';
import '../../models/quotation_model.dart';
import '../../providers/billing_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/company_provider.dart';
import '../quotations/quotation_form_dialog.dart';
import '../quotations/quotation_detail_dialog.dart';
import '../quotations/convert_quotation_dialog.dart';
import 'record_payment_dialog.dart';
import 'invoice_detail_dialog.dart';

class InvoiceListScreen extends StatefulWidget {
  final int initialTab;
  const InvoiceListScreen({super.key, this.initialTab = 0});

  @override
  State<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends State<InvoiceListScreen> {
  // 0 = Bills & Invoices (Fixed Price), 1 = Quotations & Estimates (Approximate)
  late int _selectedViewTab;
  String _selectedInvoiceStatus = 'ALL';
  String _selectedQuoteStatus = 'ALL';
  final TextEditingController _searchController = TextEditingController();

  void _printInvoiceWithBranding(InvoiceModel invoice) {
    final authUser = context.read<AuthProvider>().currentUser;
    final comp = context.read<CompanyProvider>().activeCompanyDetail;
    final String name = comp?.name.isNotEmpty == true ? comp!.name : ((authUser?.companyName?.isNotEmpty == true) ? authUser!.companyName! : 'Stepz Telecaller CRM');
    PdfInvoiceService.printInvoice(
      invoice,
      companyName: name,
      companyPhone: comp?.contactPhone.isNotEmpty == true ? comp!.contactPhone : authUser?.companyPhone,
      companyEmail: comp?.contactEmail.isNotEmpty == true ? comp!.contactEmail : authUser?.companyEmail,
      companyAddress: comp?.address.isNotEmpty == true ? comp!.address : authUser?.companyAddress,
      companyGstin: comp?.gstin.isNotEmpty == true ? comp!.gstin : authUser?.companyGstin,
      companyWebsite: comp?.website.isNotEmpty == true ? comp!.website : authUser?.companyWebsite,
      companyLogo: comp?.logo.isNotEmpty == true ? comp!.logo : authUser?.companyLogo,
    );
  }

  void _printQuotationWithBranding(QuotationModel quotation) {
    final authUser = context.read<AuthProvider>().currentUser;
    final comp = context.read<CompanyProvider>().activeCompanyDetail;
    final String name = comp?.name.isNotEmpty == true ? comp!.name : ((authUser?.companyName?.isNotEmpty == true) ? authUser!.companyName! : 'Stepz Telecaller CRM');
    PdfInvoiceService.printQuotation(
      quotation,
      companyName: name,
      companyPhone: comp?.contactPhone.isNotEmpty == true ? comp!.contactPhone : authUser?.companyPhone,
      companyEmail: comp?.contactEmail.isNotEmpty == true ? comp!.contactEmail : authUser?.companyEmail,
      companyAddress: comp?.address.isNotEmpty == true ? comp!.address : authUser?.companyAddress,
      companyGstin: comp?.gstin.isNotEmpty == true ? comp!.gstin : authUser?.companyGstin,
      companyWebsite: comp?.website.isNotEmpty == true ? comp!.website : authUser?.companyWebsite,
      companyLogo: comp?.logo.isNotEmpty == true ? comp!.logo : authUser?.companyLogo,
    );
  }

  @override
  void initState() {
    super.initState();
    _selectedViewTab = widget.initialTab;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void didUpdateWidget(covariant InvoiceListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) {
      setState(() {
        _selectedViewTab = widget.initialTab;
      });
    }
  }

  Future<void> _loadData() async {
    final provider = context.read<BillingProvider>();
    await provider.fetchBillingOverview();
    await Future.wait([
      provider.fetchInvoices(status: _selectedInvoiceStatus == 'ALL' ? null : _selectedInvoiceStatus),
      provider.fetchQuotations(status: _selectedQuoteStatus == 'ALL' ? null : _selectedQuoteStatus),
    ]);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleConvertQuotation(QuotationModel quote) async {
    final invoice = await showDialog<InvoiceModel>(
      context: context,
      builder: (_) => ConvertQuotationDialog(quotation: quote),
    );

    if (invoice != null && mounted) {
      // Switch to Invoices view tab to show the new bill immediately!
      setState(() => _selectedViewTab = 0);
      _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fixed Price Invoice ${invoice.invoiceNumber} generated successfully!'),
          backgroundColor: const Color(0xFF10B981),
          action: SnackBarAction(
            label: 'Record Payment',
            textColor: Colors.white,
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => RecordPaymentDialog(invoice: invoice),
              ).then((_) => _loadData());
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BillingProvider>();
    final auth = context.watch<AuthProvider>();
    final isTelecaller = auth.currentUser?.isEmployee ?? false;
    final kpi = provider.billingOverview;
    final isMobile = ResponsiveLayout.isMobile(context);

    final searchQuery = _searchController.text.trim().toLowerCase();

    final filteredInvoices = provider.invoices.where((inv) {
      if (searchQuery.isEmpty) return true;
      return inv.invoiceNumber.toLowerCase().contains(searchQuery) ||
          inv.customerName.toLowerCase().contains(searchQuery) ||
          inv.customerPhone.contains(searchQuery);
    }).toList();

    final filteredQuotations = provider.quotations.where((q) {
      if (searchQuery.isEmpty) return true;
      return q.quotationNumber.toLowerCase().contains(searchQuery) ||
          q.customerName.toLowerCase().contains(searchQuery) ||
          q.customerPhone.contains(searchQuery);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: AppBackground(
        preset: AppBackgroundPreset.pastelSky,
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _loadData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(isMobile ? 14 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Header Row
                  isMobile
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF059669).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF059669), size: 20),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Billing & Invoices',
                                        style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                                      ),
                                      Text(
                                        'Customer bills, quotes & receipts',
                                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.refresh_rounded, color: Color(0xFF2563EB), size: 20),
                                  onPressed: _loadData,
                                  tooltip: 'Refresh',
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF059669),
                                      side: const BorderSide(color: Color(0xFF059669)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                    ),
                                    icon: const Icon(Icons.request_quote_rounded, size: 14),
                                    label: Text('+ Quotation', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12)),
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (_) => const QuotationFormDialog(isBill: false),
                                      ).then((_) => _loadData());
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: GradientPrimaryButton(
                                    text: '+ Bill / Invoice',
                                    icon: Icons.add_rounded,
                                    gradient: const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)]),
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (_) => const QuotationFormDialog(isBill: true),
                                      ).then((_) {
                                        setState(() => _selectedViewTab = 0);
                                        _loadData();
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF059669).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF059669), size: 24),
                                ),
                                const SizedBox(width: 14),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Billing & Invoices',
                                      style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                                    ),
                                    Text(
                                      'Manage customer bills, invoices, quotations, receipts, and receivables',
                                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.refresh_rounded, color: Color(0xFF2563EB)),
                                  onPressed: _loadData,
                                  tooltip: 'Refresh',
                                ),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF059669),
                                    side: const BorderSide(color: Color(0xFF059669)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  ),
                                  icon: const Icon(Icons.request_quote_rounded, size: 16),
                                  label: Text('+ New Quotation', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (_) => const QuotationFormDialog(isBill: false),
                                    ).then((_) => _loadData());
                                  },
                                ),
                                GradientPrimaryButton(
                                  text: '+ New Bill / Invoice',
                                  icon: Icons.add_rounded,
                                  gradient: const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)]),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (_) => const QuotationFormDialog(isBill: true),
                                    ).then((_) {
                                      setState(() => _selectedViewTab = 0);
                                      _loadData();
                                    });
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                  const SizedBox(height: 20),

                  // KPI Cards Row
                  isMobile
                      ? Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildKpiCard(
                                    title: isTelecaller ? 'My Invoiced' : 'Total Invoiced',
                                    value: 'Rs. ${(kpi?.totalBilled ?? 0.0).toStringAsFixed(2)}',
                                    subtitle: '${kpi?.invoiceCount ?? 0} invoices',
                                    icon: Icons.receipt_rounded,
                                    accentColor: const Color(0xFF2563EB),
                                    isMobile: true,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildKpiCard(
                                    title: isTelecaller ? 'My Collected' : 'Total Collected',
                                    value: 'Rs. ${(kpi?.totalCollected ?? 0.0).toStringAsFixed(2)}',
                                    subtitle: '${kpi?.paidInvoiceCount ?? 0} settled',
                                    icon: Icons.check_circle_outline_rounded,
                                    accentColor: const Color(0xFF10B981),
                                    isMobile: true,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildKpiCard(
                                    title: isTelecaller ? 'Pending Due' : 'Pending Receivables',
                                    value: 'Rs. ${(kpi?.pendingReceivables ?? 0.0).toStringAsFixed(2)}',
                                    subtitle: '${kpi?.pendingInvoiceCount ?? 0} pending',
                                    icon: Icons.pending_actions_rounded,
                                    accentColor: const Color(0xFFDC2626),
                                    isMobile: true,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildKpiCard(
                                    title: isTelecaller ? 'Active Quotes' : 'Active Quotations',
                                    value: 'Rs. ${(kpi?.totalQuotationValue ?? 0.0).toStringAsFixed(2)}',
                                    subtitle: '${kpi?.quotationCount ?? 0} quotes sent',
                                    icon: Icons.request_quote_rounded,
                                    accentColor: const Color(0xFF8B5CF6),
                                    isMobile: true,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        )
                      : Wrap(
                          spacing: 16,
                          runSpacing: 14,
                          children: [
                            _buildKpiCard(
                              title: isTelecaller ? 'My Invoiced Total' : 'Total Invoiced',
                              value: 'Rs. ${(kpi?.totalBilled ?? 0.0).toStringAsFixed(2)}',
                              subtitle: '${kpi?.invoiceCount ?? 0} invoices',
                              icon: Icons.receipt_rounded,
                              accentColor: const Color(0xFF2563EB),
                            ),
                            _buildKpiCard(
                              title: isTelecaller ? 'My Collected Amount' : 'Total Collected',
                              value: 'Rs. ${(kpi?.totalCollected ?? 0.0).toStringAsFixed(2)}',
                              subtitle: '${kpi?.paidInvoiceCount ?? 0} settled',
                              icon: Icons.check_circle_outline_rounded,
                              accentColor: const Color(0xFF10B981),
                            ),
                            _buildKpiCard(
                              title: isTelecaller ? 'My Pending Balance' : 'Pending Receivables',
                              value: 'Rs. ${(kpi?.pendingReceivables ?? 0.0).toStringAsFixed(2)}',
                              subtitle: '${kpi?.pendingInvoiceCount ?? 0} pending',
                              icon: Icons.pending_actions_rounded,
                              accentColor: const Color(0xFFDC2626),
                            ),
                            _buildKpiCard(
                              title: isTelecaller ? 'My Active Quotes' : 'Active Quotations',
                              value: 'Rs. ${(kpi?.totalQuotationValue ?? 0.0).toStringAsFixed(2)}',
                              subtitle: '${kpi?.quotationCount ?? 0} quotes sent',
                              icon: Icons.request_quote_rounded,
                              accentColor: const Color(0xFF8B5CF6),
                            ),
                          ],
                        ),
                  const SizedBox(height: 24),

                  // Segment Tab Switcher: Bills vs Quotations
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _selectedViewTab = 0),
                            borderRadius: BorderRadius.circular(9),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _selectedViewTab == 0 ? const Color(0xFF2563EB) : Colors.transparent,
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.receipt_long_rounded, size: 18, color: _selectedViewTab == 0 ? Colors.white : const Color(0xFF64748B)),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Fixed Price Bills & Invoices (${provider.invoices.length})',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: _selectedViewTab == 0 ? FontWeight.w700 : FontWeight.w600,
                                      color: _selectedViewTab == 0 ? Colors.white : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _selectedViewTab = 1),
                            borderRadius: BorderRadius.circular(9),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _selectedViewTab == 1 ? const Color(0xFF059669) : Colors.transparent,
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.request_quote_rounded, size: 18, color: _selectedViewTab == 1 ? Colors.white : const Color(0xFF64748B)),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Quotations & Estimates (${provider.quotations.length})',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: _selectedViewTab == 1 ? FontWeight.w700 : FontWeight.w600,
                                      color: _selectedViewTab == 1 ? Colors.white : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Search & Filter Tabs
                  GlassCard(
                    blur: 16,
                    opacity: 0.95,
                    borderRadius: BorderRadius.circular(16),
                    borderColor: const Color(0xFFE2E8F0),
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            // Search bar
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                onChanged: (_) => setState(() {}),
                                style: GoogleFonts.inter(fontSize: 13),
                                decoration: InputDecoration(
                                  hintText: _selectedViewTab == 0
                                      ? 'Search by Invoice #, Customer Name, or Phone...'
                                      : 'Search by Quotation #, Customer Name, or Phone...',
                                  hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                                  prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                                  suffixIcon: _searchController.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear_rounded, size: 16),
                                          onPressed: () {
                                            _searchController.clear();
                                            setState(() {});
                                          },
                                        )
                                      : null,
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Filter Pills based on active tab
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _selectedViewTab == 0
                                ? [
                                    _buildFilterPill('ALL', 'All Invoices', _selectedInvoiceStatus, (val) {
                                      setState(() => _selectedInvoiceStatus = val);
                                      _loadData();
                                    }, const Color(0xFF2563EB)),
                                    const SizedBox(width: 8),
                                    _buildFilterPill('PENDING', 'Pending Payment', _selectedInvoiceStatus, (val) {
                                      setState(() => _selectedInvoiceStatus = val);
                                      _loadData();
                                    }, const Color(0xFFDC2626)),
                                    const SizedBox(width: 8),
                                    _buildFilterPill('PARTIAL', 'Partially Paid', _selectedInvoiceStatus, (val) {
                                      setState(() => _selectedInvoiceStatus = val);
                                      _loadData();
                                    }, const Color(0xFFD97706)),
                                    const SizedBox(width: 8),
                                    _buildFilterPill('PAID', 'Fully Paid', _selectedInvoiceStatus, (val) {
                                      setState(() => _selectedInvoiceStatus = val);
                                      _loadData();
                                    }, const Color(0xFF059669)),
                                  ]
                                : [
                                    _buildFilterPill('ALL', 'All Quotations', _selectedQuoteStatus, (val) {
                                      setState(() => _selectedQuoteStatus = val);
                                      _loadData();
                                    }, const Color(0xFF059669)),
                                    const SizedBox(width: 8),
                                    _buildFilterPill('SENT', 'Sent to Customer', _selectedQuoteStatus, (val) {
                                      setState(() => _selectedQuoteStatus = val);
                                      _loadData();
                                    }, const Color(0xFF2563EB)),
                                    const SizedBox(width: 8),
                                    _buildFilterPill('CONVERTED', 'Converted to Bill', _selectedQuoteStatus, (val) {
                                      setState(() => _selectedQuoteStatus = val);
                                      _loadData();
                                    }, const Color(0xFF059669)),
                                    const SizedBox(width: 8),
                                    _buildFilterPill('ACCEPTED', 'Approved', _selectedQuoteStatus, (val) {
                                      setState(() => _selectedQuoteStatus = val);
                                      _loadData();
                                    }, const Color(0xFF10B981)),
                                    const SizedBox(width: 8),
                                    _buildFilterPill('DRAFT', 'Drafts', _selectedQuoteStatus, (val) {
                                      setState(() => _selectedQuoteStatus = val);
                                      _loadData();
                                    }, const Color(0xFF64748B)),
                                  ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // TAB CONTENT
                  if (provider.isLoading)
                    const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
                  else if (_selectedViewTab == 0) ...[
                    // INVOICES LIST
                    if (filteredInvoices.isEmpty)
                      _buildEmptyState(
                        icon: Icons.receipt_outlined,
                        title: 'No invoices found in this view',
                        subtitle: 'Convert an existing quotation from the Quotations tab or click "+ New Bill / Invoice" above.',
                        actionText: '+ Create Bill / Invoice',
                        onAction: () {
                          showDialog(
                            context: context,
                            builder: (_) => const QuotationFormDialog(isBill: true),
                          ).then((_) => _loadData());
                        },
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredInvoices.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder: (context, idx) {
                          final invoice = filteredInvoices[idx];
                          return _buildInvoiceCard(invoice, isMobile);
                        },
                      ),
                  ] else ...[
                    // QUOTATIONS LIST
                    if (filteredQuotations.isEmpty)
                      _buildEmptyState(
                        icon: Icons.request_quote_outlined,
                        title: 'No quotations found in this view',
                        subtitle: 'Generate sales estimates with product catalog auto-saving to send to leads.',
                        actionText: '+ Create Quotation',
                        onAction: () {
                          showDialog(
                            context: context,
                            builder: (_) => const QuotationFormDialog(isBill: false),
                          ).then((_) => _loadData());
                        },
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredQuotations.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder: (context, idx) {
                          final quote = filteredQuotations[idx];
                          return _buildQuotationCard(quote, isMobile);
                        },
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionText,
    required VoidCallback onAction,
  }) {
    return GlassCard(
      blur: 16,
      opacity: 0.9,
      borderRadius: BorderRadius.circular(16),
      borderColor: const Color(0xFFE2E8F0),
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: const Color(0xFF94A3B8)),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF475569)),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: Text(actionText, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12)),
            onPressed: onAction,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPill(
    String status,
    String label,
    String currentSelection,
    ValueChanged<String> onSelected,
    Color activeColor,
  ) {
    final isSelected = currentSelection == status;
    return InkWell(
      onTap: () => onSelected(status),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? activeColor : const Color(0xFFE2E8F0)),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    bool isMobile = false,
  }) {
    return Container(
      width: isMobile ? null : 240,
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
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
                  title,
                  style: GoogleFonts.inter(
                    fontSize: isMobile ? 11 : 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: isMobile ? 15 : 18, color: accentColor),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 6 : 8),
          Text(
            value,
            style: GoogleFonts.robotoMono(
              fontSize: isMobile ? 14 : 18,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: isMobile ? 10 : 11,
              color: const Color(0xFF94A3B8),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceCard(InvoiceModel invoice, bool isMobile) {
    final isPaid = invoice.paymentStatus == 'PAID';
    final isPartial = invoice.paymentStatus == 'PARTIAL';

    Color badgeBg = isPaid
        ? const Color(0xFFD1FAE5)
        : isPartial
            ? const Color(0xFFFEF3C7)
            : const Color(0xFFFEE2E2);

    Color badgeFg = isPaid
        ? const Color(0xFF047857)
        : isPartial
            ? const Color(0xFFB45309)
            : const Color(0xFFB91C1C);

    return GlassCard(
      blur: 16,
      opacity: 0.95,
      borderRadius: BorderRadius.circular(16),
      borderColor: const Color(0xFFE2E8F0),
      padding: EdgeInsets.all(isMobile ? 14 : 18),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(isMobile ? 8 : 10),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isPaid ? Icons.check_circle_rounded : Icons.receipt_rounded,
                  color: badgeFg,
                  size: isMobile ? 18 : 22,
                ),
              ),
              const SizedBox(width: 12),
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
                          invoice.invoiceNumber,
                          style: GoogleFonts.robotoMono(fontSize: isMobile ? 13.5 : 15, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
                          decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(6)),
                          child: Text(
                            invoice.paymentStatus,
                            style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w800, color: badgeFg),
                          ),
                        ),
                        if (invoice.quotationNumber.isNotEmpty)
                          Text('Ref: ${invoice.quotationNumber}', style: GoogleFonts.robotoMono(fontSize: 10.5, color: const Color(0xFF64748B))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      invoice.customerName,
                      style: GoogleFonts.inter(fontSize: isMobile ? 13 : 14, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: 10,
                      runSpacing: 3,
                      children: [
                        if (invoice.customerPhone.isNotEmpty)
                          Text('📞 ${invoice.customerPhone}', style: GoogleFonts.robotoMono(fontSize: 10.5, color: const Color(0xFF64748B))),
                        Text('📅 ${invoice.date}', style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B))),
                        if (invoice.paymentMode.isNotEmpty)
                          Text('💳 ${invoice.paymentMode}', style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF059669))),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Totals Block
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    margin: const EdgeInsets.only(bottom: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1FAE5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'FIXED PRICE',
                      style: GoogleFonts.inter(fontSize: 7.5, fontWeight: FontWeight.w800, color: const Color(0xFF047857)),
                    ),
                  ),
                  Text('Rs. ${invoice.grandTotal.toStringAsFixed(2)}', style: GoogleFonts.robotoMono(fontSize: isMobile ? 14 : 16, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
                  const SizedBox(height: 2),
                  if (invoice.balanceDue > 0)
                    Text(
                      'Due: Rs. ${invoice.balanceDue.toStringAsFixed(2)}',
                      style: GoogleFonts.robotoMono(fontSize: isMobile ? 11 : 12, fontWeight: FontWeight.w700, color: const Color(0xFFDC2626)),
                    )
                  else
                    Text(
                      'Paid in Full',
                      style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: const Color(0xFF059669)),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Color(0xFFF1F5F9), height: 1),
          const SizedBox(height: 10),

          // Actions Row
          isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              elevation: 0,
                            ),
                            icon: const Icon(Icons.chat_rounded, size: 14),
                            label: Text('WhatsApp', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700)),
                            onPressed: () => PdfInvoiceService.shareInvoiceToWhatsApp(invoice),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            icon: const Icon(Icons.print_outlined, size: 14, color: Color(0xFF475569)),
                            label: Text('Print / PDF', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF475569))),
                            onPressed: () => _printInvoiceWithBranding(invoice),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            icon: const Icon(Icons.visibility_outlined, size: 14, color: Color(0xFF475569)),
                            label: Text('Details', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF475569))),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (_) => InvoiceDetailDialog(invoice: invoice),
                              ).then((_) => _loadData());
                            },
                          ),
                        ),
                        if (!isPaid) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                elevation: 0,
                              ),
                              icon: const Icon(Icons.payment_rounded, size: 14),
                              label: Text('Record Pay', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700)),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => RecordPaymentDialog(invoice: invoice),
                                ).then((_) => _loadData());
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.chat_rounded, size: 15),
                      label: Text('WhatsApp Receipt', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700)),
                      onPressed: () => PdfInvoiceService.shareInvoiceToWhatsApp(invoice),
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          icon: const Icon(Icons.print_outlined, size: 15, color: Color(0xFF475569)),
                          label: Text('Print / PDF', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF475569))),
                          onPressed: () => _printInvoiceWithBranding(invoice),
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          icon: const Icon(Icons.visibility_outlined, size: 15, color: Color(0xFF475569)),
                          label: Text('View Details', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF475569))),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => InvoiceDetailDialog(invoice: invoice),
                            ).then((_) => _loadData());
                          },
                        ),
                        if (!isPaid)
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              elevation: 0,
                            ),
                            icon: const Icon(Icons.payment_rounded, size: 15),
                            label: Text('Record Payment', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700)),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (_) => RecordPaymentDialog(invoice: invoice),
                              ).then((_) => _loadData());
                            },
                          ),
                      ],
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildQuotationCard(QuotationModel quote, bool isMobile) {
    final isConverted = quote.status == 'CONVERTED';
    final isAccepted = quote.status == 'ACCEPTED';

    Color badgeBg = isConverted
        ? const Color(0xFFD1FAE5)
        : isAccepted
            ? const Color(0xFFDCFCE7)
            : const Color(0xFFEFF6FF);

    Color badgeFg = isConverted
        ? const Color(0xFF047857)
        : isAccepted
            ? const Color(0xFF15803D)
            : const Color(0xFF1D4ED8);

    String statusLabel = isConverted
        ? 'CONVERTED TO BILL'
        : isAccepted
            ? 'ACCEPTED'
            : quote.status;

    return GlassCard(
      blur: 16,
      opacity: 0.95,
      borderRadius: BorderRadius.circular(16),
      borderColor: const Color(0xFFE2E8F0),
      padding: EdgeInsets.all(isMobile ? 14 : 18),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(isMobile ? 8 : 10),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isConverted ? Icons.check_circle_rounded : Icons.request_quote_rounded,
                  color: badgeFg,
                  size: isMobile ? 18 : 22,
                ),
              ),
              const SizedBox(width: 12),
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
                          quote.quotationNumber,
                          style: GoogleFonts.robotoMono(fontSize: isMobile ? 13.5 : 15, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
                          decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(6)),
                          child: Text(
                            statusLabel,
                            style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w800, color: badgeFg),
                          ),
                        ),
                        if (quote.items.isNotEmpty)
                          Text('${quote.items.length} items', style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      quote.customerName,
                      style: GoogleFonts.inter(fontSize: isMobile ? 13 : 14, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: 10,
                      runSpacing: 3,
                      children: [
                        if (quote.customerPhone.isNotEmpty)
                          Text('📞 ${quote.customerPhone}', style: GoogleFonts.robotoMono(fontSize: 10.5, color: const Color(0xFF64748B))),
                        Text('📅 ${quote.date}', style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B))),
                        if (quote.validUntil != null)
                          Text('⏳ Valid: ${quote.validUntil}', style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFFD97706))),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Totals Block
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    margin: const EdgeInsets.only(bottom: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'APPROX ESTIMATE',
                      style: GoogleFonts.inter(fontSize: 7.5, fontWeight: FontWeight.w800, color: const Color(0xFFB45309)),
                    ),
                  ),
                  Text('Rs. ${quote.grandTotal.toStringAsFixed(2)}', style: GoogleFonts.robotoMono(fontSize: isMobile ? 14 : 16, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
                  const SizedBox(height: 2),
                  Text(
                    isConverted ? 'Locked to Fixed Bill' : 'Approximate',
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: isConverted ? const Color(0xFF059669) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Color(0xFFF1F5F9), height: 1),
          const SizedBox(height: 10),

          // Actions Row
          isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              elevation: 0,
                            ),
                            icon: const Icon(Icons.chat_rounded, size: 14),
                            label: Text('WhatsApp', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700)),
                            onPressed: () => PdfInvoiceService.shareQuotationToWhatsApp(quote),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            icon: const Icon(Icons.print_outlined, size: 14, color: Color(0xFF475569)),
                            label: Text('Print / PDF', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF475569))),
                            onPressed: () => _printQuotationWithBranding(quote),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            icon: const Icon(Icons.visibility_outlined, size: 14, color: Color(0xFF475569)),
                            label: Text('Details', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF475569))),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (_) => QuotationDetailDialog(quotation: quote),
                              ).then((_) => _loadData());
                            },
                          ),
                        ),
                        if (!isConverted) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                side: const BorderSide(color: Color(0xFF3B82F6)),
                              ),
                              icon: const Icon(Icons.edit_outlined, size: 14, color: Color(0xFF2563EB)),
                              label: Text('Edit', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF2563EB))),
                              onPressed: () async {
                                final res = await showDialog(
                                  context: context,
                                  builder: (_) => QuotationFormDialog(quotationToEdit: quote),
                                );
                                if (res != null) {
                                  _loadData();
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF059669),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                elevation: 0,
                              ),
                              icon: const Icon(Icons.receipt_long_rounded, size: 14),
                              label: Text('Convert', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700)),
                              onPressed: () => _handleConvertQuotation(quote),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.chat_rounded, size: 15),
                      label: Text('WhatsApp Quote', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700)),
                      onPressed: () => PdfInvoiceService.shareQuotationToWhatsApp(quote),
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          icon: const Icon(Icons.print_outlined, size: 15, color: Color(0xFF475569)),
                          label: Text('Print / PDF', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF475569))),
                          onPressed: () => _printQuotationWithBranding(quote),
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          icon: const Icon(Icons.visibility_outlined, size: 15, color: Color(0xFF475569)),
                          label: Text('View Details', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF475569))),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => QuotationDetailDialog(quotation: quote),
                            ).then((_) => _loadData());
                          },
                        ),
                        if (!isConverted) ...[
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              side: const BorderSide(color: Color(0xFF3B82F6)),
                            ),
                            icon: const Icon(Icons.edit_outlined, size: 15, color: Color(0xFF2563EB)),
                            label: Text('Edit Quote', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF2563EB))),
                            onPressed: () async {
                              final res = await showDialog(
                                context: context,
                                builder: (_) => QuotationFormDialog(quotationToEdit: quote),
                              );
                              if (res != null) {
                                _loadData();
                              }
                            },
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF059669),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              elevation: 0,
                            ),
                            icon: const Icon(Icons.receipt_long_rounded, size: 15),
                            label: Text('Convert to Fixed Bill', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700)),
                            onPressed: () => _handleConvertQuotation(quote),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
        ],
      ),
    );
  }
}
