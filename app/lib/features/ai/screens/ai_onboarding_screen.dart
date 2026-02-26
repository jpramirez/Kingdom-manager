import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../household/providers/household_provider.dart';
import '../models/ai_conversation.dart';
import '../models/ai_message.dart';
import '../providers/ai_chat_provider.dart';
import '../repositories/ai_repository.dart';
import '../widgets/ai_chat_bubble.dart';
import '../widgets/ai_typing_indicator.dart';

/// State for the onboarding flow.
class _OnboardingState {
  final AiConversation? conversation;
  final List<AiMessage> messages;
  final bool isLoading;
  final bool isSending;
  final String? error;
  final int progressPercent;
  final String? currentPhase;

  const _OnboardingState({
    this.conversation,
    this.messages = const [],
    this.isLoading = false,
    this.isSending = false,
    this.error,
    this.progressPercent = 0,
    this.currentPhase,
  });

  _OnboardingState copyWith({
    AiConversation? conversation,
    List<AiMessage>? messages,
    bool? isLoading,
    bool? isSending,
    String? error,
    int? progressPercent,
    String? currentPhase,
  }) {
    return _OnboardingState(
      conversation: conversation ?? this.conversation,
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      error: error,
      progressPercent: progressPercent ?? this.progressPercent,
      currentPhase: currentPhase ?? this.currentPhase,
    );
  }
}

class _OnboardingNotifier extends StateNotifier<_OnboardingState> {
  final AiRepository _repo;
  final String _householdId;

  _OnboardingNotifier(this._repo, this._householdId)
      : super(const _OnboardingState());

  Future<void> startOnboarding() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _repo.startOnboarding(_householdId);

      final convData = result['conversation'] as Map<String, dynamic>;
      final msgData = result['message'] as Map<String, dynamic>;

      final conv = AiConversation.fromJson(convData);
      final msg = AiMessage.fromJson(msgData);

      final meta = conv.metadataJson ?? {};
      state = state.copyWith(
        conversation: conv,
        messages: [msg],
        isLoading: false,
        progressPercent: (meta['progress_percent'] as num?)?.toInt() ?? 0,
        currentPhase: meta['onboarding_phase'] as String?,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> sendMessage(String content) async {
    if (state.conversation == null || state.isSending) return;
    final convId = state.conversation!.id;

    final tempMsg = AiMessage(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: convId,
      role: 'user',
      content: content,
      createdAt: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, tempMsg],
      isSending: true,
      error: null,
    );

    try {
      await _repo.sendMessage(_householdId, convId, content);
      // Refresh messages
      final messages = await _repo.getMessages(_householdId, convId);
      state = state.copyWith(messages: messages, isSending: false);
    } catch (e) {
      final filtered =
          state.messages.where((m) => m.id != tempMsg.id).toList();
      state = state.copyWith(
        messages: filtered,
        isSending: false,
        error: e.toString(),
      );
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final _onboardingProvider = StateNotifierProvider.autoDispose
    .family<_OnboardingNotifier, _OnboardingState, String>(
        (ref, householdId) {
  return _OnboardingNotifier(ref.read(aiRepositoryProvider), householdId);
});

class AiOnboardingScreen extends ConsumerStatefulWidget {
  const AiOnboardingScreen({super.key});

  @override
  ConsumerState<AiOnboardingScreen> createState() =>
      _AiOnboardingScreenState();
}

class _AiOnboardingScreenState extends ConsumerState<AiOnboardingScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  bool _started = false;

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _sendMessage(String householdId) {
    final content = _textController.text.trim();
    if (content.isEmpty) return;
    _textController.clear();
    ref.read(_onboardingProvider(householdId).notifier).sendMessage(content);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final household = ref.watch(activeHouseholdProvider).household;
    if (household == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.aiOnboarding)),
        body: Center(child: Text(l10n.error)),
      );
    }

    final householdId = household.id;
    final state = ref.watch(_onboardingProvider(householdId));

    // Auto-start onboarding
    if (!_started) {
      _started = true;
      Future.microtask(() {
        ref.read(_onboardingProvider(householdId).notifier).startOnboarding();
      });
    }

    // Auto-scroll
    ref.listen(_onboardingProvider(householdId), (prev, next) {
      if (prev != null && next.messages.length > prev.messages.length) {
        _scrollToBottom();
      }
    });

    // Error snackbar
    ref.listen(_onboardingProvider(householdId), (prev, next) {
      if (next.error != null && prev?.error != next.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        ref.read(_onboardingProvider(householdId).notifier).clearError();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.aiOnboarding),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          // Progress bar
          if (state.progressPercent > 0)
            LinearProgressIndicator(
              value: state.progressPercent / 100,
              minHeight: 4,
            ),

          // Messages
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount:
                        state.messages.length + (state.isSending ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == state.messages.length && state.isSending) {
                        return const AiTypingIndicator();
                      }
                      return AiChatBubble(message: state.messages[index]);
                    },
                  ),
          ),

          // Input bar
          Container(
            padding: EdgeInsets.only(
              left: 12,
              right: 8,
              top: 8,
              bottom: MediaQuery.of(context).padding.bottom + 8,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    maxLines: 4,
                    minLines: 1,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(householdId),
                    decoration: InputDecoration(
                      hintText: l10n.aiChatHint,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: state.isSending
                      ? null
                      : () => _sendMessage(householdId),
                  icon: state.isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
