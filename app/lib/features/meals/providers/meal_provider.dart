import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/recipe.dart';
import '../repositories/meal_repository.dart';

final mealRepositoryProvider =
    Provider<MealRepository>((ref) => MealRepository());

final recipesProvider =
    FutureProvider.family<List<Recipe>, String>((ref, householdId) async {
  return ref.read(mealRepositoryProvider).getRecipes(householdId);
});

class MealPlanParams {
  final String householdId;
  final DateTime start;
  final DateTime end;

  MealPlanParams({
    required this.householdId,
    required this.start,
    required this.end,
  });

  @override
  bool operator ==(Object other) =>
      other is MealPlanParams &&
      householdId == other.householdId &&
      start == other.start &&
      end == other.end;

  @override
  int get hashCode => Object.hash(householdId, start, end);
}

final mealPlanProvider =
    FutureProvider.family<List<MealPlan>, MealPlanParams>(
        (ref, params) async {
  return ref.read(mealRepositoryProvider).getMealPlan(
        params.householdId,
        start: params.start,
        end: params.end,
      );
});

final mealRequestsProvider =
    FutureProvider.family<List<MealRequest>, String>((ref, householdId) async {
  return ref.read(mealRepositoryProvider).getMealRequests(householdId);
});
