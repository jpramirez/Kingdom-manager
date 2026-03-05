import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../models/inventory_item.dart';

class InventoryRepository {
  final ApiClient _api = ApiClient();

  Future<List<InventoryItem>> getItems(
    String householdId, {
    String? location,
  }) async {
    final response = await _api.get(
      ApiEndpoints.inventory(householdId),
      queryParameters: {
        if (location != null) 'location': location,
      },
    );
    final list = response.data as List;
    return list
        .map((e) => InventoryItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<InventoryItem> createItem(
      String householdId, Map<String, dynamic> data) async {
    final response =
        await _api.post(ApiEndpoints.inventory(householdId), data: data);
    return InventoryItem.fromJson(response.data);
  }

  Future<InventoryItem> updateItem(
      String householdId, String itemId, Map<String, dynamic> data) async {
    final response = await _api
        .patch(ApiEndpoints.inventoryItem(householdId, itemId), data: data);
    return InventoryItem.fromJson(response.data);
  }

  Future<void> deleteItem(String householdId, String itemId) async {
    await _api.delete(ApiEndpoints.inventoryItem(householdId, itemId));
  }

  Future<List<InventoryItem>> searchByBarcode(
      String householdId, String barcode) async {
    final response =
        await _api.get(ApiEndpoints.inventoryBarcode(householdId, barcode));
    final list = response.data as List;
    return list
        .map((e) => InventoryItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<InventoryItem> groceryToInventory(
    String householdId, {
    required String groceryItemId,
    required String listId,
    required String location,
  }) async {
    final response = await _api.post(
      ApiEndpoints.inventoryFromGrocery(householdId),
      data: {
        'grocery_item_id': groceryItemId,
        'list_id': listId,
        'location': location,
      },
    );
    return InventoryItem.fromJson(response.data);
  }
}
