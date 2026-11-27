import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/action_loader.dart';
import '../../core/widgets/glass/app_background.dart';
import '../../core/widgets/glass/glass_card.dart';
import '../../core/widgets/glass/gradient_button.dart';
import '../../core/services/pdf_invoice_service.dart';
import '../../core/utils/region_detector.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../models/lead_model.dart';
import '../../models/quotation_model.dart';
import '../../models/invoice_model.dart';
import '../../models/product_model.dart';
import '../../models/plan_model.dart';
import '../../models/document_template_model.dart';
import '../../providers/billing_provider.dart';
import '../../providers/employee_provider.dart';
import '../../providers/lead_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/company_provider.dart';

class QuotationFormDialog extends StatefulWidget {
  final LeadModel? lead;
  final bool isBill;
  final QuotationModel? quotationToEdit;
  final InvoiceModel? invoiceToEdit;
  final bool asPage;

  const QuotationFormDialog({
    super.key,
    this.lead,
    this.isBill = false,
    this.quotationToEdit,
    this.invoiceToEdit,
    this.asPage = true,
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
  bool _showMobilePreview = false;
  static const String _mainBranchSentinel = '__MAIN__';
  String? _selectedBranchId;
  String? _selectedTemplateId;
  Map<String, dynamic> _selectedTemplateSnapshot = {};
  final Map<String, TextEditingController> _customFieldControllers = {};
  final TextEditingController _bankDetailsController = TextEditingController();

  TemplateLayoutConfig get _activeTemplateLayout => TemplateLayoutConfig.fromJson(
        _selectedTemplateSnapshot,
        docType: _createAsInvoice ? 'INVOICE' : 'QUOTATION',
      );

  @override
  void initState() {
    super.initState();
    _createAsInvoice = widget.isBill;
    final editQ = widget.quotationToEdit;
    final lead = widget.lead;
    _selectedLead = lead;

    final user = context.read<AuthProvider>().currentUser;
    final comp = context.read<CompanyProvider>().activeCompanyDetail;
    _showMarginAnalysis = user?.hasPermission('quotations.view_cost_cst') ?? false;

    if (editQ != null && editQ.currency.isNotEmpty) {
      _currency = editQ.currency;
    } else if (user != null && user.companyCurrency.isNotEmpty) {
      _currency = user.companyCurrency;
    } else if (comp != null && comp.currency.isNotEmpty) {
      _currency = comp.currency;
    } else {
      _currency = 'INR';
    }

    _clientCodeController = TextEditingController(
      text: editQ?.clientCode ?? '',
    );
    _salesRepController = TextEditingController(
      text: editQ?.salesRepName.isNotEmpty == true
          ? editQ!.salesRepName
          : (user?.fullName.isNotEmpty == true ? user!.fullName : (user?.username ?? '')),
    );
    _incotermsController = TextEditingController(
      text: editQ?.incoterms ?? '',
    );
    _locationController = TextEditingController(
      text: editQ?.location.isNotEmpty == true ? editQ!.location : (lead?.city ?? ''),
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

    if (editQ != null) {
      _selectedTemplateId = editQ.templateId;
      _selectedTemplateSnapshot = Map<String, dynamic>.from(editQ.templateSnapshot);
      _syncTemplateControllers();
    } else if (widget.invoiceToEdit != null) {
      _selectedTemplateId = widget.invoiceToEdit!.templateId;
      _selectedTemplateSnapshot = Map<String, dynamic>.from(widget.invoiceToEdit!.templateSnapshot);
      _syncTemplateControllers();
    }
    if (user?.branchId?.isNotEmpty == true) {
      _selectedBranchId = user!.branchId;
    }

    // Fetch saved product catalog, leads, branches, employees, and document templates
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final bp = context.read<BillingProvider>();
      bp.fetchProducts();
      final leadP = context.read<LeadProvider>();
      if (leadP.leads.isEmpty) {
        leadP.fetchLeads();
      }
      if (leadP.branches.isEmpty) {
        await leadP.fetchBranches();
      }
      if (!mounted) return;
      final empP = context.read<EmployeeProvider>();
      if (empP.employees.isEmpty) {
        await empP.fetchEmployees();
      }
      if (!mounted) return;
      _autoResolveBranch();
      final docType = _createAsInvoice ? 'INVOICE' : 'QUOTATION';
      await bp.fetchTemplates(docType: docType);
      if (!mounted) return;
      if (widget.quotationToEdit == null && widget.invoiceToEdit == null && _selectedTemplateId == null) {
        final def = bp.defaultTemplateFor(docType);
        if (def != null) {
          _applyTemplate(def);
        } else {
          setState(() => _syncTemplateControllers());
        }
      }
    });
  }

  String? _branchIdForRepName(String repName, List<dynamic> employees) {
    final target = repName.trim().toLowerCase();
    if (target.isEmpty) return null;
    for (final emp in employees) {
      final full = '${emp['first_name'] ?? ''} ${emp['last_name'] ?? ''}'.trim().toLowerCase();
      final email = (emp['email']?.toString() ?? '').trim().toLowerCase();
      if (full == target || email == target) {
        final bId = emp['branch']?.toString() ?? '';
        if (bId.isNotEmpty) return bId;
      }
    }
    return null;
  }

  String _defaultMainOrFirstBranchId(List<dynamic> branches) {
    if (branches.isEmpty) return _mainBranchSentinel;
    for (final b in branches) {
      final name = (b.name ?? '').toString().toLowerCase();
      if (name.contains('main') || name.contains('head') || name.contains('hq')) {
        return b.id.toString();
      }
    }
    return branches.first.id.toString();
  }

  void _autoResolveBranch() {
    if (!mounted) return;
    final branches = context.read<LeadProvider>().branches;
    final employees = context.read<EmployeeProvider>().employees;
    final authUser = context.read<AuthProvider>().currentUser;

    if (branches.isEmpty) {
      setState(() => _selectedBranchId = _mainBranchSentinel);
      return;
    }

    final validIds = branches.map((b) => b.id).toSet();
    if (_selectedBranchId != null && validIds.contains(_selectedBranchId)) {
      return;
    }

    final fromRep = _branchIdForRepName(_salesRepController.text, employees);
    if (fromRep != null && validIds.contains(fromRep)) {
      setState(() => _selectedBranchId = fromRep);
      return;
    }
    if (authUser?.branchId != null && validIds.contains(authUser!.branchId)) {
      setState(() => _selectedBranchId = authUser.branchId);
      return;
    }
    if (_activeTemplateLayout.branchId.isNotEmpty && validIds.contains(_activeTemplateLayout.branchId)) {
      setState(() => _selectedBranchId = _activeTemplateLayout.branchId);
      return;
    }
    setState(() => _selectedBranchId = _defaultMainOrFirstBranchId(branches));
  }

  void _resetToStandardTemplate() {
    setState(() {
      _selectedTemplateId = null;
      _selectedTemplateSnapshot = {};
      _showQty = true;
      _showPrice = true;
      _showTax = true;
      _hideCostInPdf = true;
      _customColumns.clear();
      _bankDetailsController.clear();
      _syncTemplateControllers();
    });
  }

  static const Set<String> _builtInTableColKeys = {
    'sl. no', 'sl no', 'sr no', 's.no', '#',
    'qty', 'quantity',
    'item name', 'description',
    'item code', 'code',
    'unit price', 'rate',
    'ex. tax', 'subtotal',
    'vat%', 'tax%',
    'vat', 'tax',
    'total', 'amount',
    'cst', 'cost', 'cost price', 'margin',
  };

  List<String> _extractCustomColumnsFromLayout(TemplateLayoutConfig layout) {
    final result = <String>[];
    final seen = <String>{};
    void addIfCustom(String col) {
      final trimmed = col.trim();
      final lower = trimmed.toLowerCase();
      if (trimmed.isEmpty || _builtInTableColKeys.contains(lower)) return;
      if (seen.add(lower)) {
        result.add(trimmed);
      }
    }

    for (final c in layout.customColumns) {
      addIfCustom(c);
    }
    final tableEl = layout.canvasElements.where((e) => e.type == 'table').firstOrNull;
    if (tableEl != null) {
      for (final c in tableEl.tableColumns) {
        addIfCustom(c);
      }
    }
    return result;
  }

  void _applyTemplate(DocumentTemplateModel tpl) {
    setState(() {
      _selectedTemplateId = tpl.id;
      _selectedTemplateSnapshot = tpl.layout.toJson();
      _showQty = tpl.layout.showQty;
      _showPrice = tpl.layout.showPrice;
      _showTax = tpl.layout.showTax;
      _hideCostInPdf = tpl.layout.hideCostInPdf;
      final mergedCols = _extractCustomColumnsFromLayout(tpl.layout);
      _customColumns
        ..clear()
        ..addAll(mergedCols);
      for (final item in _items) {
        for (final col in _customColumns) {
          item.getCustomController(col, () => setState(() {}));
        }
      }
      if (tpl.layout.incoterms.isNotEmpty) {
        _incotermsController.text = tpl.layout.incoterms;
      }
      if (tpl.layout.termsAndConditions.isNotEmpty) {
        _termsController.text = tpl.layout.termsAndConditions;
      } else {
        _termsController.text = _createAsInvoice
            ? '1. Payment due within 15 days of invoice date.\n2. Applicable GST and duties included.'
            : '1. Quotation is valid for 15 days from issue date.\n2. Payment terms as agreed.\n3. All prices include applicable taxes.';
      }
      _syncTemplateControllers();
    });
  }

  void _syncTemplateControllers() {
    final layout = _activeTemplateLayout;
    final layoutCustomCols = _extractCustomColumnsFromLayout(layout);
    for (final col in layoutCustomCols) {
      if (!_customColumns.any((c) => c.toLowerCase().trim() == col.toLowerCase().trim())) {
        _customColumns.add(col);
      }
    }
    for (final item in _items) {
      for (final col in _customColumns) {
        item.getCustomController(col, () => setState(() {}));
      }
    }
    final activeSet = layout.customHeaderFields.toSet();
    final staleKeys = _customFieldControllers.keys.where((k) => !activeSet.contains(k)).toList();
    for (final k in staleKeys) {
      _customFieldControllers[k]?.dispose();
      _customFieldControllers.remove(k);
    }
    for (final field in layout.customHeaderFields) {
      if (!_customFieldControllers.containsKey(field)) {
        _customFieldControllers[field] = TextEditingController(
          text: layout.filledFields[field] ?? '',
        );
      }
    }
    _bankDetailsController.text = layout.bankDetailsText;
  }

  Map<String, dynamic> _buildFinalTemplateSnapshot() {
    if (_selectedTemplateSnapshot.isEmpty && _customFieldControllers.isEmpty && _bankDetailsController.text.trim().isEmpty) {
      return {};
    }
    final snap = Map<String, dynamic>.from(_selectedTemplateSnapshot);
    final filled = <String, String>{};
    for (final entry in _customFieldControllers.entries) {
      if (entry.value.text.trim().isNotEmpty) {
        filled[entry.key] = entry.value.text.trim();
      }
    }
    if (filled.isNotEmpty) {
      snap['filled_fields'] = filled;
    }
    if (_bankDetailsController.text.trim().isNotEmpty) {
      final defs = Map<String, dynamic>.from((snap['defaults'] as Map?) ?? {});
      defs['bank_details_text'] = _bankDetailsController.text.trim();
      snap['defaults'] = defs;
    }
    return snap;
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

  _LineItemEntry _addItemRow({String? name, String? itemCode, double? price, double? cst, double? tax}) {
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
    return item;
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
                              Text('Total (${PlanModel.getSymbolForCurrency(_currency)})', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700)),
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
      if (_selectedTemplateId != null) 'template': _selectedTemplateId,
      if (_selectedBranchId != null && _selectedBranchId!.isNotEmpty && _selectedBranchId != _mainBranchSentinel)
        'branch': _selectedBranchId
      else if (context.read<LeadProvider>().branches.isNotEmpty)
        'branch': _defaultMainOrFirstBranchId(context.read<LeadProvider>().branches)
      else if (_activeTemplateLayout.branchId.isNotEmpty)
        'branch': _activeTemplateLayout.branchId,
      if (_buildFinalTemplateSnapshot().isNotEmpty) 'template_snapshot': _buildFinalTemplateSnapshot(),
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
      if (_selectedTemplateId != null) 'template': _selectedTemplateId,
      if (_selectedBranchId != null && _selectedBranchId!.isNotEmpty && _selectedBranchId != _mainBranchSentinel)
        'branch': _selectedBranchId
      else if (context.read<LeadProvider>().branches.isNotEmpty)
        'branch': _defaultMainOrFirstBranchId(context.read<LeadProvider>().branches)
      else if (_activeTemplateLayout.branchId.isNotEmpty)
        'branch': _activeTemplateLayout.branchId,
      if (_buildFinalTemplateSnapshot().isNotEmpty) 'template_snapshot': _buildFinalTemplateSnapshot(),
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
    final employees = context.watch<EmployeeProvider>().employees;
    final isMobile = ResponsiveLayout.isMobile(context);

    final contentBody = Form(
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
                    if (widget.asPage) ...[
                      const AppBackButton(),
                      const SizedBox(width: 10),
                    ],
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
                    if (MediaQuery.of(context).size.width < 1020)
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: () => setState(() => _showMobilePreview = false),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: !_showMobilePreview ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text('Form', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: !_showMobilePreview ? const Color(0xFF0F172A) : const Color(0xFF64748B))),
                              ),
                            ),
                            InkWell(
                              onTap: () => setState(() => _showMobilePreview = true),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _showMobilePreview ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text('Preview', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: _showMobilePreview ? const Color(0xFF059669) : const Color(0xFF64748B))),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (!widget.asPage)
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                  ],
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

                // Main Form Body + Live Preview (Split-Screen on Desktop, Toggle on Mobile)
                Expanded(
                  child: LayoutBuilder(
                    builder: (ctx, bodyConstraints) {
                      final isSplit = bodyConstraints.maxWidth >= 960;
                      final formScroll = SingleChildScrollView(
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
                        // Visual Document Template Selector Cards (from Company Settings)
                        Builder(
                          builder: (ctx) {
                            final docType = _createAsInvoice ? 'INVOICE' : 'QUOTATION';
                            final bp = ctx.watch<BillingProvider>();
                            final templates = bp.templatesForType(docType);
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.design_services_rounded, size: 15, color: Color(0xFF6D28D9)),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Select Template (${templates.length} custom)',
                                      style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFF5B21B6)),
                                    ),
                                    const Spacer(),
                                    InkWell(
                                      onTap: () => bp.fetchTemplates(docType: docType),
                                      borderRadius: BorderRadius.circular(6),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.refresh_rounded, size: 13, color: Color(0xFF6D28D9)),
                                            const SizedBox(width: 3),
                                            Text('Refresh', style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: const Color(0xFF6D28D9))),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                SizedBox(
                                  height: 54,
                                  child: ListView(
                                    scrollDirection: Axis.horizontal,
                                    children: [
                                      _buildTemplateChipCard(
                                        title: 'Standard Layout',
                                        subtitle: 'System Default',
                                        accentColor: const Color(0xFF475569),
                                        isSelected: _selectedTemplateId == null,
                                        onTap: _resetToStandardTemplate,
                                      ),
                                      ...templates.map((t) {
                                        final color = _parseHexColor(t.layout.primaryColorHex, fallback: const Color(0xFF059669));
                                        return _buildTemplateChipCard(
                                          title: t.name,
                                          subtitle: t.isDefault ? 'Default Template' : 'Custom Template',
                                          accentColor: color,
                                          isSelected: _selectedTemplateId == t.id,
                                          onTap: () => _applyTemplate(t),
                                        );
                                      }),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                            );
                          },
                        ),
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
                              flex: 2,
                              child: _buildInput(
                                label: 'Phone Number *',
                                controller: _phoneController,
                                icon: Icons.phone_outlined,
                                keyboardType: TextInputType.phone,
                                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
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
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Row 2: Contact Person, Location, Email
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
                                label: 'Email',
                                controller: _emailController,
                                icon: Icons.email_outlined,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Row 3: Sales Rep (Editable + Staff Picker), Billing Address, Valid Until
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Sales Representative', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF475569))),
                                  const SizedBox(height: 5),
                                  TextFormField(
                                    controller: _salesRepController,
                                    style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w500, color: const Color(0xFF0F172A)),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      filled: true,
                                      fillColor: Colors.white,
                                      prefixIcon: const Icon(Icons.support_agent_outlined, size: 16, color: Color(0xFF64748B)),
                                      suffixIcon: employees.isEmpty
                                          ? null
                                          : PopupMenuButton<String>(
                                              tooltip: 'Select from staff',
                                              icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF64748B)),
                                              onSelected: (name) {
                                                setState(() {
                                                  _salesRepController.text = name;
                                                  final branches = context.read<LeadProvider>().branches;
                                                  final validIds = branches.map((b) => b.id).toSet();
                                                  final repBranch = _branchIdForRepName(name, employees);
                                                  if (repBranch != null && validIds.contains(repBranch)) {
                                                    _selectedBranchId = repBranch;
                                                  } else if (branches.isEmpty) {
                                                    _selectedBranchId = _mainBranchSentinel;
                                                  }
                                                });
                                              },
                                              itemBuilder: (_) => employees
                                                  .where((e) => e['is_active'] != false)
                                                  .map((e) {
                                                    final full = '${e['first_name'] ?? ''} ${e['last_name'] ?? ''}'.trim();
                                                    final disp = full.isNotEmpty ? full : (e['email']?.toString() ?? 'Staff');
                                                    return PopupMenuItem<String>(value: disp, child: Text(disp, style: GoogleFonts.inter(fontSize: 12.5)));
                                                  })
                                                  .toList(),
                                            ),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: Builder(
                                builder: (ctx) {
                                  final branches = ctx.watch<LeadProvider>().branches;
                                  final validIds = branches.map((b) => b.id).toSet();
                                  final effectiveBranchVal = branches.isEmpty
                                      ? _mainBranchSentinel
                                      : (validIds.contains(_selectedBranchId)
                                          ? _selectedBranchId
                                          : _defaultMainOrFirstBranchId(branches));
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Branch *', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF475569))),
                                      const SizedBox(height: 5),
                                      DropdownButtonFormField<String>(
                                        initialValue: effectiveBranchVal,
                                        isExpanded: true,
                                        style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                                        decoration: InputDecoration(
                                          isDense: true,
                                          filled: true,
                                          fillColor: Colors.white,
                                          prefixIcon: const Icon(Icons.store_mall_directory_outlined, size: 16, color: Color(0xFF64748B)),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        ),
                                        items: branches.isEmpty
                                            ? [
                                                DropdownMenuItem<String>(
                                                  value: _mainBranchSentinel,
                                                  child: Text('Main Branch', style: GoogleFonts.inter(fontSize: 12.5)),
                                                ),
                                              ]
                                            : branches
                                                .map((b) => DropdownMenuItem<String>(
                                                      value: b.id,
                                                      child: Text(b.name, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 12.5)),
                                                    ))
                                                .toList(),
                                        onChanged: branches.isEmpty
                                            ? null
                                            : (val) => setState(() => _selectedBranchId = val),
                                        validator: (val) => (val == null || val.isEmpty) ? 'Required' : null,
                                      ),
                                    ],
                                  );
                                },
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
                        const SizedBox(height: 16),

                        // Dynamic Template Custom Fields & Bank Details
                        if (_activeTemplateLayout.customHeaderFields.isNotEmpty ||
                            _activeTemplateLayout.isBlockVisible('bank_details')) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Template Fields & Payment Details',
                                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF475569)),
                                ),
                                if (_activeTemplateLayout.customHeaderFields.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: _activeTemplateLayout.customHeaderFields.map((fieldName) {
                                      final ctrl = _customFieldControllers.putIfAbsent(
                                        fieldName,
                                        () => TextEditingController(text: _activeTemplateLayout.filledFields[fieldName] ?? ''),
                                      );
                                      return SizedBox(
                                        width: 220,
                                        child: _buildInput(
                                          label: fieldName,
                                          controller: ctrl,
                                          icon: Icons.edit_note_rounded,
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                                if (_activeTemplateLayout.isBlockVisible('bank_details')) ...[
                                  const SizedBox(height: 10),
                                  _buildInput(
                                    label: 'Bank Payment Details',
                                    controller: _bankDetailsController,
                                    icon: Icons.account_balance_outlined,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
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
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF047857),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: () => _showCatalogItemPickerDialog(products: products),
                                  icon: const Icon(Icons.inventory_2_outlined, size: 15),
                                  label: Text('Select Item', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700)),
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
                                PopupMenuButton<String>(
                                  tooltip: 'Table & Column Options',
                                  onSelected: (val) {
                                    if (val == 'margin') {
                                      setState(() => _showMarginAnalysis = !_showMarginAnalysis);
                                    } else if (val == 'hide_cost_pdf') {
                                      setState(() => _hideCostInPdf = !_hideCostInPdf);
                                    } else if (val == 'columns') {
                                      _showAddColumnDialog();
                                    } else if (val == 'title_row') {
                                      _addSectionTitleRow();
                                    }
                                  },
                                  itemBuilder: (ctx) {
                                    final u = context.read<AuthProvider>().currentUser;
                                    final canViewCost = (u?.role == 'COMPANY_ADMIN') || (u?.hasPermission('quotations.view_cost_cst') ?? false);
                                    return [
                                    if (canViewCost) ...[
                                      PopupMenuItem(
                                        value: 'margin',
                                        child: Row(
                                          children: [
                                            Icon(
                                              _showMarginAnalysis ? Icons.query_stats_rounded : Icons.visibility_off_outlined,
                                              size: 17,
                                              color: _showMarginAnalysis ? const Color(0xFF15803D) : const Color(0xFF64748B),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              _showMarginAnalysis ? 'Cost & Margin: ON' : 'Cost & Margin: OFF',
                                              style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600),
                                            ),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'hide_cost_pdf',
                                        child: Row(
                                          children: [
                                            Icon(
                                              _hideCostInPdf ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                                              size: 17,
                                              color: _hideCostInPdf ? const Color(0xFFB45309) : const Color(0xFF64748B),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Hide Cost in PDF',
                                              style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    PopupMenuItem(
                                      value: 'columns',
                                      child: Row(
                                        children: [
                                          const Icon(Icons.view_column_rounded, size: 17, color: Color(0xFF4F46E5)),
                                          const SizedBox(width: 8),
                                          Text('Columns / Add Spec', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'title_row',
                                      child: Row(
                                        children: [
                                          const Icon(Icons.title_rounded, size: 17, color: Color(0xFFB45309)),
                                          const SizedBox(width: 8),
                                          Text('+ Add Title Row', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                    ),
                                  ];
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFCBD5E1)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.menu_rounded, size: 15, color: Color(0xFF334155)),
                                        const SizedBox(width: 5),
                                        Text('Menu', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF334155))),
                                        const Icon(Icons.arrow_drop_down_rounded, size: 16, color: Color(0xFF64748B)),
                                      ],
                                    ),
                                  ),
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
                                                        _applyProductToRow(item, selection);
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
                                                          decoration: InputDecoration(
                                                            hintText: 'Enter or pick product...',
                                                            isDense: true,
                                                            border: const OutlineInputBorder(),
                                                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                                            suffixIcon: IconButton(
                                                              icon: const Icon(Icons.search_rounded, size: 16, color: Color(0xFF2563EB)),
                                                              tooltip: 'Browse Catalog Items',
                                                              padding: EdgeInsets.zero,
                                                              constraints: const BoxConstraints(),
                                                              onPressed: () => _showCatalogItemPickerDialog(
                                                                products: products,
                                                                targetItem: item,
                                                              ),
                                                            ),
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
                                  if (_activeTemplateLayout.isBlockVisible('terms')) ...[
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
                  );

                      final previewPanel = ListenableBuilder(
                        listenable: Listenable.merge([
                          _nameController,
                          _phoneController,
                          _clientCodeController,
                          _emailController,
                          _addressController,
                          _locationController,
                          _salesRepController,
                          _incotermsController,
                          _termsController,
                          _bankDetailsController,
                          ..._customFieldControllers.values,
                        ]),
                        builder: (_, __) => _buildLiveDocumentPreview(),
                      );

                      if (isSplit) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(flex: 6, child: formScroll),
                            const SizedBox(width: 16),
                            Expanded(flex: 4, child: previewPanel),
                          ],
                        );
                      }
                      return _showMobilePreview ? previewPanel : formScroll;
                    },
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
                                  final parentCtx = nav.context;
                                  nav.pop(inv);
                                  if (parentCtx.mounted) {
                                    await ActionLoader.run(
                                      parentCtx,
                                      message: 'Opening WhatsApp...',
                                      task: () => PdfInvoiceService.shareInvoiceToWhatsApp(
                                        inv,
                                        companyName: compName,
                                        defaultCountryCode: authUser?.companyCountryCode ?? '+91',
                                      ),
                                    );
                                  }
                                }
                              } else {
                                final quote = await _saveQuotation();
                                if (quote != null) {
                                  final parentCtx = nav.context;
                                  final messenger = ScaffoldMessenger.of(context);
                                  nav.pop(quote);
                                  if (quote.status == 'PENDING_APPROVAL') {
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text('Quotation ${quote.quotationNumber} saved & sent for approval. WhatsApp share is locked until approved.'),
                                        backgroundColor: const Color(0xFFF59E0B),
                                      ),
                                    );
                                  } else if (parentCtx.mounted) {
                                    await ActionLoader.run(
                                      parentCtx,
                                      message: 'Opening WhatsApp...',
                                      task: () => PdfInvoiceService.shareQuotationToWhatsApp(
                                        quote,
                                        companyName: compName,
                                        defaultCountryCode: authUser?.companyCountryCode ?? '+91',
                                      ),
                                    );
                                  }
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
                                  final parentCtx = nav.context;
                                  nav.pop(inv);
                                  if (parentCtx.mounted) {
                                    await ActionLoader.run(
                                      parentCtx,
                                      message: 'Generating Invoice PDF...',
                                      task: () => PdfInvoiceService.printInvoice(
                                        inv,
                                        companyName: compName,
                                        companyPhone: compPhone,
                                        companyEmail: compEmail,
                                        companyAddress: compAddress,
                                        companyGstin: compGstin,
                                        companyWebsite: compWebsite,
                                        companyLogo: compLogo,
                                      ),
                                    );
                                  }
                                }
                              } else {
                                final authU = context.read<AuthProvider>().currentUser;
                                final canExportCost = (authU?.role == 'COMPANY_ADMIN') || (authU?.hasPermission('quotations.view_cost_cst') ?? false);
                                bool includeCst = canExportCost && !_hideCostInPdf;
                                if (canExportCost && _showMarginAnalysis) {
                                  final chosen = await _promptPrintFormat(context);
                                  if (chosen != null) {
                                    includeCst = chosen;
                                  }
                                }
                                final quote = await _saveQuotation();
                                if (quote != null) {
                                  final parentCtx = nav.context;
                                  final messenger = ScaffoldMessenger.of(context);
                                  nav.pop(quote);
                                  if (quote.status == 'PENDING_APPROVAL') {
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text('Quotation ${quote.quotationNumber} saved & sent for approval. PDF export is locked until approved.'),
                                        backgroundColor: const Color(0xFFF59E0B),
                                      ),
                                    );
                                  } else if (parentCtx.mounted) {
                                    await ActionLoader.run(
                                      parentCtx,
                                      message: 'Generating Quotation PDF...',
                                      task: () => PdfInvoiceService.printQuotation(
                                        quote,
                                        companyName: compName,
                                        companyPhone: compPhone,
                                        companyEmail: compEmail,
                                        companyAddress: compAddress,
                                        companyGstin: compGstin,
                                        companyWebsite: compWebsite,
                                        companyLogo: compLogo,
                                        includeCst: includeCst,
                                      ),
                                    );
                                  }
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
                                      content: Text(quote.status == 'PENDING_APPROVAL'
                                          ? 'Sales Quotation ${quote.quotationNumber} saved & sent for approval!'
                                          : 'Sales Quotation ${quote.quotationNumber} created & products saved!'),
                                      backgroundColor: quote.status == 'PENDING_APPROVAL'
                                          ? const Color(0xFFF59E0B)
                                          : const Color(0xFF10B981),
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
    );

    if (widget.asPage) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: AppBackground(
          preset: AppBackgroundPreset.cleanEnterprise,
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.all(isMobile ? 12 : 20),
              child: contentBody,
            ),
          ),
        ),
      );
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 16, vertical: isMobile ? 10 : 20),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 1260, maxHeight: isMobile ? MediaQuery.of(context).size.height * 0.96 : 890),
        child: GlassCard(
          blur: 24,
          opacity: 0.98,
          borderRadius: BorderRadius.circular(20),
          borderColor: const Color(0xFFCBD5E1),
          padding: EdgeInsets.all(isMobile ? 14 : 24),
          child: contentBody,
        ),
      ),
    );
  }

  void _applyProductToRow(_LineItemEntry item, ProductModel p) {
    if (p.itemCode.isNotEmpty) {
      item.itemCodeController.text = p.itemCode;
    } else if (item.itemCodeController.text.trim().isEmpty && p.id.isNotEmpty) {
      final cleanId = p.id.replaceAll('-', '').toUpperCase();
      item.itemCodeController.text = cleanId.length >= 6 ? 'ITM-${cleanId.substring(0, 6)}' : 'ITM-$cleanId';
    }
    item.descriptionController.text = p.name;
    item.rateController.text = p.unitPrice.toStringAsFixed(2);
    item.taxController.text = p.taxPercent.toStringAsFixed(0);
    _onItemValuesChanged(item);
  }

  void _showCatalogItemPickerDialog({
    required List<ProductModel> products,
    _LineItemEntry? targetItem,
  }) {
    String query = '';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dCtx, setDlg) {
          final q = query.trim().toLowerCase();
          final filtered = q.isEmpty
              ? products
              : products.where((p) {
                  return p.name.toLowerCase().contains(q) ||
                      p.itemCode.toLowerCase().contains(q) ||
                      p.description.toLowerCase().contains(q) ||
                      p.unit.toLowerCase().contains(q) ||
                      p.id.toLowerCase().contains(q);
                }).toList();

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620, maxHeight: 580),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.inventory_2_rounded, color: Color(0xFF047857), size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Select Catalog Item',
                                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                              ),
                              Text(
                                'Search and click an item to load code, price, and tax',
                                style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      autofocus: true,
                      onChanged: (v) => setDlg(() => query = v),
                      decoration: InputDecoration(
                        hintText: 'Search by item name, description, or unit...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 18),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                products.isEmpty
                                    ? 'No catalog items saved yet. Type a new item in the row to auto-save it.'
                                    : 'No items match "$query".',
                                style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
                                textAlign: TextAlign.center,
                              ),
                            )
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
                              itemBuilder: (_, i) {
                                final p = filtered[i];
                                final cleanId = p.id.replaceAll('-', '').toUpperCase();
                                final code = p.itemCode.isNotEmpty
                                    ? p.itemCode
                                    : (cleanId.length >= 6 ? 'ITM-${cleanId.substring(0, 6)}' : 'ITM-$cleanId');
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  title: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        margin: const EdgeInsets.only(right: 8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEFF6FF),
                                          borderRadius: BorderRadius.circular(5),
                                        ),
                                        child: Text(code, style: GoogleFonts.robotoMono(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF1D4ED8))),
                                      ),
                                      Expanded(
                                        child: Text(
                                          p.name,
                                          style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                                        ),
                                      ),
                                    ],
                                  ),
                                  subtitle: Text(
                                    '${p.description.isNotEmpty ? "${p.description} · " : ""}Unit: ${p.unit} · Tax: ${p.taxPercent.toStringAsFixed(0)}%',
                                    style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '$_currency ${p.unitPrice.toStringAsFixed(2)}',
                                        style: GoogleFonts.robotoMono(fontSize: 13, fontWeight: FontWeight.w800, color: const Color(0xFF047857)),
                                      ),
                                      Text(
                                        'Tap to select',
                                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF2563EB)),
                                      ),
                                    ],
                                  ),
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    setState(() {
                                      final row = targetItem ?? _addItemRow();
                                      _applyProductToRow(row, p);
                                    });
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
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

  Color _parseHexColor(String hex, {Color fallback = const Color(0xFF059669)}) {
    try {
      final clean = hex.replaceAll('#', '').trim();
      if (clean.length == 6) {
        return Color(int.parse('FF$clean', radix: 16));
      }
      if (clean.length == 8) {
        return Color(int.parse(clean, radix: 16));
      }
    } catch (_) {}
    return fallback;
  }

  Widget _buildTemplateChipCard({
    required String title,
    required String subtitle,
    required Color accentColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 168,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? accentColor.withValues(alpha: 0.1) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? accentColor : const Color(0xFFE2E8F0),
              width: isSelected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 32,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 9.5,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle_rounded, size: 15, color: accentColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCanvasLivePreview({
    required TemplateLayoutConfig layout,
    required String effectiveLogo,
    required Map<String, String> tags,
  }) {
    String resolveTags(String raw) {
      var out = raw;
      tags.forEach((k, v) {
        out = out.replaceAll('{{$k}}', v);
      });
      return out;
    }

    Color hex(String h, {Color fallback = Colors.transparent}) {
      if (h.isEmpty) return fallback;
      try {
        final clean = h.replaceAll('#', '');
        if (clean.length == 6) return Color(int.parse('FF$clean', radix: 16));
      } catch (_) {}
      return fallback;
    }

    String cellFor(_LineItemEntry item, String col, int rowIdx) {
      final c = col.toLowerCase().trim();
      if (c == 'sl. no' || c == 'sl no' || c == 'sr no' || c == 's.no' || c == '#') {
        return '${rowIdx + 1}';
      }
      if (c.contains('qty')) return item.qtyController.text;
      if (c.contains('item name') || c.contains('description')) {
        return item.descriptionController.text;
      }
      if (c.contains('code')) return item.itemCodeController.text;
      if (c.contains('unit price') || c.contains('rate')) {
        return item.rate.toStringAsFixed(2);
      }
      if (c.contains('ex. tax') || c.contains('subtotal')) {
        return (item.quantity * item.rate).toStringAsFixed(2);
      }
      if (c.contains('vat%') || c.contains('tax%')) {
        return item.taxPercent.toStringAsFixed(0);
      }
      if (c == 'vat' || c == 'tax') {
        return ((item.quantity * item.rate) * (item.taxPercent / 100)).toStringAsFixed(2);
      }
      if (c.contains('total') || c.contains('amount')) {
        return item.totalController.text;
      }
      return item.customControllers[col]?.text ?? '';
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const double a4W = 595.0;
        const double a4H = 842.0;
        final scale = ((constraints.maxWidth - 20) / a4W).clamp(0.35, 1.0);

        // Wrap-content table height & dynamic shift for elements below the table
        final tableEl = layout.canvasElements.where((e) => e.type == 'table').firstOrNull;
        final activeRows = _items.where((it) => !it.isSectionTitle).toList();
        double deltaY = 0.0;
        if (tableEl != null) {
          final double actualTableH = 22.0 + (activeRows.isEmpty ? 1 : activeRows.length) * 20.0 + 20.0;
          deltaY = actualTableH - tableEl.h;
        }

        double maxBottom = a4H;
        for (final el in layout.canvasElements) {
          final isBelowTable = tableEl != null && el.id != tableEl.id && el.y >= (tableEl.y + tableEl.h - 12);
          final effY = isBelowTable ? (el.y + deltaY).clamp(0.0, 4000.0) : el.y;
          final effH = (el.type == 'table' && tableEl != null)
              ? (22.0 + (activeRows.isEmpty ? 1 : activeRows.length) * 20.0 + 20.0)
              : el.h;
          if (effY + effH + 24 > maxBottom) {
            maxBottom = effY + effH + 24;
          }
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(10),
          child: Center(
            child: Container(
              width: a4W * scale,
              height: maxBottom * scale,
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Stack(
                children: layout.canvasElements.map((el) {
                  final isBelowTable = tableEl != null && el.id != tableEl.id && el.y >= (tableEl.y + tableEl.h - 12);
                  final double effY = isBelowTable ? (el.y + deltaY).clamp(0.0, 4000.0) : el.y;
                  Widget child;
                  if (el.type == 'line') {
                    child = Center(
                      child: Container(
                        width: double.infinity,
                        height: (el.borderWidth * scale).clamp(1.0, 2.5),
                        color: hex(el.colorHex, fallback: const Color(0xFF0F172A)),
                      ),
                    );
                  } else if (el.type == 'box') {
                    child = Container(
                      decoration: BoxDecoration(
                        color: hex(el.bgColorHex),
                        border: el.borderWidth > 0
                            ? Border.all(
                                color: hex(el.borderColorHex, fallback: const Color(0xFF334155)),
                                width: el.borderWidth,
                              )
                            : null,
                      ),
                    );
                  } else if (el.type == 'image') {
                    final src = el.imageSource == '{{branch_logo}}'
                        ? effectiveLogo
                        : (el.imageSource.isNotEmpty ? el.imageSource : effectiveLogo);
                    child = src.isNotEmpty ? _buildPreviewLogo(src) : const SizedBox.shrink();
                  } else if (el.type == 'table') {
                    final cols = el.tableColumns.isEmpty ? ['Qty', 'Item Name', 'Total'] : el.tableColumns;
                    final headerBg = hex(el.bgColorHex, fallback: const Color(0xFFCBD5E1));
                    final textCol = hex(el.colorHex, fallback: const Color(0xFF0F172A));
                    child = Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFF475569), width: 0.6),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            color: headerBg,
                            child: Row(
                              children: cols
                                  .map((c) => Expanded(
                                        child: Padding(
                                          padding: EdgeInsets.all(2.5 * scale),
                                          child: Text(
                                            c,
                                            textAlign: TextAlign.center,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.inter(
                                              fontSize: (7.5 * scale).clamp(5.0, 10.0),
                                              fontWeight: FontWeight.w700,
                                              color: textCol,
                                            ),
                                          ),
                                        ),
                                      ))
                                  .toList(),
                            ),
                          ),
                          ...activeRows.asMap().entries.map((entry) => Container(
                                decoration: const BoxDecoration(
                                  border: Border(top: BorderSide(color: Color(0xFFCBD5E1), width: 0.5)),
                                ),
                                child: Row(
                                  children: cols
                                      .map((c) => Expanded(
                                            child: Padding(
                                              padding: EdgeInsets.all(2.5 * scale),
                                              child: Text(
                                                cellFor(entry.value, c, entry.key),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.inter(
                                                  fontSize: (7.0 * scale).clamp(5.0, 10.0),
                                                ),
                                              ),
                                            ),
                                          ))
                                      .toList(),
                                ),
                              )),
                          Container(
                            decoration: BoxDecoration(
                              color: headerBg,
                              border: const Border(top: BorderSide(color: Color(0xFF475569), width: 0.6)),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 2.5 * scale, horizontal: 4 * scale),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('TOTAL', style: GoogleFonts.inter(fontSize: (7.5 * scale).clamp(5.0, 10.0), fontWeight: FontWeight.w700, color: textCol)),
                                Text('${tags['currency'] ?? ''} ${tags['grand_total'] ?? '0.00'}',
                                    style: GoogleFonts.inter(fontSize: (7.5 * scale).clamp(5.0, 10.0), fontWeight: FontWeight.w700, color: textCol)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  } else {
                    final align = el.align == 'center'
                        ? TextAlign.center
                        : (el.align == 'right' ? TextAlign.right : TextAlign.left);
                    child = Text(
                      resolveTags(el.text),
                      textAlign: align,
                      style: GoogleFonts.inter(
                        fontSize: (el.fontSize * scale).clamp(5.0, 24.0),
                        fontWeight: el.bold ? FontWeight.w700 : FontWeight.w400,
                        fontStyle: el.italic ? FontStyle.italic : FontStyle.normal,
                        color: hex(el.colorHex, fallback: const Color(0xFF0F172A)),
                      ),
                    );
                  }
                  return Positioned(
                    left: el.x * scale,
                    top: effY * scale,
                    width: el.w * scale,
                    height: el.type == 'table'
                        ? null
                        : (el.h * scale).clamp(el.type == 'line' ? 8.0 : 12.0, maxBottom * scale),
                    child: child,
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPreviewLogo(String rawLogo) {
    final trimmed = rawLogo.trim();
    if (trimmed.isEmpty) return const SizedBox.shrink();
    if (trimmed.startsWith('data:image')) {
      try {
        final base64Str = trimmed.split(',').last;
        final bytes = base64Decode(base64Str);
        return ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.memory(bytes, height: 38, width: 54, fit: BoxFit.contain),
        );
      } catch (_) {}
    }
    if (trimmed.startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.network(trimmed, height: 38, width: 54, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildLiveDocumentPreview() {
    final layout = _activeTemplateLayout;
    final primary = _parseHexColor(
      layout.primaryColorHex,
      fallback: _createAsInvoice ? const Color(0xFF2563EB) : const Color(0xFF059669),
    );
    final accent = _parseHexColor(layout.accentColorHex, fallback: primary);
    final authUser = context.read<AuthProvider>().currentUser;
    final comp = context.read<CompanyProvider>().activeCompanyDetail;
    final bp = context.read<BillingProvider>();
    final docType = _createAsInvoice ? 'INVOICE' : 'QUOTATION';
    final selectedTpl = _selectedTemplateId != null
        ? bp.templatesForType(docType).where((t) => t.id == _selectedTemplateId).firstOrNull
        : null;
    final compName = comp?.name.isNotEmpty == true
        ? comp!.name
        : ((authUser?.companyName?.isNotEmpty == true) ? authUser!.companyName! : 'Your Company');
    final compAddress = comp?.address.isNotEmpty == true ? comp!.address : (authUser?.companyAddress ?? '');
    final compPhone = comp?.contactPhone.isNotEmpty == true ? comp!.contactPhone : (authUser?.companyPhone ?? '');
    final compEmail = comp?.contactEmail.isNotEmpty == true ? comp!.contactEmail : (authUser?.companyEmail ?? '');
    final compGstin = comp?.gstin.isNotEmpty == true ? comp!.gstin : (authUser?.companyGstin ?? '');

    final docTitle = layout.titleOverride.isNotEmpty
        ? layout.titleOverride.toUpperCase()
        : (_createAsInvoice ? 'TAX INVOICE' : 'QUOTATION');
    final customerName = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : 'Customer / Company Name';
    final phone = _phoneController.text.trim();
    final city = _locationController.text.trim();
    final salesRep = _salesRepController.text.trim();
    final employees = context.read<EmployeeProvider>().employees;
    final resolvedRepName = salesRep.isNotEmpty ? salesRep : (authUser?.fullName ?? '');
    String resolvedRepPhone = '';
    for (final emp in employees) {
      final full = '${emp['first_name'] ?? ''} ${emp['last_name'] ?? ''}'.trim();
      final email = emp['email']?.toString() ?? '';
      if (resolvedRepName.isNotEmpty &&
          (full.toLowerCase() == resolvedRepName.toLowerCase() ||
              email.toLowerCase() == resolvedRepName.toLowerCase())) {
        resolvedRepPhone = emp['phone']?.toString() ?? '';
        break;
      }
    }
    if (resolvedRepPhone.isEmpty) {
      resolvedRepPhone = (authUser?.phone?.isNotEmpty == true)
          ? authUser!.phone!
          : compPhone;
    }
    final effectiveBranchId = (_selectedBranchId != null && _selectedBranchId != _mainBranchSentinel)
        ? _selectedBranchId!
        : layout.branchId;
    final branchObj = effectiveBranchId.isNotEmpty
        ? context.read<LeadProvider>().branches.where((b) => b.id == effectiveBranchId).firstOrNull
        : null;
    final branchName = branchObj?.name ?? '';
    final effectiveLogo = layout.logoOverride.isNotEmpty
        ? layout.logoOverride
        : (branchObj?.effectiveLogo.isNotEmpty == true
            ? branchObj!.effectiveLogo
            : (comp?.logo.isNotEmpty == true ? comp!.logo : (authUser?.companyLogo ?? '')));

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Icon(Icons.visibility_rounded, size: 15, color: primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    selectedTpl != null
                        ? 'Preview · ${selectedTpl.name}'
                        : 'Preview · Standard Layout',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    docTitle,
                    style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w800, color: primary),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: (layout.useCanvasMode && layout.canvasElements.isNotEmpty)
                ? _buildCanvasLivePreview(
                    layout: layout,
                    effectiveLogo: effectiveLogo,
                    tags: {
                      'doc_number': _createAsInvoice ? 'INV-DRAFT' : 'QTN-DRAFT',
                      'date': DateTime.now().toIso8601String().split('T').first,
                      'client_po': _clientCodeController.text.trim(),
                      'incoterms': _incotermsController.text.trim(),
                      'currency': _currency,
                      'delivery_address': city,
                      'company_trn': compGstin,
                      'customer_name': customerName,
                      'customer_address': _addressController.text.trim(),
                      'contact_person': _contactPersonController.text.trim(),
                      'customer_phone': phone,
                      'customer_trn': _crNumberController.text.trim(),
                      'subtotal': _calculatedSubtotal.toStringAsFixed(2),
                      'tax_amount': _calculatedTax.toStringAsFixed(2),
                      'extra_charge': '0.00',
                      'grand_total': _calculatedGrandTotal.toStringAsFixed(2),
                      'amount_in_words': '',
                      'vat_in_words': '',
                      'bank_details': _bankDetailsController.text.trim().isNotEmpty
                          ? _bankDetailsController.text.trim()
                          : layout.bankDetailsText,
                      'terms': _termsController.text.trim(),
                      'branch_name': branchName.isNotEmpty ? branchName : compName,
                      'branch_address': branchObj?.address.isNotEmpty == true ? branchObj!.address : compAddress,
                      'branch_email': compEmail,
                      'branch_phone': compPhone,
                      'sales_rep_name': resolvedRepName,
                      'sales_rep_phone': resolvedRepPhone,
                    },
                  )
                : SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(layout.borderStyle == 'rounded' ? 12 : 4),
                      border: layout.borderStyle == 'none'
                          ? null
                          : Border.all(
                              color: layout.borderStyle == 'double' ? primary : const Color(0xFFCBD5E1),
                              width: layout.borderStyle == 'double' ? 2 : 1,
                            ),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header Block
                        if (layout.isBlockVisible('header'))
                          Container(
                            padding: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              border: Border(bottom: BorderSide(color: primary, width: 2)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                if (effectiveLogo.isNotEmpty && layout.logoPosition != 'right') ...[
                                  _buildPreviewLogo(effectiveLogo),
                                  const SizedBox(width: 10),
                                ],
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: layout.logoPosition == 'center'
                                        ? CrossAxisAlignment.center
                                        : CrossAxisAlignment.start,
                                    children: [
                                      Text(compName, style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
                                      if (branchName.isNotEmpty)
                                        Text('Branch: $branchName', style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w600, color: primary)),
                                      if (compAddress.isNotEmpty)
                                        Text(compAddress, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 9, color: const Color(0xFF64748B))),
                                      if (compPhone.isNotEmpty || compEmail.isNotEmpty)
                                        Text([if (compPhone.isNotEmpty) compPhone, if (compEmail.isNotEmpty) compEmail].join(' · '), style: GoogleFonts.inter(fontSize: 9, color: const Color(0xFF64748B))),
                                      if (compGstin.isNotEmpty)
                                        Text('${RegionDetector.taxIdLabel(authUser?.companyCountryIso)}: $compGstin', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600, color: const Color(0xFF475569))),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    if (effectiveLogo.isNotEmpty && layout.logoPosition == 'right') ...[
                                      _buildPreviewLogo(effectiveLogo),
                                      const SizedBox(height: 4),
                                    ],
                                    Text(docTitle, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w900, color: primary)),
                                    Text('${layout.numberPrefix.isNotEmpty ? layout.numberPrefix : (_createAsInvoice ? "INV-" : "QTN-")}DRAFT', style: GoogleFonts.robotoMono(fontSize: 9.5, fontWeight: FontWeight.w700, color: const Color(0xFF475569))),
                                    if (_validUntil != null)
                                      Text('Valid: ${_validUntil!.toIso8601String().split("T").first}', style: GoogleFonts.inter(fontSize: 9, color: const Color(0xFF64748B))),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 10),

                        // Client & Commercial Meta Block
                        if (layout.isBlockVisible('client_meta')) ...[
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('BILL / QUOTE TO', style: GoogleFonts.inter(fontSize: 8.5, fontWeight: FontWeight.w800, color: primary)),
                                          const SizedBox(height: 2),
                                          Text(customerName, style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                                          if (_contactPersonController.text.trim().isNotEmpty)
                                            Text('Attn: ${_contactPersonController.text.trim()}', style: GoogleFonts.inter(fontSize: 9.5, color: const Color(0xFF475569))),
                                          if (phone.isNotEmpty || city.isNotEmpty)
                                            Text([if (phone.isNotEmpty) phone, if (city.isNotEmpty) city].join(' · '), style: GoogleFonts.inter(fontSize: 9.5, color: const Color(0xFF475569))),
                                          if (_addressController.text.trim().isNotEmpty)
                                            Text(_addressController.text.trim(), style: GoogleFonts.inter(fontSize: 9, color: const Color(0xFF64748B))),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        if (_clientCodeController.text.trim().isNotEmpty)
                                          Text('Code: ${_clientCodeController.text.trim()}', style: GoogleFonts.robotoMono(fontSize: 9, color: const Color(0xFF475569))),
                                        if (salesRep.isNotEmpty)
                                          Text('Rep: $salesRep', style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
                                        if (_incotermsController.text.trim().isNotEmpty)
                                          Text(_incotermsController.text.trim(), style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600, color: accent)),
                                      ],
                                    ),
                                  ],
                                ),
                                if (layout.customHeaderFields.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 4,
                                    children: layout.customHeaderFields.map((field) {
                                      final val = _customFieldControllers[field]?.text.trim() ?? '';
                                      return Text(
                                        '$field: ${val.isNotEmpty ? val : "—"}',
                                        style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],

                        // Line Items Table
                        if (layout.isBlockVisible('items_table')) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              color: primary,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                            ),
                            child: Row(
                              children: [
                                Expanded(flex: 4, child: Text('Description', style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w700, color: Colors.white))),
                                if (_showQty)
                                  Expanded(flex: 1, child: Text('Qty', textAlign: TextAlign.right, style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w700, color: Colors.white))),
                                if (_showPrice)
                                  Expanded(flex: 2, child: Text('Rate', textAlign: TextAlign.right, style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w700, color: Colors.white))),
                                Expanded(flex: 2, child: Text('Total', textAlign: TextAlign.right, style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w700, color: Colors.white))),
                              ],
                            ),
                          ),
                          ..._items.map((item) {
                            if (item.isSectionTitle) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                color: const Color(0xFFF1F5F9),
                                child: Text(
                                  item.titleController.text.trim().isEmpty ? 'Section' : item.titleController.text.trim(),
                                  style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w700, color: const Color(0xFF334155)),
                                ),
                              );
                            }
                            final name = item.descriptionController.text.trim().isEmpty ? 'Line Item' : item.descriptionController.text.trim();
                            final qty = double.tryParse(item.qtyController.text) ?? 1;
                            final price = double.tryParse(item.rateController.text) ?? 0;
                            final tax = double.tryParse(item.taxController.text) ?? 0;
                            final lineTotal = (qty * price) * (1 + tax / 100);
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0)))),
                              child: Row(
                                children: [
                                  Expanded(flex: 4, child: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 9.5, color: const Color(0xFF0F172A)))),
                                  if (_showQty)
                                    Expanded(flex: 1, child: Text(qty.toStringAsFixed(0), textAlign: TextAlign.right, style: GoogleFonts.robotoMono(fontSize: 9.5, color: const Color(0xFF475569)))),
                                  if (_showPrice)
                                    Expanded(flex: 2, child: Text(price.toStringAsFixed(2), textAlign: TextAlign.right, style: GoogleFonts.robotoMono(fontSize: 9.5, color: const Color(0xFF475569)))),
                                  Expanded(flex: 2, child: Text('$_currency ${lineTotal.toStringAsFixed(2)}', textAlign: TextAlign.right, style: GoogleFonts.robotoMono(fontSize: 9.5, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)))),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: 10),
                        ],

                        // Totals Breakdown
                        if (layout.isBlockVisible('totals_words'))
                          Align(
                            alignment: Alignment.centerRight,
                            child: Container(
                              width: 210,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                children: [
                                  _buildSummaryRow('Subtotal', '$_currency ${_calculatedSubtotal.toStringAsFixed(2)}', fontSize: 9.5),
                                  if (_calculatedDiscount > 0)
                                    _buildSummaryRow('Discount', '-$_currency ${_calculatedDiscount.toStringAsFixed(2)}', fontSize: 9.5, textColor: const Color(0xFFDC2626)),
                                  if (_calculatedTax > 0)
                                    _buildSummaryRow('Tax / GST', '$_currency ${_calculatedTax.toStringAsFixed(2)}', fontSize: 9.5),
                                  const Divider(height: 10),
                                  _buildSummaryRow('Grand Total', '$_currency ${_calculatedGrandTotal.toStringAsFixed(2)}', isBold: true, fontSize: 10.5, textColor: primary),
                                ],
                              ),
                            ),
                          ),

                        if (layout.isBlockVisible('bank_details') && _bankDetailsController.text.trim().isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('BANK & PAYMENT DETAILS', style: GoogleFonts.inter(fontSize: 8.5, fontWeight: FontWeight.w800, color: primary)),
                                const SizedBox(height: 2),
                                Text(_bankDetailsController.text.trim(), style: GoogleFonts.inter(fontSize: 9.5, color: const Color(0xFF334155))),
                              ],
                            ),
                          ),
                        ],

                        if (layout.isBlockVisible('terms') && _termsController.text.trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text('TERMS & CONDITIONS', style: GoogleFonts.inter(fontSize: 8.5, fontWeight: FontWeight.w800, color: const Color(0xFF64748B))),
                          const SizedBox(height: 2),
                          Text(_termsController.text.trim(), style: GoogleFonts.inter(fontSize: 9, color: const Color(0xFF475569))),
                        ],

                        if (layout.isBlockVisible('signatures')) ...[
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(width: 90, height: 1, color: const Color(0xFFCBD5E1)),
                                  const SizedBox(height: 3),
                                  Text('Customer Signature', style: GoogleFonts.inter(fontSize: 8.5, color: const Color(0xFF64748B))),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(width: 90, height: 1, color: const Color(0xFFCBD5E1)),
                                  const SizedBox(height: 3),
                                  Text('Authorized Signatory', style: GoogleFonts.inter(fontSize: 8.5, color: const Color(0xFF64748B))),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (layout.stamp.enabled)
                    Positioned(
                      right: 18,
                      bottom: 24,
                      child: Transform.rotate(
                        angle: layout.stamp.rotationDeg * 3.14159 / 180,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: _parseHexColor(layout.stamp.colorHex, fallback: primary).withValues(alpha: 0.7),
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            layout.stamp.label.toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                              color: _parseHexColor(layout.stamp.colorHex, fallback: primary).withValues(alpha: 0.8),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
