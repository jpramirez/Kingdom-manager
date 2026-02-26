import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/enums.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../household/providers/household_provider.dart';
import '../models/chore.dart';
import '../providers/chore_provider.dart';
import '../widgets/chore_card.dart';

class ChoresScreen extends ConsumerWidget {
  const ChoresScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final household = ref.watch(activeHouseholdProvider).household;

    if (household == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.chores)),
        body: const Center(child: Text('No household selected')),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.chores),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.allChores),
              Tab(text: l10n.myTasks),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _AllChoresTab(householdId: household.id),
            _MyTasksTab(householdId: household.id),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => context.push('/chores/create'),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

class _AllChoresTab extends ConsumerWidget {
  final String householdId;
  const _AllChoresTab({required this.householdId});

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final choresAsync = ref.watch(choresProvider(householdId));

    return choresAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${l10n.error}: $e'),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => ref.invalidate(choresProvider(householdId)),
              child: Text(l10n.retry),
            ),
          ],
        ),
      ),
      data: (chores) {
        if (chores.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.checklist,
                    size: 64,
                    color: Theme.of(context).colorScheme.outline),
                const SizedBox(height: 16),
                Text(l10n.noChoresYet,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        )),
              ],
            ),
          );
        }

        // Group by category
        final grouped = <ChoreCategory, List<Chore>>{};
        for (final chore in chores) {
          grouped.putIfAbsent(chore.category, () => []).add(chore);
        }

        final categories = grouped.keys.toList()
          ..sort((a, b) => a.value.compareTo(b.value));

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(choresProvider(householdId));
            await ref.read(choresProvider(householdId).future);
          },
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              final categoryChores = grouped[category]!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      _categoryLabel(context, category),
                      style:
                          Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                    ),
                  ),
                  ...categoryChores.map((chore) => Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 2),
                        child: ChoreCard(
                          chore: chore,
                          onTap: () => context.push('/chores/${chore.id}'),
                        ),
                      )),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _MyTasksTab extends ConsumerWidget {
  final String householdId;
  const _MyTasksTab({required this.householdId});

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
        return 'Active';
      case ChoreStatus.paused:
        return 'Paused';
      case ChoreStatus.archived:
        return 'Archived';
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final assignmentsAsync = ref.watch(myAssignmentsProvider(householdId));

    return assignmentsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${l10n.error}: $e'),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () =>
                  ref.invalidate(myAssignmentsProvider(householdId)),
              child: Text(l10n.retry),
            ),
          ],
        ),
      ),
      data: (assignments) {
        if (assignments.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.task_alt,
                    size: 64,
                    color: Theme.of(context).colorScheme.outline),
                const SizedBox(height: 16),
                Text(l10n.noTasksYet,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        )),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(myAssignmentsProvider(householdId));
            await ref.read(myAssignmentsProvider(householdId).future);
          },
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 80),
            itemCount: assignments.length,
            itemBuilder: (context, index) {
              final assignment = assignments[index];
              final isCompleted =
                  assignment.status == ChoreStatus.completed;

              return Dismissible(
                key: Key(assignment.id),
                direction: isCompleted
                    ? DismissDirection.none
                    : DismissDirection.startToEnd,
                background: Container(
                  color: Colors.green,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(left: 20),
                  child: const Icon(Icons.check, color: Colors.white),
                ),
                confirmDismiss: (direction) async {
                  try {
                    await ref
                        .read(choreRepositoryProvider)
                        .completeAssignment(householdId, assignment.id);
                    ref.invalidate(myAssignmentsProvider(householdId));
                    ref.invalidate(todayAssignmentsProvider(householdId));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(l10n.assignmentCompleted)),
                      );
                    }
                    return false; // Don't remove from list, let refresh handle it
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                    return false;
                  }
                },
                child: ListTile(
                  leading: Icon(
                    isCompleted
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: _statusColor(assignment.status),
                  ),
                  title: Text(
                    assignment.choreTitle ?? 'Chore',
                    style: TextStyle(
                      decoration: isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  subtitle: Text(_statusLabel(context, assignment.status)),
                  trailing: assignment.dueDate != null
                      ? Text(
                          _formatDate(assignment.dueDate!),
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                color: _isOverdue(assignment.dueDate!) &&
                                        !isCompleted
                                    ? Colors.red
                                    : Theme.of(context).colorScheme.outline,
                              ),
                        )
                      : null,
                  onTap: () => context.push('/chores/${assignment.choreId}'),
                ),
              );
            },
          ),
        );
      },
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
