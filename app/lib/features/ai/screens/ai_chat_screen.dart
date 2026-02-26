import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../household/providers/household_provider.dart';
import '../providers/ai_chat_provider.dart';
import '../widgets/ai_chat_bubble.dart';
import '../widgets/ai_suggestion_chips.dart';
import '../widgets/ai_typing_indicator.dart';

class AiChatScreen extends ConsumerStatefulWidget {
  final String? conversationId;

  const AiChatScreen({super.key, this.conversationId});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  bool _initialized = false;

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
    ref.read(aiChatProvider(householdId).notifier).sendMessage(content);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final household = ref.watch(activeHouseholdProvider).household;
    if (household == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.aiAssistant)),
        body: Center(child: Text(l10n.error)),
      );
    }

    final householdId = household.id;
    final chatState = ref.watch(aiChatProvider(householdId));

    // Initialize conversation on first build
    if (!_initialized) {
      _initialized = true;
      Future.microtask(() {
        ref.read(aiChatProvider(householdId).notifier).startConversation(
              conversationId: widget.conversationId,
            );
      });
    }

    // Auto-scroll when new messages arrive
    ref.listen<AiChatState>(aiChatProvider(householdId), (prev, next) {
      if (prev != null && next.messages.length > prev.messages.length) {
        _scrollToBottom();
      }
    });

    // Show error snackbar
    ref.listen<AiChatState>(aiChatProvider(householdId), (prev, next) {
      if (next.error != null && prev?.error != next.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        ref.read(aiChatProvider(householdId).notifier).clearError();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(chatState.conversation?.title ?? l10n.aiAssistant),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (chatState.conversation != null)
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'archive') {
                  await ref
                      .read(aiChatProvider(householdId).notifier)
                      .archiveConversation();
                  if (context.mounted) context.pop();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'archive',
                  child: Row(
                    children: [
                      const Icon(Icons.archive_outlined, size: 20),
                      const SizedBox(width: 8),
                      Text(l10n.aiArchiveChat),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: chatState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : chatState.messages.isEmpty
                    ? _EmptyState(
                        onSuggestion: (text) {
                          _textController.text = text;
                          _sendMessage(householdId);
                        },
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: chatState.messages.length +
                            (chatState.isSending ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == chatState.messages.length &&
                              chatState.isSending) {
                            return const AiTypingIndicator();
                          }
                          return AiChatBubble(
                              message: chatState.messages[index]);
                        },
                      ),
          ),

          // Suggestion chips (show when conversation has few messages)
          if (chatState.messages.length < 3 && !chatState.isLoading)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: AiSuggestionChips(
                onTap: (text) {
                  _textController.text = text;
                  _sendMessage(householdId);
                },
              ),
            ),

          // Input bar
          _InputBar(
            controller: _textController,
            isSending: chatState.isSending,
            onSend: () => _sendMessage(householdId),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final void Function(String suggestion) onSuggestion;

  const _EmptyState({required this.onSuggestion});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.smart_toy_outlined,
              size: 64,
              color: colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.aiAssistant,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.aiChatEmpty,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.outline,
                  ),
            ),
            const SizedBox(height: 24),
            AiSuggestionChips(onTap: onSuggestion),
          ],
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;

  const _InputBar({
    required this.controller,
    required this.isSending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
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
              controller: controller,
              maxLines: 4,
              minLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: l10n.aiChatHint,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: isSending ? null : onSend,
            icon: isSending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
          ),
        ],
      ),
    );
  }
}
