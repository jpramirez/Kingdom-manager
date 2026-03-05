import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../comments/widgets/comments_section.dart';
import '../../grocery/providers/grocery_provider.dart';
import '../../household/providers/household_provider.dart';
import '../models/recipe.dart';
import '../providers/meal_provider.dart';

class RecipeDetailScreen extends ConsumerStatefulWidget {
  final String recipeId;
  const RecipeDetailScreen({super.key, required this.recipeId});

  @override
  ConsumerState<RecipeDetailScreen> createState() =>
      _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends ConsumerState<RecipeDetailScreen> {
  bool _isEditing = false;

  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _instructionsController;
  late TextEditingController _prepTimeController;
  late TextEditingController _cookTimeController;
  late TextEditingController _servingsController;
  late TextEditingController _tagsController;
  final List<_IngredientEntry> _editIngredients = [];
  bool _saving = false;

  static const _units = [
    '', 'kg', 'g', 'pcs', 'bottles', 'packs', 'L', 'mL',
    'cans', 'tbsp', 'tsp', 'cups',
  ];
  static const _categories = [
    'produce', 'dairy', 'meat', 'pantry', 'frozen', 'household', 'other',
  ];

  void _initControllers(Recipe recipe) {
    _nameController = TextEditingController(text: recipe.name);
    _descriptionController =
        TextEditingController(text: recipe.description ?? '');
    _instructionsController =
        TextEditingController(text: recipe.instructions ?? '');
    _prepTimeController =
        TextEditingController(text: recipe.prepTimeMinutes?.toString() ?? '');
    _cookTimeController =
        TextEditingController(text: recipe.cookTimeMinutes?.toString() ?? '');
    _servingsController =
        TextEditingController(text: recipe.servings?.toString() ?? '');
    _tagsController =
        TextEditingController(text: recipe.tags?.join(', ') ?? '');

    _editIngredients.clear();
    for (final ing in recipe.ingredients) {
      _editIngredients.add(_IngredientEntry(
        name: ing.name,
        quantity: ing.quantity?.toString() ?? '',
        unit: ing.unit ?? '',
        category: ing.category,
        optional: ing.optional,
      ));
    }
  }

  void _disposeControllers() {
    _nameController.dispose();
    _descriptionController.dispose();
    _instructionsController.dispose();
    _prepTimeController.dispose();
    _cookTimeController.dispose();
    _servingsController.dispose();
    _tagsController.dispose();
    for (final ing in _editIngredients) {
      ing.dispose();
    }
    _editIngredients.clear();
  }

  Future<void> _save(String householdId) async {
    if (_nameController.text.trim().isEmpty) return;

    setState(() => _saving = true);
    try {
      final data = <String, dynamic>{
        'name': _nameController.text.trim(),
      };

      if (_descriptionController.text.trim().isNotEmpty) {
        data['description'] = _descriptionController.text.trim();
      }
      if (_instructionsController.text.trim().isNotEmpty) {
        data['instructions'] = _instructionsController.text.trim();
      }
      if (_prepTimeController.text.trim().isNotEmpty) {
        data['prep_time_minutes'] =
            int.tryParse(_prepTimeController.text.trim());
      }
      if (_cookTimeController.text.trim().isNotEmpty) {
        data['cook_time_minutes'] =
            int.tryParse(_cookTimeController.text.trim());
      }
      if (_servingsController.text.trim().isNotEmpty) {
        data['servings'] = int.tryParse(_servingsController.text.trim());
      }
      if (_tagsController.text.trim().isNotEmpty) {
        data['tags'] = _tagsController.text
            .split(',')
            .map((t) => t.trim())
            .where((t) => t.isNotEmpty)
            .toList();
      }

      final validIngredients = _editIngredients
          .where((ing) => ing.nameController.text.trim().isNotEmpty)
          .toList();
      data['ingredients'] = validIngredients.asMap().entries.map((e) {
        final ing = e.value;
        return {
          'name': ing.nameController.text.trim(),
          if (ing.quantityController.text.trim().isNotEmpty)
            'quantity': double.tryParse(ing.quantityController.text.trim()),
          if (ing.unit.isNotEmpty) 'unit': ing.unit,
          'category': ing.category,
          'optional': ing.optional,
          'sort_order': e.key,
        };
      }).toList();

      await ref
          .read(mealRepositoryProvider)
          .updateRecipe(householdId, widget.recipeId, data);
      ref.invalidate(recipesProvider(householdId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recipe updated')),
        );
        setState(() => _isEditing = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addToGrocery(String householdId, Recipe recipe) async {
    if (recipe.ingredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.noIngredients)),
      );
      return;
    }

    final listsAsync = ref.read(groceryListsProvider(householdId));
    final lists = listsAsync.valueOrNull ?? [];
    if (lists.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No grocery lists found. Create one first.')),
      );
      return;
    }

    final selectedListId = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx)!;
        return AlertDialog(
          title: Text(l10n.selectGroceryList),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: lists.length,
              itemBuilder: (_, i) => ListTile(
                title: Text(lists[i].name),
                leading: const Icon(Icons.shopping_cart_outlined),
                onTap: () => Navigator.of(ctx).pop(lists[i].id),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.cancel),
            ),
          ],
        );
      },
    );

    if (selectedListId == null || !mounted) return;

    try {
      final result = await ref
          .read(mealRepositoryProvider)
          .addIngredientsToGrocery(
            householdId,
            recipeId: recipe.id,
            groceryListId: selectedListId,
          );
      if (mounted) {
        final added = result['added_count'] ?? 0;
        final skipped = result['skipped_count'] ?? 0;
        ref.invalidate(groceryItemsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.ingredientsAdded(added, skipped),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _deleteRecipe(String householdId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Recipe'),
        content: const Text('Are you sure you want to delete this recipe?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref
            .read(mealRepositoryProvider)
            .deleteRecipe(householdId, widget.recipeId);
        ref.invalidate(recipesProvider(householdId));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Recipe deleted')),
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
    final household = ref.watch(activeHouseholdProvider).household;

    Widget backButton() => IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/plan');
        }
      },
    );

    if (household == null) {
      return Scaffold(
        appBar: AppBar(leading: backButton(), title: const Text('Recipe')),
        body: const Center(child: Text('No household selected')),
      );
    }

    final recipesAsync = ref.watch(recipesProvider(household.id));

    return recipesAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(leading: backButton(), title: const Text('Recipe')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(leading: backButton(), title: const Text('Recipe')),
        body: Center(child: Text('Error: $e')),
      ),
      data: (recipes) {
        final recipe =
            recipes.where((r) => r.id == widget.recipeId).firstOrNull;
        if (recipe == null) {
          return Scaffold(
            appBar: AppBar(leading: backButton(), title: const Text('Recipe')),
            body: const Center(child: Text('Recipe not found')),
          );
        }

        if (_isEditing) {
          return _buildEditView(context, recipe, household.id);
        }
        return _buildDetailView(context, recipe, household.id);
      },
    );
  }

  Widget _buildDetailView(
      BuildContext context, Recipe recipe, String householdId) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/plan');
            }
          },
        ),
        title: const Text('Recipe'),
        actions: [
          if (recipe.ingredients.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.add_shopping_cart),
              tooltip: AppLocalizations.of(context)!.addToGrocery,
              onPressed: () => _addToGrocery(householdId, recipe),
            ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              _initControllers(recipe);
              setState(() => _isEditing = true);
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _deleteRecipe(householdId),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Image
          if (recipe.imageUrl != null && recipe.imageUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  recipe.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildImagePlaceholder(context),
                ),
              ),
            )
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _buildImagePlaceholder(context),
            ),
          const SizedBox(height: 16),

          // Name
          Text(
            recipe.name,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          // Tags
          if (recipe.tags != null && recipe.tags!.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: recipe.tags!
                  .map((tag) => Chip(
                        label: Text(tag),
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),
          ],

          // Time and servings info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (recipe.prepTimeMinutes != null)
                    _InfoRow(
                      icon: Icons.timer_outlined,
                      label: 'Prep time',
                      value: '${recipe.prepTimeMinutes} min',
                    ),
                  if (recipe.cookTimeMinutes != null)
                    _InfoRow(
                      icon: Icons.local_fire_department,
                      label: 'Cook time',
                      value: '${recipe.cookTimeMinutes} min',
                    ),
                  if (recipe.totalTimeMinutes != null)
                    _InfoRow(
                      icon: Icons.schedule,
                      label: 'Total time',
                      value: '${recipe.totalTimeMinutes} min',
                    ),
                  if (recipe.servings != null)
                    _InfoRow(
                      icon: Icons.people_outline,
                      label: 'Servings',
                      value: '${recipe.servings}',
                    ),
                ],
              ),
            ),
          ),

          // Ingredients
          if (recipe.ingredients.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppLocalizations.of(context)!.ingredients,
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    ...recipe.ingredients.map((ing) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Icon(Icons.fiber_manual_record,
                                  size: 8,
                                  color: Theme.of(context).colorScheme.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text.rich(
                                  TextSpan(children: [
                                    if (ing.quantity != null)
                                      TextSpan(
                                        text:
                                            '${ing.quantity!.truncateToDouble() == ing.quantity! ? ing.quantity!.toInt().toString() : ing.quantity.toString()} ',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600),
                                      ),
                                    if (ing.unit != null && ing.unit!.isNotEmpty)
                                      TextSpan(
                                        text: '${ing.unit} ',
                                        style: TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .outline),
                                      ),
                                    TextSpan(text: ing.name),
                                    if (ing.optional)
                                      TextSpan(
                                        text:
                                            ' (${AppLocalizations.of(context)!.optional})',
                                        style: TextStyle(
                                          fontStyle: FontStyle.italic,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .outline,
                                        ),
                                      ),
                                  ]),
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
            ),
          ],

          // Description
          if (recipe.description != null &&
              recipe.description!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppLocalizations.of(context)!.description,
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Text(recipe.description!),
                  ],
                ),
              ),
            ),
          ],

          // Instructions
          if (recipe.instructions != null &&
              recipe.instructions!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppLocalizations.of(context)!.instructions,
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Text(recipe.instructions!),
                  ],
                ),
              ),
            ),
          ],

          // Comments section
          const SizedBox(height: 24),
          CommentsSection(
            householdId: householdId,
            entityType: 'recipe',
            entityId: recipe.id,
          ),
        ],
      ),
    );
  }

  Widget _buildEditView(
      BuildContext context, Recipe recipe, String householdId) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.editRecipe),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            _disposeControllers();
            setState(() => _isEditing = false);
          },
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => _save(householdId),
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.save),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: l10n.recipeName,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.restaurant_menu),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descriptionController,
            decoration: InputDecoration(
              labelText: l10n.description,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.description),
              alignLabelWithHint: true,
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _instructionsController,
            decoration: InputDecoration(
              labelText: l10n.instructions,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.list_alt),
              alignLabelWithHint: true,
            ),
            maxLines: 6,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _prepTimeController,
                  decoration: InputDecoration(
                    labelText: l10n.prepTime,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.timer_outlined),
                    suffixText: 'min',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _cookTimeController,
                  decoration: InputDecoration(
                    labelText: l10n.cookTime,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.local_fire_department),
                    suffixText: 'min',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _servingsController,
            decoration: InputDecoration(
              labelText: l10n.servings,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.people_outline),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _tagsController,
            decoration: InputDecoration(
              labelText: l10n.tags,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.tag),
              hintText: 'e.g. vegetarian, quick, healthy',
            ),
          ),
          const SizedBox(height: 24),

          // Ingredients section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.ingredients,
                  style: Theme.of(context).textTheme.titleMedium),
              TextButton.icon(
                onPressed: () {
                  setState(() => _editIngredients.add(_IngredientEntry()));
                },
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.addIngredient),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (_editIngredients.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(l10n.noIngredients,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.outline)),
                ),
              ),
            )
          else
            ..._editIngredients.asMap().entries.map((entry) {
              final index = entry.key;
              final ing = entry.value;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: ing.nameController,
                              decoration: InputDecoration(
                                labelText: l10n.ingredientName,
                                border: const OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () {
                              setState(() {
                                _editIngredients[index].dispose();
                                _editIngredients.removeAt(index);
                              });
                            },
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: ing.quantityController,
                              decoration: InputDecoration(
                                labelText: l10n.quantity,
                                border: const OutlineInputBorder(),
                                isDense: true,
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: ing.unit,
                              decoration: InputDecoration(
                                labelText: l10n.unit,
                                border: const OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: _units
                                  .map((u) => DropdownMenuItem(
                                        value: u,
                                        child: Text(u.isEmpty ? '-' : u),
                                      ))
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => ing.unit = v ?? ''),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: ing.category,
                              decoration: InputDecoration(
                                labelText: l10n.category,
                                border: const OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: _categories
                                  .map((c) => DropdownMenuItem(
                                        value: c,
                                        child: Text(c),
                                      ))
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => ing.category = v ?? 'other'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Checkbox(
                            value: ing.optional,
                            onChanged: (v) =>
                                setState(() => ing.optional = v ?? false),
                            visualDensity: VisualDensity.compact,
                          ),
                          Text(l10n.optional),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildImagePlaceholder(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        color: Theme.of(context)
            .colorScheme
            .primaryContainer
            .withValues(alpha: 0.3),
        child: Center(
          child: Icon(
            Icons.restaurant_menu,
            size: 64,
            color:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
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

class _IngredientEntry {
  final TextEditingController nameController;
  final TextEditingController quantityController;
  String unit;
  String category;
  bool optional;

  _IngredientEntry({
    String name = '',
    String quantity = '',
    this.unit = '',
    this.category = 'other',
    this.optional = false,
  })  : nameController = TextEditingController(text: name),
        quantityController = TextEditingController(text: quantity);

  void dispose() {
    nameController.dispose();
    quantityController.dispose();
  }
}
