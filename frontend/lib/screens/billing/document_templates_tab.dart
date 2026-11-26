import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/document_template_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/billing_provider.dart';
import 'template_designer_dialog.dart';

class DocumentTemplatesTab extends StatefulWidget {
  const DocumentTemplatesTab({super.key});

  @override
  State<DocumentTemplatesTab> createState() => _DocumentTemplatesTabState();
}

class _DocumentTemplatesTabState extends State<DocumentTemplatesTab> {
  String _selectedType = 'QUOTATION';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BillingProvider>().fetchTemplates();
    });
  }

  Color _parseHex(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      if (clean.length == 6) return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {}
    return const Color(0xFF1E3A8A);
  }

  @override
  Widget build(BuildContext context) {
    final bp = context.watch<BillingProvider>();
    final canManage = context.watch<AuthProvider>().currentUser?.hasPermission('templates.manage') ?? false;
    final list = bp.templatesForType(_selectedType);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'QUOTATION', label: Text('Quotations'), icon: Icon(Icons.request_quote_outlined, size: 16)),
                ButtonSegment(value: 'INVOICE', label: Text('Bills / Invoices'), icon: Icon(Icons.receipt_long_outlined, size: 16)),
                ButtonSegment(value: 'RECEIPT', label: Text('Receipt Vouchers'), icon: Icon(Icons.verified_outlined, size: 16)),
              ],
              selected: {_selectedType},
              onSelectionChanged: (s) => setState(() => _selectedType = s.first),
            ),
            if (canManage)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.design_services_rounded, size: 17),
                label: Text('Design New Template', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TemplateDesignerDialog(initialDocType: _selectedType),
                    ),
                  );
                },
              ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: list.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.style_outlined, size: 48, color: Color(0xFF94A3B8)),
                      const SizedBox(height: 10),
                      Text(
                        'No custom $_selectedType templates yet.',
                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF334155)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Create multiple templates with custom colors, drag-and-drop sections, and stamp placement.',
                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 340,
                    mainAxisExtent: 200,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                  ),
                  itemCount: list.length,
                  itemBuilder: (ctx, i) {
                    final tpl = list[i];
                    final themeColor = _parseHex(tpl.layout.primaryColorHex);
                    final visibleCount = tpl.layout.blocks.where((b) => b.visible).length;

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: tpl.isDefault ? themeColor : const Color(0xFFE2E8F0),
                          width: tpl.isDefault ? 2 : 1,
                        ),
                        boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 10, offset: Offset(0, 4))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(color: themeColor, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  tpl.name,
                                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (tpl.isDefault)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: themeColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text('DEFAULT', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: themeColor)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  tpl.branchName.isNotEmpty ? tpl.branchName : 'All Branches',
                                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF334155)),
                                ),
                              ),
                              if (tpl.layout.useCanvasMode)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFECFDF5),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Custom Layout (${tpl.layout.canvasElements.length} layers)',
                                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF047857)),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            tpl.layout.useCanvasMode
                                ? 'Custom freeform A4 design'
                                : '$visibleCount active blocks · ${tpl.layout.customColumns.length} custom cols · Logo ${tpl.layout.logoPosition}',
                            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF475569)),
                          ),
                          if (tpl.layout.stamp.enabled)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Stamp: "${tpl.layout.stamp.label}"',
                                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: themeColor),
                              ),
                            ),
                          const Spacer(),
                          if (canManage)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (!tpl.isDefault)
                                  TextButton(
                                    onPressed: () => bp.setDefaultTemplate(tpl.id),
                                    child: Text('Set Default', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700)),
                                  ),
                                IconButton(
                                  tooltip: 'Duplicate',
                                  icon: const Icon(Icons.copy_rounded, size: 17, color: Color(0xFF475569)),
                                  onPressed: () {
                                    bp.createTemplate(
                                      name: '${tpl.name} (Copy)',
                                      docType: tpl.docType,
                                      layout: TemplateLayoutConfig.fromJson(tpl.layout.toJson(), docType: tpl.docType),
                                    );
                                  },
                                ),
                                IconButton(
                                  tooltip: 'Edit Design',
                                  icon: Icon(Icons.edit_rounded, size: 18, color: themeColor),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => TemplateDesignerDialog(templateToEdit: tpl),
                                      ),
                                    );
                                  },
                                ),
                                IconButton(
                                  tooltip: 'Delete',
                                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC2626)),
                                  onPressed: () => bp.deleteTemplate(tpl.id),
                                ),
                              ],
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

