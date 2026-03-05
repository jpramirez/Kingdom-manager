import '../../../core/constants/enums.dart';

class InventoryItem {
  final String id;
  final String householdId;
  final String name;
  final double? quantity;
  final String? unit;
  final GroceryCategory category;
  final String? barcode;
  final DateTime? expiryDate;
  final InventoryLocation location;
  final String addedBy;
  final DateTime createdAt;

  InventoryItem({
    required this.id,
    required this.householdId,
    required this.name,
    this.quantity,
    this.unit,
    required this.category,
    this.barcode,
    this.expiryDate,
    required this.location,
    required this.addedBy,
    required this.createdAt,
  });

  bool get isExpired =>
      expiryDate != null && expiryDate!.isBefore(DateTime.now());

  bool get isExpiringSoon =>
      expiryDate != null &&
      !isExpired &&
      expiryDate!.isBefore(DateTime.now().add(const Duration(days: 3)));

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      id: json['id'] as String,
      householdId: json['household_id'] as String,
      name: json['name'] as String,
      quantity: (json['quantity'] as num?)?.toDouble(),
      unit: json['unit'] as String?,
      category:
          GroceryCategory.fromValue(json['category'] as String? ?? 'other'),
      barcode: json['barcode'] as String?,
      expiryDate: json['expiry_date'] != null
          ? DateTime.parse(json['expiry_date'] as String)
          : null,
      location: InventoryLocation.fromValue(
          json['location'] as String? ?? 'pantry'),
      addedBy: json['added_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (quantity != null) 'quantity': quantity,
      if (unit != null) 'unit': unit,
      'category': category.value,
      if (barcode != null) 'barcode': barcode,
      if (expiryDate != null)
        'expiry_date': expiryDate!.toIso8601String().split('T').first,
      'location': location.value,
    };
  }
}
