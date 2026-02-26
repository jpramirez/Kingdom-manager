import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../providers/household_provider.dart';

class MembersScreen extends ConsumerWidget {
  const MembersScreen({super.key});

  String _roleLabel(BuildContext context, String role) {
    final l10n = AppLocalizations.of(context)!;
    switch (role) {
      case 'family_adult':
        return l10n.familyAdult;
      case 'family_kid':
        return l10n.familyKid;
      case 'helper':
        return l10n.helper;
      default:
        return role;
    }
  }

  IconData _roleIcon(String role) {
    switch (role) {
      case 'family_adult':
        return Icons.person;
      case 'family_kid':
        return Icons.child_care;
      case 'helper':
        return Icons.support_agent;
      default:
        return Icons.person_outline;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final household = ref.watch(activeHouseholdProvider).household;
    if (household == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.members)),
        body: const Center(child: Text('No household selected')),
      );
    }

    final membersAsync = ref.watch(membersProvider(household.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.members),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: l10n.shareInvite,
            onPressed: () {
              Share.share(
                '${l10n.joinMyHousehold} ${household.name}!\n${l10n.useInviteCode} ${household.inviteCode}',
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Invite code card
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.vpn_key,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(l10n.inviteCode,
                          style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      household.inviteCode,
                      textAlign: TextAlign.center,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 4,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer,
                              ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          Clipboard.setData(
                              ClipboardData(text: household.inviteCode));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.codeCopied)),
                          );
                        },
                        icon: const Icon(Icons.copy, size: 18),
                        label: Text(l10n.copyCode),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: () {
                          Share.share(
                            '${l10n.joinMyHousehold} ${household.name}!\n${l10n.useInviteCode} ${household.inviteCode}',
                          );
                        },
                        icon: const Icon(Icons.share, size: 18),
                        label: Text(l10n.shareInvite),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Members list
          Expanded(
            child: membersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (members) => ListView.builder(
                itemCount: members.length,
                itemBuilder: (context, index) {
                  final member = members[index];
                  return ListTile(
                    leading: CircleAvatar(
                      child: Icon(_roleIcon(member.role)),
                    ),
                    title: Text(member.nickname ?? member.displayName),
                    subtitle: Text(_roleLabel(context, member.role)),
                    trailing:
                        Chip(label: Text(member.role.replaceAll('_', ' '))),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
