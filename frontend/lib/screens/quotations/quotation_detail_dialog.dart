import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/widgets/glass/glass_card.dart';
import '../../core/widgets/glass/gradient_button.dart';
import '../../core/widgets/company_logo_view.dart';
import '../../core/services/pdf_invoice_service.dart';
import '../../models/quotation_model.dart';
import '../../models/invoice_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/company_provider.dart';
import '../billing/record_payment_dialog.dart';
import 'convert_quotation_dialog.dart';
import 'quotation_form_dialog.dart';

class QuotationDetailDialog extends StatefulWidget {
  final QuotationModel quotation;

  const QuotationDetailDialog({super.key, required this.quotation});

  @override
  State<QuotationDetailDialog> createState() => _QuotationDetailDialogState();
}

class _QuotationDetailDialogState extends State<QuotationDetailDialog> {
  late QuotationModel _quotation;

  @override
  void initState() {
    super.initState();
    _quotation = widget.quotation;
  }

  Future<void> _handleConvertToInvoice() async {
    final invoice = await showDialog<InvoiceModel>(
      context: context,
      builder: (_) => ConvertQuotationDialog(quotation: _quotation),
    );

    if (!mounted || invoice == null) return;

    Navigator.of(context).pop(invoice);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Fixed Price Invoice ${invoice.invoiceNumber} generated successfully at agreed price ₹${invoice.grandTotal.toStringAsFixed(2)}!'),
        backgroundColor: const Color(0xFF10B981),
        action: SnackBarAction(
          label: 'Record Payment',
          textColor: Colors.white,
          onPressed: () {
            showDialog(
              context: context,
              builder: (_) => RecordPaymentDialog(invoice: invoice),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = _quotation;

    final authUser = context.watch<AuthProvider>().currentUser;
    final comp = context.watch<CompanyProvider>().activeCompanyDetail;

    final String compName = (comp?.name.isNotEmpty == true)
        ? comp!.name
        : ((authUser?.companyName?.isNotEmpty == true) ? authUser!.companyName! : 'Stepz Telecaller CRM');
    final compLogo = (comp?.logo.isNotEmpty == true)
        ? comp!.logo
        : (authUser?.companyLogo ?? '');
    final compPhone = (comp?.contactPhone.isNotEmpty == true)
        ? comp!.contactPhone
        : (authUser?.companyPhone ?? '');
    final compEmail = (comp?.contactEmail.isNotEmpty == true)
        ? comp!.contactEmail
        : (authUser?.companyEmail ?? '');
    final compAddress = (comp?.address.isNotEmpty == true)
        ? comp!.address
        : (authUser?.companyAddress ?? '');
    final compGstin = (comp?.gstin.isNotEmpty == true)
        ? comp!.gstin
        : (authUser?.companyGstin ?? '');
    final compWebsite = (comp?.website.isNotEmpty == true)
        ? comp!.website
        : (authUser?.companyWebsite ?? '');

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 820),
        child: GlassCard(
          blur: 24,
          opacity: 0.98,
          borderRadius: BorderRadius.circular(20),
          borderColor: const Color(0xFFCBD5E1),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.description_outlined, color: Color(0xFF2563EB), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                q.quotationNumber,
                                style: GoogleFonts.robotoMono(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                              ),
                              const SizedBox(width: 8),
                              _buildStatusBadge(q.status),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5)),
                                ),
                                child: Text(
                                  'APPROXIMATE ESTIMATE',
                                  style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: const Color(0xFFB45309)),
                                ),
                              ),
                            ],
                          ),
                          Text('Created on ${q.date}', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: Color(0xFFE2E8F0), height: 1),
              const SizedBox(height: 16),

              // Scrollable Details
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Standard Corporate Brand Header
                      Container(
                        padding: const EdgeInsets.all(14),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CompanyLogoView(
                              logo: compLogo,
                              companyName: compName,
                              size: 48,
                              borderRadius: BorderRadius.circular(10),
                              borderColor: const Color(0xFFCBD5E1),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    compName,
                                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                                  ),
                                  if (compGstin.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text('GSTIN: $compGstin', style: GoogleFonts.robotoMono(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF0F766E))),
                                  ],
                                  if (compAddress.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(compAddress, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF475569))),
                                  ],
                                  const SizedBox(height: 2),
                                  Wrap(
                                    spacing: 12,
                                    children: [
                                      if (compPhone.isNotEmpty)
                                        Text('Tel: $compPhone', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                                      if (compEmail.isNotEmpty)
                                        Text('Email: $compEmail', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                                      if (compWebsite.isNotEmpty)
                                        Text(compWebsite, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF2563EB), fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Customer Info Card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('QUOTATION FOR', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF64748B))),
                            const SizedBox(height: 4),
                            Text(q.customerName, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 16,
                              children: [
                                if (q.customerPhone.isNotEmpty)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.phone_outlined, size: 14, color: Color(0xFF2563EB)),
                                      const SizedBox(width: 4),
                                      Text(q.customerPhone, style: GoogleFonts.robotoMono(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF2563EB))),
                                    ],
                                  ),
                                if (q.customerEmail.isNotEmpty)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.email_outlined, size: 14, color: Color(0xFF64748B)),
                                      const SizedBox(width: 4),
                                      Text(q.customerEmail, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                                    ],
                                  ),
                                if (q.customerAddress.isNotEmpty)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF64748B)),
                                      const SizedBox(width: 4),
                                      Text(q.customerAddress, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                                    ],
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Items Table
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Quotation Items', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B))),
                          Text('Rates are approximate', style: GoogleFonts.inter(fontSize: 11, fontStyle: FontStyle.italic, color: const Color(0xFF64748B))),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final double minTableWidth = 240 +
                                (q.customColumns.length * 120) +
                                (q.showQty ? 80 : 0) +
                                (q.showPrice ? 110 : 0) +
                                (q.showTax ? 80 : 0) +
                                110;
                            final double tableWidth = constraints.maxWidth > minTableWidth ? constraints.maxWidth : minTableWidth;

                            return Scrollbar(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.only(bottom: 14),
                                child: SizedBox(
                                  width: tableWidth,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(flex: 5, child: Text('Product / Item', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF475569)))),
                                          for (final col in q.customColumns) ...[
                                            const SizedBox(width: 8),
                                            SizedBox(width: 110, child: Text(col, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF475569)))),
                                          ],
                                          if (q.showQty) ...[
                                            const SizedBox(width: 8),
                                            SizedBox(width: 75, child: Text('Qty', textAlign: TextAlign.right, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF475569)))),
                                          ],
                                          if (q.showPrice) ...[
                                            const SizedBox(width: 8),
                                            SizedBox(width: 100, child: Text('Approx Rate', textAlign: TextAlign.right, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF475569)))),
                                          ],
                                          if (q.showTax) ...[
                                            const SizedBox(width: 8),
                                            SizedBox(width: 75, child: Text('Tax %', textAlign: TextAlign.right, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF475569)))),
                                          ],
                                          const SizedBox(width: 8),
                                          SizedBox(width: 100, child: Text('Total', textAlign: TextAlign.right, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF475569)))),
                                        ],
                                      ),
                                    ),
                                    ...q.items.map((item) {
                                      if (item.isSectionTitle) {
                                        return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFFFBEB),
                                            border: Border(
                                              left: const BorderSide(color: Color(0xFFF59E0B), width: 4),
                                              bottom: BorderSide(color: Colors.amber.shade100, width: 0.5),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.title_rounded, size: 16, color: Color(0xFFD97706)),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  (item.title.isNotEmpty ? item.title : item.description).toUpperCase(),
                                                  style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w800, color: const Color(0xFF92400E)),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }

                                      return Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        child: Row(
                                          children: [
                                            Expanded(flex: 5, child: Text(item.description, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500))),
                                            for (final col in q.customColumns) ...[
                                              const SizedBox(width: 8),
                                              SizedBox(width: 110, child: Text(item.customFields[col] ?? '-', style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF334155)))),
                                            ],
                                            if (q.showQty) ...[
                                              const SizedBox(width: 8),
                                              SizedBox(width: 75, child: Text(item.quantity.toStringAsFixed(item.quantity.truncateToDouble() == item.quantity ? 0 : 2), textAlign: TextAlign.right, style: GoogleFonts.robotoMono(fontSize: 12))),
                                            ],
                                            if (q.showPrice) ...[
                                              const SizedBox(width: 8),
                                              SizedBox(width: 100, child: Text('₹${item.unitPrice.toStringAsFixed(2)}', textAlign: TextAlign.right, style: GoogleFonts.robotoMono(fontSize: 12))),
                                            ],
                                            if (q.showTax) ...[
                                              const SizedBox(width: 8),
                                              SizedBox(width: 75, child: Text('${item.taxPercent.toStringAsFixed(0)}%', textAlign: TextAlign.right, style: GoogleFonts.robotoMono(fontSize: 12))),
                                            ],
                                            const SizedBox(width: 8),
                                            SizedBox(width: 100, child: Text('₹${item.total.toStringAsFixed(2)}', textAlign: TextAlign.right, style: GoogleFonts.robotoMono(fontSize: 12, fontWeight: FontWeight.w700))),
                                          ],
                                        ),
                                      );
                                    }),
                                    const SizedBox(height: 10),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Totals Summary
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            _buildAmountRow('Approximate Subtotal', '₹${q.subtotal.toStringAsFixed(2)}'),
                            if (q.discountAmount > 0)
                              _buildAmountRow('Discount', '-₹${q.discountAmount.toStringAsFixed(2)}', textColor: const Color(0xFFDC2626)),
                            if (q.taxAmount > 0)
                              _buildAmountRow('Tax / GST', '₹${q.taxAmount.toStringAsFixed(2)}'),
                            const Divider(color: Color(0xFFCBD5E1), height: 16),
                            _buildAmountRow(
                              'Approximate Grand Total',
                              '₹${q.grandTotal.toStringAsFixed(2)}',
                              isBold: true,
                              fontSize: 16,
                              textColor: const Color(0xFF1E3A8A),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '* Converting to Bill will finalize and lock this amount as Fixed Price.',
                              style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B), fontStyle: FontStyle.italic),
                            ),
                          ],
                        ),
                      ),

                      if (q.notes.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text('Notes:', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF475569))),
                        const SizedBox(height: 2),
                        Text(q.notes, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF334155))),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Divider(color: Color(0xFFE2E8F0), height: 1),
              const SizedBox(height: 16),

              // Bottom Actions Bar
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  // WhatsApp Button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.chat_rounded, size: 18),
                    label: Text('Share to WhatsApp', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12)),
                    onPressed: () => PdfInvoiceService.shareQuotationToWhatsApp(q, companyName: compName),
                  ),
                  Wrap(
                    spacing: 10,
                    children: [
                      GlassSecondaryButton(
                        text: 'Print / PDF',
                        icon: Icons.print_outlined,
                        onPressed: () => PdfInvoiceService.printQuotation(
                          q,
                          companyName: compName,
                          companyPhone: compPhone,
                          companyEmail: compEmail,
                          companyAddress: compAddress,
                          companyGstin: compGstin,
                          companyWebsite: compWebsite,
                          companyLogo: compLogo,
                        ),
                      ),
                      if (q.status != 'CONVERTED') ...[
                        GlassSecondaryButton(
                          text: 'Edit Quote',
                          icon: Icons.edit_outlined,
                          onPressed: () async {
                            final updated = await showDialog<QuotationModel>(
                              context: context,
                              builder: (_) => QuotationFormDialog(quotationToEdit: _quotation),
                            );
                            if (updated != null && mounted) {
                              setState(() {
                                _quotation = updated;
                              });
                            }
                          },
                        ),
                        GradientPrimaryButton(
                          text: 'Convert to Fixed Price Bill',
                          icon: Icons.receipt_long_rounded,
                          gradient: const LinearGradient(colors: [Color(0xFF059669), Color(0xFF10B981)]),
                          onPressed: _handleConvertToInvoice,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg = const Color(0xFFF1F5F9);
    Color fg = const Color(0xFF475569);

    if (status == 'SENT') {
      bg = const Color(0xFFDBEAFE);
      fg = const Color(0xFF1D4ED8);
    } else if (status == 'ACCEPTED') {
      bg = const Color(0xFFD1FAE5);
      fg = const Color(0xFF047857);
    } else if (status == 'CONVERTED') {
      bg = const Color(0xFFEDE9FE);
      fg = const Color(0xFF6D28D9);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(status, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: fg)),
    );
  }

  Widget _buildAmountRow(String label, String value, {bool isBold = false, double fontSize = 12, Color? textColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: fontSize, fontWeight: isBold ? FontWeight.w700 : FontWeight.w500, color: textColor ?? const Color(0xFF475569))),
          Text(value, style: GoogleFonts.robotoMono(fontSize: fontSize, fontWeight: isBold ? FontWeight.w800 : FontWeight.w600, color: textColor ?? const Color(0xFF0F172A))),
        ],
      ),
    );
  }
}
