import 'dart:convert' as convert;

import 'package:customer_flutter/core/auth/auth_token_store.dart';
import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/network/api_client.dart';
import 'package:customer_flutter/features/profile/data/biometric_device_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('list maps recursive device wrappers and camelCase fields', () async {
    final api = _BiometricDeviceApiClient();
    final repository = BiometricDeviceRepository(api);

    final devices = await repository.list();

    expect(api.paths, ['/customer/auth/biometric/devices']);
    expect(devices, hasLength(3));
    expect(devices.first.id, 'bio_recursive_1');
    expect(devices.first.deviceId, 'device_recursive_1');
    expect(devices.first.platform, 'ios');
    expect(devices.first.deviceName, 'Supakit iPhone');
    expect(devices.first.algorithm, 'ES256');
    expect(devices.first.status, 'active');
    expect(devices.first.isActive, isTrue);
    expect(devices.first.registeredAt, '2026-07-01T10:00:00+07:00');
    expect(devices.first.lastUsedAt, '2026-07-02T09:15:00+07:00');
    expect(devices.first.revokedAt, isEmpty);
    expect(devices.last.id, 'bio_recursive_2');
    expect(devices.last.deviceId, 'device_recursive_2');
    expect(devices.last.deviceName, 'Pixel 8');
    expect(devices.last.status, 'revoked');
    expect(devices.last.isActive, isFalse);
    expect(devices.last.revokedAt, '2026-07-02T12:00:00+07:00');
    expect(devices[1].id, 'bio_credential_1');
    expect(devices[1].deviceId, 'credential_backend_1');
    expect(devices[1].status, 'active');
  });

  test('list accepts JSON string page and row wrappers', () async {
    final api = _BiometricDeviceJsonWrapperApiClient();
    final repository = BiometricDeviceRepository(api);

    final devices = await repository.list();

    expect(api.paths, ['/customer/auth/biometric/devices']);
    expect(devices, hasLength(2));
    expect(devices.first.id, 'bio_json_page_1');
    expect(devices.first.deviceId, 'device_json_page_1');
    expect(devices.first.platform, 'ios');
    expect(devices.first.status, 'active');
    expect(devices.last.id, 'bio_json_row_2');
    expect(devices.last.deviceId, 'credential_json_row_2');
    expect(devices.last.platform, 'android');
    expect(devices.last.status, 'revoked');
    expect(devices.last.revokedAt, '2026-07-04T08:00:00+07:00');
  });

  test('list accepts production record maps and metadata aliases', () async {
    final api = _BiometricDeviceRecordMapApiClient();
    final repository = BiometricDeviceRepository(api);

    final devices = await repository.list();

    expect(api.paths, ['/customer/auth/biometric/devices']);
    expect(devices, hasLength(3));
    expect(devices.first.id, 'bio_records_ios');
    expect(devices.first.deviceId, 'native_device_ios');
    expect(devices.first.platform, 'ios');
    expect(devices.first.deviceName, 'iPad Pro');
    expect(devices.first.algorithm, 'ES384');
    expect(devices.first.status, 'active');
    expect(devices.first.registeredAt, '2026-07-05T09:00:00+07:00');
    expect(devices.first.lastUsedAt, '2026-07-05T10:00:00+07:00');
    expect(devices[1].id, 'bio_records_android');
    expect(devices[1].deviceId, 'external_android_2');
    expect(devices[1].platform, 'android');
    expect(devices[1].deviceName, 'Pixel Fold');
    expect(devices[1].status, 'revoked');
    expect(devices[1].revokedAt, '2026-07-05T11:00:00+07:00');
    expect(devices.last.id, 'bio_records_meta');
    expect(devices.last.deviceId, 'public_meta_3');
    expect(devices.last.platform, 'ios');
    expect(devices.last.deviceName, 'Metadata iPad');
    expect(devices.last.algorithm, 'ES256');
    expect(devices.last.status, 'active');
    expect(devices.last.registeredAt, '2026-07-05T09:30:00+07:00');
    expect(devices.last.lastUsedAt, '2026-07-05T10:30:00+07:00');
  });

  test('list unwraps object scalar device rows', () async {
    final api = _BiometricDeviceObjectScalarApiClient();
    final repository = BiometricDeviceRepository(api);

    final devices = await repository.list();

    expect(api.paths, ['/customer/auth/biometric/devices']);
    expect(devices, hasLength(2));
    expect(devices.first.id, 'bio_object_ios');
    expect(devices.first.deviceId, 'native_object_ios');
    expect(devices.first.platform, 'ios');
    expect(devices.first.deviceName, 'Object iPhone');
    expect(devices.first.algorithm, 'ES256');
    expect(devices.first.status, 'active');
    expect(devices.first.isActive, isTrue);
    expect(devices.first.registeredAt, '2026-07-05T12:00:00+07:00');
    expect(devices.first.lastUsedAt, '2026-07-05T12:30:00+07:00');
    expect(devices.last.id, 'bio_object_android');
    expect(devices.last.deviceId, 'credential_object_android');
    expect(devices.last.platform, 'android');
    expect(devices.last.status, 'revoked');
    expect(devices.last.revokedAt, '2026-07-05T13:00:00+07:00');
  });
}

class _BiometricDeviceApiClient extends ApiClient {
  _BiometricDeviceApiClient()
      : super(
          const AppConfig(
            apiBaseUrl: 'https://partner.example.test/api/v1',
            defaultLocale: 'th-TH',
          ),
          AuthTokenStore(),
          localeTag: 'th-TH',
        );

  final paths = <String>[];

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? query,
    bool auth = true,
  }) async {
    paths.add(path);

    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: {
        'data': {
          'resource': {
            'biometricDevicesPage': {
              'devices': [
                {
                  'biometricDevice': {
                    'biometricDeviceId': 'bio_recursive_1',
                    'deviceId': 'device_recursive_1',
                    'platform': 'ios',
                    'deviceName': 'Supakit iPhone',
                    'algorithm': 'ES256',
                    'presentationStatus': 'REGISTERED',
                    'isActive': true,
                    'registeredAt': '2026-07-01T10:00:00+07:00',
                    'lastUsedAt': '2026-07-02T09:15:00+07:00',
                  },
                },
                {
                  'device': {
                    'id': 'bio_credential_1',
                    'credentialId': 'credential_backend_1',
                    'platform': 'ios',
                    'deviceName': 'Passkey iPhone',
                    'state': 'current',
                    'registeredAt': '2026-07-03T10:00:00+07:00',
                  },
                },
                {
                  'resource': {
                    'device': {
                      'id': 'bio_recursive_2',
                      'publicDeviceId': 'device_recursive_2',
                      'os': 'android',
                      'name': 'Pixel 8',
                      'status': 'removed',
                      'createdAt': '2026-06-20T08:00:00+07:00',
                      'revoked': true,
                      'revokedAt': '2026-07-02T12:00:00+07:00',
                    },
                  },
                },
              ],
            },
          },
        },
      } as T,
    );
  }
}

class _BiometricDeviceJsonWrapperApiClient extends ApiClient {
  _BiometricDeviceJsonWrapperApiClient()
      : super(
          const AppConfig(
            apiBaseUrl: 'https://partner.example.test/api/v1',
            defaultLocale: 'th-TH',
          ),
          AuthTokenStore(),
          localeTag: 'th-TH',
        );

  final paths = <String>[];

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? query,
    bool auth = true,
  }) async {
    paths.add(path);

    final rows = [
      convert.jsonEncode({
        'device': {
          'id': 'bio_json_page_1',
          'deviceId': 'device_json_page_1',
          'platform': 'ios',
          'deviceName': 'String iPhone',
          'status': 'registered',
        },
      }),
      {
        'payload': convert.jsonEncode({
          'biometricDevice': {
            'id': 'bio_json_row_2',
            'credentialId': 'credential_json_row_2',
            'os': 'android',
            'name': 'String Pixel',
            'status': 'removed',
            'revokedAt': '2026-07-04T08:00:00+07:00',
          },
        }),
      },
    ];

    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: {
        'resource': convert.jsonEncode({
          'biometricDevicesPage': {
            'devices': convert.jsonEncode(rows),
          },
        }),
      } as T,
    );
  }
}

class _BiometricDeviceRecordMapApiClient extends ApiClient {
  _BiometricDeviceRecordMapApiClient()
      : super(
          const AppConfig(
            apiBaseUrl: 'https://partner.example.test/api/v1',
            defaultLocale: 'th-TH',
          ),
          AuthTokenStore(),
          localeTag: 'th-TH',
        );

  final paths = <String>[];

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? query,
    bool auth = true,
  }) async {
    paths.add(path);

    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: {
        'data': {
          'records': {
            'ios-current': {
              'biometricDevice': {
                'biometricDeviceUuid': 'bio_records_ios',
                'nativeDeviceId': 'native_device_ios',
                'devicePlatform': 'iOS Native',
                'displayName': 'iPad Pro',
                'alg': 'ES384',
                'registrationStatus': 'trusted',
                'enabledAt': '2026-07-05T09:00:00+07:00',
                'lastAuthenticatedAt': '2026-07-05T10:00:00+07:00',
              },
            },
            'android-revoked': {
              'device': {
                'uuid': 'bio_records_android',
                'externalDeviceId': 'external_android_2',
                'osName': 'android-phone',
                'deviceModel': 'Pixel Fold',
                'keyAlgorithm': 'ES256',
                'lifecycleStatus': 'disabled',
                'disabledAt': '2026-07-05T11:00:00+07:00',
              },
            },
            'metadata-wrapped': {
              'metadata': {
                'biometricDeviceUuid': 'bio_records_meta',
                'publicDeviceId': 'public_meta_3',
              },
              'attributes': {
                'devicePlatform': 'iPadOS',
                'displayName': 'Metadata iPad',
                'keyAlgorithm': 'ES256',
              },
              'registrationInfo': {
                'status': 'trusted',
                'enabledAt': '2026-07-05T09:30:00+07:00',
              },
              'lifecycle': {
                'lastAuthenticatedAt': '2026-07-05T10:30:00+07:00',
              },
            },
          },
        },
      } as T,
    );
  }
}

class _BiometricDeviceObjectScalarApiClient extends ApiClient {
  _BiometricDeviceObjectScalarApiClient()
      : super(
          const AppConfig(
            apiBaseUrl: 'https://partner.example.test/api/v1',
            defaultLocale: 'th-TH',
          ),
          AuthTokenStore(),
          localeTag: 'th-TH',
        );

  final paths = <String>[];

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? query,
    bool auth = true,
  }) async {
    paths.add(path);

    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: {
        'data': {
          'biometricDevices': [
            {
              'biometricDevice': {
                'biometricDeviceId': {'value': 'bio_object_ios'},
                'nativeDeviceId': {'key': 'native_object_ios'},
                'devicePlatform': {'code': 'ios'},
                'displayName': {'value': 'Object iPhone'},
                'algorithm': {'code': 'ES256'},
                'registrationStatus': {'code': 'registered'},
                'enabled': {'value': 'on'},
                'registeredAt': {'value': '2026-07-05T12:00:00+07:00'},
                'lastAuthenticatedAt': {
                  'value': '2026-07-05T12:30:00+07:00',
                },
              },
            },
            {
              'device': {
                'uuid': {'value': 'bio_object_android'},
                'credentialId': {'value': 'credential_object_android'},
                'osName': {'code': 'android-phone'},
                'deviceModel': {'value': 'Object Pixel'},
                'lifecycleStatus': {'code': 'disabled'},
                'disabled': {'value': 'yes'},
                'disabledAt': {'value': '2026-07-05T13:00:00+07:00'},
              },
            },
          ],
        },
      } as T,
    );
  }
}
