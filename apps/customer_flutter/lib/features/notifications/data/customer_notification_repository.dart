import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/api_payload.dart';
import 'customer_notification_models.dart';

final customerNotificationRepositoryProvider =
    Provider<CustomerNotificationRepository>((ref) {
      return CustomerNotificationRepository(ref.watch(apiClientProvider));
    });

final customerNotificationUnreadCountProvider = FutureProvider<int>((
  ref,
) async {
  final auth = ref.watch(authControllerProvider);
  if (!auth.isAuthenticated || auth.pinRequired || auth.pinSetupRequired) {
    return 0;
  }
  return ref.watch(customerNotificationRepositoryProvider).unreadCount();
});

class CustomerNotificationRepository {
  const CustomerNotificationRepository(this._api);

  final ApiClient _api;

  Future<CustomerNotificationPage> list({
    int limit = 20,
    String cursor = '',
    String status = 'all',
    String category = '',
  }) async {
    final response = await _api.get<Map<String, dynamic>>(
      '/customer/notifications',
      query: {
        'limit': limit,
        'status': status,
        if (cursor.trim().isNotEmpty) 'cursor': cursor.trim(),
        if (category.trim().isNotEmpty) 'category': category.trim(),
      },
    );
    return CustomerNotificationPage.fromJson(response.data);
  }

  Future<int> unreadCount() async {
    final response = await _api.get<Map<String, dynamic>>(
      '/customer/notifications/unread-count',
    );
    final payload = unwrapPayload(response.data);
    final value = payload['unread_count'] ?? payload['unreadCount'];
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Future<CustomerNotificationItem> markRead(String notificationId) async {
    final encodedId = Uri.encodeComponent(notificationId.trim());
    final response = await _api.patchWithHeaders<Map<String, dynamic>>(
      '/customer/notifications/$encodedId/read',
      data: const <String, dynamic>{},
    );
    return CustomerNotificationItem.fromJson(response.data);
  }

  Future<int> markAllRead() async {
    final response = await _api.post<Map<String, dynamic>>(
      '/customer/notifications/read-all',
      data: const <String, dynamic>{},
    );
    final payload = unwrapPayload(response.data);
    final value = payload['unread_count'] ?? payload['unreadCount'];
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Future<void> registerDevice({
    required String installationId,
    required String platform,
    required String fcmToken,
    required String locale,
    String appVersion = '',
    String deviceName = '',
    Map<String, dynamic> metadata = const {},
  }) async {
    await _api.post<Map<String, dynamic>>(
      '/customer/notification-devices',
      data: {
        'installation_id': installationId,
        'platform': platform,
        'fcm_token': fcmToken,
        'locale': locale,
        if (appVersion.trim().isNotEmpty) 'app_version': appVersion.trim(),
        if (deviceName.trim().isNotEmpty) 'device_name': deviceName.trim(),
        if (metadata.isNotEmpty) 'metadata': metadata,
      },
    );
  }

  Future<void> revokeDevice(String installationId) async {
    final encodedId = Uri.encodeComponent(installationId.trim());
    await _api.deleteWithHeaders<void>(
      '/customer/notification-devices/$encodedId',
    );
  }
}
