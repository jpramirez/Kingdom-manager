import '../../../core/constants/enums.dart';

class GroceryList {
  final String id;
  final String householdId;
  final String name;
  final DateTime? deliveryDate;
  final String status;
  final String createdBy;
  final DateTime createdAt;
  final int itemCount;
  final int checkedCount;

  GroceryList({
    required this.id,
    required this.householdId,
    required this.name,
    this.deliveryDate,
    required this.status,
    required this.createdBy,
    required this.createdAt,
    this.itemCount = 0,
    this.checkedCount = 0,
  });

  double get progress => itemCount > 0 ? checkedCount / itemCount : 0;

  factory GroceryList.fromJson(Map<String, dynamic> json) {
    return GroceryList(
      id: json['id'] as String,
      householdId: json['household_id'] as String,
      name: json['name'] as String,
      deliveryDate: json['delivery_date'] != null
          ? DateTime.parse(json['delivery_date'] as String)
          : null,
      status: json['status'] as String? ?? 'active',
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      itemCount: json['item_count'] as int? ?? 0,
      checkedCount: json['checked_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (deliveryDate != null)
        'delivery_date': deliveryDate!.toIso8601String().split('T').first,
    };
  }
}

class GroceryItem {
  final String id;
  final String listId;
  final String name;
  final double? quantity;
  final String? unit;
  final GroceryCategory category;
  final bool isChecked;
  final String addedBy;
  final String? checkedBy;
  final String? notes;
  final int sortOrder;
  final DateTime createdAt;

  GroceryItem({
    required this.id,
    required this.listId,
    required this.name,
    this.quantity,
    this.unit,
    required this.category,
    required this.isChecked,
    required this.addedBy,
    this.checkedBy,
    this.notes,
    required this.sortOrder,
    required this.createdAt,
  });

  factory GroceryItem.fromJson(Map<String, dynamic> json) {
    return GroceryItem(
      id: json['id'] as String,
      listId: json['list_id'] as String,
      name: json['name'] as String,
      quantity: (json['quantity'] as num?)?.toDouble(),
      unit: json['unit'] as String?,
      category: GroceryCategory.fromValue(json['category'] as String? ?? 'other'),
      isChecked: json['is_checked'] as bool? ?? false,
      addedBy: json['added_by'] as String,
      checkedBy: json['checked_by'] as String?,
      notes: json['notes'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'category': category.value,
      'notes': notes,
    };
  }
}
