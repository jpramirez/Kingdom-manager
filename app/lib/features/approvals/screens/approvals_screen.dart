import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/providers/auth_provider.dart';
import '../../household/providers/household_provider.dart';
import '../models/approval.dart';
import '../providers/approval_provider.dart';
import '../widgets/approval_card.dart';

class ApprovalsScreen extends ConsumerWidget {
  const ApprovalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final household = ref.watch(activeHouseholdProvider).household;

    Widget backButton() => IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/');
        }
      },
    );

    if (household == null) {
      return Scaffold(
        appBar: AppBar(leading: backButton(), title: Text(l10n.approvals)),
        body: Center(child: Text(l10n.noHouseholdSelected)),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          leading: backButton(),
          title: Text(l10n.approvals),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.pending),
              Tab(text: l10n.allApprovals),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _PendingTab(householdId: household.id),
            _AllTab(householdId: household.id),
          ],
        ),
      ),
    );
  }
}

class _PendingTab extends ConsumerWidget {
  final String householdId;
  const _PendingTab({required this.householdId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final approvalsAsync = ref.watch(pendingApprovalsProvider(householdId));
    final membersAsync = ref.watch(membersProvider(householdId));
    final authState = ref.watch(authStateProvider);
    final currentUser = authState.valueOrNull;

    // Determine if the current user is a family_adult
    final isFamilyAdult = membersAsync.whenOrNull(
          data: (members) {
            if (currentUser == null) return false;
            final me = members.where((m) => m.userId == currentUser.id);
            return me.isNotEmpty && me.first.role == 'family_adult';
          },
        ) ??
        false;

    return approvalsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${l10n.error}: $e'),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () =>
                  ref.invalidate(pendingApprovalsProvider(householdId)),
              child: Text(l10n.retry),
            ),
          ],
        ),
      ),
      data: (approvals) {
        if (approvals.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.approval,
                    size: 64,
                    color: Theme.of(context).colorScheme.outline),
                const SizedBox(height: 16),
                Text(
                  l10n.noPendingApprovals,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(pendingApprovalsProvider(householdId));
            await ref.read(pendingApprovalsProvider(householdId).future);
          },
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 80),
            itemCount: approvals.length,
            itemBuilder: (context, index) {
              final approval = approvals[index];
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                child: ApprovalCard(
                  approval: approval,
                  canApprove: isFamilyAdult,
                  onApprove: isFamilyAdult
                      ? () => _handleApprove(context, ref, approval)
                      : null,
                  onReject: isFamilyAdult
                      ? () => _handleReject(context, ref, approval)
                      : null,
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _handleApprove(
      BuildContext context, WidgetRef ref, ApprovalRequest approval) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.approveRequest),
        content: Text('Approve "${approval.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.approve),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref
          .read(approvalRepositoryProvider)
          .approveRequest(householdId, approval.id);
      ref.invalidate(pendingApprovalsProvider(householdId));
      ref.invalidate(allApprovalsProvider(householdId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.requestApproved)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.error}: $e')),
        );
      }
    }
  }

  Future<void> _handleReject(
      BuildContext context, WidgetRef ref, ApprovalRequest approval) async {
    final l10n = AppLocalizations.of(context)!;
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.rejectRequest),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reject "${approval.title}"?'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: l10n.reasonOptional,
                border: const OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(l10n.reject),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final reason =
          reasonController.text.trim().isNotEmpty ? reasonController.text.trim() : null;
      await ref
          .read(approvalRepositoryProvider)
          .rejectRequest(householdId, approval.id, reason: reason);
      ref.invalidate(pendingApprovalsProvider(householdId));
      ref.invalidate(allApprovalsProvider(householdId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.requestRejected)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.error}: $e')),
        );
      }
    } finally {
      reasonController.dispose();
    }
  }
}

class _AllTab extends ConsumerWidget {
  final String householdId;
  const _AllTab({required this.householdId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final approvalsAsync = ref.watch(allApprovalsProvider(householdId));

    return approvalsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${l10n.error}: $e'),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () =>
                  ref.invalidate(allApprovalsProvider(householdId)),
              child: Text(l10n.retry),
            ),
          ],
        ),
      ),
      data: (approvals) {
        if (approvals.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.approval,
                    size: 64,
                    color: Theme.of(context).colorScheme.outline),
                const SizedBox(height: 16),
                Text(
                  l10n.noApprovalsYet,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(allApprovalsProvider(householdId));
            await ref.read(allApprovalsProvider(householdId).future);
          },
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 80),
            itemCount: approvals.length,
            itemBuilder: (context, index) {
              final approval = approvals[index];
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                child: ApprovalCard(approval: approval),
              );
            },
          ),
        );
      },
    );
  }
}
