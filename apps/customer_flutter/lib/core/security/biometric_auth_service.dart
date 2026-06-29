import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../network/api_client.dart';
import '../utils/api_payload.dart';

final biometricAuthServiceProvider = Provider<BiometricAuthService>((ref) {
  return BiometricAuthService(ref.watch(apiClientProvider));
});

class BiometricAuthService {
  BiometricAuthService(this._api);

  static const _keyChannel = MethodChannel('customer_flutter/biometric_keys');

  final ApiClient _api;
  final LocalAuthentication _localAuth = LocalAuthentication();

  Future<bool> canUseBiometric() async {
    if (kIsWeb) return false;
    return _localAuth.canCheckBiometrics;
  }

  Future<void> registerDevice({
    required String pin,
    required String platform,
    String? deviceName,
    String? appVersion,
  }) async {
    if (!await canUseBiometric()) {
      throw StateError(
        'Biometric authentication is not available on this device.',
      );
    }

    final key = await _keyChannel.invokeMethod<Map<dynamic, dynamic>>(
      'createKeyPair',
      {'platform': platform, 'deviceName': deviceName},
    );
    final deviceId = key?['deviceId']?.toString() ?? '';
    final publicKeyPem = key?['publicKeyPem']?.toString() ?? '';
    final algorithm = key?['algorithm']?.toString() ?? 'ES256';
    if (deviceId.isEmpty || publicKeyPem.isEmpty) {
      throw StateError('Unable to create a biometric device key.');
    }

    await _api.post(
      '/customer/auth/biometric/devices',
      data: {
        'pin': pin,
        'device_id': deviceId,
        'platform': platform,
        'device_name': deviceName,
        'app_version': appVersion,
        'algorithm': algorithm,
        'public_key_pem': publicKeyPem,
      },
    );
  }

  Future<String?> requestPinAssertion({
    String purpose = 'pin_unlock',
    required String localizedReason,
  }) async {
    if (!await canUseBiometric()) return null;
    final deviceId = await _keyChannel.invokeMethod<String>('deviceId');
    if (deviceId == null || deviceId.isEmpty) return null;

    final challengeResponse = await _api.post<Map<String, dynamic>>(
      '/customer/auth/biometric/challenge',
      data: {'device_id': deviceId, 'purpose': purpose},
    );
    final challengePayload =
        BiometricChallengePayload.fromResponse(challengeResponse.data);
    if (!challengePayload.isComplete) return null;

    final unlocked = await _localAuth.authenticate(
      localizedReason: localizedReason,
      options: const AuthenticationOptions(
        biometricOnly: true,
        stickyAuth: true,
      ),
    );
    if (!unlocked) return null;

    final signature = await _keyChannel.invokeMethod<String>('signChallenge', {
      'challenge': challengePayload.challenge,
      'purpose': purpose,
    });
    if (signature == null || signature.isEmpty) return null;

    final verifyResponse = await _api.post<Map<String, dynamic>>(
      '/customer/auth/biometric/verify',
      data: {
        'challenge_id': challengePayload.challengeId,
        'signed_payload': challengePayload.challenge,
        'signature': signature,
      },
    );

    return biometricPinAssertionTokenFromResponse(verifyResponse.data);
  }
}

class BiometricChallengePayload {
  const BiometricChallengePayload({
    required this.challengeId,
    required this.challenge,
  });

  factory BiometricChallengePayload.fromResponse(Object? response) {
    final payload = unwrapPayload(response);
    return BiometricChallengePayload(
      challengeId: payload['challenge_id']?.toString() ?? '',
      challenge: payload['challenge']?.toString() ?? '',
    );
  }

  final String challengeId;
  final String challenge;

  bool get isComplete => challengeId.isNotEmpty && challenge.isNotEmpty;
}

String biometricPinAssertionTokenFromResponse(Object? response) {
  return unwrapPayload(response)['pin_assertion_token']?.toString() ?? '';
}
