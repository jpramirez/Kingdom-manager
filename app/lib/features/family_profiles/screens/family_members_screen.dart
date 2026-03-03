import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../household/providers/household_provider.dart';
import '../../settings/providers/locale_provider.dart';
import '../models/family_profile.dart';
import '../providers/family_profile_provider.dart';
class FamilyMembersScreen extends ConsumerWidget {
  const FamilyMembersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final household = ref.watch(activeHouseholdProvider).household;

    if (household == null) {
      return Scaffold(
        appBar: AppBar(
          leading: _backButton(context),
          title: Text(l10n.familyMembers),
        ),
        body: const Center(child: Text('No household selected')),
      );
    }

    final profilesAsync = ref.watch(familyProfilesProvider(household.id));
    final currentMember = ref.watch(currentMemberProvider).valueOrNull;
    final canManage = currentMember?.canManage ?? false;

    return Scaffold(
      appBar: AppBar(
        leading: _backButton(context),
        title: Text(l10n.familyMembers),
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
      body: profilesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (profiles) => ListView(
          padding: const EdgeInsets.only(bottom: 80),
          children: [
            // Invite code card
            _InviteCodeCard(
              inviteCode: household.inviteCode,
              householdName: household.name,
            ),
            // Family members list
            if (profiles.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    l10n.familySetupDesc,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                ),
              )
            else
              ...profiles.map((profile) => _FamilyMemberTile(
                    profile: profile,
                    canManage: canManage,
                    householdId: household.id,
                  )),
          ],
        ),
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => _showAddMemberSheet(context, ref, household.id),
              icon: const Icon(Icons.person_add),
              label: Text(l10n.addFamilyMember),
            )
          : null,
    );
  }

  Widget _backButton(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/settings');
        }
      },
    );
  }

  void _showAddMemberSheet(BuildContext context, WidgetRef ref, String householdId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _AddMemberSheet(householdId: householdId),
    );
  }
}

// ── Invite Code Card ─────────────────────────────────────────────

class _InviteCodeCard extends StatelessWidget {
  final String inviteCode;
  final String householdName;

  const _InviteCodeCard({
    required this.inviteCode,
    required this.householdName,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Card(
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                inviteCode,
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
                    Clipboard.setData(ClipboardData(text: inviteCode));
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
                      '${l10n.joinMyHousehold} $householdName!\n${l10n.useInviteCode} $inviteCode',
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
    );
  }
}

// ── Family Member Tile ───────────────────────────────────────────

class _FamilyMemberTile extends ConsumerWidget {
  final FamilyProfile profile;
  final bool canManage;
  final String householdId;

  const _FamilyMemberTile({
    required this.profile,
    required this.canManage,
    required this.householdId,
  });

  String _roleLabel(AppLocalizations l10n, String role) {
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

  Color _statusColor(BuildContext context) {
    if (profile.isLinked) return Colors.green;
    if (profile.hasPendingInvite) return Colors.orange;
    return Theme.of(context).colorScheme.outline;
  }

  String _statusLabel(AppLocalizations l10n) {
    if (profile.isLinked) return l10n.appAccount;
    if (profile.hasPendingInvite) return l10n.pendingInvite;
    return l10n.noAppAccount;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(_roleIcon(profile.role)),
        ),
        title: Row(
          children: [
            Flexible(child: Text(profile.name)),
            if (profile.isAdmin) ...[
              const SizedBox(width: 6),
              Icon(Icons.shield,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(_roleLabel(l10n, profile.role)),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: _statusColor(context).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        profile.isLinked
                            ? Icons.link
                            : profile.hasPendingInvite
                                ? Icons.mail_outline
                                : Icons.person_outline,
                        size: 12,
                        color: _statusColor(context),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _statusLabel(l10n),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: _statusColor(context),
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (profile.isLinked && profile.linkedUserEmail != null)
              Text(
                profile.linkedUserEmail!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            if (profile.dietaryPrefs.isNotEmpty || profile.allergies.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(
                  spacing: 4,
                  runSpacing: 2,
                  children: [
                    ...profile.dietaryPrefs.map((d) => Chip(
                          label: Text(d),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          labelStyle:
                              Theme.of(context).textTheme.labelSmall,
                          padding: EdgeInsets.zero,
                        )),
                    ...profile.allergies.map((a) => Chip(
                          avatar: Icon(Icons.warning_amber,
                              size: 12,
                              color: Theme.of(context).colorScheme.error),
                          label: Text(a),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          labelStyle:
                              Theme.of(context).textTheme.labelSmall,
                          padding: EdgeInsets.zero,
                        )),
                  ],
                ),
              ),
          ],
        ),
        isThreeLine: true,
        trailing: canManage
            ? PopupMenuButton<String>(
                onSelected: (action) =>
                    _handleAction(context, ref, action),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: const Icon(Icons.edit),
                      title: Text(l10n.editProfile),
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
            : null,
      ),
    );
  }

  void _handleAction(BuildContext context, WidgetRef ref, String action) {
    switch (action) {
      case 'edit':
        _showEditSheet(context, ref);
      case 'remove':
        _showRemoveDialog(context, ref);
    }
  }

  void _showEditSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _EditMemberSheet(
        householdId: householdId,
        profile: profile,
      ),
    );
  }

  void _showRemoveDialog(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.removeMember),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.removeMemberConfirm),
            if (profile.isLinked) ...[
              const SizedBox(height: 8),
              Text(
                l10n.removeProfileLinkedWarning,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w500,
                ),
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
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await ref
                    .read(familyProfileRepositoryProvider)
                    .deleteProfile(householdId, profile.id);
                ref.invalidate(familyProfilesProvider(householdId));
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
      ),
    );
  }
}

// ── Add Member Bottom Sheet ──────────────────────────────────────

class _AddMemberSheet extends ConsumerStatefulWidget {
  final String householdId;

  const _AddMemberSheet({required this.householdId});

  @override
  ConsumerState<_AddMemberSheet> createState() => _AddMemberSheetState();
}

class _AddMemberSheetState extends ConsumerState<_AddMemberSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _contactController = TextEditingController();

  String _selectedRole = 'family_adult';
  String _selectedLang = 'en';
  final Set<String> _selectedDietary = {};
  final Set<String> _selectedAllergies = {};
  final Map<String, String> _mealTimes = {};
  bool _saving = false;
  bool _showAdvanced = false;

  static const _dietaryOptions = [
    'vegetarian', 'vegan', 'halal', 'gluten-free', 'lactose-free',
  ];
  static const _allergyOptions = [
    'peanuts', 'tree nuts', 'shellfish', 'dairy', 'eggs', 'soy', 'wheat',
  ];
  static const _mealTimeSlots = ['breakfast', 'lunch', 'dinner', 'snack'];

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final contact = _contactController.text.trim();
      String? inviteEmail;
      String? invitePhone;
      if (contact.isNotEmpty) {
        if (contact.contains('@')) {
          inviteEmail = contact;
        } else {
          invitePhone = contact;
        }
      }

      final data = {
        'name': _nameController.text.trim(),
        'role': _selectedRole,
        if (_ageController.text.trim().isNotEmpty)
          'age': int.tryParse(_ageController.text.trim()),
        'preferred_lang': _selectedLang,
        'dietary_prefs': _selectedDietary.toList(),
        'allergies': _selectedAllergies.toList(),
        'meal_times': _mealTimes,
        if (inviteEmail != null) 'invite_email': inviteEmail,
        if (invitePhone != null) 'invite_phone': invitePhone,
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
        Navigator.pop(context);
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

  String _mealSlotLabel(AppLocalizations l10n, String slot) {
    switch (slot) {
      case 'breakfast': return l10n.breakfast;
      case 'lunch': return l10n.lunch;
      case 'dinner': return l10n.dinner;
      case 'snack': return l10n.snack;
      default: return slot;
    }
  }

  Future<void> _pickMealTime(String slot) async {
    TimeOfDay initial;
    final existing = _mealTimes[slot];
    if (existing != null) {
      final parts = existing.split(':');
      initial = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } else {
      switch (slot) {
        case 'breakfast': initial = const TimeOfDay(hour: 7, minute: 0);
        case 'lunch': initial = const TimeOfDay(hour: 12, minute: 0);
        case 'dinner': initial = const TimeOfDay(hour: 19, minute: 0);
        default: initial = const TimeOfDay(hour: 15, minute: 0);
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            controller: scrollController,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(l10n.addFamilyMember,
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),

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
                  DropdownMenuItem(value: 'family_adult', child: Text(l10n.familyAdult)),
                  DropdownMenuItem(value: 'family_kid', child: Text(l10n.familyKid)),
                  DropdownMenuItem(value: 'helper', child: Text(l10n.helper)),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _selectedRole = v);
                },
              ),
              const SizedBox(height: 12),

              // Email or Phone (optional)
              TextFormField(
                controller: _contactController,
                decoration: InputDecoration(
                  labelText: l10n.inviteEmailOrPhone,
                  prefixIcon: const Icon(Icons.mail_outline),
                  helperText: l10n.inviteEmailHint,
                ),
                keyboardType: TextInputType.emailAddress,
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

              // Advanced section toggle
              InkWell(
                onTap: () => setState(() => _showAdvanced = !_showAdvanced),
                child: Row(
                  children: [
                    Icon(_showAdvanced
                        ? Icons.expand_less
                        : Icons.expand_more),
                    const SizedBox(width: 8),
                    Text(
                      '${l10n.dietaryPreferences} / ${l10n.allergiesLabel} / ${l10n.mealTimes}',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
              ),

              if (_showAdvanced) ...[
                const SizedBox(height: 12),
                // Dietary
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
                      selectedColor:
                          Theme.of(context).colorScheme.errorContainer,
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
                ..._mealTimeSlots.map((slot) {
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
              ],

              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.person_add),
                label: Text(l10n.addFamilyMember),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Edit Member Bottom Sheet ─────────────────────────────────────

class _EditMemberSheet extends ConsumerStatefulWidget {
  final String householdId;
  final FamilyProfile profile;

  const _EditMemberSheet({
    required this.householdId,
    required this.profile,
  });

  @override
  ConsumerState<_EditMemberSheet> createState() => _EditMemberSheetState();
}

class _EditMemberSheetState extends ConsumerState<_EditMemberSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _ageController;
  late final TextEditingController _contactController;

  late String _selectedRole;
  late String _selectedLang;
  late bool _isAdmin;
  late Set<String> _selectedDietary;
  late Set<String> _selectedAllergies;
  late Map<String, String> _mealTimes;
  bool _saving = false;

  static const _dietaryOptions = [
    'vegetarian', 'vegan', 'halal', 'gluten-free', 'lactose-free',
  ];
  static const _allergyOptions = [
    'peanuts', 'tree nuts', 'shellfish', 'dairy', 'eggs', 'soy', 'wheat',
  ];
  static const _mealTimeSlots = ['breakfast', 'lunch', 'dinner', 'snack'];

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _nameController = TextEditingController(text: p.name);
    _ageController = TextEditingController(text: p.age?.toString() ?? '');
    _contactController = TextEditingController(
      text: p.inviteEmail ?? p.invitePhone ?? '',
    );
    _selectedRole = p.role;
    _selectedLang = p.preferredLang;
    _isAdmin = p.isAdmin;
    _selectedDietary = Set.from(p.dietaryPrefs);
    _selectedAllergies = Set.from(p.allergies);
    _mealTimes = Map.from(p.mealTimes);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final contact = _contactController.text.trim();
      String? inviteEmail;
      String? invitePhone;
      if (contact.isNotEmpty) {
        if (contact.contains('@')) {
          inviteEmail = contact;
        } else {
          invitePhone = contact;
        }
      }

      final data = <String, dynamic>{
        'name': _nameController.text.trim(),
        'role': _selectedRole,
        'preferred_lang': _selectedLang,
        'is_admin': _isAdmin,
        'dietary_prefs': _selectedDietary.toList(),
        'allergies': _selectedAllergies.toList(),
        'meal_times': _mealTimes,
      };
      final ageText = _ageController.text.trim();
      if (ageText.isNotEmpty) {
        data['age'] = int.tryParse(ageText);
      }
      if (inviteEmail != null) data['invite_email'] = inviteEmail;
      if (invitePhone != null) data['invite_phone'] = invitePhone;

      await ref
          .read(familyProfileRepositoryProvider)
          .updateProfile(widget.householdId, widget.profile.id, data);
      ref.invalidate(familyProfilesProvider(widget.householdId));
      ref.invalidate(membersProvider(widget.householdId));
      ref.invalidate(currentMemberProvider);

      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.memberUpdated)),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _mealSlotLabel(AppLocalizations l10n, String slot) {
    switch (slot) {
      case 'breakfast': return l10n.breakfast;
      case 'lunch': return l10n.lunch;
      case 'dinner': return l10n.dinner;
      case 'snack': return l10n.snack;
      default: return slot;
    }
  }

  Future<void> _pickMealTime(String slot) async {
    TimeOfDay initial;
    final existing = _mealTimes[slot];
    if (existing != null) {
      final parts = existing.split(':');
      initial = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } else {
      switch (slot) {
        case 'breakfast': initial = const TimeOfDay(hour: 7, minute: 0);
        case 'lunch': initial = const TimeOfDay(hour: 12, minute: 0);
        case 'dinner': initial = const TimeOfDay(hour: 19, minute: 0);
        default: initial = const TimeOfDay(hour: 15, minute: 0);
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(l10n.editProfile,
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),

              // Name
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: l10n.profileName,
                  prefixIcon: const Icon(Icons.person),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? l10n.profileName : null,
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
                  DropdownMenuItem(value: 'family_adult', child: Text(l10n.familyAdult)),
                  DropdownMenuItem(value: 'family_kid', child: Text(l10n.familyKid)),
                  DropdownMenuItem(value: 'helper', child: Text(l10n.helper)),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      _selectedRole = v;
                      if (v != 'helper') _isAdmin = false;
                    });
                  }
                },
              ),
              const SizedBox(height: 12),

              // Admin toggle (only for helpers)
              if (_selectedRole == 'helper')
                SwitchListTile(
                  title: Text(l10n.adminAccess),
                  subtitle: Text(l10n.admin),
                  value: _isAdmin,
                  onChanged: (v) => setState(() => _isAdmin = v),
                ),

              // Contact
              if (!widget.profile.isLinked) ...[
                TextFormField(
                  controller: _contactController,
                  decoration: InputDecoration(
                    labelText: l10n.inviteEmailOrPhone,
                    prefixIcon: const Icon(Icons.mail_outline),
                    helperText: l10n.inviteEmailHint,
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
              ],

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

              // Dietary
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
                    selectedColor:
                        Theme.of(context).colorScheme.errorContainer,
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
              ..._mealTimeSlots.map((slot) {
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
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.save),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
