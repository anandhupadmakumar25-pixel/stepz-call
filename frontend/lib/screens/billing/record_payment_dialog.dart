import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/widgets/glass/glass_card.dart';
import '../../core/widgets/glass/gradient_button.dart';
import '../../models/invoice_model.dart';
import '../../models/plan_model.dart';
import '../../models/document_template_model.dart';
import '../../providers/billing_provider.dart';
import 'receipt_voucher_dialog.dart';

class RecordPaymentDialog extends StatefulWidget {
  final InvoiceModel invoice;

  const RecordPaymentDialog({super.key, required this.invoice});

  @override
  State<RecordPaymentDialog> createState() => _RecordPaymentDialogState();
}

class _RecordPaymentDialogState extends State<RecordPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _amountController;
  late TextEditingController _refController;
  late TextEditingController _notesController;

  String _paymentMode = 'Bank Transfer';
  bool _isSaving = false;
  String? _errorMessage;
  String? _selectedReceiptTemplateId;
  Map<String, dynamic> _selectedReceiptTemplateSnapshot = {};
  final Map<String, TextEditingController> _customFieldCtrls = {};
  final TextEditingController _podDriverCtrl = TextEditingController();
  final TextEditingController _podReceiverCtrl = TextEditingController();
  final TextEditingController _podPhoneCtrl = TextEditingController();
  final TextEditingController _podCommodityCtrl = TextEditingController();

  final List<String> _paymentModes = [
    'Bank Transfer',
    'Cash',
    'Card (Debit/Credit)',
    'Cheque',
    'Online Transfer',
  ];

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.invoice.balanceDue > 0
          ? widget.invoice.balanceDue.toStringAsFixed(2)
          : '0.00',
    );
    _refController = TextEditingController();
    _notesController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final bp = context.read<BillingProvider>();
      await bp.fetchTemplates(docType: 'RECEIPT');
      if (!mounted) return;
      final def = bp.defaultTemplateFor('RECEIPT');
      if (def != null) {
        setState(() {
          _selectedReceiptTemplateId = def.id;
          _selectedReceiptTemplateSnapshot = def.layout.toJson();
        });
      }
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _refController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleRecordPayment() async {
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (amount <= 0) {
      setState(() => _errorMessage = 'Payment amount must be greater than 0');
      return;
    }

    setState(() => _isSaving = true);
    final provider = context.read<BillingProvider>();
    final tplLayout = TemplateLayoutConfig.fromJson(_selectedReceiptTemplateSnapshot, docType: 'RECEIPT');
    final includePod = tplLayout.includePodSlip || tplLayout.isBlockVisible('pod_slip');
    final finalSnap = Map<String, dynamic>.from(_selectedReceiptTemplateSnapshot);
    if (_customFieldCtrls.isNotEmpty) {
      final filled = <String, String>{};
      for (final e in _customFieldCtrls.entries) {
        if (e.value.text.trim().isNotEmpty) filled[e.key] = e.value.text.trim();
      }
      if (filled.isNotEmpty) finalSnap['filled_fields'] = filled;
    }

    final success = await provider.recordPayment(
      invoiceId: widget.invoice.id,
      amount: amount,
      paymentMode: _paymentMode,
      paymentReference: _refController.text.trim(),
      notes: _notesController.text.trim(),
      includePodSlip: includePod,
      podDriverName: _podDriverCtrl.text.trim(),
      podReceiverName: _podReceiverCtrl.text.trim(),
      podReceiverPhone: _podPhoneCtrl.text.trim(),
      podCommodity: _podCommodityCtrl.text.trim(),
      templateId: _selectedReceiptTemplateId,
      templateSnapshot: finalSnap,
    );
    setState(() => _isSaving = false);

    if (mounted) {
      if (success) {
        final generatedVoucher = provider.lastGeneratedReceipt;
        Navigator.of(context).pop(true);
        if (generatedVoucher != null) {
          showDialog(
            context: context,
            builder: (ctx) => ReceiptVoucherDialog(voucher: generatedVoucher),
          );
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Payment of ${PlanModel.getSymbolForCurrency(widget.invoice.currency)} ${amount.toStringAsFixed(2)} recorded! Official Receipt Voucher generated.',
            ),
            backgroundColor: const Color(0xFF10B981),
            action: SnackBarAction(
              label: 'View Voucher',
              textColor: Colors.white,
              onPressed: () {
                if (generatedVoucher != null) {
                  showDialog(
                    context: context,
                    builder: (ctx) => ReceiptVoucherDialog(voucher: generatedVoucher),
                  );
                }
              },
            ),
          ),
        );
      } else {
        setState(() => _errorMessage = provider.errorMessage ?? 'Failed to record payment');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final inv = widget.invoice;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: GlassCard(
          blur: 24,
          opacity: 0.98,
          borderRadius: BorderRadius.circular(20),
          borderColor: const Color(0xFFCBD5E1),
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                            color: const Color(
                              0xFF10B981,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.payments_rounded,
                            color: Color(0xFF10B981),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Record Bill Payment',
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              '${inv.invoiceNumber} • ${inv.customerName}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Color(0xFF64748B),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(color: Color(0xFFE2E8F0), height: 1),
                const SizedBox(height: 14),

                if (_errorMessage != null) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFDC2626),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Invoice Balance Summary
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text(
                            'Invoice Total',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                          Text(
                            '${PlanModel.getSymbolForCurrency(inv.currency)} ${inv.grandTotal.toStringAsFixed(2)}',
                            style: GoogleFonts.robotoMono(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            'Already Paid',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                          Text(
                            '${PlanModel.getSymbolForCurrency(inv.currency)} ${inv.amountPaid.toStringAsFixed(2)}',
                            style: GoogleFonts.robotoMono(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF059669),
                            ),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            'Balance Due',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                          Text(
                            '${PlanModel.getSymbolForCurrency(inv.currency)} ${inv.balanceDue.toStringAsFixed(2)}',
                            style: GoogleFonts.robotoMono(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFDC2626),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Amount Input
                Text(
                  'Amount Received (${PlanModel.getSymbolForCurrency(inv.currency)}) *',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _amountController,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) {
                    if (!_isSaving) _handleRecordPayment();
                  },
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: GoogleFonts.robotoMono(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    final num = double.tryParse(v);
                    if (num == null || num <= 0) return 'Enter a valid amount';
                    return null;
                  },
                  decoration: InputDecoration(
                    prefixIcon: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      child: Text(
                        PlanModel.getSymbolForCurrency(inv.currency),
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: Color(0xFF10B981),
                        width: 1.5,
                      ),
                    ),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 14),

                // Payment Mode Dropdown
                Text(
                  'Payment Mode *',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _paymentMode,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  items: _paymentModes
                      .map(
                        (m) => DropdownMenuItem(
                          value: m,
                          child: Text(
                            m,
                            style: GoogleFonts.inter(fontSize: 12),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _paymentMode = val);
                  },
                ),
                const SizedBox(height: 14),

                // Reference Input
                Text(
                  'Transaction / Reference ID',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _refController,
                  style: GoogleFonts.inter(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Reference / Receipt ID (Optional)',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Receipt Voucher Template Picker
                Builder(
                  builder: (ctx) {
                    final receiptTemplates = ctx.watch<BillingProvider>().templatesForType('RECEIPT');
                    if (receiptTemplates.isEmpty) return const SizedBox.shrink();
                    final currentId = receiptTemplates.any((t) => t.id == _selectedReceiptTemplateId)
                        ? _selectedReceiptTemplateId
                        : null;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Receipt Voucher Template',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String?>(
                            initialValue: currentId,
                            decoration: InputDecoration(
                              isDense: true,
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            items: [
                              const DropdownMenuItem<String?>(value: null, child: Text('Standard System Receipt')),
                              ...receiptTemplates.map((t) => DropdownMenuItem<String?>(
                                    value: t.id,
                                    child: Text('${t.name}${t.isDefault ? " (Default)" : ""}'),
                                  )),
                            ],
                            onChanged: (val) {
                              setState(() {
                                _selectedReceiptTemplateId = val;
                                if (val == null) {
                                  _selectedReceiptTemplateSnapshot = {};
                                } else {
                                  _selectedReceiptTemplateSnapshot =
                                      receiptTemplates.firstWhere((t) => t.id == val).layout.toJson();
                                }
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),

                // Dynamic Receipt Template Fields (Custom Fields & POD Slip)
                Builder(
                  builder: (ctx) {
                    final tplLayout = TemplateLayoutConfig.fromJson(_selectedReceiptTemplateSnapshot, docType: 'RECEIPT');
                    final showPod = tplLayout.includePodSlip || tplLayout.isBlockVisible('pod_slip');
                    if (tplLayout.customHeaderFields.isEmpty && !showPod) return const SizedBox.shrink();
                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Template Fields', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF475569))),
                          ...tplLayout.customHeaderFields.map((fld) {
                            final ctrl = _customFieldCtrls.putIfAbsent(fld, () => TextEditingController());
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: TextFormField(
                                controller: ctrl,
                                decoration: InputDecoration(
                                  isDense: true,
                                  labelText: fld,
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            );
                          }),
                          if (showPod) ...[
                            const SizedBox(height: 8),
                            Text('Proof of Delivery (POD)', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                            const SizedBox(height: 6),
                            TextFormField(controller: _podDriverCtrl, decoration: InputDecoration(isDense: true, labelText: 'Driver Name', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
                            const SizedBox(height: 6),
                            TextFormField(controller: _podCommodityCtrl, decoration: InputDecoration(isDense: true, labelText: 'Commodity', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(child: TextFormField(controller: _podReceiverCtrl, decoration: InputDecoration(isDense: true, labelText: 'Receiver Name', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))))),
                                const SizedBox(width: 8),
                                Expanded(child: TextFormField(controller: _podPhoneCtrl, decoration: InputDecoration(isDense: true, labelText: 'Receiver Mob', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))))),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),

                // Payment Notes
                Text(
                  'Payment Notes',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  style: GoogleFonts.inter(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Optional notes (e.g. Part payment for phase 1)',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GradientPrimaryButton(
                      text: _isSaving ? 'Recording...' : 'Confirm Payment',
                      icon: Icons.check_circle_rounded,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF059669), Color(0xFF10B981)],
                      ),
                      onPressed: _isSaving ? null : _handleRecordPayment,
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
