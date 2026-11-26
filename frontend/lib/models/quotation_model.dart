class QuotationItemModel {
  final String rowType; // 'ITEM' or 'SECTION_TITLE'
  final String title; // Section Title header
  final String itemCode; // Item Code (e.g. from PDF)
  final String description;
  final Map<String, String> customFields; // { columnTitle: value }
  final double quantity;
  final double unitPrice;
  final double cst; // Cost price per unit (internal CST column)
  final double taxPercent;
  final double discountPercent;
  final double total; // Qty * UnitPrice

  bool get isSectionTitle => rowType == 'SECTION_TITLE';
  double get costPrice => cst;
  double get costSum => quantity * cst; // QT * CST
  double get grossMargin => total - costSum;
  double get marginPercent => total > 0 ? (grossMargin / total) * 100 : 0.0;

  QuotationItemModel({
    this.rowType = 'ITEM',
    this.title = '',
    this.itemCode = '',
    required this.description,
    this.customFields = const {},
    this.quantity = 1,
    this.unitPrice = 0.0,
    this.cst = 0.0,
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

    Map<String, String> parseCustomFields(dynamic val) {
      if (val is Map) {
        return val.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
      }
      return {};
    }

    final rawType = json['row_type']?.toString() ?? json['rowType']?.toString() ?? 'ITEM';

    return QuotationItemModel(
      rowType: rawType,
      title: json['title']?.toString() ?? '',
      itemCode: json['item_code']?.toString() ?? json['itemCode']?.toString() ?? '',
      description: json['description']?.toString() ?? json['name']?.toString() ?? '',
      customFields: parseCustomFields(json['custom_fields'] ?? json['customFields']),
      quantity: parseNum(json['quantity'] ?? json['qty']),
      unitPrice: parseNum(json['unit_price'] ?? json['unitPrice'] ?? json['price']),
      cst: parseNum(json['cst'] ?? json['cost_price'] ?? json['costPrice']),
      taxPercent: parseNum(json['tax_percent'] ?? json['taxPercent']),
      discountPercent: parseNum(json['discount_percent'] ?? json['discountPercent']),
      total: parseNum(json['total']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'row_type': rowType,
      'title': title,
      'item_code': itemCode,
      'description': description,
      'custom_fields': customFields,
      'quantity': quantity,
      'unit_price': unitPrice,
      'cst': cst,
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

  // Professional metadata from official PDF format
  final String clientCode;
  final String salesRepName;
  final String incoterms;
  final String location;
  final String contactPerson;
  final String crNumber;
  final String currency;

  final String? createdBy;
  final String createdByName;
  final String createdByPhone;
  final String date;
  final String? validUntil;
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

  final String notes;
  final String termsAndConditions;
  final String status;
  final String? templateId;
  final Map<String, dynamic> templateSnapshot;
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
    this.clientCode = '',
    this.salesRepName = '',
    this.incoterms = 'EX WORKSHOP DOHA',
    this.location = '',
    this.contactPerson = '',
    this.crNumber = '',
    this.currency = 'INR',
    this.createdBy,
    this.createdByName = '',
    this.createdByPhone = '',
    required this.date,
    this.validUntil,
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
    this.notes = '',
    this.termsAndConditions = '',
    this.status = 'DRAFT',
    this.templateId,
    this.templateSnapshot = const {},
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
    String? clientCode,
    String? salesRepName,
    String? incoterms,
    String? location,
    String? contactPerson,
    String? crNumber,
    String? currency,
    String? createdBy,
    String? createdByName,
    String? date,
    String? validUntil,
    List<String>? customColumns,
    bool? showQty,
    bool? showPrice,
    bool? showTax,
    List<QuotationItemModel>? items,
    double? subtotal,
    double? taxAmount,
    double? discountAmount,
    double? grandTotal,
    double? totalCost,
    double? grossMargin,
    bool? hideCostInPdf,
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
      clientCode: clientCode ?? this.clientCode,
      salesRepName: salesRepName ?? this.salesRepName,
      incoterms: incoterms ?? this.incoterms,
      location: location ?? this.location,
      contactPerson: contactPerson ?? this.contactPerson,
      crNumber: crNumber ?? this.crNumber,
      currency: currency ?? this.currency,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      date: date ?? this.date,
      validUntil: validUntil ?? this.validUntil,
      customColumns: customColumns ?? this.customColumns,
      showQty: showQty ?? this.showQty,
      showPrice: showPrice ?? this.showPrice,
      showTax: showTax ?? this.showTax,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      taxAmount: taxAmount ?? this.taxAmount,
      discountAmount: discountAmount ?? this.discountAmount,
      grandTotal: grandTotal ?? this.grandTotal,
      totalCost: totalCost ?? this.totalCost,
      grossMargin: grossMargin ?? this.grossMargin,
      hideCostInPdf: hideCostInPdf ?? this.hideCostInPdf,
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

    return QuotationModel(
      id: json['id']?.toString() ?? '',
      quotationNumber: json['quotation_number']?.toString() ?? json['quotationNumber']?.toString() ?? '',
      leadId: json['lead']?.toString() ?? json['leadId']?.toString(),
      leadName: json['lead_name']?.toString() ?? json['leadName']?.toString() ?? '',
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
      createdByPhone: json['created_by_phone']?.toString() ?? json['createdByPhone']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      validUntil: json['valid_until']?.toString() ?? json['validUntil']?.toString(),
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
      notes: json['notes']?.toString() ?? '',
      termsAndConditions: json['terms_and_conditions']?.toString() ?? json['termsAndConditions']?.toString() ?? '',
      status: json['status']?.toString() ?? 'DRAFT',
      templateId: json['template']?.toString(),
      templateSnapshot: (json['template_snapshot'] as Map<String, dynamic>?) ?? const {},
      createdAt: json['created_at']?.toString() ?? json['createdAt']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? json['updatedAt']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
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
      if (validUntil != null) 'valid_until': validUntil,
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
      'notes': notes,
      'terms_and_conditions': termsAndConditions,
      'status': status,
    };
  }
}
