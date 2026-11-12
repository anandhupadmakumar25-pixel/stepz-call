import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/widgets/glass/glass_card.dart';
import '../../core/widgets/glass/gradient_button.dart';
import '../../models/product_model.dart';
import '../../models/quotation_model.dart';
import '../../providers/billing_provider.dart';

class ConvertQuotationDialog extends StatefulWidget {
  final QuotationModel quotation;

  const ConvertQuotationDialog({super.key, required this.quotation});

  @override
  State<ConvertQuotationDialog> createState() => _ConvertQuotationDialogState();
}

class _NegotiatedItemEntry {
  String rowType;
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final TextEditingController qtyController;
  final TextEditingController rateController;
  final TextEditingController taxController;
  final TextEditingController discountController;
  final TextEditingController totalController;
  final Map<String, TextEditingController> customControllers = {};

  _NegotiatedItemEntry({
    this.rowType = 'ITEM',
    String title = '',
    String description = '',
    double qty = 1,
    double rate = 0.0,
    double tax = 18,
    double discount = 0,
    double total = 0.0,
    Map<String, String> customFields = const {},
  })  : titleController = TextEditingController(text: title),
        descriptionController = TextEditingController(text: description),
        qtyController = TextEditingController(text: qty == qty.roundToDouble() ? qty.toInt().toString() : qty.toString()),
        rateController = TextEditingController(text: rate > 0 ? rate.toStringAsFixed(2) : '0.00'),
        taxController = TextEditingController(text: tax.toStringAsFixed(0)),
        discountController = TextEditingController(text: discount.toStringAsFixed(0)),
        totalController = TextEditingController(text: total > 0 ? total.toStringAsFixed(2) : '0.00') {
    customFields.forEach((k, v) {
      customControllers[k] = TextEditingController(text: v);
    });
  }

  bool get isSectionTitle => rowType == 'SECTION_TITLE';

  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    qtyController.dispose();
    rateController.dispose();
    taxController.dispose();
    discountController.dispose();
    totalController.dispose();
    for (final c in customControllers.values) {
      c.dispose();
    }
  }

  TextEditingController getCustomController(String col, [VoidCallback? listener]) {
    if (!customControllers.containsKey(col)) {
      final ctrl = TextEditingController();
      if (listener != null) ctrl.addListener(listener);
      customControllers[col] = ctrl;
    }
    return customControllers[col]!;
  }

  double get quantity => isSectionTitle ? 0.0 : (double.tryParse(qtyController.text) ?? 1.0);
  double get rate => isSectionTitle ? 0.0 : (double.tryParse(rateController.text) ?? 0.0);
  double get taxPercent => isSectionTitle ? 0.0 : (double.tryParse(taxController.text) ?? 0.0);
  double get discountPercent => isSectionTitle ? 0.0 : (double.tryParse(discountController.text) ?? 0.0);

  double computeLineTotal({required bool showPrice, required bool showQty, required bool showTax}) {
    if (isSectionTitle) return 0.0;
    if (!showPrice) {
      final direct = double.tryParse(totalController.text);
      if (direct != null) return direct;
      return rate;
    }
    final effQty = showQty ? quantity : 1.0;
    final effTax = showTax ? taxPercent : 0.0;
    final base = effQty * rate;
    final disc = base * (discountPercent / 100.0);
    final taxable = base - disc;
    return taxable + (taxable * (effTax / 100.0));
  }

  bool get isValid => isSectionTitle ? titleController.text.trim().isNotEmpty : descriptionController.text.trim().isNotEmpty;

  QuotationItemModel toModel({required bool showPrice, required bool showQty, required bool showTax}) {
    final customFields = <String, String>{};
    customControllers.forEach((key, controller) {
      customFields[key] = controller.text.trim();
    });

    final effQty = showQty ? quantity : 1.0;
    final effTax = showTax ? taxPercent : 0.0;
    final effTotal = computeLineTotal(showPrice: showPrice, showQty: showQty, showTax: showTax);
    final effRate = showPrice ? rate : (effQty > 0 ? (effTotal / effQty) : effTotal);

    return QuotationItemModel(
      rowType: rowType,
      title: titleController.text.trim(),
      description: descriptionController.text.trim(),
      customFields: customFields,
      quantity: effQty,
      unitPrice: effRate,
      taxPercent: effTax,
      discountPercent: discountPercent,
      total: effTotal,
    );
  }
}

class _ConvertQuotationDialogState extends State<ConvertQuotationDialog> {
  final _formKey = GlobalKey<FormState>();
  final List<String> _customColumns = [];
  bool _showQty = true;
  bool _showPrice = true;
  bool _showTax = true;
  final ScrollController _horizontalScrollController = ScrollController();
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
    _showQty = q.showQty;
    _showPrice = q.showPrice;
    _showTax = q.showTax;
    if (q.customColumns.isNotEmpty) {
      _customColumns.addAll(q.customColumns);
    }

    if (q.items.isNotEmpty) {
      for (final it in q.items) {
        final entry = _NegotiatedItemEntry(
          rowType: it.rowType,
          title: it.title,
          description: it.description,
          qty: it.quantity,
          rate: it.unitPrice,
          tax: it.taxPercent,
          discount: it.discountPercent,
          total: it.total,
          customFields: it.customFields,
        );
        _bindListeners(entry);
        _items.add(entry);
      }
    } else {
      final entry = _NegotiatedItemEntry(
        description: 'Sales Order Item',
        qty: 1,
        rate: q.subtotal > 0 ? q.subtotal : q.grandTotal,
        tax: 18,
        discount: 0,
        total: q.grandTotal,
      );
      _bindListeners(entry);
      _items.add(entry);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BillingProvider>().fetchProducts();
    });
  }

  void _onItemValuesChanged(_NegotiatedItemEntry it) {
    if (_showPrice) {
      it.totalController.text = it.computeLineTotal(showPrice: _showPrice, showQty: _showQty, showTax: _showTax).toStringAsFixed(2);
    }
    setState(() {});
  }

  void _bindListeners(_NegotiatedItemEntry it) {
    it.titleController.addListener(() => setState(() {}));
    it.descriptionController.addListener(() => setState(() {}));
    it.qtyController.addListener(() => _onItemValuesChanged(it));
    it.rateController.addListener(() => _onItemValuesChanged(it));
    it.taxController.addListener(() => _onItemValuesChanged(it));
    it.discountController.addListener(() => _onItemValuesChanged(it));
    it.totalController.addListener(() => setState(() {}));
  }

  void _addSectionTitleRow() {
    final entry = _NegotiatedItemEntry(rowType: 'SECTION_TITLE');
    _bindListeners(entry);
    setState(() => _items.add(entry));
  }

  void _moveRowUp(int index) {
    if (index > 0) {
      setState(() {
        final item = _items.removeAt(index);
        _items.insert(index - 1, item);
      });
    }
  }

  void _moveRowDown(int index) {
    if (index < _items.length - 1) {
      setState(() {
        final item = _items.removeAt(index);
        _items.insert(index + 1, item);
      });
    }
  }

  Future<void> _showAddColumnDialog() async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.view_column_rounded, color: Color(0xFF2563EB), size: 22),
              const SizedBox(width: 8),
              Text('Customize Bill Columns', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DEFAULT COLUMNS (ADD OR REMOVE)',
                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF64748B), letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        CheckboxListTile(
                          dense: true,
                          title: Text('Quantity (Qty)', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600)),
                          subtitle: Text('If removed, quantity defaults to 1 per item', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B))),
                          value: _showQty,
                          activeColor: const Color(0xFF2563EB),
                          onChanged: (val) {
                            setState(() => _showQty = val ?? true);
                            setDialogState(() {});
                          },
                        ),
                        const Divider(height: 1, color: Color(0xFFE2E8F0)),
                        CheckboxListTile(
                          dense: true,
                          title: Text('Unit Rate (Price)', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600)),
                          subtitle: Text('If removed, enter item total directly', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B))),
                          value: _showPrice,
                          activeColor: const Color(0xFF2563EB),
                          onChanged: (val) {
                            setState(() => _showPrice = val ?? true);
                            setDialogState(() {});
                          },
                        ),
                        const Divider(height: 1, color: Color(0xFFE2E8F0)),
                        CheckboxListTile(
                          dense: true,
                          title: Text('GST / Tax (%)', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600)),
                          subtitle: Text('If removed, zero tax is applied', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B))),
                          value: _showTax,
                          activeColor: const Color(0xFF2563EB),
                          onChanged: (val) {
                            setState(() => _showTax = val ?? true);
                            setDialogState(() {});
                          },
                        ),
                        const Divider(height: 1, color: Color(0xFFE2E8F0)),
                        CheckboxListTile(
                          dense: true,
                          title: Row(
                            children: [
                              Text('Total (₹)', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text('REQUIRED / LOCKED', style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w800, color: const Color(0xFF15803D))),
                              ),
                            ],
                          ),
                          subtitle: Text('Total cannot be removed', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B))),
                          value: true,
                          onChanged: null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'ADD CUSTOM SPECIFICATION COLUMN',
                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF64748B), letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          style: GoogleFonts.inter(fontSize: 13),
                          decoration: const InputDecoration(
                            hintText: 'e.g. HSN/SAC, Unit, Delivery Time...',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                          onSubmitted: (val) {
                            if (val.trim().isNotEmpty && !_customColumns.contains(val.trim())) {
                              setState(() {
                                _customColumns.add(val.trim());
                                for (var row in _items) {
                                  row.getCustomController(val.trim(), () => setState(() {}));
                                }
                              });
                              controller.clear();
                              setDialogState(() {});
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          final text = controller.text.trim();
                          if (text.isNotEmpty && !_customColumns.contains(text)) {
                            setState(() {
                              _customColumns.add(text);
                              for (var row in _items) {
                                row.getCustomController(text, () => setState(() {}));
                              }
                            });
                            controller.clear();
                            setDialogState(() {});
                          }
                        },
                        child: const Text('Add', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      'HSN/SAC', 'Unit', 'Delivery Time', 'Brand', 'Size', 'Warranty', 'Serial No.'
                    ].map((sug) => ActionChip(
                          label: Text('+ $sug', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF2563EB), fontWeight: FontWeight.w600)),
                          backgroundColor: const Color(0xFFEFF6FF),
                          side: const BorderSide(color: Color(0xFFBFDBFE)),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            if (!_customColumns.contains(sug)) {
                              setState(() {
                                _customColumns.add(sug);
                                for (var row in _items) {
                                  row.getCustomController(sug, () => setState(() {}));
                                }
                              });
                              setDialogState(() {});
                            }
                          },
                        )).toList(),
                  ),
                  if (_customColumns.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('Active Custom Columns:', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF475569))),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: _customColumns.map((col) => Chip(
                        label: Text(col, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF4338CA))),
                        backgroundColor: const Color(0xFFEEF2FF),
                        side: const BorderSide(color: Color(0xFFC7D2FE)),
                        deleteIcon: const Icon(Icons.close_rounded, size: 14, color: Color(0xFFEF4444)),
                        onDeleted: () {
                          _removeCustomColumn(col);
                          setDialogState(() {});
                        },
                      )).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _removeCustomColumn(String col) {
    setState(() {
      _customColumns.remove(col);
      for (var row in _items) {
        row.customControllers[col]?.dispose();
        row.customControllers.remove(col);
      }
    });
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    for (final it in _items) {
      it.dispose();
    }
    _negotiationDiscountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double get _itemsBaseSubtotal {
    return _items.where((it) => !it.isSectionTitle).fold(0.0, (acc, it) {
      if (!_showPrice) {
        return acc + it.computeLineTotal(showPrice: _showPrice, showQty: _showQty, showTax: _showTax);
      }
      final effQty = _showQty ? it.quantity : 1.0;
      return acc + (effQty * it.rate);
    });
  }

  double get _itemsDiscountTotal {
    if (!_showPrice) return 0.0;
    return _items.where((it) => !it.isSectionTitle).fold(0.0, (acc, it) {
      final effQty = _showQty ? it.quantity : 1.0;
      final base = effQty * it.rate;
      return acc + (base * (it.discountPercent / 100.0));
    });
  }

  double get _specialNegotiationDiscount => double.tryParse(_negotiationDiscountController.text) ?? 0.0;
  double get _totalDiscount => _itemsDiscountTotal + _specialNegotiationDiscount;

  // _taxableSubtotal handled in grand total

  double get _calculatedTax {
    if (!_showTax || !_showPrice) return 0.0;
    return _items.where((it) => !it.isSectionTitle).fold(0.0, (acc, it) {
      final effQty = _showQty ? it.quantity : 1.0;
      final base = effQty * it.rate;
      final taxable = base - (base * (it.discountPercent / 100.0));
      return acc + (taxable * (it.taxPercent / 100.0));
    });
  }

  double get _finalGrandTotal {
    return _items.where((it) => !it.isSectionTitle).fold(0.0, (acc, it) {
      return acc + it.computeLineTotal(showPrice: _showPrice, showQty: _showQty, showTax: _showTax);
    }) - _specialNegotiationDiscount;
  }

  Future<void> _submitConversion({bool useOriginalQuote = false}) async {
    final q = widget.quotation;
    final provider = context.read<BillingProvider>();
    setState(() => _isConverting = true);

    Map<String, dynamic> overrideData;
    if (useOriginalQuote) {
      overrideData = {
        'items': q.items.map((it) => it.toJson()).toList(),
        'custom_columns': {
          'columns': q.customColumns,
          'show_qty': q.showQty,
          'show_price': q.showPrice,
          'show_tax': q.showTax,
        },
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
            .where((i) => i.isValid)
            .map((i) => i.toModel(showPrice: _showPrice, showQty: _showQty, showTax: _showTax).toJson())
            .toList(),
        'custom_columns': {
          'columns': _customColumns,
          'show_qty': _showQty,
          'show_price': _showPrice,
          'show_tax': _showTax,
        },
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

  Widget _buildRowControls(int idx) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_upward_rounded, size: 14, color: Color(0xFF64748B)),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
          tooltip: 'Move Up',
          onPressed: idx > 0 ? () => _moveRowUp(idx) : null,
        ),
        IconButton(
          icon: const Icon(Icons.arrow_downward_rounded, size: 14, color: Color(0xFF64748B)),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
          tooltip: 'Move Down',
          onPressed: idx < _items.length - 1 ? () => _moveRowDown(idx) : null,
        ),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline_rounded, size: 16, color: Color(0xFFEF4444)),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
          tooltip: 'Delete Row',
          onPressed: _items.length > 1
              ? () {
                  setState(() {
                    _items.removeAt(idx).dispose();
                  });
                }
              : null,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.quotation;
    final products = context.watch<BillingProvider>().products;
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

                // Editable Items Table Header Toolbar
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 6,
                  children: [
                    Text(
                      'Bill Items & Custom Specifications',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (!_showQty)
                          ActionChip(
                            avatar: const Icon(Icons.add_rounded, size: 14, color: Color(0xFF2563EB)),
                            label: Text('Qty', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF2563EB))),
                            backgroundColor: const Color(0xFFEFF6FF),
                            side: const BorderSide(color: Color(0xFFBFDBFE)),
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            onPressed: () => setState(() => _showQty = true),
                          ),
                        if (!_showPrice)
                          ActionChip(
                            avatar: const Icon(Icons.add_rounded, size: 14, color: Color(0xFF2563EB)),
                            label: Text('Rate', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF2563EB))),
                            backgroundColor: const Color(0xFFEFF6FF),
                            side: const BorderSide(color: Color(0xFFBFDBFE)),
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            onPressed: () => setState(() => _showPrice = true),
                          ),
                        if (!_showTax)
                          ActionChip(
                            avatar: const Icon(Icons.add_rounded, size: 14, color: Color(0xFF2563EB)),
                            label: Text('GST', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF2563EB))),
                            backgroundColor: const Color(0xFFEFF6FF),
                            side: const BorderSide(color: Color(0xFFBFDBFE)),
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            onPressed: () => setState(() => _showTax = true),
                          ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            side: const BorderSide(color: Color(0xFF6366F1)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: _showAddColumnDialog,
                          icon: const Icon(Icons.view_column_rounded, size: 14, color: Color(0xFF4F46E5)),
                          label: Text('Columns / Add Spec', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF4F46E5))),
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            side: const BorderSide(color: Color(0xFFD97706)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: _addSectionTitleRow,
                          icon: const Icon(Icons.title_rounded, size: 14, color: Color(0xFFB45309)),
                          label: Text('+ Add Title Row', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFFB45309))),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () {
                            final entry = _NegotiatedItemEntry(description: '', qty: 1, rate: 0.0, tax: 18, discount: 0);
                            for (final col in _customColumns) {
                              entry.getCustomController(col, () => setState(() {}));
                            }
                            _bindListeners(entry);
                            setState(() => _items.add(entry));
                          },
                          icon: const Icon(Icons.add_rounded, size: 14),
                          label: Text('+ Add Line Item', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Editable Scrollable Items Table
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final double minTableWidth = 28 + 240 +
                          (_customColumns.length * 128) +
                          (_showQty ? 85 : 0) +
                          (_showPrice ? 115 : 0) +
                          (_showTax ? 80 : 0) +
                          115 + 76 + 20;
                      final double tableWidth = constraints.maxWidth > minTableWidth ? constraints.maxWidth : minTableWidth;

                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Scrollbar(
                          controller: _horizontalScrollController,
                          thumbVisibility: true,
                          child: SingleChildScrollView(
                            controller: _horizontalScrollController,
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                              width: tableWidth,
                              child: Column(
                                children: [
                                  // Table Header
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.only(topLeft: Radius.circular(10), topRight: Radius.circular(10)),
                                    ),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 28,
                                          child: Text('#', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF475569))),
                                        ),
                                        Expanded(child: Text('Product / Type to Search', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF475569)))),
                                        for (final col in _customColumns) ...[
                                          const SizedBox(width: 8),
                                          SizedBox(
                                            width: 120,
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    col,
                                                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF4338CA)),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                Tooltip(
                                                  message: 'Remove $col column',
                                                  child: InkWell(
                                                    onTap: () => _removeCustomColumn(col),
                                                    child: const Padding(
                                                      padding: EdgeInsets.only(left: 4),
                                                      child: Icon(Icons.close_rounded, size: 12, color: Color(0xFFEF4444)),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                        if (_showQty) ...[
                                          const SizedBox(width: 8),
                                          SizedBox(
                                            width: 80,
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Text('QTY', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF475569))),
                                                Tooltip(
                                                  message: 'Remove Quantity column',
                                                  child: InkWell(
                                                    onTap: () => setState(() => _showQty = false),
                                                    child: const Padding(
                                                      padding: EdgeInsets.only(left: 4),
                                                      child: Icon(Icons.close_rounded, size: 12, color: Color(0xFFEF4444)),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                        if (_showPrice) ...[
                                          const SizedBox(width: 8),
                                          SizedBox(
                                            width: 110,
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.end,
                                              children: [
                                                Text('RATE (₹)', textAlign: TextAlign.right, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF475569))),
                                                Tooltip(
                                                  message: 'Remove Rate column',
                                                  child: InkWell(
                                                    onTap: () => setState(() => _showPrice = false),
                                                    child: const Padding(
                                                      padding: EdgeInsets.only(left: 4),
                                                      child: Icon(Icons.close_rounded, size: 12, color: Color(0xFFEF4444)),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                        if (_showTax) ...[
                                          const SizedBox(width: 8),
                                          SizedBox(
                                            width: 75,
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Text('GST %', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF475569))),
                                                Tooltip(
                                                  message: 'Remove GST column',
                                                  child: InkWell(
                                                    onTap: () => setState(() => _showTax = false),
                                                    child: const Padding(
                                                      padding: EdgeInsets.only(left: 4),
                                                      child: Icon(Icons.close_rounded, size: 12, color: Color(0xFFEF4444)),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                        const SizedBox(width: 8),
                                        SizedBox(
                                          width: 110,
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            children: [
                                              Text('TOTAL (₹)', textAlign: TextAlign.right, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF475569))),
                                              const Padding(
                                                padding: EdgeInsets.only(left: 4),
                                                child: Icon(Icons.lock_outline_rounded, size: 11, color: Color(0xFF94A3B8)),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const SizedBox(width: 68),
                                      ],
                                    ),
                                  ),
                                  // Rows
                                  Expanded(
                                    child: ListView.separated(
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      itemCount: _items.length,
                                      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                      itemBuilder: (context, idx) {
                                        final item = _items[idx];

                                        if (item.isSectionTitle) {
                                          return Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFFFBEB),
                                              border: Border(
                                                left: const BorderSide(color: Color(0xFFF59E0B), width: 4),
                                                top: BorderSide(color: Colors.amber.shade200, width: 0.5),
                                                bottom: BorderSide(color: Colors.amber.shade200, width: 0.5),
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                SizedBox(
                                                  width: 28,
                                                  child: Text('${idx + 1}', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFB45309))),
                                                ),
                                                const Icon(Icons.title_rounded, size: 16, color: Color(0xFFD97706)),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: TextField(
                                                    controller: item.titleController,
                                                    style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                                                    decoration: const InputDecoration(
                                                      isDense: true,
                                                      border: InputBorder.none,
                                                      hintText: 'Enter Section / Title Header...',
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFFEF3C7),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text('TITLE ROW', style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w800, color: const Color(0xFF92400E))),
                                                ),
                                                const SizedBox(width: 8),
                                                _buildRowControls(idx),
                                              ],
                                            ),
                                          );
                                        }

                                        return Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          child: Row(
                                            children: [
                                              SizedBox(
                                                width: 28,
                                                child: Text('${idx + 1}', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                                              ),
                                              // Product Search Autocomplete Field
                                              Expanded(
                                                child: Autocomplete<ProductModel>(
                                                  optionsBuilder: (TextEditingValue textVal) {
                                                    if (textVal.text.trim().isEmpty) {
                                                      return products.take(6);
                                                    }
                                                    return products.where((p) => p.name.toLowerCase().contains(textVal.text.toLowerCase()));
                                                  },
                                                  displayStringForOption: (ProductModel p) => p.name,
                                                  onSelected: (ProductModel selection) {
                                                    item.descriptionController.text = selection.name;
                                                    item.rateController.text = selection.unitPrice.toStringAsFixed(2);
                                                    item.taxController.text = selection.taxPercent.toStringAsFixed(0);
                                                    _onItemValuesChanged(item);
                                                  },
                                                  fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                                                    if (textEditingController.text != item.descriptionController.text && item.descriptionController.text.isNotEmpty) {
                                                      textEditingController.text = item.descriptionController.text;
                                                    }
                                                    return TextFormField(
                                                      controller: textEditingController,
                                                      focusNode: focusNode,
                                                      style: GoogleFonts.inter(fontSize: 12),
                                                      onChanged: (val) {
                                                        item.descriptionController.text = val;
                                                        final match = products.where((p) => p.name.trim().toLowerCase() == val.trim().toLowerCase()).firstOrNull;
                                                        if (match != null) {
                                                          item.rateController.text = match.unitPrice.toStringAsFixed(2);
                                                          item.taxController.text = match.taxPercent.toStringAsFixed(0);
                                                          _onItemValuesChanged(item);
                                                        } else {
                                                          setState(() {});
                                                        }
                                                      },
                                                      decoration: const InputDecoration(
                                                        hintText: 'Search or enter item...',
                                                        isDense: true,
                                                        border: OutlineInputBorder(),
                                                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                              // Custom Columns inputs
                                              for (final col in _customColumns) ...[
                                                const SizedBox(width: 8),
                                                SizedBox(
                                                  width: 120,
                                                  child: TextField(
                                                    controller: item.getCustomController(col, () => setState(() {})),
                                                    style: GoogleFonts.inter(fontSize: 12),
                                                    decoration: InputDecoration(
                                                      isDense: true,
                                                      border: const OutlineInputBorder(),
                                                      hintText: col,
                                                      contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                              // Qty
                                              if (_showQty) ...[
                                                const SizedBox(width: 8),
                                                SizedBox(
                                                  width: 80,
                                                  child: TextField(
                                                    controller: item.qtyController,
                                                    textAlign: TextAlign.center,
                                                    keyboardType: TextInputType.number,
                                                    style: GoogleFonts.robotoMono(fontSize: 12.5, fontWeight: FontWeight.bold),
                                                    decoration: const InputDecoration(
                                                      isDense: true,
                                                      border: OutlineInputBorder(),
                                                      contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                              // Rate
                                              if (_showPrice) ...[
                                                const SizedBox(width: 8),
                                                SizedBox(
                                                  width: 110,
                                                  child: TextField(
                                                    controller: item.rateController,
                                                    textAlign: TextAlign.right,
                                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                    style: GoogleFonts.robotoMono(fontSize: 12.5, fontWeight: FontWeight.bold),
                                                    decoration: const InputDecoration(
                                                      isDense: true,
                                                      border: OutlineInputBorder(),
                                                      contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                              // GST
                                              if (_showTax) ...[
                                                const SizedBox(width: 8),
                                                SizedBox(
                                                  width: 75,
                                                  child: TextField(
                                                    controller: item.taxController,
                                                    textAlign: TextAlign.center,
                                                    keyboardType: TextInputType.number,
                                                    style: GoogleFonts.robotoMono(fontSize: 12),
                                                    decoration: const InputDecoration(
                                                      isDense: true,
                                                      border: OutlineInputBorder(),
                                                      contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                              // Line Total (Editable if price is hidden, computed if price is visible)
                                              const SizedBox(width: 8),
                                              SizedBox(
                                                width: 110,
                                                child: _showPrice
                                                    ? Text(
                                                        '₹${item.computeLineTotal(showPrice: _showPrice, showQty: _showQty, showTax: _showTax).toStringAsFixed(2)}',
                                                        textAlign: TextAlign.right,
                                                        style: GoogleFonts.robotoMono(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                                                      )
                                                    : TextFormField(
                                                        controller: item.totalController,
                                                        textAlign: TextAlign.right,
                                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                        style: GoogleFonts.robotoMono(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                                                        decoration: const InputDecoration(
                                                          hintText: '0.00',
                                                          isDense: true,
                                                          border: OutlineInputBorder(),
                                                          contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                                        ),
                                                      ),
                                              ),
                                              const SizedBox(width: 8),
                                              _buildRowControls(idx),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
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

