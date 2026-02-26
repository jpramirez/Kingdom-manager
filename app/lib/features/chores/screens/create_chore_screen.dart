import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/enums.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../household/providers/household_provider.dart';
import '../providers/chore_provider.dart';

class CreateChoreScreen extends ConsumerStatefulWidget {
  const CreateChoreScreen({super.key});

  @override
  ConsumerState<CreateChoreScreen> createState() => _CreateChoreScreenState();
}

class _CreateChoreScreenState extends ConsumerState<CreateChoreScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _estimatedMinutesController = TextEditingController();

  ChoreCategory _selectedCategory = ChoreCategory.cleaning;
  ChorePriority _selectedPriority = ChorePriority.medium;
  DateTime? _selectedDueDate;
  bool _loading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _estimatedMinutesController.dispose();
    super.dispose();
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

  Future<void> _pickDueDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      setState(() {
        if (time != null) {
          _selectedDueDate = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        } else {
          _selectedDueDate = date;
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final household = ref.read(activeHouseholdProvider).household;
    if (household == null) return;

    setState(() => _loading = true);
    try {
      final data = <String, dynamic>{
        'title': _titleController.text.trim(),
        'category': _selectedCategory.value,
        'priority': _selectedPriority.value,
      };

      if (_descriptionController.text.trim().isNotEmpty) {
        data['description'] = _descriptionController.text.trim();
      }
      if (_selectedDueDate != null) {
        data['due_date'] = _selectedDueDate!.toIso8601String();
      }
      if (_estimatedMinutesController.text.trim().isNotEmpty) {
        data['estimated_minutes'] =
            int.tryParse(_estimatedMinutesController.text.trim());
      }
      if (_locationController.text.trim().isNotEmpty) {
        data['location'] = _locationController.text.trim();
      }

      await ref
          .read(choreRepositoryProvider)
          .createChore(household.id, data);

      ref.invalidate(choresProvider(household.id));
      ref.invalidate(todayAssignmentsProvider(household.id));

      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.choreCreated)),
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
        title: Text(l10n.createChore),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Title
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: l10n.choreTitle,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.title),
              ),
              textInputAction: TextInputAction.next,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Title is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: l10n.choreDescription,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.description),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
              textInputAction: TextInputAction.newline,
            ),
            const SizedBox(height: 16),

            // Category dropdown
            DropdownButtonFormField<ChoreCategory>(
              value: _selectedCategory,
              decoration: InputDecoration(
                labelText: l10n.category,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.category),
              ),
              items: ChoreCategory.values
                  .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(_categoryLabel(context, c)),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedCategory = value);
                }
              },
            ),
            const SizedBox(height: 16),

            // Priority chips
            Text(l10n.priority,
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ChorePriority.values.map((priority) {
                final isSelected = _selectedPriority == priority;
                return ChoiceChip(
                  label: Text(_priorityLabel(context, priority)),
                  selected: isSelected,
                  selectedColor:
                      _priorityColor(priority).withValues(alpha: 0.2),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedPriority = priority);
                    }
                  },
                  avatar: isSelected
                      ? Icon(Icons.check,
                          size: 18, color: _priorityColor(priority))
                      : null,
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Due date picker
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: Text(l10n.dueDate),
              subtitle: Text(
                _selectedDueDate != null
                    ? _formatDateTime(_selectedDueDate!)
                    : l10n.noDueDate,
              ),
              trailing: _selectedDueDate != null
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () =>
                          setState(() => _selectedDueDate = null),
                    )
                  : null,
              onTap: _pickDueDate,
            ),
            const Divider(),

            // Estimated minutes
            TextFormField(
              controller: _estimatedMinutesController,
              decoration: InputDecoration(
                labelText: l10n.estimatedMinutes,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.timer),
                suffixText: l10n.minutesShort,
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),

            // Location
            TextFormField(
              controller: _locationController,
              decoration: InputDecoration(
                labelText: l10n.location,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.location_on),
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
                  : Text(l10n.save),
            ),
          ],
        ),
      ),
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
