class ProductModel {
  final String id;
  final String name;
  final String description;
  final double unitPrice;
  final double taxPercent;
  final String unit;
  final bool isActive;

  ProductModel({
    required this.id,
    required this.name,
    this.description = '',
    this.unitPrice = 0.0,
    this.taxPercent = 18.0,
    this.unit = 'unit',
    this.isActive = true,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      unitPrice: double.tryParse(json['unit_price']?.toString() ?? '0') ?? 0.0,
      taxPercent: double.tryParse(json['tax_percent']?.toString() ?? '18') ?? 18.0,
      unit: json['unit']?.toString() ?? 'unit',
      isActive: json['is_active'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'unit_price': unitPrice,
      'tax_percent': taxPercent,
      'unit': unit,
      'is_active': isActive,
    };
  }
}

