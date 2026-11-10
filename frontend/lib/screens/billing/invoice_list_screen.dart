import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/widgets/glass/app_background.dart';
import '../../core/widgets/glass/glass_card.dart';
import '../../core/widgets/glass/gradient_button.dart';
import '../../core/services/pdf_invoice_service.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../models/invoice_model.dart';
import '../../providers/billing_provider.dart';
import '../../providers/auth_provider.dart';
import '../quotations/quotation_form_dialog.dart';
import 'record_payment_dialog.dart';

class InvoiceListScreen extends StatefulWidget {
  const InvoiceListScreen({super.key});

  @override
  State<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends State<InvoiceListScreen> {
  String _selectedStatus = 'ALL';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final provider = context.read<BillingProvider>();
    await provider.fetchBillingOverview();
    await provider.fetchInvoices(status: _selectedStatus == 'ALL' ? null : _selectedStatus);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
                  Row(
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
                                style: GoogleFonts.inter(fontSize: isMobile ? 20 : 24, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                              ),
                              Text(
                                'Manage customer bills, invoices, receipts, and receivables',
                                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Wrap(
                        spacing: 10,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF2563EB)),
                            onPressed: _loadData,
                            tooltip: 'Refresh',
                          ),
                          GradientPrimaryButton(
                            text: '+ New Bill / Quote',
                            icon: Icons.add_rounded,
                            gradient: const LinearGradient(colors: [Color(0xFF059669), Color(0xFF10B981)]),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (_) => const QuotationFormDialog(),
                              ).then((_) => _loadData());
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // KPI Cards Row
                  Wrap(
                    spacing: 16,
                    runSpacing: 14,
                    children: [
                      _buildKpiCard(
                        title: isTelecaller ? 'My Invoiced Total' : 'Total Invoiced',
                        value: '₹${(kpi?.totalBilled ?? 0.0).toStringAsFixed(2)}',
                        subtitle: '${kpi?.invoiceCount ?? 0} invoices',
                        icon: Icons.receipt_rounded,
                        accentColor: const Color(0xFF2563EB),
                      ),
                      _buildKpiCard(
                        title: isTelecaller ? 'My Collected Amount' : 'Total Collected',
                        value: '₹${(kpi?.totalCollected ?? 0.0).toStringAsFixed(2)}',
                        subtitle: '${kpi?.paidInvoiceCount ?? 0} settled',
                        icon: Icons.check_circle_outline_rounded,
                        accentColor: const Color(0xFF10B981),
                      ),
                      _buildKpiCard(
                        title: isTelecaller ? 'My Pending Balance' : 'Pending Receivables',
                        value: '₹${(kpi?.pendingReceivables ?? 0.0).toStringAsFixed(2)}',
                        subtitle: '${kpi?.pendingInvoiceCount ?? 0} pending',
                        icon: Icons.pending_actions_rounded,
                        accentColor: const Color(0xFFDC2626),
                      ),
                      _buildKpiCard(
                        title: isTelecaller ? 'My Active Quotes' : 'Active Quotations',
                        value: '₹${(kpi?.totalQuotationValue ?? 0.0).toStringAsFixed(2)}',
                        subtitle: '${kpi?.quotationCount ?? 0} quotes sent',
                        icon: Icons.request_quote_rounded,
                        accentColor: const Color(0xFF8B5CF6),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

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
                                  hintText: 'Search by Invoice #, Customer Name, or Phone...',
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
                        // Filter Pills
                        Row(
                          children: [
                            _buildFilterPill('ALL', 'All Invoices'),
                            const SizedBox(width: 8),
                            _buildFilterPill('PENDING', 'Pending Payment'),
                            const SizedBox(width: 8),
                            _buildFilterPill('PARTIAL', 'Partially Paid'),
                            const SizedBox(width: 8),
                            _buildFilterPill('PAID', 'Fully Paid'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Invoices List
                  if (provider.isLoading)
                    const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
                  else if (filteredInvoices.isEmpty)
                    GlassCard(
                      blur: 16,
                      opacity: 0.9,
                      borderRadius: BorderRadius.circular(16),
                      borderColor: const Color(0xFFE2E8F0),
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.receipt_outlined, size: 48, color: Color(0xFF94A3B8)),
                          const SizedBox(height: 12),
                          Text(
                            'No invoices found in this view',
                            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF475569)),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Convert an interested lead quotation or create a new invoice to start billing.',
                            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterPill(String status, String label) {
    final isSelected = _selectedStatus == status;
    return InkWell(
      onTap: () {
        setState(() => _selectedStatus = status);
        _loadData();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0)),
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
  }) {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(16),
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
              Text(title, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: accentColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: GoogleFonts.robotoMono(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
          const SizedBox(height: 4),
          Text(subtitle, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
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
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isPaid ? Icons.check_circle_rounded : Icons.receipt_rounded,
                  color: badgeFg,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
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
                          style: GoogleFonts.robotoMono(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(6)),
                          child: Text(
                            invoice.paymentStatus,
                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: badgeFg),
                          ),
                        ),
                        if (invoice.quotationNumber.isNotEmpty)
                          Text('Ref: ${invoice.quotationNumber}', style: GoogleFonts.robotoMono(fontSize: 11, color: const Color(0xFF64748B))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      invoice.customerName,
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: 12,
                      children: [
                        if (invoice.customerPhone.isNotEmpty)
                          Text('📞 ${invoice.customerPhone}', style: GoogleFonts.robotoMono(fontSize: 11, color: const Color(0xFF64748B))),
                        Text('📅 Date: ${invoice.date}', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                        if (invoice.paymentMode.isNotEmpty)
                          Text('💳 Mode: ${invoice.paymentMode}', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF059669))),
                      ],
                    ),
                  ],
                ),
              ),
              // Totals Block
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    margin: const EdgeInsets.only(bottom: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1FAE5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'FIXED PRICE',
                      style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w800, color: const Color(0xFF047857)),
                    ),
                  ),
                  Text('₹${invoice.grandTotal.toStringAsFixed(2)}', style: GoogleFonts.robotoMono(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
                  const SizedBox(height: 2),
                  if (invoice.balanceDue > 0)
                    Text(
                      'Due: ₹${invoice.balanceDue.toStringAsFixed(2)}',
                      style: GoogleFonts.robotoMono(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFFDC2626)),
                    )
                  else
                    Text(
                      'Paid in Full',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF059669)),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Color(0xFFF1F5F9), height: 1),
          const SizedBox(height: 12),

          // Actions Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // WhatsApp Share
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
                    onPressed: () => PdfInvoiceService.printInvoice(invoice),
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
}

