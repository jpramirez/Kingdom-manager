class AiMessage {
  final String id;
  final String conversationId;
  final String role; // 'user' or 'assistant'
  final String content;
  final String? modelUsed;
  final int? tokensIn;
  final int? tokensOut;
  final Map<String, dynamic>? metadataJson;
  final DateTime createdAt;

  const AiMessage({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    this.modelUsed,
    this.tokensIn,
    this.tokensOut,
    this.metadataJson,
    required this.createdAt,
  });

  factory AiMessage.fromJson(Map<String, dynamic> json) {
    return AiMessage(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      role: json['role'] as String,
      content: json['content'] as String,
      modelUsed: json['model_used'] as String?,
      tokensIn: json['tokens_in'] as int?,
      tokensOut: json['tokens_out'] as int?,
      metadataJson: json['metadata_json'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';

  /// Extract action results from metadata, if any.
  List<ActionResult> get actionResults {
    final actions = metadataJson?['actions'] as List<dynamic>?;
    if (actions == null) return [];
    return actions
        .map((e) => ActionResult.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

class ActionResult {
  final String status;
  final String? actionType;
  final String? entityType;
  final String? entityId;
  final String? summary;
  final String? error;

  const ActionResult({
    required this.status,
    this.actionType,
    this.entityType,
    this.entityId,
    this.summary,
    this.error,
  });

  factory ActionResult.fromJson(Map<String, dynamic> json) {
    return ActionResult(
      status: json['status'] as String? ?? 'unknown',
      actionType: json['action_type'] as String?,
      entityType: json['entity_type'] as String?,
      entityId: json['entity_id'] as String?,
      summary: json['summary'] as String?,
      error: json['error'] as String?,
    );
  }

  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';

  /// Human-readable label for the action type.
  String get readableLabel {
    switch (actionType) {
      case 'create_chore':
        return 'Created chore';
      case 'assign_chore':
        return 'Assigned chore';
      case 'complete_chore':
        return 'Completed chore';
      case 'add_grocery_items':
        return 'Added grocery items';
      case 'check_grocery_item':
        return 'Checked off item';
      case 'create_meal_plan':
        return 'Planned meal';
      case 'batch_meal_plan':
        return 'Planned meals';
      case 'create_event':
        return 'Created event';
      case 'create_approval':
        return 'Created approval';
      case 'update_memory':
        return 'Remembered';
      default:
        return actionType ?? 'Action';
    }
  }

  /// Route path for navigating to the created entity, if applicable.
  String? get navigationRoute {
    if (!isCompleted) return null;
    switch (entityType) {
      case 'chore':
        return entityId != null ? '/chores/$entityId' : '/chores';
      case 'chore_assignment':
        return '/chores';
      case 'grocery_list':
        return entityId != null ? '/grocery/$entityId' : '/grocery';
      case 'meal_plan':
        return '/meals';
      case 'event':
        return '/calendar';
      case 'approval':
        return '/approvals';
      default:
        return null;
    }
  }
}
