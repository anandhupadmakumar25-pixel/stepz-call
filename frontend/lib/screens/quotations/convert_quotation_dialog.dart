import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/widgets/glass/glass_card.dart';
import '../../core/widgets/glass/gradient_button.dart';
import '../../models/quotation_model.dart';
import '../../providers/billing_provider.dart';

class ConvertQuotationDialog extends StatefulWidget {
  final QuotationModel quotation;

  const ConvertQuotationDialog({super.key, required this.quotation});

  @override
  State<ConvertQuotationDialog> createState() => _ConvertQuotationDialogState();
}

class _NegotiatedItemEntry {
  final TextEditingController descriptionController;
  final TextEditingController qtyController;
  final TextEditingController rateController;
  final TextEditingController taxController;
  final TextEditingController discountController;

  _NegotiatedItemEntry({
    required String description,
    required double qty,
    required double rate,
    required double tax,
    required double discount,
  })  : descriptionController = TextEditingController(text: description),
        qtyController = TextEditingController(text: qty == qty.roundToDouble() ? qty.toInt().toString() : qty.toString()),
        rateController = TextEditingController(text: rate.toStringAsFixed(2)),
        taxController = TextEditingController(text: tax.toStringAsFixed(0)),
        discountController = TextEditingController(text: discount.toStringAsFixed(0));

  void dispose() {
    descriptionController.dispose();
    qtyController.dispose();
    rateController.dispose();
    taxController.dispose();
    discountController.dispose();
  }

  double get quantity => double.tryParse(qtyController.text) ?? 1.0;
  double get rate => double.tryParse(rateController.text) ?? 0.0;
  double get taxPercent => double.tryParse(taxController.text) ?? 0.0;
  double get discountPercent => double.tryParse(discountController.text) ?? 0.0;

  double get baseAmount => quantity * rate;
  double get itemDiscountAmount => baseAmount * (discountPercent / 100.0);
  double get taxableAmount => baseAmount - itemDiscountAmount;
  double get taxAmount => taxableAmount * (taxPercent / 100.0);
  double get lineTotal => taxableAmount + taxAmount;

  QuotationItemModel toModel() {
    return QuotationItemModel(
      description: descriptionController.text.trim(),
      quantity: quantity,
      unitPrice: rate,
      taxPercent: taxPercent,
      discountPercent: discountPercent,
      total: lineTotal,
    );
  }
}

class _ConvertQuotationDialogState extends State<ConvertQuotationDialog> {
  final _formKey = GlobalKey<FormState>();
  final List<_NegotiatedItemEntry> _items = [];
  final TextEditingController _negotiationDiscountController = TextEditingController(text: '0.00');
  final TextEditingController _notesController = TextEditingController();
  final DateTime _dueDate = DateTime.now().add(const Duration(days: 15));
  bool _isConverting = false;

  @override
  void initState() {
    super.initState();
    final q = widget.quotation;
    _notesController.text = q.notes;

    if (q.items.isNotEmpty) {
      for (final it in q.items) {
        _items.add(
          _NegotiatedItemEntry(
            description: it.description,
            qty: it.quantity,
            rate: it.unitPrice,
            tax: it.taxPercent,
            discount: it.discountPercent,
          ),
        );
      }
    } else {
      _items.add(
        _NegotiatedItemEntry(
          description: 'Sales Order Item',
          qty: 1,
          rate: q.subtotal > 0 ? q.subtotal : q.grandTotal,
          tax: 18,
          discount: 0,
        ),
      );
    }
  }

  @override
  void dispose() {
    for (final it in _items) {
      it.dispose();
    }
    _negotiationDiscountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double get _itemsBaseSubtotal => _items.fold(0.0, (acc, it) => acc + it.baseAmount);
  double get _itemsDiscountTotal => _items.fold(0.0, (acc, it) => acc + it.itemDiscountAmount);
  double get _specialNegotiationDiscount => double.tryParse(_negotiationDiscountController.text) ?? 0.0;
  double get _totalDiscount => _itemsDiscountTotal + _specialNegotiationDiscount;

  double get _taxableSubtotal => (_itemsBaseSubtotal - _totalDiscount).clamp(0.0, double.infinity);
  double get _calculatedTax => _items.fold(0.0, (acc, it) => acc + it.taxAmount);
  double get _finalGrandTotal => (_taxableSubtotal + _calculatedTax).clamp(0.0, double.infinity);

  Future<void> _submitConversion({bool useOriginalQuote = false}) async {
    final q = widget.quotation;
    final provider = context.read<BillingProvider>();
    setState(() => _isConverting = true);

    Map<String, dynamic> overrideData;
    if (useOriginalQuote) {
      overrideData = {
        'items': q.items.map((it) => it.toJson()).toList(),
        'subtotal': q.subtotal,
        'tax_amount': q.taxAmount,
        'discount_amount': q.discountAmount,
        'grand_total': q.grandTotal,
        'due_date': _dueDate.toIso8601String().split('T').first,
        'notes': q.notes,
      };
    } else {
      overrideData = {
        'items': _items
            .where((i) => i.descriptionController.text.trim().isNotEmpty)
            .map((i) => i.toModel().toJson())
            .toList(),
        'subtotal': _itemsBaseSubtotal,
        'tax_amount': _calculatedTax,
        'discount_amount': _totalDiscount,
        'grand_total': _finalGrandTotal,
        'due_date': _dueDate.toIso8601String().split('T').first,
        'notes': _notesController.text.trim(),
      };
    }

    final invoice = await provider.convertQuotationToInvoice(q.id, overrideData: overrideData);
    setState(() => _isConverting = false);

    if (mounted) {
      if (invoice != null) {
        Navigator.of(context).pop(invoice);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage ?? 'Failed to convert quotation to bill'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.quotation;
    final isPriceLower = _finalGrandTotal < q.grandTotal;
    final priceDiff = (q.grandTotal - _finalGrandTotal).abs();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860, maxHeight: 840),
        child: GlassCard(
          blur: 24,
          opacity: 0.98,
          borderRadius: BorderRadius.circular(20),
          borderColor: const Color(0xFFCBD5E1),
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
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
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFF059669), Color(0xFF10B981)]),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Convert Quote to Fixed Price Bill',
                                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFD1FAE5),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    q.quotationNumber,
                                    style: GoogleFonts.robotoMono(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF047857)),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'Customer: ${q.customerName} (${q.customerPhone}) | Original Estimate: ₹${q.grandTotal.toStringAsFixed(2)}',
                              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                            ),
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
                const SizedBox(height: 12),

                // Negotiation Banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.handshake_rounded, size: 20, color: Color(0xFF2563EB)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Client negotiated or accepted below the approximate quotation? Edit rates, quantities, or enter a negotiated discount below to lock the exact agreed bill amount.',
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF1E40AF), fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Editable Items Table Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(flex: 5, child: Text('ITEM / SERVICE DESCRIPTION', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF475569)))),
                      const SizedBox(width: 8),
                      Expanded(flex: 2, child: Text('QTY', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF475569)))),
                      const SizedBox(width: 8),
                      Expanded(flex: 3, child: Text('RATE (₹)', textAlign: TextAlign.right, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF475569)))),
                      const SizedBox(width: 8),
                      Expanded(flex: 2, child: Text('GST %', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF475569)))),
                      const SizedBox(width: 8),
                      Expanded(flex: 3, child: Text('TOTAL (₹)', textAlign: TextAlign.right, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF475569)))),
                      const SizedBox(width: 32),
                    ],
                  ),
                ),
                const SizedBox(height: 6),

                // Editable Items List
                Expanded(
                  child: ListView.separated(
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, idx) {
                      final item = _items[idx];
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            // Description
                            Expanded(
                              flex: 5,
                              child: TextField(
                                controller: item.descriptionController,
                                style: GoogleFonts.inter(fontSize: 12.5),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  border: InputBorder.none,
                                  hintText: 'Item description',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Qty
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: item.qtyController,
                                textAlign: TextAlign.center,
                                keyboardType: TextInputType.number,
                                onChanged: (_) => setState(() {}),
                                style: GoogleFonts.robotoMono(fontSize: 12.5, fontWeight: FontWeight.bold),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Rate
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: item.rateController,
                                textAlign: TextAlign.right,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                onChanged: (_) => setState(() {}),
                                style: GoogleFonts.robotoMono(fontSize: 12.5, fontWeight: FontWeight.bold),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // GST
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: item.taxController,
                                textAlign: TextAlign.center,
                                keyboardType: TextInputType.number,
                                onChanged: (_) => setState(() {}),
                                style: GoogleFonts.robotoMono(fontSize: 12),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Line Total
                            Expanded(
                              flex: 3,
                              child: Text(
                                '₹${item.lineTotal.toStringAsFixed(2)}',
                                textAlign: TextAlign.right,
                                style: GoogleFonts.robotoMono(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                              onPressed: _items.length > 1
                                  ? () {
                                      setState(() {
                                        _items.removeAt(idx).dispose();
                                      });
                                    }
                                  : null,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),

                // Add item button
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _items.add(_NegotiatedItemEntry(description: '', qty: 1, rate: 0.0, tax: 18, discount: 0));
                      });
                    },
                    icon: const Icon(Icons.add_rounded, size: 16, color: Color(0xFF2563EB)),
                    label: Text('+ Add Line Item', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB))),
                  ),
                ),
                const SizedBox(height: 10),

                // Calculation & Negotiation Discount Box
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Original Estimated Quote:', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                          Text('₹${q.grandTotal.toStringAsFixed(2)}', style: GoogleFonts.robotoMono(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text('Client Negotiation Discount (₹):', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFDC2626))),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 120,
                                height: 32,
                                child: TextField(
                                  controller: _negotiationDiscountController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  onChanged: (_) => setState(() {}),
                                  style: GoogleFonts.robotoMono(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFDC2626)),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    prefixText: '₹ ',
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text('-₹${_specialNegotiationDiscount.toStringAsFixed(2)}', style: GoogleFonts.robotoMono(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFFDC2626))),
                        ],
                      ),
                      const Divider(color: Color(0xFFCBD5E1), height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Final Agreed Fixed Price:',
                                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                              ),
                              if (isPriceLower)
                                Text(
                                  '✓ Negotiated ₹${priceDiff.toStringAsFixed(2)} below original estimate',
                                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF059669)),
                                ),
                            ],
                          ),
                          Text(
                            '₹${_finalGrandTotal.toStringAsFixed(2)}',
                            style: GoogleFonts.robotoMono(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFF047857)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(color: Color(0xFFE2E8F0), height: 1),
                const SizedBox(height: 16),

                // Action Buttons
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      onPressed: _isConverting ? null : () => Navigator.of(context).pop(),
                      child: Text('Cancel', style: GoogleFonts.inter(color: const Color(0xFF64748B), fontWeight: FontWeight.w600)),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.history_rounded, size: 16),
                      label: Text('Convert at Original Estimate (₹${q.grandTotal.toStringAsFixed(2)})', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                      onPressed: _isConverting ? null : () => _submitConversion(useOriginalQuote: true),
                    ),
                    GradientPrimaryButton(
                      text: _isConverting ? 'Generating Bill...' : 'Generate Bill at Agreed Price (₹${_finalGrandTotal.toStringAsFixed(2)})',
                      icon: Icons.check_circle_rounded,
                      gradient: const LinearGradient(colors: [Color(0xFF059669), Color(0xFF10B981)]),
                      onPressed: _isConverting ? null : () => _submitConversion(useOriginalQuote: false),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

