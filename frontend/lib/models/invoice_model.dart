import 'quotation_model.dart';

class InvoiceModel {
  final String id;
  final String invoiceNumber;
  final String? quotationId;
  final String quotationNumber;
  final String? leadId;
  final String customerName;
  final String customerPhone;
  final String customerEmail;
  final String customerAddress;

  // Professional metadata from official PDF / invoice format
  final String clientCode;
  final String salesRepName;
  final String incoterms;
  final String location;
  final String contactPerson;
  final String crNumber;
  final String currency;

  final String? createdBy;
  final String createdByName;
  final String date;
  final String? dueDate;
  final List<String> customColumns;
  final bool showQty;
  final bool showPrice;
  final bool showTax;
  final List<QuotationItemModel> items;
  final double subtotal;
  final double taxAmount;
  final double discountAmount;
  final double grandTotal;

  // Cost and margin analysis
  final double totalCost;
  final double grossMargin;
  final bool hideCostInPdf;

  // Bilingual amount in words
  final String amountInWordsEn;
  final String amountInWordsAr;

  final double amountPaid;
  final double balanceDue;
  final String paymentStatus;
  final String paymentMode;
  final String paymentReference;
  final String paymentNotes;
  final String notes;
  final String termsAndConditions;
  final String? templateId;
  final Map<String, dynamic> templateSnapshot;
  final String createdAt;
  final String updatedAt;

  InvoiceModel({
    required this.id,
    required this.invoiceNumber,
    this.quotationId,
    this.quotationNumber = '',
    this.leadId,
    required this.customerName,
    required this.customerPhone,
    this.customerEmail = '',
    this.customerAddress = '',
    this.clientCode = '',
    this.salesRepName = '',
    this.incoterms = 'EX WORKSHOP DOHA',
    this.location = '',
    this.contactPerson = '',
    this.crNumber = '',
    this.currency = 'INR',
    this.createdBy,
    this.createdByName = '',
    required this.date,
    this.dueDate,
    this.customColumns = const [],
    this.showQty = true,
    this.showPrice = true,
    this.showTax = true,
    this.items = const [],
    this.subtotal = 0.0,
    this.taxAmount = 0.0,
    this.discountAmount = 0.0,
    this.grandTotal = 0.0,
    this.totalCost = 0.0,
    this.grossMargin = 0.0,
    this.hideCostInPdf = true,
    this.amountInWordsEn = '',
    this.amountInWordsAr = '',
    this.amountPaid = 0.0,
    this.balanceDue = 0.0,
    this.paymentStatus = 'PENDING',
    this.paymentMode = '',
    this.paymentReference = '',
    this.paymentNotes = '',
    this.notes = '',
    this.termsAndConditions = '',
    this.templateId,
    this.templateSnapshot = const {},
    required this.createdAt,
    this.updatedAt = '',
  });

  factory InvoiceModel.fromJson(Map<String, dynamic> json) {
    double parseNum(dynamic val) {
      if (val == null) return 0.0;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? 0.0;
    }

    bool showQty = true;
    bool showPrice = true;
    bool showTax = true;
    List<String> customCols = [];

    final rawCustom = json['custom_columns'] ?? json['customColumns'];
    if (rawCustom is Map) {
      if (rawCustom['columns'] is List) {
        customCols = (rawCustom['columns'] as List).map((e) => e.toString()).toList();
      }
      showQty = rawCustom['show_qty'] == null ? true : (rawCustom['show_qty'] == true);
      showPrice = rawCustom['show_price'] == null ? true : (rawCustom['show_price'] == true);
      showTax = rawCustom['show_tax'] == null ? true : (rawCustom['show_tax'] == true);
    } else if (rawCustom is List) {
      customCols = rawCustom.map((e) => e.toString()).toList();
    }

    var rawItems = json['items'];
    List<QuotationItemModel> itemsList = [];
    if (rawItems is List) {
      itemsList = rawItems
          .map((item) {
            if (item is Map) {
              return QuotationItemModel.fromJson(Map<String, dynamic>.from(item));
            }
            return null;
          })
          .whereType<QuotationItemModel>()
          .toList();
    }

    return InvoiceModel(
      id: json['id']?.toString() ?? '',
      invoiceNumber: json['invoice_number']?.toString() ?? json['invoiceNumber']?.toString() ?? '',
      quotationId: json['quotation']?.toString() ?? json['quotationId']?.toString(),
      quotationNumber: json['quotation_number']?.toString() ?? json['quotationNumber']?.toString() ?? '',
      leadId: json['lead']?.toString() ?? json['leadId']?.toString(),
      customerName: json['customer_name']?.toString() ?? json['customerName']?.toString() ?? '',
      customerPhone: json['customer_phone']?.toString() ?? json['customerPhone']?.toString() ?? '',
      customerEmail: json['customer_email']?.toString() ?? json['customerEmail']?.toString() ?? '',
      customerAddress: json['customer_address']?.toString() ?? json['customerAddress']?.toString() ?? '',
      clientCode: json['client_code']?.toString() ?? json['clientCode']?.toString() ?? '',
      salesRepName: json['sales_rep_name']?.toString() ?? json['salesRepName']?.toString() ?? '',
      incoterms: json['incoterms']?.toString() ?? 'EX WORKSHOP DOHA',
      location: json['location']?.toString() ?? '',
      contactPerson: json['contact_person']?.toString() ?? json['contactPerson']?.toString() ?? '',
      crNumber: json['cr_number']?.toString() ?? json['crNumber']?.toString() ?? '',
      currency: json['currency']?.toString() ?? 'INR',
      createdBy: json['created_by']?.toString() ?? json['createdBy']?.toString(),
      createdByName: json['created_by_name']?.toString() ?? json['createdByName']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      dueDate: json['due_date']?.toString() ?? json['dueDate']?.toString(),
      customColumns: customCols,
      showQty: showQty,
      showPrice: showPrice,
      showTax: showTax,
      items: itemsList,
      subtotal: parseNum(json['subtotal']),
      taxAmount: parseNum(json['tax_amount'] ?? json['taxAmount']),
      discountAmount: parseNum(json['discount_amount'] ?? json['discountAmount']),
      grandTotal: parseNum(json['grand_total'] ?? json['grandTotal']),
      totalCost: parseNum(json['total_cost'] ?? json['totalCost']),
      grossMargin: parseNum(json['gross_margin'] ?? json['grossMargin']),
      hideCostInPdf: json['hide_cost_in_pdf'] == null ? true : (json['hide_cost_in_pdf'] == true),
      amountInWordsEn: json['amount_in_words_en']?.toString() ?? json['amountInWordsEn']?.toString() ?? '',
      amountInWordsAr: json['amount_in_words_ar']?.toString() ?? json['amountInWordsAr']?.toString() ?? '',
      amountPaid: parseNum(json['amount_paid'] ?? json['amountPaid']),
      balanceDue: parseNum(json['balance_due'] ?? json['balanceDue']),
      paymentStatus: json['payment_status']?.toString() ?? json['paymentStatus']?.toString() ?? 'PENDING',
      paymentMode: json['payment_mode']?.toString() ?? json['paymentMode']?.toString() ?? '',
      paymentReference: json['payment_reference']?.toString() ?? json['paymentReference']?.toString() ?? '',
      paymentNotes: json['payment_notes']?.toString() ?? json['paymentNotes']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      termsAndConditions: json['terms_and_conditions']?.toString() ?? json['termsAndConditions']?.toString() ?? '',
      templateId: json['template']?.toString(),
      templateSnapshot: (json['template_snapshot'] as Map<String, dynamic>?) ?? const {},
      createdAt: json['created_at']?.toString() ?? json['createdAt']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? json['updatedAt']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (quotationId != null) 'quotation': quotationId,
      if (leadId != null) 'lead': leadId,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'customer_email': customerEmail,
      'customer_address': customerAddress,
      'client_code': clientCode,
      'sales_rep_name': salesRepName,
      'incoterms': incoterms,
      'location': location,
      'contact_person': contactPerson,
      'cr_number': crNumber,
      'currency': currency,
      if (dueDate != null) 'due_date': dueDate,
      'custom_columns': {
        'columns': customColumns,
        'show_qty': showQty,
        'show_price': showPrice,
        'show_tax': showTax,
      },
      'items': items.map((i) => i.toJson()).toList(),
      'subtotal': subtotal,
      'tax_amount': taxAmount,
      'discount_amount': discountAmount,
      'grand_total': grandTotal,
      'total_cost': totalCost,
      'gross_margin': grossMargin,
      'hide_cost_in_pdf': hideCostInPdf,
      'amount_in_words_en': amountInWordsEn,
      'amount_in_words_ar': amountInWordsAr,
      'amount_paid': amountPaid,
      'payment_status': paymentStatus,
      'payment_mode': paymentMode,
      'payment_reference': paymentReference,
      'payment_notes': paymentNotes,
      'notes': notes,
      'terms_and_conditions': termsAndConditions,
    };
  }
}

class BillingOverviewModel {
  final int quotationCount;
  final double totalQuotationValue;
  final int invoiceCount;
  final double totalBilled;
  final double totalCollected;
  final double pendingReceivables;
  final int paidInvoiceCount;
  final int pendingInvoiceCount;

  BillingOverviewModel({
    this.quotationCount = 0,
    this.totalQuotationValue = 0.0,
    this.invoiceCount = 0,
    this.totalBilled = 0.0,
    this.totalCollected = 0.0,
    this.pendingReceivables = 0.0,
    this.paidInvoiceCount = 0,
    this.pendingInvoiceCount = 0,
  });

  factory BillingOverviewModel.fromJson(Map<String, dynamic> json) {
    double parseNum(dynamic val) {
      if (val == null) return 0.0;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? 0.0;
    }

    int parseInt(dynamic val) {
      if (val == null) return 0;
      if (val is int) return val;
      return int.tryParse(val.toString()) ?? 0;
    }

    return BillingOverviewModel(
      quotationCount: parseInt(json['quotation_count']),
      totalQuotationValue: parseNum(json['total_quotation_value']),
      invoiceCount: parseInt(json['invoice_count']),
      totalBilled: parseNum(json['total_billed']),
      totalCollected: parseNum(json['total_collected']),
      pendingReceivables: parseNum(json['pending_receivables']),
      paidInvoiceCount: parseInt(json['paid_invoice_count']),
      pendingInvoiceCount: parseInt(json['pending_invoice_count']),
    );
  }
}
