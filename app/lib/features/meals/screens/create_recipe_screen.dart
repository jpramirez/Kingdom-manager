import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../household/providers/household_provider.dart';
import '../providers/meal_provider.dart';

class CreateRecipeScreen extends ConsumerStatefulWidget {
  const CreateRecipeScreen({super.key});

  @override
  ConsumerState<CreateRecipeScreen> createState() =>
      _CreateRecipeScreenState();
}

class _CreateRecipeScreenState extends ConsumerState<CreateRecipeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _instructionsController = TextEditingController();
  final _prepTimeController = TextEditingController();
  final _cookTimeController = TextEditingController();
  final _servingsController = TextEditingController();
  final _tagsController = TextEditingController();

  final List<_IngredientEntry> _ingredients = [];
  bool _loading = false;

  static const _units = [
    '', 'kg', 'g', 'pcs', 'bottles', 'packs', 'L', 'mL',
    'cans', 'tbsp', 'tsp', 'cups',
  ];
  static const _categories = [
    'produce', 'dairy', 'meat', 'pantry', 'frozen', 'household', 'other',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _instructionsController.dispose();
    _prepTimeController.dispose();
    _cookTimeController.dispose();
    _servingsController.dispose();
    _tagsController.dispose();
    for (final ing in _ingredients) {
      ing.dispose();
    }
    super.dispose();
  }

  void _addIngredient() {
    setState(() {
      _ingredients.add(_IngredientEntry());
    });
  }

  void _removeIngredient(int index) {
    setState(() {
      _ingredients[index].dispose();
      _ingredients.removeAt(index);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final household = ref.read(activeHouseholdProvider).household;
    if (household == null) return;

    setState(() => _loading = true);
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

      final validIngredients = _ingredients
          .where((ing) => ing.nameController.text.trim().isNotEmpty)
          .toList();
      if (validIngredients.isNotEmpty) {
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
      }

      await ref
          .read(mealRepositoryProvider)
          .createRecipe(household.id, data);

      ref.invalidate(recipesProvider(household.id));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.recipeCreated)),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

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
        title: Text(l10n.createRecipe),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: l10n.recipeName,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.restaurant_menu),
              ),
              textInputAction: TextInputAction.next,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Recipe name is required';
                }
                return null;
              },
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
              textInputAction: TextInputAction.newline,
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
              textInputAction: TextInputAction.newline,
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
                Text(
                  l10n.ingredients,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                TextButton.icon(
                  onPressed: _addIngredient,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(l10n.addIngredient),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (_ingredients.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      l10n.noIngredients,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ),
                ),
              )
            else
              ..._ingredients.asMap().entries.map((entry) {
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
                              onPressed: () => _removeIngredient(index),
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

            const SizedBox(height: 32),

            FilledButton(
              onPressed: _loading ? null : _save,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }
}

class _IngredientEntry {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController quantityController = TextEditingController();
  String unit = '';
  String category = 'other';
  bool optional = false;

  void dispose() {
    nameController.dispose();
    quantityController.dispose();
  }
}
