import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../household/providers/household_provider.dart';
import '../models/recipe.dart';
import '../providers/meal_provider.dart';
import '../widgets/recipe_card.dart';

class MealsScreen extends ConsumerWidget {
  const MealsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final household = ref.watch(activeHouseholdProvider).household;

    if (household == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Meals')),
        body: const Center(child: Text('No household selected')),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Meals'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Recipes'),
              Tab(text: 'Meal Plan'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _RecipesTab(householdId: household.id),
            _MealPlanTab(householdId: household.id),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => context.push('/meals/create'),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

class _RecipesTab extends ConsumerWidget {
  final String householdId;
  const _RecipesTab({required this.householdId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipesAsync = ref.watch(recipesProvider(householdId));

    return recipesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Error: $e'),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => ref.invalidate(recipesProvider(householdId)),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (recipes) {
        if (recipes.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.restaurant_menu,
                    size: 64,
                    color: Theme.of(context).colorScheme.outline),
                const SizedBox(height: 16),
                Text('No recipes yet',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        )),
                const SizedBox(height: 8),
                Text('Tap + to add your first recipe',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        )),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(recipesProvider(householdId));
            await ref.read(recipesProvider(householdId).future);
          },
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 80),
            itemCount: recipes.length,
            itemBuilder: (context, index) {
              final recipe = recipes[index];
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: RecipeCard(
                  recipe: recipe,
                  onTap: () => context.push('/meals/recipes/${recipe.id}'),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _MealPlanTab extends ConsumerStatefulWidget {
  final String householdId;
  const _MealPlanTab({required this.householdId});

  @override
  ConsumerState<_MealPlanTab> createState() => _MealPlanTabState();
}

class _MealPlanTabState extends ConsumerState<_MealPlanTab> {
  late DateTime _weekStart;

  static const _mealTypes = ['breakfast', 'lunch', 'dinner', 'snack'];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // Start on Monday of the current week
    _weekStart = now.subtract(Duration(days: now.weekday - 1));
    _weekStart = DateTime(_weekStart.year, _weekStart.month, _weekStart.day);
  }

  MealPlanParams get _params => MealPlanParams(
        householdId: widget.householdId,
        start: _weekStart,
        end: _weekStart.add(const Duration(days: 6)),
      );

  void _previousWeek() {
    setState(() {
      _weekStart = _weekStart.subtract(const Duration(days: 7));
    });
  }

  void _nextWeek() {
    setState(() {
      _weekStart = _weekStart.add(const Duration(days: 7));
    });
  }

  void _goToThisWeek() {
    final now = DateTime.now();
    setState(() {
      _weekStart = now.subtract(Duration(days: now.weekday - 1));
      _weekStart = DateTime(_weekStart.year, _weekStart.month, _weekStart.day);
    });
  }

  String _mealTypeLabel(String type) {
    switch (type) {
      case 'breakfast':
        return 'Breakfast';
      case 'lunch':
        return 'Lunch';
      case 'dinner':
        return 'Dinner';
      case 'snack':
        return 'Snack';
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

  String _weekdayShort(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday - 1];
  }

  String _formatWeekRange() {
    final end = _weekStart.add(const Duration(days: 6));
    return '${_weekStart.day}/${_weekStart.month} - ${end.day}/${end.month}/${end.year}';
  }

  Future<void> _showAddMealDialog(DateTime date, String mealType) async {
    final recipesAsync = ref.read(recipesProvider(widget.householdId));
    final recipes = recipesAsync.valueOrNull ?? [];

    String? selectedRecipeId;
    final customNameController = TextEditingController();
    final notesController = TextEditingController();
    bool useCustom = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
              'Add ${_mealTypeLabel(mealType)} - ${_weekdayShort(date.weekday)} ${date.day}/${date.month}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Toggle: recipe vs custom
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Custom meal name'),
                  value: useCustom,
                  onChanged: (v) => setDialogState(() => useCustom = v),
                ),
                const SizedBox(height: 8),

                if (useCustom)
                  TextField(
                    controller: customNameController,
                    decoration: const InputDecoration(
                      labelText: 'Meal name',
                      border: OutlineInputBorder(),
                    ),
                    autofocus: true,
                  )
                else
                  DropdownButtonFormField<String>(
                    value: selectedRecipeId,
                    decoration: const InputDecoration(
                      labelText: 'Select recipe',
                      border: OutlineInputBorder(),
                    ),
                    items: recipes.map((r) => DropdownMenuItem(
                      value: r.id,
                      child: Text(r.name),
                    )).toList(),
                    onChanged: (v) =>
                        setDialogState(() => selectedRecipeId = v),
                  ),

                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final hasRecipe = !useCustom && selectedRecipeId != null;
                final hasCustom =
                    useCustom && customNameController.text.trim().isNotEmpty;

                if (!hasRecipe && !hasCustom) return;

                Navigator.of(ctx).pop();
                try {
                  final entry = <String, dynamic>{
                    'date': date.toIso8601String().split('T').first,
                    'meal_type': mealType,
                  };
                  if (hasRecipe) entry['recipe_id'] = selectedRecipeId;
                  if (hasCustom) {
                    entry['custom_meal_name'] =
                        customNameController.text.trim();
                  }
                  if (notesController.text.trim().isNotEmpty) {
                    entry['notes'] = notesController.text.trim();
                  }

                  await ref
                      .read(mealRepositoryProvider)
                      .updateMealPlan(widget.householdId, [entry]);
                  ref.invalidate(mealPlanProvider(_params));
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final planAsync = ref.watch(mealPlanProvider(_params));

    return Column(
      children: [
        // Week navigation header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _previousWeek,
              ),
              Expanded(
                child: GestureDetector(
                  onTap: _goToThisWeek,
                  child: Text(
                    _formatWeekRange(),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _nextWeek,
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Meal plan grid
        Expanded(
          child: planAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Error: $e'),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () =>
                        ref.invalidate(mealPlanProvider(_params)),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
            data: (plans) {
              // Build a lookup: date string -> meal_type -> MealPlan
              final lookup = <String, Map<String, MealPlan>>{};
              for (final plan in plans) {
                final dateKey =
                    plan.date.toIso8601String().split('T').first;
                lookup.putIfAbsent(dateKey, () => {})[plan.mealType] = plan;
              }

              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(mealPlanProvider(_params));
                  await ref.read(mealPlanProvider(_params).future);
                },
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: 7,
                  itemBuilder: (context, dayIndex) {
                    final date =
                        _weekStart.add(Duration(days: dayIndex));
                    final dateKey =
                        date.toIso8601String().split('T').first;
                    final dayPlans = lookup[dateKey] ?? {};
                    final isToday = _isToday(date);

                    return _DayCard(
                      date: date,
                      weekdayLabel: _weekdayShort(date.weekday),
                      isToday: isToday,
                      mealTypes: _mealTypes,
                      dayPlans: dayPlans,
                      mealTypeLabel: _mealTypeLabel,
                      mealTypeIcon: _mealTypeIcon,
                      onAddMeal: (mealType) =>
                          _showAddMealDialog(date, mealType),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }
}

class _DayCard extends StatelessWidget {
  final DateTime date;
  final String weekdayLabel;
  final bool isToday;
  final List<String> mealTypes;
  final Map<String, MealPlan> dayPlans;
  final String Function(String) mealTypeLabel;
  final IconData Function(String) mealTypeIcon;
  final void Function(String) onAddMeal;

  const _DayCard({
    required this.date,
    required this.weekdayLabel,
    required this.isToday,
    required this.mealTypes,
    required this.dayPlans,
    required this.mealTypeLabel,
    required this.mealTypeIcon,
    required this.onAddMeal,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: isToday
          ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)
          : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Day header
            Row(
              children: [
                Text(
                  '$weekdayLabel, ${date.day}/${date.month}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isToday
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                ),
                if (isToday) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Today',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),

            // Meal slots
            ...mealTypes.map((type) {
              final plan = dayPlans[type];

              return InkWell(
                onTap: () => onAddMeal(type),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        mealTypeIcon(type),
                        size: 18,
                        color: plan != null
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 72,
                        child: Text(
                          mealTypeLabel(type),
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                        ),
                      ),
                      Expanded(
                        child: plan != null
                            ? Text(
                                plan.displayName,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w500,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              )
                            : Text(
                                'Tap to add',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .outline
                                          .withValues(alpha: 0.5),
                                      fontStyle: FontStyle.italic,
                                    ),
                              ),
                      ),
                      if (plan?.notes != null && plan!.notes!.isNotEmpty)
                        Icon(
                          Icons.notes,
                          size: 16,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
