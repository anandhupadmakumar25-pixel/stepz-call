class QuotationItemModel {
  final String description;
  final double quantity;
  final double unitPrice;
  final double taxPercent;
  final double discountPercent;
  final double total;

  QuotationItemModel({
    required this.description,
    this.quantity = 1,
    this.unitPrice = 0.0,
    this.taxPercent = 0.0,
    this.discountPercent = 0.0,
    this.total = 0.0,
  });

  factory QuotationItemModel.fromJson(Map<String, dynamic> json) {
    double parseNum(dynamic val) {
      if (val == null) return 0.0;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? 0.0;
    }

    return QuotationItemModel(
      description: json['description']?.toString() ?? '',
      quantity: parseNum(json['quantity']),
      unitPrice: parseNum(json['unit_price'] ?? json['unitPrice']),
      taxPercent: parseNum(json['tax_percent'] ?? json['taxPercent']),
      discountPercent: parseNum(json['discount_percent'] ?? json['discountPercent']),
      total: parseNum(json['total']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'description': description,
      'quantity': quantity,
      'unit_price': unitPrice,
      'tax_percent': taxPercent,
      'discount_percent': discountPercent,
      'total': total,
    };
  }
}

class QuotationModel {
  final String id;
  final String quotationNumber;
  final String? leadId;
  final String leadName;
  final String customerName;
  final String customerPhone;
  final String customerEmail;
  final String customerAddress;
  final String? createdBy;
  final String createdByName;
  final String date;
  final String? validUntil;
  final List<QuotationItemModel> items;
  final double subtotal;
  final double taxAmount;
  final double discountAmount;
  final double grandTotal;
  final String notes;
  final String termsAndConditions;
  final String status;
  final String createdAt;
  final String updatedAt;

  QuotationModel({
    required this.id,
    required this.quotationNumber,
    this.leadId,
    this.leadName = '',
    required this.customerName,
    required this.customerPhone,
    this.customerEmail = '',
    this.customerAddress = '',
    this.createdBy,
    this.createdByName = '',
    required this.date,
    this.validUntil,
    this.items = const [],
    this.subtotal = 0.0,
    this.taxAmount = 0.0,
    this.discountAmount = 0.0,
    this.grandTotal = 0.0,
    this.notes = '',
    this.termsAndConditions = '',
    this.status = 'DRAFT',
    required this.createdAt,
    this.updatedAt = '',
  });

  QuotationModel copyWith({
    String? id,
    String? quotationNumber,
    String? leadId,
    String? leadName,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    String? customerAddress,
    String? createdBy,
    String? createdByName,
    String? date,
    String? validUntil,
    List<QuotationItemModel>? items,
    double? subtotal,
    double? taxAmount,
    double? discountAmount,
    double? grandTotal,
    String? notes,
    String? termsAndConditions,
    String? status,
    String? createdAt,
    String? updatedAt,
  }) {
    return QuotationModel(
      id: id ?? this.id,
      quotationNumber: quotationNumber ?? this.quotationNumber,
      leadId: leadId ?? this.leadId,
      leadName: leadName ?? this.leadName,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerEmail: customerEmail ?? this.customerEmail,
      customerAddress: customerAddress ?? this.customerAddress,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      date: date ?? this.date,
      validUntil: validUntil ?? this.validUntil,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      taxAmount: taxAmount ?? this.taxAmount,
      discountAmount: discountAmount ?? this.discountAmount,
      grandTotal: grandTotal ?? this.grandTotal,
      notes: notes ?? this.notes,
      termsAndConditions: termsAndConditions ?? this.termsAndConditions,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory QuotationModel.fromJson(Map<String, dynamic> json) {
    double parseNum(dynamic val) {
      if (val == null) return 0.0;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? 0.0;
    }

    var rawItems = json['items'];
    List<QuotationItemModel> itemsList = [];
    if (rawItems is List) {
      itemsList = rawItems
          .whereType<Map<String, dynamic>>()
          .map((item) => QuotationItemModel.fromJson(item))
          .toList();
    }

    return QuotationModel(
      id: json['id']?.toString() ?? '',
      quotationNumber: json['quotation_number']?.toString() ?? '',
      leadId: json['lead']?.toString(),
      leadName: json['lead_name']?.toString() ?? '',
      customerName: json['customer_name']?.toString() ?? '',
      customerPhone: json['customer_phone']?.toString() ?? '',
      customerEmail: json['customer_email']?.toString() ?? '',
      customerAddress: json['customer_address']?.toString() ?? '',
      createdBy: json['created_by']?.toString(),
      createdByName: json['created_by_name']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      validUntil: json['valid_until']?.toString(),
      items: itemsList,
      subtotal: parseNum(json['subtotal']),
      taxAmount: parseNum(json['tax_amount']),
      discountAmount: parseNum(json['discount_amount']),
      grandTotal: parseNum(json['grand_total']),
      notes: json['notes']?.toString() ?? '',
      termsAndConditions: json['terms_and_conditions']?.toString() ?? '',
      status: json['status']?.toString() ?? 'DRAFT',
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (leadId != null) 'lead': leadId,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'customer_email': customerEmail,
      'customer_address': customerAddress,
      if (validUntil != null) 'valid_until': validUntil,
      'items': items.map((i) => i.toJson()).toList(),
      'subtotal': subtotal,
      'tax_amount': taxAmount,
      'discount_amount': discountAmount,
      'grand_total': grandTotal,
      'notes': notes,
      'terms_and_conditions': termsAndConditions,
      'status': status,
    };
  }
}
