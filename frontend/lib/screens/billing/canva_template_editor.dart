import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/document_template_model.dart';

class CanvaTemplateEditor extends StatefulWidget {
  final String docType;
  final List<CanvasElement> elements;
  final String branchLogoUrl;
  final String companyLogoUrl;
  final VoidCallback onChanged;

  const CanvaTemplateEditor({
    super.key,
    required this.docType,
    required this.elements,
    required this.branchLogoUrl,
    required this.companyLogoUrl,
    required this.onChanged,
  });

  @override
  State<CanvaTemplateEditor> createState() => _CanvaTemplateEditorState();
}

class _CanvaTemplateEditorState extends State<CanvaTemplateEditor> {
  String? _selectedId;
  double _zoom = 1.0;
  final FocusNode _canvasFocusNode = FocusNode();
  final TextEditingController _textCtrl = TextEditingController();
  final TextEditingController _customColCtrl = TextEditingController();

  static const double _a4W = 595.0;
  static const double _a4H = 842.0;

  static const List<String> _standardTableCols = [
    'Sl. No',
    'Qty',
    'Item Name',
    'Item code',
    'Category',
    'HS code',
    'Pkg',
    'Origin',
    'Unit price',
    'CST',
    'Ex. Tax',
    'VAT%',
    'VAT',
    'Total',
    'Margin',
  ];

  static const List<Map<String, String>> _dynamicTags = [
    {'label': 'Doc Number', 'tag': '{{doc_number}}'},
    {'label': 'Date', 'tag': '{{date}}'},
    {'label': 'Customer Name', 'tag': '{{customer_name}}'},
    {'label': 'Customer Phone', 'tag': '{{customer_phone}}'},
    {'label': 'Customer Address', 'tag': '{{customer_address}}'},
    {'label': 'Client PO', 'tag': '{{client_po}}'},
    {'label': 'Incoterms', 'tag': '{{incoterms}}'},
    {'label': 'Currency', 'tag': '{{currency}}'},
    {'label': 'Delivery Address', 'tag': '{{delivery_address}}'},
    {'label': 'Company TRN', 'tag': '{{company_trn}}'},
    {'label': 'Customer TRN', 'tag': '{{customer_trn}}'},
    {'label': 'Subtotal', 'tag': '{{subtotal}}'},
    {'label': 'Tax / VAT', 'tag': '{{tax_amount}}'},
    {'label': 'Extra Charge', 'tag': '{{extra_charge}}'},
    {'label': 'Grand Total', 'tag': '{{grand_total}}'},
    {'label': 'Amount in Words', 'tag': '{{amount_in_words}}'},
    {'label': 'VAT in Words', 'tag': '{{vat_in_words}}'},
    {'label': 'Bank Details', 'tag': '{{bank_details}}'},
    {'label': 'Terms & Conditions', 'tag': '{{terms}}'},
    {'label': 'Branch Name', 'tag': '{{branch_name}}'},
    {'label': 'Branch Address', 'tag': '{{branch_address}}'},
    {'label': 'Branch Email', 'tag': '{{branch_email}}'},
    {'label': 'Branch Phone', 'tag': '{{branch_phone}}'},
    {'label': 'Sales Rep Name', 'tag': '{{sales_rep_name}}'},
    {'label': 'Sales Rep Phone', 'tag': '{{sales_rep_phone}}'},
  ];

  static const List<String> _palette = [
    '#0F172A',
    '#1E3A8A',
    '#047857',
    '#B45309',
    '#DC2626',
    '#6D28D9',
    '#475569',
    '#FFFFFF',
  ];

  CanvasElement? get _selected {
    if (_selectedId == null) return null;
    final idx = widget.elements.indexWhere((e) => e.id == _selectedId);
    return idx == -1 ? null : widget.elements[idx];
  }

  @override
  void dispose() {
    _canvasFocusNode.dispose();
    _textCtrl.dispose();
    _customColCtrl.dispose();
    super.dispose();
  }

  void _select(CanvasElement? el, {bool focusCanvas = false}) {
    if (focusCanvas) {
      _canvasFocusNode.requestFocus();
    }
    setState(() {
      _selectedId = el?.id;
      _textCtrl.text = el?.text ?? '';
    });
  }

  void _deleteSelected() {
    if (_selectedId == null) return;
    setState(() {
      widget.elements.removeWhere((e) => e.id == _selectedId);
      _selectedId = null;
      _textCtrl.clear();
    });
    widget.onChanged();
  }

  void _duplicateSelected() {
    final sel = _selected;
    if (sel == null) return;
    _addElement(sel.copyWith(id: _newId(sel.type), x: sel.x + 12, y: sel.y + 12));
  }

  String _newId(String prefix) =>
      '${prefix}_${DateTime.now().microsecondsSinceEpoch}';

  void _addElement(CanvasElement el) {
    setState(() {
      widget.elements.add(el);
      _selectedId = el.id;
      _textCtrl.text = el.text;
    });
    widget.onChanged();
  }

  Future<void> _pickImageForElement(CanvasElement? existing) async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (res == null || res.files.isEmpty || res.files.first.bytes == null) return;
    final b64 = base64Encode(res.files.first.bytes!);
    final ext = (res.files.first.extension ?? 'png').toLowerCase();
    final dataUri = 'data:image/$ext;base64,$b64';
    if (existing != null) {
      setState(() => existing.imageSource = dataUri);
      widget.onChanged();
    } else {
      _addElement(CanvasElement(
        id: _newId('img'),
        type: 'image',
        x: 200,
        y: 30,
        w: 160,
        h: 64,
        imageSource: dataUri,
      ));
    }
  }

  void _loadStandardPreset() {
    setState(() {
      widget.elements
        ..clear()
        ..addAll(TemplateLayoutConfig.buildStandardParfemperorCanvas(widget.docType));
      _selectedId = widget.elements.isNotEmpty ? widget.elements.first.id : null;
      _textCtrl.text = widget.elements.isNotEmpty ? widget.elements.first.text : '';
    });
    widget.onChanged();
  }

  Color _hex(String hex, {Color fallback = Colors.transparent}) {
    if (hex.isEmpty) return fallback;
    try {
      final clean = hex.replaceAll('#', '');
      if (clean.length == 6) return Color(int.parse('FF$clean', radix: 16));
      if (clean.length == 8) return Color(int.parse(clean, radix: 16));
    } catch (_) {}
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final sel = _selected;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.delete): _deleteSelected,
        const SingleActivator(LogicalKeyboardKey.backspace): _deleteSelected,
        const SingleActivator(LogicalKeyboardKey.keyD, control: true): _duplicateSelected,
      },
      child: Focus(
        focusNode: _canvasFocusNode,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 900;
            final toolbar = _buildToolbar();
            final canvasArea = _buildCanvasArea();
            final inspector = _buildInspector(sel);

            if (isNarrow) {
              return Column(
                children: [
                  toolbar,
                  const SizedBox(height: 8),
                  Expanded(flex: 3, child: canvasArea),
                  const SizedBox(height: 8),
                  SizedBox(height: 220, child: inspector),
                ],
              );
            }

            return Column(
              children: [
                toolbar,
                const SizedBox(height: 10),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 7, child: canvasArea),
                      const SizedBox(width: 12),
                      SizedBox(width: 280, child: inspector),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ElevatedButton.icon(
            onPressed: _loadStandardPreset,
            icon: const Icon(Icons.auto_awesome_rounded, size: 15),
            label: const Text('Load Standard Layout', style: TextStyle(fontSize: 11.5)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF047857),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => _addElement(CanvasElement(
              id: _newId('txt'),
              type: 'text',
              x: 40,
              y: 120,
              w: 220,
              h: 32,
              text: 'Custom Text',
              fontSize: 11,
            )),
            icon: const Icon(Icons.text_fields_rounded, size: 15),
            label: const Text('+ Text', style: TextStyle(fontSize: 11.5)),
          ),
          PopupMenuButton<String>(
            onSelected: (tag) {
              _addElement(CanvasElement(
                id: _newId('fld'),
                type: 'text',
                x: 40,
                y: 150,
                w: 220,
                h: 26,
                text: tag,
                fontSize: 10,
              ));
            },
            itemBuilder: (_) => _dynamicTags
                .map((t) => PopupMenuItem<String>(
                      value: t['tag']!,
                      child: Text('${t['label']} (${t['tag']})', style: const TextStyle(fontSize: 12)),
                    ))
                .toList(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFCBD5E1)),
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.data_object_rounded, size: 15, color: Color(0xFF1E3A8A)),
                  SizedBox(width: 5),
                  Text('+ Field Tag', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => _addElement(CanvasElement(
              id: _newId('logo'),
              type: 'image',
              x: 205,
              y: 24,
              w: 180,
              h: 64,
              imageSource: '{{branch_logo}}',
            )),
            icon: const Icon(Icons.business_rounded, size: 15),
            label: const Text('+ Branch Logo', style: TextStyle(fontSize: 11.5)),
          ),
          OutlinedButton.icon(
            onPressed: () => _pickImageForElement(null),
            icon: const Icon(Icons.image_outlined, size: 15),
            label: const Text('+ Upload Image', style: TextStyle(fontSize: 11.5)),
          ),
          OutlinedButton.icon(
            onPressed: () => _addElement(CanvasElement(
              id: _newId('tbl'),
              type: 'table',
              x: 32,
              y: 250,
              w: 531,
              h: 260,
              borderColorHex: '#334155',
              borderWidth: 0.8,
              tableColumns: ['Qty', 'Item Name', 'Unit price', 'VAT%', 'Total'],
            )),
            icon: const Icon(Icons.table_chart_outlined, size: 15),
            label: const Text('+ Items Table', style: TextStyle(fontSize: 11.5)),
          ),
          OutlinedButton.icon(
            onPressed: () => _addElement(CanvasElement(
              id: _newId('line'),
              type: 'line',
              x: 32,
              y: 400,
              w: 531,
              h: 2,
              colorHex: '#0F172A',
              borderWidth: 1.0,
            )),
            icon: const Icon(Icons.horizontal_rule_rounded, size: 15),
            label: const Text('+ Line', style: TextStyle(fontSize: 11.5)),
          ),
          OutlinedButton.icon(
            onPressed: () => _addElement(CanvasElement(
              id: _newId('box'),
              type: 'box',
              x: 32,
              y: 100,
              w: 240,
              h: 80,
              bgColorHex: '#F8FAFC',
              borderColorHex: '#94A3B8',
              borderWidth: 1.0,
            )),
            icon: const Icon(Icons.crop_square_rounded, size: 15),
            label: const Text('+ Box', style: TextStyle(fontSize: 11.5)),
          ),
          Container(
            margin: const EdgeInsets.only(left: 6),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Zoom Out',
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.zoom_out_rounded, size: 17),
                  onPressed: () => setState(() => _zoom = (_zoom - 0.15).clamp(0.5, 2.5)),
                ),
                InkWell(
                  onTap: () => setState(() => _zoom = 1.0),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Text(
                      '${(_zoom * 100).round()}%',
                      style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Zoom In',
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.zoom_in_rounded, size: 17),
                  onPressed: () => setState(() => _zoom = (_zoom + 0.15).clamp(0.5, 2.5)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCanvasArea() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scaleW = (constraints.maxWidth - 8) / _a4W;
          final scaleH = (constraints.maxHeight - 8) / _a4H;
          final baseScale = (scaleW < scaleH ? scaleW : scaleH).clamp(0.35, 1.15);
          final scale = baseScale * _zoom;

          return SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: GestureDetector(
                onTap: () => _select(null, focusCanvas: true),
                child: Container(
                  width: _a4W * scale,
                  height: _a4H * scale,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.14),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: widget.elements.map((el) {
                      final isSel = el.id == _selectedId;
                      final showBorder = isSel || (el.type != 'line' && el.borderWidth > 0);
                      return Positioned(
                        left: el.x * scale,
                        top: el.y * scale,
                        width: (el.w * scale).clamp(16.0, _a4W * scale),
                        height: (el.h * scale).clamp(el.type == 'line' ? 10.0 : 14.0, _a4H * scale),
                        child: GestureDetector(
                          onTap: () => _select(el, focusCanvas: true),
                          onPanUpdate: el.locked
                              ? null
                              : (d) {
                                  setState(() {
                                    el.x = (el.x + d.delta.dx / scale).clamp(0.0, _a4W - 20);
                                    el.y = (el.y + d.delta.dy / scale).clamp(0.0, _a4H - 12);
                                  });
                                  widget.onChanged();
                                },
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: double.infinity,
                                height: double.infinity,
                                decoration: BoxDecoration(
                                  color: (el.type == 'line' || el.type == 'table')
                                      ? Colors.transparent
                                      : _hex(el.bgColorHex),
                                  border: showBorder
                                      ? Border.all(
                                          color: isSel
                                              ? const Color(0xFF2563EB)
                                              : _hex(el.borderColorHex, fallback: const Color(0xFF334155)),
                                          width: isSel ? 1.5 : el.borderWidth,
                                        )
                                      : null,
                                ),
                                child: _renderElementPreview(el, scale),
                              ),
                              if (isSel && !el.locked)
                                Positioned(
                                  right: -5,
                                  bottom: -5,
                                  child: GestureDetector(
                                    onPanUpdate: (d) {
                                      setState(() {
                                        el.w = (el.w + d.delta.dx / scale).clamp(24.0, _a4W - el.x);
                                        el.h = (el.h + d.delta.dy / scale).clamp(
                                            el.type == 'line' ? 2.0 : 16.0, _a4H - el.y);
                                      });
                                      widget.onChanged();
                                    },
                                    child: Container(
                                      width: 11,
                                      height: 11,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2563EB),
                                        border: Border.all(color: Colors.white, width: 1.5),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _renderElementPreview(CanvasElement el, double scale) {
    if (el.type == 'line') {
      return Center(
        child: Container(
          width: double.infinity,
          height: (el.borderWidth * scale).clamp(1.0, 2.5),
          color: _hex(el.colorHex, fallback: const Color(0xFF0F172A)),
        ),
      );
    }
    if (el.type == 'box') {
      return const SizedBox.expand();
    }
    if (el.type == 'image') {
      final src = el.imageSource == '{{branch_logo}}'
          ? (widget.branchLogoUrl.isNotEmpty ? widget.branchLogoUrl : widget.companyLogoUrl)
          : el.imageSource;
      if (src.startsWith('data:image')) {
        try {
          final bytes = base64Decode(src.split(',').last);
          return Image.memory(bytes, fit: BoxFit.contain);
        } catch (_) {}
      } else if (src.startsWith('http')) {
        return Image.network(src, fit: BoxFit.contain, errorBuilder: (_, __, ___) => _logoPlaceholder());
      }
      return _logoPlaceholder();
    }
    if (el.type == 'table') {
      final cols = el.tableColumns.isEmpty ? ['Qty', 'Item Name', 'Total'] : el.tableColumns;
      final headerBg = _hex(el.bgColorHex, fallback: const Color(0xFFCBD5E1));
      final textCol = _hex(el.colorHex, fallback: const Color(0xFF0F172A));
      return Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: headerBg,
              border: const Border(bottom: BorderSide(color: Color(0xFF475569), width: 0.8)),
            ),
            child: Row(
              children: cols.asMap().entries.map((entry) {
                final isLast = entry.key == cols.length - 1;
                return Expanded(
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 3 * scale, horizontal: 2 * scale),
                    decoration: BoxDecoration(
                      border: isLast
                          ? null
                          : const Border(right: BorderSide(color: Color(0xFF64748B), width: 0.6)),
                    ),
                    child: Text(
                      entry.value,
                      style: GoogleFonts.inter(
                        fontSize: (7.5 * scale).clamp(5.0, 11.0),
                        fontWeight: FontWeight.w700,
                        color: textCol,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: Column(
              children: List.generate(5, (rowIdx) {
                return Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Color(0xFFCBD5E1), width: 0.6)),
                    ),
                    child: Row(
                      children: cols.asMap().entries.map((entry) {
                        final isLast = entry.key == cols.length - 1;
                        return Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              border: isLast
                                  ? null
                                  : const Border(right: BorderSide(color: Color(0xFFE2E8F0), width: 0.6)),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                );
              }),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: headerBg,
              border: const Border(top: BorderSide(color: Color(0xFF475569), width: 0.8)),
            ),
            padding: EdgeInsets.symmetric(vertical: 2.5 * scale, horizontal: 4 * scale),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('TOTAL', style: GoogleFonts.inter(fontSize: (7.5 * scale).clamp(5.0, 11.0), fontWeight: FontWeight.w700, color: textCol)),
                Text('{{grand_total}}', style: GoogleFonts.inter(fontSize: (7.5 * scale).clamp(5.0, 11.0), fontWeight: FontWeight.w700, color: textCol)),
              ],
            ),
          ),
        ],
      );
    }

    final align = el.align == 'center'
        ? TextAlign.center
        : (el.align == 'right' ? TextAlign.right : TextAlign.left);
    return Padding(
      padding: EdgeInsets.all(2 * scale),
      child: Text(
        el.text,
        textAlign: align,
        style: GoogleFonts.inter(
          fontSize: (el.fontSize * scale).clamp(5.0, 28.0),
          fontWeight: el.bold ? FontWeight.w700 : FontWeight.w400,
          fontStyle: el.italic ? FontStyle.italic : FontStyle.normal,
          color: _hex(el.colorHex, fallback: const Color(0xFF0F172A)),
        ),
        overflow: TextOverflow.fade,
      ),
    );
  }

  Widget _logoPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      alignment: Alignment.center,
      child: const Text('LOGO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
    );
  }

  Widget _buildInspector(CanvasElement? sel) {
    if (sel == null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Layers (${widget.elements.length})',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('Tap any element on the A4 canvas to edit, move, resize, or delete it.',
                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.separated(
                itemCount: widget.elements.length,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (_, i) {
                  final el = widget.elements[i];
                  return ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    tileColor: Colors.white,
                    title: Text(
                      el.type == 'text' ? (el.text.split('\n').first) : el.type.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFDC2626)),
                      onPressed: () {
                        setState(() => widget.elements.removeAt(i));
                        widget.onChanged();
                      },
                    ),
                    onTap: () => _select(el),
                  );
                },
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Edit ${sel.type.toUpperCase()}',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800)),
                ),
                IconButton(
                  tooltip: 'Duplicate',
                  icon: const Icon(Icons.copy_rounded, size: 17),
                  onPressed: () {
                    _addElement(sel.copyWith(id: _newId(sel.type), x: sel.x + 12, y: sel.y + 12));
                  },
                ),
                IconButton(
                  tooltip: 'Bring Forward',
                  icon: const Icon(Icons.arrow_upward_rounded, size: 17),
                  onPressed: () {
                    final idx = widget.elements.indexOf(sel);
                    if (idx < widget.elements.length - 1) {
                      setState(() {
                        widget.elements.removeAt(idx);
                        widget.elements.insert(idx + 1, sel);
                      });
                      widget.onChanged();
                    }
                  },
                ),
                IconButton(
                  tooltip: 'Delete Layer',
                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC2626)),
                  onPressed: () {
                    setState(() {
                      widget.elements.removeWhere((e) => e.id == sel.id);
                      _selectedId = null;
                    });
                    widget.onChanged();
                  },
                ),
              ],
            ),
            const Divider(height: 12),
            if (sel.type == 'text') ...[
              TextField(
                controller: _textCtrl,
                maxLines: 4,
                style: GoogleFonts.inter(fontSize: 12),
                decoration: const InputDecoration(
                  labelText: 'Text / Dynamic Tags',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) {
                  setState(() => sel.text = v);
                  widget.onChanged();
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('Size:', style: TextStyle(fontSize: 11.5)),
                  Expanded(
                    child: Slider(
                      min: 6,
                      max: 24,
                      divisions: 18,
                      value: sel.fontSize.clamp(6, 24),
                      label: sel.fontSize.toStringAsFixed(0),
                      onChanged: (v) {
                        setState(() => sel.fontSize = v);
                        widget.onChanged();
                      },
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.format_bold,
                        color: sel.bold ? const Color(0xFF2563EB) : const Color(0xFF64748B)),
                    onPressed: () {
                      setState(() => sel.bold = !sel.bold);
                      widget.onChanged();
                    },
                  ),
                ],
              ),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'left', icon: Icon(Icons.format_align_left, size: 15)),
                  ButtonSegment(value: 'center', icon: Icon(Icons.format_align_center, size: 15)),
                  ButtonSegment(value: 'right', icon: Icon(Icons.format_align_right, size: 15)),
                ],
                selected: {sel.align},
                onSelectionChanged: (s) {
                  setState(() => sel.align = s.first);
                  widget.onChanged();
                },
              ),
              const SizedBox(height: 8),
            ],
            if (sel.type == 'image') ...[
              ElevatedButton.icon(
                onPressed: () => _pickImageForElement(sel),
                icon: const Icon(Icons.upload_rounded, size: 16),
                label: const Text('Replace Image'),
              ),
              const SizedBox(height: 6),
              OutlinedButton(
                onPressed: () {
                  setState(() => sel.imageSource = '{{branch_logo}}');
                  widget.onChanged();
                },
                child: const Text('Use Dynamic {{branch_logo}}'),
              ),
              const SizedBox(height: 8),
            ],
            if (sel.type == 'table') ...[
              Text('Drag Columns to Reorder', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Container(
                constraints: const BoxConstraints(maxHeight: 190),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: ReorderableListView.builder(
                  shrinkWrap: true,
                  buildDefaultDragHandles: false,
                  itemCount: sel.tableColumns.length,
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) newIndex -= 1;
                      final cols = List<String>.from(sel.tableColumns);
                      final moved = cols.removeAt(oldIndex);
                      cols.insert(newIndex, moved);
                      sel.tableColumns = cols;
                    });
                    widget.onChanged();
                  },
                  itemBuilder: (ctx, idx) {
                    final colName = sel.tableColumns[idx];
                    return Container(
                      key: ValueKey('col_${sel.id}_$colName'),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                      ),
                      child: Row(
                        children: [
                          ReorderableDragStartListener(
                            index: idx,
                            child: const Icon(Icons.drag_handle_rounded, size: 16, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              colName,
                              style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (sel.tableColumns.length > 1)
                            InkWell(
                              onTap: () {
                                setState(() {
                                  final cols = List<String>.from(sel.tableColumns)..removeAt(idx);
                                  sel.tableColumns = cols;
                                });
                                widget.onChanged();
                              },
                              child: const Icon(Icons.close_rounded, size: 14, color: Color(0xFFDC2626)),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Text('Toggle Columns', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: _standardTableCols.map((col) {
                  final active = sel.tableColumns.contains(col);
                  return FilterChip(
                    label: Text(col, style: const TextStyle(fontSize: 10.5)),
                    selected: active,
                    onSelected: (v) {
                      setState(() {
                        final cols = List<String>.from(sel.tableColumns);
                        if (v && !cols.contains(col)) {
                          cols.add(col);
                        } else if (!v && cols.length > 1) {
                          cols.remove(col);
                        }
                        sel.tableColumns = cols;
                      });
                      widget.onChanged();
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _customColCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Custom column...',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_rounded, color: Color(0xFF047857)),
                    onPressed: () {
                      final col = _customColCtrl.text.trim();
                      if (col.isEmpty) return;
                      setState(() {
                        sel.tableColumns = [...sel.tableColumns, col];
                        _customColCtrl.clear();
                      });
                      widget.onChanged();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Text('Text / Line Color', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ..._palette.map((hex) => InkWell(
                      onTap: () {
                        setState(() => sel.colorHex = hex);
                        widget.onChanged();
                      },
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: _hex(hex),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: sel.colorHex == hex ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
                            width: sel.colorHex == hex ? 2.5 : 1,
                          ),
                        ),
                      ),
                    )),
                _buildColorPickerButton(
                  currentHex: sel.colorHex.isEmpty ? '#0F172A' : sel.colorHex,
                  onPicked: (hex) {
                    setState(() => sel.colorHex = hex);
                    widget.onChanged();
                  },
                ),
              ],
            ),
            if (sel.type != 'image' && sel.type != 'line') ...[
              const SizedBox(height: 10),
              Text(
                sel.type == 'table' ? 'Header / Footer Fill Color' : 'Background Fill Color',
                style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  InkWell(
                    onTap: () {
                      setState(() => sel.bgColorHex = '');
                      widget.onChanged();
                    },
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: sel.bgColorHex.isEmpty ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
                          width: sel.bgColorHex.isEmpty ? 2.5 : 1,
                        ),
                      ),
                      child: const Icon(Icons.block_rounded, size: 13, color: Color(0xFF94A3B8)),
                    ),
                  ),
                  ..._palette.map((hex) => InkWell(
                        onTap: () {
                          setState(() => sel.bgColorHex = hex);
                          widget.onChanged();
                        },
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: _hex(hex),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: sel.bgColorHex == hex ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
                              width: sel.bgColorHex == hex ? 2.5 : 1,
                            ),
                          ),
                        ),
                      )),
                  _buildColorPickerButton(
                    currentHex: sel.bgColorHex.isEmpty ? '#CBD5E1' : sel.bgColorHex,
                    onPicked: (hex) {
                      setState(() => sel.bgColorHex = hex);
                      widget.onChanged();
                    },
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Text(
              'Pos: X=${sel.x.toStringAsFixed(0)} Y=${sel.y.toStringAsFixed(0)} | Size: ${sel.w.toStringAsFixed(0)}×${sel.h.toStringAsFixed(0)}',
              style: GoogleFonts.robotoMono(fontSize: 10.5, color: const Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorPickerButton({
    required String currentHex,
    required ValueChanged<String> onPicked,
  }) {
    return InkWell(
      onTap: () => _openColorPickerDialog(currentHex, onPicked),
      borderRadius: BorderRadius.circular(12),
      child: Tooltip(
        message: 'Custom Color Picker',
        child: Container(
          width: 24,
          height: 22,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            gradient: const SweepGradient(
              colors: [
                Colors.red,
                Colors.orange,
                Colors.yellow,
                Colors.green,
                Colors.cyan,
                Colors.blue,
                Colors.purple,
                Colors.red,
              ],
            ),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: const Icon(Icons.colorize_rounded, size: 12, color: Colors.white),
        ),
      ),
    );
  }

  Future<void> _openColorPickerDialog(
    String initialHex,
    ValueChanged<String> onPicked,
  ) async {
    Color current = _hex(initialHex, fallback: const Color(0xFF0F172A));
    double r = (current.r * 255).roundToDouble();
    double g = (current.g * 255).roundToDouble();
    double b = (current.b * 255).roundToDouble();
    String toHex(Color c) {
      final ri = (c.r * 255).round().toRadixString(16).padLeft(2, '0');
      final gi = (c.g * 255).round().toRadixString(16).padLeft(2, '0');
      final bi = (c.b * 255).round().toRadixString(16).padLeft(2, '0');
      return '#${ri.toUpperCase()}${gi.toUpperCase()}${bi.toUpperCase()}';
    }

    final hexCtrl = TextEditingController(text: toHex(current));
    const swatches = [
      '#000000', '#0F172A', '#334155', '#64748B', '#CBD5E1', '#E2E8F0', '#F1F5F9', '#FFFFFF',
      '#1E3A8A', '#2563EB', '#0284C7', '#0891B2', '#0D9488', '#047857', '#16A34A', '#65A30D',
      '#CA8A04', '#D97706', '#EA580C', '#DC2626', '#E11D48', '#9333EA', '#7C3AED', '#4F46E5',
    ];

    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDlg) {
            void syncRgb(Color c) {
              current = c;
              r = (c.r * 255).roundToDouble();
              g = (c.g * 255).roundToDouble();
              b = (c.b * 255).roundToDouble();
              hexCtrl.text = toHex(c);
            }

            return AlertDialog(
              title: Text('Pick Color', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800)),
              content: SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: current,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: hexCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Hex (#RRGGBB)',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (v) {
                              if (v.replaceAll('#', '').length == 6) {
                                final parsed = _hex(v, fallback: current);
                                setDlg(() => syncRgb(parsed));
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: swatches.map((h) {
                        final col = _hex(h);
                        return InkWell(
                          onTap: () => setDlg(() => syncRgb(col)),
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: col,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: toHex(current) == h ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
                                width: toHex(current) == h ? 2.5 : 1,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const SizedBox(width: 16, child: Text('R', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.red))),
                        Expanded(
                          child: Slider(
                            min: 0,
                            max: 255,
                            activeColor: Colors.red,
                            value: r,
                            onChanged: (v) => setDlg(() {
                              r = v;
                              current = Color.fromARGB(255, r.round(), g.round(), b.round());
                              hexCtrl.text = toHex(current);
                            }),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const SizedBox(width: 16, child: Text('G', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.green))),
                        Expanded(
                          child: Slider(
                            min: 0,
                            max: 255,
                            activeColor: Colors.green,
                            value: g,
                            onChanged: (v) => setDlg(() {
                              g = v;
                              current = Color.fromARGB(255, r.round(), g.round(), b.round());
                              hexCtrl.text = toHex(current);
                            }),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const SizedBox(width: 16, child: Text('B', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.blue))),
                        Expanded(
                          child: Slider(
                            min: 0,
                            max: 255,
                            activeColor: Colors.blue,
                            value: b,
                            onChanged: (v) => setDlg(() {
                              b = v;
                              current = Color.fromARGB(255, r.round(), g.round(), b.round());
                              hexCtrl.text = toHex(current);
                            }),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, toHex(current)),
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
    hexCtrl.dispose();
    if (picked != null) {
      onPicked(picked);
    }
  }
}
