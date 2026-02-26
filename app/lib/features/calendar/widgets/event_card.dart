import 'package:flutter/material.dart';
import '../models/calendar_event.dart';

class EventCard extends StatelessWidget {
  final CalendarEvent event;
  final VoidCallback? onTap;

  const EventCard({
    super.key,
    required this.event,
    this.onTap,
  });

  Color _eventTypeColor(String eventType) {
    switch (eventType) {
      case 'chore':
        return Colors.orange;
      case 'activity':
        return Colors.blue;
      case 'meal':
        return Colors.green;
      case 'appointment':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _eventTypeIcon(String eventType) {
    switch (eventType) {
      case 'chore':
        return Icons.cleaning_services;
      case 'activity':
        return Icons.directions_run;
      case 'meal':
        return Icons.restaurant;
      case 'appointment':
        return Icons.event;
      default:
        return Icons.event_note;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _eventTypeColor(event.eventType);

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: color, width: 4)),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(_eventTypeIcon(event.eventType), color: color, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.access_time,
                            size: 14,
                            color: Theme.of(context).colorScheme.outline),
                        const SizedBox(width: 4),
                        Text(
                          event.allDay
                              ? 'All Day'
                              : _formatTimeRange(
                                  event.startTime, event.endTime),
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                        ),
                        if (event.location != null &&
                            event.location!.isNotEmpty) ...[
                          const SizedBox(width: 12),
                          Icon(Icons.location_on,
                              size: 14,
                              color: Theme.of(context).colorScheme.outline),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              event.location!,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.outline,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimeRange(DateTime start, DateTime? end) {
    final startStr =
        '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
    if (end == null) return startStr;
    final endStr =
        '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
    return '$startStr - $endStr';
  }
}
