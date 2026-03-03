import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../settings/providers/locale_provider.dart';
import '../models/family_profile.dart';
import '../providers/family_profile_provider.dart';
import '../widgets/profile_summary_card.dart';

class FamilySetupWizardScreen extends ConsumerStatefulWidget {
  final String householdId;

  const FamilySetupWizardScreen({super.key, required this.householdId});

  @override
  ConsumerState<FamilySetupWizardScreen> createState() =>
      _FamilySetupWizardScreenState();
}

class _FamilySetupWizardScreenState
    extends ConsumerState<FamilySetupWizardScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();

  String _selectedRole = 'family_adult';
  String _selectedLang = 'en';
  final Set<String> _selectedDietary = {};
  final Set<String> _selectedAllergies = {};
  final Map<String, String> _mealTimes = {};
  bool _saving = false;

  static const _dietaryOptions = [
    'vegetarian',
    'vegan',
    'halal',
    'gluten-free',
    'lactose-free',
  ];

  static const _allergyOptions = [
    'peanuts',
    'tree nuts',
    'shellfish',
    'dairy',
    'eggs',
    'soy',
    'wheat',
  ];

  static const _mealTimeSlots = ['breakfast', 'lunch', 'dinner', 'snack'];

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _nameController.clear();
    _ageController.clear();
    setState(() {
      _selectedRole = 'family_adult';
      _selectedLang = 'en';
      _selectedDietary.clear();
      _selectedAllergies.clear();
      _mealTimes.clear();
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final data = {
        'name': _nameController.text.trim(),
        'role': _selectedRole,
        if (_ageController.text.trim().isNotEmpty)
          'age': int.tryParse(_ageController.text.trim()),
        'preferred_lang': _selectedLang,
        'dietary_prefs': _selectedDietary.toList(),
        'allergies': _selectedAllergies.toList(),
        'meal_times': _mealTimes,
      };

      await ref
          .read(familyProfileRepositoryProvider)
          .createProfile(widget.householdId, data);
      ref.invalidate(familyProfilesProvider(widget.householdId));

      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.profileSaved)),
        );
        _resetForm();
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

  Future<void> _deleteProfile(FamilyProfile profile) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.delete),
        content: Text('${l10n.delete} ${profile.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref
          .read(familyProfileRepositoryProvider)
          .deleteProfile(widget.householdId, profile.id);
      ref.invalidate(familyProfilesProvider(widget.householdId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.profileDeleted)),
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

  Future<void> _pickMealTime(String slot) async {
    final existing = _mealTimes[slot];
    TimeOfDay initial = const TimeOfDay(hour: 7, minute: 0);
    if (existing != null) {
      final parts = existing.split(':');
      initial = TimeOfDay(
          hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } else {
      switch (slot) {
        case 'breakfast':
          initial = const TimeOfDay(hour: 7, minute: 0);
        case 'lunch':
          initial = const TimeOfDay(hour: 12, minute: 0);
        case 'dinner':
          initial = const TimeOfDay(hour: 19, minute: 0);
        case 'snack':
          initial = const TimeOfDay(hour: 15, minute: 0);
      }
    }

    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      setState(() {
        _mealTimes[slot] = '${picked.hour.toString().padLeft(2, '0')}:'
            '${picked.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  String _mealSlotLabel(AppLocalizations l10n, String slot) {
    switch (slot) {
      case 'breakfast':
        return l10n.breakfast;
      case 'lunch':
        return l10n.lunch;
      case 'dinner':
        return l10n.dinner;
      case 'snack':
        return l10n.snack;
      default:
        return slot;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final profilesAsync =
        ref.watch(familyProfilesProvider(widget.householdId));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.familySetupTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Intro
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.family_restroom,
                      color: Theme.of(context)
                          .colorScheme
                          .onPrimaryContainer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.familySetupDesc,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Saved profiles
          profilesAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (e, _) => Text('${l10n.error}: $e'),
            data: (profiles) {
              if (profiles.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.reviewProfiles,
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  ...profiles.map((p) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ProfileSummaryCard(
                          profile: p,
                          onDelete: () => _deleteProfile(p),
                        ),
                      )),
                  const Divider(height: 32),
                ],
              );
            },
          ),

          // Add member form
          Text(l10n.addFamilyMember,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),

          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Name
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: l10n.profileName,
                    prefixIcon: const Icon(Icons.person),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? l10n.profileName : null,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),

                // Role
                DropdownButtonFormField<String>(
                  initialValue: _selectedRole,
                  decoration: InputDecoration(
                    labelText: l10n.profileRole,
                    prefixIcon: const Icon(Icons.badge),
                  ),
                  items: [
                    DropdownMenuItem(
                        value: 'family_adult',
                        child: Text(l10n.familyAdult)),
                    DropdownMenuItem(
                        value: 'family_kid',
                        child: Text(l10n.familyKid)),
                    DropdownMenuItem(
                        value: 'helper', child: Text(l10n.helper)),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedRole = v);
                  },
                ),
                const SizedBox(height: 12),

                // Age
                TextFormField(
                  controller: _ageController,
                  decoration: InputDecoration(
                    labelText: l10n.profileAge,
                    prefixIcon: const Icon(Icons.cake),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),

                // Language
                DropdownButtonFormField<String>(
                  initialValue: _selectedLang,
                  decoration: InputDecoration(
                    labelText: l10n.profileLanguage,
                    prefixIcon: const Icon(Icons.language),
                  ),
                  items: availableLocales.map((li) {
                    return DropdownMenuItem(
                      value: li.locale.languageCode,
                      child: Text('${li.nativeName} (${li.englishName})'),
                    );
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedLang = v);
                  },
                ),
                const SizedBox(height: 16),

                // Dietary preferences
                Text(l10n.dietaryPreferences,
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: _dietaryOptions.map((opt) {
                    final selected = _selectedDietary.contains(opt);
                    return FilterChip(
                      label: Text(opt),
                      selected: selected,
                      onSelected: (v) {
                        setState(() {
                          if (v) {
                            _selectedDietary.add(opt);
                          } else {
                            _selectedDietary.remove(opt);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Allergies
                Text(l10n.allergiesLabel,
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: _allergyOptions.map((opt) {
                    final selected = _selectedAllergies.contains(opt);
                    return FilterChip(
                      label: Text(opt),
                      selected: selected,
                      selectedColor: Theme.of(context)
                          .colorScheme
                          .errorContainer,
                      onSelected: (v) {
                        setState(() {
                          if (v) {
                            _selectedAllergies.add(opt);
                          } else {
                            _selectedAllergies.remove(opt);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Meal times
                Text(l10n.mealTimes,
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                ...(_mealTimeSlots).map((slot) {
                  final time = _mealTimes[slot];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.schedule),
                    title: Text(_mealSlotLabel(l10n, slot)),
                    trailing: TextButton(
                      onPressed: () => _pickMealTime(slot),
                      child: Text(time ?? l10n.add),
                    ),
                  );
                }),
                const SizedBox(height: 24),

                // Save button
                FilledButton.icon(
                  onPressed: _saving ? null : _saveProfile,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child:
                              CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.person_add),
                  label: Text(l10n.addFamilyMember),
                ),
                const SizedBox(height: 12),

                // Done button
                OutlinedButton(
                  onPressed: () => context.go('/'),
                  child: Text(l10n.done),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
