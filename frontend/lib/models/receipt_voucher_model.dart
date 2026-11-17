class ReceiptVoucherModel {
  final String id;
  final String voucherNumber;
  final String? invoiceId;
  final String invoiceNumber;
  final String? quotationId;
  final String quotationNumber;
  final String customerName;
  final String customerPhone;
  final String customerEmail;
  final String date;

  final double amount;
  final String currency;
  final double totalInvoiceAmount;
  final double previouslyPaid;
  final double balanceDue;
  final String amountInWordsEn;
  final String amountInWordsAr;

  final String paymentMethod; // CASH, CHEQUE, BANK_TRANSFER, CARD, ONLINE
  final String chequeNumber;
  final String bankName;
  final String? chequeDate;
  final String paymentReference;

  final String being;
  final String receiverName;
  final String accountantName;
  final String? createdBy;
  final String createdByName;

  final bool hasWatermarkStamp;
  final bool includePodSlip;
  final String podDriverName;
  final String podReceiverName;
  final String podReceiverPhone;
  final String? podDeliveryDate;
  final String podCommodity;

  final String notes;
  final String createdAt;
  final String updatedAt;

  ReceiptVoucherModel({
    required this.id,
    required this.voucherNumber,
    this.invoiceId,
    this.invoiceNumber = '',
    this.quotationId,
    this.quotationNumber = '',
    required this.customerName,
    this.customerPhone = '',
    this.customerEmail = '',
    required this.date,
    this.amount = 0.0,
    this.currency = 'INR',
    this.totalInvoiceAmount = 0.0,
    this.previouslyPaid = 0.0,
    this.balanceDue = 0.0,
    this.amountInWordsEn = '',
    this.amountInWordsAr = '',
    this.paymentMethod = 'CASH',
    this.chequeNumber = '',
    this.bankName = '',
    this.chequeDate,
    this.paymentReference = '',
    this.being = '',
    this.receiverName = '',
    this.accountantName = '',
    this.createdBy,
    this.createdByName = '',
    this.hasWatermarkStamp = true,
    this.includePodSlip = false,
    this.podDriverName = '',
    this.podReceiverName = '',
    this.podReceiverPhone = '',
    this.podDeliveryDate,
    this.podCommodity = '',
    this.notes = '',
    required this.createdAt,
    this.updatedAt = '',
  });

  factory ReceiptVoucherModel.fromJson(Map<String, dynamic> json) {
    double parseNum(dynamic val) {
      if (val == null) return 0.0;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? 0.0;
    }

    return ReceiptVoucherModel(
      id: json['id']?.toString() ?? '',
      voucherNumber: json['voucher_number']?.toString() ?? json['voucherNumber']?.toString() ?? '',
      invoiceId: json['invoice']?.toString() ?? json['invoiceId']?.toString(),
      invoiceNumber: json['invoice_number']?.toString() ?? json['invoiceNumber']?.toString() ?? '',
      quotationId: json['quotation']?.toString() ?? json['quotationId']?.toString(),
      quotationNumber: json['quotation_number']?.toString() ?? json['quotationNumber']?.toString() ?? '',
      customerName: json['customer_name']?.toString() ?? json['customerName']?.toString() ?? '',
      customerPhone: json['customer_phone']?.toString() ?? json['customerPhone']?.toString() ?? '',
      customerEmail: json['customer_email']?.toString() ?? json['customerEmail']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      amount: parseNum(json['amount']),
      currency: json['currency']?.toString() ?? 'INR',
      totalInvoiceAmount: parseNum(json['total_invoice_amount'] ?? json['totalInvoiceAmount']),
      previouslyPaid: parseNum(json['previously_paid'] ?? json['previouslyPaid']),
      balanceDue: parseNum(json['balance_due'] ?? json['balanceDue']),
      amountInWordsEn: json['amount_in_words_en']?.toString() ?? json['amountInWordsEn']?.toString() ?? '',
      amountInWordsAr: json['amount_in_words_ar']?.toString() ?? json['amountInWordsAr']?.toString() ?? '',
      paymentMethod: json['payment_method']?.toString() ?? json['paymentMethod']?.toString() ?? 'CASH',
      chequeNumber: json['cheque_number']?.toString() ?? json['chequeNumber']?.toString() ?? '',
      bankName: json['bank_name']?.toString() ?? json['bankName']?.toString() ?? '',
      chequeDate: json['cheque_date']?.toString() ?? json['chequeDate']?.toString(),
      paymentReference: json['payment_reference']?.toString() ?? json['paymentReference']?.toString() ?? '',
      being: json['being']?.toString() ?? '',
      receiverName: json['receiver_name']?.toString() ?? json['receiverName']?.toString() ?? '',
      accountantName: json['accountant_name']?.toString() ?? json['accountantName']?.toString() ?? '',
      createdBy: json['created_by']?.toString() ?? json['createdBy']?.toString(),
      createdByName: json['created_by_name']?.toString() ?? json['createdByName']?.toString() ?? '',
      hasWatermarkStamp: json['has_watermark_stamp'] == null ? true : (json['has_watermark_stamp'] == true),
      includePodSlip: json['include_pod_slip'] == null ? false : (json['include_pod_slip'] == true),
      podDriverName: json['pod_driver_name']?.toString() ?? json['podDriverName']?.toString() ?? '',
      podReceiverName: json['pod_receiver_name']?.toString() ?? json['podReceiverName']?.toString() ?? '',
      podReceiverPhone: json['pod_receiver_phone']?.toString() ?? json['podReceiverPhone']?.toString() ?? '',
      podDeliveryDate: json['pod_delivery_date']?.toString() ?? json['podDeliveryDate']?.toString(),
      podCommodity: json['pod_commodity']?.toString() ?? json['podCommodity']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? json['createdAt']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? json['updatedAt']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (invoiceId != null) 'invoice': invoiceId,
      if (quotationId != null) 'quotation': quotationId,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'customer_email': customerEmail,
      'amount': amount,
      'currency': currency,
      'total_invoice_amount': totalInvoiceAmount,
      'previously_paid': previouslyPaid,
      'balance_due': balanceDue,
      'amount_in_words_en': amountInWordsEn,
      'amount_in_words_ar': amountInWordsAr,
      'payment_method': paymentMethod,
      'cheque_number': chequeNumber,
      'bank_name': bankName,
      if (chequeDate != null) 'cheque_date': chequeDate,
      'payment_reference': paymentReference,
      'being': being,
      'receiver_name': receiverName,
      'accountant_name': accountantName,
      'has_watermark_stamp': hasWatermarkStamp,
      'include_pod_slip': includePodSlip,
      'pod_driver_name': podDriverName,
      'pod_receiver_name': podReceiverName,
      'pod_receiver_phone': podReceiverPhone,
      if (podDeliveryDate != null) 'pod_delivery_date': podDeliveryDate,
      'pod_commodity': podCommodity,
      'notes': notes,
    };
  }
}

