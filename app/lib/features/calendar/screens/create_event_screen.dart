import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../household/providers/household_provider.dart';
import '../providers/calendar_provider.dart';

class CreateEventScreen extends ConsumerStatefulWidget {
  const CreateEventScreen({super.key});

  @override
  ConsumerState<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends ConsumerState<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();

  String _selectedEventType = 'other';
  DateTime _startTime = DateTime.now().add(const Duration(hours: 1));
  DateTime? _endTime;
  bool _allDay = false;
  bool _loading = false;

  final _eventTypes = ['chore', 'activity', 'meal', 'appointment', 'other'];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final initialDate = isStart ? _startTime : (_endTime ?? _startTime);
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (date == null) return;

    if (_allDay) {
      setState(() {
        if (isStart) {
          _startTime = DateTime(date.year, date.month, date.day);
        } else {
          _endTime = DateTime(date.year, date.month, date.day, 23, 59);
        }
      });
      return;
    }

    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );

    setState(() {
      final dt = DateTime(
        date.year, date.month, date.day,
        time?.hour ?? initialDate.hour,
        time?.minute ?? initialDate.minute,
      );
      if (isStart) {
        _startTime = dt;
      } else {
        _endTime = dt;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final household = ref.read(activeHouseholdProvider).household;
    if (household == null) return;

    setState(() => _loading = true);
    try {
      final data = <String, dynamic>{
        'title': _titleController.text.trim(),
        'event_type': _selectedEventType,
        'start_time': _startTime.toIso8601String(),
        'all_day': _allDay,
      };
      if (_descriptionController.text.trim().isNotEmpty) {
        data['description'] = _descriptionController.text.trim();
      }
      if (_endTime != null) {
        data['end_time'] = _endTime!.toIso8601String();
      }
      if (_locationController.text.trim().isNotEmpty) {
        data['location'] = _locationController.text.trim();
      }

      await ref
          .read(calendarRepositoryProvider)
          .createEvent(household.id, data);

      ref.invalidate(calendarEventsProvider);

      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.eventCreated)),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
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
              context.go('/calendar');
            }
          },
        ),
        title: Text(l10n.createEvent),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: l10n.eventTitle,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.title),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Title is required' : null,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: l10n.choreDescription,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.description),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: _selectedEventType,
              decoration: InputDecoration(
                labelText: l10n.eventType,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.category),
              ),
              items: _eventTypes.map((t) => DropdownMenuItem(
                value: t,
                child: Text(t[0].toUpperCase() + t.substring(1)),
              )).toList(),
              onChanged: (v) {
                if (v != null) setState(() => _selectedEventType = v);
              },
            ),
            const SizedBox(height: 16),

            SwitchListTile(
              title: Text(l10n.allDay),
              value: _allDay,
              onChanged: (v) => setState(() => _allDay = v),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 8),

            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.play_arrow),
              title: Text(l10n.startTime),
              subtitle: Text(_formatDateTime(_startTime)),
              onTap: () => _pickDateTime(isStart: true),
            ),

            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.stop),
              title: Text(l10n.endTime),
              subtitle: Text(_endTime != null
                  ? _formatDateTime(_endTime!)
                  : l10n.noEndTime),
              trailing: _endTime != null
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _endTime = null),
                    )
                  : null,
              onTap: () => _pickDateTime(isStart: false),
            ),
            const SizedBox(height: 8),

            TextFormField(
              controller: _locationController,
              decoration: InputDecoration(
                labelText: l10n.location,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.location_on),
              ),
            ),
            const SizedBox(height: 32),

            FilledButton(
              onPressed: _loading ? null : _save,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final date = '${dt.day}/${dt.month}/${dt.year}';
    if (_allDay) return date;
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$date $h:$m';
  }
}
