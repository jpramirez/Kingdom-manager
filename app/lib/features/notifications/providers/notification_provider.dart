import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/storage/secure_storage.dart';
import '../models/app_notification.dart';
import '../repositories/notification_repository.dart';

// ── Repository singleton ────────────────────────────────────────

final notificationRepositoryProvider =
    Provider<NotificationRepository>((ref) => NotificationRepository());

// ── Notifications list ──────────────────────────────────────────

final notificationsProvider =
    FutureProvider<List<AppNotification>>((ref) async {
  return ref.read(notificationRepositoryProvider).getNotifications();
});

// ── Unread count ────────────────────────────────────────────────

final unreadCountProvider = FutureProvider<int>((ref) async {
  return ref.read(notificationRepositoryProvider).getUnreadCount();
});

// ── WebSocket real-time provider ────────────────────────────────

final wsNotificationProvider =
    StateNotifierProvider<WsNotificationNotifier, AsyncValue<AppNotification?>>(
        (ref) {
  return WsNotificationNotifier(ref);
});

class WsNotificationNotifier extends StateNotifier<AsyncValue<AppNotification?>> {
  final Ref _ref;
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _reconnectTimer;
  bool _disposed = false;

  WsNotificationNotifier(this._ref) : super(const AsyncValue.data(null)) {
    _connect();
  }

  Future<void> _connect() async {
    if (_disposed) return;

    final token = await SecureStorage.getAccessToken();
    if (token == null) return;

    final uri = Uri.parse(
      '${AppConstants.wsBaseUrl}/notifications?token=$token',
    );

    try {
      _channel = WebSocketChannel.connect(uri);
      _sub = _channel!.stream.listen(
        (message) {
          if (_disposed) return;
          try {
            final data = json.decode(message as String) as Map<String, dynamic>;
            if (data.containsKey('notification')) {
              final notif = AppNotification.fromJson(
                data['notification'] as Map<String, dynamic>,
              );
              state = AsyncValue.data(notif);
              // Refresh the notifications list and unread count
              _ref.invalidate(notificationsProvider);
              _ref.invalidate(unreadCountProvider);
            }
          } catch (_) {
            // Ignore malformed messages
          }
        },
        onDone: () => _scheduleReconnect(),
        onError: (_) => _scheduleReconnect(),
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), _connect);
  }

  Future<void> reconnect() async {
    await _channel?.sink.close();
    _sub?.cancel();
    _reconnectTimer?.cancel();
    await _connect();
  }

  @override
  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _sub?.cancel();
    _channel?.sink.close();
    super.dispose();
  }
}
