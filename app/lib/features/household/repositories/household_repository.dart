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

  Future<Household> createHousehold({
    required String name,
    String timezone = 'Asia/Singapore',
    String creatorRole = 'family_adult',
  }) async {
    final response = await _api.post(ApiEndpoints.households, data: {
      'name': name,
      'timezone': timezone,
      'creator_role': creatorRole,
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

  Future<void> updateMember(
    String householdId,
    String memberId, {
    String? role,
    String? nickname,
    bool? isAdmin,
  }) async {
    final data = <String, dynamic>{};
    if (role != null) data['role'] = role;
    if (nickname != null) data['nickname'] = nickname;
    if (isAdmin != null) data['is_admin'] = isAdmin;
    await _api.patch(ApiEndpoints.member(householdId, memberId), data: data);
  }

  Future<void> removeMember(String householdId, String memberId) async {
    await _api.delete(ApiEndpoints.member(householdId, memberId));
  }

  Future<Household> updateHousehold(String householdId, Map<String, dynamic> data) async {
    final response = await _api.patch(ApiEndpoints.household(householdId), data: data);
    return Household.fromJson(response.data);
  }

  Future<Household> refreshInviteCode(String householdId) async {
    final response = await _api.post(ApiEndpoints.refreshInvite(householdId));
    return Household.fromJson(response.data);
  }
}
