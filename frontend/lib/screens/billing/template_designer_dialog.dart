import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/widgets/company_logo_view.dart';
import '../../models/document_template_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/billing_provider.dart';
import '../../providers/company_provider.dart';
import '../../providers/lead_provider.dart';
import 'canva_template_editor.dart';

class TemplateDesignerDialog extends StatefulWidget {
  final DocumentTemplateModel? templateToEdit;
  final String initialDocType;

  const TemplateDesignerDialog({
    super.key,
    this.templateToEdit,
    this.initialDocType = 'QUOTATION',
  });

  @override
  State<TemplateDesignerDialog> createState() => _TemplateDesignerDialogState();
}

class _TemplateDesignerDialogState extends State<TemplateDesignerDialog> {
  late TextEditingController _nameCtrl;
  late TextEditingController _titleOverrideCtrl;
  late TextEditingController _incotermsCtrl;
  late TextEditingController _termsCtrl;
  late TextEditingController _bankCtrl;
  late TextEditingController _stampLabelCtrl;
  final TextEditingController _newColCtrl = TextEditingController();
  final TextEditingController _newFieldCtrl = TextEditingController();

  late String _docType;
  late bool _isDefault;
  late TemplateLayoutConfig _layout;
  bool _isSaving = false;
  String? _errorText;

  static const List<String> _colorPalette = [
    '#1E3A8A', // Navy
    '#059669', // Emerald
    '#0F172A', // Charcoal
    '#6D28D9', // Royal Purple
    '#881337', // Burgundy
    '#0F766E', // Deep Teal
    '#B45309', // Amber Gold
  ];

  @override
  void initState() {
    super.initState();
    final edit = widget.templateToEdit;
    _docType = edit?.docType ?? widget.initialDocType;
    _isDefault = edit?.isDefault ?? false;
    _layout = edit != null
        ? TemplateLayoutConfig.fromJson(edit.layout.toJson(), docType: _docType)
        : TemplateLayoutConfig.defaultFor(_docType);
    if (edit == null) {
      _layout.useCanvasMode = true;
      _layout.canvasElements = TemplateLayoutConfig.buildStandardParfemperorCanvas(_docType);
    } else if (_layout.useCanvasMode && _layout.canvasElements.isEmpty) {
      _layout.canvasElements = TemplateLayoutConfig.buildStandardParfemperorCanvas(_docType);
    }
    if (edit != null && edit.branchId.isNotEmpty) {
      _layout.branchId = edit.branchId;
    }

    _nameCtrl = TextEditingController(text: edit?.name ?? '');
    _titleOverrideCtrl = TextEditingController(text: _layout.titleOverride);
    _incotermsCtrl = TextEditingController(text: _layout.incoterms);
    _termsCtrl = TextEditingController(text: _layout.termsAndConditions);
    _bankCtrl = TextEditingController(text: _layout.bankDetailsText);
    _stampLabelCtrl = TextEditingController(text: _layout.stamp.label);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final leadProv = context.read<LeadProvider>();
      if (leadProv.branches.isEmpty) {
        leadProv.fetchBranches();
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _titleOverrideCtrl.dispose();
    _incotermsCtrl.dispose();
    _termsCtrl.dispose();
    _bankCtrl.dispose();
    _stampLabelCtrl.dispose();
    _newColCtrl.dispose();
    _newFieldCtrl.dispose();
    super.dispose();
  }

  Color _parseHex(String hex, {Color fallback = const Color(0xFF1E3A8A)}) {
    try {
      final clean = hex.replaceAll('#', '');
      if (clean.length == 6) return Color(int.parse('FF$clean', radix: 16));
      if (clean.length == 8) return Color(int.parse(clean, radix: 16));
    } catch (_) {}
    return fallback;
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _errorText = 'Please enter a template name.');
      return;
    }
    _layout.titleOverride = _titleOverrideCtrl.text.trim();
    _layout.incoterms = _incotermsCtrl.text.trim();
    _layout.termsAndConditions = _termsCtrl.text.trim();
    _layout.bankDetailsText = _bankCtrl.text.trim();
    _layout.stamp.label = _stampLabelCtrl.text.trim().isEmpty ? 'RECEIVED' : _stampLabelCtrl.text.trim();

    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    final bp = context.read<BillingProvider>();
    DocumentTemplateModel? result;
    if (widget.templateToEdit != null) {
      result = await bp.updateTemplate(
        id: widget.templateToEdit!.id,
        name: _nameCtrl.text.trim(),
        layout: _layout,
        branchId: _layout.branchId,
        isDefault: _isDefault,
      );
    } else {
      result = await bp.createTemplate(
        name: _nameCtrl.text.trim(),
        docType: _docType,
        layout: _layout,
        branchId: _layout.branchId,
        isDefault: _isDefault,
      );
    }

    if (!mounted) return;
    setState(() => _isSaving = false);
    if (result != null) {
      Navigator.of(context).pop(result);
    } else {
      setState(() => _errorText = bp.errorMessage ?? 'Failed to save template.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final comp = context.watch<CompanyProvider>().activeCompanyDetail;
    final user = context.watch<AuthProvider>().currentUser;
    final companyName = comp?.name.isNotEmpty == true ? comp!.name : (user?.companyName ?? 'YOUR COMPANY');
    final currency = (user?.companyCurrency.isNotEmpty == true)
        ? user!.companyCurrency
        : (comp?.currency ?? 'INR');
    final primaryColor = _parseHex(_layout.primaryColorHex);
    final accentColor = _parseHex(_layout.accentColorHex, fallback: const Color(0xFF059669));

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Top Studio Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: const Color(0xFF0F172A),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    tooltip: 'Back',
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.design_services_rounded, color: Color(0xFF38BDF8), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.templateToEdit != null ? 'Edit Document Template' : 'Visual Drag & Drop Template Designer',
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          'Drag sections on the A4 canvas to reorder · Drag the stamp freely to position',
                          style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  if (_errorText != null)
                    Container(
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: const Color(0xFF991B1B), borderRadius: BorderRadius.circular(8)),
                      child: Text(_errorText!, style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                    ),
                    onPressed: _isSaving ? null : _save,
                    icon: _isSaving
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save_rounded, size: 17),
                    label: Text(_isSaving ? 'Saving...' : 'Save Template'),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Body: Canva Freeform Canvas OR 3-Panel Classic Studio
            if (_layout.useCanvasMode) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F5F9),
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 230,
                      child: TextField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Template Name *',
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 185,
                      child: DropdownButtonFormField<String>(
                        initialValue: _docType,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Document Type',
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'QUOTATION', child: Text('Quotation', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'INVOICE', child: Text('Invoice / Proforma', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'RECEIPT', child: Text('Receipt Voucher', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'PAYSLIP', child: Text('Salary Payslip', overflow: TextOverflow.ellipsis)),
                        ],
                        onChanged: widget.templateToEdit != null
                            ? null
                            : (v) {
                                if (v != null) setState(() => _docType = v);
                              },
                      ),
                    ),
                    Builder(builder: (ctx) {
                      final branches = ctx.watch<LeadProvider>().branches;
                      return SizedBox(
                        width: 220,
                        child: DropdownButtonFormField<String>(
                          initialValue: branches.any((b) => b.id == _layout.branchId) ? _layout.branchId : '',
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Branch Assignment',
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem(value: '', child: Text('All Branches (Company)', overflow: TextOverflow.ellipsis)),
                            ...branches.map((b) => DropdownMenuItem(
                                  value: b.id,
                                  child: Text(b.name, overflow: TextOverflow.ellipsis),
                                )),
                          ],
                          onChanged: (v) {
                            setState(() {
                              _layout.branchId = v ?? '';
                              final br = branches.where((b) => b.id == _layout.branchId).firstOrNull;
                              _layout.logoOverride = br?.logo ?? '';
                            });
                          },
                        ),
                      );
                    }),
                    FilterChip(
                      label: const Text('Default for Branch/Type'),
                      selected: _isDefault,
                      onSelected: (v) => setState(() => _isDefault = v),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: CanvaTemplateEditor(
                    docType: _docType,
                    elements: _layout.canvasElements,
                    branchLogoUrl: _layout.logoOverride,
                    companyLogoUrl: comp?.logo ?? (user?.companyLogo ?? ''),
                    onChanged: () {},
                  ),
                ),
              ),
            ] else
              Expanded(
                child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // LEFT: Component Toolbox
                  Container(
                    width: 250,
                    padding: const EdgeInsets.all(14),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('DOCUMENT BLOCKS', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF475569), letterSpacing: 0.7)),
                          const SizedBox(height: 8),
                          ..._layout.blocks.map((b) {
                            return CheckboxListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              value: b.visible,
                              activeColor: primaryColor,
                              title: Text(b.label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
                              onChanged: (val) => setState(() => b.visible = val ?? true),
                            );
                          }),
                          const Divider(height: 20),
                          SwitchListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text('Watermark Stamp', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B))),
                            subtitle: Text('Drag stamp on canvas', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B))),
                            value: _layout.stamp.enabled,
                            onChanged: (v) => setState(() => _layout.stamp.enabled = v),
                          ),
                          const Divider(height: 20),
                          Text('CUSTOM TABLE COLUMNS', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF475569), letterSpacing: 0.7)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _newColCtrl,
                                  decoration: InputDecoration(
                                    isDense: true,
                                    hintText: 'e.g. HSN, Weight',
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              IconButton(
                                icon: const Icon(Icons.add_circle, color: Color(0xFF2563EB)),
                                onPressed: () {
                                  final col = _newColCtrl.text.trim();
                                  if (col.isNotEmpty && !_layout.customColumns.contains(col)) {
                                    setState(() {
                                      _layout.customColumns = [..._layout.customColumns, col];
                                      _newColCtrl.clear();
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: _layout.customColumns.map((col) {
                              return Chip(
                                label: Text(col, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
                                deleteIcon: const Icon(Icons.close, size: 14),
                                onDeleted: () => setState(() {
                                  _layout.customColumns = _layout.customColumns.where((c) => c != col).toList();
                                }),
                              );
                            }).toList(),
                          ),
                          const Divider(height: 20),
                          Text('CUSTOM FORM FIELDS', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF475569), letterSpacing: 0.7)),
                          const SizedBox(height: 4),
                          Text('Shown when creating a doc with this template', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B))),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _newFieldCtrl,
                                  decoration: InputDecoration(
                                    isDense: true,
                                    hintText: 'e.g. PO Number, Vehicle',
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              IconButton(
                                icon: const Icon(Icons.add_circle, color: Color(0xFF6D28D9)),
                                onPressed: () {
                                  final fld = _newFieldCtrl.text.trim();
                                  if (fld.isNotEmpty && !_layout.customHeaderFields.contains(fld)) {
                                    setState(() {
                                      _layout.customHeaderFields = [..._layout.customHeaderFields, fld];
                                      _newFieldCtrl.clear();
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: _layout.customHeaderFields.map((fld) {
                              return Chip(
                                label: Text(fld, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF4C1D95))),
                                deleteIcon: const Icon(Icons.close, size: 14),
                                onDeleted: () => setState(() {
                                  _layout.customHeaderFields = _layout.customHeaderFields.where((f) => f != fld).toList();
                                }),
                              );
                            }).toList(),
                          ),
                          if (_docType != 'RECEIPT') ...[
                            const Divider(height: 20),
                            Text('FORM FIELD VISIBILITY', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF475569), letterSpacing: 0.7)),
                            CheckboxListTile(dense: true, contentPadding: EdgeInsets.zero, value: _layout.showClientCode, title: Text('Client Code', style: GoogleFonts.inter(fontSize: 12)), onChanged: (v) => setState(() => _layout.showClientCode = v ?? true)),
                            CheckboxListTile(dense: true, contentPadding: EdgeInsets.zero, value: _layout.showSalesRep, title: Text('Sales Rep', style: GoogleFonts.inter(fontSize: 12)), onChanged: (v) => setState(() => _layout.showSalesRep = v ?? true)),
                            CheckboxListTile(dense: true, contentPadding: EdgeInsets.zero, value: _layout.showIncoterms, title: Text('Incoterms / Delivery', style: GoogleFonts.inter(fontSize: 12)), onChanged: (v) => setState(() => _layout.showIncoterms = v ?? true)),
                            CheckboxListTile(dense: true, contentPadding: EdgeInsets.zero, value: _layout.showLocation, title: Text('Location', style: GoogleFonts.inter(fontSize: 12)), onChanged: (v) => setState(() => _layout.showLocation = v ?? true)),
                            CheckboxListTile(dense: true, contentPadding: EdgeInsets.zero, value: _layout.showContactPerson, title: Text('Contact Person', style: GoogleFonts.inter(fontSize: 12)), onChanged: (v) => setState(() => _layout.showContactPerson = v ?? true)),
                            CheckboxListTile(dense: true, contentPadding: EdgeInsets.zero, value: _layout.showCrNumber, title: Text('CR / GSTIN No.', style: GoogleFonts.inter(fontSize: 12)), onChanged: (v) => setState(() => _layout.showCrNumber = v ?? true)),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // CENTER: Interactive Live A4 Canvas
                  Expanded(
                    child: Container(
                      color: const Color(0xFFE2E8F0),
                      padding: const EdgeInsets.all(20),
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: 0.72,
                          child: LayoutBuilder(
                            builder: (context, box) {
                              final visibleBlocks = _layout.blocks.where((b) => b.visible).toList();
                              return Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(_layout.borderStyle == 'rounded' ? 12 : 2),
                                  border: _layout.borderStyle == 'none'
                                      ? null
                                      : Border.all(
                                          color: primaryColor,
                                          width: _layout.borderStyle == 'double' ? 2.5 : 1.2,
                                        ),
                                  boxShadow: const [BoxShadow(color: Color(0x26000000), blurRadius: 18, offset: Offset(0, 6))],
                                ),
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    ReorderableListView.builder(
                                      padding: const EdgeInsets.all(18),
                                      buildDefaultDragHandles: false,
                                      itemCount: visibleBlocks.length,
                                      onReorder: (oldIdx, newIdx) {
                                        setState(() {
                                          if (newIdx > oldIdx) newIdx -= 1;
                                          final moved = visibleBlocks.removeAt(oldIdx);
                                          visibleBlocks.insert(newIdx, moved);
                                          final hidden = _layout.blocks.where((b) => !b.visible).toList();
                                          _layout.blocks = [...visibleBlocks, ...hidden];
                                          for (int i = 0; i < _layout.blocks.length; i++) {
                                            _layout.blocks[i].order = i;
                                          }
                                        });
                                      },
                                      itemBuilder: (ctx, i) {
                                        final blk = visibleBlocks[i];
                                        return ReorderableDragStartListener(
                                          key: ValueKey(blk.id),
                                          index: i,
                                          child: Container(
                                            margin: const EdgeInsets.only(bottom: 10),
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              border: Border.all(color: const Color(0xFFE2E8F0), style: BorderStyle.solid),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Padding(
                                                  padding: EdgeInsets.only(right: 6, top: 2),
                                                  child: Icon(Icons.drag_indicator_rounded, size: 15, color: Color(0xFF94A3B8)),
                                                ),
                                                Expanded(
                                                  child: _buildPreviewBlock(blk, companyName, currency, primaryColor, accentColor),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),

                                    // Draggable Stamp Overlay
                                    if (_layout.stamp.enabled)
                                      Positioned(
                                        left: (_layout.stamp.xRatio.clamp(0.05, 0.80)) * box.maxWidth,
                                        top: (_layout.stamp.yRatio.clamp(0.05, 0.86)) * box.maxHeight,
                                        child: GestureDetector(
                                          onPanUpdate: (details) {
                                            setState(() {
                                              _layout.stamp.xRatio = (_layout.stamp.xRatio + details.delta.dx / box.maxWidth).clamp(0.05, 0.80);
                                              _layout.stamp.yRatio = (_layout.stamp.yRatio + details.delta.dy / box.maxHeight).clamp(0.05, 0.86);
                                            });
                                          },
                                          child: MouseRegion(
                                            cursor: SystemMouseCursors.grab,
                                            child: Transform.rotate(
                                              angle: _layout.stamp.rotationDeg * math.pi / 180.0,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                                decoration: BoxDecoration(
                                                  color: Colors.white.withValues(alpha: 0.78),
                                                  border: Border.all(color: primaryColor, width: 2),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  _stampLabelCtrl.text.isEmpty ? 'RECEIVED' : _stampLabelCtrl.text.toUpperCase(),
                                                  style: GoogleFonts.inter(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w900,
                                                    color: primaryColor,
                                                    letterSpacing: 1.5,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),

                  // RIGHT: Design & Defaults Inspector
                  Container(
                    width: 300,
                    padding: const EdgeInsets.all(14),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(left: BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('TEMPLATE DETAILS', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF475569))),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _nameCtrl,
                            decoration: InputDecoration(
                              isDense: true,
                              labelText: 'Template Name *',
                              hintText: 'e.g. Wholesale Quote',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            initialValue: _docType,
                            decoration: InputDecoration(
                              isDense: true,
                              labelText: 'Document Type',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'QUOTATION', child: Text('Quotation / Estimate')),
                              DropdownMenuItem(value: 'INVOICE', child: Text('Bill / Tax Invoice')),
                              DropdownMenuItem(value: 'RECEIPT', child: Text('Receipt Voucher')),
                              DropdownMenuItem(value: 'PAYSLIP', child: Text('Salary Payslip')),
                            ],
                            onChanged: widget.templateToEdit != null
                                ? null
                                : (val) {
                                    if (val != null) {
                                      setState(() {
                                        _docType = val;
                                        _layout = TemplateLayoutConfig.defaultFor(val);
                                        _stampLabelCtrl.text = _layout.stamp.label;
                                      });
                                    }
                                  },
                          ),
                          SwitchListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text('Set as Default Template', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
                            value: _isDefault,
                            onChanged: (v) => setState(() => _isDefault = v),
                          ),
                          const Divider(height: 18),
                          Text('THEME & LAYOUT', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF475569))),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _colorPalette.map((hex) {
                              final c = _parseHex(hex);
                              final selected = _layout.primaryColorHex.toUpperCase() == hex.toUpperCase();
                              return InkWell(
                                onTap: () => setState(() => _layout.primaryColorHex = hex),
                                child: Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    color: c,
                                    shape: BoxShape.circle,
                                    border: selected ? Border.all(color: Colors.black, width: 2.5) : null,
                                  ),
                                  child: selected ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            initialValue: _layout.logoPosition,
                            decoration: InputDecoration(
                              isDense: true,
                              labelText: 'Logo Alignment',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'left', child: Text('Left')),
                              DropdownMenuItem(value: 'center', child: Text('Center')),
                              DropdownMenuItem(value: 'right', child: Text('Right')),
                            ],
                            onChanged: (v) => setState(() => _layout.logoPosition = v ?? 'left'),
                          ),
                          const SizedBox(height: 10),
                          Builder(
                            builder: (ctx) {
                              final branches = ctx.watch<LeadProvider>().branches;
                              final companyLogo = ctx.watch<CompanyProvider>().activeCompanyDetail?.logo ??
                                  (ctx.watch<AuthProvider>().currentUser?.companyLogo ?? '');
                              final validBranchId = branches.any((b) => b.id == _layout.branchId)
                                  ? _layout.branchId
                                  : '';
                              final previewLogo = _layout.logoOverride.isNotEmpty
                                  ? _layout.logoOverride
                                  : companyLogo;

                              return Row(
                                children: [
                                  CompanyLogoView(
                                    logo: previewLogo,
                                    companyName: 'Logo',
                                    size: 36,
                                    borderRadius: BorderRadius.circular(8),
                                    borderColor: const Color(0xFFCBD5E1),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      initialValue: validBranchId,
                                      isExpanded: true,
                                      decoration: InputDecoration(
                                        isDense: true,
                                        labelText: 'Header Logo (Branch)',
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      items: [
                                        const DropdownMenuItem(
                                          value: '',
                                          child: Text('Company Main Logo (Default)', overflow: TextOverflow.ellipsis),
                                        ),
                                        ...branches.map((b) => DropdownMenuItem(
                                              value: b.id,
                                              child: Text(
                                                '${b.name}${b.logo.isNotEmpty ? " (Custom)" : " (Default)"}',
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            )),
                                      ],
                                      onChanged: (v) {
                                        setState(() {
                                          _layout.branchId = v ?? '';
                                          if (_layout.branchId.isEmpty) {
                                            _layout.logoOverride = '';
                                          } else {
                                            final selected = branches.firstWhere((b) => b.id == _layout.branchId);
                                            _layout.logoOverride = selected.effectiveLogo.isNotEmpty
                                                ? selected.effectiveLogo
                                                : (selected.logo.isNotEmpty ? selected.logo : companyLogo);
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            initialValue: _layout.borderStyle,
                            decoration: InputDecoration(
                              isDense: true,
                              labelText: 'Border Style',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'solid', child: Text('Classic Solid')),
                              DropdownMenuItem(value: 'rounded', child: Text('Modern Rounded')),
                              DropdownMenuItem(value: 'double', child: Text('Banknote Thick')),
                              DropdownMenuItem(value: 'none', child: Text('Borderless Minimal')),
                            ],
                            onChanged: (v) => setState(() => _layout.borderStyle = v ?? 'solid'),
                          ),
                          if (_layout.stamp.enabled) ...[
                            const SizedBox(height: 10),
                            TextField(
                              controller: _stampLabelCtrl,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                isDense: true,
                                labelText: 'Stamp Text',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
                          const Divider(height: 18),
                          Text('CONTENT DEFAULTS', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF475569))),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _titleOverrideCtrl,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              isDense: true,
                              labelText: 'Custom Document Title',
                              hintText: 'e.g. PROFORMA INVOICE',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _incotermsCtrl,
                            decoration: InputDecoration(
                              isDense: true,
                              labelText: 'Default Incoterms / Delivery',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _bankCtrl,
                            maxLines: 2,
                            decoration: InputDecoration(
                              isDense: true,
                              labelText: 'Bank Payment Details',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _termsCtrl,
                            maxLines: 3,
                            decoration: InputDecoration(
                              isDense: true,
                              labelText: 'Default Terms & Conditions',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                          CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            value: _layout.hideCostInPdf,
                            title: Text('Hide CST Cost in Client PDF', style: GoogleFonts.inter(fontSize: 12)),
                            onChanged: (v) => setState(() => _layout.hideCostInPdf = v ?? true),
                          ),
                          CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            value: _layout.includePodSlip,
                            title: Text('Include POD Slip by Default', style: GoogleFonts.inter(fontSize: 12)),
                            onChanged: (v) => setState(() => _layout.includePodSlip = v ?? false),
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
      ),
    );
  }

  Widget _buildPreviewBlock(
    TemplateBlockConfig blk,
    String companyName,
    String currency,
    Color primary,
    Color accent,
  ) {
    final docLabel = _titleOverrideCtrl.text.isNotEmpty
        ? _titleOverrideCtrl.text.toUpperCase()
        : (_docType == 'QUOTATION'
            ? 'QUOTATION'
            : (_docType == 'INVOICE'
                ? 'TAX INVOICE'
                : (_docType == 'PAYSLIP' ? 'SALARY PAYSLIP' : 'RECEIPT VOUCHER')));

    switch (blk.id) {
      case 'header':
        final align = _layout.logoPosition == 'center'
            ? CrossAxisAlignment.center
            : (_layout.logoPosition == 'right' ? CrossAxisAlignment.end : CrossAxisAlignment.start);
        return Column(
          crossAxisAlignment: align,
          children: [
            Row(
              mainAxisAlignment: _layout.logoPosition == 'center'
                  ? MainAxisAlignment.center
                  : (_layout.logoPosition == 'right' ? MainAxisAlignment.end : MainAxisAlignment.spaceBetween),
              children: [
                Text(companyName.toUpperCase(), style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: primary)),
                if (_layout.logoPosition == 'left')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(4)),
                    child: Text(docLabel, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
              ],
            ),
            if (_layout.logoPosition != 'left') ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(4)),
                child: Text(docLabel, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
            ],
            if (_layout.showCompanyAddress)
              Text('Company Address · Phone · Email', style: GoogleFonts.inter(fontSize: 9, color: const Color(0xFF64748B))),
          ],
        );

      case 'client_meta':
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('BILL TO / CLIENT', style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w700, color: primary)),
                Text('Sample Customer Ltd.', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700)),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Doc #: QT-2026-0001', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600)),
                Text('Date: 2026-11-18', style: GoogleFonts.inter(fontSize: 9, color: const Color(0xFF64748B))),
              ],
            ),
          ],
        );

      case 'items_table':
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              color: primary,
              child: Row(
                children: [
                  Expanded(flex: 3, child: Text('Item', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white))),
                  ..._layout.customColumns.map((c) => Expanded(child: Text(c, style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w700, color: Colors.white)))),
                  if (_layout.showQty) Expanded(child: Text('Qty', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white))),
                  if (_layout.showPrice) Expanded(child: Text('Price', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white))),
                  Expanded(child: Text('Total', textAlign: TextAlign.right, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white))),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              color: const Color(0xFFF8FAFC),
              child: Row(
                children: [
                  Expanded(flex: 3, child: Text('Sample Product / Service', style: GoogleFonts.inter(fontSize: 9))),
                  ..._layout.customColumns.map((_) => Expanded(child: Text('-', style: GoogleFonts.inter(fontSize: 9)))),
                  if (_layout.showQty) Expanded(child: Text('10', style: GoogleFonts.inter(fontSize: 9))),
                  if (_layout.showPrice) Expanded(child: Text('500.00', style: GoogleFonts.inter(fontSize: 9))),
                  Expanded(child: Text('$currency 5,000', textAlign: TextAlign.right, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700))),
                ],
              ),
            ),
          ],
        );

      case 'totals_words':
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Amount in Words: Five Thousand Only', style: GoogleFonts.inter(fontSize: 9, fontStyle: FontStyle.italic, color: const Color(0xFF475569))),
            Text('GRAND TOTAL: $currency 5,000.00', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: accent)),
          ],
        );

      case 'bank_details':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('BANK / PAYMENT DETAILS', style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w800, color: primary)),
            Text(
              _bankCtrl.text.isNotEmpty ? _bankCtrl.text : 'Bank Name · A/C No · IBAN / SWIFT',
              style: GoogleFonts.inter(fontSize: 9, color: const Color(0xFF475569)),
            ),
          ],
        );

      case 'terms':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('TERMS & CONDITIONS', style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w800, color: primary)),
            Text(
              _termsCtrl.text.isNotEmpty ? _termsCtrl.text : 'Standard payment and delivery terms apply.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(fontSize: 9, color: const Color(0xFF475569)),
            ),
          ],
        );

      case 'pod_slip':
        return Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)),
          child: Text('PROOF OF DELIVERY (POD) · Driver · Receiver Sign & Mobile', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700)),
        );

      case 'signatures':
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Receiver Signature', style: GoogleFonts.inter(fontSize: 9, color: const Color(0xFF475569))),
              Text('Authorized Signature', style: GoogleFonts.inter(fontSize: 9, color: const Color(0xFF475569))),
            ],
          ),
        );

      default:
        return Text(blk.label, style: GoogleFonts.inter(fontSize: 10));
    }
  }
}

