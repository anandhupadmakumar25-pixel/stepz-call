import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass/glass_card.dart';
import '../../core/widgets/glass/gradient_button.dart';
import '../../core/services/pdf_invoice_service.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../models/lead_model.dart';
import '../../models/quotation_model.dart';
import '../../models/invoice_model.dart';
import '../../models/product_model.dart';
import '../../providers/billing_provider.dart';
import '../../providers/lead_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/company_provider.dart';

class QuotationFormDialog extends StatefulWidget {
  final LeadModel? lead;
  final bool isBill;
  final QuotationModel? quotationToEdit;
  final InvoiceModel? invoiceToEdit;

  const QuotationFormDialog({
    super.key,
    this.lead,
    this.isBill = false,
    this.quotationToEdit,
    this.invoiceToEdit,
  });

  @override
  State<QuotationFormDialog> createState() => _QuotationFormDialogState();
}

class _LineItemEntry {
  String rowType; // 'ITEM' or 'SECTION_TITLE'
  final TextEditingController titleController = TextEditingController();
  final TextEditingController itemCodeController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController qtyController = TextEditingController(text: '1');
  final TextEditingController rateController = TextEditingController(text: '0.00');
  final TextEditingController cstController = TextEditingController(text: '0.00'); // Cost Price (CST)
  final TextEditingController taxController = TextEditingController(text: '0');
  final TextEditingController discountController = TextEditingController(text: '0');
  final TextEditingController totalController = TextEditingController(text: '0.00');
  final Map<String, TextEditingController> customControllers = {};

  _LineItemEntry({this.rowType = 'ITEM'});

  bool get isSectionTitle => rowType == 'SECTION_TITLE';

  void dispose() {
    titleController.dispose();
    itemCodeController.dispose();
    descriptionController.dispose();
    qtyController.dispose();
    rateController.dispose();
    cstController.dispose();
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
  double get cst => isSectionTitle ? 0.0 : (double.tryParse(cstController.text) ?? 0.0);
  double get costSum => isSectionTitle ? 0.0 : (quantity * cst);
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

  double get grossMargin => computeLineTotal(showPrice: true, showQty: true, showTax: false) - costSum;
  double get marginPercent {
    final t = computeLineTotal(showPrice: true, showQty: true, showTax: false);
    return t > 0 ? (grossMargin / t) * 100 : 0.0;
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
      itemCode: itemCodeController.text.trim(),
      description: descriptionController.text.trim(),
      customFields: customFields,
      quantity: effQty,
      unitPrice: effRate,
      cst: cst,
      taxPercent: effTax,
      discountPercent: discountPercent,
      total: effTotal,
    );
  }
}

class _QuotationFormDialogState extends State<QuotationFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late bool _createAsInvoice;
  LeadModel? _selectedLead;
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;
  late TextEditingController _notesController;
  late TextEditingController _termsController;
  DateTime? _validUntil;

  // Professional Endless Perfume format metadata
  late TextEditingController _clientCodeController;
  late TextEditingController _salesRepController;
  late TextEditingController _incotermsController;
  late TextEditingController _locationController;
  late TextEditingController _contactPersonController;
  late TextEditingController _crNumberController;
  String _currency = 'INR';
  bool _showMarginAnalysis = true; // Toggle for CST & margin columns in table
  bool _hideCostInPdf = true; // Checkbox toggle for customer PDF export
  String? _errorMessage;

  final List<String> _customColumns = [];
  bool _showQty = true;
  bool _showPrice = true;
  bool _showTax = true;
  final ScrollController _horizontalScrollController = ScrollController();
  final List<_LineItemEntry> _items = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _createAsInvoice = widget.isBill;
    final editQ = widget.quotationToEdit;
    final lead = widget.lead;
    _selectedLead = lead;

    final user = context.read<AuthProvider>().currentUser;
    final comp = context.read<CompanyProvider>().activeCompanyDetail;

    if (editQ != null && editQ.currency.isNotEmpty) {
      _currency = editQ.currency;
    } else if (comp != null) {
      _currency = comp.currency;
    } else if (user != null && user.companyCurrency.isNotEmpty) {
      _currency = user.companyCurrency;
    } else {
      _currency = 'INR';
    }

    _clientCodeController = TextEditingController(
      text: editQ?.clientCode.isNotEmpty == true
          ? editQ!.clientCode
          : (lead != null ? 'SP-${lead.phoneNumber.replaceAll(RegExp(r'[^0-9]'), '').padLeft(4).substring(0, 4)}' : ''),
    );
    _salesRepController = TextEditingController(
      text: editQ?.salesRepName.isNotEmpty == true
          ? editQ!.salesRepName
          : (user?.fullName.isNotEmpty == true ? user!.fullName : (user?.username ?? '')),
    );
    _incotermsController = TextEditingController(
      text: editQ?.incoterms.isNotEmpty == true ? editQ!.incoterms : 'EX WORKSHOP DOHA',
    );
    _locationController = TextEditingController(
      text: editQ?.location.isNotEmpty == true ? editQ!.location : (lead?.city.isNotEmpty == true ? lead!.city : 'DOHA'),
    );
    _contactPersonController = TextEditingController(
      text: editQ?.contactPerson.isNotEmpty == true ? editQ!.contactPerson : (lead?.fullName ?? ''),
    );
    _crNumberController = TextEditingController(text: editQ?.crNumber ?? '');
    _hideCostInPdf = editQ?.hideCostInPdf ?? true;

    _nameController = TextEditingController(text: editQ?.customerName ?? lead?.fullName ?? '');
    _phoneController = TextEditingController(text: editQ?.customerPhone ?? lead?.phoneNumber ?? '');
    _emailController = TextEditingController(text: editQ?.customerEmail ?? lead?.email ?? '');
    _addressController = TextEditingController(
      text: editQ?.customerAddress.isNotEmpty == true
          ? editQ!.customerAddress
          : [lead?.city, lead?.state].where((s) => s != null && s.isNotEmpty).join(', '),
    );
    _notesController = TextEditingController(
      text: editQ?.notes.isNotEmpty == true
          ? editQ!.notes
          : (lead?.notes.isNotEmpty == true ? 'Regarding: ${lead!.notes}' : ''),
    );
    _termsController = TextEditingController(
      text: editQ?.termsAndConditions.isNotEmpty == true
          ? editQ!.termsAndConditions
          : 'JO Value below 5000: Should be fully paid in advance upon opening JO for all clients.\nJO Value above 5000: 50% advance payment & 50% postdated cheques in delivery timeline.\nOil maceration (minimum 1 week) | Bulk Maceration: 21 Days before filtering. Goods will be delivered in original packing. Approved orders will not be cancelled.',
    );
    _validUntil = DateTime.now().add(const Duration(days: 15));

    if (editQ != null) {
      _showQty = editQ.showQty;
      _showPrice = editQ.showPrice;
      _showTax = editQ.showTax;
      if (editQ.customColumns.isNotEmpty) {
        _customColumns.addAll(editQ.customColumns);
      }
    }

    if (editQ != null && editQ.items.isNotEmpty) {
      for (final it in editQ.items) {
        final row = _LineItemEntry(rowType: it.rowType);
        if (it.isSectionTitle) {
          row.titleController.text = it.title.isNotEmpty ? it.title : it.description;
          row.titleController.addListener(() => setState(() {}));
        } else {
          row.descriptionController.text = it.description;
          row.itemCodeController.text = it.itemCode;
          row.qtyController.text = it.quantity == it.quantity.roundToDouble() ? it.quantity.toInt().toString() : it.quantity.toString();
          row.rateController.text = it.unitPrice.toStringAsFixed(2);
          row.cstController.text = it.cst.toStringAsFixed(2);
          row.taxController.text = it.taxPercent.toStringAsFixed(0);
          row.discountController.text = it.discountPercent.toStringAsFixed(0);
          row.totalController.text = it.total > 0 ? it.total.toStringAsFixed(2) : (it.unitPrice > 0 ? it.unitPrice.toStringAsFixed(2) : '0.00');
          it.customFields.forEach((col, val) {
            row.getCustomController(col, () => setState(() {})).text = val;
          });
          row.descriptionController.addListener(() => setState(() {}));
          row.itemCodeController.addListener(() => setState(() {}));
          row.cstController.addListener(() => _onItemValuesChanged(row));
          row.qtyController.addListener(() => _onItemValuesChanged(row));
          row.rateController.addListener(() => _onItemValuesChanged(row));
          row.taxController.addListener(() => _onItemValuesChanged(row));
          row.discountController.addListener(() => _onItemValuesChanged(row));
          row.totalController.addListener(() => setState(() {}));
        }
        _items.add(row);
      }
    } else {
      _addItemRow();
    }

    // Fetch saved product catalog and leads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BillingProvider>().fetchProducts();
      final leadP = context.read<LeadProvider>();
      if (leadP.leads.isEmpty) {
        leadP.fetchLeads();
      }
    });
  }

  void _onItemValuesChanged(_LineItemEntry row) {
    if (_showPrice) {
      row.totalController.text = row.computeLineTotal(showPrice: _showPrice, showQty: _showQty, showTax: _showTax).toStringAsFixed(2);
    }
    setState(() {});
  }

  void _selectLead(LeadModel lead) {
    setState(() {
      _selectedLead = lead;
      _nameController.text = lead.fullName;
      _phoneController.text = lead.phoneNumber;
      if (lead.email.isNotEmpty) _emailController.text = lead.email;
      final addr = [lead.city, lead.state].where((s) => s.isNotEmpty).join(', ');
      if (addr.isNotEmpty) _addressController.text = addr;

      if (_locationController.text.isEmpty && lead.city.isNotEmpty) {
        _locationController.text = lead.city;
      }
      if (_contactPersonController.text.isEmpty) {
        _contactPersonController.text = lead.fullName;
      }
      if (_clientCodeController.text.isEmpty) {
        final digits = lead.phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
        final suffix = digits.length >= 4 ? digits.substring(digits.length - 4) : '1106';
        _clientCodeController.text = 'SP-$suffix';
      }

      if (lead.notes.isNotEmpty && (_notesController.text.isEmpty || _notesController.text.startsWith('Regarding:'))) {
        _notesController.text = 'Regarding: ${lead.notes}';
      }
    });
  }

  void _clearSelectedLead() {
    setState(() {
      _selectedLead = null;
    });
  }

  void _applyDynamicTerms() {
    final total = _calculatedGrandTotal;
    final buf = StringBuffer();
    if (total < 5000) {
      buf.writeln('JO Value below 5000:');
      buf.writeln('Should be fully paid in advance upon opening JO for all clients including new and old.');
    } else {
      buf.writeln('JO Value above 5000:');
      buf.writeln('Should be fully paid in advance Or 50% advance payment and remaining balance 50% as postdated cheques with dates in the delivery timeline.');
    }
    buf.writeln('');
    buf.writeln('Oil maceration (minimum 1 week) | Bulk Maceration: 21 Days before filtering. Goods will be delivered in original packing | Approved orders will not be cancelled and advances will not be refunded.');
    buf.writeln('All above listed references have been sampled and approved by the customer before order. Therefore, goods will not be taken back | Grievances regarding technicalities must be reported within a week of receiving goods thereafter they shall not be entertained | Price on proforma invoice will be valid for a month unless agreed in written.');
    setState(() {
      _termsController.text = buf.toString().trim();
    });
  }

  void _addItemRow({String? name, String? itemCode, double? price, double? cst, double? tax}) {
    final item = _LineItemEntry();
    if (name != null) item.descriptionController.text = name;
    if (itemCode != null) item.itemCodeController.text = itemCode;
    if (price != null) item.rateController.text = price.toStringAsFixed(2);
    if (cst != null) item.cstController.text = cst.toStringAsFixed(2);
    if (tax != null) item.taxController.text = tax.toStringAsFixed(0);

    for (final col in _customColumns) {
      item.getCustomController(col, () => setState(() {}));
    }

    item.totalController.text = item.computeLineTotal(showPrice: _showPrice, showQty: _showQty, showTax: _showTax).toStringAsFixed(2);

    item.descriptionController.addListener(() => setState(() {}));
    item.itemCodeController.addListener(() => setState(() {}));
    item.cstController.addListener(() => _onItemValuesChanged(item));
    item.qtyController.addListener(() => _onItemValuesChanged(item));
    item.rateController.addListener(() => _onItemValuesChanged(item));
    item.taxController.addListener(() => _onItemValuesChanged(item));
    item.discountController.addListener(() => _onItemValuesChanged(item));
    item.totalController.addListener(() => setState(() {}));
    _items.add(item);
  }

  void _addSectionTitleRow() {
    final item = _LineItemEntry(rowType: 'SECTION_TITLE');
    item.titleController.addListener(() => setState(() {}));
    setState(() => _items.add(item));
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
              Text('Customize Table Columns', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
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
                          title: Text('Unit Price / Rate', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600)),
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
                          title: Text('Tax / GST (%)', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600)),
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
                          label: Text('+ $sug', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF334155), fontWeight: FontWeight.w600)),
                          backgroundColor: const Color(0xFFF8FAFC),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
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
                        label: Text(col, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
                        backgroundColor: const Color(0xFFF1F5F9),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
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

  void _removeItemRow(int index) {
    if (_items.length > 1) {
      final removed = _items.removeAt(index);
      removed.dispose();
      setState(() {});
    }
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    _clientCodeController.dispose();
    _salesRepController.dispose();
    _incotermsController.dispose();
    _locationController.dispose();
    _contactPersonController.dispose();
    _crNumberController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    _termsController.dispose();
    for (var item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  double get _calculatedSubtotal {
    return _items.where((i) => !i.isSectionTitle).fold(0.0, (acc, item) {
      if (!_showPrice) {
        return acc + item.computeLineTotal(showPrice: _showPrice, showQty: _showQty, showTax: _showTax);
      }
      final effQty = _showQty ? item.quantity : 1.0;
      return acc + (effQty * item.rate);
    });
  }

  double get _calculatedDiscount {
    if (!_showPrice) return 0.0;
    return _items.where((i) => !i.isSectionTitle).fold(0.0, (acc, item) {
      final effQty = _showQty ? item.quantity : 1.0;
      final base = effQty * item.rate;
      return acc + (base * (item.discountPercent / 100.0));
    });
  }

  double get _calculatedTax {
    if (!_showTax || !_showPrice) return 0.0;
    return _items.where((i) => !i.isSectionTitle).fold(0.0, (acc, item) {
      final effQty = _showQty ? item.quantity : 1.0;
      final base = effQty * item.rate;
      final taxable = base - (base * (item.discountPercent / 100.0));
      return acc + (taxable * (item.taxPercent / 100.0));
    });
  }

  double get _calculatedGrandTotal {
    return _items.where((i) => !i.isSectionTitle).fold(0.0, (acc, item) {
      return acc + item.computeLineTotal(showPrice: _showPrice, showQty: _showQty, showTax: _showTax);
    });
  }

  double get _calculatedTotalCost {
    return _items.where((i) => !i.isSectionTitle).fold(0.0, (acc, item) {
      final effQty = _showQty ? item.quantity : 1.0;
      return acc + (effQty * item.cst);
    });
  }

  double get _calculatedGrossMargin => _calculatedGrandTotal - _calculatedTotalCost;
  double get _calculatedMarginPercent => _calculatedGrandTotal > 0 ? (_calculatedGrossMargin / _calculatedGrandTotal) * 100 : 0.0;

  Future<bool?> _promptPrintFormat(BuildContext context) async {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: GlassCard(
            blur: 24,
            opacity: 0.98,
            borderRadius: BorderRadius.circular(20),
            borderColor: const Color(0xFFCBD5E1),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF6366F1), size: 22),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Quotation PDF Format',
                          style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.pop(ctx, null),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Select the PDF presentation format to generate:',
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                ),
                const SizedBox(height: 16),

                // Option 1: Standard Client PDF
                InkWell(
                  onTap: () => Navigator.pop(ctx, false),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDBEAFE),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.person_outline_rounded, color: Color(0xFF1D4ED8), size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Client Quotation (Standard)',
                                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Clean customer-facing quote. Hides internal unit cost (CST) & profit margin.',
                                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Option 2: Commercial Quotation with CST
                InkWell(
                  onTap: () => Navigator.pop(ctx, true),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.analytics_rounded, color: Color(0xFFB45309), size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Commercial Quotation with CST',
                                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF92400E)),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Shows Unit Cost (CST), Cost SUM, and Gross Margin analysis.',
                                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF78350F)),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFFB45309)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<QuotationModel?> _saveQuotation() async {
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) {
      setState(() => _errorMessage = 'Please fix the highlighted fields in the form.');
      return null;
    }

    final validItems = _items.where((i) => i.isValid).toList();
    if (validItems.isEmpty) {
      setState(() => _errorMessage = 'Please add at least one line item or section title.');
      return null;
    }

    setState(() => _isSaving = true);
    final provider = context.read<BillingProvider>();

    final payload = <String, dynamic>{
      if (_selectedLead != null) 'lead': _selectedLead!.id,
      'customer_name': _nameController.text.trim(),
      'customer_phone': _phoneController.text.trim(),
      'customer_email': _emailController.text.trim(),
      'customer_address': _addressController.text.trim(),
      'client_code': _clientCodeController.text.trim(),
      'sales_rep_name': _salesRepController.text.trim(),
      'incoterms': _incotermsController.text.trim(),
      'location': _locationController.text.trim(),
      'contact_person': _contactPersonController.text.trim(),
      'cr_number': _crNumberController.text.trim(),
      'currency': _currency,
      if (_validUntil != null) 'valid_until': _validUntil!.toIso8601String().split('T').first,
      'custom_columns': {
        'columns': _customColumns,
        'show_qty': _showQty,
        'show_price': _showPrice,
        'show_tax': _showTax,
      },
      'items': validItems.map((i) => i.toModel(showPrice: _showPrice, showQty: _showQty, showTax: _showTax).toJson()).toList(),
      'subtotal': _calculatedSubtotal,
      'discount_amount': _calculatedDiscount,
      'tax_amount': _calculatedTax,
      'grand_total': _calculatedGrandTotal,
      'total_cost': _calculatedTotalCost,
      'gross_margin': _calculatedGrossMargin,
      'hide_cost_in_pdf': _hideCostInPdf,
      'notes': _notesController.text.trim(),
      'terms_and_conditions': _termsController.text.trim(),
      'status': 'SENT',
    };

    final result = widget.quotationToEdit != null
        ? await provider.updateQuotation(widget.quotationToEdit!.id, payload)
        : await provider.createQuotation(payload);
    setState(() => _isSaving = false);
    if (result == null && provider.errorMessage != null) {
      setState(() => _errorMessage = provider.errorMessage);
    }
    return result;
  }

  Future<InvoiceModel?> _saveInvoice() async {
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) {
      setState(() => _errorMessage = 'Please fix the highlighted fields in the form.');
      return null;
    }

    final validItems = _items.where((i) => i.isValid).toList();
    if (validItems.isEmpty) {
      setState(() => _errorMessage = 'Please add at least one line item or section title.');
      return null;
    }

    setState(() => _isSaving = true);
    final provider = context.read<BillingProvider>();

    final payload = <String, dynamic>{
      if (_selectedLead != null) 'lead': _selectedLead!.id,
      'customer_name': _nameController.text.trim(),
      'customer_phone': _phoneController.text.trim(),
      'customer_email': _emailController.text.trim(),
      'customer_address': _addressController.text.trim(),
      'client_code': _clientCodeController.text.trim(),
      'sales_rep_name': _salesRepController.text.trim(),
      'incoterms': _incotermsController.text.trim(),
      'location': _locationController.text.trim(),
      'contact_person': _contactPersonController.text.trim(),
      'cr_number': _crNumberController.text.trim(),
      'currency': _currency,
      if (_validUntil != null) 'due_date': _validUntil!.toIso8601String().split('T').first,
      'custom_columns': {
        'columns': _customColumns,
        'show_qty': _showQty,
        'show_price': _showPrice,
        'show_tax': _showTax,
      },
      'items': validItems.map((i) => i.toModel(showPrice: _showPrice, showQty: _showQty, showTax: _showTax).toJson()).toList(),
      'subtotal': _calculatedSubtotal,
      'discount_amount': _calculatedDiscount,
      'tax_amount': _calculatedTax,
      'grand_total': _calculatedGrandTotal,
      'total_cost': _calculatedTotalCost,
      'gross_margin': _calculatedGrossMargin,
      'hide_cost_in_pdf': _hideCostInPdf,
      'notes': _notesController.text.trim(),
      'terms_and_conditions': _termsController.text.trim(),
      'payment_status': widget.invoiceToEdit?.paymentStatus ?? 'PENDING',
    };

    final InvoiceModel? result;
    if (widget.invoiceToEdit != null) {
      result = await provider.updateInvoice(widget.invoiceToEdit!.id, payload);
    } else {
      result = await provider.createInvoice(payload);
    }
    setState(() => _isSaving = false);
    if (result == null && provider.errorMessage != null) {
      setState(() => _errorMessage = provider.errorMessage);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final products = context.watch<BillingProvider>().products;
    final leads = context.watch<LeadProvider>().leads;
    final isMobile = ResponsiveLayout.isMobile(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 16, vertical: isMobile ? 10 : 20),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 900, maxHeight: isMobile ? MediaQuery.of(context).size.height * 0.96 : 870),
        child: GlassCard(
          blur: 24,
          opacity: 0.98,
          borderRadius: BorderRadius.circular(20),
          borderColor: const Color(0xFFCBD5E1),
          padding: EdgeInsets.all(isMobile ? 14 : 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: _createAsInvoice
                                  ? const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)])
                                  : AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              _createAsInvoice ? Icons.receipt_long_rounded : Icons.request_quote_rounded,
                              color: Colors.white,
                              size: isMobile ? 20 : 24,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        widget.quotationToEdit != null
                                            ? 'Edit Quotation ${widget.quotationToEdit!.quotationNumber}'
                                            : (_createAsInvoice ? 'New Fixed Price Bill' : 'Generate Quotation'),
                                        style: GoogleFonts.inter(fontSize: isMobile ? 15 : 18, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: (_createAsInvoice ? const Color(0xFF059669) : const Color(0xFFF59E0B)).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: (_createAsInvoice ? const Color(0xFF059669) : const Color(0xFFF59E0B)).withValues(alpha: 0.4)),
                                      ),
                                      child: Text(
                                        _createAsInvoice ? 'FIXED' : 'ESTIMATE',
                                        style: GoogleFonts.inter(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w800,
                                          color: _createAsInvoice ? const Color(0xFF047857) : const Color(0xFFB45309),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  _selectedLead != null
                                      ? 'For Lead: ${_selectedLead!.fullName} (${_selectedLead!.phoneNumber})'
                                      : (_createAsInvoice ? 'Create official tax invoice with fixed pricing' : 'Create sales estimate with auto-saving catalog'),
                                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Mode Toggle Row: Quotation vs Fixed Price Bill
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _createAsInvoice = false;
                              _termsController.text =
                                  '1. Quotation is valid for 15 days from issue date.\n2. Payment terms as agreed.\n3. All prices include applicable taxes.';
                            });
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: !_createAsInvoice ? const Color(0xFF059669) : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.request_quote_rounded, size: 16, color: !_createAsInvoice ? Colors.white : const Color(0xFF475569)),
                                const SizedBox(width: 8),
                                Text(
                                  'Quotation (Estimate)',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: !_createAsInvoice ? FontWeight.w700 : FontWeight.w500,
                                    color: !_createAsInvoice ? Colors.white : const Color(0xFF475569),
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
                          onTap: () {
                            setState(() {
                              _createAsInvoice = true;
                              _termsController.text =
                                  '1. Payment due within 15 days of invoice date.\n2. Applicable GST and duties included.\n3. Goods/Services once sold are governed by standard service terms.';
                            });
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _createAsInvoice ? const Color(0xFF2563EB) : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.receipt_long_rounded, size: 16, color: _createAsInvoice ? Colors.white : const Color(0xFF475569)),
                                const SizedBox(width: 8),
                                Text(
                                  'Tax Invoice / Bill (Fixed Price)',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: _createAsInvoice ? FontWeight.w700 : FontWeight.w500,
                                    color: _createAsInvoice ? Colors.white : const Color(0xFF475569),
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
                const SizedBox(height: 10),

                // Note banner explaining Quotation vs Fixed Price Bill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _createAsInvoice ? const Color(0xFFEFF6FF) : const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _createAsInvoice ? const Color(0xFFBFDBFE) : const Color(0xFFA7F3D0)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _createAsInvoice ? Icons.receipt_long_rounded : Icons.info_outline_rounded,
                        size: 16,
                        color: _createAsInvoice ? const Color(0xFF2563EB) : const Color(0xFF059669),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _createAsInvoice
                              ? 'Official Tax Invoice: Product prices entered here will be saved directly as a Fixed Price Bill in Billing & Invoices.'
                              : 'Sales Quotation: Official commercial offer. When converted to an Invoice, amounts are finalized as a Fixed Price Bill.',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: _createAsInvoice ? const Color(0xFF1E40AF) : const Color(0xFF065F46),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 18, color: Color(0xFFDC2626)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFFB91C1C)),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFFDC2626)),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                          onPressed: () => setState(() => _errorMessage = null),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                const Divider(color: Color(0xFFE2E8F0), height: 1),
                const SizedBox(height: 12),

                // Main Form Body
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Customer Details Section Header & Lead Search Bar
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Customer Details',
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)),
                            ),
                            if (_selectedLead == null)
                              Text(
                                'Select from leads to auto-fill or enter manually below',
                                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // If lead is linked, show linked lead card banner
                        if (_selectedLead != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF86EFAC)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF16A34A),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.check, size: 14, color: Colors.white),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              'Linked Lead: ${_selectedLead!.fullName}',
                                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF14532D)),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFDCFCE7),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              _selectedLead!.status,
                                              style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: const Color(0xFF15803D)),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${_selectedLead!.phoneNumber}${_selectedLead!.city.isNotEmpty ? ' • ${_selectedLead!.city}' : ''}',
                                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF166534)),
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: _clearSelectedLead,
                                  icon: const Icon(Icons.swap_horiz_rounded, size: 16, color: Color(0xFF16A34A)),
                                  label: Text('Change / Search Another', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF16A34A))),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ] else ...[
                          _buildLeadSearchAutocomplete(leads),
                          const SizedBox(height: 12),
                        ],
                        // Customer & Commercial Metadata - Row 1
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: _buildInput(
                                label: 'Customer / Company Name *',
                                controller: _nameController,
                                icon: Icons.business_outlined,
                                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 15,
                              child: _buildInput(
                                label: 'Client Code',
                                controller: _clientCodeController,
                                icon: Icons.tag_rounded,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 15,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Currency', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF475569))),
                                  const SizedBox(height: 5),
                                  Container(
                                    height: 42,
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: const Color(0xFFCBD5E1)),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: _currency,
                                        isExpanded: true,
                                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                                        items: const [
                                          DropdownMenuItem(value: 'QAR', child: Text('QAR (ر.ق)')),
                                          DropdownMenuItem(value: 'AED', child: Text('AED (د.إ)')),
                                          DropdownMenuItem(value: 'SAR', child: Text('SAR (ر.س)')),
                                          DropdownMenuItem(value: 'OMR', child: Text('OMR (ر.ع.)')),
                                          DropdownMenuItem(value: 'KWD', child: Text('KWD (د.ك)')),
                                          DropdownMenuItem(value: 'BHD', child: Text('BHD (د.ب)')),
                                          DropdownMenuItem(value: 'INR', child: Text('INR (₹)')),
                                          DropdownMenuItem(value: 'USD', child: Text('USD (\$)')),
                                          DropdownMenuItem(value: 'EUR', child: Text('EUR (€)')),
                                          DropdownMenuItem(value: 'GBP', child: Text('GBP (£)')),
                                        ],
                                        onChanged: (val) {
                                          if (val != null) setState(() => _currency = val);
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: _buildInput(
                                label: 'Phone Number *',
                                controller: _phoneController,
                                icon: Icons.phone_outlined,
                                keyboardType: TextInputType.phone,
                                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Row 2: Contact Person, Location, CR Number, Email
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: _buildInput(
                                label: 'Contact Person',
                                controller: _contactPersonController,
                                icon: Icons.person_outline_rounded,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: _buildInput(
                                label: 'Location / City',
                                controller: _locationController,
                                icon: Icons.location_city_outlined,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: _buildInput(
                                label: 'CR / Reg Number',
                                controller: _crNumberController,
                                icon: Icons.badge_outlined,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: _buildInput(
                                label: 'Email',
                                controller: _emailController,
                                icon: Icons.email_outlined,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Row 3: Sales Rep, Incoterms, Billing Address, Valid Until
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: _buildInput(
                                label: 'Sales Rep',
                                controller: _salesRepController,
                                icon: Icons.support_agent_outlined,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: _buildInput(
                                label: 'Incoterms',
                                controller: _incotermsController,
                                icon: Icons.local_shipping_outlined,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 3,
                              child: _buildInput(
                                label: 'Billing Address',
                                controller: _addressController,
                                icon: Icons.location_on_outlined,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Valid Until', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF475569))),
                                  const SizedBox(height: 5),
                                  InkWell(
                                    onTap: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: _validUntil ?? DateTime.now().add(const Duration(days: 15)),
                                        firstDate: DateTime.now(),
                                        lastDate: DateTime.now().add(const Duration(days: 365)),
                                      );
                                      if (picked != null) setState(() => _validUntil = picked);
                                    },
                                    child: Container(
                                      height: 42,
                                      padding: const EdgeInsets.symmetric(horizontal: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: const Color(0xFFCBD5E1)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.calendar_today_outlined, size: 15, color: Color(0xFF2563EB)),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              _validUntil != null ? _validUntil!.toIso8601String().split('T').first : 'Select date',
                                              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF0F172A)),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Saved Products Quick Tag Bar
                        if (products.isNotEmpty) ...[
                          Row(
                            children: [
                              const Icon(Icons.inventory_2_outlined, size: 14, color: Color(0xFF64748B)),
                              const SizedBox(width: 6),
                              Text(
                                'Saved Products Catalog (Tap to quickly add row):',
                                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: products.take(8).map((p) {
                              return InkWell(
                                onTap: () {
                                  // If the last item is completely empty, populate it; otherwise add a new row
                                  if (_items.isNotEmpty && _items.last.descriptionController.text.trim().isEmpty) {
                                    final last = _items.last;
                                    last.descriptionController.text = p.name;
                                    last.rateController.text = p.unitPrice.toStringAsFixed(2);
                                    last.taxController.text = p.taxPercent.toStringAsFixed(0);
                                    setState(() {});
                                  } else {
                                    setState(() {
                                      _addItemRow(name: p.name, price: p.unitPrice, tax: p.taxPercent);
                                    });
                                  }
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFCBD5E1)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.add_rounded, size: 14, color: Color(0xFF2563EB)),
                                      const SizedBox(width: 4),
                                      Text(
                                        p.name,
                                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '₹${p.unitPrice.toStringAsFixed(0)}',
                                        style: GoogleFonts.robotoMono(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF059669)),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Line Items Table Header Toolbar
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _createAsInvoice ? 'Invoice Items & Specifications' : 'Quotation Items & Specifications',
                                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'AUTO-SAVES TO CATALOG',
                                    style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: const Color(0xFF92400E)),
                                  ),
                                ),
                              ],
                            ),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                // Quick Restore Chips if column is hidden
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
                                    label: Text('Price', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF2563EB))),
                                    backgroundColor: const Color(0xFFEFF6FF),
                                    side: const BorderSide(color: Color(0xFFBFDBFE)),
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () => setState(() => _showPrice = true),
                                  ),
                                if (!_showTax)
                                  ActionChip(
                                    avatar: const Icon(Icons.add_rounded, size: 14, color: Color(0xFF2563EB)),
                                    label: Text('Tax', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF2563EB))),
                                    backgroundColor: const Color(0xFFEFF6FF),
                                    side: const BorderSide(color: Color(0xFFBFDBFE)),
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () => setState(() => _showTax = true),
                                  ),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    backgroundColor: _showMarginAnalysis ? const Color(0xFFF0FDF4) : Colors.transparent,
                                    side: BorderSide(color: _showMarginAnalysis ? const Color(0xFF16A34A) : const Color(0xFFCBD5E1)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: () => setState(() => _showMarginAnalysis = !_showMarginAnalysis),
                                  icon: Icon(_showMarginAnalysis ? Icons.query_stats_rounded : Icons.visibility_off_outlined, size: 15, color: _showMarginAnalysis ? const Color(0xFF15803D) : const Color(0xFF64748B)),
                                  label: Text(_showMarginAnalysis ? 'Cost & Margin: ON' : 'Cost & Margin: OFF', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: _showMarginAnalysis ? const Color(0xFF15803D) : const Color(0xFF64748B))),
                                ),
                                InkWell(
                                  onTap: () => setState(() => _hideCostInPdf = !_hideCostInPdf),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: _hideCostInPdf ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: _hideCostInPdf ? const Color(0xFFFCD34D) : const Color(0xFFCBD5E1)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(_hideCostInPdf ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded, size: 15, color: _hideCostInPdf ? const Color(0xFFB45309) : const Color(0xFF64748B)),
                                        const SizedBox(width: 4),
                                        Text('Hide Cost in PDF', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: _hideCostInPdf ? const Color(0xFF92400E) : const Color(0xFF475569))),
                                      ],
                                    ),
                                  ),
                                ),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    side: const BorderSide(color: Color(0xFF6366F1)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: _showAddColumnDialog,
                                  icon: const Icon(Icons.view_column_rounded, size: 15, color: Color(0xFF4F46E5)),
                                  label: Text('Columns / Add Spec', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF4F46E5))),
                                ),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    side: const BorderSide(color: Color(0xFFD97706)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: _addSectionTitleRow,
                                  icon: const Icon(Icons.title_rounded, size: 15, color: Color(0xFFB45309)),
                                  label: Text('+ Add Title Row', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFFB45309))),
                                ),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2563EB),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: () => setState(() => _addItemRow()),
                                  icon: const Icon(Icons.add_rounded, size: 15),
                                  label: Text('+ Add Item Row', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700)),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Line Items Scrollable Container
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final double minTableWidth = 36 + 85 + 220 +
                                (_customColumns.length * 120) +
                                (_showQty ? 80 : 0) +
                                (_showPrice ? 110 : 0) +
                                (_showTax ? 75 : 0) +
                                (_showMarginAnalysis ? (85 + 90 + 95) : 0) +
                                115 + 76 + 32;
                            final double tableWidth = constraints.maxWidth > minTableWidth ? constraints.maxWidth : minTableWidth;

                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Scrollbar(
                                controller: _horizontalScrollController,
                                thumbVisibility: true,
                                child: SingleChildScrollView(
                                  controller: _horizontalScrollController,
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: SizedBox(
                                    width: tableWidth,
                                    child: Column(
                                      children: [
                                        // Table Header Row
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          decoration: const BoxDecoration(
                                            color: Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                                          ),
                                          child: Row(
                                            children: [
                                              SizedBox(
                                                width: 36,
                                                child: Text('#', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF475569))),
                                              ),
                                              const SizedBox(width: 8),
                                              SizedBox(
                                                width: 85,
                                                child: Text('Item Code', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF475569))),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text('Product / Type to Search', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF475569))),
                                              ),
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
                                                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF475569)),
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                      Tooltip(
                                                        message: 'Remove $col column',
                                                        child: InkWell(
                                                          onTap: () => _removeCustomColumn(col),
                                                          child: const Padding(
                                                            padding: EdgeInsets.only(left: 4),
                                                            child: Icon(Icons.close_rounded, size: 13, color: Color(0xFFEF4444)),
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
                                                    mainAxisAlignment: MainAxisAlignment.end,
                                                    children: [
                                                      Text('Qty', textAlign: TextAlign.right, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF475569))),
                                                      Tooltip(
                                                        message: 'Remove Qty column',
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
                                                      Text('Price ($_currency)', textAlign: TextAlign.right, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF475569))),
                                                      Tooltip(
                                                        message: 'Remove Price column',
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
                                                    mainAxisAlignment: MainAxisAlignment.end,
                                                    children: [
                                                      Text('Tax %', textAlign: TextAlign.right, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF475569))),
                                                      Tooltip(
                                                        message: 'Remove Tax column',
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
                                              if (_showMarginAnalysis) ...[
                                                const SizedBox(width: 8),
                                                SizedBox(
                                                  width: 85,
                                                  child: Text('CST ($_currency)', textAlign: TextAlign.right, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFFB45309))),
                                                ),
                                                const SizedBox(width: 8),
                                                SizedBox(
                                                  width: 90,
                                                  child: Text('Cost Sum', textAlign: TextAlign.right, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFFB45309))),
                                                ),
                                                const SizedBox(width: 8),
                                                SizedBox(
                                                  width: 95,
                                                  child: Text('Gross Margin', textAlign: TextAlign.right, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF15803D))),
                                                ),
                                              ],
                                              const SizedBox(width: 8),
                                              SizedBox(
                                                width: 115,
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.end,
                                                  children: [
                                                    Text('Total ($_currency)', textAlign: TextAlign.right, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF475569))),
                                                    const Padding(
                                                      padding: EdgeInsets.only(left: 4),
                                                      child: Icon(Icons.lock_outline_rounded, size: 11, color: Color(0xFF94A3B8)),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              const SizedBox(width: 76),
                                            ],
                                          ),
                                        ),
                                        // Rows
                                        ListView.separated(
                                          shrinkWrap: true,
                                          physics: const NeverScrollableScrollPhysics(),
                                          itemCount: _items.length,
                                          separatorBuilder: (_, __) => const Divider(color: Color(0xFFF1F5F9), height: 1),
                                          itemBuilder: (context, idx) {
                                            final item = _items[idx];

                                            // SECTION TITLE ROW
                                            if (item.isSectionTitle) {
                                              return Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFFFFBEB),
                                                  border: Border(
                                                    left: const BorderSide(color: Color(0xFFF59E0B), width: 4),
                                                    bottom: BorderSide(color: Colors.amber.shade100, width: 0.5),
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    SizedBox(
                                                      width: 36,
                                                      child: Text('${idx + 1}', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFFB45309))),
                                                    ),
                                                    const Icon(Icons.title_rounded, size: 18, color: Color(0xFFD97706)),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: TextFormField(
                                                        controller: item.titleController,
                                                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                                                        decoration: const InputDecoration(
                                                          hintText: 'Enter Section / Title Header (e.g. Phase 1: Planning, Hardware Components...)',
                                                          hintStyle: TextStyle(fontWeight: FontWeight.normal, fontSize: 12, color: Color(0xFF94A3B8)),
                                                          isDense: true,
                                                          border: OutlineInputBorder(),
                                                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFFFEF3C7),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: Text('TITLE ROW', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: const Color(0xFF92400E))),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    SizedBox(width: 76, child: _buildRowControls(idx)),
                                                  ],
                                                ),
                                              );
                                            }

                                            // REGULAR ITEM ROW
                                            return Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                              child: Row(
                                                children: [
                                                  SizedBox(
                                                    width: 36,
                                                    child: Text('${idx + 1}', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  // Item Code Field
                                                  SizedBox(
                                                    width: 85,
                                                    child: TextFormField(
                                                      controller: item.itemCodeController,
                                                      style: GoogleFonts.inter(fontSize: 12),
                                                      decoration: const InputDecoration(
                                                        hintText: 'Code',
                                                        isDense: true,
                                                        border: OutlineInputBorder(),
                                                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
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
                                                            hintText: 'Search or enter product...',
                                                            isDense: true,
                                                            border: OutlineInputBorder(),
                                                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                                          ),
                                                        );
                                                      },
                                                      optionsViewBuilder: (context, onSelected, options) {
                                                        return Align(
                                                          alignment: Alignment.topLeft,
                                                          child: Material(
                                                            elevation: 8,
                                                            borderRadius: BorderRadius.circular(10),
                                                            child: Container(
                                                              width: 320,
                                                              constraints: const BoxConstraints(maxHeight: 220),
                                                              decoration: BoxDecoration(
                                                                color: Colors.white,
                                                                borderRadius: BorderRadius.circular(10),
                                                                border: Border.all(color: const Color(0xFFCBD5E1)),
                                                              ),
                                                              child: ListView.separated(
                                                                padding: const EdgeInsets.symmetric(vertical: 4),
                                                                shrinkWrap: true,
                                                                itemCount: options.length,
                                                                separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                                                itemBuilder: (context, i) {
                                                                  final opt = options.elementAt(i);
                                                                  return ListTile(
                                                                    dense: true,
                                                                    visualDensity: VisualDensity.compact,
                                                                    title: Text(opt.name, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                                                                    subtitle: Text('Price: $_currency ${opt.unitPrice.toStringAsFixed(2)} · Tax ${opt.taxPercent.toStringAsFixed(0)}%', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B))),
                                                                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Color(0xFF94A3B8)),
                                                                    onTap: () => onSelected(opt),
                                                                  );
                                                                },
                                                              ),
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                  // Custom Columns Inputs
                                                  for (final col in _customColumns) ...[
                                                    const SizedBox(width: 8),
                                                    SizedBox(
                                                      width: 120,
                                                      child: TextFormField(
                                                        controller: item.getCustomController(col, () => setState(() {})),
                                                        style: GoogleFonts.inter(fontSize: 12),
                                                        decoration: InputDecoration(
                                                          hintText: col,
                                                          isDense: true,
                                                          border: const OutlineInputBorder(),
                                                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                  // Quantity
                                                  if (_showQty) ...[
                                                    const SizedBox(width: 8),
                                                    SizedBox(
                                                      width: 80,
                                                      child: TextFormField(
                                                        controller: item.qtyController,
                                                        textAlign: TextAlign.right,
                                                        keyboardType: TextInputType.number,
                                                        style: GoogleFonts.robotoMono(fontSize: 12),
                                                        decoration: const InputDecoration(
                                                          isDense: true,
                                                          border: OutlineInputBorder(),
                                                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                  // Unit Price
                                                  if (_showPrice) ...[
                                                    const SizedBox(width: 8),
                                                    SizedBox(
                                                      width: 110,
                                                      child: TextFormField(
                                                        controller: item.rateController,
                                                        textAlign: TextAlign.right,
                                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                        style: GoogleFonts.robotoMono(fontSize: 12),
                                                        decoration: const InputDecoration(
                                                          isDense: true,
                                                          border: OutlineInputBorder(),
                                                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                  // Tax %
                                                  if (_showTax) ...[
                                                    const SizedBox(width: 8),
                                                    SizedBox(
                                                      width: 75,
                                                      child: TextFormField(
                                                        controller: item.taxController,
                                                        textAlign: TextAlign.right,
                                                        keyboardType: TextInputType.number,
                                                        style: GoogleFonts.robotoMono(fontSize: 12),
                                                        decoration: const InputDecoration(
                                                          isDense: true,
                                                          border: OutlineInputBorder(),
                                                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                  // Cost & Margin columns
                                                  if (_showMarginAnalysis) ...[
                                                    const SizedBox(width: 8),
                                                    SizedBox(
                                                      width: 85,
                                                      child: TextFormField(
                                                        controller: item.cstController,
                                                        textAlign: TextAlign.right,
                                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                        style: GoogleFonts.robotoMono(fontSize: 12, color: const Color(0xFF0F172A)),
                                                        decoration: const InputDecoration(
                                                          hintText: '0.00',
                                                          isDense: true,
                                                          border: OutlineInputBorder(),
                                                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    SizedBox(
                                                      width: 90,
                                                      child: Text(
                                                        '$_currency ${item.costSum.toStringAsFixed(2)}',
                                                        textAlign: TextAlign.right,
                                                        style: GoogleFonts.robotoMono(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    SizedBox(
                                                      width: 95,
                                                      child: Text(
                                                        '$_currency ${item.grossMargin.toStringAsFixed(2)}\n(${item.marginPercent.toStringAsFixed(0)}%)',
                                                        textAlign: TextAlign.right,
                                                        style: GoogleFonts.robotoMono(
                                                          fontSize: 10.5,
                                                          fontWeight: FontWeight.w700,
                                                          color: item.grossMargin >= 0 ? const Color(0xFF15803D) : const Color(0xFFDC2626),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                  // Line Total (Editable if price is hidden, computed if price is visible)
                                                  const SizedBox(width: 8),
                                                  SizedBox(
                                                    width: 115,
                                                    child: _showPrice
                                                        ? Text(
                                                            '$_currency ${item.computeLineTotal(showPrice: _showPrice, showQty: _showQty, showTax: _showTax).toStringAsFixed(2)}',
                                                            textAlign: TextAlign.right,
                                                            style: GoogleFonts.robotoMono(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                                                          )
                                                        : TextFormField(
                                                            controller: item.totalController,
                                                            textAlign: TextAlign.right,
                                                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                            style: GoogleFonts.robotoMono(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                                                            decoration: const InputDecoration(
                                                              hintText: '0.00',
                                                              isDense: true,
                                                              border: OutlineInputBorder(),
                                                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                                            ),
                                                          ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  SizedBox(width: 76, child: _buildRowControls(idx)),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                        const SizedBox(height: 10),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),

                        // Totals Summary & Notes Row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Notes & Terms
                            Expanded(
                              flex: 5,
                              child: Column(
                                children: [
                                  _buildInput(
                                    label: 'Notes / Remarks',
                                    controller: _notesController,
                                    icon: Icons.notes_outlined,
                                    maxLines: 2,
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Terms & Conditions', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF475569))),
                                      TextButton.icon(
                                        onPressed: _applyDynamicTerms,
                                        icon: const Icon(Icons.auto_fix_high_rounded, size: 14, color: Color(0xFF2563EB)),
                                        label: Text('⚡ Auto-fill Terms (<5k / ≥5k Rule)', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF2563EB))),
                                        style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  TextFormField(
                                    controller: _termsController,
                                    maxLines: 3,
                                    style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF0F172A)),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      filled: true,
                                      fillColor: Colors.white,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 20),
                            // Calculation Card
                            Expanded(
                              flex: 4,
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  children: [
                                    _buildSummaryRow('Selling Subtotal', '$_currency ${_calculatedSubtotal.toStringAsFixed(2)}'),
                                    if (_calculatedDiscount > 0)
                                      _buildSummaryRow('Discount', '-$_currency ${_calculatedDiscount.toStringAsFixed(2)}', textColor: const Color(0xFFDC2626)),
                                    if (_calculatedTax > 0)
                                      _buildSummaryRow('Tax / GST', '$_currency ${_calculatedTax.toStringAsFixed(2)}'),
                                    const Divider(color: Color(0xFFCBD5E1), height: 16),
                                    _buildSummaryRow(
                                      'Grand Total',
                                      '$_currency ${_calculatedGrandTotal.toStringAsFixed(2)}',
                                      isBold: true,
                                      fontSize: 15,
                                      textColor: const Color(0xFF1E3A8A),
                                    ),
                                    if (_showMarginAnalysis) ...[
                                      const Divider(color: Color(0xFFCBD5E1), height: 16),
                                      _buildSummaryRow('Total Cost (CST)', '$_currency ${_calculatedTotalCost.toStringAsFixed(2)}', textColor: const Color(0xFF64748B)),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: _calculatedGrossMargin >= 0 ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: _calculatedGrossMargin >= 0 ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5)),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text('Gross Margin', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: _calculatedGrossMargin >= 0 ? const Color(0xFF15803D) : const Color(0xFFB91C1C))),
                                            Text(
                                              '$_currency ${_calculatedGrossMargin.toStringAsFixed(2)} (${_calculatedMarginPercent.toStringAsFixed(1)}%)',
                                              style: GoogleFonts.robotoMono(fontSize: 12, fontWeight: FontWeight.w800, color: _calculatedGrossMargin >= 0 ? const Color(0xFF15803D) : const Color(0xFFB91C1C)),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 6),
                                    Text(
                                      _createAsInvoice
                                          ? '* Fixed Price Tax Invoice with dynamic tenant branding.'
                                          : '* Estimated quote. Prices locked upon conversion to Bill.',
                                      style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B), fontStyle: FontStyle.italic),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(color: Color(0xFFE2E8F0), height: 1),
                const SizedBox(height: 16),

                // Action Buttons
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    TextButton(
                      onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                      child: Text('Cancel', style: GoogleFonts.inter(color: const Color(0xFF64748B), fontWeight: FontWeight.w600)),
                    ),
                    GlassSecondaryButton(
                      text: 'Save & WhatsApp',
                      icon: Icons.chat_bubble_outline_rounded,
                      onPressed: _isSaving
                          ? null
                          : () async {
                              final nav = Navigator.of(context);
                              final authUser = context.read<AuthProvider>().currentUser;
                              final comp = context.read<CompanyProvider>().activeCompanyDetail;
                              final String compName = comp?.name.isNotEmpty == true ? comp!.name : ((authUser?.companyName?.isNotEmpty == true) ? authUser!.companyName! : 'Stepz Telecaller CRM');
                              if (_createAsInvoice) {
                                final inv = await _saveInvoice();
                                if (inv != null) {
                                  nav.pop(inv);
                                  await PdfInvoiceService.shareInvoiceToWhatsApp(inv, companyName: compName);
                                }
                              } else {
                                final quote = await _saveQuotation();
                                if (quote != null) {
                                  nav.pop(quote);
                                  await PdfInvoiceService.shareQuotationToWhatsApp(quote, companyName: compName);
                                }
                              }
                            },
                    ),
                    GlassSecondaryButton(
                      text: 'Save & PDF',
                      icon: Icons.picture_as_pdf_outlined,
                      onPressed: _isSaving
                          ? null
                          : () async {
                              final nav = Navigator.of(context);
                              final authUser = context.read<AuthProvider>().currentUser;
                              final comp = context.read<CompanyProvider>().activeCompanyDetail;
                              final String compName = comp?.name.isNotEmpty == true ? comp!.name : ((authUser?.companyName?.isNotEmpty == true) ? authUser!.companyName! : 'Stepz Telecaller CRM');
                              final compPhone = comp?.contactPhone.isNotEmpty == true ? comp!.contactPhone : authUser?.companyPhone;
                              final compEmail = comp?.contactEmail.isNotEmpty == true ? comp!.contactEmail : authUser?.companyEmail;
                              final compAddress = comp?.address.isNotEmpty == true ? comp!.address : authUser?.companyAddress;
                              final compGstin = comp?.gstin.isNotEmpty == true ? comp!.gstin : authUser?.companyGstin;
                              final compWebsite = comp?.website.isNotEmpty == true ? comp!.website : authUser?.companyWebsite;
                              final compLogo = comp?.logo.isNotEmpty == true ? comp!.logo : authUser?.companyLogo;
                              if (_createAsInvoice) {
                                final inv = await _saveInvoice();
                                if (inv != null) {
                                  nav.pop(inv);
                                  await PdfInvoiceService.printInvoice(
                                    inv,
                                    companyName: compName,
                                    companyPhone: compPhone,
                                    companyEmail: compEmail,
                                    companyAddress: compAddress,
                                    companyGstin: compGstin,
                                    companyWebsite: compWebsite,
                                    companyLogo: compLogo,
                                  );
                                }
                              } else {
                                bool includeCst = !_hideCostInPdf;
                                if (_showMarginAnalysis) {
                                  final chosen = await _promptPrintFormat(context);
                                  if (chosen != null) {
                                    includeCst = chosen;
                                  }
                                }
                                final quote = await _saveQuotation();
                                if (quote != null) {
                                  nav.pop(quote);
                                  await PdfInvoiceService.printQuotation(
                                    quote,
                                    companyName: compName,
                                    companyPhone: compPhone,
                                    companyEmail: compEmail,
                                    companyAddress: compAddress,
                                    companyGstin: compGstin,
                                    companyWebsite: compWebsite,
                                    companyLogo: compLogo,
                                    includeCst: includeCst,
                                  );
                                }
                              }
                            },
                    ),
                    if (_createAsInvoice) ...[
                      GradientPrimaryButton(
                        text: _isSaving ? 'Creating Bill...' : 'Save Fixed Price Bill',
                        icon: Icons.check_circle_rounded,
                        gradient: const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)]),
                        onPressed: _isSaving
                            ? null
                            : () async {
                                final nav = Navigator.of(context);
                                final messenger = ScaffoldMessenger.of(context);
                                final inv = await _saveInvoice();
                                if (inv != null) {
                                  nav.pop(inv);
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text('Fixed Price Bill ${inv.invoiceNumber} created successfully!'),
                                      backgroundColor: const Color(0xFF10B981),
                                    ),
                                  );
                                }
                              },
                      ),
                    ] else ...[
                      GradientPrimaryButton(
                        text: _isSaving ? 'Saving...' : 'Save Quotation',
                        icon: Icons.check_circle_outline_rounded,
                        gradient: AppColors.primaryGradient,
                        onPressed: _isSaving
                            ? null
                            : () async {
                                final nav = Navigator.of(context);
                                final messenger = ScaffoldMessenger.of(context);
                                final quote = await _saveQuotation();
                                if (quote != null) {
                                  nav.pop(quote);
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text('Sales Quotation ${quote.quotationNumber} created & products saved!'),
                                      backgroundColor: const Color(0xFF10B981),
                                    ),
                                  );
                                }
                              },
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeadSearchAutocomplete(List<LeadModel> leads) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.person_search_rounded, size: 16, color: Color(0xFF2563EB)),
            const SizedBox(width: 6),
            Text(
              'Search Leads by Name or Phone (Tap to auto-fill details):',
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF2563EB)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Autocomplete<LeadModel>(
          optionsBuilder: (TextEditingValue textVal) {
            final query = textVal.text.trim().toLowerCase();
            if (query.isEmpty) {
              return leads.take(8);
            }
            return leads.where((lead) {
              final nameMatch = lead.fullName.toLowerCase().contains(query) ||
                  lead.firstName.toLowerCase().contains(query) ||
                  lead.lastName.toLowerCase().contains(query);
              final phoneMatch = lead.phoneNumber.contains(query) ||
                  lead.rawPhone.contains(query) ||
                  lead.normalizedPhone.contains(query);
              final cityMatch = lead.city.toLowerCase().contains(query);
              return nameMatch || phoneMatch || cityMatch;
            });
          },
          displayStringForOption: (LeadModel lead) => '${lead.fullName} (${lead.phoneNumber})',
          onSelected: (LeadModel selection) => _selectLead(selection),
          fieldViewBuilder: (context, searchController, focusNode, onFieldSubmitted) {
            return TextField(
              controller: searchController,
              focusNode: focusNode,
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF0F172A), fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: 'Search lead by name, phone number, or city to auto-fill...',
                hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF2563EB)),
                suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16, color: Color(0xFF94A3B8)),
                        onPressed: () {
                          searchController.clear();
                          setState(() {});
                        },
                      )
                    : const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF94A3B8)),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                ),
              ),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 10,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 520,
                  constraints: const BoxConstraints(maxHeight: 280),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: options.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(14),
                          child: Text(
                            'No leads found matching query',
                            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          shrinkWrap: true,
                          itemCount: options.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          itemBuilder: (context, i) {
                            final lead = options.elementAt(i);
                            return ListTile(
                              dense: true,
                              visualDensity: VisualDensity.compact,
                              leading: CircleAvatar(
                                radius: 16,
                                backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                child: Text(
                                  lead.fullName.isNotEmpty ? lead.fullName[0].toUpperCase() : 'L',
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF2563EB)),
                                ),
                              ),
                              title: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      lead.fullName,
                                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: const Color(0xFFBFDBFE)),
                                    ),
                                    child: Text(
                                      lead.status,
                                      style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: const Color(0xFF1D4ED8)),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Text(
                                '${lead.phoneNumber}${lead.city.isNotEmpty ? ' • ${lead.city}' : ''}',
                                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                              ),
                              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFF94A3B8)),
                              onTap: () => onSelected(lead),
                            );
                          },
                        ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRowControls(int idx) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_upward_rounded, size: 15, color: Color(0xFF64748B)),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
          tooltip: 'Move Up',
          onPressed: idx > 0 ? () => _moveRowUp(idx) : null,
        ),
        IconButton(
          icon: const Icon(Icons.arrow_downward_rounded, size: 15, color: Color(0xFF64748B)),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
          tooltip: 'Move Down',
          onPressed: idx < _items.length - 1 ? () => _moveRowDown(idx) : null,
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded, size: 17, color: Color(0xFFEF4444)),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          tooltip: 'Delete Row',
          onPressed: _items.length > 1 ? () => _removeItemRow(idx) : null,
        ),
      ],
    );
  }

  Widget _buildInput({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF475569))),
        const SizedBox(height: 5),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF0F172A)),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            prefixIcon: maxLines == 1 ? Icon(icon, size: 16, color: const Color(0xFF64748B)) : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false, double fontSize = 12, Color? textColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
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
