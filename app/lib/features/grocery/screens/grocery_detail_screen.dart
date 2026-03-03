import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/enums.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../comments/widgets/comments_section.dart';
import '../../household/providers/household_provider.dart';
import '../models/grocery.dart';
import '../providers/grocery_provider.dart';

class GroceryDetailScreen extends ConsumerStatefulWidget {
  final String listId;

  const GroceryDetailScreen({super.key, required this.listId});

  @override
  ConsumerState<GroceryDetailScreen> createState() =>
      _GroceryDetailScreenState();
}

class _GroceryDetailScreenState extends ConsumerState<GroceryDetailScreen> {
  String _categoryLabel(BuildContext context, GroceryCategory category) {
    final l10n = AppLocalizations.of(context)!;
    switch (category) {
      case GroceryCategory.produce:
        return l10n.produce;
      case GroceryCategory.dairy:
        return l10n.dairy;
      case GroceryCategory.meat:
        return l10n.meat;
      case GroceryCategory.pantry:
        return l10n.pantry;
      case GroceryCategory.frozen:
        return l10n.frozen;
      case GroceryCategory.household:
        return l10n.household;
      case GroceryCategory.other:
        return l10n.other;
    }
  }

  Future<void> _showAddItemDialog(String householdId) async {
    final l10n = AppLocalizations.of(context)!;
    final nameController = TextEditingController();
    final qtyController = TextEditingController();
    final notesController = TextEditingController();
    String selectedCategory = 'other';
    String? selectedUnit;
    final units = ['kg', 'g', 'pcs', 'bottles', 'packs', 'L', 'mL', 'cans'];

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(l10n.addItem),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: l10n.itemName,
                    border: const OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: qtyController,
                        decoration: InputDecoration(
                          labelText: l10n.quantity,
                          border: const OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedUnit,
                        decoration: InputDecoration(
                          labelText: l10n.unit,
                          border: const OutlineInputBorder(),
                        ),
                        items: units.map((u) => DropdownMenuItem(
                          value: u,
                          child: Text(u),
                        )).toList(),
                        onChanged: (v) =>
                            setDialogState(() => selectedUnit = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: InputDecoration(
                    labelText: l10n.category,
                    border: const OutlineInputBorder(),
                  ),
                  items: GroceryCategory.values.map((c) => DropdownMenuItem(
                    value: c.value,
                    child: Text(_categoryLabel(context, c)),
                  )).toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setDialogState(() => selectedCategory = v);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  decoration: InputDecoration(
                    labelText: l10n.notes,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
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
                    'category': selectedCategory,
                  };
                  if (qtyController.text.trim().isNotEmpty) {
                    data['quantity'] =
                        double.tryParse(qtyController.text.trim());
                  }
                  if (selectedUnit != null) data['unit'] = selectedUnit;
                  if (notesController.text.trim().isNotEmpty) {
                    data['notes'] = notesController.text.trim();
                  }
                  await ref.read(groceryRepositoryProvider).addItem(
                        householdId,
                        widget.listId,
                        data,
                      );
                  _refreshItems(householdId);
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
              child: Text(l10n.addItem),
            ),
          ],
        ),
      ),
    );
  }

  void _refreshItems(String householdId) {
    ref.invalidate(groceryItemsProvider(GroceryItemsParams(
      householdId: householdId,
      listId: widget.listId,
    )));
    ref.invalidate(groceryListsProvider(householdId));
  }

  Future<void> _toggleItem(
      String householdId, GroceryItem item) async {
    try {
      await ref.read(groceryRepositoryProvider).toggleItem(
            householdId,
            widget.listId,
            item.id,
            !item.isChecked,
          );
      _refreshItems(householdId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _removeItem(
      String householdId, GroceryItem item) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await ref.read(groceryRepositoryProvider).removeItem(
            householdId,
            widget.listId,
            item.id,
          );
      _refreshItems(householdId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${item.name} removed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                context.go('/grocery');
              }
            },
          ),
          title: Text(l10n.groceryList),
        ),
        body: const Center(child: Text('No household')),
      );
    }

    final itemsParams = GroceryItemsParams(
      householdId: household.id,
      listId: widget.listId,
    );
    final itemsAsync = ref.watch(groceryItemsProvider(itemsParams));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/grocery');
            }
          },
        ),
        title: Text(l10n.groceryList),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(l10n.delete),
                  content: const Text('Delete this grocery list?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: Text(l10n.cancel),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: FilledButton.styleFrom(
                          backgroundColor: Colors.red),
                      child: Text(l10n.delete),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                try {
                  await ref.read(groceryRepositoryProvider).deleteList(
                        household.id,
                        widget.listId,
                      );
                  ref.invalidate(groceryListsProvider(household.id));
                  if (mounted) context.pop();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              }
            },
          ),
        ],
      ),
      body: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${l10n.error}: $e'),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () =>
                    ref.invalidate(groceryItemsProvider(itemsParams)),
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const SizedBox(height: 48),
                Icon(Icons.receipt_long_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.outline),
                const SizedBox(height: 16),
                Center(
                  child: Text(l10n.noItems,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          )),
                ),
                const SizedBox(height: 32),
                CommentsSection(
                  householdId: household.id,
                  entityType: 'grocery_list',
                  entityId: widget.listId,
                ),
              ],
            );
          }

          // Group by category
          final grouped = <GroceryCategory, List<GroceryItem>>{};
          for (final item in items) {
            grouped.putIfAbsent(item.category, () => []).add(item);
          }
          final categories = grouped.keys.toList()
            ..sort((a, b) => a.value.compareTo(b.value));

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(groceryItemsProvider(itemsParams));
              await ref.read(groceryItemsProvider(itemsParams).future);
            },
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: categories.length + 1,
              itemBuilder: (context, index) {
                // Last item: comments section
                if (index == categories.length) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: CommentsSection(
                      householdId: household.id,
                      entityType: 'grocery_list',
                      entityId: widget.listId,
                    ),
                  );
                }

                final category = categories[index];
                final categoryItems = grouped[category]!;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Text(
                        _categoryLabel(context, category),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    ...categoryItems.map((item) => Dismissible(
                          key: Key(item.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            color: Colors.red,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child: const Icon(Icons.delete,
                                color: Colors.white),
                          ),
                          onDismissed: (_) =>
                              _removeItem(household.id, item),
                          child: CheckboxListTile(
                            value: item.isChecked,
                            onChanged: (_) =>
                                _toggleItem(household.id, item),
                            title: Text(
                              item.name,
                              style: TextStyle(
                                decoration: item.isChecked
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: item.isChecked
                                    ? Theme.of(context).colorScheme.outline
                                    : null,
                              ),
                            ),
                            subtitle: _buildSubtitle(item),
                            controlAffinity:
                                ListTileControlAffinity.leading,
                          ),
                        )),
                  ],
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddItemDialog(household.id),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget? _buildSubtitle(GroceryItem item) {
    final parts = <String>[];
    if (item.quantity != null) {
      final qty = item.quantity! % 1 == 0
          ? item.quantity!.toInt().toString()
          : item.quantity.toString();
      parts.add(item.unit != null ? '$qty ${item.unit}' : qty);
    }
    if (item.notes != null && item.notes!.isNotEmpty) {
      parts.add(item.notes!);
    }
    if (parts.isEmpty) return null;
    return Text(parts.join(' • '));
  }
}
