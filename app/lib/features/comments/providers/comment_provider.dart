import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/comment.dart';
import '../repositories/comment_repository.dart';

final commentRepositoryProvider =
    Provider<CommentRepository>((ref) => CommentRepository());

class CommentParams {
  final String householdId;
  final String entityType;
  final String entityId;

  CommentParams({
    required this.householdId,
    required this.entityType,
    required this.entityId,
  });

  @override
  bool operator ==(Object other) =>
      other is CommentParams &&
      householdId == other.householdId &&
      entityType == other.entityType &&
      entityId == other.entityId;

  @override
  int get hashCode => Object.hash(householdId, entityType, entityId);
}

final commentsProvider =
    FutureProvider.family<List<Comment>, CommentParams>((ref, params) async {
  return ref.read(commentRepositoryProvider).getComments(
        params.householdId,
        params.entityType,
        params.entityId,
      );
});
