import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../models/household.dart';
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
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/settings');
              }
            },
          ),
          title: Text(l10n.members),
        ),
        body: const Center(child: Text('No household selected')),
      );
    }

    final membersAsync = ref.watch(membersProvider(household.id));
    final currentMemberAsync = ref.watch(currentMemberProvider);
    final canManage = currentMemberAsync.valueOrNull?.canManage ?? false;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/settings');
            }
          },
        ),
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
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
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
                    title: Row(
                      children: [
                        Flexible(
                          child: Text(member.nickname ?? member.displayName),
                        ),
                        if (member.isAdmin) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.shield,
                              size: 16,
                              color: Theme.of(context).colorScheme.primary),
                        ],
                      ],
                    ),
                    subtitle: Text(_roleLabel(context, member.role)),
                    trailing: canManage
                        ? PopupMenuButton<String>(
                            onSelected: (action) =>
                                _handleMemberAction(context, ref, action, member, household.id),
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'edit',
                                child: ListTile(
                                  leading: const Icon(Icons.edit),
                                  title: Text(l10n.changeRole),
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                              PopupMenuItem(
                                value: 'remove',
                                child: ListTile(
                                  leading: Icon(Icons.person_remove,
                                      color: Theme.of(context).colorScheme.error),
                                  title: Text(l10n.removeMember,
                                      style: TextStyle(
                                          color: Theme.of(context).colorScheme.error)),
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ],
                          )
                        : Chip(label: Text(member.role.replaceAll('_', ' '))),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleMemberAction(
    BuildContext context,
    WidgetRef ref,
    String action,
    HouseholdMember member,
    String householdId,
  ) {
    switch (action) {
      case 'edit':
        _showEditMemberDialog(context, ref, member, householdId);
        break;
      case 'remove':
        _showRemoveConfirmDialog(context, ref, member, householdId);
        break;
    }
  }

  void _showEditMemberDialog(
    BuildContext context,
    WidgetRef ref,
    HouseholdMember member,
    String householdId,
  ) {
    final l10n = AppLocalizations.of(context)!;
    var selectedRole = member.role;
    var isAdmin = member.isAdmin;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(l10n.changeRole),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(member.displayName,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 16),
                  Text(l10n.selectRole),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                        value: 'family_adult',
                        label: Text(l10n.familyAdult),
                        icon: const Icon(Icons.person),
                      ),
                      ButtonSegment(
                        value: 'family_kid',
                        label: Text(l10n.familyKid),
                        icon: const Icon(Icons.child_care),
                      ),
                      ButtonSegment(
                        value: 'helper',
                        label: Text(l10n.helper),
                        icon: const Icon(Icons.support_agent),
                      ),
                    ],
                    selected: {selectedRole},
                    onSelectionChanged: (selection) {
                      setState(() {
                        selectedRole = selection.first;
                        if (selectedRole != 'helper') {
                          isAdmin = false;
                        }
                      });
                    },
                  ),
                  if (selectedRole == 'helper') ...[
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: Text(l10n.adminAccess),
                      subtitle: Text(l10n.admin),
                      value: isAdmin,
                      onChanged: (value) {
                        setState(() => isAdmin = value);
                      },
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: () async {
                    Navigator.pop(dialogContext);
                    try {
                      await ref
                          .read(householdRepositoryProvider)
                          .updateMember(
                            householdId,
                            member.id,
                            role: selectedRole != member.role ? selectedRole : null,
                            isAdmin: isAdmin != member.isAdmin ? isAdmin : null,
                          );
                      ref.invalidate(membersProvider(householdId));
                      ref.invalidate(currentMemberProvider);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.memberUpdated)),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('$e')),
                        );
                      }
                    }
                  },
                  child: Text(l10n.save),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showRemoveConfirmDialog(
    BuildContext context,
    WidgetRef ref,
    HouseholdMember member,
    String householdId,
  ) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.removeMember),
          content: Text(l10n.removeMemberConfirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () async {
                Navigator.pop(dialogContext);
                try {
                  await ref
                      .read(householdRepositoryProvider)
                      .removeMember(householdId, member.id);
                  ref.invalidate(membersProvider(householdId));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.memberRemoved)),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$e')),
                    );
                  }
                }
              },
              child: Text(l10n.removeMember),
            ),
          ],
        );
      },
    );
  }
}
