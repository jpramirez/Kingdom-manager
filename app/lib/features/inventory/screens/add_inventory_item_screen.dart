import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/enums.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../household/providers/household_provider.dart';
import '../providers/inventory_provider.dart';

class AddInventoryItemScreen extends ConsumerStatefulWidget {
  const AddInventoryItemScreen({super.key});

  @override
  ConsumerState<AddInventoryItemScreen> createState() =>
      _AddInventoryItemScreenState();
}

class _AddInventoryItemScreenState
    extends ConsumerState<AddInventoryItemScreen> {
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _barcodeController = TextEditingController();
  String _unit = '';
  String _category = 'other';
  InventoryLocation _location = InventoryLocation.pantry;
  DateTime? _expiryDate;
  bool _saving = false;

  static const _units = [
    '', 'kg', 'g', 'pcs', 'bottles', 'packs', 'L', 'mL', 'cans',
  ];
  static const _categories = [
    'produce', 'dairy', 'meat', 'pantry', 'frozen', 'household', 'other',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _barcodeController.dispose();
    super.dispose();
  }

  Future<void> _save(String householdId) async {
    if (_nameController.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final data = <String, dynamic>{
        'name': _nameController.text.trim(),
        'category': _category,
        'location': _location.value,
      };
      if (_quantityController.text.trim().isNotEmpty) {
        data['quantity'] = double.tryParse(_quantityController.text.trim());
      }
      if (_unit.isNotEmpty) data['unit'] = _unit;
      if (_barcodeController.text.trim().isNotEmpty) {
        data['barcode'] = _barcodeController.text.trim();
      }
      if (_expiryDate != null) {
        data['expiry_date'] =
            _expiryDate!.toIso8601String().split('T').first;
      }

      await ref
          .read(inventoryRepositoryProvider)
          .createItem(householdId, data);
      ref.invalidate(inventoryItemsProvider(householdId));

      if (mounted) {
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final household = ref.watch(activeHouseholdProvider).household;

    if (household == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.addToInventory)),
        body: const Center(child: Text('No household selected')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.addToInventory),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => _save(household.id),
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.save),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: l10n.name,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.inventory_2_outlined),
            ),
            autofocus: true,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _quantityController,
                  decoration: InputDecoration(
                    labelText: l10n.quantity,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.numbers),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _unit,
                  decoration: InputDecoration(
                    labelText: l10n.unit,
                    border: const OutlineInputBorder(),
                  ),
                  items: _units
                      .map((u) => DropdownMenuItem(
                            value: u,
                            child: Text(u.isEmpty ? '-' : u),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _unit = v ?? ''),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: InputDecoration(
              labelText: l10n.category,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.category),
            ),
            items: _categories
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) => setState(() => _category = v ?? 'other'),
          ),
          const SizedBox(height: 16),
          // Location selector
          Text(l10n.location,
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<InventoryLocation>(
            segments: [
              ButtonSegment(
                value: InventoryLocation.fridge,
                label: Text(l10n.fridge),
                icon: const Icon(Icons.kitchen),
              ),
              ButtonSegment(
                value: InventoryLocation.freezer,
                label: Text(l10n.freezer),
                icon: const Icon(Icons.ac_unit),
              ),
              ButtonSegment(
                value: InventoryLocation.pantry,
                label: Text(l10n.pantry),
                icon: const Icon(Icons.shelves),
              ),
            ],
            selected: {_location},
            onSelectionChanged: (s) =>
                setState(() => _location = s.first),
          ),
          const SizedBox(height: 16),
          // Expiry date
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event),
            title: Text(l10n.expiryDate),
            subtitle: _expiryDate != null
                ? Text(
                    '${_expiryDate!.day}/${_expiryDate!.month}/${_expiryDate!.year}')
                : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_expiryDate != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() => _expiryDate = null),
                  ),
                IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate:
                          _expiryDate ?? DateTime.now().add(const Duration(days: 7)),
                      firstDate: DateTime.now(),
                      lastDate:
                          DateTime.now().add(const Duration(days: 365 * 3)),
                    );
                    if (picked != null) {
                      setState(() => _expiryDate = picked);
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _barcodeController,
            decoration: InputDecoration(
              labelText: l10n.barcode,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.qr_code),
            ),
          ),
        ],
      ),
    );
  }
}
