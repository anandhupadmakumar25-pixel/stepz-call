import 'dart:convert';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/quotation_model.dart';
import '../../models/invoice_model.dart';
import '../../models/receipt_voucher_model.dart';
import '../../models/document_template_model.dart';
import '../../models/plan_model.dart';

class PdfInvoiceService {
  static pw.Page _buildCanvaPdfPage({
    required List<CanvasElement> elements,
    required Map<String, String> tags,
    required List<dynamic> items,
    required pw.MemoryImage? branchLogo,
  }) {
    String resolveTags(String raw) {
      var out = raw;
      tags.forEach((k, v) {
        out = out.replaceAll('{{$k}}', v);
      });
      return out;
    }

    String cellFor(dynamic item, String col, int rowIdx) {
      final Map<String, dynamic> m;
      if (item is Map) {
        m = Map<String, dynamic>.from(item);
      } else if (item is QuotationItemModel) {
        m = {
          'qty': item.quantity,
          'quantity': item.quantity,
          'description': item.isSectionTitle ? item.title : item.description,
          'name': item.isSectionTitle ? item.title : item.description,
          'item_code': item.itemCode,
          'code': item.itemCode,
          'unit_price': item.unitPrice,
          'rate': item.unitPrice,
          'cst': item.cst,
          'cost_price': item.costPrice,
          'gross_margin': item.grossMargin,
          'tax_percent': item.taxPercent,
          'total': item.total,
          'amount': item.total,
          ...item.customFields,
        };
      } else {
        m = <String, dynamic>{};
      }
      final c = col.toLowerCase().trim();
      if (c == 'sl. no' || c == 'sl no' || c == 'sr no' || c == 's.no' || c == '#') {
        return '${rowIdx + 1}';
      }
      if (c.contains('qty')) {
        final q = num.tryParse((m['qty'] ?? m['quantity'] ?? 1).toString()) ?? 1;
        return q == q.roundToDouble() ? q.toInt().toString() : q.toString();
      }
      if (c.contains('item name') || c.contains('description')) {
        return (m['description'] ?? m['name'] ?? '').toString();
      }
      if (c.contains('code') && !c.contains('hs')) {
        return (m['item_code'] ?? m['code'] ?? '').toString();
      }
      if (c.contains('category')) return (m['category'] ?? m['Category'] ?? '').toString();
      if (c.contains('hs')) return (m['hs_code'] ?? m['HS code'] ?? m['HS Code'] ?? '').toString();
      if (c == 'pkg') return (m['pkg'] ?? m['Pkg'] ?? '').toString();
      if (c.contains('origin')) return (m['origin'] ?? m['Origin'] ?? '').toString();
      if (c.contains('unit price') || c.contains('rate')) {
        final v = num.tryParse((m['unit_price'] ?? m['rate'] ?? 0).toString()) ?? 0;
        return v.toStringAsFixed(2);
      }
      if (c.contains('ex. tax') || c.contains('subtotal')) {
        final q = num.tryParse((m['qty'] ?? m['quantity'] ?? 1).toString()) ?? 1;
        final r = num.tryParse((m['unit_price'] ?? m['rate'] ?? 0).toString()) ?? 0;
        return (q * r).toStringAsFixed(2);
      }
      if (c.contains('vat%') || c.contains('tax%')) {
        final t = num.tryParse((m['tax_percent'] ?? 0).toString()) ?? 0;
        return t.toStringAsFixed(0);
      }
      if (c == 'vat' || c == 'tax') {
        final q = num.tryParse((m['qty'] ?? m['quantity'] ?? 1).toString()) ?? 1;
        final r = num.tryParse((m['unit_price'] ?? m['rate'] ?? 0).toString()) ?? 0;
        final t = num.tryParse((m['tax_percent'] ?? 0).toString()) ?? 0;
        return ((q * r) * (t / 100)).toStringAsFixed(2);
      }
      if (c == 'cst' || c == 'cost' || c == 'cost price') {
        final v = num.tryParse((m['cst'] ?? m['cost_price'] ?? 0).toString()) ?? 0;
        return v.toStringAsFixed(2);
      }
      if (c.contains('margin')) {
        final v = num.tryParse((m['gross_margin'] ?? 0).toString()) ?? 0;
        return v.toStringAsFixed(2);
      }
      if (c.contains('total') || c.contains('amount')) {
        final q = num.tryParse((m['qty'] ?? m['quantity'] ?? 1).toString()) ?? 1;
        final r = num.tryParse((m['unit_price'] ?? m['rate'] ?? 0).toString()) ?? 0;
        final t = num.tryParse((m['tax_percent'] ?? 0).toString()) ?? 0;
        final stored = num.tryParse((m['total'] ?? m['amount'] ?? 0).toString()) ?? 0;
        final val = stored > 0 ? stored : (q * r * (1 + t / 100));
        return val.toStringAsFixed(2);
      }
      return (m[col] ?? m.entries.where((e) => e.key.toLowerCase().trim() == c).firstOrNull?.value ?? '').toString();
    }

    final tableEl = elements.where((e) => e.type == 'table').firstOrNull;
    final double actualTableH = 22.0 + (items.isEmpty ? 1 : items.length) * 20.0 + 20.0;
    final double deltaY = tableEl != null ? (actualTableH - tableEl.h) : 0.0;

    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      build: (ctx) {
        return pw.Stack(
          children: elements.map((el) {
            final isBelowTable = tableEl != null && el.id != tableEl.id && el.y >= (tableEl.y + tableEl.h - 12);
            final double effY = isBelowTable ? (el.y + deltaY).clamp(0.0, 810.0) : el.y;
            final fg = _pdfColorFromHex(el.colorHex, PdfColors.blueGrey900);
            final hasBg = el.bgColorHex.isNotEmpty;
            final bg = hasBg ? _pdfColorFromHex(el.bgColorHex, PdfColors.white) : null;
            final hasBorder = el.borderWidth > 0 && el.borderColorHex.isNotEmpty;
            final borderColor = _pdfColorFromHex(el.borderColorHex, PdfColors.grey700);

            pw.Widget child;
            if (el.type == 'line') {
              child = pw.Container(
                width: el.w,
                height: el.borderWidth > 0 ? el.borderWidth : 1.0,
                color: fg,
              );
            } else if (el.type == 'box') {
              child = pw.Container(
                width: el.w,
                height: el.h,
                decoration: pw.BoxDecoration(
                  color: bg,
                  border: hasBorder ? pw.Border.all(color: borderColor, width: el.borderWidth) : null,
                ),
              );
            } else if (el.type == 'image') {
              final img = el.imageSource == '{{branch_logo}}'
                  ? branchLogo
                  : (_decodeLogo(el.imageSource) ?? branchLogo);
              child = img != null ? pw.Image(img, fit: pw.BoxFit.contain) : pw.SizedBox();
            } else if (el.type == 'table') {
              final cols = el.tableColumns.isEmpty ? ['Qty', 'Item Name', 'Unit price', 'Total'] : el.tableColumns;
              final headerBg = el.bgColorHex.isNotEmpty
                  ? _pdfColorFromHex(el.bgColorHex, PdfColors.grey300)
                  : PdfColors.grey300;
              child = pw.Table(
                border: pw.TableBorder.all(color: borderColor, width: 0.6),
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: headerBg),
                    children: cols
                        .map((c) => pw.Padding(
                              padding: const pw.EdgeInsets.all(4),
                              child: pw.Text(
                                c,
                                style: pw.TextStyle(fontSize: el.fontSize, fontWeight: pw.FontWeight.bold, color: fg),
                                textAlign: pw.TextAlign.center,
                              ),
                            ))
                        .toList(),
                  ),
                  ...items.asMap().entries.map((entry) => pw.TableRow(
                        children: cols
                            .map((c) => pw.Padding(
                                  padding: const pw.EdgeInsets.all(4),
                                  child: pw.Text(
                                    cellFor(entry.value, c, entry.key),
                                    style: pw.TextStyle(fontSize: el.fontSize),
                                  ),
                                ))
                            .toList(),
                      )),
                ],
              );
            } else {
              final align = el.align == 'center'
                  ? pw.TextAlign.center
                  : (el.align == 'right' ? pw.TextAlign.right : pw.TextAlign.left);
              child = pw.Container(
                width: el.w,
                height: el.h,
                decoration: pw.BoxDecoration(
                  color: bg,
                  border: hasBorder ? pw.Border.all(color: borderColor, width: el.borderWidth) : null,
                ),
                child: pw.Text(
                  resolveTags(el.text),
                  textAlign: align,
                  style: pw.TextStyle(
                    fontSize: el.fontSize,
                    fontWeight: el.bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                    fontStyle: el.italic ? pw.FontStyle.italic : pw.FontStyle.normal,
                    color: fg,
                  ),
                ),
              );
            }

            return pw.Positioned(
              left: el.x,
              top: effY,
              child: el.type == 'table'
                  ? pw.SizedBox(width: el.w, child: child)
                  : pw.SizedBox(width: el.w, height: el.h, child: child),
            );
          }).toList(),
        );
      },
    );
  }

  static PdfColor _pdfColorFromHex(String? hex, PdfColor fallback) {
    if (hex == null || hex.isEmpty) return fallback;
    try {
      final clean = hex.replaceAll('#', '');
      if (clean.length == 6) {
        return PdfColor.fromInt(int.parse('FF$clean', radix: 16));
      }
    } catch (_) {}
    return fallback;
  }
  static pw.MemoryImage? _decodeLogo(String? logo) {
    if (logo == null || logo.trim().isEmpty) return null;
    try {
      String clean = logo.trim();
      if (clean.contains(',')) {
        clean = clean.split(',').last.trim();
      }
      final bytes = base64Decode(clean);
      if (bytes.isNotEmpty) {
        return pw.MemoryImage(bytes);
      }
    } catch (_) {}
    return null;
  }

  static Future<Uint8List> generateQuotationPdf(
    QuotationModel quotation, {
    String companyName = 'Stepz Telecaller CRM',
    String? companyPhone,
    String? companyEmail,
    String? companyAddress,
    String? companyGstin,
    String? companyWebsite,
    String? companyLogo,
    bool includeCst = false,
  }) async {
    final pdf = pw.Document();
    final curr = quotation.currency.isNotEmpty ? quotation.currency : 'INR';
    final hasCustomTpl = quotation.templateSnapshot.isNotEmpty;
    final tpl = TemplateLayoutConfig.fromJson(quotation.templateSnapshot, docType: 'QUOTATION');
    final logoImage = _decodeLogo(tpl.logoOverride.trim().isNotEmpty ? tpl.logoOverride : companyLogo);
    final tplColor = _pdfColorFromHex(tpl.primaryColorHex, PdfColors.indigo800);
    final tplAccent = _pdfColorFromHex(tpl.accentColorHex, PdfColors.green800);
    final borderRadius = tpl.borderStyle == 'rounded' ? 10.0 : 4.0;
    final hasPageBorder = hasCustomTpl && tpl.borderStyle != 'none';

    if (tpl.useCanvasMode && tpl.canvasElements.isNotEmpty) {
      final tags = <String, String>{
        'doc_number': quotation.quotationNumber,
        'date': quotation.date,
        'client_po': quotation.clientCode,
        'incoterms': quotation.incoterms,
        'currency': curr,
        'delivery_address': quotation.location,
        'company_trn': companyGstin ?? '',
        'customer_name': quotation.customerName,
        'customer_address': quotation.customerAddress,
        'contact_person': quotation.contactPerson,
        'customer_phone': quotation.customerPhone,
        'customer_trn': quotation.crNumber,
        'subtotal': quotation.subtotal.toStringAsFixed(2),
        'tax_amount': quotation.taxAmount.toStringAsFixed(2),
        'extra_charge': '0.00',
        'grand_total': quotation.grandTotal.toStringAsFixed(2),
        'amount_in_words': '',
        'vat_in_words': '',
        'bank_details': tpl.bankDetailsText,
        'terms': quotation.termsAndConditions.isNotEmpty
            ? quotation.termsAndConditions
            : tpl.termsAndConditions,
        'branch_name': companyName,
        'branch_address': companyAddress ?? '',
        'branch_email': companyEmail ?? '',
        'branch_phone': companyPhone ?? '',
        'sales_rep_name': quotation.salesRepName.isNotEmpty ? quotation.salesRepName : quotation.createdByName,
        'sales_rep_phone': quotation.createdByPhone.isNotEmpty ? quotation.createdByPhone : (companyPhone ?? ''),
      };
      pdf.addPage(_buildCanvaPdfPage(
        elements: tpl.canvasElements,
        tags: tags,
        items: quotation.items,
        branchLogo: logoImage,
      ));
      return pdf.save();
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (logoImage != null) ...[
                          pw.Container(
                            width: 52,
                            height: 52,
                            margin: const pw.EdgeInsets.only(right: 12),
                            decoration: pw.BoxDecoration(
                              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                              border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                            ),
                            child: pw.ClipRRect(
                              horizontalRadius: 8,
                              verticalRadius: 8,
                              child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                            ),
                          ),
                        ],
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                companyName,
                                style: pw.TextStyle(
                                  fontSize: 18,
                                  fontWeight: pw.FontWeight.bold,
                                  color: tplColor,
                                ),
                              ),
                              if (companyGstin != null && companyGstin.isNotEmpty) ...[
                                pw.SizedBox(height: 2),
                                pw.Text(
                                  '${curr == 'INR' ? 'GSTIN' : 'TRN / Tax ID'}: $companyGstin',
                                  style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo800),
                                ),
                              ],
                              if (companyAddress != null && companyAddress.isNotEmpty) ...[
                                pw.SizedBox(height: 2),
                                pw.Text(companyAddress, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                              ],
                              pw.SizedBox(height: 2),
                              pw.Row(
                                children: [
                                  if (companyPhone != null && companyPhone.isNotEmpty)
                                    pw.Text('Phone: $companyPhone   ', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
                                  if (companyEmail != null && companyEmail.isNotEmpty)
                                    pw.Text('Email: $companyEmail', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
                                ],
                              ),
                              if (companyWebsite != null && companyWebsite.isNotEmpty) ...[
                                pw.SizedBox(height: 1),
                                pw.Text(companyWebsite, style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.indigo700)),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 16),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: pw.BoxDecoration(
                          color: includeCst ? PdfColors.amber50 : tplColor,
                          borderRadius: pw.BorderRadius.all(pw.Radius.circular(borderRadius)),
                          border: pw.Border.all(color: includeCst ? PdfColors.amber300 : tplColor),
                        ),
                        child: pw.Text(
                          includeCst
                              ? 'INTERNAL CST & MARGIN QUOTATION'
                              : (tpl.titleOverride.isNotEmpty ? tpl.titleOverride.toUpperCase() : 'SALES QUOTATION'),
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: includeCst ? PdfColors.amber900 : PdfColors.white,
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text('Quote #: ${quotation.quotationNumber}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                      pw.Text('Date: ${quotation.date}', style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey700)),
                      if (quotation.validUntil != null && quotation.validUntil!.isNotEmpty)
                        pw.Text('Valid Until: ${quotation.validUntil}', style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey700)),
                    ],
                  ),
                ],
              ),
              pw.Divider(color: tplColor, thickness: 1.5, height: 22),

              // Customer Info
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('QUOTATION FOR:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
                      pw.SizedBox(height: 4),
                      pw.Text(quotation.customerName, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                      if (quotation.customerPhone.isNotEmpty)
                        pw.Text('Phone: ${quotation.customerPhone}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
                      if (quotation.customerEmail.isNotEmpty)
                        pw.Text('Email: ${quotation.customerEmail}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
                      if (quotation.customerAddress.isNotEmpty)
                        pw.Text(quotation.customerAddress, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      if (tpl.filledFields.isNotEmpty) ...[
                        pw.SizedBox(height: 4),
                        ...tpl.filledFields.entries.map((e) => pw.Text(
                              '${e.key}: ${e.value}',
                              style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: tplColor),
                            )),
                      ],
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('PREPARED BY:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
                      pw.SizedBox(height: 4),
                      pw.Text(quotation.createdByName.isNotEmpty ? quotation.createdByName : 'Sales Team', style: const pw.TextStyle(fontSize: 11)),
                      pw.Text('Status: ${quotation.status}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo700)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // Line Items Table with Custom Columns & Section Titles
              () {
                final customCols = quotation.customColumns;
                final showQty = quotation.showQty;
                final showPrice = quotation.showPrice;
                final showTax = quotation.showTax;

                final Map<int, pw.TableColumnWidth> colWidths = {
                  0: const pw.FixedColumnWidth(22),
                  1: const pw.FlexColumnWidth(3.0),
                };
                final hasItemCode = quotation.items.any((i) => i.itemCode.trim().isNotEmpty);
                int cIdx = 2;
                if (hasItemCode) colWidths[cIdx++] = const pw.FixedColumnWidth(58); // Item Code
                for (int i = 0; i < customCols.length; i++) {
                  colWidths[cIdx++] = const pw.FlexColumnWidth(1.3);
                }
                if (showQty) colWidths[cIdx++] = const pw.FixedColumnWidth(38);
                if (includeCst) {
                  colWidths[cIdx++] = const pw.FixedColumnWidth(44); // CST
                  colWidths[cIdx++] = const pw.FixedColumnWidth(50); // SUM Cost
                }
                if (showPrice) colWidths[cIdx++] = const pw.FixedColumnWidth(52);
                if (showTax && !includeCst) colWidths[cIdx++] = const pw.FixedColumnWidth(40);
                colWidths[cIdx++] = const pw.FixedColumnWidth(58); // Total
                if (includeCst) {
                  colWidths[cIdx++] = const pw.FixedColumnWidth(48); // Margin
                }

                return pw.Table(
                  border: pw.TableBorder(
                    horizontalInside: const pw.BorderSide(color: PdfColors.grey200, width: 0.5),
                    bottom: const pw.BorderSide(color: PdfColors.grey300, width: 1),
                  ),
                  columnWidths: colWidths,
                  children: [
                    // Table Header
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: includeCst ? PdfColors.amber50 : tplColor),
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('#', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5, color: includeCst ? PdfColors.black : PdfColors.white))),
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Item Description', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5, color: includeCst ? PdfColors.black : PdfColors.white))),
                        if (hasItemCode)
                          pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Item Code', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5, color: includeCst ? PdfColors.black : PdfColors.white))),
                        for (final col in customCols)
                          pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(col, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5, color: includeCst ? PdfColors.black : PdfColors.white))),
                        if (showQty)
                          pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Qty', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5, color: includeCst ? PdfColors.black : PdfColors.white))),
                        if (includeCst) ...[
                          pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('CST', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5, color: PdfColors.amber900))),
                          pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('SUM', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5, color: PdfColors.amber900))),
                        ],
                        if (showPrice)
                          pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Rate', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5, color: includeCst ? PdfColors.black : PdfColors.white))),
                        if (showTax && !includeCst)
                          pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Tax %', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5, color: PdfColors.white))),
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Total', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5, color: includeCst ? PdfColors.black : PdfColors.white))),
                        if (includeCst)
                          pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Margin', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5, color: PdfColors.green900))),
                      ],
                    ),
                    // Items & Section Title Rows
                    ...quotation.items.asMap().entries.map((entry) {
                      final idx = entry.key + 1;
                      final item = entry.value;

                      if (item.isSectionTitle) {
                        final titleText = item.title.isNotEmpty ? item.title : item.description;
                        final emptyCount = colWidths.length - 2;
                        return pw.TableRow(
                          decoration: const pw.BoxDecoration(color: PdfColors.amber50),
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(5),
                              child: pw.Center(
                                child: pw.Container(
                                  width: 4,
                                  height: 4,
                                  decoration: const pw.BoxDecoration(color: PdfColors.amber900, shape: pw.BoxShape.circle),
                                ),
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(5),
                              child: pw.Text(
                                titleText.toUpperCase(),
                                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.amber900),
                              ),
                            ),
                            for (int k = 0; k < emptyCount; k++)
                              pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('')),
                          ],
                        );
                      }

                      final costSum = item.costPrice * item.quantity;
                      final grossProfit = item.total - costSum;

                      return pw.TableRow(
                        children: [
                          pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('$idx', style: const pw.TextStyle(fontSize: 8))),
                          pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(item.description, style: const pw.TextStyle(fontSize: 8.5))),
                          if (hasItemCode)
                            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(item.itemCode.isNotEmpty ? item.itemCode : '-', style: const pw.TextStyle(fontSize: 8))),
                          for (final col in customCols)
                            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(item.customFields[col] ?? '-', style: const pw.TextStyle(fontSize: 8))),
                          if (showQty)
                            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(item.quantity.toStringAsFixed(item.quantity.truncateToDouble() == item.quantity ? 0 : 2), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8))),
                          if (includeCst) ...[
                            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(item.costPrice.toStringAsFixed(2), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800))),
                            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(costSum.toStringAsFixed(2), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800))),
                          ],
                          if (showPrice)
                            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('$curr ${item.unitPrice.toStringAsFixed(2)}', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8))),
                          if (showTax && !includeCst)
                            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('${item.taxPercent}%', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8))),
                          pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('$curr ${item.total.toStringAsFixed(2)}', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                          if (includeCst)
                            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(grossProfit.toStringAsFixed(2), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: grossProfit >= 0 ? PdfColors.green800 : PdfColors.red800))),
                        ],
                      );
                    }),
                  ],
                );
              }(),
              pw.SizedBox(height: 16),

              // Totals Block
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Terms / Notes
                  pw.Expanded(
                    flex: 6,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (quotation.notes.isNotEmpty) ...[
                          pw.Text('Notes:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                          pw.Text(quotation.notes, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                          pw.SizedBox(height: 8),
                        ],
                        if (quotation.termsAndConditions.isNotEmpty) ...[
                          pw.Text('Terms & Conditions:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                          pw.Text(quotation.termsAndConditions, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                        ],
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 24),
                  // Calculation
                  pw.Expanded(
                    flex: 4,
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey100,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                      ),
                      child: pw.Column(
                        children: [
                          _buildPdfAmountRow('Subtotal', '$curr ${quotation.subtotal.toStringAsFixed(2)}'),
                          if (includeCst) ...[
                            _buildPdfAmountRow('Total Cost (CST Sum)', '$curr ${quotation.totalCost.toStringAsFixed(2)}', textColor: PdfColors.amber900),
                            _buildPdfAmountRow(
                              'Gross Profit',
                              '$curr ${quotation.grossMargin.toStringAsFixed(2)} (${quotation.subtotal > 0 ? ((quotation.grossMargin / quotation.subtotal) * 100).toStringAsFixed(1) : 0}%)',
                              textColor: PdfColors.green800,
                              isBold: true,
                            ),
                          ],
                          if (quotation.discountAmount > 0)
                            _buildPdfAmountRow('Discount', '-$curr ${quotation.discountAmount.toStringAsFixed(2)}', textColor: PdfColors.red700),
                          if (quotation.taxAmount > 0)
                            _buildPdfAmountRow('Tax / GST', '$curr ${quotation.taxAmount.toStringAsFixed(2)}'),
                          pw.Divider(color: PdfColors.grey400, thickness: 0.5, height: 12),
                          _buildPdfAmountRow(
                            'Grand Total',
                            '$curr ${quotation.grandTotal.toStringAsFixed(2)}',
                            isBold: true,
                            fontSize: 12,
                            textColor: tplColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (tpl.bankDetailsText.isNotEmpty) ...[
                pw.SizedBox(height: 12),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey50,
                    border: pw.Border.all(color: tplColor, width: 0.7),
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(borderRadius)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('BANK / PAYMENT DETAILS', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: tplColor)),
                      pw.SizedBox(height: 3),
                      pw.Text(tpl.bankDetailsText, style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey800)),
                    ],
                  ),
                ),
              ],
              if (hasPageBorder)
                pw.Container(
                  margin: const pw.EdgeInsets.only(top: 8),
                  height: 2,
                  color: tplAccent,
                ),
              pw.Spacer(),

              // Footer
              pw.Center(
                child: pw.Text(
                  'Thank you for your business! This quotation is valid for 15 days from issue date.',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static Future<Uint8List> generateInvoicePdf(
    InvoiceModel invoice, {
    String companyName = 'Stepz Telecaller CRM',
    String? companyPhone,
    String? companyEmail,
    String? companyAddress,
    String? companyGstin,
    String? companyWebsite,
    String? companyLogo,
  }) async {
    final pdf = pw.Document();
    final curr = invoice.currency.isNotEmpty ? invoice.currency : 'INR';
    final tpl = TemplateLayoutConfig.fromJson(invoice.templateSnapshot, docType: 'INVOICE');
    final logoImage = _decodeLogo(tpl.logoOverride.trim().isNotEmpty ? tpl.logoOverride : companyLogo);
    final tplColor = _pdfColorFromHex(tpl.primaryColorHex, PdfColors.indigo800);
    final borderRadius = tpl.borderStyle == 'rounded' ? 10.0 : 4.0;

    if (tpl.useCanvasMode && tpl.canvasElements.isNotEmpty) {
      final tags = <String, String>{
        'doc_number': invoice.invoiceNumber,
        'date': invoice.date,
        'client_po': invoice.clientCode,
        'incoterms': invoice.incoterms,
        'currency': curr,
        'delivery_address': invoice.location,
        'company_trn': companyGstin ?? '',
        'customer_name': invoice.customerName,
        'customer_address': invoice.customerAddress,
        'contact_person': invoice.contactPerson,
        'customer_phone': invoice.customerPhone,
        'customer_trn': invoice.crNumber,
        'subtotal': invoice.subtotal.toStringAsFixed(2),
        'tax_amount': invoice.taxAmount.toStringAsFixed(2),
        'extra_charge': '0.00',
        'grand_total': invoice.grandTotal.toStringAsFixed(2),
        'amount_in_words': invoice.amountInWordsEn,
        'vat_in_words': '',
        'bank_details': tpl.bankDetailsText,
        'terms': invoice.termsAndConditions.isNotEmpty
            ? invoice.termsAndConditions
            : tpl.termsAndConditions,
        'branch_name': companyName,
        'branch_address': companyAddress ?? '',
        'branch_email': companyEmail ?? '',
        'branch_phone': companyPhone ?? '',
        'sales_rep_name': invoice.salesRepName.isNotEmpty ? invoice.salesRepName : invoice.createdByName,
        'sales_rep_phone': invoice.createdByPhone.isNotEmpty ? invoice.createdByPhone : (companyPhone ?? ''),
      };
      pdf.addPage(_buildCanvaPdfPage(
        elements: tpl.canvasElements,
        tags: tags,
        items: invoice.items,
        branchLogo: logoImage,
      ));
      return pdf.save();
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          final isPaid = invoice.paymentStatus == 'PAID';
          final isPartial = invoice.paymentStatus == 'PARTIAL';
          final statusColor = isPaid
              ? PdfColors.green800
              : isPartial
                  ? PdfColors.orange800
                  : PdfColors.red800;

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (logoImage != null) ...[
                          pw.Container(
                            width: 52,
                            height: 52,
                            margin: const pw.EdgeInsets.only(right: 12),
                            decoration: pw.BoxDecoration(
                              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                              border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                            ),
                            child: pw.ClipRRect(
                              horizontalRadius: 8,
                              verticalRadius: 8,
                              child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                            ),
                          ),
                        ],
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                companyName,
                                style: pw.TextStyle(
                                  fontSize: 18,
                                  fontWeight: pw.FontWeight.bold,
                                  color: tplColor,
                                ),
                              ),
                              if (companyGstin != null && companyGstin.isNotEmpty) ...[
                                pw.SizedBox(height: 2),
                                pw.Text(
                                  '${curr == 'INR' ? 'GSTIN' : 'TRN / Tax ID'}: $companyGstin',
                                  style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo800),
                                ),
                              ],
                              if (companyAddress != null && companyAddress.isNotEmpty) ...[
                                pw.SizedBox(height: 2),
                                pw.Text(companyAddress, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                              ],
                              pw.SizedBox(height: 2),
                              pw.Row(
                                children: [
                                  if (companyPhone != null && companyPhone.isNotEmpty)
                                    pw.Text('Phone: $companyPhone   ', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
                                  if (companyEmail != null && companyEmail.isNotEmpty)
                                    pw.Text('Email: $companyEmail', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
                                ],
                              ),
                              if (companyWebsite != null && companyWebsite.isNotEmpty) ...[
                                pw.SizedBox(height: 1),
                                pw.Text(companyWebsite, style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.indigo700)),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 16),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: pw.BoxDecoration(
                          color: invoice.templateSnapshot.isNotEmpty ? tplColor : (isPaid ? PdfColors.green50 : PdfColors.amber50),
                          borderRadius: pw.BorderRadius.all(pw.Radius.circular(borderRadius)),
                          border: pw.Border.all(color: invoice.templateSnapshot.isNotEmpty ? tplColor : statusColor),
                        ),
                        child: pw.Text(
                          tpl.titleOverride.isNotEmpty ? tpl.titleOverride.toUpperCase() : 'TAX INVOICE (FIXED PRICE BILL)',
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: invoice.templateSnapshot.isNotEmpty ? PdfColors.white : statusColor,
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text('Invoice #: ${invoice.invoiceNumber}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                      pw.Text('Date: ${invoice.date}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      if (invoice.dueDate != null && invoice.dueDate!.isNotEmpty)
                        pw.Text('Due Date: ${invoice.dueDate}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      if (invoice.quotationNumber.isNotEmpty)
                        pw.Text('Ref Quote: ${invoice.quotationNumber}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                    ],
                  ),
                ],
              ),
              pw.Divider(color: tplColor, thickness: 1.5, height: 22),

              // Customer Info & Status
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('BILLED TO:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
                      pw.SizedBox(height: 4),
                      pw.Text(invoice.customerName, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                      if (invoice.customerPhone.isNotEmpty)
                        pw.Text('Phone: ${invoice.customerPhone}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
                      if (invoice.customerEmail.isNotEmpty)
                        pw.Text('Email: ${invoice.customerEmail}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
                      if (invoice.customerAddress.isNotEmpty)
                        pw.Text(invoice.customerAddress, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      if (tpl.filledFields.isNotEmpty) ...[
                        pw.SizedBox(height: 4),
                        ...tpl.filledFields.entries.map((e) => pw.Text(
                              '${e.key}: ${e.value}',
                              style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: tplColor),
                            )),
                      ],
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('PAYMENT STATUS:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
                      pw.SizedBox(height: 4),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: pw.BoxDecoration(
                          color: isPaid ? PdfColors.green100 : PdfColors.amber100,
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                        ),
                        child: pw.Text(
                          invoice.paymentStatus,
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ),
                      if (invoice.paymentMode.isNotEmpty)
                        pw.Text('Mode: ${invoice.paymentMode}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800)),
                      if (invoice.paymentReference.isNotEmpty)
                        pw.Text('Ref: ${invoice.paymentReference}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // Line Items Table with Custom Columns & Section Titles
              () {
                final customCols = invoice.customColumns;
                final showQty = invoice.showQty;
                final showPrice = invoice.showPrice;
                final showTax = invoice.showTax;

                final Map<int, pw.TableColumnWidth> colWidths = {
                  0: const pw.FixedColumnWidth(24),
                  1: const pw.FlexColumnWidth(3.0),
                };
                final hasItemCode = invoice.items.any((i) => i.itemCode.trim().isNotEmpty);
                int cIdx = 2;
                if (hasItemCode) colWidths[cIdx++] = const pw.FixedColumnWidth(58); // Item Code
                for (int i = 0; i < customCols.length; i++) {
                  colWidths[cIdx++] = const pw.FlexColumnWidth(1.4);
                }
                if (showQty) colWidths[cIdx++] = const pw.FixedColumnWidth(40);
                if (showPrice) colWidths[cIdx++] = const pw.FixedColumnWidth(60);
                if (showTax) colWidths[cIdx++] = const pw.FixedColumnWidth(44);
                colWidths[cIdx++] = const pw.FixedColumnWidth(65);

                return pw.Table(
                  border: pw.TableBorder(
                    horizontalInside: const pw.BorderSide(color: PdfColors.grey200, width: 0.5),
                    bottom: const pw.BorderSide(color: PdfColors.grey300, width: 1),
                  ),
                  columnWidths: colWidths,
                  children: [
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: invoice.templateSnapshot.isNotEmpty ? tplColor : PdfColors.indigo50),
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('#', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: invoice.templateSnapshot.isNotEmpty ? PdfColors.white : PdfColors.black))),
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Item Description', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: invoice.templateSnapshot.isNotEmpty ? PdfColors.white : PdfColors.black))),
                        if (hasItemCode)
                          pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Item Code', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: invoice.templateSnapshot.isNotEmpty ? PdfColors.white : PdfColors.black))),
                        for (final col in customCols)
                          pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(col, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: invoice.templateSnapshot.isNotEmpty ? PdfColors.white : PdfColors.black))),
                        if (showQty)
                          pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Qty', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: invoice.templateSnapshot.isNotEmpty ? PdfColors.white : PdfColors.black))),
                        if (showPrice)
                          pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Rate', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: invoice.templateSnapshot.isNotEmpty ? PdfColors.white : PdfColors.black))),
                        if (showTax)
                          pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Tax %', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: invoice.templateSnapshot.isNotEmpty ? PdfColors.white : PdfColors.black))),
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Total', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: invoice.templateSnapshot.isNotEmpty ? PdfColors.white : PdfColors.black))),
                      ],
                    ),
                    ...invoice.items.asMap().entries.map((entry) {
                      final idx = entry.key + 1;
                      final item = entry.value;

                      if (item.isSectionTitle) {
                        final titleText = item.title.isNotEmpty ? item.title : item.description;
                        final emptyCount = colWidths.length - 2;
                        return pw.TableRow(
                          decoration: const pw.BoxDecoration(color: PdfColors.amber50),
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(5),
                              child: pw.Center(
                                child: pw.Container(
                                  width: 4,
                                  height: 4,
                                  decoration: const pw.BoxDecoration(color: PdfColors.amber900, shape: pw.BoxShape.circle),
                                ),
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(5),
                              child: pw.Text(
                                titleText.toUpperCase(),
                                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.amber900),
                              ),
                            ),
                            for (int k = 0; k < emptyCount; k++)
                              pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('')),
                          ],
                        );
                      }

                      return pw.TableRow(
                        children: [
                          pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('$idx', style: const pw.TextStyle(fontSize: 8.5))),
                          pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(item.description, style: const pw.TextStyle(fontSize: 9))),
                          if (hasItemCode)
                            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(item.itemCode.isNotEmpty ? item.itemCode : '-', style: const pw.TextStyle(fontSize: 8.5))),
                          for (final col in customCols)
                            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(item.customFields[col] ?? '-', style: const pw.TextStyle(fontSize: 8.5))),
                          if (showQty)
                            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(item.quantity.toStringAsFixed(item.quantity.truncateToDouble() == item.quantity ? 0 : 2), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8.5))),
                          if (showPrice)
                            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('$curr ${item.unitPrice.toStringAsFixed(2)}', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8.5))),
                          if (showTax)
                            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('${item.taxPercent}%', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8.5))),
                          pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('$curr ${item.total.toStringAsFixed(2)}', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold))),
                        ],
                      );
                    }),
                  ],
                );
              }(),
              pw.SizedBox(height: 16),

              // Totals & Payment Balance
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    flex: 6,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (invoice.paymentNotes.isNotEmpty) ...[
                          pw.Text('Payment History / Notes:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                          pw.Text(invoice.paymentNotes, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                          pw.SizedBox(height: 8),
                        ],
                        if (invoice.termsAndConditions.isNotEmpty) ...[
                          pw.Text('Terms & Conditions:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                          pw.Text(invoice.termsAndConditions, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                        ],
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 24),
                  pw.Expanded(
                    flex: 4,
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey100,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                      ),
                      child: pw.Column(
                        children: [
                          _buildPdfAmountRow('Fixed Subtotal', '$curr ${invoice.subtotal.toStringAsFixed(2)}'),
                          if (invoice.discountAmount > 0)
                            _buildPdfAmountRow('Discount', '-$curr ${invoice.discountAmount.toStringAsFixed(2)}', textColor: PdfColors.red700),
                          if (invoice.taxAmount > 0)
                            _buildPdfAmountRow('Tax / GST', '$curr ${invoice.taxAmount.toStringAsFixed(2)}'),
                          pw.Divider(color: PdfColors.grey400, thickness: 0.5, height: 10),
                          _buildPdfAmountRow(
                            'Grand Total',
                            '$curr ${invoice.grandTotal.toStringAsFixed(2)}',
                            isBold: true,
                            fontSize: 11,
                            textColor: invoice.templateSnapshot.isNotEmpty ? tplColor : PdfColors.indigo900,
                          ),
                          _buildPdfAmountRow(
                            'Amount Paid',
                            '$curr ${invoice.amountPaid.toStringAsFixed(2)}',
                            fontSize: 10,
                            textColor: PdfColors.green800,
                          ),
                          pw.Divider(color: PdfColors.grey400, thickness: 0.5, height: 10),
                          _buildPdfAmountRow(
                            'Balance Due',
                            '$curr ${invoice.balanceDue.toStringAsFixed(2)}',
                            isBold: true,
                            fontSize: 12,
                            textColor: invoice.balanceDue > 0 ? PdfColors.red800 : PdfColors.green800,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (tpl.bankDetailsText.isNotEmpty) ...[
                pw.SizedBox(height: 12),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey50,
                    border: pw.Border.all(color: tplColor, width: 0.7),
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(borderRadius)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('BANK / PAYMENT DETAILS', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: tplColor)),
                      pw.SizedBox(height: 3),
                      pw.Text(tpl.bankDetailsText, style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey800)),
                    ],
                  ),
                ),
              ],
              if (invoice.templateSnapshot.isNotEmpty && tpl.borderStyle != 'none')
                pw.Container(
                  margin: const pw.EdgeInsets.only(top: 8),
                  height: 2,
                  color: tplColor,
                ),
              pw.Spacer(),

              // Footer
              pw.Center(
                child: pw.Text(
                  'Thank you for your payment! This is an official system generated tax invoice.',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildPdfAmountRow(
    String label,
    String value, {
    bool isBold = false,
    double fontSize = 9,
    PdfColor? textColor,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: textColor ?? PdfColors.grey800,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: textColor ?? PdfColors.grey900,
            ),
          ),
        ],
      ),
    );
  }

  /// Print or preview quotation
  static Future<void> printQuotation(
    QuotationModel quotation, {
    String companyName = 'Stepz Telecaller CRM',
    String? companyPhone,
    String? companyEmail,
    String? companyAddress,
    String? companyGstin,
    String? companyWebsite,
    String? companyLogo,
    bool includeCst = false,
  }) async {
    await Printing.layoutPdf(
      onLayout: (format) async => await generateQuotationPdf(
        quotation,
        companyName: companyName,
        companyPhone: companyPhone,
        companyEmail: companyEmail,
        companyAddress: companyAddress,
        companyGstin: companyGstin,
        companyWebsite: companyWebsite,
        companyLogo: companyLogo,
        includeCst: includeCst,
      ),
      name: '${quotation.quotationNumber}${includeCst ? '_INTERNAL_CST' : ''}.pdf',
    );
  }

  /// Share quotation PDF file
  static Future<void> shareQuotationPdf(
    QuotationModel quotation, {
    String companyName = 'Stepz Telecaller CRM',
    String? companyPhone,
    String? companyEmail,
    String? companyAddress,
    String? companyGstin,
    String? companyWebsite,
    String? companyLogo,
    bool includeCst = false,
  }) async {
    final bytes = await generateQuotationPdf(
      quotation,
      companyName: companyName,
      companyPhone: companyPhone,
      companyEmail: companyEmail,
      companyAddress: companyAddress,
      companyGstin: companyGstin,
      companyWebsite: companyWebsite,
      companyLogo: companyLogo,
      includeCst: includeCst,
    );
    await Printing.sharePdf(bytes: bytes, filename: '${quotation.quotationNumber}${includeCst ? '_INTERNAL_CST' : ''}.pdf');
  }

  /// Print or preview invoice
  static Future<void> printInvoice(
    InvoiceModel invoice, {
    String companyName = 'Stepz Telecaller CRM',
    String? companyPhone,
    String? companyEmail,
    String? companyAddress,
    String? companyGstin,
    String? companyWebsite,
    String? companyLogo,
  }) async {
    await Printing.layoutPdf(
      onLayout: (format) async => await generateInvoicePdf(
        invoice,
        companyName: companyName,
        companyPhone: companyPhone,
        companyEmail: companyEmail,
        companyAddress: companyAddress,
        companyGstin: companyGstin,
        companyWebsite: companyWebsite,
        companyLogo: companyLogo,
      ),
      name: '${invoice.invoiceNumber}.pdf',
    );
  }

  /// Share invoice PDF file
  static Future<void> shareInvoicePdf(
    InvoiceModel invoice, {
    String companyName = 'Stepz Telecaller CRM',
    String? companyPhone,
    String? companyEmail,
    String? companyAddress,
    String? companyGstin,
    String? companyWebsite,
    String? companyLogo,
  }) async {
    final bytes = await generateInvoicePdf(
      invoice,
      companyName: companyName,
      companyPhone: companyPhone,
      companyEmail: companyEmail,
      companyAddress: companyAddress,
      companyGstin: companyGstin,
      companyWebsite: companyWebsite,
      companyLogo: companyLogo,
    );
    await Printing.sharePdf(bytes: bytes, filename: '${invoice.invoiceNumber}.pdf');
  }

  /// Launch WhatsApp with pre-filled message for Quotation
  static Future<bool> shareQuotationToWhatsApp(
    QuotationModel quotation, {
    String companyName = 'Stepz Telecaller CRM',
    String defaultCountryCode = '+91',
  }) async {
    final cleanPhone = quotation.customerPhone.replaceAll(RegExp(r'[^0-9]'), '');
    final dialPrefix = defaultCountryCode.replaceAll(RegExp(r'[^0-9]'), '');
    final phoneToUse = cleanPhone.length <= 10 && dialPrefix.isNotEmpty && !cleanPhone.startsWith(dialPrefix)
        ? '$dialPrefix$cleanPhone'
        : cleanPhone;

    final currSym = PlanModel.getSymbolForCurrency(quotation.currency);
    final itemsSummary = quotation.items.map((i) => '• ${i.description} (x${i.quantity}): $currSym ${i.total.toStringAsFixed(2)}').join('\n');

    final message = '''Hello ${quotation.customerName},

Greetings from *$companyName*!

We are pleased to share your Sales Quotation *${quotation.quotationNumber}* dated ${quotation.date}:

*Items / Services:*
$itemsSummary

*Subtotal:* $currSym ${quotation.subtotal.toStringAsFixed(2)}
${quotation.discountAmount > 0 ? '*Discount:* -$currSym ${quotation.discountAmount.toStringAsFixed(2)}\n' : ''}*Tax / GST:* $currSym ${quotation.taxAmount.toStringAsFixed(2)}
*Total Amount:* $currSym ${quotation.grandTotal.toStringAsFixed(2)}

${quotation.validUntil != null ? 'Valid until: ${quotation.validUntil}\n' : ''}Please let us know if you have any questions or would like to proceed.

Thank you!''';

    final uri = Uri.parse('https://wa.me/$phoneToUse?text=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return true;
    }
    return false;
  }

  /// Launch WhatsApp with pre-filled message for Invoice / Bill
  static Future<bool> shareInvoiceToWhatsApp(
    InvoiceModel invoice, {
    String companyName = 'Stepz Telecaller CRM',
    String defaultCountryCode = '+91',
  }) async {
    final cleanPhone = invoice.customerPhone.replaceAll(RegExp(r'[^0-9]'), '');
    final dialPrefix = defaultCountryCode.replaceAll(RegExp(r'[^0-9]'), '');
    final phoneToUse = cleanPhone.length <= 10 && dialPrefix.isNotEmpty && !cleanPhone.startsWith(dialPrefix)
        ? '$dialPrefix$cleanPhone'
        : cleanPhone;

    final currSym = PlanModel.getSymbolForCurrency(invoice.currency);
    final isPaid = invoice.paymentStatus == 'PAID';

    final message = '''Hello ${invoice.customerName},

Thank you for choosing *$companyName*!

Here are the details of your Fixed Price Bill / Tax Invoice *${invoice.invoiceNumber}*:

*Fixed Total Amount:* $currSym ${invoice.grandTotal.toStringAsFixed(2)} (Fixed Price)
*Amount Paid:* $currSym ${invoice.amountPaid.toStringAsFixed(2)}
*Balance Due:* $currSym ${invoice.balanceDue.toStringAsFixed(2)}
*Status:* ${invoice.paymentStatus} ${isPaid ? '✅' : '⏳'}
${invoice.paymentMode.isNotEmpty ? '*Payment Mode:* ${invoice.paymentMode}\n' : ''}${invoice.paymentReference.isNotEmpty ? '*Ref / Txn ID:* ${invoice.paymentReference}\n' : ''}
${invoice.balanceDue > 0 ? 'Please complete the remaining balance at your earliest convenience.\n' : 'We have received your payment in full. Thank you!\n'}
For any support, feel free to reply directly to this message.''';

    final uri = Uri.parse('https://wa.me/$phoneToUse?text=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return true;
    }
    return false;
  }

  /// Generate luxury bilingual Receipt Voucher PDF (سند قبض)
  static Future<Uint8List> generateReceiptVoucherPdf(
    ReceiptVoucherModel voucher, {
    String companyName = 'Nine Stars Perfumes Trading L L C SP',
    String? companyPhone,
    String? companyEmail,
    String? companyAddress,
    String? companyGstin,
    String? companyWebsite,
    String? companyLogo,
  }) async {
    final pdf = pw.Document();
    final curr = voucher.currency.isNotEmpty ? voucher.currency : 'INR';
    final tpl = TemplateLayoutConfig.fromJson(voucher.templateSnapshot, docType: 'RECEIPT');
    final logoImage = _decodeLogo(tpl.logoOverride.trim().isNotEmpty ? tpl.logoOverride : companyLogo);
    final tplColor = _pdfColorFromHex(tpl.primaryColorHex, PdfColors.blue900);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // Main Outer Box with security border
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: tplColor, width: tpl.borderStyle == 'double' ? 2.5 : 1.5),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Stack(
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: [
                        // Header Row: Logo, Company info, Title & Number
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            if (logoImage != null)
                              pw.Container(
                                width: 60,
                                height: 60,
                                margin: const pw.EdgeInsets.only(right: 12),
                                child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                              ),
                            pw.Expanded(
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text(
                                    companyName.toUpperCase(),
                                    style: pw.TextStyle(
                                      fontSize: 15,
                                      fontWeight: pw.FontWeight.bold,
                                      color: tplColor,
                                    ),
                                  ),
                                  if (companyAddress != null && companyAddress.isNotEmpty)
                                    pw.Text(companyAddress, style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
                                  pw.Row(
                                    children: [
                                      if (companyPhone != null && companyPhone.isNotEmpty)
                                        pw.Text('Mob: $companyPhone   ', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
                                      if (companyEmail != null && companyEmail.isNotEmpty)
                                        pw.Text('Email: $companyEmail', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
                                    ],
                                  ),
                                  if (companyGstin != null && companyGstin.isNotEmpty)
                                    pw.Text('CR / Reg: $companyGstin', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
                                ],
                              ),
                            ),
                            pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.end,
                              children: [
                                pw.Container(
                                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: pw.BoxDecoration(
                                    color: voucher.templateSnapshot.isNotEmpty ? tplColor : PdfColors.blue50,
                                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                                    border: pw.Border.all(color: tplColor, width: 1),
                                  ),
                                  child: pw.Text(
                                    tpl.titleOverride.isNotEmpty ? tpl.titleOverride.toUpperCase() : 'RECEIPT VOUCHER',
                                    style: pw.TextStyle(
                                      fontSize: 10,
                                      fontWeight: pw.FontWeight.bold,
                                      color: voucher.templateSnapshot.isNotEmpty ? PdfColors.white : PdfColors.blue900,
                                    ),
                                  ),
                                ),
                                pw.SizedBox(height: 4),
                                pw.Text('NO. ${voucher.voucherNumber}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.red800)),
                                pw.Text('Date: ${voucher.date}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800)),
                              ],
                            ),
                          ],
                        ),
                        pw.Divider(color: tplColor, thickness: 1, height: 16),

                        // Amount Box
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: pw.BoxDecoration(
                                border: pw.Border.all(color: PdfColors.blue900, width: 1.5),
                                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                                color: PdfColors.blue50,
                              ),
                              child: pw.Row(
                                children: [
                                  pw.Text('$curr  ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColors.blue900)),
                                  pw.Text(
                                    '# ${voucher.amount.toStringAsFixed(2)} #',
                                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13, color: PdfColors.blue900),
                                  ),
                                ],
                              ),
                            ),
                            if (voucher.invoiceNumber.isNotEmpty)
                              pw.Text('Invoice Ref: ${voucher.invoiceNumber}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                          ],
                        ),
                        pw.SizedBox(height: 12),

                        // Received From Line
                        pw.Row(
                          children: [
                            pw.Text('Received From Mr./M/s.: ', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
                            pw.Expanded(
                              child: pw.Container(
                                padding: const pw.EdgeInsets.only(bottom: 2),
                                decoration: const pw.BoxDecoration(
                                  border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey600, width: 0.8)),
                                ),
                                child: pw.Text(
                                  voucher.customerName,
                                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                                ),
                              ),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 10),

                        // The Sum of Line (English Only)
                        pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('The sum of: ', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
                            pw.Expanded(
                              child: pw.Container(
                                width: double.infinity,
                                padding: const pw.EdgeInsets.only(bottom: 2),
                                decoration: const pw.BoxDecoration(
                                  border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey600, width: 0.8)),
                                ),
                                child: pw.Text(
                                  voucher.amountInWordsEn.isNotEmpty ? voucher.amountInWordsEn : '${voucher.amount.toStringAsFixed(2)} $curr Only',
                                  style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900),
                                ),
                              ),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 10),

                        // Payment Method Details Line
                        pw.Row(
                          children: [
                            pw.Text('By: ', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
                            pw.Expanded(
                              flex: 3,
                              child: pw.Container(
                                padding: const pw.EdgeInsets.only(bottom: 2),
                                decoration: const pw.BoxDecoration(
                                  border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey600, width: 0.8)),
                                ),
                                child: pw.Text(
                                  voucher.paymentMethod + (voucher.chequeNumber.isNotEmpty ? ' #${voucher.chequeNumber}' : ''),
                                  style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey900),
                                ),
                              ),
                            ),
                            pw.SizedBox(width: 8),
                            pw.Text('Bank: ', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
                            pw.Expanded(
                              flex: 3,
                              child: pw.Container(
                                padding: const pw.EdgeInsets.only(bottom: 2),
                                decoration: const pw.BoxDecoration(
                                  border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey600, width: 0.8)),
                                ),
                                child: pw.Text(
                                  voucher.bankName.isNotEmpty ? voucher.bankName : 'Cash / Direct',
                                  style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey900),
                                ),
                              ),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 10),

                        // Being Line
                        pw.Row(
                          children: [
                            pw.Text('Being: ', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
                            pw.Expanded(
                              child: pw.Container(
                                padding: const pw.EdgeInsets.only(bottom: 2),
                                decoration: const pw.BoxDecoration(
                                  border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey600, width: 0.8)),
                                ),
                                child: pw.Text(
                                  voucher.being.isNotEmpty ? voucher.being : 'Payment received with thanks',
                                  style: pw.TextStyle(fontSize: 9.5, fontStyle: pw.FontStyle.italic, color: PdfColors.grey900),
                                ),
                              ),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 12),

                        // Financial Balance Breakdown Box (Total, Received Now, Previously Paid, Balance Due)
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.grey100,
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                            border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
                          ),
                          child: pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text('Total Amount', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
                                  pw.SizedBox(height: 2),
                                  pw.Text(
                                    '$curr ${(voucher.totalInvoiceAmount > 0 ? voucher.totalInvoiceAmount : voucher.amount).toStringAsFixed(2)}',
                                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900),
                                  ),
                                ],
                              ),
                              pw.Container(width: 1, height: 24, color: PdfColors.grey300),
                              pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.center,
                                children: [
                                  pw.Text('Amount Received', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
                                  pw.SizedBox(height: 2),
                                  pw.Text(
                                    '$curr ${voucher.amount.toStringAsFixed(2)}',
                                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.green900),
                                  ),
                                ],
                              ),
                              pw.Container(width: 1, height: 24, color: PdfColors.grey300),
                              pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.center,
                                children: [
                                  pw.Text('Previously Paid', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
                                  pw.SizedBox(height: 2),
                                  pw.Text(
                                    '$curr ${voucher.previouslyPaid.toStringAsFixed(2)}',
                                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
                                  ),
                                ],
                              ),
                              pw.Container(width: 1, height: 24, color: PdfColors.grey300),
                              pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.end,
                                children: [
                                  pw.Text('Balance Due', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
                                  pw.SizedBox(height: 2),
                                  pw.Text(
                                    '$curr ${voucher.balanceDue.toStringAsFixed(2)}',
                                    style: pw.TextStyle(
                                      fontSize: 10,
                                      fontWeight: pw.FontWeight.bold,
                                      color: voucher.balanceDue > 0 ? PdfColors.red900 : PdfColors.green900,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        pw.SizedBox(height: 24),

                        // Signatures Area
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            // Left: Receiver Sign
                            pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Container(width: 140, height: 1, color: PdfColors.grey600),
                                pw.SizedBox(height: 4),
                                pw.Text('Receiver\'s Signature', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
                              ],
                            ),

                            // Right: Authorized Sign
                            pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.end,
                              children: [
                                pw.Container(width: 140, height: 1, color: PdfColors.grey600),
                                pw.SizedBox(height: 4),
                                pw.Text('Authorized Signature', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Overlay Rubber Stamp (unclipped, template-driven position & label)
                    if (voucher.hasWatermarkStamp && tpl.stamp.enabled)
                      pw.Positioned(
                        left: voucher.templateSnapshot.isNotEmpty ? (tpl.stamp.xRatio.clamp(0.05, 0.72) * 480) : null,
                        top: voucher.templateSnapshot.isNotEmpty ? (tpl.stamp.yRatio.clamp(0.05, 0.85) * 420) : null,
                        right: voucher.templateSnapshot.isNotEmpty ? null : 70,
                        bottom: voucher.templateSnapshot.isNotEmpty ? null : 12,
                        child: pw.Transform.rotate(
                          angle: tpl.stamp.rotationDeg * 3.14159265 / 180.0,
                          child: pw.Container(
                            padding: const pw.EdgeInsets.all(2),
                            decoration: pw.BoxDecoration(
                              border: pw.Border.all(color: tplColor, width: 2),
                              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
                            ),
                            child: pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                              decoration: pw.BoxDecoration(
                                border: pw.Border.all(color: tplColor, width: 0.8),
                                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                              ),
                              child: pw.Column(
                                mainAxisSize: pw.MainAxisSize.min,
                                children: [
                                  pw.Text(
                                    tpl.stamp.label.isNotEmpty ? tpl.stamp.label.toUpperCase() : 'RECEIVED',
                                    style: pw.TextStyle(
                                      fontSize: 16,
                                      fontWeight: pw.FontWeight.bold,
                                      color: tplColor,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                  pw.SizedBox(height: 1),
                                  pw.Text(
                                    'VERIFIED PAYMENT • ${voucher.date}',
                                    style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold, color: tplColor),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Optional Proof of Delivery (POD) Section
              if (voucher.includePodSlip) ...[
                pw.SizedBox(height: 16),
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey700, width: 1),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey800, width: 1),
                        ),
                        child: pw.Text('PROOF OF DELIVERY', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Row(
                        children: [
                          pw.Expanded(
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text('Date Of Delivery: ${voucher.podDeliveryDate ?? "..........................."}', style: const pw.TextStyle(fontSize: 8.5)),
                                pw.SizedBox(height: 4),
                                pw.Text('Commodity: ${voucher.podCommodity.isNotEmpty ? voucher.podCommodity : "..........................."}', style: const pw.TextStyle(fontSize: 8.5)),
                                pw.SizedBox(height: 4),
                                pw.Text('Driver Name: ${voucher.podDriverName.isNotEmpty ? voucher.podDriverName : "..........................."}', style: const pw.TextStyle(fontSize: 8.5)),
                              ],
                            ),
                          ),
                          pw.Expanded(
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text('Receiver Name: ${voucher.podReceiverName.isNotEmpty ? voucher.podReceiverName : "..........................."}', style: const pw.TextStyle(fontSize: 8.5)),
                                pw.SizedBox(height: 4),
                                pw.Text('Receiver\'s Mob: ${voucher.podReceiverPhone.isNotEmpty ? voucher.podReceiverPhone : "..........................."}', style: const pw.TextStyle(fontSize: 8.5)),
                                pw.SizedBox(height: 4),
                                pw.Text('Receiver\'s Sign: ...........................', style: const pw.TextStyle(fontSize: 8.5)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Print or preview Receipt Voucher
  static Future<void> printReceiptVoucher(
    ReceiptVoucherModel voucher, {
    String companyName = 'Stepz Telecaller CRM',
    String? companyPhone,
    String? companyEmail,
    String? companyAddress,
    String? companyGstin,
    String? companyWebsite,
    String? companyLogo,
  }) async {
    await Printing.layoutPdf(
      onLayout: (format) async => await generateReceiptVoucherPdf(
        voucher,
        companyName: companyName,
        companyPhone: companyPhone,
        companyEmail: companyEmail,
        companyAddress: companyAddress,
        companyGstin: companyGstin,
        companyWebsite: companyWebsite,
        companyLogo: companyLogo,
      ),
      name: '${voucher.voucherNumber}.pdf',
    );
  }

  /// Share Receipt Voucher PDF file
  static Future<void> shareReceiptVoucherPdf(
    ReceiptVoucherModel voucher, {
    String companyName = 'Stepz Telecaller CRM',
    String? companyPhone,
    String? companyEmail,
    String? companyAddress,
    String? companyGstin,
    String? companyWebsite,
    String? companyLogo,
  }) async {
    final bytes = await generateReceiptVoucherPdf(
      voucher,
      companyName: companyName,
      companyPhone: companyPhone,
      companyEmail: companyEmail,
      companyAddress: companyAddress,
      companyGstin: companyGstin,
      companyWebsite: companyWebsite,
      companyLogo: companyLogo,
    );
    await Printing.sharePdf(bytes: bytes, filename: '${voucher.voucherNumber}.pdf');
  }

  /// Launch WhatsApp with pre-filled message for Receipt Voucher
  static Future<bool> shareReceiptVoucherToWhatsApp(
    ReceiptVoucherModel voucher, {
    String companyName = 'Stepz Telecaller CRM',
  }) async {
    final curr = voucher.currency.isNotEmpty ? voucher.currency : 'INR';
    final message = '''Official Payment Receipt Voucher - *$companyName*

Receipt Voucher: *${voucher.voucherNumber}*
Date: ${voucher.date}
Received From: *${voucher.customerName}*
Amount: *$curr ${voucher.amount.toStringAsFixed(2)}*
${voucher.amountInWordsEn.isNotEmpty ? 'Amount in Words: ${voucher.amountInWordsEn}\n' : ''}${voucher.amountInWordsAr.isNotEmpty ? 'المبلغ بالحروف: ${voucher.amountInWordsAr}\n' : ''}
Payment Mode: ${voucher.paymentMethod}
${voucher.chequeNumber.isNotEmpty ? 'Cheque No: ${voucher.chequeNumber}\n' : ''}For: ${voucher.being.isNotEmpty ? voucher.being : 'Payment received with thanks'}

Status: *VERIFIED & RECEIVED ✅*

Thank you for your business!
*$companyName*''';

    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return true;
    }
    return false;
  }
}
