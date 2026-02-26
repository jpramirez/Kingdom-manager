import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../models/ai_conversation.dart';
import '../models/ai_message.dart';

class AiRepository {
  final ApiClient _api = ApiClient();

  // ── Conversations ───────────────────────────────────────────────

  Future<List<AiConversation>> getConversations(String householdId) async {
    final response = await _api.get(ApiEndpoints.aiConversations(householdId));
    final list = response.data as List;
    return list
        .map((e) => AiConversation.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<AiConversation> createConversation(
    String householdId, {
    String conversationType = 'general',
  }) async {
    final response = await _api.post(
      ApiEndpoints.aiConversations(householdId),
      data: {'conversation_type': conversationType},
    );
    return AiConversation.fromJson(response.data);
  }

  Future<void> archiveConversation(
      String householdId, String conversationId) async {
    await _api.delete(
        ApiEndpoints.aiConversation(householdId, conversationId));
  }

  // ── Messages ────────────────────────────────────────────────────

  Future<List<AiMessage>> getMessages(
      String householdId, String conversationId) async {
    final response = await _api.get(
        ApiEndpoints.aiMessages(householdId, conversationId));
    final list = response.data as List;
    return list
        .map((e) => AiMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Send a message and receive the ChatResponse (assistant message + actions).
  Future<Map<String, dynamic>> sendMessage(
    String householdId,
    String conversationId,
    String content, {
    String? taskHint,
  }) async {
    final data = <String, dynamic>{
      'content': content,
    };
    if (taskHint != null) data['task_hint'] = taskHint;

    final response = await _api.post(
      ApiEndpoints.aiMessages(householdId, conversationId),
      data: data,
    );
    return response.data as Map<String, dynamic>;
  }

  // ── Onboarding ──────────────────────────────────────────────────

  Future<Map<String, dynamic>> startOnboarding(String householdId) async {
    final response = await _api.post(
        ApiEndpoints.aiOnboardingStart(householdId));
    return response.data as Map<String, dynamic>;
  }

  // ── Memory ──────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getMemories(String householdId) async {
    final response = await _api.get(ApiEndpoints.aiMemory(householdId));
    final list = response.data as List;
    return list.map((e) => e as Map<String, dynamic>).toList();
  }
}
