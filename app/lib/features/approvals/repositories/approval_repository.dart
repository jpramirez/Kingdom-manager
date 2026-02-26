import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../models/approval.dart';

class ApprovalRepository {
  final ApiClient _api = ApiClient();

  Future<List<ApprovalRequest>> getApprovals(String householdId) async {
    final response = await _api.get(ApiEndpoints.approvals(householdId));
    final list = response.data as List;
    return list
        .map((e) => ApprovalRequest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<ApprovalRequest>> getPendingApprovals(
      String householdId) async {
    final response = await _api.get(
      ApiEndpoints.approvals(householdId),
      queryParameters: {'status': 'pending'},
    );
    final list = response.data as List;
    return list
        .map((e) => ApprovalRequest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ApprovalRequest> createApproval(
      String householdId, Map<String, dynamic> data) async {
    final response =
        await _api.post(ApiEndpoints.approvals(householdId), data: data);
    return ApprovalRequest.fromJson(response.data);
  }

  Future<ApprovalRequest> approveRequest(
      String householdId, String approvalId) async {
    final response = await _api.post(
        ApiEndpoints.approvalApprove(householdId, approvalId));
    return ApprovalRequest.fromJson(response.data);
  }

  Future<ApprovalRequest> rejectRequest(
      String householdId, String approvalId,
      {String? reason}) async {
    final data = <String, dynamic>{};
    if (reason != null) data['reason'] = reason;
    final response = await _api.post(
        ApiEndpoints.approvalReject(householdId, approvalId),
        data: data.isNotEmpty ? data : null);
    return ApprovalRequest.fromJson(response.data);
  }
}
