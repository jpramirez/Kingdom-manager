import 'package:flutter/material.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../models/family_profile.dart';

class ProfileSummaryCard extends StatelessWidget {
  final FamilyProfile profile;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const ProfileSummaryCard({
    super.key,
    required this.profile,
    this.onEdit,
    this.onDelete,
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

  Color _roleColor(BuildContext context, String role) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (role) {
      case 'family_adult':
        return colorScheme.primary;
      case 'family_kid':
        return colorScheme.tertiary;
      case 'helper':
        return colorScheme.secondary;
      default:
        return colorScheme.outline;
    }
  }

  static const _langNames = {
    'en': 'English',
    'zh': '中文',
    'ms': 'Melayu',
    'tl': 'Tagalog',
    'id': 'Indonesia',
    'my': 'မြန်မာ',
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final roleColor = _roleColor(context, profile.role);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: roleColor, width: 4)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor:
                        roleColor.withValues(alpha: 0.15),
                    child: Text(
                      profile.name.isNotEmpty
                          ? profile.name[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                          color: roleColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.name,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: roleColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _roleLabel(l10n, profile.role),
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(color: roleColor),
                              ),
                            ),
                            if (profile.age != null) ...[
                              const SizedBox(width: 8),
                              Text(
                                '${profile.age}',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .outline,
                                    ),
                              ),
                            ],
                            const SizedBox(width: 8),
                            Text(
                              _langNames[profile.preferredLang] ??
                                  profile.preferredLang,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.outline,
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (onEdit != null)
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      onPressed: onEdit,
                      visualDensity: VisualDensity.compact,
                    ),
                  if (onDelete != null)
                    IconButton(
                      icon: Icon(Icons.delete_outline,
                          size: 18,
                          color: Theme.of(context).colorScheme.error),
                      onPressed: onDelete,
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              if (profile.dietaryPrefs.isNotEmpty ||
                  profile.allergies.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
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
                              size: 14,
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
              ],
            ],
          ),
        ),
      ),
    );
  }
}
