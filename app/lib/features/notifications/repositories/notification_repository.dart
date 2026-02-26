import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../models/app_notification.dart';

class NotificationRepository {
  final ApiClient _api = ApiClient();

  Future<List<AppNotification>> getNotifications({
    bool unreadOnly = false,
    int limit = 50,
    int offset = 0,
  }) async {
    final response = await _api.get(
      ApiEndpoints.notifications,
      queryParameters: {
        'unread_only': unreadOnly,
        'limit': limit,
        'offset': offset,
      },
    );
    final list = response.data as List;
    return list
        .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<int> getUnreadCount() async {
    final response = await _api.get('${ApiEndpoints.notifications}/unread-count');
    return (response.data as Map<String, dynamic>)['count'] as int;
  }

  Future<void> markRead(List<String> notificationIds) async {
    await _api.post(
      ApiEndpoints.notificationsRead,
      data: {'notification_ids': notificationIds},
    );
  }

  Future<void> markAllRead() async {
    await _api.post('${ApiEndpoints.notifications}/read-all');
  }

  Future<void> registerDeviceToken(String token, String platform) async {
    await _api.post(
      ApiEndpoints.deviceToken,
      data: {'token': token, 'platform': platform},
    );
  }
}
