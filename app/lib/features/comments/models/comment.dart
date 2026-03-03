class Comment {
  final String id;
  final String householdId;
  final String entityType;
  final String entityId;
  final String userId;
  final String userName;
  final String text;
  final DateTime createdAt;

  Comment({
    required this.id,
    required this.householdId,
    required this.entityType,
    required this.entityId,
    required this.userId,
    required this.userName,
    required this.text,
    required this.createdAt,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'] as String,
      householdId: json['household_id'] as String,
      entityType: json['entity_type'] as String,
      entityId: json['entity_id'] as String,
      userId: json['user_id'] as String,
      userName: json['user_name'] as String,
      text: json['text'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'household_id': householdId,
      'entity_type': entityType,
      'entity_id': entityId,
      'user_id': userId,
      'user_name': userName,
      'text': text,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Comment copyWith({
    String? text,
  }) {
    return Comment(
      id: id,
      householdId: householdId,
      entityType: entityType,
      entityId: entityId,
      userId: userId,
      userName: userName,
      text: text ?? this.text,
      createdAt: createdAt,
    );
  }
}
