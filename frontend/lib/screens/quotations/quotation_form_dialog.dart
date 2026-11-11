import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass/glass_card.dart';
import '../../core/widgets/glass/gradient_button.dart';
import '../../core/services/pdf_invoice_service.dart';
import '../../models/lead_model.dart';
import '../../models/quotation_model.dart';
import '../../models/invoice_model.dart';
import '../../models/product_model.dart';
import '../../providers/billing_provider.dart';
import '../../providers/lead_provider.dart';

class QuotationFormDialog extends StatefulWidget {
  final LeadModel? lead;
  final bool isBill;
  final QuotationModel? quotationToEdit;

  const QuotationFormDialog({
    super.key,
    this.lead,
    this.isBill = false,
    this.quotationToEdit,
  });

  @override
  State<QuotationFormDialog> createState() => _QuotationFormDialogState();
}

class _LineItemEntry {
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController qtyController = TextEditingController(text: '1');
  final TextEditingController rateController = TextEditingController(text: '0.00');
  final TextEditingController taxController = TextEditingController(text: '18');
  final TextEditingController discountController = TextEditingController(text: '0');

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
  double get discountAmount => baseAmount * (discountPercent / 100.0);
  double get taxableAmount => baseAmount - discountAmount;
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

  final List<_LineItemEntry> _items = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _createAsInvoice = widget.isBill;
    final editQ = widget.quotationToEdit;
    final lead = widget.lead;
    _selectedLead = lead;
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
          : (_createAsInvoice
              ? '1. Payment due within 15 days of invoice date.\n2. Applicable GST and duties included.\n3. Goods/Services once rendered are governed by standard service agreements.'
              : '1. Quotation is an approximate estimate valid for 15 days.\n2. Final billing price is locked upon Tax Invoice generation.\n3. Applicable GST and duties included.'),
    );
    _validUntil = DateTime.now().add(const Duration(days: 15));

    if (editQ != null && editQ.items.isNotEmpty) {
      for (final it in editQ.items) {
        final row = _LineItemEntry();
        row.descriptionController.text = it.description;
        row.qtyController.text = it.quantity == it.quantity.roundToDouble() ? it.quantity.toInt().toString() : it.quantity.toString();
        row.rateController.text = it.unitPrice.toStringAsFixed(2);
        row.taxController.text = it.taxPercent.toStringAsFixed(0);
        row.discountController.text = it.discountPercent.toStringAsFixed(0);
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

  void _selectLead(LeadModel lead) {
    setState(() {
      _selectedLead = lead;
      _nameController.text = lead.fullName;
      _phoneController.text = lead.phoneNumber;
      if (lead.email.isNotEmpty) _emailController.text = lead.email;
      final addr = [lead.city, lead.state].where((s) => s.isNotEmpty).join(', ');
      if (addr.isNotEmpty) _addressController.text = addr;
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

  void _addItemRow({String? name, double? price, double? tax}) {
    final item = _LineItemEntry();
    if (name != null) item.descriptionController.text = name;
    if (price != null) item.rateController.text = price.toStringAsFixed(2);
    if (tax != null) item.taxController.text = tax.toStringAsFixed(0);

    item.descriptionController.addListener(() => setState(() {}));
    item.qtyController.addListener(() => setState(() {}));
    item.rateController.addListener(() => setState(() {}));
    item.taxController.addListener(() => setState(() {}));
    item.discountController.addListener(() => setState(() {}));
    _items.add(item);
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

  double get _calculatedSubtotal => _items.fold(0.0, (acc, item) => acc + item.baseAmount);
  double get _calculatedDiscount => _items.fold(0.0, (acc, item) => acc + item.discountAmount);
  double get _calculatedTax => _items.fold(0.0, (acc, item) => acc + item.taxAmount);
  double get _calculatedGrandTotal => _items.fold(0.0, (acc, item) => acc + item.lineTotal);

  Future<QuotationModel?> _saveQuotation() async {
    if (!_formKey.currentState!.validate()) return null;

    if (_items.isEmpty || _items.every((i) => i.descriptionController.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one line item with a description.')),
      );
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
      if (_validUntil != null) 'valid_until': _validUntil!.toIso8601String().split('T').first,
      'items': _items
          .where((i) => i.descriptionController.text.trim().isNotEmpty)
          .map((i) => i.toModel().toJson())
          .toList(),
      'subtotal': _calculatedSubtotal,
      'discount_amount': _calculatedDiscount,
      'tax_amount': _calculatedTax,
      'grand_total': _calculatedGrandTotal,
      'notes': _notesController.text.trim(),
      'terms_and_conditions': _termsController.text.trim(),
      'status': 'SENT',
    };

    final result = widget.quotationToEdit != null
        ? await provider.updateQuotation(widget.quotationToEdit!.id, payload)
        : await provider.createQuotation(payload);
    setState(() => _isSaving = false);
    return result;
  }

  Future<InvoiceModel?> _saveInvoice() async {
    if (!_formKey.currentState!.validate()) return null;

    if (_items.isEmpty || _items.every((i) => i.descriptionController.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one line item with a description.')),
      );
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
      if (_validUntil != null) 'due_date': _validUntil!.toIso8601String().split('T').first,
      'items': _items
          .where((i) => i.descriptionController.text.trim().isNotEmpty)
          .map((i) => i.toModel().toJson())
          .toList(),
      'subtotal': _calculatedSubtotal,
      'discount_amount': _calculatedDiscount,
      'tax_amount': _calculatedTax,
      'grand_total': _calculatedGrandTotal,
      'notes': _notesController.text.trim(),
      'terms_and_conditions': _termsController.text.trim(),
      'payment_status': 'PENDING',
    };

    final result = await provider.createInvoice(payload);
    setState(() => _isSaving = false);
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final products = context.watch<BillingProvider>().products;
    final leads = context.watch<LeadProvider>().leads;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 870),
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
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  widget.quotationToEdit != null
                                      ? 'Edit Quotation ${widget.quotationToEdit!.quotationNumber}'
                                      : (_createAsInvoice ? 'New Fixed Price Bill' : 'Generate Quotation'),
                                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (_createAsInvoice ? const Color(0xFF059669) : const Color(0xFFF59E0B)).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: (_createAsInvoice ? const Color(0xFF059669) : const Color(0xFFF59E0B)).withValues(alpha: 0.4)),
                                  ),
                                  child: Text(
                                    _createAsInvoice ? 'FIXED PRICE BILL' : 'APPROXIMATE PRICE',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
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
                                  '1. Quotation is an approximate estimate valid for 15 days.\n2. Final billing price is locked upon Tax Invoice generation.\n3. Applicable GST and duties included.';
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

                // Note banner explaining Approximate vs Fixed Price
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
                              : 'Estimated Quote: Product prices here are approximate. When converted to an Invoice / Bill, prices are locked as Fixed Price.',
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
                            const SizedBox(width: 12),
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
                            const SizedBox(width: 12),
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
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: _buildInput(
                                label: 'Billing Address',
                                controller: _addressController,
                                icon: Icons.location_on_outlined,
                              ),
                            ),
                            const SizedBox(width: 12),
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
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF2563EB)),
                                          const SizedBox(width: 8),
                                          Text(
                                            _validUntil != null ? _validUntil!.toIso8601String().split('T').first : 'Select date',
                                            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF0F172A)),
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

                        // Line Items Table Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Quotation Products & Approximate Pricing',
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
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () => setState(() => _addItemRow()),
                              icon: const Icon(Icons.add_rounded, size: 16),
                              label: Text('Add Next Product (+)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Line Items Container
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
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
                                    Expanded(flex: 5, child: Text('Product / Type to Search', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF475569)))),
                                    const SizedBox(width: 8),
                                    Expanded(flex: 2, child: Text('Qty', textAlign: TextAlign.right, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF475569)))),
                                    const SizedBox(width: 8),
                                    Expanded(flex: 2, child: Text('Approx. Price (₹)', textAlign: TextAlign.right, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF475569)))),
                                    const SizedBox(width: 8),
                                    Expanded(flex: 2, child: Text('Tax %', textAlign: TextAlign.right, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF475569)))),
                                    const SizedBox(width: 8),
                                    Expanded(flex: 2, child: Text('Total (₹)', textAlign: TextAlign.right, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF475569)))),
                                    const SizedBox(width: 32),
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
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    child: Row(
                                      children: [
                                        // Product Search Autocomplete Field
                                        Expanded(
                                          flex: 5,
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
                                              setState(() {});
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
                                                  // Auto-detect if matching exact existing product to auto-fill price
                                                  final match = products.where((p) => p.name.trim().toLowerCase() == val.trim().toLowerCase()).firstOrNull;
                                                  if (match != null) {
                                                    item.rateController.text = match.unitPrice.toStringAsFixed(2);
                                                    item.taxController.text = match.taxPercent.toStringAsFixed(0);
                                                  }
                                                  setState(() {});
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
                                                          subtitle: Text('Price: ₹${opt.unitPrice.toStringAsFixed(2)} · Tax ${opt.taxPercent.toStringAsFixed(0)}%', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B))),
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
                                        const SizedBox(width: 8),
                                        // Quantity
                                        Expanded(
                                          flex: 2,
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
                                        const SizedBox(width: 8),
                                        // Unit Price (Approximate)
                                        Expanded(
                                          flex: 2,
                                          child: TextFormField(
                                            controller: item.rateController,
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
                                        const SizedBox(width: 8),
                                        // Tax %
                                        Expanded(
                                          flex: 2,
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
                                        const SizedBox(width: 8),
                                        // Line Total
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            '₹${item.lineTotal.toStringAsFixed(2)}',
                                            textAlign: TextAlign.right,
                                            style: GoogleFonts.robotoMono(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                                          onPressed: _items.length > 1 ? () => _removeItemRow(idx) : null,
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
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
                                  _buildInput(
                                    label: 'Terms & Conditions',
                                    controller: _termsController,
                                    icon: Icons.gavel_outlined,
                                    maxLines: 2,
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
                                    _buildSummaryRow('Approximate Subtotal', '₹${_calculatedSubtotal.toStringAsFixed(2)}'),
                                    if (_calculatedDiscount > 0)
                                      _buildSummaryRow('Discount', '-₹${_calculatedDiscount.toStringAsFixed(2)}', textColor: const Color(0xFFDC2626)),
                                    if (_calculatedTax > 0)
                                      _buildSummaryRow('Tax / GST', '₹${_calculatedTax.toStringAsFixed(2)}'),
                                    const Divider(color: Color(0xFFCBD5E1), height: 16),
                                    _buildSummaryRow(
                                      'Approximate Total',
                                      '₹${_calculatedGrandTotal.toStringAsFixed(2)}',
                                      isBold: true,
                                      fontSize: 15,
                                      textColor: const Color(0xFF1E3A8A),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '* Estimated quote only. Price will be fixed upon converting to Bill.',
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
                              if (_createAsInvoice) {
                                final inv = await _saveInvoice();
                                if (inv != null) {
                                  nav.pop(inv);
                                  await PdfInvoiceService.shareInvoiceToWhatsApp(inv);
                                }
                              } else {
                                final quote = await _saveQuotation();
                                if (quote != null) {
                                  nav.pop(quote);
                                  await PdfInvoiceService.shareQuotationToWhatsApp(quote);
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
                              if (_createAsInvoice) {
                                final inv = await _saveInvoice();
                                if (inv != null) {
                                  nav.pop(inv);
                                  await PdfInvoiceService.printInvoice(inv);
                                }
                              } else {
                                final quote = await _saveQuotation();
                                if (quote != null) {
                                  nav.pop(quote);
                                  await PdfInvoiceService.printQuotation(quote);
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
                                      content: Text('Approximate Quotation ${quote.quotationNumber} created & products saved!'),
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
