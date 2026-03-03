import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../models/family_profile.dart';

class FamilyProfileRepository {
  final ApiClient _api = ApiClient();

  Future<List<FamilyProfile>> getFamily(String householdId) async {
    final response = await _api.get(ApiEndpoints.family(householdId));
    final list = response.data as List;
    return list
        .map((e) => FamilyProfile.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<FamilyProfile>> getProfiles(String householdId) async {
    final response =
        await _api.get(ApiEndpoints.familyProfiles(householdId));
    final list = response.data as List;
    return list
        .map((e) => FamilyProfile.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<FamilyProfile> createProfile(
      String householdId, Map<String, dynamic> data) async {
    final response =
        await _api.post(ApiEndpoints.familyProfiles(householdId), data: data);
    return FamilyProfile.fromJson(response.data);
  }

  Future<FamilyProfile> updateProfile(
      String householdId, String profileId, Map<String, dynamic> data) async {
    final response = await _api.patch(
        ApiEndpoints.familyProfile(householdId, profileId),
        data: data);
    return FamilyProfile.fromJson(response.data);
  }

  Future<void> deleteProfile(String householdId, String profileId) async {
    await _api.delete(
        ApiEndpoints.familyProfile(householdId, profileId));
  }
}
