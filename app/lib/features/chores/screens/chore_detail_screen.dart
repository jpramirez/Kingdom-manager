import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/enums.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../household/models/household.dart';
import '../../household/providers/household_provider.dart';
import '../models/chore.dart';
import '../providers/chore_provider.dart';

class ChoreDetailScreen extends ConsumerStatefulWidget {
  final String choreId;
  const ChoreDetailScreen({super.key, required this.choreId});

  @override
  ConsumerState<ChoreDetailScreen> createState() => _ChoreDetailScreenState();
}

class _ChoreDetailScreenState extends ConsumerState<ChoreDetailScreen> {
  Widget _backButton(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/chores');
        }
      },
    );
  }

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

  Color _priorityColor(ChorePriority priority) {
    switch (priority) {
      case ChorePriority.low:
        return Colors.green;
      case ChorePriority.medium:
        return Colors.orange;
      case ChorePriority.high:
        return Colors.red;
    }
  }

  String _statusLabel(BuildContext context, ChoreStatus status) {
    final l10n = AppLocalizations.of(context)!;
    switch (status) {
      case ChoreStatus.pending:
        return l10n.pending;
      case ChoreStatus.inProgress:
        return l10n.inProgress;
      case ChoreStatus.completed:
        return l10n.completed;
      case ChoreStatus.skipped:
        return l10n.skipped;
      case ChoreStatus.active:
        return l10n.active;
      case ChoreStatus.paused:
        return l10n.paused;
      case ChoreStatus.archived:
        return l10n.archived;
    }
  }

  Color _statusColor(ChoreStatus status) {
    switch (status) {
      case ChoreStatus.pending:
        return Colors.orange;
      case ChoreStatus.inProgress:
        return Colors.blue;
      case ChoreStatus.completed:
        return Colors.green;
      case ChoreStatus.skipped:
        return Colors.grey;
      case ChoreStatus.active:
        return Colors.green;
      case ChoreStatus.paused:
        return Colors.amber;
      case ChoreStatus.archived:
        return Colors.grey;
    }
  }

  Future<void> _showAssignDialog(
      String householdId, String choreId, List<HouseholdMember> members) async {
    final l10n = AppLocalizations.of(context)!;
    String? selectedMemberId;
    DateTime selectedDate = DateTime.now();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(l10n.assignChore),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.selectMember),
              const SizedBox(height: 12),
              RadioGroup<String>(
                groupValue: selectedMemberId ?? '',
                onChanged: (value) {
                  setDialogState(() => selectedMemberId = value);
                },
                child: Column(
                  children: members.map((member) => RadioListTile<String>(
                    title: Text(member.nickname ?? member.displayName),
                    subtitle: Text(member.role.replaceAll('_', ' ')),
                    value: member.userId,
                  )).toList(),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: Text(l10n.dueDate),
                subtitle: Text('${selectedDate.day}/${selectedDate.month}/${selectedDate.year}'),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setDialogState(() => selectedDate = picked);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: selectedMemberId == null
                  ? null
                  : () async {
                      Navigator.of(ctx).pop();
                      try {
                        await ref
                            .read(choreRepositoryProvider)
                            .assignChore(householdId, choreId, {
                          'assigned_to': selectedMemberId,
                          'due_date': '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                        });
                        ref.invalidate(choresProvider(householdId));
                        ref.invalidate(myAssignmentsProvider(householdId));
                        ref.invalidate(todayAssignmentsProvider(householdId));
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.choreAssigned)),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      }
                    },
              child: Text(l10n.assignTo),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCompleteDialog(
      String householdId, ChoreAssignment assignment) async {
    final l10n = AppLocalizations.of(context)!;
    final notesController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.markComplete),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: notesController,
              decoration: InputDecoration(
                labelText: l10n.addNotes,
                border: const OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await ref
                    .read(choreRepositoryProvider)
                    .completeAssignment(
                  householdId,
                  assignment.id,
                  notes: notesController.text.trim().isNotEmpty
                      ? notesController.text.trim()
                      : null,
                );
                ref.invalidate(choresProvider(householdId));
                ref.invalidate(myAssignmentsProvider(householdId));
                ref.invalidate(todayAssignmentsProvider(householdId));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.assignmentCompleted)),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: Text(l10n.done),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteChore(String householdId, String choreId) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.delete),
        content: Text(l10n.deleteChoreConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref
            .read(choreRepositoryProvider)
            .deleteChore(householdId, choreId);
        ref.invalidate(choresProvider(householdId));
        ref.invalidate(myAssignmentsProvider(householdId));
        ref.invalidate(todayAssignmentsProvider(householdId));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.choreDeleted)),
          );
          context.pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final household = ref.watch(activeHouseholdProvider).household;

    if (household == null) {
      return Scaffold(
        appBar: AppBar(
          leading: _backButton(context),
          title: Text(l10n.choreDetails),
        ),
        body: const Center(child: Text('No household selected')),
      );
    }

    final choresAsync = ref.watch(choresProvider(household.id));
    final membersAsync = ref.watch(membersProvider(household.id));

    return choresAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(
          leading: _backButton(context),
          title: Text(l10n.choreDetails),
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(
          leading: _backButton(context),
          title: Text(l10n.choreDetails),
        ),
        body: Center(child: Text('${l10n.error}: $e')),
      ),
      data: (chores) {
        final chore = chores.where((c) => c.id == widget.choreId).firstOrNull;
        if (chore == null) {
          return Scaffold(
            appBar: AppBar(
              leading: _backButton(context),
              title: Text(l10n.choreDetails),
            ),
            body: Center(child: Text(l10n.noResults)),
          );
        }

        return Scaffold(
          appBar: AppBar(
            leading: _backButton(context),
            title: Text(l10n.choreDetails),
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _deleteChore(household.id, chore.id),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Title and status
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(_categoryIcon(chore.category),
                              color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              chore.title,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Chip(
                            avatar: Icon(Icons.label,
                                size: 16,
                                color: Theme.of(context).colorScheme.primary),
                            label:
                                Text(_categoryLabel(context, chore.category)),
                          ),
                          Chip(
                            avatar: Icon(Icons.flag,
                                size: 16,
                                color: _priorityColor(chore.priority)),
                            label:
                                Text(_priorityLabel(context, chore.priority)),
                            backgroundColor: _priorityColor(chore.priority)
                                .withValues(alpha: 0.1),
                          ),
                          Chip(
                            avatar: Icon(Icons.circle,
                                size: 12,
                                color: _statusColor(chore.status)),
                            label:
                                Text(_statusLabel(context, chore.status)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Details card
              if (chore.description != null && chore.description!.isNotEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.choreDescription,
                            style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 8),
                        Text(chore.description!),
                      ],
                    ),
                  ),
                ),

              // Info rows
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      if (chore.dueDate != null)
                        _InfoRow(
                          icon: Icons.calendar_today,
                          label: l10n.dueDate,
                          value: _formatDateTime(chore.dueDate!),
                        ),
                      if (chore.estimatedMinutes != null)
                        _InfoRow(
                          icon: Icons.timer,
                          label: l10n.estimatedMinutes,
                          value:
                              '${chore.estimatedMinutes} ${l10n.minutesShort}',
                        ),
                      if (chore.location != null &&
                          chore.location!.isNotEmpty)
                        _InfoRow(
                          icon: Icons.location_on,
                          label: l10n.location,
                          value: chore.location!,
                        ),
                      if (chore.recurrence != null)
                        _InfoRow(
                          icon: Icons.repeat,
                          label: l10n.recurrence,
                          value: chore.recurrence!,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Assign button
              membersAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (members) => FilledButton.icon(
                  onPressed: () => _showAssignDialog(
                      household.id, chore.id, members),
                  icon: const Icon(Icons.person_add),
                  label: Text(l10n.assignChore),
                ),
              ),
              const SizedBox(height: 16),

              // Assignments section
              Text(l10n.assignments,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              _AssignmentsList(
                householdId: household.id,
                choreId: chore.id,
                onComplete: (assignment) =>
                    _showCompleteDialog(household.id, assignment),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDateTime(DateTime dt) {
    final date = '${dt.day}/${dt.month}/${dt.year}';
    if (dt.hour == 0 && dt.minute == 0) return date;
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$date $hour:$minute';
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.outline),
          const SizedBox(width: 12),
          Text(label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  )),
          const Spacer(),
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _AssignmentsList extends ConsumerWidget {
  final String householdId;
  final String choreId;
  final void Function(ChoreAssignment) onComplete;

  const _AssignmentsList({
    required this.householdId,
    required this.choreId,
    required this.onComplete,
  });

  Color _statusColor(ChoreStatus status) {
    switch (status) {
      case ChoreStatus.pending:
        return Colors.orange;
      case ChoreStatus.inProgress:
        return Colors.blue;
      case ChoreStatus.completed:
        return Colors.green;
      case ChoreStatus.skipped:
        return Colors.grey;
      case ChoreStatus.active:
        return Colors.green;
      case ChoreStatus.paused:
        return Colors.amber;
      case ChoreStatus.archived:
        return Colors.grey;
    }
  }

  String _statusLabel(BuildContext context, ChoreStatus status) {
    final l10n = AppLocalizations.of(context)!;
    switch (status) {
      case ChoreStatus.pending:
        return l10n.pending;
      case ChoreStatus.inProgress:
        return l10n.inProgress;
      case ChoreStatus.completed:
        return l10n.completed;
      case ChoreStatus.skipped:
        return l10n.skipped;
      case ChoreStatus.active:
        return l10n.active;
      case ChoreStatus.paused:
        return l10n.paused;
      case ChoreStatus.archived:
        return l10n.archived;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final assignmentsAsync = ref.watch(myAssignmentsProvider(householdId));

    return assignmentsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('${l10n.error}: $e'),
      data: (allAssignments) {
        final assignments =
            allAssignments.where((a) => a.choreId == choreId).toList();

        if (assignments.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.unassigned,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ),
          );
        }

        return Column(
          children: assignments.map((assignment) {
            final isCompleted = assignment.status == ChoreStatus.completed;
            return Card(
              child: ListTile(
                leading: Icon(
                  isCompleted
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: _statusColor(assignment.status),
                ),
                title: Text(assignment.assigneeName ?? assignment.assignedTo),
                subtitle: Text(_statusLabel(context, assignment.status)),
                trailing: isCompleted
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.check),
                        onPressed: () => onComplete(assignment),
                      ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
