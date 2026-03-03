import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../comments/widgets/comments_section.dart';
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
  bool _saving = false;

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
  }

  void _disposeControllers() {
    _nameController.dispose();
    _descriptionController.dispose();
    _instructionsController.dispose();
    _prepTimeController.dispose();
    _cookTimeController.dispose();
    _servingsController.dispose();
    _tagsController.dispose();
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
          context.go('/meals');
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
              context.go('/meals');
            }
          },
        ),
        title: const Text('Recipe'),
        actions: [
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
                    Text('Description',
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
                    Text('Instructions',
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Recipe'),
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
                : const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Recipe name',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.restaurant_menu),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.description),
              alignLabelWithHint: true,
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _instructionsController,
            decoration: const InputDecoration(
              labelText: 'Instructions',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.list_alt),
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
                  decoration: const InputDecoration(
                    labelText: 'Prep (min)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.timer_outlined),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _cookTimeController,
                  decoration: const InputDecoration(
                    labelText: 'Cook (min)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.local_fire_department),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _servingsController,
            decoration: const InputDecoration(
              labelText: 'Servings',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.people_outline),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _tagsController,
            decoration: const InputDecoration(
              labelText: 'Tags (comma-separated)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.tag),
              hintText: 'e.g. vegetarian, quick, healthy',
            ),
          ),
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
