import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/inventory_item.dart';
import '../repositories/inventory_repository.dart';

final inventoryRepositoryProvider =
    Provider<InventoryRepository>((ref) => InventoryRepository());

final inventoryItemsProvider =
    FutureProvider.family<List<InventoryItem>, String>(
        (ref, householdId) async {
  return ref.read(inventoryRepositoryProvider).getItems(householdId);
});
