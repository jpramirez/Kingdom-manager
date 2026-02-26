import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/generated/app_localizations.dart';

class HouseholdSetupScreen extends StatelessWidget {
  const HouseholdSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.home_rounded, size: 80, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                l10n.appTitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 48),
              FilledButton.icon(
                onPressed: () => context.go('/create-household'),
                icon: const Icon(Icons.add),
                label: Text(l10n.createHousehold),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => context.go('/join-household'),
                icon: const Icon(Icons.group_add),
                label: Text(l10n.joinHousehold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
