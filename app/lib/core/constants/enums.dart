enum UserRole {
  familyAdult('family_adult'),
  familyKid('family_kid'),
  helper('helper');

  final String value;
  const UserRole(this.value);

  static UserRole fromValue(String value) {
    return UserRole.values.firstWhere(
      (e) => e.value == value,
      orElse: () => UserRole.helper,
    );
  }
}

// Used for assignment statuses
enum ChoreStatus {
  pending('pending'),
  inProgress('in_progress'),
  completed('completed'),
  skipped('skipped'),
  // Chore-level statuses
  active('active'),
  paused('paused'),
  archived('archived');

  final String value;
  const ChoreStatus(this.value);

  static ChoreStatus fromValue(String value) {
    return ChoreStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ChoreStatus.active,
    );
  }
}

enum ChorePriority {
  low('low'),
  medium('medium'),
  high('high');

  final String value;
  const ChorePriority(this.value);

  static ChorePriority fromValue(String value) {
    return ChorePriority.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ChorePriority.medium,
    );
  }
}

enum ChoreCategory {
  cleaning('cleaning'),
  cooking('cooking'),
  laundry('laundry'),
  childcare('childcare'),
  errands('errands'),
  other('other');

  final String value;
  const ChoreCategory(this.value);

  static ChoreCategory fromValue(String value) {
    return ChoreCategory.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ChoreCategory.other,
    );
  }
}

enum ApprovalStatus {
  pending('pending'),
  approved('approved'),
  rejected('rejected');

  final String value;
  const ApprovalStatus(this.value);

  static ApprovalStatus fromValue(String value) {
    return ApprovalStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ApprovalStatus.pending,
    );
  }
}

enum GroceryCategory {
  produce('produce'),
  dairy('dairy'),
  meat('meat'),
  pantry('pantry'),
  frozen('frozen'),
  household('household'),
  other('other');

  final String value;
  const GroceryCategory(this.value);

  static GroceryCategory fromValue(String value) {
    return GroceryCategory.values.firstWhere(
      (e) => e.value == value,
      orElse: () => GroceryCategory.other,
    );
  }
}

enum InventoryLocation {
  fridge('fridge'),
  freezer('freezer'),
  pantry('pantry');

  final String value;
  const InventoryLocation(this.value);

  static InventoryLocation fromValue(String value) {
    return InventoryLocation.values.firstWhere(
      (e) => e.value == value,
      orElse: () => InventoryLocation.pantry,
    );
  }
}

enum MealType {
  breakfast('breakfast'),
  lunch('lunch'),
  dinner('dinner'),
  snack('snack');

  final String value;
  const MealType(this.value);

  static MealType fromValue(String value) {
    return MealType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => MealType.dinner,
    );
  }
}
