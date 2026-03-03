import 'package:flutter/material.dart';
import '../../../l10n/generated/app_localizations.dart';

class AiSuggestionChips extends StatelessWidget {
  final void Function(String suggestion) onTap;
  final String? taskHint;

  const AiSuggestionChips({super.key, required this.onTap, this.taskHint});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final suggestions = _getSuggestions(l10n);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: suggestions.map((text) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              label: Text(text),
              onPressed: () => onTap(text),
            ),
          );
        }).toList(),
      ),
    );
  }

  List<String> _getSuggestions(AppLocalizations l10n) {
    switch (taskHint) {
      case 'chore_scheduling':
        return [
          'What chores are due today?',
          'Assign laundry to the helper',
          'Create a weekly cleaning schedule',
          'Suggest chores for the kids',
        ];
      case 'meal_planning':
        return [
          'Plan dinners for this week',
          'What\'s for lunch today?',
          'Suggest meals considering allergies',
          'What meals are planned this week?',
        ];
      case 'grocery':
        return [
          'Build a grocery list from meal plan',
          'What do we need for this week?',
          'Add pantry staples to the list',
          'What\'s on the grocery list?',
        ];
      case 'calendar':
        return [
          'What\'s happening this week?',
          'Schedule a family outing Saturday',
          'When is the next event?',
          'Add a reminder for the doctor visit',
        ];
      default:
        return [
          l10n.aiSuggestMealPlan,
          l10n.aiSuggestChores,
          l10n.aiSuggestGrocery,
          l10n.aiSuggestEvent,
        ];
    }
  }
}
