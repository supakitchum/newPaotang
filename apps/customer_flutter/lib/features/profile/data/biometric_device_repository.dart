import 'dart:convert' as convert;

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
    return _biometricDeviceRows(response.data)
        .map(BiometricDevice.fromJson)
        .toList(growable: false);
  }

  Future<void> revoke(String id) async {
    await _api.deleteWithHeaders<Map<String, dynamic>>(
      '/customer/auth/biometric/devices/$id',
    );
  }
}

List<Map<String, dynamic>> _biometricDeviceRows(
  Object? value, [
  int depth = 0,
]) {
  final directRows = _asBiometricDeviceRowList(value);
  if (directRows.isNotEmpty || value is List) return directRows;
  if (depth >= 6) return const [];

  final payload = _asBiometricDeviceMap(value);
  if (payload.isEmpty) return const [];

  for (final key in const [
    'biometric_devices',
    'biometricDevices',
    'biometric_device_page',
    'biometricDevicePage',
    'biometric_devices_page',
    'biometricDevicesPage',
    'device_page',
    'devicePage',
    'devices_page',
    'devicesPage',
    'biometric_device_list',
    'biometricDeviceList',
    'device_list',
    'deviceList',
    'devices',
    'items',
    'records',
    'rows',
    'results',
    'collection',
    'list',
    'entries',
    'page',
    'resource',
    'data',
    'result',
    'payload',
  ]) {
    if (!payload.containsKey(key)) continue;
    final rows = _biometricDeviceRows(payload[key], depth + 1);
    if (rows.isNotEmpty || payload[key] is List) return rows;
  }

  final keyedRows = _keyedBiometricDeviceRows(payload);
  if (keyedRows.isNotEmpty) return keyedRows;

  return unwrapDataList(value);
}

List<Map<String, dynamic>> _asBiometricDeviceRowList(Object? value) {
  if (value is String) {
    final trimmed = value.trim();
    if (!trimmed.startsWith('[')) return const [];
    try {
      return _asBiometricDeviceRowList(convert.jsonDecode(trimmed));
    } catch (_) {
      return const [];
    }
  }
  if (value is! List) return const [];
  return value
      .map(_asBiometricDeviceMap)
      .where((row) => row.isNotEmpty)
      .toList(growable: false);
}

Map<String, dynamic> _asBiometricDeviceMap(Object? value) {
  final direct = asMap(value);
  if (direct.isNotEmpty) return direct;
  if (value is! String) return const <String, dynamic>{};
  final trimmed = value.trim();
  if (!trimmed.startsWith('{')) return const <String, dynamic>{};
  try {
    final decoded = convert.jsonDecode(trimmed);
    return asMap(decoded);
  } catch (_) {
    return const <String, dynamic>{};
  }
}

List<Map<String, dynamic>> _keyedBiometricDeviceRows(
  Map<String, dynamic> payload,
) {
  final mappedValues = payload.values.map(_asBiometricDeviceMap).toList();
  final nonEmptyValues =
      mappedValues.where((row) => row.isNotEmpty).toList(growable: false);
  if (nonEmptyValues.isEmpty || nonEmptyValues.length != mappedValues.length) {
    return const [];
  }
  if (!nonEmptyValues.every(_looksLikeBiometricDeviceRow)) {
    return const [];
  }
  return nonEmptyValues;
}

bool _looksLikeBiometricDeviceRow(
  Map<String, dynamic> row, [
  int depth = 0,
]) {
  if (depth >= 3 || row.isEmpty) return false;
  for (final key in const [
    'id',
    'uuid',
    'biometric_id',
    'biometricId',
    'biometric_device_id',
    'biometricDeviceId',
    'device_id',
    'deviceId',
    'public_device_id',
    'publicDeviceId',
    'credential_id',
    'credentialId',
    'key_id',
    'keyId',
    'native_device_id',
    'nativeDeviceId',
    'platform',
    'device_platform',
    'devicePlatform',
    'os',
    'os_name',
    'osName',
    'device_name',
    'deviceName',
    'display_name',
    'displayName',
    'status',
    'state',
    'registration_status',
    'registrationStatus',
    'lifecycle_status',
    'lifecycleStatus',
    'metadata',
    'meta',
    'attributes',
    'details',
    'platformInfo',
    'platform_info',
    'deviceInfo',
    'device_info',
    'registration',
    'registrationInfo',
    'registration_info',
    'lifecycle',
    'lifecycleInfo',
    'lifecycle_info',
    'statusInfo',
    'status_info',
    'timestamps',
  ]) {
    if (row.containsKey(key)) return true;
  }

  for (final key in const [
    'biometric_device',
    'biometricDevice',
    'device',
    'resource',
    'data',
    'result',
    'payload',
    'metadata',
    'meta',
    'attributes',
    'details',
    'platformInfo',
    'platform_info',
    'deviceInfo',
    'device_info',
    'registration',
    'registrationInfo',
    'registration_info',
    'lifecycle',
    'lifecycleInfo',
    'lifecycle_info',
    'statusInfo',
    'status_info',
    'timestamps',
  ]) {
    final nested = _asBiometricDeviceMap(row[key]);
    if (nested.isNotEmpty && _looksLikeBiometricDeviceRow(nested, depth + 1)) {
      return true;
    }
  }
  return false;
}
