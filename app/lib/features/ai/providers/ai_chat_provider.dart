import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ai_conversation.dart';
import '../models/ai_message.dart';
import '../repositories/ai_repository.dart';

final aiRepositoryProvider =
    Provider<AiRepository>((ref) => AiRepository());

final aiConversationsProvider =
    FutureProvider.family<List<AiConversation>, String>(
        (ref, householdId) async {
  return ref.read(aiRepositoryProvider).getConversations(householdId);
});

/// Whether the household has any memories (used to detect if onboarding needed).
final hasMemoriesProvider =
    FutureProvider.family<bool, String>((ref, householdId) async {
  final memories = await ref.read(aiRepositoryProvider).getMemories(householdId);
  return memories.isNotEmpty;
});

// ── Chat State ──────────────────────────────────────────────────────

class AiChatState {
  final AiConversation? conversation;
  final List<AiMessage> messages;
  final bool isLoading;
  final bool isSending;
  final String? error;
  final String? taskHint;

  const AiChatState({
    this.conversation,
    this.messages = const [],
    this.isLoading = false,
    this.isSending = false,
    this.error,
    this.taskHint,
  });

  AiChatState copyWith({
    AiConversation? conversation,
    List<AiMessage>? messages,
    bool? isLoading,
    bool? isSending,
    String? error,
    String? taskHint,
  }) {
    return AiChatState(
      conversation: conversation ?? this.conversation,
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      error: error,
      taskHint: taskHint ?? this.taskHint,
    );
  }
}

class AiChatNotifier extends StateNotifier<AiChatState> {
  final AiRepository _repo;
  final String _householdId;

  AiChatNotifier(this._repo, this._householdId) : super(const AiChatState());

  /// Start a new conversation or load an existing one.
  Future<void> startConversation({
    String? conversationId,
    String conversationType = 'general',
    String? taskHint,
  }) async {
    state = state.copyWith(isLoading: true, error: null, taskHint: taskHint);
    try {
      AiConversation conv;
      if (conversationId != null) {
        // Load existing conversation
        debugPrint('[AI] Provider: loading existing conversation $conversationId');
        final conversations = await _repo.getConversations(_householdId);
        conv = conversations.firstWhere((c) => c.id == conversationId);
      } else {
        // Create new
        debugPrint('[AI] Provider: creating new conversation type=$conversationType');
        conv = await _repo.createConversation(
          _householdId,
          conversationType: conversationType,
        );
      }

      debugPrint('[AI] Provider: conversation ready id=${conv.id}');
      // Load messages
      final messages = await _repo.getMessages(_householdId, conv.id);
      debugPrint('[AI] Provider: loaded ${messages.length} existing messages');

      state = state.copyWith(
        conversation: conv,
        messages: messages,
        isLoading: false,
      );
    } catch (e, st) {
      debugPrint('[AI] Provider: startConversation ERROR: $e');
      debugPrint('[AI] Provider: stack: $st');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Send a user message and receive the AI response.
  Future<void> sendMessage(String content, {String? taskHint}) async {
    if (state.conversation == null || state.isSending) return;

    final convId = state.conversation!.id;
    // Use provided taskHint or fall back to the stored one
    final hint = taskHint ?? state.taskHint;

    // Optimistically add user message
    final tempUserMsg = AiMessage(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: convId,
      role: 'user',
      content: content,
      createdAt: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, tempUserMsg],
      isSending: true,
      error: null,
    );

    try {
      debugPrint('[AI] Provider: sending message to conv=$convId hint=$hint');
      final response = await _repo.sendMessage(
        _householdId,
        convId,
        content,
        taskHint: hint,
      );
      debugPrint('[AI] Provider: got response, re-fetching messages');

      // Re-fetch all messages from server to get actual IDs
      final messages = await _repo.getMessages(_householdId, convId);
      debugPrint('[AI] Provider: fetched ${messages.length} messages');

      state = state.copyWith(
        messages: messages,
        isSending: false,
      );
    } catch (e, st) {
      debugPrint('[AI] Provider: sendMessage ERROR: $e');
      debugPrint('[AI] Provider: stack: $st');
      // Remove the temp message on error
      final filtered =
          state.messages.where((m) => m.id != tempUserMsg.id).toList();
      state = state.copyWith(
        messages: filtered,
        isSending: false,
        error: e.toString(),
      );
    }
  }

  /// Archive the current conversation.
  Future<void> archiveConversation() async {
    if (state.conversation == null) return;
    try {
      await _repo.archiveConversation(
          _householdId, state.conversation!.id);
      state = const AiChatState();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Provider factory: one chat notifier per household.
final aiChatProvider =
    StateNotifierProvider.family<AiChatNotifier, AiChatState, String>(
        (ref, householdId) {
  return AiChatNotifier(
    ref.read(aiRepositoryProvider),
    householdId,
  );
});
