import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../models/chore.dart';

class ChoreRepository {
  final ApiClient _api = ApiClient();

  Future<List<Chore>> getChores(String householdId) async {
    final response = await _api.get(ApiEndpoints.chores(householdId));
    final list = response.data as List;
    return list.map((e) => Chore.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Chore> createChore(
      String householdId, Map<String, dynamic> data) async {
    final response =
        await _api.post(ApiEndpoints.chores(householdId), data: data);
    return Chore.fromJson(response.data);
  }

  Future<Chore> updateChore(
      String householdId, String choreId, Map<String, dynamic> data) async {
    final response =
        await _api.patch(ApiEndpoints.chore(householdId, choreId), data: data);
    return Chore.fromJson(response.data);
  }

  Future<void> deleteChore(String householdId, String choreId) async {
    await _api.delete(ApiEndpoints.chore(householdId, choreId));
  }

  Future<ChoreAssignment> assignChore(
      String householdId, String choreId, Map<String, dynamic> data) async {
    final response = await _api.post(
        ApiEndpoints.choreAssignments(householdId, choreId),
        data: data);
    return ChoreAssignment.fromJson(response.data);
  }

  Future<ChoreAssignment> completeAssignment(
    String householdId,
    String assignmentId, {
    String? photoUrl,
    String? notes,
  }) async {
    final data = <String, dynamic>{
      'status': 'completed',
    };
    if (photoUrl != null) data['photo_url'] = photoUrl;
    if (notes != null) data['notes'] = notes;
    final response = await _api.patch(
        ApiEndpoints.assignment(householdId, assignmentId),
        data: data);
    return ChoreAssignment.fromJson(response.data);
  }

  Future<List<ChoreAssignment>> getMyAssignments(String householdId) async {
    final response =
        await _api.get(ApiEndpoints.myAssignments(householdId));
    final list = response.data as List;
    return list
        .map((e) => ChoreAssignment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<ChoreAssignment>> getTodayAssignments(
      String householdId) async {
    final response =
        await _api.get(ApiEndpoints.todayAssignments(householdId));
    final list = response.data as List;
    return list
        .map((e) => ChoreAssignment.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
