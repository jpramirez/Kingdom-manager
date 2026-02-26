import 'package:flutter/material.dart';
import '../../../l10n/generated/app_localizations.dart';

class AiSuggestionChips extends StatelessWidget {
  final void Function(String suggestion) onTap;

  const AiSuggestionChips({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Localized suggestion chips
    final suggestions = [
      l10n.aiSuggestMealPlan,
      l10n.aiSuggestChores,
      l10n.aiSuggestGrocery,
      l10n.aiSuggestEvent,
    ];

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
}
