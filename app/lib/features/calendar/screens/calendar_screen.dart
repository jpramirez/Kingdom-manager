import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../household/providers/household_provider.dart';
import '../models/calendar_event.dart';
import '../providers/calendar_provider.dart';
import '../widgets/event_card.dart';

class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final household = ref.watch(activeHouseholdProvider).household;
    final selectedDay = ref.watch(selectedDayProvider);
    final focusedDay = ref.watch(focusedDayProvider);

    if (household == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.calendar)),
        body: const Center(child: Text('No household selected')),
      );
    }

    // Fetch events for the focused month (with padding)
    final firstDay = DateTime(focusedDay.year, focusedDay.month - 1, 1);
    final lastDay = DateTime(focusedDay.year, focusedDay.month + 2, 0);

    final eventsParams = CalendarEventsParams(
      householdId: household.id,
      startDate: firstDay,
      endDate: lastDay,
    );
    final eventsAsync = ref.watch(calendarEventsProvider(eventsParams));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.calendar),
        actions: [
          IconButton(
            icon: const Icon(Icons.today),
            tooltip: 'Today',
            onPressed: () {
              final now = DateTime.now();
              ref.read(selectedDayProvider.notifier).state =
                  DateTime(now.year, now.month, now.day);
              ref.read(focusedDayProvider.notifier).state = now;
            },
          ),
        ],
      ),
      body: Column(
        children: [
          eventsAsync.when(
            loading: () => _buildCalendar(
                context, ref, selectedDay, focusedDay, [], l10n),
            error: (_, __) => _buildCalendar(
                context, ref, selectedDay, focusedDay, [], l10n),
            data: (events) => _buildCalendar(
                context, ref, selectedDay, focusedDay, events, l10n),
          ),
          const Divider(height: 1),
          Expanded(
            child: eventsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${l10n.error}: $e'),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: () => ref
                          .invalidate(calendarEventsProvider(eventsParams)),
                      child: Text(l10n.retry),
                    ),
                  ],
                ),
              ),
              data: (events) {
                final dayEvents = events.where((e) {
                  final eventDate = DateTime(
                      e.startTime.year, e.startTime.month, e.startTime.day);
                  return isSameDay(eventDate, selectedDay);
                }).toList()
                  ..sort((a, b) => a.startTime.compareTo(b.startTime));

                if (dayEvents.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.event_available,
                            size: 48,
                            color: Theme.of(context).colorScheme.outline),
                        const SizedBox(height: 8),
                        Text(l10n.noEventsForDay,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color:
                                      Theme.of(context).colorScheme.outline,
                                )),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(calendarEventsProvider(eventsParams));
                    await ref
                        .read(calendarEventsProvider(eventsParams).future);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: dayEvents.length,
                    itemBuilder: (context, index) {
                      return EventCard(
                        event: dayEvents[index],
                        onTap: () => _showEventDetail(
                            context, ref, household.id, dayEvents[index]),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/calendar/create'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildCalendar(
    BuildContext context,
    WidgetRef ref,
    DateTime selectedDay,
    DateTime focusedDay,
    List<CalendarEvent> events,
    AppLocalizations l10n,
  ) {
    return TableCalendar<CalendarEvent>(
      firstDay: DateTime(2020, 1, 1),
      lastDay: DateTime(2030, 12, 31),
      focusedDay: focusedDay,
      selectedDayPredicate: (day) => isSameDay(selectedDay, day),
      calendarFormat: CalendarFormat.month,
      startingDayOfWeek: StartingDayOfWeek.monday,
      eventLoader: (day) {
        return events.where((e) {
          final eventDate =
              DateTime(e.startTime.year, e.startTime.month, e.startTime.day);
          return isSameDay(eventDate, day);
        }).toList();
      },
      onDaySelected: (selected, focused) {
        ref.read(selectedDayProvider.notifier).state = selected;
        ref.read(focusedDayProvider.notifier).state = focused;
      },
      onPageChanged: (focused) {
        ref.read(focusedDayProvider.notifier).state = focused;
      },
      calendarStyle: CalendarStyle(
        todayDecoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          shape: BoxShape.circle,
        ),
        todayTextStyle: TextStyle(
          color: Theme.of(context).colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.bold,
        ),
        selectedDecoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          shape: BoxShape.circle,
        ),
        selectedTextStyle: TextStyle(
          color: Theme.of(context).colorScheme.onPrimary,
          fontWeight: FontWeight.bold,
        ),
        markerDecoration: BoxDecoration(
          color: Theme.of(context).colorScheme.tertiary,
          shape: BoxShape.circle,
        ),
        markerSize: 6,
        markersMaxCount: 3,
      ),
      headerStyle: HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
        titleTextStyle: Theme.of(context).textTheme.titleMedium!,
      ),
    );
  }

  void _showEventDetail(
    BuildContext context,
    WidgetRef ref,
    String householdId,
    CalendarEvent event,
  ) {
    final l10n = AppLocalizations.of(context)!;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(event.title,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _eventTypeChip(context, event.eventType),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.access_time),
              title: Text(event.allDay
                  ? 'All Day'
                  : _formatTime(event.startTime)),
              subtitle: event.endTime != null && !event.allDay
                  ? Text('to ${_formatTime(event.endTime!)}')
                  : null,
            ),
            if (event.description != null &&
                event.description!.isNotEmpty) ...[
              const Divider(),
              Text(l10n.choreDescription,
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(event.description!),
            ],
            if (event.location != null &&
                event.location!.isNotEmpty) ...[
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.location_on),
                title: Text(event.location!),
              ),
            ],
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _deleteEvent(context, ref, householdId, event);
                  },
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  label: Text(l10n.delete,
                      style: const TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _eventTypeChip(BuildContext context, String eventType) {
    final colors = {
      'chore': Colors.orange,
      'activity': Colors.blue,
      'meal': Colors.green,
      'appointment': Colors.purple,
      'other': Colors.grey,
    };
    final color = colors[eventType] ?? Colors.grey;
    return Chip(
      label: Text(eventType[0].toUpperCase() + eventType.substring(1)),
      backgroundColor: color.withValues(alpha: 0.15),
      side: BorderSide.none,
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w600),
      visualDensity: VisualDensity.compact,
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _deleteEvent(
    BuildContext context,
    WidgetRef ref,
    String householdId,
    CalendarEvent event,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.delete),
        content: Text('Delete "${event.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await ref
            .read(calendarRepositoryProvider)
            .deleteEvent(householdId, event.id);
        ref.invalidate(calendarEventsProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Event deleted')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }
}
