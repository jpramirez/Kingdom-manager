import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/enums.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../household/providers/household_provider.dart';
import '../models/inventory_item.dart';
import '../providers/inventory_provider.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  InventoryLocation? _locationFilter;
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final household = ref.watch(activeHouseholdProvider).household;

    if (household == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.inventory)),
        body: const Center(child: Text('No household selected')),
      );
    }

    final itemsAsync = ref.watch(inventoryItemsProvider(household.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.inventory),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
      ),
      body: Column(
        children: [
          // Location filter chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _FilterChip(
                  label: l10n.all,
                  selected: _locationFilter == null,
                  onSelected: () => setState(() => _locationFilter = null),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: l10n.fridge,
                  icon: Icons.kitchen,
                  selected: _locationFilter == InventoryLocation.fridge,
                  onSelected: () =>
                      setState(() => _locationFilter = InventoryLocation.fridge),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: l10n.freezer,
                  icon: Icons.ac_unit,
                  selected: _locationFilter == InventoryLocation.freezer,
                  onSelected: () => setState(
                      () => _locationFilter = InventoryLocation.freezer),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: l10n.pantry,
                  icon: Icons.shelves,
                  selected: _locationFilter == InventoryLocation.pantry,
                  onSelected: () => setState(
                      () => _locationFilter = InventoryLocation.pantry),
                ),
              ],
            ),
          ),
          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              decoration: InputDecoration(
                hintText: l10n.search,
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _search = v.toLowerCase()),
            ),
          ),
          const SizedBox(height: 8),
          // Items list
          Expanded(
            child: itemsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Error: $e'),
                    FilledButton(
                      onPressed: () => ref
                          .invalidate(inventoryItemsProvider(household.id)),
                      child: Text(l10n.retry),
                    ),
                  ],
                ),
              ),
              data: (items) {
                var filtered = items;
                if (_locationFilter != null) {
                  filtered = filtered
                      .where((i) => i.location == _locationFilter)
                      .toList();
                }
                if (_search.isNotEmpty) {
                  filtered = filtered
                      .where(
                          (i) => i.name.toLowerCase().contains(_search))
                      .toList();
                }

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inventory_2_outlined,
                            size: 64,
                            color: Theme.of(context).colorScheme.outline),
                        const SizedBox(height: 16),
                        Text(l10n.noInventoryItems,
                            style: TextStyle(
                                color:
                                    Theme.of(context).colorScheme.outline)),
                      ],
                    ),
                  );
                }

                // Group by category
                final grouped = <String, List<InventoryItem>>{};
                for (final item in filtered) {
                  grouped
                      .putIfAbsent(item.category.value, () => [])
                      .add(item);
                }

                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: grouped.entries.map((entry) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            entry.key[0].toUpperCase() +
                                entry.key.substring(1),
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary),
                          ),
                        ),
                        ...entry.value.map((item) => _InventoryItemTile(
                              item: item,
                              householdId: household.id,
                            )),
                      ],
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/inventory/add'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    this.icon,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16),
            const SizedBox(width: 4),
          ],
          Text(label),
        ],
      ),
      selected: selected,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _InventoryItemTile extends ConsumerWidget {
  final InventoryItem item;
  final String householdId;

  const _InventoryItemTile({
    required this.item,
    required this.householdId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    Color? expiryColor;
    String? expiryLabel;
    if (item.isExpired) {
      expiryColor = Colors.red;
      expiryLabel = l10n.expired;
    } else if (item.isExpiringSoon) {
      expiryColor = Colors.orange;
      expiryLabel = l10n.expiringSoon;
    }

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.delete),
            content: Text('${l10n.delete} "${item.name}"?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(l10n.cancel)),
              FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  style:
                      FilledButton.styleFrom(backgroundColor: Colors.red),
                  child: Text(l10n.delete)),
            ],
          ),
        );
      },
      onDismissed: (_) async {
        try {
          await ref
              .read(inventoryRepositoryProvider)
              .deleteItem(householdId, item.id);
          ref.invalidate(inventoryItemsProvider(householdId));
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text('Error: $e')));
          }
        }
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 4),
        child: ListTile(
          leading: _locationIcon(item.location),
          title: Text(item.name),
          subtitle: Row(
            children: [
              if (item.quantity != null) ...[
                Text(
                  '${item.quantity!.truncateToDouble() == item.quantity! ? item.quantity!.toInt().toString() : item.quantity.toString()}'
                  '${item.unit != null ? " ${item.unit}" : ""}',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.outline),
                ),
                const SizedBox(width: 8),
              ],
              if (expiryLabel != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: expiryColor?.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(expiryLabel,
                      style: TextStyle(
                          color: expiryColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          trailing: item.expiryDate != null
              ? Text(
                  '${item.expiryDate!.day}/${item.expiryDate!.month}',
                  style: TextStyle(
                      color: expiryColor ??
                          Theme.of(context).colorScheme.outline,
                      fontSize: 12),
                )
              : null,
          dense: true,
        ),
      ),
    );
  }

  Widget _locationIcon(InventoryLocation location) {
    switch (location) {
      case InventoryLocation.fridge:
        return const Icon(Icons.kitchen, color: Colors.blue);
      case InventoryLocation.freezer:
        return const Icon(Icons.ac_unit, color: Colors.cyan);
      case InventoryLocation.pantry:
        return const Icon(Icons.shelves, color: Colors.brown);
    }
  }
}
