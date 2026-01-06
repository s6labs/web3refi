import 'package:equatable/equatable.dart';

/// A line item on an invoice
class InvoiceItem extends Equatable {
  /// Unique item identifier
  final String id;

  /// Item description
  final String description;

  /// Quantity of items
  final int quantity;

  /// Price per unit (in smallest token unit, e.g., wei for ETH, smallest unit for USDC)
  final BigInt unitPrice;

  /// Total price (quantity * unitPrice)
  final BigInt total;

  /// Optional SKU/product code
  final String? sku;

  /// Optional tax rate for this item (as percentage, e.g., 10.0 for 10%)
  final double? taxRate;

  /// Optional discount amount (in smallest token unit)
  final BigInt? discount;

  /// Optional discount percentage
  final double? discountPercentage;

  /// Optional category/type
  final String? category;

  /// Optional unit of measurement
  final String? unit;

  /// Optional notes for this line item
  final String? notes;

  /// Custom metadata
  final Map<String, dynamic>? metadata;

  const InvoiceItem({
    required this.id,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.total,
    this.sku,
    this.taxRate,
    this.discount,
    this.discountPercentage,
    this.category,
    this.unit,
    this.notes,
    this.metadata,
  });

  /// Create item with auto-calculated total
  factory InvoiceItem.create({
    required String description,
    required int quantity,
    required BigInt unitPrice,
    String? id,
    String? sku,
    double? taxRate,
    BigInt? discount,
    double? discountPercentage,
    String? category,
    String? unit,
    String? notes,
    Map<String, dynamic>? metadata,
  }) {
    final itemId = id ?? DateTime.now().millisecondsSinceEpoch.toString();
    BigInt total = unitPrice * BigInt.from(quantity);

    // Apply discount
    if (discount != null) {
      total -= discount;
    } else if (discountPercentage != null) {
      final discountAmount = (total.toDouble() * discountPercentage / 100.0).round();
      total -= BigInt.from(discountAmount);
    }

    return InvoiceItem(
      id: itemId,
      description: description,
      quantity: quantity,
      unitPrice: unitPrice,
      total: total > BigInt.zero ? total : BigInt.zero,
      sku: sku,
      taxRate: taxRate,
      discount: discount,
      discountPercentage: discountPercentage,
      category: category,
      unit: unit,
      notes: notes,
      metadata: metadata,
    );
  }

  /// Calculate total with tax
  BigInt get totalWithTax {
    if (taxRate == null || taxRate == 0) return total;
    final taxAmount = (total.toDouble() * taxRate! / 100.0).round();
    return total + BigInt.from(taxAmount);
  }

  /// Calculate tax amount
  BigInt get taxAmount {
    if (taxRate == null || taxRate == 0) return BigInt.zero;
    return BigInt.from((total.toDouble() * taxRate! / 100.0).round());
  }

  /// Copy with modifications
  InvoiceItem copyWith({
    String? id,
    String? description,
    int? quantity,
    BigInt? unitPrice,
    BigInt? total,
    String? sku,
    double? taxRate,
    BigInt? discount,
    double? discountPercentage,
    String? category,
    String? unit,
    String? notes,
    Map<String, dynamic>? metadata,
  }) {
    return InvoiceItem(
      id: id ?? this.id,
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      total: total ?? this.total,
      sku: sku ?? this.sku,
      taxRate: taxRate ?? this.taxRate,
      discount: discount ?? this.discount,
      discountPercentage: discountPercentage ?? this.discountPercentage,
      category: category ?? this.category,
      unit: unit ?? this.unit,
      notes: notes ?? this.notes,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'description': description,
      'quantity': quantity,
      'unitPrice': unitPrice.toString(),
      'total': total.toString(),
      if (sku != null) 'sku': sku,
      if (taxRate != null) 'taxRate': taxRate,
      if (discount != null) 'discount': discount.toString(),
      if (discountPercentage != null) 'discountPercentage': discountPercentage,
      if (category != null) 'category': category,
      if (unit != null) 'unit': unit,
      if (notes != null) 'notes': notes,
      if (metadata != null) 'metadata': metadata,
    };
  }

  /// Create from JSON
  factory InvoiceItem.fromJson(Map<String, dynamic> json) {
    return InvoiceItem(
      id: json['id'] as String,
      description: json['description'] as String,
      quantity: json['quantity'] as int,
      unitPrice: BigInt.parse(json['unitPrice'] as String),
      total: BigInt.parse(json['total'] as String),
      sku: json['sku'] as String?,
      taxRate: json['taxRate'] as double?,
      discount: json['discount'] != null ? BigInt.parse(json['discount'] as String) : null,
      discountPercentage: json['discountPercentage'] as double?,
      category: json['category'] as String?,
      unit: json['unit'] as String?,
      notes: json['notes'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  @override
  List<Object?> get props => [
        id,
        description,
        quantity,
        unitPrice,
        total,
        sku,
        taxRate,
        discount,
        discountPercentage,
        category,
        unit,
        notes,
        metadata,
      ];

  @override
  String toString() {
    return 'InvoiceItem(id: $id, description: $description, qty: $quantity, price: $unitPrice, total: $total)';
  }
}
