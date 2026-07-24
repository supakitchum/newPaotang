import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/api_payload.dart';
import '../../../core/utils/provider_cache.dart';
import 'line_notification_models.dart';

final lineNotificationRepositoryProvider = Provider<LineNotificationRepository>(
  (ref) {
    return LineNotificationRepository(ref.watch(apiClientProvider));
  },
);

final lineNotificationSettingsProvider =
    FutureProvider.autoDispose<LineNotificationSettings>((ref) async {
      ref.keepForCustomerNavigation();
      return ref.watch(lineNotificationRepositoryProvider).load();
    });

class LineNotificationRepository {
  const LineNotificationRepository(this._api);

  final ApiClient _api;

  Future<LineNotificationSettings> load() async {
    final response = await _api.get<Map<String, dynamic>>(
      '/customer/line-notifications',
    );
    return LineNotificationSettings.fromJson(unwrapPayload(response.data));
  }

  Future<LineNotificationSettings> updateNotificationEnabled(
    bool enabled,
  ) async {
    final response = await _api.patchWithHeaders<Map<String, dynamic>>(
      '/customer/line-notifications',
      data: {'notification_enabled': enabled},
    );
    return LineNotificationSettings.fromJson(unwrapPayload(response.data));
  }

  Future<LineNotificationSettings> disconnect() async {
    final response = await _api.deleteWithHeaders<Map<String, dynamic>>(
      '/customer/line-notifications',
    );
    return LineNotificationSettings.fromJson(unwrapPayload(response.data));
  }
}
