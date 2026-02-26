import 'package:flutter/material.dart';
import '../../../core/constants/enums.dart';
import '../models/approval.dart';

class ApprovalCard extends StatelessWidget {
  final ApprovalRequest approval;
  final bool canApprove;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  const ApprovalCard({
    super.key,
    required this.approval,
    this.canApprove = false,
    this.onApprove,
    this.onReject,
  });

  IconData _requestTypeIcon(String requestType) {
    switch (requestType) {
      case 'grocery':
        return Icons.shopping_cart;
      case 'meal':
        return Icons.restaurant_menu;
      case 'chore':
        return Icons.checklist;
      case 'event':
        return Icons.event;
      case 'purchase':
        return Icons.shopping_bag;
      case 'outing':
        return Icons.directions_walk;
      default:
        return Icons.approval;
    }
  }

  String _requestTypeLabel(String requestType) {
    switch (requestType) {
      case 'grocery':
        return 'Grocery';
      case 'meal':
        return 'Meal';
      case 'chore':
        return 'Chore';
      case 'event':
        return 'Event';
      case 'purchase':
        return 'Purchase';
      case 'outing':
        return 'Outing';
      default:
        return requestType.substring(0, 1).toUpperCase() +
            requestType.substring(1);
    }
  }

  Color _statusColor(ApprovalStatus status) {
    switch (status) {
      case ApprovalStatus.pending:
        return Colors.orange;
      case ApprovalStatus.approved:
        return Colors.green;
      case ApprovalStatus.rejected:
        return Colors.red;
    }
  }

  String _statusLabel(ApprovalStatus status) {
    switch (status) {
      case ApprovalStatus.pending:
        return 'Pending';
      case ApprovalStatus.approved:
        return 'Approved';
      case ApprovalStatus.rejected:
        return 'Rejected';
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(approval.status);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: statusColor, width: 4),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _requestTypeIcon(approval.requestType),
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      approval.title,
                      style:
                          Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _statusLabel(approval.status),
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ),
              if (approval.description != null &&
                  approval.description!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  approval.description!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.label_outline,
                      size: 14,
                      color: Theme.of(context).colorScheme.outline),
                  const SizedBox(width: 4),
                  Text(
                    _requestTypeLabel(approval.requestType),
                    style:
                        Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.person_outline,
                      size: 14,
                      color: Theme.of(context).colorScheme.outline),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      approval.requesterName ?? 'Unknown',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    _formatDate(approval.createdAt),
                    style:
                        Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                  ),
                ],
              ),
              if (approval.status != ApprovalStatus.pending &&
                  approval.approverName != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      approval.status == ApprovalStatus.approved
                          ? Icons.check_circle_outline
                          : Icons.cancel_outlined,
                      size: 14,
                      color: statusColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${_statusLabel(approval.status)} by ${approval.approverName}',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(
                            color: statusColor,
                          ),
                    ),
                  ],
                ),
              ],
              if (canApprove &&
                  approval.status == ApprovalStatus.pending) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: onReject,
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: onApprove,
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Approve'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) return 'Today';
    if (dateOnly == today.subtract(const Duration(days: 1))) return 'Yesterday';

    return '${date.day}/${date.month}/${date.year}';
  }
}
