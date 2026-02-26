import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../models/app_notification.dart';
import '../providers/notification_provider.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final notificationsAsync = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.notifications),
        actions: [
          TextButton(
            onPressed: () async {
              await ref
                  .read(notificationRepositoryProvider)
                  .markAllRead();
              ref.invalidate(notificationsProvider);
              ref.invalidate(unreadCountProvider);
            },
            child: Text(l10n.markAllRead),
          ),
        ],
      ),
      body: notificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 8),
              Text(l10n.somethingWentWrong),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => ref.invalidate(notificationsProvider),
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
        data: (notifications) {
          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_none,
                      size: 64, color: Theme.of(context).disabledColor),
                  const SizedBox(height: 16),
                  Text(l10n.noNotifications,
                      style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(notificationsProvider);
              ref.invalidate(unreadCountProvider);
            },
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final n = notifications[index];
                return _NotificationTile(notification: n);
              },
            ),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  final AppNotification notification;
  const _NotificationTile({required this.notification});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final color = notification.isRead
        ? theme.colorScheme.surface
        : theme.colorScheme.primaryContainer.withValues(alpha: 0.3);

    return ListTile(
      tileColor: color,
      leading: CircleAvatar(
        backgroundColor: _typeColor(notification.notificationType),
        child: Icon(_typeIcon(notification.notificationType),
            color: Colors.white, size: 20),
      ),
      title: Text(
        notification.title,
        style: TextStyle(
          fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(notification.body, maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(
            _timeAgo(notification.createdAt),
            style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
      isThreeLine: true,
      onTap: () async {
        if (!notification.isRead) {
          await ref
              .read(notificationRepositoryProvider)
              .markRead([notification.id]);
          ref.invalidate(notificationsProvider);
          ref.invalidate(unreadCountProvider);
        }
        // Navigate to the referenced entity if available
        if (context.mounted && notification.referenceType != null) {
          _navigateToReference(context, notification);
        }
      },
    );
  }

  void _navigateToReference(BuildContext context, AppNotification n) {
    switch (n.referenceType) {
      case 'chore':
      case 'assignment':
        context.push('/chores/${n.referenceId}');
        break;
      case 'approval':
        context.push('/approvals');
        break;
      case 'meal_plan':
      case 'recipe':
        context.push('/meals');
        break;
      case 'calendar_event':
        context.push('/calendar');
        break;
      case 'grocery_list':
        context.push('/grocery/${n.referenceId}');
        break;
      default:
        break;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'chore_assigned':
      case 'chore_completed':
        return Icons.cleaning_services;
      case 'approval_requested':
      case 'approval_approved':
      case 'approval_rejected':
        return Icons.approval;
      case 'meal_planned':
      case 'meal_requested':
        return Icons.restaurant;
      case 'event_created':
        return Icons.event;
      case 'grocery_added':
        return Icons.shopping_cart;
      case 'member_joined':
        return Icons.person_add;
      default:
        return Icons.notifications;
    }
  }

  Color _typeColor(String type) {
    if (type.startsWith('chore')) return Colors.orange;
    if (type.startsWith('approval')) return Colors.purple;
    if (type.startsWith('meal')) return Colors.green;
    if (type.startsWith('event')) return Colors.blue;
    if (type.startsWith('grocery')) return Colors.teal;
    if (type.startsWith('member')) return Colors.indigo;
    return Colors.grey;
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
