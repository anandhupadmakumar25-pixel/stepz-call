import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../core/widgets/action_loader.dart';
import '../../core/services/pdf_invoice_service.dart';
import '../../models/receipt_voucher_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/company_provider.dart';

class ReceiptVoucherDialog extends StatelessWidget {
  final ReceiptVoucherModel voucher;

  const ReceiptVoucherDialog({
    super.key,
    required this.voucher,
  });

  @override
  Widget build(BuildContext context) {
    final comp = context.watch<CompanyProvider>().activeCompanyDetail;
    final user = context.watch<AuthProvider>().currentUser;
    final isMobile = ResponsiveLayout.isMobile(context);

    final companyName = comp?.name.isNotEmpty == true
        ? comp!.name
        : (user?.companyName?.isNotEmpty == true ? user!.companyName! : 'Nine Stars Perfumes Trading L L C SP');
    final companyAddress = comp?.address.isNotEmpty == true ? comp!.address : user?.companyAddress;
    final companyPhone = comp?.contactPhone.isNotEmpty == true ? comp!.contactPhone : user?.companyPhone;
    final companyEmail = comp?.contactEmail.isNotEmpty == true ? comp!.contactEmail : user?.companyEmail;
    final companyCr = comp?.gstin.isNotEmpty == true ? comp!.gstin : user?.companyGstin;
    final companyLogo = comp?.logo.isNotEmpty == true ? comp!.logo : user?.companyLogo;

    final curr = voucher.currency.isNotEmpty
        ? voucher.currency
        : (user?.companyCurrency.isNotEmpty == true
            ? user!.companyCurrency
            : (comp?.currency ?? 'INR'));

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 32,
        vertical: isMobile ? 16 : 32,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 780,
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFBFBF9), // Banknote parchment tone
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1E3A8A), width: 2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Action Toolbar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFF1E3A8A),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(14),
                    topRight: Radius.circular(14),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.verified_outlined, color: Colors.amber, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Official Payment Receipt Voucher',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () => ActionLoader.run(
                            context,
                            message: 'Generating Receipt PDF...',
                            task: () => PdfInvoiceService.printReceiptVoucher(
                              voucher,
                              companyName: companyName,
                              companyPhone: companyPhone,
                              companyEmail: companyEmail,
                              companyAddress: companyAddress,
                              companyGstin: companyCr,
                              companyLogo: companyLogo,
                            ),
                          ),
                          icon: const Icon(Icons.print_rounded, size: 15),
                          label: const Text('Print / PDF'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () => ActionLoader.run(
                            context,
                            message: 'Opening WhatsApp...',
                            task: () => PdfInvoiceService.shareReceiptVoucherToWhatsApp(
                              voucher,
                              companyName: companyName,
                            ),
                          ),
                          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 15),
                          label: const Text('WhatsApp'),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Scrollable Voucher Content
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isMobile ? 16 : 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                          // Header Section
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (companyLogo != null && companyLogo.isNotEmpty) ...[
                                _buildLogoWidget(companyLogo),
                                const SizedBox(width: 14),
                              ],
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      companyName.toUpperCase(),
                                      style: GoogleFonts.cinzel(
                                        fontSize: isMobile ? 16 : 20,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF1E3A8A),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    if (companyAddress != null && companyAddress.isNotEmpty)
                                      Text(
                                        companyAddress,
                                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF475569)),
                                      ),
                                    Text(
                                      [
                                        if (companyPhone != null && companyPhone.isNotEmpty) 'Mob: $companyPhone',
                                        if (companyEmail != null && companyEmail.isNotEmpty) 'Email: $companyEmail',
                                        if (companyCr != null && companyCr.isNotEmpty) 'CR: $companyCr',
                                      ].join(' • '),
                                      style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFF1E3A8A), width: 1.5),
                                    ),
                                    child: Text(
                                      'RECEIPT VOUCHER',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF1E3A8A),
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Text('NO. ', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF991B1B))),
                                      Text(
                                        voucher.voucherNumber,
                                        style: GoogleFonts.robotoMono(fontSize: 13, fontWeight: FontWeight.w800, color: const Color(0xFFDC2626)),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    'Date: ${voucher.date}',
                                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(color: Color(0xFF1E3A8A), thickness: 1.5),
                          const SizedBox(height: 12),

                          // Amount Box Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF1E3A8A), width: 2),
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      '$curr  ',
                                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFF1E3A8A)),
                                    ),
                                    Text(
                                      '# ${voucher.amount.toStringAsFixed(2)} #',
                                      style: GoogleFonts.robotoMono(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF1E3A8A),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (voucher.invoiceNumber.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFCBD5E1)),
                                  ),
                                  child: Text(
                                    'Invoice Ref: ${voucher.invoiceNumber}',
                                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          // Received From Field
                          _buildCleanField(
                            label: 'Received From Mr./M/s.',
                            value: voucher.customerName,
                            isBold: true,
                          ),
                          const SizedBox(height: 14),

                          // The sum of Field (English Words Only)
                          _buildCleanField(
                            label: 'The sum of $curr',
                            value: voucher.amountInWordsEn.isNotEmpty
                                ? voucher.amountInWordsEn
                                : '${voucher.amount.toStringAsFixed(2)} $curr Only',
                            isBold: true,
                          ),
                          const SizedBox(height: 14),

                          // By Cash / Cheque No & Bank Field
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: _buildUnderlinedItem(
                                  label: 'By Cash / Cheque No.',
                                  value: voucher.paymentMethod + (voucher.chequeNumber.isNotEmpty ? ' #${voucher.chequeNumber}' : ''),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: _buildUnderlinedItem(
                                  label: 'Bank',
                                  value: voucher.bankName.isNotEmpty ? voucher.bankName : 'Cash / Direct',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: _buildUnderlinedItem(
                                  label: 'Date',
                                  value: voucher.chequeDate?.isNotEmpty == true ? voucher.chequeDate! : voucher.date,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Being Field
                          _buildCleanField(
                            label: 'Being',
                            value: voucher.being.isNotEmpty ? voucher.being : 'Payment received with thanks',
                            isItalic: true,
                          ),
                          const SizedBox(height: 16),

                          // Financial Balance Breakdown Box (Total Amount, Received Now, Previously Paid, Balance Due)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Total Amount',
                                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '$curr ${(voucher.totalInvoiceAmount > 0 ? voucher.totalInvoiceAmount : voucher.amount).toStringAsFixed(2)}',
                                      style: GoogleFonts.robotoMono(fontSize: 13, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                                    ),
                                  ],
                                ),
                                Container(width: 1, height: 28, color: const Color(0xFFCBD5E1)),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Amount Received',
                                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '$curr ${voucher.amount.toStringAsFixed(2)}',
                                      style: GoogleFonts.robotoMono(fontSize: 13, fontWeight: FontWeight.w800, color: const Color(0xFF059669)),
                                    ),
                                  ],
                                ),
                                Container(width: 1, height: 28, color: const Color(0xFFCBD5E1)),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Previously Paid',
                                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '$curr ${voucher.previouslyPaid.toStringAsFixed(2)}',
                                      style: GoogleFonts.robotoMono(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF475569)),
                                    ),
                                  ],
                                ),
                                Container(width: 1, height: 28, color: const Color(0xFFCBD5E1)),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Balance Due',
                                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '$curr ${voucher.balanceDue.toStringAsFixed(2)}',
                                      style: GoogleFonts.robotoMono(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                        color: voucher.balanceDue > 0 ? const Color(0xFFDC2626) : const Color(0xFF059669),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 28),

                          // Signatures Area
                          Padding(
                            padding: const EdgeInsets.only(top: 10, bottom: 6),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Receiver's Sign
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 180,
                                      height: 1.2,
                                      color: const Color(0xFF475569),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Receiver\'s Signature',
                                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
                                    ),
                                  ],
                                ),
                                // Accountant's Sign
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      width: 180,
                                      height: 1.2,
                                      color: const Color(0xFF475569),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Authorized Signature',
                                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Overlay Rubber Stamp Watermark (Angled, unclipped, floating over the document)
                      if (voucher.hasWatermarkStamp)
                        Positioned(
                          right: isMobile ? 30 : 120,
                          bottom: 18,
                          child: IgnorePointer(
                            child: Transform.rotate(
                              angle: -0.14,
                              child: _buildRubberStamp(voucher.date),
                            ),
                          ),
                        ),
                    ],
                  ),

                      // Proof of Delivery (POD) Section if enabled
                      if (voucher.includePodSlip) ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  border: Border.all(color: const Color(0xFF94A3B8)),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'PROOF OF DELIVERY',
                                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _buildPodLine('Date Of Delivery', voucher.podDeliveryDate ?? '...........................'),
                                        const SizedBox(height: 6),
                                        _buildPodLine('Commodity', voucher.podCommodity.isNotEmpty ? voucher.podCommodity : '...........................'),
                                        const SizedBox(height: 6),
                                        _buildPodLine('Driver Name', voucher.podDriverName.isNotEmpty ? voucher.podDriverName : '...........................'),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _buildPodLine('Receiver Name', voucher.podReceiverName.isNotEmpty ? voucher.podReceiverName : '...........................'),
                                        const SizedBox(height: 6),
                                        _buildPodLine('Receiver\'s Mob', voucher.podReceiverPhone.isNotEmpty ? voucher.podReceiverPhone : '...........................'),
                                        const SizedBox(height: 6),
                                        _buildPodLine('Receiver\'s Sign', '...........................'),
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
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCleanField({
    required String label,
    required String value,
    bool isBold = false,
    bool isItalic = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFF94A3B8), width: 1)),
          ),
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
              color: const Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRubberStamp(String date) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF1D4ED8).withValues(alpha: 0.85), width: 2.5),
        borderRadius: BorderRadius.circular(8),
        color: const Color(0xFFEFF6FF).withValues(alpha: 0.82),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1D4ED8).withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(1, 2),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF1D4ED8).withValues(alpha: 0.85), width: 1),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'RECEIVED',
              style: GoogleFonts.inter(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF1D4ED8),
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              'VERIFIED PAYMENT • $date',
              style: GoogleFonts.robotoMono(
                fontSize: 8.5,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1D4ED8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnderlinedItem({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF475569))),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFF94A3B8), width: 1)),
          ),
          child: Text(
            value,
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildPodLine(String label, String value) {
    return Row(
      children: [
        Text('$label: ', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF334155))),
        Expanded(
          child: Text(value, style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF0F172A))),
        ),
      ],
    );
  }

  Widget _buildLogoWidget(String base64Logo) {
    try {
      String clean = base64Logo.trim();
      if (clean.contains(',')) {
        clean = clean.split(',').last.trim();
      }
      final bytes = base64Decode(clean);
      if (bytes.isNotEmpty) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(bytes, width: 56, height: 56, fit: BoxFit.contain),
        );
      }
    } catch (_) {}
    return const SizedBox();
  }
}

