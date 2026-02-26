import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../models/calendar_event.dart';

class CalendarRepository {
  final ApiClient _api = ApiClient();

  Future<List<CalendarEvent>> getEvents(
    String householdId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final queryParams = <String, dynamic>{};
    if (startDate != null) {
      queryParams['start_date'] = startDate.toIso8601String();
    }
    if (endDate != null) {
      queryParams['end_date'] = endDate.toIso8601String();
    }
    final response = await _api.get(
      ApiEndpoints.calendar(householdId),
      queryParameters: queryParams.isEmpty ? null : queryParams,
    );
    final list = response.data as List;
    return list
        .map((e) => CalendarEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CalendarEvent> createEvent(
    String householdId,
    Map<String, dynamic> data,
  ) async {
    final response = await _api.post(
      ApiEndpoints.calendar(householdId),
      data: data,
    );
    return CalendarEvent.fromJson(response.data);
  }

  Future<CalendarEvent> updateEvent(
    String householdId,
    String eventId,
    Map<String, dynamic> data,
  ) async {
    final response = await _api.patch(
      ApiEndpoints.calendarEvent(householdId, eventId),
      data: data,
    );
    return CalendarEvent.fromJson(response.data);
  }

  Future<void> deleteEvent(String householdId, String eventId) async {
    await _api.delete(ApiEndpoints.calendarEvent(householdId, eventId));
  }
}
