import 'package:flutter/material.dart';
import '../../../core/constants/enums.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../models/chore.dart';

class ChoreCard extends StatelessWidget {
  final Chore chore;
  final VoidCallback? onTap;

  const ChoreCard({
    super.key,
    required this.chore,
    this.onTap,
  });

  IconData _categoryIcon(ChoreCategory category) {
    switch (category) {
      case ChoreCategory.cleaning:
        return Icons.cleaning_services;
      case ChoreCategory.cooking:
        return Icons.restaurant;
      case ChoreCategory.laundry:
        return Icons.local_laundry_service;
      case ChoreCategory.childcare:
        return Icons.child_care;
      case ChoreCategory.errands:
        return Icons.directions_run;
      case ChoreCategory.other:
        return Icons.task_alt;
    }
  }

  Color _priorityColor(BuildContext context, ChorePriority priority) {
    switch (priority) {
      case ChorePriority.low:
        return Colors.green;
      case ChorePriority.medium:
        return Colors.orange;
      case ChorePriority.high:
        return Colors.red;
    }
  }

  String _categoryLabel(BuildContext context, ChoreCategory category) {
    final l10n = AppLocalizations.of(context)!;
    switch (category) {
      case ChoreCategory.cleaning:
        return l10n.cleaning;
      case ChoreCategory.cooking:
        return l10n.cooking;
      case ChoreCategory.laundry:
        return l10n.laundry;
      case ChoreCategory.childcare:
        return l10n.childcare;
      case ChoreCategory.errands:
        return l10n.errands;
      case ChoreCategory.other:
        return l10n.other;
    }
  }

  String _priorityLabel(BuildContext context, ChorePriority priority) {
    final l10n = AppLocalizations.of(context)!;
    switch (priority) {
      case ChorePriority.low:
        return l10n.low;
      case ChorePriority.medium:
        return l10n.medium;
      case ChorePriority.high:
        return l10n.high;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final priorityColor = _priorityColor(context, chore.priority);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: priorityColor, width: 4),
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
                      _categoryIcon(chore.category),
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        chore.title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
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
                        color: priorityColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _priorityLabel(context, chore.priority),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: priorityColor,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ],
                ),
                if (chore.description != null &&
                    chore.description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    chore.description!,
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
                      _categoryLabel(context, chore.category),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                    if (chore.dueDate != null) ...[
                      const SizedBox(width: 12),
                      Icon(Icons.schedule,
                          size: 14,
                          color: Theme.of(context).colorScheme.outline),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(chore.dueDate!),
                        style:
                            Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: _isOverdue(chore.dueDate!)
                                      ? Colors.red
                                      : Theme.of(context).colorScheme.outline,
                                ),
                      ),
                    ],
                    if (chore.estimatedMinutes != null) ...[
                      const SizedBox(width: 12),
                      Icon(Icons.timer_outlined,
                          size: 14,
                          color: Theme.of(context).colorScheme.outline),
                      const SizedBox(width: 4),
                      Text(
                        '${chore.estimatedMinutes} ${l10n.minutesShort}',
                        style:
                            Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
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
    if (dateOnly == today.add(const Duration(days: 1))) return 'Tomorrow';

    return '${date.day}/${date.month}/${date.year}';
  }

  bool _isOverdue(DateTime date) {
    return date.isBefore(DateTime.now());
  }
}
