import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/calendar_event.dart';
import '../repositories/calendar_repository.dart';

final calendarRepositoryProvider =
    Provider<CalendarRepository>((ref) => CalendarRepository());

/// Fetch events for a given month range
class CalendarEventsParams {
  final String householdId;
  final DateTime startDate;
  final DateTime endDate;

  CalendarEventsParams({
    required this.householdId,
    required this.startDate,
    required this.endDate,
  });

  @override
  bool operator ==(Object other) =>
      other is CalendarEventsParams &&
      householdId == other.householdId &&
      startDate == other.startDate &&
      endDate == other.endDate;

  @override
  int get hashCode => Object.hash(householdId, startDate, endDate);
}

final calendarEventsProvider = FutureProvider.family<List<CalendarEvent>,
    CalendarEventsParams>((ref, params) async {
  return ref.read(calendarRepositoryProvider).getEvents(
        params.householdId,
        startDate: params.startDate,
        endDate: params.endDate,
      );
});

/// Selected day state
final selectedDayProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

/// Focused day (for month navigation)
final focusedDayProvider = StateProvider<DateTime>((ref) {
  return DateTime.now();
});
