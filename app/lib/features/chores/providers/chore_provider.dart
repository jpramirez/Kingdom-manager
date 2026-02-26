import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chore.dart';
import '../repositories/chore_repository.dart';

final choreRepositoryProvider =
    Provider<ChoreRepository>((ref) => ChoreRepository());

final choresProvider =
    FutureProvider.family<List<Chore>, String>((ref, householdId) async {
  return ref.read(choreRepositoryProvider).getChores(householdId);
});

final myAssignmentsProvider = FutureProvider.family<List<ChoreAssignment>,
    String>((ref, householdId) async {
  return ref.read(choreRepositoryProvider).getMyAssignments(householdId);
});

final todayAssignmentsProvider = FutureProvider.family<List<ChoreAssignment>,
    String>((ref, householdId) async {
  return ref.read(choreRepositoryProvider).getTodayAssignments(householdId);
});
