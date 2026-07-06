import 'package:customer_flutter/core/auth/auth_token_store.dart';
import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/network/api_client.dart';
import 'package:customer_flutter/core/security/biometric_auth_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('biometric currentDeviceId uses read-only native lookup', () async {
    final calls = <MethodCall>[];
    const channel = MethodChannel('test/biometric_keys/current_device');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'existingDeviceId') return 'device_existing';
      if (call.method == 'deviceId') {
        fail('currentDeviceId must not create a native device id.');
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final service = BiometricAuthService(
      _testApiClient(),
      keyChannel: channel,
    );

    expect(await service.currentDeviceId(), 'device_existing');
    expect(calls.map((call) => call.method), ['existingDeviceId']);
  });

  test('biometric currentDeviceId accepts credential id wrapper aliases',
      () async {
    final calls = <MethodCall>[];
    const channel = MethodChannel('test/biometric_keys/current_credential');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'existingDeviceId') {
        return {
          'data': {
            'device': {'credentialId': 'credential_existing'},
          },
        };
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final service = BiometricAuthService(
      _testApiClient(),
      keyChannel: channel,
    );

    expect(await service.currentDeviceId(), 'credential_existing');
    expect(calls.map((call) => call.method), ['existingDeviceId']);
  });

  test('biometric currentDeviceId accepts JSON string wrapper payloads',
      () async {
    const channel = MethodChannel('test/biometric_keys/current_json_wrapper');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'existingDeviceId') {
        return {
          'payload': '{"device":{"credentialId":"credential_json"}}',
        };
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final service = BiometricAuthService(
      _testApiClient(),
      keyChannel: channel,
    );

    expect(await service.currentDeviceId(), 'credential_json');
  });

  test('biometric clearLocalDeviceKey deletes only the current device key',
      () async {
    final calls = <MethodCall>[];
    const channel = MethodChannel('test/biometric_keys/clear_current');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'existingDeviceId') return 'device_local';
      if (call.method == 'deleteKeyPair') return true;
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final service = BiometricAuthService(
      _testApiClient(),
      keyChannel: channel,
    );

    expect(
      await service.clearLocalDeviceKey(deviceId: 'device_remote'),
      isFalse,
    );
    expect(calls.map((call) => call.method), ['existingDeviceId']);

    calls.clear();
    expect(
      await service.clearLocalDeviceKey(deviceId: 'device_local'),
      isTrue,
    );
    expect(calls.map((call) => call.method), [
      'existingDeviceId',
      'deleteKeyPair',
    ]);
    expect(calls.last.arguments, {'deviceId': 'device_local'});
  });

  test('biometric register cleans up native key when backend rejects device',
      () async {
    final calls = <MethodCall>[];
    const channel = MethodChannel('test/biometric_keys/register_cleanup');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'createKeyPair':
          return {
            'deviceId': 'device_local',
            'publicKeyPem':
                '-----BEGIN PUBLIC KEY-----\nkey\n-----END PUBLIC KEY-----',
            'algorithm': 'ES256',
          };
        case 'existingDeviceId':
          return 'device_local';
        case 'deleteKeyPair':
          return true;
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final api = _RejectingBiometricApiClient();
    final service = BiometricAuthService(
      api,
      localAuth: _AvailableLocalAuthentication(),
      keyChannel: channel,
    );

    await expectLater(
      service.registerDevice(
        pin: '123456',
        platform: 'ios',
        localizedReason: 'Enable Face ID',
        deviceName: 'iPhone',
        appVersion: '1.2.3',
      ),
      throwsA(isA<DioException>()),
    );

    expect(api.posts, ['/customer/auth/biometric/devices']);
    expect(calls.map((call) => call.method), [
      'createKeyPair',
      'existingDeviceId',
      'deleteKeyPair',
    ]);
    expect(calls.last.arguments, {'deviceId': 'device_local'});
  });

  test('biometric register accepts native key pair alias payloads', () async {
    final calls = <MethodCall>[];
    const channel = MethodChannel('test/biometric_keys/register_aliases');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'createKeyPair') {
        return {
          'data': {
            'biometric_key_pair': {
              'device_id': 'device_alias',
              'public_key_pem':
                  '-----BEGIN PUBLIC KEY-----\nalias\n-----END PUBLIC KEY-----',
              'alg': 'ES256',
            },
          },
        };
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final api = _CapturingBiometricDeviceApiClient();
    final service = BiometricAuthService(
      api,
      localAuth: _AvailableLocalAuthentication(),
      keyChannel: channel,
    );

    await service.registerDevice(
      pin: '123456',
      platform: 'android',
      localizedReason: 'Enable biometric',
      deviceName: 'Pixel',
      appVersion: '2.0.0',
    );

    expect(api.posts, ['/customer/auth/biometric/devices']);
    expect(api.payloads.single, {
      'pin': '123456',
      'device_id': 'device_alias',
      'platform': 'android',
      'device_name': 'Pixel',
      'app_version': '2.0.0',
      'algorithm': 'ES256',
      'public_key_pem':
          '-----BEGIN PUBLIC KEY-----\nalias\n-----END PUBLIC KEY-----',
    });
    expect(calls.map((call) => call.method), ['createKeyPair']);
  });

  test('biometric register accepts native credential id aliases', () async {
    const channel = MethodChannel('test/biometric_keys/register_credential');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'createKeyPair') {
        return {
          'resource': {
            'keyPair': {
              'credentialId': 'credential_alias',
              'publicKey':
                  '-----BEGIN PUBLIC KEY-----\ncredential\n-----END PUBLIC KEY-----',
              'signingAlgorithm': 'ES256',
            },
          },
        };
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final api = _CapturingBiometricDeviceApiClient();
    final service = BiometricAuthService(
      api,
      localAuth: _AvailableLocalAuthentication(),
      keyChannel: channel,
    );

    await service.registerDevice(
      pin: '654321',
      platform: 'ios',
      localizedReason: 'Enable Face ID',
      deviceName: 'iPhone',
      appVersion: '3.0.0',
    );

    expect(api.payloads.single['device_id'], 'credential_alias');
    expect(
      api.payloads.single['public_key_pem'],
      '-----BEGIN PUBLIC KEY-----\ncredential\n-----END PUBLIC KEY-----',
    );
    expect(api.payloads.single['algorithm'], 'ES256');
  });

  test('biometric register accepts JSON string native key wrappers', () async {
    const channel = MethodChannel('test/biometric_keys/register_json_wrapper');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'createKeyPair') {
        return {
          'data':
              '{"keyPair":{"deviceId":"device_json","publicKeyPem":"-----BEGIN PUBLIC KEY-----\\njson\\n-----END PUBLIC KEY-----","algorithm":"ES256"}}',
        };
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final api = _CapturingBiometricDeviceApiClient();
    final service = BiometricAuthService(
      api,
      localAuth: _AvailableLocalAuthentication(),
      keyChannel: channel,
    );

    await service.registerDevice(
      pin: '456789',
      platform: 'android',
      localizedReason: 'Enable biometric',
      deviceName: 'Pixel',
      appVersion: '4.0.0',
    );

    expect(api.payloads.single['device_id'], 'device_json');
    expect(
      api.payloads.single['public_key_pem'],
      '-----BEGIN PUBLIC KEY-----\njson\n-----END PUBLIC KEY-----',
    );
  });

  test('biometric register accepts native key pair production aliases',
      () async {
    const channel =
        MethodChannel('test/biometric_keys/register_native_key_aliases');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'createKeyPair') {
        return {
          'nativeKeyPair': {
            'nativeDeviceId': 'native-device-alias',
            'keyPem':
                '-----BEGIN PUBLIC KEY-----\nnative\n-----END PUBLIC KEY-----',
            'coseAlgorithm': 'ES384',
          },
        };
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final api = _CapturingBiometricDeviceApiClient();
    final service = BiometricAuthService(
      api,
      localAuth: _AvailableLocalAuthentication(),
      keyChannel: channel,
    );

    await service.registerDevice(
      pin: '159753',
      platform: 'ios',
      localizedReason: 'Enable Face ID',
      deviceName: 'iPad',
      appVersion: '5.0.0',
    );

    expect(api.payloads.single['device_id'], 'native-device-alias');
    expect(
      api.payloads.single['public_key_pem'],
      '-----BEGIN PUBLIC KEY-----\nnative\n-----END PUBLIC KEY-----',
    );
    expect(api.payloads.single['algorithm'], 'ES256');
  });

  test('biometric register normalizes provider COSE algorithms', () async {
    const channel =
        MethodChannel('test/biometric_keys/register_cose_algorithm');
    var created = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'createKeyPair') {
        created += 1;
        return {
          'credential': {
            'rawId': 'credential-$created',
            'publicKey':
                '-----BEGIN PUBLIC KEY-----\ncose-$created\n-----END PUBLIC KEY-----',
            'coseAlgorithm': created == 1 ? -7 : '-257',
          },
        };
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final api = _CapturingBiometricDeviceApiClient();
    final service = BiometricAuthService(
      api,
      localAuth: _AvailableLocalAuthentication(),
      keyChannel: channel,
    );

    await service.registerDevice(
      pin: '111111',
      platform: 'ios',
      localizedReason: 'Enable Face ID',
    );
    await service.registerDevice(
      pin: '222222',
      platform: 'android',
      localizedReason: 'Enable biometric',
    );

    expect(api.payloads.map((payload) => payload['algorithm']), [
      'ES256',
      'RS256',
    ]);
  });

  test('biometric register accepts provider public-key aliases', () async {
    const channel =
        MethodChannel('test/biometric_keys/register_provider_public_key');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'createKeyPair') {
        return {
          'credential': {
            'nativeDeviceId': 'provider-device-alias',
            'credentialPublicKey':
                '-----BEGIN PUBLIC KEY-----\nprovider\n-----END PUBLIC KEY-----',
            'keyAlgorithm': 'ES256',
          },
        };
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final api = _CapturingBiometricDeviceApiClient();
    final service = BiometricAuthService(
      api,
      localAuth: _AvailableLocalAuthentication(),
      keyChannel: channel,
    );

    await service.registerDevice(
      pin: '741852',
      platform: 'ios',
      localizedReason: 'Enable Face ID',
      deviceName: 'iPhone',
      appVersion: '5.2.0',
    );

    expect(api.payloads.single['device_id'], 'provider-device-alias');
    expect(
      api.payloads.single['public_key_pem'],
      '-----BEGIN PUBLIC KEY-----\nprovider\n-----END PUBLIC KEY-----',
    );
    expect(api.payloads.single['algorithm'], 'ES256');
  });

  test('biometric register accepts passkey raw id and JWK public key aliases',
      () async {
    const channel = MethodChannel('test/biometric_keys/register_passkey_jwk');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'createKeyPair') {
        return {
          'credential': {
            'rawId': 'passkey-raw-device',
            'publicKeyJwk': {
              'kty': 'EC',
              'kid': 'passkey-key',
              'crv': 'P-256',
            },
            'alg': 'ES256',
          },
        };
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final api = _CapturingBiometricDeviceApiClient();
    final service = BiometricAuthService(
      api,
      localAuth: _AvailableLocalAuthentication(),
      keyChannel: channel,
    );

    await service.registerDevice(
      pin: '258147',
      platform: 'ios',
      localizedReason: 'Enable Face ID',
      deviceName: 'iPhone',
      appVersion: '5.3.0',
    );

    expect(api.payloads.single['device_id'], 'passkey-raw-device');
    expect(
      api.payloads.single['public_key_pem'],
      '{"kty":"EC","kid":"passkey-key","crv":"P-256"}',
    );
    expect(api.payloads.single['algorithm'], 'ES256');
  });

  test('biometric register accepts object scalar native key rows', () async {
    const channel = MethodChannel('test/biometric_keys/register_object_scalar');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'createKeyPair') {
        return {
          'payload': {
            'nativeKeyPair': {
              'nativeDeviceId': {'value': 'native-device-object'},
              'keyPem': {
                'value':
                    '-----BEGIN PUBLIC KEY-----\nobject\n-----END PUBLIC KEY-----',
              },
              'coseAlgorithm': {'code': 'ES256'},
            },
          },
        };
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final api = _CapturingBiometricDeviceApiClient();
    final service = BiometricAuthService(
      api,
      localAuth: _AvailableLocalAuthentication(),
      keyChannel: channel,
    );

    await service.registerDevice(
      pin: '753159',
      platform: 'android',
      localizedReason: 'Enable biometric',
      deviceName: 'Pixel',
      appVersion: '5.1.0',
    );

    expect(api.payloads.single['device_id'], 'native-device-object');
    expect(
      api.payloads.single['public_key_pem'],
      '-----BEGIN PUBLIC KEY-----\nobject\n-----END PUBLIC KEY-----',
    );
    expect(api.payloads.single['algorithm'], 'ES256');
  });

  test('biometric availability rejects weak-only native credentials', () async {
    final service = BiometricAuthService(
      _testApiClient(),
      localAuth: _AvailableLocalAuthentication(
        biometrics: const [BiometricType.weak],
      ),
      keyChannel: const MethodChannel('test/biometric_keys/weak_only'),
    );

    expect(await service.canUseBiometric(), isFalse);
  });

  test('biometric PIN assertion falls back before native key lookup when weak',
      () async {
    final calls = <MethodCall>[];
    const channel = MethodChannel('test/biometric_keys/weak_fallback');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final service = BiometricAuthService(
      _testApiClient(),
      localAuth: _AvailableLocalAuthentication(
        biometrics: const [BiometricType.weak],
      ),
      keyChannel: channel,
    );

    expect(
      await service.requestPinAssertion(localizedReason: 'Unlock with face'),
      isNull,
    );
    expect(calls, isEmpty);
  });

  test('biometric PIN assertion falls back when challenge API rejects',
      () async {
    final calls = <MethodCall>[];
    const channel = MethodChannel('test/biometric_keys/challenge_reject');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'existingDeviceId') return 'device_local';
      if (call.method == 'signChallenge') {
        fail('challenge rejection must not ask the native key to sign.');
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final api = _BiometricAssertionApiClient(rejectChallenge: true);
    final service = BiometricAuthService(
      api,
      localAuth: _AvailableLocalAuthentication(),
      keyChannel: channel,
    );

    expect(
      await service.requestPinAssertion(
        purpose: 'reward_claim',
        localizedReason: 'Unlock with face',
      ),
      isNull,
    );
    expect(api.posts, ['/customer/auth/biometric/challenge']);
    expect(api.payloads.single['purpose'], 'reward_claim');
    expect(calls.map((call) => call.method), ['existingDeviceId']);
  });

  test('biometric PIN assertion falls back when verify API rejects', () async {
    final calls = <MethodCall>[];
    const channel = MethodChannel('test/biometric_keys/verify_reject');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'existingDeviceId') return 'device_local';
      if (call.method == 'signChallenge') return 'signature-local';
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final api = _BiometricAssertionApiClient(rejectVerify: true);
    final service = BiometricAuthService(
      api,
      localAuth: _AvailableLocalAuthentication(),
      keyChannel: channel,
    );

    expect(
      await service.requestPinAssertion(
        purpose: 'activity_claim',
        localizedReason: 'Unlock with face',
      ),
      isNull,
    );
    expect(api.posts, [
      '/customer/auth/biometric/challenge',
      '/customer/auth/biometric/verify',
    ]);
    expect(api.payloads.first['purpose'], 'activity_claim');
    expect(api.payloads.last['challenge_id'], 'challenge-local');
    expect(api.payloads.last['signed_payload'], 'payload-local');
    expect(api.payloads.last['signature'], 'signature-local');
    expect(calls.map((call) => call.method), [
      'existingDeviceId',
      'signChallenge',
    ]);
  });

  test('biometric PIN assertion accepts native signature alias payloads',
      () async {
    final calls = <MethodCall>[];
    const channel = MethodChannel('test/biometric_keys/signature_aliases');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'existingDeviceId') return 'device_local';
      if (call.method == 'signChallenge') {
        return {
          'data': {'signature': 'signature-from-map'},
        };
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final api = _BiometricAssertionApiClient();
    final service = BiometricAuthService(
      api,
      localAuth: _AvailableLocalAuthentication(),
      keyChannel: channel,
    );

    expect(
      await service.requestPinAssertion(
        purpose: 'profile_update',
        localizedReason: 'Unlock with biometric',
      ),
      'assertion-local',
    );
    expect(api.posts, [
      '/customer/auth/biometric/challenge',
      '/customer/auth/biometric/verify',
    ]);
    expect(api.payloads.last['challenge_id'], 'challenge-local');
    expect(api.payloads.last['signed_payload'], 'payload-local');
    expect(api.payloads.last['signature'], 'signature-from-map');
    expect(calls.map((call) => call.method), [
      'existingDeviceId',
      'signChallenge',
    ]);
  });

  test('biometric PIN assertion accepts native signature payload aliases',
      () async {
    const channel = MethodChannel('test/biometric_keys/signature_payload');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'existingDeviceId') return 'device_local';
      if (call.method == 'signChallenge') {
        return {
          'payload': {
            'signaturePayload': 'signature-payload-from-native',
          },
        };
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final api = _BiometricAssertionApiClient();
    final service = BiometricAuthService(
      api,
      localAuth: _AvailableLocalAuthentication(),
      keyChannel: channel,
    );

    expect(
      await service.requestPinAssertion(
        purpose: 'wallet_update',
        localizedReason: 'Unlock with biometric',
      ),
      'assertion-local',
    );
    expect(
      api.payloads.last['signature'],
      'signature-payload-from-native',
    );
  });

  test('biometric PIN assertion accepts encoded native signature aliases',
      () async {
    const channel = MethodChannel('test/biometric_keys/signature_encoded');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'existingDeviceId') return 'device_local';
      if (call.method == 'signChallenge') {
        return {
          'data': {
            'signatureBase64': 'signature-base64-from-native',
          },
        };
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final api = _BiometricAssertionApiClient();
    final service = BiometricAuthService(
      api,
      localAuth: _AvailableLocalAuthentication(),
      keyChannel: channel,
    );

    expect(
      await service.requestPinAssertion(
        purpose: 'ticket_claim',
        localizedReason: 'Unlock with biometric',
      ),
      'assertion-local',
    );
    expect(api.payloads.last['signature'], 'signature-base64-from-native');
  });

  test('biometric PIN assertion accepts JSON string native signature wrappers',
      () async {
    const channel = MethodChannel('test/biometric_keys/signature_json_wrapper');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'existingDeviceId') return 'device_local';
      if (call.method == 'signChallenge') {
        return {
          'resource': '{"signaturePayload":"signature-json-from-native"}',
        };
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final api = _BiometricAssertionApiClient();
    final service = BiometricAuthService(
      api,
      localAuth: _AvailableLocalAuthentication(),
      keyChannel: channel,
    );

    expect(
      await service.requestPinAssertion(
        purpose: 'wallet_update',
        localizedReason: 'Unlock with biometric',
      ),
      'assertion-local',
    );
    expect(api.payloads.last['signature'], 'signature-json-from-native');
  });

  test('biometric PIN assertion accepts provider signature aliases', () async {
    const channel = MethodChannel('test/biometric_keys/signature_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'existingDeviceId') return 'device_local';
      if (call.method == 'signChallenge') {
        return {
          'credential': {
            'signatureJws': 'signature-jws-from-provider',
          },
        };
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final api = _BiometricAssertionApiClient();
    final service = BiometricAuthService(
      api,
      localAuth: _AvailableLocalAuthentication(),
      keyChannel: channel,
    );

    expect(
      await service.requestPinAssertion(
        purpose: 'ticket_claim',
        localizedReason: 'Unlock with biometric',
      ),
      'assertion-local',
    );
    expect(api.payloads.last['signature'], 'signature-jws-from-provider');
  });

  test('biometric PIN assertion accepts passkey response signature wrappers',
      () async {
    const channel = MethodChannel('test/biometric_keys/signature_response');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'existingDeviceId') {
        return {
          'credential': {'rawId': 'device_local'},
        };
      }
      if (call.method == 'signChallenge') {
        return {
          'credential': {
            'rawId': 'passkey-credential-id',
            'alg': -7,
            'response': {
              'signature': 'signature-from-response',
              'clientDataJSON': 'client-data-json',
              'authenticatorData': 'authenticator-data',
            },
          },
        };
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final api = _BiometricAssertionApiClient();
    final service = BiometricAuthService(
      api,
      localAuth: _AvailableLocalAuthentication(),
      keyChannel: channel,
    );

    expect(
      await service.requestPinAssertion(
        purpose: 'reward_claim',
        localizedReason: 'Unlock with biometric',
      ),
      'assertion-local',
    );
    expect(api.payloads.last['signature'], 'signature-from-response');
    expect(api.payloads.last['credential_id'], 'passkey-credential-id');
    expect(api.payloads.last['client_data_json'], 'client-data-json');
    expect(api.payloads.last['authenticator_data'], 'authenticator-data');
    expect(api.payloads.last['algorithm'], 'ES256');
  });

  test('biometric PIN assertion forwards WebAuthn challenge options to native',
      () async {
    final calls = <MethodCall>[];
    const channel = MethodChannel('test/biometric_keys/webauthn_options');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'existingDeviceId') return 'device_local';
      if (call.method == 'signChallenge') {
        return {
          'credential': {
            'rawId': 'passkey-credential-id',
            'alg': -7,
            'response': {
              'signature': 'signature-from-webauthn',
              'clientDataJSON': 'client-data-json',
              'authenticatorData': 'authenticator-data',
            },
          },
        };
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final api = _BiometricAssertionApiClient(
      challengeResponse: {
        'data': {
          'challengeId': 'challenge-webauthn',
          'publicKey': {
            'challenge': 'payload-webauthn',
            'rpId': 'partner.example.com',
            'userVerification': 'required',
            'allowCredentials': [
              {'type': 'public-key', 'id': 'device_local'},
            ],
            'timeout': 60000,
          },
        },
      },
    );
    final service = BiometricAuthService(
      api,
      localAuth: _AvailableLocalAuthentication(),
      keyChannel: channel,
    );

    expect(
      await service.requestPinAssertion(
        purpose: 'reward_claim',
        localizedReason: 'Unlock with biometric',
      ),
      'assertion-local',
    );

    final signCall = calls.singleWhere(
      (call) => call.method == 'signChallenge',
    );
    final signArgs = Map<String, dynamic>.from(signCall.arguments as Map);
    expect(signArgs['challenge'], 'payload-webauthn');
    expect(signArgs['purpose'], 'reward_claim');
    expect(signArgs['rp_id'], 'partner.example.com');
    expect(signArgs['user_verification'], 'required');
    expect(signArgs['timeout'], 60000);
    expect(signArgs['allow_credentials'], [
      {'type': 'public-key', 'id': 'device_local'},
    ]);
    expect(api.payloads.last['challenge_id'], 'challenge-webauthn');
    expect(api.payloads.last['signed_payload'], 'payload-webauthn');
    expect(api.payloads.last['signature'], 'signature-from-webauthn');
    expect(api.payloads.last['credential_id'], 'passkey-credential-id');
  });

  test(
      'biometric PIN assertion forwards extended WebAuthn options and '
      'credential containers to native', () async {
    final calls = <MethodCall>[];
    const channel = MethodChannel('test/biometric_keys/webauthn_extended');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'existingDeviceId') return 'device_local';
      if (call.method == 'signChallenge') {
        return {
          'credentialResponse': {
            'signature': 'signature-from-extended-webauthn',
            'credentialId': 'credential-from-native',
          },
        };
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final api = _BiometricAssertionApiClient(
      challengeResponse: {
        'data': {
          'challengeId': 'challenge-extended',
          'publicKey': {
            'challengeBase64Url': 'payload-base64url',
            'rp': {'id': 'partner.example.com'},
            'allowCredentials': {
              'items': [
                {
                  'credential': {
                    'rawId': {'base64Url': 'credential-from-container'},
                    'transports': ['hybrid'],
                  },
                },
              ],
            },
            'excludeCredentials': {
              'records': [
                {
                  'publicKeyCredential': {
                    'id': {'base64url': 'credential-excluded'},
                    'type': 'public-key',
                  },
                },
              ],
            },
            'authenticatorSelection': {
              'authenticatorAttachment': 'platform',
              'residentKey': 'preferred',
            },
            'attestation': 'none',
            'attestationFormats': ['packed'],
            'mediation': 'conditional',
            'hints': ['client-device'],
            'pubKeyCredParams': [
              {'type': 'public-key', 'alg': -7},
            ],
          },
        },
      },
    );
    final service = BiometricAuthService(
      api,
      localAuth: _AvailableLocalAuthentication(),
      keyChannel: channel,
    );

    expect(
      await service.requestPinAssertion(
        purpose: 'reward_claim',
        localizedReason: 'Unlock with biometric',
      ),
      'assertion-local',
    );

    final signCall = calls.singleWhere(
      (call) => call.method == 'signChallenge',
    );
    final signArgs = Map<String, dynamic>.from(signCall.arguments as Map);
    expect(signArgs['challenge'], 'payload-base64url');
    expect(signArgs['rp_id'], 'partner.example.com');
    expect(signArgs['allow_credentials'], [
      {
        'rawId': 'credential-from-container',
        'transports': ['hybrid'],
        'id': 'credential-from-container',
        'type': 'public-key',
      },
    ]);
    expect(signArgs['exclude_credentials'], [
      {'id': 'credential-excluded', 'type': 'public-key'},
    ]);
    expect(signArgs['authenticator_selection'], {
      'authenticatorAttachment': 'platform',
      'residentKey': 'preferred',
    });
    expect(signArgs['attestation'], 'none');
    expect(signArgs['attestation_formats'], ['packed']);
    expect(signArgs['mediation'], 'conditional');
    expect(signArgs['hints'], ['client-device']);
    expect(signArgs['pub_key_cred_params'], [
      {'type': 'public-key', 'alg': -7},
    ]);
    expect(api.payloads.last['challenge_id'], 'challenge-extended');
    expect(api.payloads.last['signed_payload'], 'payload-base64url');
    expect(api.payloads.last['signature'], 'signature-from-extended-webauthn');
    expect(api.payloads.last['credential_id'], 'credential-from-native');
  });

  test(
      'biometric PIN assertion normalizes WebAuthn credential descriptors '
      'before native signing', () async {
    final calls = <MethodCall>[];
    const channel = MethodChannel('test/biometric_keys/webauthn_descriptor');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'existingDeviceId') return 'device_local';
      if (call.method == 'signChallenge') {
        return {
          'signature': 'signature-from-descriptor-test',
          'credentialId': 'credential-from-native',
        };
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final api = _BiometricAssertionApiClient(
      challengeResponse: {
        'data': {
          'challengeId': 'challenge-descriptor',
          'publicKeyCredentialRequestOptions': {
            'challenge': 'payload-descriptor',
            'rp': {'id': 'partner.example.com'},
            'user': {'id': 'user-handle-from-options'},
            'allowCredentials': [
              {
                'type': 'public-key',
                'credentialId': 'credential-from-alias',
                'transports': ['internal'],
              },
              {'rawId': 'raw-credential-from-alias'},
            ],
            'extensions': {
              'appid': 'https://partner.example.com',
            },
          },
        },
      },
    );
    final service = BiometricAuthService(
      api,
      localAuth: _AvailableLocalAuthentication(),
      keyChannel: channel,
    );

    expect(
      await service.requestPinAssertion(
        purpose: 'reward_claim',
        localizedReason: 'Unlock with biometric',
      ),
      'assertion-local',
    );

    final signCall = calls.singleWhere(
      (call) => call.method == 'signChallenge',
    );
    final signArgs = Map<String, dynamic>.from(signCall.arguments as Map);
    expect(signArgs['challenge'], 'payload-descriptor');
    expect(signArgs['rp_id'], 'partner.example.com');
    expect(signArgs['user_handle'], 'user-handle-from-options');
    expect(signArgs['allow_credentials'], [
      {
        'type': 'public-key',
        'credentialId': 'credential-from-alias',
        'transports': ['internal'],
        'id': 'credential-from-alias',
      },
      {
        'rawId': 'raw-credential-from-alias',
        'id': 'raw-credential-from-alias',
        'type': 'public-key',
      },
    ]);
    expect(signArgs['extensions'], {
      'appid': 'https://partner.example.com',
    });
  });

  test('biometric challenge parser accepts standard data payload', () {
    final payload = BiometricChallengePayload.fromResponse({
      'data': {
        'challenge_id': 'challenge-1',
        'challenge': 'payload-to-sign',
      },
    });

    expect(payload.challengeId, 'challenge-1');
    expect(payload.challenge, 'payload-to-sign');
    expect(payload.isComplete, isTrue);
  });

  test('biometric challenge parser accepts legacy result payload', () {
    final payload = BiometricChallengePayload.fromResponse({
      'result': {
        'challenge_id': 'challenge-2',
        'challenge': 'legacy-payload',
      },
    });

    expect(payload.challengeId, 'challenge-2');
    expect(payload.challenge, 'legacy-payload');
    expect(payload.isComplete, isTrue);
  });

  test('biometric challenge parser accepts nested resource data payload', () {
    final payload = BiometricChallengePayload.fromResponse({
      'resource': {
        'data': {
          'challenge_id': 'challenge-resource',
          'challenge': 'backend-payload',
        },
      },
    });

    expect(payload.challengeId, 'challenge-resource');
    expect(payload.challenge, 'backend-payload');
    expect(payload.isComplete, isTrue);
  });

  test('biometric challenge parser accepts recursive named wrappers', () {
    final payload = BiometricChallengePayload.fromResponse({
      'data': {
        'resource': {
          'biometricChallenge': {
            'challengeId': 'challenge-recursive',
            'payload': 'recursive-payload',
          },
        },
      },
    });

    expect(payload.challengeId, 'challenge-recursive');
    expect(payload.challenge, 'recursive-payload');
    expect(payload.isComplete, isTrue);
  });

  test('biometric challenge parser accepts JSON string wrappers', () {
    final payload = BiometricChallengePayload.fromResponse({
      'data':
          '{"biometricChallenge":{"challengeId":"challenge-json","challengePayload":"json-payload"}}',
    });

    expect(payload.challengeId, 'challenge-json');
    expect(payload.challenge, 'json-payload');
    expect(payload.isComplete, isTrue);
  });

  test('biometric challenge parser accepts id and payload aliases', () {
    final payload = BiometricChallengePayload.fromResponse({
      'data': {
        'id': 'challenge-alias',
        'payload': 'payload-alias',
      },
    });

    expect(payload.challengeId, 'challenge-alias');
    expect(payload.challenge, 'payload-alias');
    expect(payload.isComplete, isTrue);
  });

  test('biometric challenge parser accepts provider request token aliases', () {
    final payload = BiometricChallengePayload.fromResponse({
      'data': {
        'authChallenge': {
          'requestToken': 'challenge-request-token',
          'challengeData': 'challenge-data-to-sign',
        },
      },
    });

    expect(payload.challengeId, 'challenge-request-token');
    expect(payload.challenge, 'challenge-data-to-sign');
    expect(payload.isComplete, isTrue);
  });

  test('biometric challenge parser accepts provider id and signing aliases',
      () {
    final payload = BiometricChallengePayload.fromResponse({
      'resource': {
        'authChallenge': {
          'authChallengeId': 'auth-challenge-alias',
          'payloadToSign': 'provider-payload-to-sign',
        },
      },
    });

    expect(payload.challengeId, 'auth-challenge-alias');
    expect(payload.challenge, 'provider-payload-to-sign');
    expect(payload.isComplete, isTrue);

    final biometricPayload = BiometricChallengePayload.fromResponse({
      'data': {
        'biometricChallenge': {
          'biometricChallengeId': 'biometric-challenge-alias',
          'challengeNonce': 'nonce-provider-payload',
        },
      },
    });

    expect(biometricPayload.challengeId, 'biometric-challenge-alias');
    expect(biometricPayload.challenge, 'nonce-provider-payload');
    expect(biometricPayload.isComplete, isTrue);
  });

  test('biometric challenge parser accepts verification wrapper aliases', () {
    final payload = BiometricChallengePayload.fromResponse({
      'verification': {
        'requestId': 'request-alias',
        'serverChallenge': 'server-challenge-payload',
      },
    });

    expect(payload.challengeId, 'request-alias');
    expect(payload.challenge, 'server-challenge-payload');
    expect(payload.isComplete, isTrue);

    final credentialPayload = BiometricChallengePayload.fromResponse({
      'data': {
        'credentialChallenge': {
          'challengeTokenId': 'token-challenge',
          'challengeToken': 'token-payload',
        },
      },
    });

    expect(credentialPayload.challengeId, 'token-challenge');
    expect(credentialPayload.challenge, 'token-payload');
    expect(credentialPayload.isComplete, isTrue);
  });

  test('biometric challenge parser accepts WebAuthn publicKey options', () {
    final payload = BiometricChallengePayload.fromResponse({
      'data': {
        'challengeId': 'challenge-public-key',
        'publicKey': {
          'challenge': 'payload-public-key',
          'rpId': 'partner.example.com',
          'userVerification': 'required',
          'allowCredentials': [
            {'type': 'public-key', 'id': 'credential-1'},
          ],
        },
      },
    });

    expect(payload.challengeId, 'challenge-public-key');
    expect(payload.challenge, 'payload-public-key');
    expect(payload.metadata['rp_id'], 'partner.example.com');
    expect(payload.metadata['user_verification'], 'required');
    expect(payload.metadata['allow_credentials'], [
      {'type': 'public-key', 'id': 'credential-1'},
    ]);
    expect(payload.isComplete, isTrue);
  });

  test('biometric challenge parser normalizes WebAuthn descriptor aliases', () {
    final payload = BiometricChallengePayload.fromResponse({
      'data': {
        'challengeId': 'challenge-descriptor',
        'publicKeyCredentialRequestOptions': {
          'challenge': 'payload-descriptor',
          'rp': {'id': 'partner.example.com'},
          'user': {'id': 'user-handle-from-options'},
          'allowCredentials': [
            {
              'credentialId': 'credential-from-alias',
              'transports': ['internal'],
            },
            {'rawId': 'raw-credential-from-alias'},
          ],
        },
      },
    });

    expect(payload.challengeId, 'challenge-descriptor');
    expect(payload.challenge, 'payload-descriptor');
    expect(payload.metadata['rp_id'], 'partner.example.com');
    expect(payload.metadata['user_handle'], 'user-handle-from-options');
    expect(payload.metadata['allow_credentials'], [
      {
        'credentialId': 'credential-from-alias',
        'transports': ['internal'],
        'id': 'credential-from-alias',
        'type': 'public-key',
      },
      {
        'rawId': 'raw-credential-from-alias',
        'id': 'raw-credential-from-alias',
        'type': 'public-key',
      },
    ]);
    expect(payload.isComplete, isTrue);
  });

  test('biometric challenge parser merges wrapper and nested fields', () {
    final payload = BiometricChallengePayload.fromResponse({
      'challengeId': 'challenge-wrapper',
      'data': {
        'resource': {
          'biometricChallenge': {
            'challengePayload': 'payload-from-nested-provider',
          },
        },
      },
    });

    expect(payload.challengeId, 'challenge-wrapper');
    expect(payload.challenge, 'payload-from-nested-provider');
    expect(payload.isComplete, isTrue);

    final noncePayload = BiometricChallengePayload.fromResponse({
      'resource': {
        'authChallenge': {
          'id': 'challenge-nonce',
          'nonce': 'nonce-to-sign',
        },
      },
    });

    expect(noncePayload.challengeId, 'challenge-nonce');
    expect(noncePayload.challenge, 'nonce-to-sign');
    expect(noncePayload.isComplete, isTrue);
  });

  test('biometric challenge parser unwraps object scalar rows', () {
    final payload = BiometricChallengePayload.fromResponse({
      'data': {
        'biometricChallenge': {
          'challengeId': {'value': 'challenge-object'},
          'payloadToSign': {'value': 'payload-object'},
        },
      },
    });

    expect(payload.challengeId, 'challenge-object');
    expect(payload.challenge, 'payload-object');
    expect(payload.isComplete, isTrue);
  });

  test('biometric challenge parser rejects incomplete payloads', () {
    final payload = BiometricChallengePayload.fromResponse({
      'data': {'challenge_id': 'challenge-3'},
    });

    expect(payload.isComplete, isFalse);
  });

  test('biometric pin assertion parser accepts multiple API wrappers', () {
    expect(
      biometricPinAssertionTokenFromResponse({
        'data': {'pin_assertion_token': 'data-token'},
      }),
      'data-token',
    );
    expect(
      biometricPinAssertionTokenFromResponse({
        'result': {'pin_assertion_token': 'result-token'},
      }),
      'result-token',
    );
    expect(
      biometricPinAssertionTokenFromResponse({
        'resource': {'pin_assertion_token': 'resource-token'},
      }),
      'resource-token',
    );
    expect(
      biometricPinAssertionTokenFromResponse({
        'resource': {
          'data': {'pin_assertion_token': 'resource-data-token'},
        },
      }),
      'resource-data-token',
    );
    expect(
      biometricPinAssertionTokenFromResponse({
        'data': {'pinAssertionToken': 'camel-token'},
      }),
      'camel-token',
    );
    expect(
      biometricPinAssertionTokenFromResponse({
        'data': {
          'resource': {
            'biometricVerification': {
              'assertionToken': 'recursive-assertion-token',
            },
          },
        },
      }),
      'recursive-assertion-token',
    );
    expect(
      biometricPinAssertionTokenFromResponse({
        'pinToken': 'wrapper-pin-token',
        'data': {
          'resource': {
            'biometricVerification': {'status': 'ok'},
          },
        },
      }),
      'wrapper-pin-token',
    );
    expect(
      biometricPinAssertionTokenFromResponse({
        'resource': {
          'pinAssertion': {
            'pinAssertion': 'nested-pin-assertion-token',
          },
        },
      }),
      'nested-pin-assertion-token',
    );
    expect(
      biometricPinAssertionTokenFromResponse({
        'payload': '{"pinAssertion":{"token":"json-pin-token"}}',
      }),
      'json-pin-token',
    );
    expect(
      biometricPinAssertionTokenFromResponse({
        'authResult': {'pinAssertionJwt': 'jwt-pin-token'},
      }),
      'jwt-pin-token',
    );
    expect(
      biometricPinAssertionTokenFromResponse({
        'verification': {'assertionJwt': 'assertion-jwt-token'},
      }),
      'assertion-jwt-token',
    );
    expect(
      biometricPinAssertionTokenFromResponse({
        'biometricVerification': {
          'verificationToken': 'verification-provider-token',
        },
      }),
      'verification-provider-token',
    );
    expect(
      biometricPinAssertionTokenFromResponse({
        'credential': {'proofToken': 'proof-pin-token'},
      }),
      'proof-pin-token',
    );
    expect(
      biometricPinAssertionTokenFromResponse({
        'data': {
          'biometricVerification': {
            'assertionToken': {'value': 'object-token'},
          },
        },
      }),
      'object-token',
    );
  });
}

ApiClient _testApiClient() {
  return ApiClient(
    const AppConfig(
      apiBaseUrl: 'https://partner.example.com/api/v1',
      defaultLocale: 'en-US',
    ),
    AuthTokenStore(),
    localeTag: 'en-US',
  );
}

class _RejectingBiometricApiClient extends ApiClient {
  _RejectingBiometricApiClient()
      : super(
          const AppConfig(
            apiBaseUrl: 'https://partner.example.com/api/v1',
            defaultLocale: 'en-US',
          ),
          AuthTokenStore(),
          localeTag: 'en-US',
        );

  final posts = <String>[];

  @override
  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    bool auth = true,
  }) async {
    posts.add(path);
    throw DioException(
      requestOptions: RequestOptions(path: path),
      response: Response(
        requestOptions: RequestOptions(path: path),
        statusCode: 422,
        data: {
          'code': 'pin_invalid',
          'message': 'The customer PIN is incorrect.',
        },
      ),
      type: DioExceptionType.badResponse,
    );
  }
}

class _CapturingBiometricDeviceApiClient extends ApiClient {
  _CapturingBiometricDeviceApiClient()
      : super(
          const AppConfig(
            apiBaseUrl: 'https://partner.example.com/api/v1',
            defaultLocale: 'en-US',
          ),
          AuthTokenStore(),
          localeTag: 'en-US',
        );

  final posts = <String>[];
  final payloads = <Map<String, dynamic>>[];

  @override
  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    bool auth = true,
  }) async {
    posts.add(path);
    payloads.add(Map<String, dynamic>.from(data as Map));
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: <String, dynamic>{'ok': true} as T,
    );
  }
}

class _BiometricAssertionApiClient extends ApiClient {
  _BiometricAssertionApiClient({
    this.rejectChallenge = false,
    this.rejectVerify = false,
    this.challengeResponse,
  }) : super(
          const AppConfig(
            apiBaseUrl: 'https://partner.example.com/api/v1',
            defaultLocale: 'en-US',
          ),
          AuthTokenStore(),
          localeTag: 'en-US',
        );

  final bool rejectChallenge;
  final bool rejectVerify;
  final Map<String, dynamic>? challengeResponse;
  final posts = <String>[];
  final payloads = <Map<String, dynamic>>[];

  @override
  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    bool auth = true,
  }) async {
    posts.add(path);
    payloads.add(Map<String, dynamic>.from(data as Map));

    if ((rejectChallenge && path.endsWith('/challenge')) ||
        (rejectVerify && path.endsWith('/verify'))) {
      throw DioException(
        requestOptions: RequestOptions(path: path),
        response: Response(
          requestOptions: RequestOptions(path: path),
          statusCode: 403,
          data: {
            'code': path.endsWith('/challenge')
                ? 'biometric_challenge_invalid'
                : 'biometric_signature_invalid',
            'message': 'Biometric assertion failed.',
          },
        ),
        type: DioExceptionType.badResponse,
      );
    }

    final response = path.endsWith('/challenge')
        ? challengeResponse ??
            {
              'resource': {
                'data': {
                  'challenge_id': 'challenge-local',
                  'challenge': 'payload-local',
                },
              },
            }
        : {
            'resource': {
              'data': {'pin_assertion_token': 'assertion-local'},
            },
          };
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: response as T,
    );
  }
}

class _AvailableLocalAuthentication extends LocalAuthentication {
  _AvailableLocalAuthentication({
    this.biometrics = const [BiometricType.strong],
  });

  final List<BiometricType> biometrics;

  @override
  Future<bool> isDeviceSupported() async => true;

  @override
  Future<bool> get canCheckBiometrics async => true;

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async {
    return biometrics;
  }

  @override
  Future<bool> authenticate({
    required String localizedReason,
    Iterable authMessages = const [],
    AuthenticationOptions options = const AuthenticationOptions(),
  }) async {
    return true;
  }
}
