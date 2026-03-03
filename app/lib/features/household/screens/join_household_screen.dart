import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../providers/household_provider.dart';

class JoinHouseholdScreen extends ConsumerStatefulWidget {
  const JoinHouseholdScreen({super.key});

  @override
  ConsumerState<JoinHouseholdScreen> createState() => _JoinHouseholdScreenState();
}

class _JoinHouseholdScreenState extends ConsumerState<JoinHouseholdScreen> {
  final _codeController = TextEditingController();
  String _selectedRole = 'helper';
  bool _loading = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    if (_codeController.text.trim().length != 8) return;
    setState(() => _loading = true);
    try {
      await ref.read(householdRepositoryProvider).joinHousehold(
            inviteCode: _codeController.text.trim(),
            role: _selectedRole,
          );
      await ref.read(activeHouseholdProvider.notifier).refresh();
      if (mounted) context.go('/');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to join: $e')),
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/household-setup');
            }
          },
        ),
        title: Text(l10n.joinHousehold),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.group_add, size: 64, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 24),
            TextFormField(
              controller: _codeController,
              decoration: InputDecoration(
                labelText: l10n.inviteCode,
                hintText: 'e.g. AB12CD34',
                border: const OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
              maxLength: 8,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _join(),
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'family_adult', label: Text(l10n.familyAdult)),
                ButtonSegment(value: 'family_kid', label: Text(l10n.familyKid)),
                ButtonSegment(value: 'helper', label: Text(l10n.helper)),
              ],
              selected: {_selectedRole},
              onSelectionChanged: (s) => setState(() => _selectedRole = s.first),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading ? null : _join,
              child: _loading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(l10n.join),
            ),
          ],
        ),
      ),
    );
  }
}
