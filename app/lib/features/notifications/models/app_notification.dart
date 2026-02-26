class AppNotification {
  final String id;
  final String userId;
  final String? householdId;
  final String title;
  final String body;
  final String notificationType;
  final String? referenceId;
  final String? referenceType;
  final bool isRead;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.userId,
    this.householdId,
    required this.title,
    required this.body,
    required this.notificationType,
    this.referenceId,
    this.referenceType,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      householdId: json['household_id'] as String?,
      title: json['title'] as String,
      body: json['body'] as String,
      notificationType: json['notification_type'] as String,
      referenceId: json['reference_id'] as String?,
      referenceType: json['reference_type'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      userId: userId,
      householdId: householdId,
      title: title,
      body: body,
      notificationType: notificationType,
      referenceId: referenceId,
      referenceType: referenceType,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }
}
