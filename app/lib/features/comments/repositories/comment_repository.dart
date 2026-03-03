import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../models/comment.dart';

class CommentRepository {
  final ApiClient _api = ApiClient();

  Future<List<Comment>> getComments(
      String householdId, String entityType, String entityId) async {
    final response = await _api.get(
        ApiEndpoints.comments(householdId, entityType, entityId));
    final list = response.data as List;
    return list
        .map((e) => Comment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Comment> createComment(
      String householdId, String entityType, String entityId, String text) async {
    final response = await _api.post(
      ApiEndpoints.comments(householdId, entityType, entityId),
      data: {'text': text},
    );
    return Comment.fromJson(response.data);
  }

  Future<void> deleteComment(String householdId, String commentId) async {
    await _api.delete(ApiEndpoints.comment(householdId, commentId));
  }
}
