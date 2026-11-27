class TemplateBlockConfig {
  String id;
  String label;
  bool visible;
  int order;
  String width; // 'full', 'left', 'right'

  TemplateBlockConfig({
    required this.id,
    required this.label,
    this.visible = true,
    required this.order,
    this.width = 'full',
  });

  factory TemplateBlockConfig.fromJson(Map<String, dynamic> json, {int fallbackOrder = 0}) {
    final id = json['id']?.toString() ?? 'header';
    return TemplateBlockConfig(
      id: id,
      label: json['label']?.toString() ?? defaultLabelFor(id),
      visible: json['visible'] == null ? true : json['visible'] == true,
      order: json['order'] is int ? json['order'] : int.tryParse(json['order']?.toString() ?? '') ?? fallbackOrder,
      width: json['width']?.toString() ?? 'full',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'visible': visible,
        'order': order,
        'width': width,
      };

  static String defaultLabelFor(String id) {
    switch (id) {
      case 'header':
        return 'Company Header & Logo';
      case 'client_meta':
        return 'Client & Document Info';
      case 'items_table':
        return 'Line Items Table';
      case 'totals_words':
        return 'Totals & Amount in Words';
      case 'bank_details':
        return 'Bank & Payment Details';
      case 'terms':
        return 'Terms & Conditions';
      case 'pod_slip':
        return 'Proof of Delivery (POD)';
      case 'signatures':
        return 'Authorized Signatures';
      default:
        return id;
    }
  }
}

class TemplateStampConfig {
  bool enabled;
  String label;
  double xRatio;
  double yRatio;
  double rotationDeg;
  String colorHex;

  TemplateStampConfig({
    this.enabled = true,
    this.label = 'RECEIVED',
    this.xRatio = 0.68,
    this.yRatio = 0.78,
    this.rotationDeg = -8.0,
    this.colorHex = '#1E3A8A',
  });

  factory TemplateStampConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null) return TemplateStampConfig();
    return TemplateStampConfig(
      enabled: json['enabled'] == null ? true : json['enabled'] == true,
      label: json['label']?.toString() ?? 'RECEIVED',
      xRatio: (json['x_ratio'] as num?)?.toDouble() ?? 0.68,
      yRatio: (json['y_ratio'] as num?)?.toDouble() ?? 0.78,
      rotationDeg: (json['rotation_deg'] as num?)?.toDouble() ?? -8.0,
      colorHex: json['color']?.toString() ?? '#1E3A8A',
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'label': label,
        'x_ratio': xRatio,
        'y_ratio': yRatio,
        'rotation_deg': rotationDeg,
        'color': colorHex,
      };
}

class CanvasElement {
  String id;
  String type; // 'text', 'field', 'image', 'table', 'line', 'box'
  double x; // A4 pt (0..595)
  double y; // A4 pt (0..842)
  double w;
  double h;
  String text;
  double fontSize;
  bool bold;
  bool italic;
  String align; // 'left', 'center', 'right'
  String colorHex;
  String bgColorHex;
  String borderColorHex;
  double borderWidth;
  String imageSource; // '{{branch_logo}}' or base64/url
  List<String> tableColumns;
  bool locked;

  CanvasElement({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    this.text = '',
    this.fontSize = 10.0,
    this.bold = false,
    this.italic = false,
    this.align = 'left',
    this.colorHex = '#0F172A',
    this.bgColorHex = '',
    this.borderColorHex = '',
    this.borderWidth = 0.0,
    this.imageSource = '',
    this.tableColumns = const [],
    this.locked = false,
  });

  CanvasElement copyWith({
    String? id,
    String? type,
    double? x,
    double? y,
    double? w,
    double? h,
    String? text,
    double? fontSize,
    bool? bold,
    bool? italic,
    String? align,
    String? colorHex,
    String? bgColorHex,
    String? borderColorHex,
    double? borderWidth,
    String? imageSource,
    List<String>? tableColumns,
    bool? locked,
  }) {
    return CanvasElement(
      id: id ?? this.id,
      type: type ?? this.type,
      x: x ?? this.x,
      y: y ?? this.y,
      w: w ?? this.w,
      h: h ?? this.h,
      text: text ?? this.text,
      fontSize: fontSize ?? this.fontSize,
      bold: bold ?? this.bold,
      italic: italic ?? this.italic,
      align: align ?? this.align,
      colorHex: colorHex ?? this.colorHex,
      bgColorHex: bgColorHex ?? this.bgColorHex,
      borderColorHex: borderColorHex ?? this.borderColorHex,
      borderWidth: borderWidth ?? this.borderWidth,
      imageSource: imageSource ?? this.imageSource,
      tableColumns: tableColumns ?? List<String>.from(this.tableColumns),
      locked: locked ?? this.locked,
    );
  }

  factory CanvasElement.fromJson(Map<String, dynamic> json) {
    return CanvasElement(
      id: json['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
      type: json['type']?.toString() ?? 'text',
      x: (json['x'] as num?)?.toDouble() ?? 32.0,
      y: (json['y'] as num?)?.toDouble() ?? 32.0,
      w: (json['w'] as num?)?.toDouble() ?? 180.0,
      h: (json['h'] as num?)?.toDouble() ?? 32.0,
      text: json['text']?.toString() ?? '',
      fontSize: (json['font_size'] as num?)?.toDouble() ?? 10.0,
      bold: json['bold'] == true,
      italic: json['italic'] == true,
      align: json['align']?.toString() ?? 'left',
      colorHex: json['color']?.toString() ?? '#0F172A',
      bgColorHex: json['bg_color']?.toString() ?? '',
      borderColorHex: json['border_color']?.toString() ?? '',
      borderWidth: (json['border_width'] as num?)?.toDouble() ?? 0.0,
      imageSource: json['image_source']?.toString() ?? '',
      tableColumns: (json['table_columns'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      locked: json['locked'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'x': x,
        'y': y,
        'w': w,
        'h': h,
        'text': text,
        'font_size': fontSize,
        'bold': bold,
        'italic': italic,
        'align': align,
        'color': colorHex,
        'bg_color': bgColorHex,
        'border_color': borderColorHex,
        'border_width': borderWidth,
        'image_source': imageSource,
        'table_columns': tableColumns,
        'locked': locked,
      };
}

class TemplateLayoutConfig {
  String preset; // 'classic_corporate', 'modern_minimal', 'banknote_voucher'
  String primaryColorHex;
  String accentColorHex;
  String borderStyle; // 'solid', 'rounded', 'none', 'double'
  String logoPosition; // 'left', 'center', 'right'
  String branchId; // '' = company main logo, or selected branch ID
  String logoOverride; // resolved branch/custom logo base64/url
  bool showCompanyAddress;
  bool showCrGstin;
  String titleOverride;
  String numberPrefix;
  List<TemplateBlockConfig> blocks;
  TemplateStampConfig stamp;

  // Smart content & column defaults
  bool showQty;
  bool showPrice;
  bool showTax;
  bool hideCostInPdf;
  bool includePodSlip;
  List<String> customColumns;
  String incoterms;
  String termsAndConditions;
  String notes;
  String bankDetailsText;

  // Dynamic form field visibility & custom header fields
  bool showClientCode;
  bool showSalesRep;
  bool showIncoterms;
  bool showLocation;
  bool showContactPerson;
  bool showCrNumber;
  bool showValidUntil;
  List<String> customHeaderFields;
  Map<String, String> filledFields;
  bool useCanvasMode;
  List<CanvasElement> canvasElements;

  TemplateLayoutConfig({
    this.preset = 'classic_corporate',
    this.primaryColorHex = '#1E3A8A',
    this.accentColorHex = '#059669',
    this.borderStyle = 'solid',
    this.logoPosition = 'left',
    this.branchId = '',
    this.logoOverride = '',
    this.showCompanyAddress = true,
    this.showCrGstin = true,
    this.titleOverride = '',
    this.numberPrefix = '',
    required this.blocks,
    required this.stamp,
    this.showQty = true,
    this.showPrice = true,
    this.showTax = true,
    this.hideCostInPdf = true,
    this.includePodSlip = false,
    this.customColumns = const [],
    this.incoterms = '',
    this.termsAndConditions = '',
    this.notes = '',
    this.bankDetailsText = '',
    this.showClientCode = true,
    this.showSalesRep = true,
    this.showIncoterms = true,
    this.showLocation = true,
    this.showContactPerson = true,
    this.showCrNumber = true,
    this.showValidUntil = true,
    this.customHeaderFields = const [],
    this.filledFields = const {},
    this.useCanvasMode = false,
    this.canvasElements = const [],
  });

  bool isBlockVisible(String id) {
    final m = blocks.where((b) => b.id == id);
    return m.isEmpty ? false : m.first.visible;
  }

  factory TemplateLayoutConfig.defaultFor(String docType) {
    final isReceipt = docType == 'RECEIPT';
    return TemplateLayoutConfig(
      preset: isReceipt ? 'banknote_voucher' : 'parfemperor_standard',
      primaryColorHex: '#1E3A8A',
      accentColorHex: '#059669',
      borderStyle: isReceipt ? 'double' : 'solid',
      logoPosition: isReceipt ? 'left' : 'center',
      useCanvasMode: !isReceipt,
      canvasElements: isReceipt ? const [] : buildStandardParfemperorCanvas(docType),
      blocks: [
        TemplateBlockConfig(id: 'header', label: 'Company Header & Logo', visible: true, order: 0),
        TemplateBlockConfig(id: 'client_meta', label: 'Client & Document Info', visible: true, order: 1),
        if (!isReceipt)
          TemplateBlockConfig(id: 'items_table', label: 'Line Items Table', visible: true, order: 2),
        TemplateBlockConfig(id: 'totals_words', label: 'Totals & Amount in Words', visible: true, order: 3),
        TemplateBlockConfig(id: 'bank_details', label: 'Bank & Payment Details', visible: false, order: 4),
        if (!isReceipt)
          TemplateBlockConfig(id: 'terms', label: 'Terms & Conditions', visible: true, order: 5),
        TemplateBlockConfig(id: 'pod_slip', label: 'Proof of Delivery (POD)', visible: false, order: 6),
        TemplateBlockConfig(id: 'signatures', label: 'Authorized Signatures', visible: true, order: 7),
      ],
      stamp: TemplateStampConfig(
        enabled: isReceipt,
        label: isReceipt ? 'RECEIVED' : 'APPROVED',
        xRatio: 0.68,
        yRatio: 0.78,
        rotationDeg: -8.0,
        colorHex: '#1E3A8A',
      ),
    );
  }

  /// Decomposes the uploaded Parfemperor Proforma Invoice / Quotation layout
  /// into fully editable, draggable, and deletable Canva-style elements.
  static List<CanvasElement> buildStandardParfemperorCanvas(String docType) {
    final docTitle = docType == 'QUOTATION'
        ? 'QUOTATION'
        : (docType == 'RECEIPT'
            ? 'RECEIPT VOUCHER'
            : (docType == 'PAYSLIP' ? 'SALARY PAYSLIP' : 'PROFORMA INVOICE'));
    final numLabel = docType == 'QUOTATION'
        ? 'Quote No.'
        : (docType == 'PAYSLIP' ? 'Pay Period' : 'INV. No.');
    final dateLabel = docType == 'QUOTATION'
        ? 'Quote Date'
        : (docType == 'PAYSLIP' ? 'Payday Due' : 'INV. Date');

    return [
      CanvasElement(
        id: 'std_logo',
        type: 'image',
        x: 207,
        y: 22,
        w: 180,
        h: 64,
        imageSource: '{{branch_logo}}',
      ),
      CanvasElement(
        id: 'std_meta_left',
        type: 'text',
        x: 32,
        y: 98,
        w: 270,
        h: 112,
        fontSize: 9.5,
        text:
            '$numLabel : {{doc_number}}\n$dateLabel : {{date}}\nClient PO. : {{client_po}}\nIncoterms : {{incoterms}}\nCurrency : {{currency}}\nDelivery address : {{delivery_address}}\nTRN : {{company_trn}}\nSales Rep : {{sales_rep_name}} ({{sales_rep_phone}})',
      ),
      CanvasElement(
        id: 'std_client_right',
        type: 'text',
        x: 335,
        y: 102,
        w: 228,
        h: 96,
        fontSize: 9.5,
        text:
            '{{customer_name}}\n{{customer_address}}\n{{contact_person}}\nTEL: {{customer_phone}}\nTRN: {{customer_trn}}',
      ),
      CanvasElement(
        id: 'std_title',
        type: 'text',
        x: 145,
        y: 218,
        w: 305,
        h: 24,
        fontSize: 13.0,
        bold: true,
        align: 'center',
        text: docTitle,
      ),
      CanvasElement(
        id: 'std_table',
        type: 'table',
        x: 32,
        y: 248,
        w: 531,
        h: 348,
        fontSize: 8.5,
        borderColorHex: '#334155',
        borderWidth: 0.8,
        tableColumns: [
          'Qty',
          'Item Name',
          'Item code',
          'Category',
          'HS code',
          'Pkg',
          'Origin',
          'Unit price',
          'Ex. Tax',
          'VAT%',
          'VAT',
          'Total',
        ],
      ),
      CanvasElement(
        id: 'std_words',
        type: 'text',
        x: 32,
        y: 604,
        w: 340,
        h: 38,
        fontSize: 9.0,
        bold: true,
        text: 'Amount In Words : {{amount_in_words}}\nVAT In Words : {{vat_in_words}}',
      ),
      CanvasElement(
        id: 'std_totals',
        type: 'text',
        x: 380,
        y: 604,
        w: 183,
        h: 42,
        fontSize: 9.5,
        bold: true,
        align: 'right',
        text: 'Extra / Clearance : {{extra_charge}}\nTOTAL AMOUNT : {{currency}} {{grand_total}}',
      ),
      CanvasElement(
        id: 'std_divider',
        type: 'line',
        x: 32,
        y: 650,
        w: 531,
        h: 2,
        colorHex: '#0F172A',
        borderWidth: 1.0,
      ),
      CanvasElement(
        id: 'std_terms',
        type: 'text',
        x: 32,
        y: 658,
        w: 531,
        h: 120,
        fontSize: 8.0,
        text:
            'Terms & Conditions\n{{bank_details}}\n{{terms}}',
      ),
      CanvasElement(
        id: 'std_footer',
        type: 'text',
        x: 32,
        y: 790,
        w: 531,
        h: 24,
        fontSize: 8.5,
        bold: true,
        align: 'center',
        text: '{{branch_name}} | {{branch_address}} | {{branch_email}} | tel: {{branch_phone}}',
      ),
    ];
  }

  factory TemplateLayoutConfig.fromJson(Map<String, dynamic>? json, {String docType = 'QUOTATION'}) {
    if (json == null || json.isEmpty) {
      return TemplateLayoutConfig.defaultFor(docType);
    }
    final theme = (json['theme'] as Map<String, dynamic>?) ?? {};
    final header = (json['header'] as Map<String, dynamic>?) ?? {};
    final defaults = (json['defaults'] as Map<String, dynamic>?) ?? {};
    final formFields = (json['form_fields'] as Map<String, dynamic>?) ?? {};
    final rawFilled = (json['filled_fields'] as Map<String, dynamic>?) ?? {};
    final rawBlocks = json['blocks'] as List<dynamic>?;

    final parsedBlocks = rawBlocks != null && rawBlocks.isNotEmpty
        ? rawBlocks
            .asMap()
            .entries
            .where((e) => e.value is Map<String, dynamic>)
            .map((e) => TemplateBlockConfig.fromJson(e.value as Map<String, dynamic>, fallbackOrder: e.key))
            .toList()
        : TemplateLayoutConfig.defaultFor(docType).blocks;
    parsedBlocks.sort((a, b) => a.order.compareTo(b.order));

    return TemplateLayoutConfig(
      preset: json['preset']?.toString() ?? 'classic_corporate',
      primaryColorHex: theme['primary_color']?.toString() ?? '#1E3A8A',
      accentColorHex: theme['accent_color']?.toString() ?? '#059669',
      borderStyle: theme['border_style']?.toString() ?? 'solid',
      logoPosition: header['logo_position']?.toString() ?? 'left',
      branchId: header['branch_id']?.toString() ?? '',
      logoOverride: header['logo_override']?.toString() ?? '',
      showCompanyAddress: header['show_company_address'] == null ? true : header['show_company_address'] == true,
      showCrGstin: header['show_cr_gstin'] == null ? true : header['show_cr_gstin'] == true,
      titleOverride: header['title_override']?.toString() ?? '',
      numberPrefix: header['number_prefix']?.toString() ?? '',
      blocks: parsedBlocks,
      stamp: TemplateStampConfig.fromJson(json['stamp'] as Map<String, dynamic>?),
      showQty: defaults['show_qty'] == null ? true : defaults['show_qty'] == true,
      showPrice: defaults['show_price'] == null ? true : defaults['show_price'] == true,
      showTax: defaults['show_tax'] == null ? true : defaults['show_tax'] == true,
      hideCostInPdf: defaults['hide_cost_in_pdf'] == null ? true : defaults['hide_cost_in_pdf'] == true,
      includePodSlip: defaults['include_pod_slip'] == true,
      customColumns: (defaults['custom_columns'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      incoterms: defaults['incoterms']?.toString() ?? '',
      termsAndConditions: defaults['terms_and_conditions']?.toString() ?? '',
      notes: defaults['notes']?.toString() ?? '',
      bankDetailsText: defaults['bank_details_text']?.toString() ?? '',
      showClientCode: formFields['show_client_code'] == null ? true : formFields['show_client_code'] == true,
      showSalesRep: formFields['show_sales_rep'] == null ? true : formFields['show_sales_rep'] == true,
      showIncoterms: formFields['show_incoterms'] == null ? true : formFields['show_incoterms'] == true,
      showLocation: formFields['show_location'] == null ? true : formFields['show_location'] == true,
      showContactPerson: formFields['show_contact_person'] == null ? true : formFields['show_contact_person'] == true,
      showCrNumber: formFields['show_cr_number'] == null ? true : formFields['show_cr_number'] == true,
      showValidUntil: formFields['show_valid_until'] == null ? true : formFields['show_valid_until'] == true,
      customHeaderFields: (formFields['custom_header_fields'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      filledFields: rawFilled.map((k, v) => MapEntry(k.toString(), v?.toString() ?? '')),
      useCanvasMode: json['use_canvas_mode'] == true,
      canvasElements: (json['canvas_elements'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(CanvasElement.fromJson)
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'preset': preset,
        'use_canvas_mode': useCanvasMode,
        if (canvasElements.isNotEmpty)
          'canvas_elements': canvasElements.map((e) => e.toJson()).toList(),
        'theme': {
          'primary_color': primaryColorHex,
          'accent_color': accentColorHex,
          'border_style': borderStyle,
        },
        'header': {
          'logo_position': logoPosition,
          if (branchId.isNotEmpty) 'branch_id': branchId,
          if (logoOverride.isNotEmpty) 'logo_override': logoOverride,
          'show_company_address': showCompanyAddress,
          'show_cr_gstin': showCrGstin,
          'title_override': titleOverride,
          'number_prefix': numberPrefix,
        },
        'blocks': blocks
            .asMap()
            .entries
            .map((e) {
              e.value.order = e.key;
              return e.value.toJson();
            })
            .toList(),
        'stamp': stamp.toJson(),
        'defaults': {
          'show_qty': showQty,
          'show_price': showPrice,
          'show_tax': showTax,
          'hide_cost_in_pdf': hideCostInPdf,
          'include_pod_slip': includePodSlip,
          'custom_columns': customColumns,
          'incoterms': incoterms,
          'terms_and_conditions': termsAndConditions,
          'notes': notes,
          'bank_details_text': bankDetailsText,
        },
        'form_fields': {
          'show_client_code': showClientCode,
          'show_sales_rep': showSalesRep,
          'show_incoterms': showIncoterms,
          'show_location': showLocation,
          'show_contact_person': showContactPerson,
          'show_cr_number': showCrNumber,
          'show_valid_until': showValidUntil,
          'custom_header_fields': customHeaderFields,
        },
        if (filledFields.isNotEmpty) 'filled_fields': filledFields,
      };
}

class DocumentTemplateModel {
  final String id;
  final String name;
  final String docType; // 'QUOTATION', 'INVOICE', 'RECEIPT'
  final String branchId;
  final String branchName;
  final bool isDefault;
  final bool isActive;
  final TemplateLayoutConfig layout;
  final String createdByName;
  final String createdAt;

  DocumentTemplateModel({
    required this.id,
    required this.name,
    required this.docType,
    this.branchId = '',
    this.branchName = '',
    this.isDefault = false,
    this.isActive = true,
    required this.layout,
    this.createdByName = '',
    this.createdAt = '',
  });

  factory DocumentTemplateModel.fromJson(Map<String, dynamic> json) {
    final docType = json['doc_type']?.toString() ?? 'QUOTATION';
    final layout = TemplateLayoutConfig.fromJson(json['layout_json'] as Map<String, dynamic>?, docType: docType);
    final brId = json['branch']?.toString() ?? layout.branchId;
    return DocumentTemplateModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Untitled Template',
      docType: docType,
      branchId: brId,
      branchName: json['branch_name']?.toString() ?? '',
      isDefault: json['is_default'] == true,
      isActive: json['is_active'] == null ? true : json['is_active'] == true,
      layout: layout,
      createdByName: json['created_by_name']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}

