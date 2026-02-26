import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../models/grocery.dart';

class GroceryRepository {
  final ApiClient _api = ApiClient();

  // Lists
  Future<List<GroceryList>> getLists(String householdId) async {
    final response = await _api.get(ApiEndpoints.groceryLists(householdId));
    final list = response.data as List;
    return list
        .map((e) => GroceryList.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<GroceryList> createList(
      String householdId, Map<String, dynamic> data) async {
    final response =
        await _api.post(ApiEndpoints.groceryLists(householdId), data: data);
    return GroceryList.fromJson(response.data);
  }

  Future<GroceryList> updateList(
      String householdId, String listId, Map<String, dynamic> data) async {
    final response = await _api
        .patch(ApiEndpoints.groceryList(householdId, listId), data: data);
    return GroceryList.fromJson(response.data);
  }

  Future<void> deleteList(String householdId, String listId) async {
    await _api.delete(ApiEndpoints.groceryList(householdId, listId));
  }

  // Items
  Future<List<GroceryItem>> getItems(
      String householdId, String listId) async {
    final response =
        await _api.get(ApiEndpoints.groceryItems(householdId, listId));
    final list = response.data as List;
    return list
        .map((e) => GroceryItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<GroceryItem> addItem(
      String householdId, String listId, Map<String, dynamic> data) async {
    final response = await _api
        .post(ApiEndpoints.groceryItems(householdId, listId), data: data);
    return GroceryItem.fromJson(response.data);
  }

  Future<GroceryItem> updateItem(
    String householdId,
    String listId,
    String itemId,
    Map<String, dynamic> data,
  ) async {
    final response = await _api.patch(
        ApiEndpoints.groceryItem(householdId, listId, itemId),
        data: data);
    return GroceryItem.fromJson(response.data);
  }

  Future<void> removeItem(
      String householdId, String listId, String itemId) async {
    await _api
        .delete(ApiEndpoints.groceryItem(householdId, listId, itemId));
  }

  Future<GroceryItem> toggleItem(
    String householdId,
    String listId,
    String itemId,
    bool isChecked,
  ) async {
    return updateItem(householdId, listId, itemId, {
      'is_checked': isChecked,
    });
  }
}
