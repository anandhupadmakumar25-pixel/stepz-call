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
  final double amountPaid;
  final double balanceDue;
  final String paymentStatus;
  final String paymentMode;
  final String paymentReference;
  final String paymentNotes;
  final String notes;
  final String termsAndConditions;
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
    this.amountPaid = 0.0,
    this.balanceDue = 0.0,
    this.paymentStatus = 'PENDING',
    this.paymentMode = '',
    this.paymentReference = '',
    this.paymentNotes = '',
    this.notes = '',
    this.termsAndConditions = '',
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
      invoiceNumber: json['invoice_number']?.toString() ?? '',
      quotationId: json['quotation']?.toString(),
      quotationNumber: json['quotation_number']?.toString() ?? '',
      leadId: json['lead']?.toString(),
      customerName: json['customer_name']?.toString() ?? '',
      customerPhone: json['customer_phone']?.toString() ?? '',
      customerEmail: json['customer_email']?.toString() ?? '',
      customerAddress: json['customer_address']?.toString() ?? '',
      createdBy: json['created_by']?.toString(),
      createdByName: json['created_by_name']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      dueDate: json['due_date']?.toString(),
      customColumns: customCols,
      showQty: showQty,
      showPrice: showPrice,
      showTax: showTax,
      items: itemsList,
      subtotal: parseNum(json['subtotal']),
      taxAmount: parseNum(json['tax_amount']),
      discountAmount: parseNum(json['discount_amount']),
      grandTotal: parseNum(json['grand_total']),
      amountPaid: parseNum(json['amount_paid']),
      balanceDue: parseNum(json['balance_due']),
      paymentStatus: json['payment_status']?.toString() ?? 'PENDING',
      paymentMode: json['payment_mode']?.toString() ?? '',
      paymentReference: json['payment_reference']?.toString() ?? '',
      paymentNotes: json['payment_notes']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      termsAndConditions: json['terms_and_conditions']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
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

