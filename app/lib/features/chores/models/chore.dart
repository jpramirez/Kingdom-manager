import '../../../core/constants/enums.dart';

class Chore {
  final String id;
  final String householdId;
  final String title;
  final String? description;
  final ChoreCategory category;
  final ChorePriority priority;
  final ChoreStatus status;
  final bool requiresPhotoProof;
  final bool isRecurring;
  final String? recurrence;
  final DateTime? dueDate;
  final int? estimatedMinutes;
  final String? location;
  final double? locationLat;
  final double? locationLng;
  final String createdBy;
  final DateTime createdAt;

  Chore({
    required this.id,
    required this.householdId,
    required this.title,
    this.description,
    required this.category,
    required this.priority,
    required this.status,
    this.requiresPhotoProof = false,
    this.isRecurring = false,
    this.recurrence,
    this.dueDate,
    this.estimatedMinutes,
    this.location,
    this.locationLat,
    this.locationLng,
    required this.createdBy,
    required this.createdAt,
  });

  factory Chore.fromJson(Map<String, dynamic> json) {
    return Chore(
      id: json['id'] as String,
      householdId: json['household_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      category: ChoreCategory.fromValue(json['category'] as String? ?? 'other'),
      priority: ChorePriority.fromValue(json['priority'] as String? ?? 'medium'),
      status: ChoreStatus.fromValue(json['status'] as String? ?? 'active'),
      requiresPhotoProof: json['requires_photo_proof'] as bool? ?? false,
      isRecurring: json['is_recurring'] as bool? ?? false,
      recurrence: json['recurrence_rule'] as String?,
      dueDate: json['due_date'] != null
          ? DateTime.parse(json['due_date'] as String)
          : null,
      estimatedMinutes: json['estimated_minutes'] as int?,
      location: json['location'] as String?,
      locationLat: (json['location_lat'] as num?)?.toDouble(),
      locationLng: (json['location_lng'] as num?)?.toDouble(),
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'category': category.value,
      'priority': priority.value,
      'requires_photo_proof': requiresPhotoProof,
      'is_recurring': isRecurring,
      'recurrence_rule': recurrence,
      'due_date': dueDate?.toIso8601String().split('T').first,
      'estimated_minutes': estimatedMinutes,
      'location': location,
      'location_lat': locationLat,
      'location_lng': locationLng,
    };
  }

  Chore copyWith({
    String? title,
    String? description,
    ChoreCategory? category,
    ChorePriority? priority,
    ChoreStatus? status,
    bool? requiresPhotoProof,
    bool? isRecurring,
    String? recurrence,
    DateTime? dueDate,
    int? estimatedMinutes,
    String? location,
    double? locationLat,
    double? locationLng,
  }) {
    return Chore(
      id: id,
      householdId: householdId,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      requiresPhotoProof: requiresPhotoProof ?? this.requiresPhotoProof,
      isRecurring: isRecurring ?? this.isRecurring,
      recurrence: recurrence ?? this.recurrence,
      dueDate: dueDate ?? this.dueDate,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      location: location ?? this.location,
      locationLat: locationLat ?? this.locationLat,
      locationLng: locationLng ?? this.locationLng,
      createdBy: createdBy,
      createdAt: createdAt,
    );
  }
}

class ChoreAssignment {
  final String id;
  final String choreId;
  final String assignedTo;
  final ChoreStatus status;
  final DateTime? dueDate;
  final String? dueTime;
  final DateTime? completedAt;
  final String? completedBy;
  final String? photoProofUrl;
  final String? notes;
  final DateTime createdAt;
  // Populated from API joins
  final String? choreTitle;
  final String? assigneeName;

  ChoreAssignment({
    required this.id,
    required this.choreId,
    required this.assignedTo,
    required this.status,
    this.dueDate,
    this.dueTime,
    this.completedAt,
    this.completedBy,
    this.photoProofUrl,
    this.notes,
    required this.createdAt,
    this.choreTitle,
    this.assigneeName,
  });

  factory ChoreAssignment.fromJson(Map<String, dynamic> json) {
    return ChoreAssignment(
      id: json['id'] as String,
      choreId: json['chore_id'] as String,
      assignedTo: json['assigned_to'] as String,
      status: ChoreStatus.fromValue(json['status'] as String? ?? 'pending'),
      dueDate: json['due_date'] != null
          ? DateTime.parse(json['due_date'] as String)
          : null,
      dueTime: json['due_time'] as String?,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      completedBy: json['completed_by'] as String?,
      photoProofUrl: json['photo_proof_url'] as String?,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      choreTitle: json['chore_title'] as String?,
      assigneeName: json['assignee_name'] as String?,
    );
  }
}
