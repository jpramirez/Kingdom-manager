import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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

  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _instructionsController.dispose();
    _prepTimeController.dispose();
    _cookTimeController.dispose();
    _servingsController.dispose();
    _tagsController.dispose();
    super.dispose();
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

      await ref
          .read(mealRepositoryProvider)
          .createRecipe(household.id, data);

      ref.invalidate(recipesProvider(household.id));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recipe created')),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Recipe'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Recipe name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.restaurant_menu),
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

            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
              textInputAction: TextInputAction.newline,
            ),
            const SizedBox(height: 16),

            // Instructions
            TextFormField(
              controller: _instructionsController,
              decoration: const InputDecoration(
                labelText: 'Instructions',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.list_alt),
                alignLabelWithHint: true,
                hintText: 'Step-by-step cooking instructions...',
              ),
              maxLines: 6,
              textInputAction: TextInputAction.newline,
            ),
            const SizedBox(height: 16),

            // Prep and Cook time
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _prepTimeController,
                    decoration: const InputDecoration(
                      labelText: 'Prep time',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.timer_outlined),
                      suffixText: 'min',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _cookTimeController,
                    decoration: const InputDecoration(
                      labelText: 'Cook time',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.local_fire_department),
                      suffixText: 'min',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Servings
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

            // Tags
            TextFormField(
              controller: _tagsController,
              decoration: const InputDecoration(
                labelText: 'Tags (comma-separated)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.tag),
                hintText: 'e.g. vegetarian, quick, healthy',
              ),
            ),
            const SizedBox(height: 32),

            // Save button
            FilledButton(
              onPressed: _loading ? null : _save,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
