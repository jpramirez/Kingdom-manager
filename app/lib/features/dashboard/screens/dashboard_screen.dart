import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/enums.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/providers/auth_provider.dart';
import '../../chores/models/chore.dart';
import '../../chores/providers/chore_provider.dart';
import '../../household/providers/household_provider.dart';
import '../../meals/models/recipe.dart';
import '../../meals/providers/meal_provider.dart';
import '../../approvals/providers/approval_provider.dart';
import '../../notifications/providers/notification_provider.dart';
import '../../ai/providers/ai_chat_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final authState = ref.watch(authStateProvider);
    final household = ref.watch(activeHouseholdProvider).household;

    final userName = authState.valueOrNull?.displayName ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(household?.name ?? l10n.appTitle),
        actions: [
          if (household != null) _NotificationBellButton(),
          if (household != null)
            IconButton(
              icon: const Icon(Icons.people_outline),
              onPressed: () => context.push('/members'),
            ),
        ],
      ),
      floatingActionButton: household != null
          ? FloatingActionButton(
              heroTag: 'ai_fab',
              onPressed: () => context.push('/ai-chat'),
              tooltip: l10n.aiAssistant,
              child: const Icon(Icons.smart_toy_outlined),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Welcome card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.welcomeBack(userName),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  if (household != null)
                    Row(
                      children: [
                        Icon(Icons.home_outlined,
                            size: 16,
                            color: Theme.of(context).colorScheme.outline),
                        const SizedBox(width: 4),
                        Text(
                          household.name,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // AI Onboarding banner (show when no memories exist)
          if (household != null)
            _OnboardingBanner(householdId: household.id),

          // Today's Chores - real data
          if (household != null)
            _TodayChoresCard(householdId: household.id)
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.checklist),
                        const SizedBox(width: 8),
                        Text(l10n.todayChores,
                            style: Theme.of(context).textTheme.titleMedium),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(l10n.noChoresForToday,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            )),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),

          // Today's Meals - real data
          if (household != null)
            _TodayMealsCard(householdId: household.id)
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.restaurant_menu),
                        const SizedBox(width: 8),
                        Text(l10n.upcomingMeals,
                            style: Theme.of(context).textTheme.titleMedium),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(l10n.noMealPlanSet,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            )),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),

          // Pending Approvals
          if (household != null)
            _PendingApprovalsCard(householdId: household.id),
        ],
      ),
    );
  }
}

class _TodayChoresCard extends ConsumerWidget {
  final String householdId;
  const _TodayChoresCard({required this.householdId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final todayAsync = ref.watch(todayAssignmentsProvider(householdId));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.checklist),
                const SizedBox(width: 8),
                Text(l10n.todayChores,
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                TextButton(
                  onPressed: () => context.go('/chores'),
                  child: Text(l10n.chores),
                ),
              ],
            ),
            const SizedBox(height: 12),
            todayAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => Text(
                '${l10n.error}: $e',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
              ),
              data: (assignments) {
                if (assignments.isEmpty) {
                  return Text(
                    l10n.noChoresForToday,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  );
                }

                return Column(
                  children: assignments.map((assignment) {
                    final isCompleted =
                        assignment.status == ChoreStatus.completed;
                    return _TodayChoreRow(
                      assignment: assignment,
                      householdId: householdId,
                      isCompleted: isCompleted,
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayChoreRow extends ConsumerWidget {
  final ChoreAssignment assignment;
  final String householdId;
  final bool isCompleted;

  const _TodayChoreRow({
    required this.assignment,
    required this.householdId,
    required this.isCompleted,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return InkWell(
      onTap: () => context.push('/chores/${assignment.choreId}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            GestureDetector(
              onTap: isCompleted
                  ? null
                  : () async {
                      try {
                        await ref
                            .read(choreRepositoryProvider)
                            .completeAssignment(householdId, assignment.id);
                        ref.invalidate(todayAssignmentsProvider(householdId));
                        ref.invalidate(myAssignmentsProvider(householdId));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(l10n.assignmentCompleted)),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      }
                    },
              child: Icon(
                isCompleted
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: isCompleted ? Colors.green : Colors.grey,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                assignment.choreTitle ?? 'Chore',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      decoration:
                          isCompleted ? TextDecoration.lineThrough : null,
                      color: isCompleted
                          ? Theme.of(context).colorScheme.outline
                          : null,
                    ),
              ),
            ),
            if (assignment.assigneeName != null)
              Text(
                assignment.assigneeName!,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            Icon(Icons.chevron_right,
                size: 16, color: Theme.of(context).colorScheme.outline),
          ],
        ),
      ),
    );
  }
}

class _TodayMealsCard extends ConsumerWidget {
  final String householdId;
  const _TodayMealsCard({required this.householdId});

  static const _mealTypes = ['breakfast', 'lunch', 'dinner', 'snack'];

  String _mealTypeLabel(BuildContext context, String type) {
    final l10n = AppLocalizations.of(context)!;
    switch (type) {
      case 'breakfast':
        return l10n.breakfast;
      case 'lunch':
        return l10n.lunch;
      case 'dinner':
        return l10n.dinner;
      case 'snack':
        return l10n.snack;
      default:
        return type;
    }
  }

  IconData _mealTypeIcon(String type) {
    switch (type) {
      case 'breakfast':
        return Icons.free_breakfast;
      case 'lunch':
        return Icons.lunch_dining;
      case 'dinner':
        return Icons.dinner_dining;
      case 'snack':
        return Icons.cookie;
      default:
        return Icons.restaurant;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final params = MealPlanParams(
      householdId: householdId,
      start: today,
      end: today,
    );
    final planAsync = ref.watch(mealPlanProvider(params));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.restaurant_menu),
                const SizedBox(width: 8),
                Text(l10n.upcomingMeals,
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                TextButton(
                  onPressed: () => context.push('/meals'),
                  child: Text(l10n.meals),
                ),
              ],
            ),
            const SizedBox(height: 12),
            planAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => Text(
                '${l10n.error}: $e',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
              ),
              data: (plans) {
                if (plans.isEmpty) {
                  return Text(
                    l10n.noMealPlanSet,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  );
                }

                // Build lookup by meal_type
                final lookup = <String, MealPlan>{};
                for (final plan in plans) {
                  lookup[plan.mealType] = plan;
                }

                return Column(
                  children: _mealTypes.map((type) {
                    final plan = lookup[type];
                    if (plan == null) return const SizedBox.shrink();
                    return InkWell(
                      onTap: () => plan.recipeId != null
                          ? context.push('/meals/recipes/${plan.recipeId}')
                          : context.push('/meals'),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Icon(
                              _mealTypeIcon(type),
                              size: 18,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 72,
                              child: Text(
                                _mealTypeLabel(context, type),
                                style: Theme.of(context)
                                    .textTheme
                                    .labelMedium
                                    ?.copyWith(
                                      color:
                                          Theme.of(context).colorScheme.outline,
                                    ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                plan.displayName,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Icon(Icons.chevron_right,
                                size: 14,
                                color: Theme.of(context).colorScheme.outline),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingApprovalsCard extends ConsumerWidget {
  final String householdId;
  const _PendingApprovalsCard({required this.householdId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final approvalsAsync = ref.watch(pendingApprovalsProvider(householdId));

    return approvalsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (approvals) {
        if (approvals.isEmpty) return const SizedBox.shrink();

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.approval),
                    const SizedBox(width: 8),
                    Text(l10n.pendingApprovals,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.error,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${approvals.length}',
                        style:
                            Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color:
                                      Theme.of(context).colorScheme.onError,
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => context.push('/approvals'),
                      child: Text(l10n.approvals),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...approvals.take(3).map((approval) => InkWell(
                      onTap: () => context.push('/approvals'),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Icon(
                              Icons.pending_actions,
                              size: 18,
                              color: Colors.orange,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                approval.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              approval.requesterName ?? '',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.outline,
                                  ),
                            ),
                            Icon(Icons.chevron_right,
                                size: 14,
                                color: Theme.of(context).colorScheme.outline),
                          ],
                        ),
                      ),
                    )),
                if (approvals.length > 3)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '+${approvals.length - 3} more',
                      style:
                          Theme.of(context).textTheme.labelSmall?.copyWith(
                                color:
                                    Theme.of(context).colorScheme.outline,
                              ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OnboardingBanner extends ConsumerWidget {
  final String householdId;
  const _OnboardingBanner({required this.householdId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final hasMemories = ref.watch(hasMemoriesProvider(householdId));

    return hasMemories.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (has) {
        if (has) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.smart_toy_outlined,
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimaryContainer),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.aiOnboarding,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.aiOnboardingDesc,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimaryContainer,
                        ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => context.push('/ai-onboarding'),
                    icon: const Icon(Icons.rocket_launch),
                    label: Text(l10n.aiOnboardingStart),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NotificationBellButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(unreadCountProvider);

    // Initialise WS connection so real-time updates flow
    ref.watch(wsNotificationProvider);

    return IconButton(
      icon: Badge(
        isLabelVisible: countAsync.valueOrNull != null &&
            countAsync.valueOrNull! > 0,
        label: Text(
          '${countAsync.valueOrNull ?? 0}',
          style: const TextStyle(fontSize: 10),
        ),
        child: const Icon(Icons.notifications_outlined),
      ),
      onPressed: () => context.push('/notifications'),
    );
  }
}
