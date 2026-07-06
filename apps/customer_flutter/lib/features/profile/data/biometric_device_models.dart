import 'dart:convert' as convert;

import '../../../core/utils/api_payload.dart';

class BiometricDevice {
  const BiometricDevice({
    required this.id,
    required this.deviceId,
    required this.platform,
    required this.deviceName,
    required this.algorithm,
    required this.status,
    required this.registeredAt,
    required this.lastUsedAt,
    required this.revokedAt,
  });

  factory BiometricDevice.fromJson(Map<String, dynamic> json) {
    final payload = _biometricDevicePayload(json);
    return BiometricDevice(
      id: _firstString([
        payload['id'],
        payload['uuid'],
        payload['biometric_id'],
        payload['biometricId'],
        payload['biometric_device_id'],
        payload['biometricDeviceId'],
        payload['biometricDeviceID'],
        payload['biometric_device_uuid'],
        payload['biometricDeviceUuid'],
      ]),
      deviceId: _firstString([
        payload['device_id'],
        payload['deviceId'],
        payload['deviceID'],
        payload['public_device_id'],
        payload['publicDeviceId'],
        payload['publicDeviceID'],
        payload['public_device_uuid'],
        payload['publicDeviceUuid'],
        payload['credential_id'],
        payload['credentialId'],
        payload['credentialID'],
        payload['key_id'],
        payload['keyId'],
        payload['keyID'],
        payload['key_identifier'],
        payload['keyIdentifier'],
        payload['native_device_id'],
        payload['nativeDeviceId'],
        payload['local_device_id'],
        payload['localDeviceId'],
        payload['external_device_id'],
        payload['externalDeviceId'],
      ]),
      platform: _normalizeBiometricPlatform(
        _firstString([
          payload['platform'],
          payload['device_platform'],
          payload['devicePlatform'],
          payload['os'],
          payload['os_name'],
          payload['osName'],
          payload['operating_system'],
          payload['operatingSystem'],
          payload['system_name'],
          payload['systemName'],
        ]),
      ),
      deviceName: _firstString([
        payload['device_name'],
        payload['deviceName'],
        payload['device_label'],
        payload['deviceLabel'],
        payload['display_name'],
        payload['displayName'],
        payload['model_name'],
        payload['modelName'],
        payload['device_model'],
        payload['deviceModel'],
        payload['model'],
        payload['name'],
      ]),
      algorithm: _firstString([
        payload['algorithm'],
        payload['alg'],
        payload['signing_algorithm'],
        payload['signingAlgorithm'],
        payload['key_algorithm'],
        payload['keyAlgorithm'],
        payload['public_key_algorithm'],
        payload['publicKeyAlgorithm'],
        payload['cose_algorithm'],
        payload['coseAlgorithm'],
      ]),
      status: _normalizeBiometricDeviceStatus(payload),
      registeredAt: _firstString([
        payload['registered_at'],
        payload['registeredAt'],
        payload['enabled_at'],
        payload['enabledAt'],
        payload['activated_at'],
        payload['activatedAt'],
        payload['linked_at'],
        payload['linkedAt'],
        payload['created_at'],
        payload['createdAt'],
      ]),
      lastUsedAt: _firstString([
        payload['last_used_at'],
        payload['lastUsedAt'],
        payload['last_authenticated_at'],
        payload['lastAuthenticatedAt'],
        payload['last_verified_at'],
        payload['lastVerifiedAt'],
        payload['last_unlocked_at'],
        payload['lastUnlockedAt'],
        payload['used_at'],
        payload['usedAt'],
      ]),
      revokedAt: _firstString([
        payload['revoked_at'],
        payload['revokedAt'],
        payload['disabled_at'],
        payload['disabledAt'],
        payload['removed_at'],
        payload['removedAt'],
        payload['deleted_at'],
        payload['deletedAt'],
      ]),
    );
  }

  final String id;
  final String deviceId;
  final String platform;
  final String deviceName;
  final String algorithm;
  final String status;
  final String registeredAt;
  final String lastUsedAt;
  final String revokedAt;

  bool get isActive => status == 'active';
}

Map<String, dynamic> _biometricDevicePayload(
  Map<String, dynamic> json, [
  int depth = 0,
]) {
  if (depth >= 6 || json.isEmpty) return json;
  for (final key in const [
    'biometric_device',
    'biometricDevice',
    'device',
    'resource',
    'data',
    'result',
    'payload',
  ]) {
    final nested = _asBiometricDeviceMap(json[key]);
    if (nested.isEmpty) continue;
    final resolved = _biometricDevicePayload(nested, depth + 1);
    final wrapper = <String, dynamic>{...json}..remove(key);
    return {...wrapper, ...resolved};
  }

  return _mergeBiometricDeviceFallbackWrappers(json, depth);
}

Map<String, dynamic> _mergeBiometricDeviceFallbackWrappers(
  Map<String, dynamic> payload,
  int depth,
) {
  final merged = <String, dynamic>{...payload};
  if (depth >= 6) return merged;

  for (final key in _biometricDeviceFallbackWrapperKeys) {
    final nested = _asBiometricDeviceMap(payload[key]);
    if (nested.isEmpty) continue;
    final resolved = _biometricDevicePayload(nested, depth + 1);
    for (final entry in resolved.entries) {
      if (_biometricScalarText(merged[entry.key]).isEmpty) {
        merged[entry.key] = entry.value;
      }
    }
  }

  return merged;
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

String _firstString(Iterable<Object?> values) {
  for (final value in values) {
    final stringValue = _biometricScalarText(value);
    if (stringValue.isNotEmpty) return stringValue;
  }
  return '';
}

String _biometricScalarText(Object? value, [int depth = 0]) {
  if (value == null) return '';
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.startsWith('{') && depth < 4) {
      final map = _asBiometricDeviceMap(trimmed);
      if (map.isNotEmpty) {
        final text = _biometricScalarText(map, depth + 1);
        if (text.isNotEmpty) return text;
      }
    }
    return trimmed;
  }
  if (value is num || value is bool) return value.toString().trim();
  if (depth >= 4 || value is Iterable) return '';

  final map = _asBiometricDeviceMap(value);
  if (map.isEmpty) return '';

  for (final key in const [
    'value',
    'code',
    'key',
    'biometric_device',
    'biometricDevice',
    'device',
    'resource',
    'data',
    'result',
    'payload',
    'id',
    'uuid',
    'biometric_id',
    'biometricId',
    'biometric_device_id',
    'biometricDeviceId',
    'biometricDeviceID',
    'biometric_device_uuid',
    'biometricDeviceUuid',
    'device_id',
    'deviceId',
    'deviceID',
    'public_device_id',
    'publicDeviceId',
    'publicDeviceID',
    'public_device_uuid',
    'publicDeviceUuid',
    'credential_id',
    'credentialId',
    'credentialID',
    'key_id',
    'keyId',
    'keyID',
    'key_identifier',
    'keyIdentifier',
    'native_device_id',
    'nativeDeviceId',
    'local_device_id',
    'localDeviceId',
    'external_device_id',
    'externalDeviceId',
    'platform',
    'device_platform',
    'devicePlatform',
    'os',
    'os_name',
    'osName',
    'operating_system',
    'operatingSystem',
    'system_name',
    'systemName',
    'device_name',
    'deviceName',
    'device_label',
    'deviceLabel',
    'display_name',
    'displayName',
    'model_name',
    'modelName',
    'device_model',
    'deviceModel',
    'model',
    'name',
    'algorithm',
    'alg',
    'signing_algorithm',
    'signingAlgorithm',
    'key_algorithm',
    'keyAlgorithm',
    'public_key_algorithm',
    'publicKeyAlgorithm',
    'cose_algorithm',
    'coseAlgorithm',
    'status',
    'presentation_status',
    'presentationStatus',
    'state',
    'lifecycle_status',
    'lifecycleStatus',
    'registration_status',
    'registrationStatus',
    'device_status',
    'deviceStatus',
    'registered_at',
    'registeredAt',
    'enabled_at',
    'enabledAt',
    'activated_at',
    'activatedAt',
    'linked_at',
    'linkedAt',
    'created_at',
    'createdAt',
    'last_used_at',
    'lastUsedAt',
    'last_authenticated_at',
    'lastAuthenticatedAt',
    'last_verified_at',
    'lastVerifiedAt',
    'last_unlocked_at',
    'lastUnlockedAt',
    'used_at',
    'usedAt',
    'revoked_at',
    'revokedAt',
    'disabled_at',
    'disabledAt',
    'removed_at',
    'removedAt',
    'deleted_at',
    'deletedAt',
  ]) {
    if (!map.containsKey(key)) continue;
    final text = _biometricScalarText(map[key], depth + 1);
    if (text.isNotEmpty) return text;
  }

  if (map.length == 1) {
    final entry = map.entries.single;
    final text = _biometricScalarText(entry.value, depth + 1).toLowerCase();
    if (const {
      '1',
      'true',
      'yes',
      'y',
      'on',
      'active',
      'enabled',
      'available',
      'allowed',
      'supported',
      'ready',
      'registered',
      'trusted',
    }.contains(text)) {
      return entry.key.toString().trim();
    }
  }

  return '';
}

String _normalizeBiometricDeviceStatus(Map<String, dynamic> payload) {
  final raw = _firstString([
    payload['status'],
    payload['presentation_status'],
    payload['presentationStatus'],
    payload['state'],
    payload['lifecycle_status'],
    payload['lifecycleStatus'],
    payload['registration_status'],
    payload['registrationStatus'],
    payload['device_status'],
    payload['deviceStatus'],
  ]).toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');

  if (_truthy(payload['revoked']) ||
      _truthy(payload['is_revoked']) ||
      _truthy(payload['isRevoked']) ||
      _truthy(payload['removed']) ||
      _truthy(payload['is_removed']) ||
      _truthy(payload['isRemoved']) ||
      _truthy(payload['deleted']) ||
      _truthy(payload['is_deleted']) ||
      _truthy(payload['isDeleted']) ||
      _truthy(payload['disabled']) ||
      _truthy(payload['is_disabled']) ||
      _truthy(payload['isDisabled']) ||
      _firstString([
        payload['revoked_at'],
        payload['revokedAt'],
        payload['disabled_at'],
        payload['disabledAt'],
        payload['removed_at'],
        payload['removedAt'],
        payload['deleted_at'],
        payload['deletedAt'],
      ]).isNotEmpty) {
    return 'revoked';
  }

  if (_truthy(payload['active']) ||
      _truthy(payload['is_active']) ||
      _truthy(payload['isActive']) ||
      _truthy(payload['enabled']) ||
      _truthy(payload['is_enabled']) ||
      _truthy(payload['isEnabled']) ||
      _truthy(payload['registered']) ||
      _truthy(payload['ready']) ||
      _truthy(payload['available']) ||
      _truthy(payload['allowed']) ||
      _truthy(payload['supported']) ||
      _truthy(payload['trusted'])) {
    return 'active';
  }

  return switch (raw) {
    'enabled' ||
    'registered' ||
    'ready' ||
    'available' ||
    'allowed' ||
    'supported' ||
    'current' ||
    'linked' ||
    'verified' ||
    'trusted' ||
    'valid' ||
    'synced' =>
      'active',
    'disabled' ||
    'inactive' ||
    'revoked' ||
    'removed' ||
    'deleted' ||
    'expired' ||
    'blocked' =>
      'revoked',
    _ => raw,
  };
}

String _normalizeBiometricPlatform(String value) {
  final normalized =
      value.trim().toLowerCase().replaceAll(RegExp(r'[\s_\-]+'), '');
  if (normalized.isEmpty) return '';
  if (normalized == 'ios' ||
      normalized == 'iphone' ||
      normalized == 'ipad' ||
      normalized == 'ipados' ||
      normalized == 'iosnative') {
    return 'ios';
  }
  if (normalized == 'android' ||
      normalized == 'androidnative' ||
      normalized == 'androidphone' ||
      normalized == 'androidtablet') {
    return 'android';
  }
  if (normalized == 'web' ||
      normalized == 'pwa' ||
      normalized == 'browser' ||
      normalized == 'webauthn') {
    return 'web';
  }
  if (normalized == 'macos' ||
      normalized == 'macosx' ||
      normalized == 'osx' ||
      normalized == 'mac') {
    return 'macos';
  }
  return value.trim().toLowerCase();
}

bool _truthy(Object? value) {
  if (value is bool) return value;
  final normalized = _biometricScalarText(value).toLowerCase();
  return normalized == 'true' ||
      normalized == '1' ||
      normalized == 'yes' ||
      normalized == 'on' ||
      normalized == 'active' ||
      normalized == 'available' ||
      normalized == 'allowed' ||
      normalized == 'supported' ||
      normalized == 'ready' ||
      normalized == 'registered' ||
      normalized == 'enabled' ||
      normalized == 'trusted';
}

const _biometricDeviceFallbackWrapperKeys = [
  'metadata',
  'meta',
  'attributes',
  'details',
  'detail',
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
  'audit',
];
