import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../models/recipe.dart';

class MealRepository {
  final ApiClient _api = ApiClient();

  // Recipes
  Future<List<Recipe>> getRecipes(String householdId) async {
    final response = await _api.get(ApiEndpoints.recipes(householdId));
    final list = response.data as List;
    return list
        .map((e) => Recipe.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Recipe> getRecipe(String householdId, String recipeId) async {
    final response =
        await _api.get(ApiEndpoints.recipe(householdId, recipeId));
    return Recipe.fromJson(response.data);
  }

  Future<Recipe> createRecipe(
      String householdId, Map<String, dynamic> data) async {
    final response =
        await _api.post(ApiEndpoints.recipes(householdId), data: data);
    return Recipe.fromJson(response.data);
  }

  Future<Recipe> updateRecipe(
      String householdId, String recipeId, Map<String, dynamic> data) async {
    final response = await _api
        .patch(ApiEndpoints.recipe(householdId, recipeId), data: data);
    return Recipe.fromJson(response.data);
  }

  Future<void> deleteRecipe(String householdId, String recipeId) async {
    await _api.delete(ApiEndpoints.recipe(householdId, recipeId));
  }

  // Meal Plan
  Future<List<MealPlan>> getMealPlan(
    String householdId, {
    required DateTime start,
    required DateTime end,
  }) async {
    final response = await _api.get(
      ApiEndpoints.mealPlan(householdId),
      queryParameters: {
        'start': start.toIso8601String().split('T').first,
        'end': end.toIso8601String().split('T').first,
      },
    );
    final list = response.data as List;
    return list
        .map((e) => MealPlan.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<MealPlan>> updateMealPlan(
    String householdId,
    List<Map<String, dynamic>> entries,
  ) async {
    final response = await _api.put(
      ApiEndpoints.mealPlan(householdId),
      data: {'entries': entries},
    );
    final list = response.data as List;
    return list
        .map((e) => MealPlan.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // Meal Requests
  Future<List<MealRequest>> getMealRequests(String householdId) async {
    final response = await _api.get(ApiEndpoints.mealRequests(householdId));
    final list = response.data as List;
    return list
        .map((e) => MealRequest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<MealRequest> createMealRequest(
      String householdId, Map<String, dynamic> data) async {
    final response =
        await _api.post(ApiEndpoints.mealRequests(householdId), data: data);
    return MealRequest.fromJson(response.data);
  }

  Future<MealRequest> updateMealRequest(
      String householdId, String requestId, Map<String, dynamic> data) async {
    final response = await _api.patch(
        ApiEndpoints.mealRequest(householdId, requestId),
        data: data);
    return MealRequest.fromJson(response.data);
  }

  Future<void> deleteMealRequest(
      String householdId, String requestId) async {
    await _api.delete(ApiEndpoints.mealRequest(householdId, requestId));
  }
}
