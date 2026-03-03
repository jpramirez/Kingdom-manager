import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../household/providers/household_provider.dart';
import '../models/grocery.dart';
import '../providers/grocery_provider.dart';

class GroceryScreen extends ConsumerWidget {
  const GroceryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final household = ref.watch(activeHouseholdProvider).household;

    if (household == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.grocery)),
        body: const Center(child: Text('No household selected')),
      );
    }

    final canManage = ref.watch(currentMemberProvider).valueOrNull?.canManage ?? false;
    final listsAsync = ref.watch(groceryListsProvider(household.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.grocery),
        actions: [
          if (canManage)
            IconButton(
              icon: const Icon(Icons.smart_toy_outlined),
              tooltip: l10n.aiAskAboutGrocery,
              onPressed: () => context.push('/ai-chat', extra: {
                'initialMessage':
                    'Generate a grocery list from this week\'s meal plan. Check what we already have on active grocery lists and only add what\'s missing.',
                'taskHint': 'grocery',
              }),
            ),
        ],
      ),
      body: listsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${l10n.error}: $e'),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () =>
                    ref.invalidate(groceryListsProvider(household.id)),
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
        data: (lists) {
          if (lists.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shopping_cart_outlined,
                      size: 64,
                      color: Theme.of(context).colorScheme.outline),
                  const SizedBox(height: 16),
                  Text(l10n.noGroceryLists,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          )),
                ],
              ),
            );
          }

          // Group by delivery date
          final withDate = <DateTime, List<GroceryList>>{};
          final noDate = <GroceryList>[];

          for (final gl in lists) {
            if (gl.deliveryDate != null) {
              final dateKey = DateTime(
                gl.deliveryDate!.year,
                gl.deliveryDate!.month,
                gl.deliveryDate!.day,
              );
              withDate.putIfAbsent(dateKey, () => []).add(gl);
            } else {
              noDate.add(gl);
            }
          }

          final sortedDates = withDate.keys.toList()..sort();

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(groceryListsProvider(household.id));
              await ref.read(groceryListsProvider(household.id).future);
            },
            child: ListView(
              padding: const EdgeInsets.only(bottom: 80),
              children: [
                for (final date in sortedDates) ...[
                  _DateHeader(date: date),
                  ...withDate[date]!.map((gl) => _GroceryListTile(
                        groceryList: gl,
                        householdId: household.id,
                        onTap: () => context.push('/grocery/${gl.id}'),
                      )),
                ],
                if (noDate.isNotEmpty) ...[
                  _DateHeader(date: null),
                  ...noDate.map((gl) => _GroceryListTile(
                        groceryList: gl,
                        householdId: household.id,
                        onTap: () => context.push('/grocery/${gl.id}'),
                      )),
                ],
              ],
            ),
          );
        },
      ),
      floatingActionButton: canManage
          ? FloatingActionButton(
              onPressed: () => _showCreateListDialog(context, ref, household.id),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Future<void> _showCreateListDialog(
      BuildContext context, WidgetRef ref, String householdId) async {
    final l10n = AppLocalizations.of(context)!;
    final nameController = TextEditingController();
    DateTime? deliveryDate;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(l10n.createGroceryList),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: l10n.listName,
                  border: const OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.local_shipping),
                title: Text(l10n.deliveryDate),
                subtitle: Text(
                  deliveryDate != null
                      ? '${deliveryDate!.day}/${deliveryDate!.month}/${deliveryDate!.year}'
                      : l10n.noDeliveryDate,
                ),
                onTap: () async {
                  final date = await showDatePicker(
                    context: ctx,
                    initialDate: deliveryDate ?? DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate:
                        DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    setDialogState(() => deliveryDate = date);
                  }
                },
                trailing: deliveryDate != null
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () =>
                            setDialogState(() => deliveryDate = null),
                      )
                    : null,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;
                Navigator.of(ctx).pop();
                try {
                  final data = <String, dynamic>{
                    'name': nameController.text.trim(),
                  };
                  if (deliveryDate != null) {
                    data['delivery_date'] = deliveryDate!
                        .toIso8601String()
                        .split('T')
                        .first;
                  }
                  await ref
                      .read(groceryRepositoryProvider)
                      .createList(householdId, data);
                  ref.invalidate(groceryListsProvider(householdId));
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
              child: Text(l10n.create),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateHeader extends StatelessWidget {
  final DateTime? date;

  const _DateHeader({this.date});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    String label;
    if (date == null) {
      label = l10n.noDeliveryDate;
    } else {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final dateOnly = DateTime(date!.year, date!.month, date!.day);

      if (dateOnly == today) {
        label = l10n.today;
      } else if (dateOnly == today.add(const Duration(days: 1))) {
        label = l10n.tomorrow;
      } else {
        final weekday = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        label =
            '${weekday[date!.weekday - 1]}, ${date!.day}/${date!.month}/${date!.year}';
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _GroceryListTile extends StatelessWidget {
  final GroceryList groceryList;
  final String householdId;
  final VoidCallback? onTap;

  const _GroceryListTile({
    required this.groceryList,
    required this.householdId,
    this.onTap,
  });

  Color _statusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.blue;
      case 'shopping':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final statusColor = _statusColor(groceryList.status);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: statusColor, width: 4)),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.shopping_bag_outlined,
                      color: statusColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      groceryList.name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      groceryList.status[0].toUpperCase() +
                          groceryList.status.substring(1),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '${groceryList.checkedCount}/${l10n.itemCount(groceryList.itemCount)}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: groceryList.progress,
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
