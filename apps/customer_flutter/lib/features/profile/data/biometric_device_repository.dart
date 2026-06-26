import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/api_payload.dart';
import 'biometric_device_models.dart';

final biometricDeviceRepositoryProvider =
    Provider<BiometricDeviceRepository>((ref) {
  return BiometricDeviceRepository(ref.watch(apiClientProvider));
});

final biometricDevicesProvider =
    FutureProvider.autoDispose<List<BiometricDevice>>((ref) async {
  return ref.watch(biometricDeviceRepositoryProvider).list();
});

class BiometricDeviceRepository {
  const BiometricDeviceRepository(this._api);

  final ApiClient _api;

  Future<List<BiometricDevice>> list() async {
    final response = await _api
        .get<Map<String, dynamic>>('/customer/auth/biometric/devices');
    return unwrapDataList(response.data)
        .map(BiometricDevice.fromJson)
        .toList(growable: false);
  }

  Future<void> revoke(String id) async {
    await _api.deleteWithHeaders<Map<String, dynamic>>(
      '/customer/auth/biometric/devices/$id',
    );
  }
}
