class AiConversation {
  final String id;
  final String householdId;
  final String userId;
  final String conversationType;
  final String? title;
  final String status;
  final Map<String, dynamic>? metadataJson;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AiConversation({
    required this.id,
    required this.householdId,
    required this.userId,
    required this.conversationType,
    this.title,
    required this.status,
    this.metadataJson,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AiConversation.fromJson(Map<String, dynamic> json) {
    return AiConversation(
      id: json['id'] as String,
      householdId: json['household_id'] as String,
      userId: json['user_id'] as String,
      conversationType: json['conversation_type'] as String? ?? 'general',
      title: json['title'] as String?,
      status: json['status'] as String? ?? 'active',
      metadataJson: json['metadata_json'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'conversation_type': conversationType,
    };
  }
}
