class CalendarEvent {
  final String id;
  final String householdId;
  final String title;
  final String? description;
  final String eventType;
  final DateTime startTime;
  final DateTime? endTime;
  final bool allDay;
  final String? recurrenceRule;
  final String? location;
  final double? locationLat;
  final double? locationLng;
  final String? sourceId;
  final String? sourceType;
  final String createdBy;
  final DateTime createdAt;

  CalendarEvent({
    required this.id,
    required this.householdId,
    required this.title,
    this.description,
    required this.eventType,
    required this.startTime,
    this.endTime,
    required this.allDay,
    this.recurrenceRule,
    this.location,
    this.locationLat,
    this.locationLng,
    this.sourceId,
    this.sourceType,
    required this.createdBy,
    required this.createdAt,
  });

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    return CalendarEvent(
      id: json['id'] as String,
      householdId: json['household_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      eventType: json['event_type'] as String? ?? 'other',
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: json['end_time'] != null
          ? DateTime.parse(json['end_time'] as String)
          : null,
      allDay: json['all_day'] as bool? ?? false,
      recurrenceRule: json['recurrence_rule'] as String?,
      location: json['location'] as String?,
      locationLat: (json['location_lat'] as num?)?.toDouble(),
      locationLng: (json['location_lng'] as num?)?.toDouble(),
      sourceId: json['source_id'] as String?,
      sourceType: json['source_type'] as String?,
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'event_type': eventType,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'all_day': allDay,
      'recurrence_rule': recurrenceRule,
      'location': location,
      'location_lat': locationLat,
      'location_lng': locationLng,
    };
  }

  CalendarEvent copyWith({
    String? title,
    String? description,
    String? eventType,
    DateTime? startTime,
    DateTime? endTime,
    bool? allDay,
    String? recurrenceRule,
    String? location,
    double? locationLat,
    double? locationLng,
  }) {
    return CalendarEvent(
      id: id,
      householdId: householdId,
      title: title ?? this.title,
      description: description ?? this.description,
      eventType: eventType ?? this.eventType,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      allDay: allDay ?? this.allDay,
      recurrenceRule: recurrenceRule ?? this.recurrenceRule,
      location: location ?? this.location,
      locationLat: locationLat ?? this.locationLat,
      locationLng: locationLng ?? this.locationLng,
      sourceId: sourceId,
      sourceType: sourceType,
      createdBy: createdBy,
      createdAt: createdAt,
    );
  }
}
