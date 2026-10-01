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
    required String installationSecret,
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
        'installation_secret': installationSecret,
        'platform': platform,
        'fcm_token': fcmToken,
        'locale': locale,
        if (appVersion.trim().isNotEmpty) 'app_version': appVersion.trim(),
        if (deviceName.trim().isNotEmpty) 'device_name': deviceName.trim(),
        if (metadata.isNotEmpty) 'metadata': metadata,
      },
    );
  }

  Future<void> registerAnonymousInstallation({
    required String installationId,
    required String installationSecret,
    required String platform,
    required String fcmToken,
    required String locale,
    String appVersion = '',
    String deviceName = '',
    Map<String, dynamic> metadata = const {},
  }) async {
    await _api.post<Map<String, dynamic>>(
      '/public/notification-installations',
      auth: false,
      data: {
        'installation_id': installationId,
        'installation_secret': installationSecret,
        'platform': platform,
        'fcm_token': fcmToken,
        'locale': locale,
        if (appVersion.trim().isNotEmpty) 'app_version': appVersion.trim(),
        if (deviceName.trim().isNotEmpty) 'device_name': deviceName.trim(),
        if (metadata.isNotEmpty) 'metadata': metadata,
      },
    );
  }

  Future<CustomerPushDeviceStatus> deviceStatus(String installationId) async {
    final encodedId = Uri.encodeComponent(installationId.trim());
    final response = await _api.get<Map<String, dynamic>>(
      '/customer/notification-devices/$encodedId/status',
    );
    return CustomerPushDeviceStatus.fromJson(
      response.data ?? const <String, dynamic>{},
    );
  }

  Future<void> revokeDevice(String installationId) async {
    final encodedId = Uri.encodeComponent(installationId.trim());
    await _api.deleteWithHeaders<void>(
      '/customer/notification-devices/$encodedId',
    );
  }

  Future<void> detachDevice(String installationId) async {
    final encodedId = Uri.encodeComponent(installationId.trim());
    await _api.post<Map<String, dynamic>>(
      '/customer/notification-devices/$encodedId/detach',
      data: const <String, dynamic>{},
    );
  }
}

class CustomerPushDeviceStatus {
  const CustomerPushDeviceStatus({
    required this.state,
    required this.registered,
    required this.needsTokenRotation,
    this.revokedReason = '',
  });

  const CustomerPushDeviceStatus.missing()
    : state = 'missing',
      registered = false,
      needsTokenRotation = false,
      revokedReason = '';

  final String state;
  final bool registered;
  final bool needsTokenRotation;
  final String revokedReason;

  factory CustomerPushDeviceStatus.fromJson(Map<String, dynamic> json) {
    final payload = unwrapPayload(json);
    return CustomerPushDeviceStatus(
      state: (payload['state'] ?? '').toString().trim().toLowerCase(),
      registered: payload['registered'] == true,
      needsTokenRotation:
          payload['needs_token_rotation'] == true ||
          payload['needsTokenRotation'] == true,
      revokedReason:
          (payload['revoked_reason'] ?? payload['revokedReason'] ?? '')
              .toString()
              .trim(),
    );
  }
}
