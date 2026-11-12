import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/quotation_model.dart';
import '../../models/invoice_model.dart';

class PdfInvoiceService {
  static Future<Uint8List> generateQuotationPdf(
    QuotationModel quotation, {
    String companyName = 'Stepz Telecaller CRM',
    String? companyPhone,
    String? companyEmail,
    String? companyAddress,
  }) async {
    final pdf = pw.Document();

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
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        companyName,
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.indigo900,
                        ),
                      ),
                      if (companyPhone != null && companyPhone.isNotEmpty)
                        pw.Text('Phone: $companyPhone', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      if (companyEmail != null && companyEmail.isNotEmpty)
                        pw.Text('Email: $companyEmail', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      if (companyAddress != null && companyAddress.isNotEmpty)
                        pw.Text(companyAddress, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.indigo50,
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                          border: pw.Border.all(color: PdfColors.indigo200),
                        ),
                        child: pw.Text(
                          'ESTIMATE / APPROXIMATE QUOTATION',
                          style: pw.TextStyle(
                            fontSize: 13,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.indigo800,
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text('Quote #: ${quotation.quotationNumber}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                      pw.Text('Date: ${quotation.date}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      if (quotation.validUntil != null && quotation.validUntil!.isNotEmpty)
                        pw.Text('Valid Until: ${quotation.validUntil}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    ],
                  ),
                ],
              ),
              pw.Divider(color: PdfColors.grey300, thickness: 1, height: 24),

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
                  0: const pw.FixedColumnWidth(24),
                  1: const pw.FlexColumnWidth(3.0),
                };
                int cIdx = 2;
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
                    // Table Header
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.indigo50),
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('#', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Item Description', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                        for (final col in customCols)
                          pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(col, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                        if (showQty)
                          pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Qty', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                        if (showPrice)
                          pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Rate', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                        if (showTax)
                          pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Tax %', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Total', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
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
                            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('•', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.amber900))),
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
                          for (final col in customCols)
                            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(item.customFields[col] ?? '-', style: const pw.TextStyle(fontSize: 8.5))),
                          if (showQty)
                            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(item.quantity.toStringAsFixed(item.quantity.truncateToDouble() == item.quantity ? 0 : 2), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8.5))),
                          if (showPrice)
                            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('₹${item.unitPrice.toStringAsFixed(2)}', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8.5))),
                          if (showTax)
                            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('${item.taxPercent}%', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8.5))),
                          pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('₹${item.total.toStringAsFixed(2)}', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold))),
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
                          _buildPdfAmountRow('Approximate Subtotal', '₹${quotation.subtotal.toStringAsFixed(2)}'),
                          if (quotation.discountAmount > 0)
                            _buildPdfAmountRow('Discount', '-₹${quotation.discountAmount.toStringAsFixed(2)}', textColor: PdfColors.red700),
                          if (quotation.taxAmount > 0)
                            _buildPdfAmountRow('Tax / GST', '₹${quotation.taxAmount.toStringAsFixed(2)}'),
                          pw.Divider(color: PdfColors.grey400, thickness: 0.5, height: 12),
                          _buildPdfAmountRow(
                            'Approximate Grand Total',
                            '₹${quotation.grandTotal.toStringAsFixed(2)}',
                            isBold: true,
                            fontSize: 12,
                            textColor: PdfColors.indigo900,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              pw.Spacer(),

              // Footer
              pw.Center(
                child: pw.Text(
                  'Thank you for your business! This is an approximate quotation / estimate. Final pricing is fixed upon Tax Invoice generation.',
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
  }) async {
    final pdf = pw.Document();

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
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        companyName,
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.indigo900,
                        ),
                      ),
                      if (companyPhone != null && companyPhone.isNotEmpty)
                        pw.Text('Phone: $companyPhone', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      if (companyEmail != null && companyEmail.isNotEmpty)
                        pw.Text('Email: $companyEmail', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      if (companyAddress != null && companyAddress.isNotEmpty)
                        pw.Text(companyAddress, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: pw.BoxDecoration(
                          color: isPaid ? PdfColors.green50 : PdfColors.amber50,
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                          border: pw.Border.all(color: statusColor),
                        ),
                        child: pw.Text(
                          'TAX INVOICE (FIXED PRICE BILL)',
                          style: pw.TextStyle(
                            fontSize: 13,
                            fontWeight: pw.FontWeight.bold,
                            color: statusColor,
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
              pw.Divider(color: PdfColors.grey300, thickness: 1, height: 24),

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
                int cIdx = 2;
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
                      decoration: const pw.BoxDecoration(color: PdfColors.indigo50),
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('#', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Item Description', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                        for (final col in customCols)
                          pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(col, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                        if (showQty)
                          pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Qty', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                        if (showPrice)
                          pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Rate', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                        if (showTax)
                          pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Tax %', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Total', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
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
                            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('•', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.amber900))),
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
                          for (final col in customCols)
                            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(item.customFields[col] ?? '-', style: const pw.TextStyle(fontSize: 8.5))),
                          if (showQty)
                            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(item.quantity.toStringAsFixed(item.quantity.truncateToDouble() == item.quantity ? 0 : 2), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8.5))),
                          if (showPrice)
                            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('₹${item.unitPrice.toStringAsFixed(2)}', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8.5))),
                          if (showTax)
                            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('${item.taxPercent}%', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8.5))),
                          pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('₹${item.total.toStringAsFixed(2)}', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold))),
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
                          _buildPdfAmountRow('Fixed Subtotal', '₹${invoice.subtotal.toStringAsFixed(2)}'),
                          if (invoice.discountAmount > 0)
                            _buildPdfAmountRow('Discount', '-₹${invoice.discountAmount.toStringAsFixed(2)}', textColor: PdfColors.red700),
                          if (invoice.taxAmount > 0)
                            _buildPdfAmountRow('Tax / GST', '₹${invoice.taxAmount.toStringAsFixed(2)}'),
                          pw.Divider(color: PdfColors.grey400, thickness: 0.5, height: 10),
                          _buildPdfAmountRow(
                            'Approximate Grand Total',
                            '₹${invoice.grandTotal.toStringAsFixed(2)}',
                            isBold: true,
                            fontSize: 11,
                            textColor: PdfColors.indigo900,
                          ),
                          _buildPdfAmountRow(
                            'Amount Paid',
                            '₹${invoice.amountPaid.toStringAsFixed(2)}',
                            fontSize: 10,
                            textColor: PdfColors.green800,
                          ),
                          pw.Divider(color: PdfColors.grey400, thickness: 0.5, height: 10),
                          _buildPdfAmountRow(
                            'Balance Due',
                            '₹${invoice.balanceDue.toStringAsFixed(2)}',
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
  static Future<void> printQuotation(QuotationModel quotation, {String companyName = 'Stepz Telecaller CRM'}) async {
    await Printing.layoutPdf(
      onLayout: (format) async => await generateQuotationPdf(quotation, companyName: companyName),
      name: '${quotation.quotationNumber}.pdf',
    );
  }

  /// Share quotation PDF file
  static Future<void> shareQuotationPdf(QuotationModel quotation, {String companyName = 'Stepz Telecaller CRM'}) async {
    final bytes = await generateQuotationPdf(quotation, companyName: companyName);
    await Printing.sharePdf(bytes: bytes, filename: '${quotation.quotationNumber}.pdf');
  }

  /// Print or preview invoice
  static Future<void> printInvoice(InvoiceModel invoice, {String companyName = 'Stepz Telecaller CRM'}) async {
    await Printing.layoutPdf(
      onLayout: (format) async => await generateInvoicePdf(invoice, companyName: companyName),
      name: '${invoice.invoiceNumber}.pdf',
    );
  }

  /// Share invoice PDF file
  static Future<void> shareInvoicePdf(InvoiceModel invoice, {String companyName = 'Stepz Telecaller CRM'}) async {
    final bytes = await generateInvoicePdf(invoice, companyName: companyName);
    await Printing.sharePdf(bytes: bytes, filename: '${invoice.invoiceNumber}.pdf');
  }

  /// Launch WhatsApp with pre-filled message for Quotation
  static Future<bool> shareQuotationToWhatsApp(QuotationModel quotation, {String companyName = 'Stepz Telecaller CRM'}) async {
    final cleanPhone = quotation.customerPhone.replaceAll(RegExp(r'[^0-9]'), '');
    final phoneToUse = cleanPhone.length == 10 ? '91$cleanPhone' : cleanPhone;

    final itemsSummary = quotation.items.map((i) => '• ${i.description} (x${i.quantity}): ₹${i.total.toStringAsFixed(2)}').join('\n');

    final message = '''Hello ${quotation.customerName},

Greetings from *$companyName*!

We are pleased to share your Approximate Quotation *${quotation.quotationNumber}* dated ${quotation.date}:

*Items / Services:*
$itemsSummary

*Subtotal:* ₹${quotation.subtotal.toStringAsFixed(2)}
${quotation.discountAmount > 0 ? '*Discount:* -₹${quotation.discountAmount.toStringAsFixed(2)}\n' : ''}*Tax / GST:* ₹${quotation.taxAmount.toStringAsFixed(2)}
*Approximate Total Amount:* ₹${quotation.grandTotal.toStringAsFixed(2)} (Estimated Quote)

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
  static Future<bool> shareInvoiceToWhatsApp(InvoiceModel invoice, {String companyName = 'Stepz Telecaller CRM'}) async {
    final cleanPhone = invoice.customerPhone.replaceAll(RegExp(r'[^0-9]'), '');
    final phoneToUse = cleanPhone.length == 10 ? '91$cleanPhone' : cleanPhone;

    final isPaid = invoice.paymentStatus == 'PAID';

    final message = '''Hello ${invoice.customerName},

Thank you for choosing *$companyName*!

Here are the details of your Fixed Price Bill / Tax Invoice *${invoice.invoiceNumber}*:

*Fixed Total Amount:* ₹${invoice.grandTotal.toStringAsFixed(2)} (Fixed Price)
*Amount Paid:* ₹${invoice.amountPaid.toStringAsFixed(2)}
*Balance Due:* ₹${invoice.balanceDue.toStringAsFixed(2)}
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
}
