import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/ai_message.dart';

class AiChatBubble extends StatelessWidget {
  final AiMessage message;

  const AiChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final colorScheme = Theme.of(context).colorScheme;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.80,
        ),
        margin: EdgeInsets.only(
          left: isUser ? 48 : 8,
          right: isUser ? 8 : 48,
          top: 4,
          bottom: 4,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isUser
              ? colorScheme.primary
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(
              message.content,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isUser
                        ? colorScheme.onPrimary
                        : colorScheme.onSurface,
                  ),
            ),
            // Show action results for assistant messages
            if (message.isAssistant && message.actionResults.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...message.actionResults
                  .where((a) => a.status != 'skipped')
                  .map((action) => _ActionChip(action: action)),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final ActionResult action;
  const _ActionChip({required this.action});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isOk = action.isCompleted;
    final route = action.navigationRoute;

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: InkWell(
        onTap: route != null ? () => context.push(route) : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isOk
                ? Colors.green.withValues(alpha: 0.15)
                : Colors.red.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isOk ? Icons.check_circle_outline : Icons.error_outline,
                size: 16,
                color: isOk ? Colors.green : colorScheme.error,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.readableLabel,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: isOk ? Colors.green : colorScheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    if (action.summary != null &&
                        action.summary != action.readableLabel)
                      Text(
                        action.summary!,
                        style:
                            Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: isOk
                                      ? Colors.green.withValues(alpha: 0.8)
                                      : colorScheme.error
                                          .withValues(alpha: 0.8),
                                ),
                      ),
                  ],
                ),
              ),
              if (route != null) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right,
                  size: 14,
                  color: isOk ? Colors.green : colorScheme.error,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
