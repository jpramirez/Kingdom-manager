import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/providers/auth_provider.dart';
import '../../household/providers/household_provider.dart';
import '../providers/locale_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final user = ref.watch(authStateProvider).valueOrNull;
    final household = ref.watch(activeHouseholdProvider).household;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        children: [
          // User profile section
          if (user != null)
            ListTile(
              leading: CircleAvatar(
                child: Text(user.displayName[0].toUpperCase()),
              ),
              title: Text(user.displayName),
              subtitle: Text(user.email),
            ),
          const Divider(),

          // Household section
          if (household != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(l10n.household, style: Theme.of(context).textTheme.titleSmall),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: Text(household.name),
              subtitle: Text('${l10n.inviteCode}: ${household.inviteCode}'),
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: Text(l10n.members),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/members'),
            ),
            const Divider(),
          ],

          // Language section
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(l10n.language, style: Theme.of(context).textTheme.titleSmall),
          ),
          ...availableLocales.map((localeInfo) {
            return RadioListTile<String>(
              title: Text(localeInfo.nativeName),
              subtitle: Text(localeInfo.englishName),
              value: localeInfo.locale.languageCode,
              groupValue: ref.watch(localeProvider)?.languageCode ??
                  Localizations.localeOf(context).languageCode,
              onChanged: (value) {
                if (value != null) {
                  ref.read(localeProvider.notifier).setLocale(Locale(value));
                }
              },
            );
          }),
          const Divider(),

          // Logout
          ListTile(
            leading: Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
            title: Text(l10n.logout, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            onTap: () async {
              await ref.read(authStateProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
    );
  }
}
