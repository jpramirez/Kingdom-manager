import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../models/household.dart';

class HouseholdRepository {
  final ApiClient _api = ApiClient();

  Future<List<Household>> getMyHouseholds() async {
    final response = await _api.get(ApiEndpoints.households);
    final list = response.data as List;
    return list.map((e) => Household.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Household> createHousehold({required String name, String timezone = 'Asia/Singapore'}) async {
    final response = await _api.post(ApiEndpoints.households, data: {
      'name': name,
      'timezone': timezone,
    });
    return Household.fromJson(response.data);
  }

  Future<HouseholdMember> joinHousehold({required String inviteCode, String role = 'helper'}) async {
    final response = await _api.post(ApiEndpoints.joinHousehold, data: {
      'invite_code': inviteCode,
      'role': role,
    });
    return HouseholdMember.fromJson(response.data);
  }

  Future<List<HouseholdMember>> getMembers(String householdId) async {
    final response = await _api.get(ApiEndpoints.members(householdId));
    final list = response.data as List;
    return list.map((e) => HouseholdMember.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Household> refreshInviteCode(String householdId) async {
    final response = await _api.post(ApiEndpoints.refreshInvite(householdId));
    return Household.fromJson(response.data);
  }
}
