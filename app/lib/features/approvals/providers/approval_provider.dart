import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/approval.dart';
import '../repositories/approval_repository.dart';

final approvalRepositoryProvider =
    Provider<ApprovalRepository>((ref) => ApprovalRepository());

final pendingApprovalsProvider =
    FutureProvider.family<List<ApprovalRequest>, String>(
        (ref, householdId) async {
  return ref.read(approvalRepositoryProvider).getPendingApprovals(householdId);
});

final allApprovalsProvider =
    FutureProvider.family<List<ApprovalRequest>, String>(
        (ref, householdId) async {
  return ref.read(approvalRepositoryProvider).getApprovals(householdId);
});
