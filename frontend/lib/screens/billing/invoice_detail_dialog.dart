import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/widgets/glass/glass_card.dart';
import '../../core/widgets/glass/gradient_button.dart';
import '../../core/services/pdf_invoice_service.dart';
import '../../models/invoice_model.dart';
import 'record_payment_dialog.dart';

class InvoiceDetailDialog extends StatefulWidget {
  final InvoiceModel invoice;

  const InvoiceDetailDialog({super.key, required this.invoice});

  @override
  State<InvoiceDetailDialog> createState() => _InvoiceDetailDialogState();
}

class _InvoiceDetailDialogState extends State<InvoiceDetailDialog> {
  late InvoiceModel _invoice;

  @override
  void initState() {
    super.initState();
    _invoice = widget.invoice;
  }

  @override
  Widget build(BuildContext context) {
    final inv = _invoice;
    final isPaid = inv.paymentStatus == 'PAID';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 840),
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
                          color: const Color(0xFF10B981).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF059669), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                inv.invoiceNumber,
                                style: GoogleFonts.robotoMono(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                              ),
                              const SizedBox(width: 8),
                              _buildPaymentStatusBadge(inv.paymentStatus),
                            ],
                          ),
                          Text('Billed on ${inv.date} · Due: ${inv.dueDate ?? 'Upon receipt'}', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
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

              // Scrollable Body
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
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
                            Text(inv.customerName, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 16,
                              children: [
                                if (inv.customerPhone.isNotEmpty)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.phone_outlined, size: 14, color: Color(0xFF2563EB)),
                                      const SizedBox(width: 4),
                                      Text(inv.customerPhone, style: GoogleFonts.robotoMono(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF2563EB))),
                                    ],
                                  ),
                                if (inv.customerEmail.isNotEmpty)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.email_outlined, size: 14, color: Color(0xFF64748B)),
                                      const SizedBox(width: 4),
                                      Text(inv.customerEmail, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                                    ],
                                  ),
                                if (inv.customerAddress.isNotEmpty)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF64748B)),
                                      const SizedBox(width: 4),
                                      Text(inv.customerAddress, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
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
                          Text('Tax Invoice Items', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B))),
                          Text('Official Fixed Price', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF059669))),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: const BoxDecoration(
                                color: Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(flex: 5, child: Text('Product / Item Description', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF475569)))),
                                  for (final col in inv.customColumns) ...[
                                    const SizedBox(width: 8),
                                    Expanded(flex: 2, child: Text(col, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF4338CA)))),
                                  ],
                                  const SizedBox(width: 8),
                                  Expanded(flex: 2, child: Text('Qty', textAlign: TextAlign.right, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF475569)))),
                                  const SizedBox(width: 8),
                                  Expanded(flex: 2, child: Text('Rate (₹)', textAlign: TextAlign.right, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF475569)))),
                                  const SizedBox(width: 8),
                                  Expanded(flex: 2, child: Text('Tax %', textAlign: TextAlign.right, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF475569)))),
                                  const SizedBox(width: 8),
                                  Expanded(flex: 2, child: Text('Total (₹)', textAlign: TextAlign.right, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF475569)))),
                                ],
                              ),
                            ),
                            ...inv.items.map((item) {
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
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                child: Row(
                                  children: [
                                    Expanded(flex: 5, child: Text(item.description, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500))),
                                    for (final col in inv.customColumns) ...[
                                      const SizedBox(width: 8),
                                      Expanded(flex: 2, child: Text(item.customFields[col] ?? '-', style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF334155)))),
                                    ],
                                    const SizedBox(width: 8),
                                    Expanded(flex: 2, child: Text(item.quantity.toStringAsFixed(item.quantity.truncateToDouble() == item.quantity ? 0 : 2), textAlign: TextAlign.right, style: GoogleFonts.robotoMono(fontSize: 12))),
                                    const SizedBox(width: 8),
                                    Expanded(flex: 2, child: Text('₹${item.unitPrice.toStringAsFixed(2)}', textAlign: TextAlign.right, style: GoogleFonts.robotoMono(fontSize: 12))),
                                    const SizedBox(width: 8),
                                    Expanded(flex: 2, child: Text('${item.taxPercent.toStringAsFixed(0)}%', textAlign: TextAlign.right, style: GoogleFonts.robotoMono(fontSize: 12))),
                                    const SizedBox(width: 8),
                                    Expanded(flex: 2, child: Text('₹${item.total.toStringAsFixed(2)}', textAlign: TextAlign.right, style: GoogleFonts.robotoMono(fontSize: 12, fontWeight: FontWeight.w700))),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Totals & Balance Summary
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            _buildAmountRow('Subtotal', '₹${inv.subtotal.toStringAsFixed(2)}'),
                            if (inv.discountAmount > 0)
                              _buildAmountRow('Discount', '-₹${inv.discountAmount.toStringAsFixed(2)}', isNegative: true),
                            _buildAmountRow('Tax / GST', '+₹${inv.taxAmount.toStringAsFixed(2)}'),
                            const Divider(color: Color(0xFFE2E8F0), height: 16),
                            _buildAmountRow('Grand Total', '₹${inv.grandTotal.toStringAsFixed(2)}', isBold: true, isHighlight: true),
                            const SizedBox(height: 6),
                            _buildAmountRow('Amount Paid', '₹${inv.amountPaid.toStringAsFixed(2)}', color: const Color(0xFF059669)),
                            _buildAmountRow('Balance Due', '₹${inv.balanceDue.toStringAsFixed(2)}', isBold: true, color: inv.balanceDue > 0 ? const Color(0xFFDC2626) : const Color(0xFF059669)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Divider(color: Color(0xFFE2E8F0), height: 1),
              const SizedBox(height: 16),

              // Bottom Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF25D366)),
                      foregroundColor: const Color(0xFF059669),
                    ),
                    icon: const Icon(Icons.chat_rounded, size: 16),
                    label: const Text('WhatsApp Receipt'),
                    onPressed: () => PdfInvoiceService.shareInvoiceToWhatsApp(inv),
                  ),
                  Wrap(
                    spacing: 10,
                    children: [
                      GlassSecondaryButton(
                        text: 'Print / PDF',
                        icon: Icons.print_outlined,
                        onPressed: () => PdfInvoiceService.printInvoice(inv),
                      ),
                      if (!isPaid)
                        GradientPrimaryButton(
                          text: 'Record Payment',
                          icon: Icons.payment_rounded,
                          gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
                          onPressed: () async {
                            await showDialog(
                              context: context,
                              builder: (_) => RecordPaymentDialog(invoice: inv),
                            );
                            if (!context.mounted) return;
                            Navigator.of(context).pop(true);
                          },
                        ),
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

  Widget _buildPaymentStatusBadge(String status) {
    Color bg = const Color(0xFFF1F5F9);
    Color fg = const Color(0xFF475569);

    if (status == 'PAID') {
      bg = const Color(0xFFD1FAE5);
      fg = const Color(0xFF047857);
    } else if (status == 'PARTIAL') {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFFB45309);
    } else if (status == 'PENDING') {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFFDC2626);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        status,
        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: fg),
      ),
    );
  }

  Widget _buildAmountRow(String label, String value, {bool isBold = false, bool isHighlight = false, bool isNegative = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: isHighlight ? 14 : 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: isHighlight ? const Color(0xFF0F172A) : const Color(0xFF64748B),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.robotoMono(
              fontSize: isHighlight ? 15 : 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color ?? (isNegative ? const Color(0xFFDC2626) : (isHighlight ? const Color(0xFF0F172A) : const Color(0xFF334155))),
            ),
          ),
        ],
      ),
    );
  }
}

