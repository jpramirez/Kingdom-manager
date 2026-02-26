import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/grocery.dart';
import '../repositories/grocery_repository.dart';

final groceryRepositoryProvider =
    Provider<GroceryRepository>((ref) => GroceryRepository());

final groceryListsProvider =
    FutureProvider.family<List<GroceryList>, String>((ref, householdId) async {
  return ref.read(groceryRepositoryProvider).getLists(householdId);
});

class GroceryItemsParams {
  final String householdId;
  final String listId;

  GroceryItemsParams({required this.householdId, required this.listId});

  @override
  bool operator ==(Object other) =>
      other is GroceryItemsParams &&
      householdId == other.householdId &&
      listId == other.listId;

  @override
  int get hashCode => Object.hash(householdId, listId);
}

final groceryItemsProvider =
    FutureProvider.family<List<GroceryItem>, GroceryItemsParams>(
        (ref, params) async {
  return ref
      .read(groceryRepositoryProvider)
      .getItems(params.householdId, params.listId);
});
