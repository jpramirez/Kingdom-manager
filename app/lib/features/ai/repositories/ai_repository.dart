import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../models/ai_conversation.dart';
import '../models/ai_message.dart';

/// Longer timeout for AI endpoints — LLM inference can take 30-120s.
final _aiTimeout = Options(
  sendTimeout: const Duration(seconds: 150),
  receiveTimeout: const Duration(seconds: 150),
);

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
    debugPrint('[AI] Creating conversation for household=$householdId type=$conversationType');
    final response = await _api.post(
      ApiEndpoints.aiConversations(householdId),
      data: {'conversation_type': conversationType},
    );
    debugPrint('[AI] Conversation created: ${response.statusCode}');
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

    final url = ApiEndpoints.aiMessages(householdId, conversationId);
    debugPrint('[AI] Sending message to $url hint=$taskHint');
    try {
      final response = await _api.post(url, data: data, options: _aiTimeout);
      debugPrint('[AI] Response received: ${response.statusCode}');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[AI] Send error: $e');
      rethrow;
    }
  }

  // ── Onboarding ──────────────────────────────────────────────────

  Future<Map<String, dynamic>> startOnboarding(String householdId) async {
    final response = await _api.post(
      ApiEndpoints.aiOnboardingStart(householdId),
      options: _aiTimeout,
    );
    return response.data as Map<String, dynamic>;
  }

  // ── Memory ──────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getMemories(String householdId) async {
    final response = await _api.get(ApiEndpoints.aiMemory(householdId));
    final list = response.data as List;
    return list.map((e) => e as Map<String, dynamic>).toList();
  }

  Future<void> updateMemory(String householdId, String memoryId, Map<String, dynamic> data) async {
    await _api.put(ApiEndpoints.aiMemoryItem(householdId, memoryId), data: data);
  }

  Future<void> deleteMemory(String householdId, String memoryId) async {
    await _api.delete(ApiEndpoints.aiMemoryItem(householdId, memoryId));
  }

  // ── Onboarding Advance ────────────────────────────────────────

  Future<Map<String, dynamic>> advanceOnboarding(String householdId, String conversationId) async {
    final response = await _api.post(
      ApiEndpoints.aiOnboardingAdvance(householdId, conversationId),
      options: _aiTimeout,
    );
    return response.data as Map<String, dynamic>;
  }
}
