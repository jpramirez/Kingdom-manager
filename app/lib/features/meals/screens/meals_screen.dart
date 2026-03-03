import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../family_profiles/providers/family_profile_provider.dart';
import '../../household/providers/household_provider.dart';
import '../models/recipe.dart';
import '../providers/meal_provider.dart';
import '../widgets/recipe_card.dart';

class MealsScreen extends ConsumerWidget {
  const MealsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final household = ref.watch(activeHouseholdProvider).household;
    final l10n = AppLocalizations.of(context)!;

    if (household == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.meals)),
        body: Center(child: Text(l10n.noHouseholdSelected)),
      );
    }

    final canManage = ref.watch(currentMemberProvider).valueOrNull?.canManage ?? false;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.meals),
          actions: [
            IconButton(
              icon: const Icon(Icons.smart_toy_outlined),
              tooltip: l10n.aiAskAboutMeals,
              onPressed: () => context.push('/ai-chat', extra: {
                'initialMessage': l10n.aiSuggestMealPlan,
                'taskHint': 'meal_planning',
              }),
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.recipes),
              Tab(text: l10n.mealPlan),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _RecipesTab(householdId: household.id),
            _MealPlanTab(householdId: household.id),
          ],
        ),
        floatingActionButton: canManage
            ? FloatingActionButton(
                onPressed: () => context.push('/meals/create'),
                child: const Icon(Icons.add),
              )
            : null,
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
    final l10n = AppLocalizations.of(context)!;

    return recipesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${l10n.error}: $e'),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => ref.invalidate(recipesProvider(householdId)),
              child: Text(l10n.retry),
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
                Text(l10n.noRecipesYet,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        )),
                const SizedBox(height: 8),
                Text(l10n.addFirstRecipe,
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

  String _weekdayShort(DateTime date) {
    final locale = Localizations.localeOf(context).toString();
    return DateFormat.E(locale).format(date);
  }

  String _formatWeekRange() {
    final end = _weekStart.add(const Duration(days: 6));
    return '${_weekStart.day}/${_weekStart.month} - ${end.day}/${end.month}/${end.year}';
  }

  Future<void> _showAddMealDialog(DateTime date, String mealType) async {
    final l10n = AppLocalizations.of(context)!;
    final recipesAsync = ref.read(recipesProvider(widget.householdId));
    final recipes = recipesAsync.valueOrNull ?? [];
    final profilesAsync =
        ref.read(familyProfilesProvider(widget.householdId));
    final profiles = profilesAsync.valueOrNull ?? [];

    String? selectedRecipeId;
    String? selectedProfileId;
    final customNameController = TextEditingController();
    final notesController = TextEditingController();
    bool useCustom = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
              '${l10n.add} ${_mealTypeLabel(mealType)} - ${_weekdayShort(date)} ${date.day}/${date.month}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Toggle: recipe vs custom
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.customMealName),
                  value: useCustom,
                  onChanged: (v) => setDialogState(() => useCustom = v),
                ),
                const SizedBox(height: 8),

                if (useCustom)
                  TextField(
                    controller: customNameController,
                    decoration: InputDecoration(
                      labelText: l10n.mealName,
                      border: const OutlineInputBorder(),
                    ),
                    autofocus: true,
                  )
                else
                  DropdownButtonFormField<String>(
                    value: selectedRecipeId,
                    decoration: InputDecoration(
                      labelText: l10n.selectRecipe,
                      border: const OutlineInputBorder(),
                    ),
                    items: recipes.map((r) => DropdownMenuItem(
                      value: r.id,
                      child: Text(r.name),
                    )).toList(),
                    onChanged: (v) =>
                        setDialogState(() => selectedRecipeId = v),
                  ),

                if (profiles.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedProfileId,
                    decoration: InputDecoration(
                      labelText: l10n.forMemberOptional,
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.person),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text(l10n.everyone),
                      ),
                      ...profiles.map((p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(p.name),
                          )),
                    ],
                    onChanged: (v) =>
                        setDialogState(() => selectedProfileId = v),
                  ),
                ],

                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  decoration: InputDecoration(
                    labelText: l10n.notesOptional,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.cancel),
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
                  if (selectedProfileId != null) {
                    entry['profile_id'] = selectedProfileId;
                  }

                  await ref
                      .read(mealRepositoryProvider)
                      .updateMealPlan(widget.householdId, [entry]);
                  ref.invalidate(mealPlanProvider(_params));
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${l10n.error}: $e')),
                    );
                  }
                }
              },
              child: Text(l10n.add),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final planAsync = ref.watch(mealPlanProvider(_params));
    final l10n = AppLocalizations.of(context)!;

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
                  Text('${l10n.error}: $e'),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () =>
                        ref.invalidate(mealPlanProvider(_params)),
                    child: Text(l10n.retry),
                  ),
                ],
              ),
            ),
            data: (plans) {
              // Build a lookup: date string -> meal_type -> list of MealPlans
              final lookup = <String, Map<String, List<MealPlan>>>{};
              for (final plan in plans) {
                final dateKey =
                    plan.date.toIso8601String().split('T').first;
                lookup
                    .putIfAbsent(dateKey, () => {})
                    .putIfAbsent(plan.mealType, () => [])
                    .add(plan);
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
                      weekdayLabel: _weekdayShort(date),
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
  final Map<String, List<MealPlan>> dayPlans;
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
    final l10n = AppLocalizations.of(context)!;

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
                      l10n.today,
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
              final plans = dayPlans[type];
              final hasMeals = plans != null && plans.isNotEmpty;

              return InkWell(
                onTap: () => onAddMeal(type),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        mealTypeIcon(type),
                        size: 18,
                        color: hasMeals
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
                        child: hasMeals
                            ? Text(
                                plans.map((p) => p.displayName).join(', '),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w500,
                                    ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              )
                            : Text(
                                l10n.tapToAdd,
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
                      if (hasMeals && plans.any((p) => p.notes != null && p.notes!.isNotEmpty))
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
