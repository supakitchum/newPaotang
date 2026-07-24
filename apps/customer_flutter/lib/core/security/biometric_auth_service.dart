import 'dart:convert' as convert;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../network/api_client.dart';
import '../utils/api_payload.dart';

final biometricAuthServiceProvider = Provider<BiometricAuthService>((ref) {
  return BiometricAuthService(
    ref.watch(apiClientProvider),
    promptCoordinator: ref.watch(biometricPromptCoordinatorProvider),
  );
});

final biometricPromptCoordinatorProvider = Provider<BiometricPromptCoordinator>(
  (_) => BiometricPromptCoordinator(),
);

class BiometricPromptCoordinator {
  int _activeOperations = 0;

  bool get isActive => _activeOperations > 0;

  Future<T> track<T>(Future<T> Function() operation) async {
    _activeOperations += 1;
    try {
      return await operation();
    } finally {
      _activeOperations -= 1;
    }
  }
}

class BiometricAuthService {
  BiometricAuthService(
    this._api, {
    LocalAuthentication? localAuth,
    MethodChannel? keyChannel,
    TargetPlatform? targetPlatform,
    BiometricPromptCoordinator? promptCoordinator,
  }) : _localAuth = localAuth ?? LocalAuthentication(),
       _keyChannel = keyChannel ?? _defaultKeyChannel,
       _targetPlatform = targetPlatform ?? defaultTargetPlatform,
       _promptCoordinator = promptCoordinator ?? BiometricPromptCoordinator();

  static const _defaultKeyChannel = MethodChannel(
    'customer_flutter/biometric_keys',
  );

  final ApiClient _api;
  final LocalAuthentication _localAuth;
  final MethodChannel _keyChannel;
  final TargetPlatform _targetPlatform;
  final BiometricPromptCoordinator _promptCoordinator;

  Future<bool> canUseBiometric() async {
    if (kIsWeb) return false;
    try {
      final supported = await _localAuth.isDeviceSupported();
      if (!supported) return false;
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      if (!canCheckBiometrics) return false;
      return _hasNativeKeyCompatibleBiometric(
        await _localAuth.getAvailableBiometrics(),
      );
    } on PlatformException {
      return false;
    }
  }

  Future<bool> canUnlockCurrentDevice() async {
    if (!await canUseBiometric()) return false;
    final deviceId = await _safeExistingDeviceId();
    return deviceId != null && deviceId.isNotEmpty;
  }

  Future<void> registerDevice({
    required String pin,
    required String platform,
    required String localizedReason,
    String? deviceName,
    String? appVersion,
  }) async {
    if (!await canUseBiometric()) {
      throw StateError(
        'Biometric authentication is not available on this device.',
      );
    }
    final confirmed = await _authenticateWithBiometric(localizedReason);
    if (!confirmed) {
      throw StateError('Biometric authentication was cancelled or failed.');
    }

    final key = await _keyChannel.invokeMethod<Object?>('createKeyPair', {
      'platform': platform,
      'deviceName': deviceName,
    });
    final keyPayload = _biometricKeyPairPayload(key);
    final deviceId = _biometricDeviceIdFromPayload(keyPayload);
    final publicKeyPem = _biometricPublicKeyFromPayload(keyPayload);
    final algorithm = _biometricAlgorithmFromPayload(keyPayload);
    if (deviceId.isEmpty || publicKeyPem.isEmpty) {
      throw StateError('Unable to create a biometric device key.');
    }

    try {
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
    } catch (_) {
      await clearLocalDeviceKey(deviceId: deviceId);
      rethrow;
    }
  }

  Future<String?> currentDeviceId() {
    return _safeExistingDeviceId();
  }

  Future<bool> clearLocalDeviceKey({String? deviceId}) async {
    final currentId = await _safeExistingDeviceId();
    if (currentId == null || currentId.isEmpty) return false;
    final expectedId = deviceId?.trim() ?? '';
    if (expectedId.isNotEmpty && expectedId != currentId) return false;
    try {
      final deleted = await _keyChannel.invokeMethod<bool>('deleteKeyPair', {
        'deviceId': currentId,
      });
      return deleted == true;
    } on PlatformException {
      return false;
    }
  }

  Future<String?> requestPinAssertion({
    String purpose = 'pin_unlock',
    required String localizedReason,
  }) async {
    if (!await canUseBiometric()) return null;
    final deviceId = await _safeExistingDeviceId();
    if (deviceId == null || deviceId.isEmpty) return null;

    final challengeResponse = await _safePostMap(
      '/customer/auth/biometric/challenge',
      data: {'device_id': deviceId, 'purpose': purpose},
    );
    if (challengeResponse == null) return null;
    final challengePayload = BiometricChallengePayload.fromResponse(
      challengeResponse,
    );
    if (!challengePayload.isComplete) return null;

    // The iOS Secure Enclave key is protected by biometryCurrentSet. Let the
    // key operation present Face ID/Touch ID itself so the user is not asked
    // once by local_auth and then a second time by Security.framework.
    if (_targetPlatform != TargetPlatform.iOS) {
      final unlocked = await _authenticateWithBiometric(localizedReason);
      if (!unlocked) return null;
    }

    final signaturePayload = await _safeSignChallenge(
      challenge: challengePayload.challenge,
      purpose: purpose,
      localizedReason: localizedReason,
      metadata: challengePayload.metadata,
    );
    if (signaturePayload == null || !signaturePayload.isComplete) return null;

    final verifyResponse = await _safePostMap(
      '/customer/auth/biometric/verify',
      data: {
        'challenge_id': challengePayload.challengeId,
        'signed_payload': challengePayload.challenge,
        'signature': signaturePayload.signature,
        ...signaturePayload.metadata,
      },
    );
    if (verifyResponse == null) return null;

    return biometricPinAssertionTokenFromResponse(verifyResponse);
  }

  Future<Map<String, dynamic>?> _safePostMap(
    String path, {
    required Map<String, dynamic> data,
  }) async {
    try {
      final response = await _api.post<Map<String, dynamic>>(path, data: data);
      return response.data;
    } catch (_) {
      return null;
    }
  }

  Future<bool> _authenticateWithBiometric(String localizedReason) async {
    try {
      return _promptCoordinator.track(
        () => _localAuth.authenticate(
          localizedReason: localizedReason,
          options: const AuthenticationOptions(
            biometricOnly: true,
            stickyAuth: true,
          ),
        ),
      );
    } on PlatformException {
      return false;
    }
  }

  Future<String?> _safeExistingDeviceId() async {
    try {
      final value = await _keyChannel.invokeMethod<Object?>('existingDeviceId');
      final scalar = _firstScalarString([value]);
      if (scalar.isNotEmpty) return scalar;
      final payload = _unwrapBiometricPayload(value, const [
        'device',
        'biometric_device',
        'biometricDevice',
        'native_device',
        'nativeDevice',
        'credential',
        'biometric_credential',
        'biometricCredential',
        'key_pair',
        'keyPair',
        'native_key_pair',
        'nativeKeyPair',
      ]);
      final deviceId = _biometricDeviceIdFromPayload(payload);
      return deviceId.isEmpty ? null : deviceId;
    } on PlatformException {
      return null;
    }
  }

  Future<_BiometricSignaturePayload?> _safeSignChallenge({
    required String challenge,
    required String purpose,
    required String localizedReason,
    Map<String, dynamic> metadata = const {},
  }) async {
    try {
      final value = await _promptCoordinator.track(
        () => _keyChannel.invokeMethod<Object?>('signChallenge', {
          ...metadata,
          'challenge': challenge,
          'purpose': purpose,
          'localizedReason': localizedReason,
          'localized_reason': localizedReason,
        }),
      );
      if (value is String || value is num || value is bool) {
        final scalar = _firstScalarString([value]);
        if (scalar.isNotEmpty) {
          return _BiometricSignaturePayload(signature: scalar);
        }
      }
      final payload = _unwrapBiometricPayload(value, const [
        'signature',
        'biometric_signature',
        'biometricSignature',
        'signature_payload',
        'signaturePayload',
        'native_signature',
        'nativeSignature',
        'signature_data',
        'signatureData',
        'assertion_signature',
        'assertionSignature',
        'signed_payload',
        'signedPayload',
        'response',
        'authenticator_response',
        'authenticatorResponse',
        'credential_response',
        'credentialResponse',
        'assertion_response',
        'assertionResponse',
        'credential',
        'biometric_credential',
        'biometricCredential',
        'proof',
      ]);
      final signature = _firstString([
        payload['signature'],
        payload['signature_base64'],
        payload['signatureBase64'],
        payload['base64_signature'],
        payload['base64Signature'],
        payload['encoded_signature'],
        payload['encodedSignature'],
        payload['native_signature'],
        payload['nativeSignature'],
        payload['signature_data'],
        payload['signatureData'],
        payload['biometric_signature'],
        payload['biometricSignature'],
        payload['signature_payload'],
        payload['signaturePayload'],
        payload['signature_jws'],
        payload['signatureJws'],
        payload['assertion_signature'],
        payload['assertionSignature'],
        payload['assertion_jws'],
        payload['assertionJws'],
        payload['assertion_jwt'],
        payload['assertionJwt'],
        payload['credential_signature'],
        payload['credentialSignature'],
        payload['credential_assertion'],
        payload['credentialAssertion'],
        payload['raw_signature'],
        payload['rawSignature'],
        payload['signature_raw'],
        payload['signatureRaw'],
        payload['signature_der'],
        payload['signatureDer'],
        payload['signature_urlsafe'],
        payload['signatureUrlSafe'],
        payload['signed_jws'],
        payload['signedJws'],
        payload['signed_payload'],
        payload['signedPayload'],
        payload['signed_data'],
        payload['signedData'],
        payload['jws'],
        payload['proof'],
        payload['signed'],
        payload['value'],
        payload['result'],
      ]);
      if (signature.isEmpty) return null;
      return _BiometricSignaturePayload(
        signature: signature,
        metadata: _biometricSignatureMetadataFromPayload(payload),
      );
    } on PlatformException {
      return null;
    }
  }

  static bool _hasNativeKeyCompatibleBiometric(List<BiometricType> biometrics) {
    if (biometrics.isEmpty) return false;
    return biometrics.any((type) => type != BiometricType.weak);
  }
}

class _BiometricSignaturePayload {
  const _BiometricSignaturePayload({
    required this.signature,
    this.metadata = const {},
  });

  final String signature;
  final Map<String, dynamic> metadata;

  bool get isComplete => signature.trim().isNotEmpty;
}

Map<String, dynamic> _biometricKeyPairPayload(Object? response) {
  return _unwrapBiometricPayload(response, const [
    'key_pair',
    'keyPair',
    'biometric_key',
    'biometricKey',
    'biometric_key_pair',
    'biometricKeyPair',
    'device',
    'biometric_device',
    'biometricDevice',
    'native_key',
    'nativeKey',
    'native_key_pair',
    'nativeKeyPair',
    'credential',
    'biometric_credential',
    'biometricCredential',
  ]);
}

String _biometricDeviceIdFromPayload(Map<String, dynamic> payload) {
  return _firstString([
    payload['device_id'],
    payload['deviceId'],
    payload['deviceID'],
    payload['biometric_device_id'],
    payload['biometricDeviceId'],
    payload['biometricDeviceID'],
    payload['credential_id'],
    payload['credentialId'],
    payload['credentialID'],
    payload['raw_id'],
    payload['rawId'],
    payload['rawID'],
    payload['credential_raw_id'],
    payload['credentialRawId'],
    payload['credentialRawID'],
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
    payload['id'],
    payload['uuid'],
  ]);
}

String _biometricPublicKeyFromPayload(Map<String, dynamic> payload) {
  return _firstBiometricPublicKeyString([
    payload['public_key_pem'],
    payload['publicKeyPem'],
    payload['publicKeyPEM'],
    payload['public_key'],
    payload['publicKey'],
    payload['public_key_base64'],
    payload['publicKeyBase64'],
    payload['public_key_spki'],
    payload['publicKeySpki'],
    payload['publicKeySPKI'],
    payload['public_key_der'],
    payload['publicKeyDer'],
    payload['publicKeyDER'],
    payload['public_key_der_base64'],
    payload['publicKeyDerBase64'],
    payload['publicKeyDERBase64'],
    payload['public_key_jwk'],
    payload['publicKeyJwk'],
    payload['publicKeyJWK'],
    payload['public_jwk'],
    payload['publicJwk'],
    payload['credential_public_key'],
    payload['credentialPublicKey'],
    payload['key_pem'],
    payload['keyPem'],
    payload['pem_encoded'],
    payload['pemEncoded'],
    payload['pem'],
    payload['key'],
  ]);
}

String _biometricAlgorithmFromPayload(Map<String, dynamic> payload) {
  final algorithm = _firstString([
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
  ]);
  final normalized = algorithm.trim().toUpperCase().replaceAll(
    RegExp(r'[^A-Z0-9-]'),
    '',
  );
  return switch (normalized) {
    '' => 'ES256',
    'ES256' ||
    'ECDSA256' ||
    'ECDSAP256SHA256' ||
    'SHA256WITHECDSA' ||
    '-7' => 'ES256',
    'RS256' || 'RSA256' || 'SHA256WITHRSA' || '-257' => 'RS256',
    _ => 'ES256',
  };
}

Map<String, dynamic> _biometricSignatureMetadataFromPayload(
  Map<String, dynamic> payload,
) {
  final metadata = <String, dynamic>{};
  _putStringIfNotEmpty(
    metadata,
    'credential_id',
    _firstString([
      payload['credential_id'],
      payload['credentialId'],
      payload['credentialID'],
      payload['raw_id'],
      payload['rawId'],
      payload['rawID'],
      payload['credential_raw_id'],
      payload['credentialRawId'],
      payload['credentialRawID'],
      payload['native_device_id'],
      payload['nativeDeviceId'],
      payload['local_device_id'],
      payload['localDeviceId'],
      payload['external_device_id'],
      payload['externalDeviceId'],
      payload['device_id'],
      payload['deviceId'],
      payload['deviceID'],
    ]),
  );
  _putStringIfNotEmpty(
    metadata,
    'client_data_json',
    _firstString([
      payload['client_data_json'],
      payload['clientDataJson'],
      payload['clientDataJSON'],
      payload['client_data'],
      payload['clientData'],
      payload['client_json'],
      payload['clientJson'],
    ]),
  );
  _putStringIfNotEmpty(
    metadata,
    'authenticator_data',
    _firstString([
      payload['authenticator_data'],
      payload['authenticatorData'],
      payload['authenticator_data_base64'],
      payload['authenticatorDataBase64'],
      payload['auth_data'],
      payload['authData'],
      payload['authenticator'],
    ]),
  );
  _putStringIfNotEmpty(
    metadata,
    'user_handle',
    _firstString([
      payload['user_handle'],
      payload['userHandle'],
      payload['user_id'],
      payload['userId'],
    ]),
  );
  _putStringIfNotEmpty(
    metadata,
    'algorithm',
    _biometricOptionalAlgorithmFromPayload(payload),
  );
  return metadata;
}

String _biometricOptionalAlgorithmFromPayload(Map<String, dynamic> payload) {
  final algorithm = _firstString([
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
  ]);
  if (algorithm.trim().isEmpty) return '';
  return _biometricAlgorithmFromPayload(payload);
}

void _putStringIfNotEmpty(
  Map<String, dynamic> target,
  String key,
  String value,
) {
  final trimmed = value.trim();
  if (trimmed.isNotEmpty) target[key] = trimmed;
}

void _putChannelValueIfPresent(
  Map<String, dynamic> target,
  String key,
  Iterable<Object?> values,
) {
  for (final value in values) {
    final channelValue = _biometricChannelValue(value);
    if (channelValue == null) continue;
    target[key] = channelValue;
    return;
  }
}

Object? _biometricChannelValue(Object? value, [int depth = 0]) {
  if (value == null || depth >= 5) return null;
  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
  if (value is num || value is bool) return value;
  if (value is Iterable) {
    final rows = value
        .map((item) => _biometricChannelValue(item, depth + 1))
        .where((item) => item != null)
        .toList(growable: false);
    return rows.isEmpty ? null : rows;
  }

  final map = _asBiometricMap(value);
  if (map.isEmpty) return null;
  if (const {
    'value',
    'code',
    'key',
    'base64',
    'base64_url',
    'base64url',
    'base64Url',
    'base64URL',
    'url_safe_base64',
    'urlSafeBase64',
    'urlsafeBase64',
  }.any((key) => map.containsKey(key) && map.length <= 2)) {
    for (final key in const [
      'value',
      'code',
      'key',
      'base64',
      'base64_url',
      'base64url',
      'base64Url',
      'base64URL',
      'url_safe_base64',
      'urlSafeBase64',
      'urlsafeBase64',
    ]) {
      final scalar = _biometricChannelValue(map[key], depth + 1);
      if (scalar != null) return scalar;
    }
  }

  final entries = <String, dynamic>{};
  for (final entry in map.entries) {
    final key = entry.key.toString().trim();
    if (key.isEmpty) continue;
    final mappedValue = _biometricChannelValue(entry.value, depth + 1);
    if (mappedValue == null) continue;
    entries[key] = mappedValue;
  }
  return entries.isEmpty ? null : entries;
}

class BiometricChallengePayload {
  const BiometricChallengePayload({
    required this.challengeId,
    required this.challenge,
    this.metadata = const {},
  });

  factory BiometricChallengePayload.fromResponse(Object? response) {
    final payload = _unwrapBiometricPayload(response, const [
      'challenge',
      'biometric_challenge',
      'biometricChallenge',
      'auth_challenge',
      'authChallenge',
      'credential_challenge',
      'credentialChallenge',
      'public_key',
      'publicKey',
      'public_key_credential_request_options',
      'publicKeyCredentialRequestOptions',
      'request_options',
      'requestOptions',
      'options',
      'biometric_credential',
      'biometricCredential',
      'verification',
      'biometric_auth',
      'biometricAuth',
      'auth',
    ]);
    final challengeId = _firstString([
      payload['challenge_id'],
      payload['challengeId'],
      payload['biometric_challenge_id'],
      payload['biometricChallengeId'],
      payload['auth_challenge_id'],
      payload['authChallengeId'],
      payload['challenge_uuid'],
      payload['challengeUuid'],
      payload['uuid'],
      payload['request_id'],
      payload['requestId'],
      payload['request_token'],
      payload['requestToken'],
      payload['transaction_id'],
      payload['transactionId'],
      payload['reference_id'],
      payload['referenceId'],
      payload['ref_id'],
      payload['refId'],
      payload['challenge_token_id'],
      payload['challengeTokenId'],
      payload['id'],
    ]);
    final challenge = _firstString([
      payload['challenge'],
      payload['challenge_base64'],
      payload['challengeBase64'],
      payload['challenge_base64_url'],
      payload['challengeBase64Url'],
      payload['challengeBase64URL'],
      payload['base64_challenge'],
      payload['base64Challenge'],
      payload['base64_url_challenge'],
      payload['base64UrlChallenge'],
      payload['base64URLChallenge'],
      payload['payload'],
      payload['signed_payload'],
      payload['signedPayload'],
      payload['challenge_payload'],
      payload['challengePayload'],
      payload['challenge_data'],
      payload['challengeData'],
      payload['challenge_string'],
      payload['challengeString'],
      payload['challenge_nonce'],
      payload['challengeNonce'],
      payload['signing_payload'],
      payload['signingPayload'],
      payload['auth_payload'],
      payload['authPayload'],
      payload['payload_to_sign'],
      payload['payloadToSign'],
      payload['signing_data'],
      payload['signingData'],
      payload['server_challenge'],
      payload['serverChallenge'],
      payload['challenge_token'],
      payload['challengeToken'],
      payload['request_token'],
      payload['requestToken'],
      payload['credential_challenge'],
      payload['credentialChallenge'],
      payload['client_data_json'],
      payload['clientDataJson'],
      payload['clientDataJSON'],
      payload['nonce'],
    ]);
    return BiometricChallengePayload(
      challengeId: challengeId,
      challenge: challenge,
      metadata: _biometricChallengeMetadataFromPayload(payload),
    );
  }

  final String challengeId;
  final String challenge;
  final Map<String, dynamic> metadata;

  bool get isComplete => challengeId.isNotEmpty && challenge.isNotEmpty;
}

Map<String, dynamic> _biometricChallengeMetadataFromPayload(
  Map<String, dynamic> payload,
) {
  final metadata = <String, dynamic>{};
  _putStringIfNotEmpty(
    metadata,
    'credential_id',
    _firstString([
      payload['credential_id'],
      payload['credentialId'],
      payload['credentialID'],
      payload['raw_id'],
      payload['rawId'],
      payload['rawID'],
      payload['credential_raw_id'],
      payload['credentialRawId'],
      payload['credentialRawID'],
      payload['device_id'],
      payload['deviceId'],
      payload['deviceID'],
    ]),
  );
  _putStringIfNotEmpty(
    metadata,
    'rp_id',
    _firstString([
      payload['rp_id'],
      payload['rpId'],
      payload['relying_party_id'],
      payload['relyingPartyId'],
      payload['relying_party'],
      payload['relyingParty'],
      _asBiometricMap(payload['rp'])['id'],
      _asBiometricMap(payload['rp'])['rp_id'],
      _asBiometricMap(payload['rp'])['rpId'],
      _asBiometricMap(payload['relying_party'])['id'],
      _asBiometricMap(payload['relyingParty'])['id'],
    ]),
  );
  _putStringIfNotEmpty(
    metadata,
    'origin',
    _firstString([
      payload['origin'],
      payload['client_origin'],
      payload['clientOrigin'],
      payload['web_origin'],
      payload['webOrigin'],
    ]),
  );
  _putStringIfNotEmpty(
    metadata,
    'user_verification',
    _firstString([
      payload['user_verification'],
      payload['userVerification'],
      payload['verification_requirement'],
      payload['verificationRequirement'],
    ]),
  );
  _putStringIfNotEmpty(
    metadata,
    'user_handle',
    _firstString([
      payload['user_handle'],
      payload['userHandle'],
      payload['user_id'],
      payload['userId'],
      _asBiometricMap(payload['user'])['id'],
      _asBiometricMap(payload['user'])['user_id'],
      _asBiometricMap(payload['user'])['userId'],
      _asBiometricMap(payload['user'])['handle'],
      _asBiometricMap(payload['user'])['userHandle'],
    ]),
  );
  _putStringIfNotEmpty(
    metadata,
    'algorithm',
    _biometricOptionalAlgorithmFromPayload(payload),
  );
  _putChannelValueIfPresent(metadata, 'timeout', [
    payload['timeout'],
    payload['timeout_ms'],
    payload['timeoutMs'],
    payload['expires_in_ms'],
    payload['expiresInMs'],
  ]);
  _putChannelValueIfPresent(metadata, 'mediation', [
    payload['mediation'],
    payload['credential_mediation'],
    payload['credentialMediation'],
  ]);
  _putChannelValueIfPresent(metadata, 'hints', [
    payload['hints'],
    payload['credential_hints'],
    payload['credentialHints'],
  ]);
  _putChannelValueIfPresent(metadata, 'authenticator_selection', [
    payload['authenticator_selection'],
    payload['authenticatorSelection'],
    payload['authenticator'],
    payload['authenticator_options'],
    payload['authenticatorOptions'],
  ]);
  _putChannelValueIfPresent(metadata, 'attestation', [
    payload['attestation'],
    payload['attestation_conveyance_preference'],
    payload['attestationConveyancePreference'],
  ]);
  _putChannelValueIfPresent(metadata, 'attestation_formats', [
    payload['attestation_formats'],
    payload['attestationFormats'],
    payload['attestation_format'],
    payload['attestationFormat'],
    payload['formats'],
  ]);
  _putChannelValueIfPresent(metadata, 'pub_key_cred_params', [
    payload['pub_key_cred_params'],
    payload['pubKeyCredParams'],
    payload['public_key_credential_params'],
    payload['publicKeyCredentialParams'],
  ]);
  final allowCredentials = _biometricAllowCredentialsFromPayload(payload);
  if (allowCredentials != null) {
    metadata['allow_credentials'] = allowCredentials;
  }
  final excludeCredentials = _biometricExcludeCredentialsFromPayload(payload);
  if (excludeCredentials != null) {
    metadata['exclude_credentials'] = excludeCredentials;
  }
  _putChannelValueIfPresent(metadata, 'extensions', [
    payload['extensions'],
    payload['client_extensions'],
    payload['clientExtensions'],
  ]);
  return metadata;
}

Object? _biometricAllowCredentialsFromPayload(Map<String, dynamic> payload) {
  return _biometricCredentialsFromPayload(payload, const [
    'allow_credentials',
    'allowCredentials',
    'allowed_credentials',
    'allowedCredentials',
    'credentials',
    'credential_descriptors',
    'credentialDescriptors',
    'public_key_credentials',
    'publicKeyCredentials',
    'public_key_credential_descriptors',
    'publicKeyCredentialDescriptors',
  ], fallbackToPayload: true);
}

Object? _biometricExcludeCredentialsFromPayload(Map<String, dynamic> payload) {
  return _biometricCredentialsFromPayload(payload, const [
    'exclude_credentials',
    'excludeCredentials',
    'excluded_credentials',
    'excludedCredentials',
    'exclude_credential_descriptors',
    'excludeCredentialDescriptors',
  ]);
}

Object? _biometricCredentialsFromPayload(
  Map<String, dynamic> payload,
  List<String> keys, {
  bool fallbackToPayload = false,
}) {
  for (final value in [for (final key in keys) payload[key]]) {
    final normalized = _biometricAllowCredentialsValue(value);
    if (normalized != null) return normalized;
  }

  if (!fallbackToPayload) return null;
  final singleCredential = _biometricCredentialDescriptor(payload);
  if (singleCredential == null) return null;
  return [singleCredential];
}

Object? _biometricAllowCredentialsValue(Object? value) {
  if (value == null) return null;
  final rows = _biometricCredentialDescriptorRows(value);
  if (rows != null && rows.isNotEmpty) return rows;
  return _biometricChannelValue(value);
}

const _biometricCredentialListContainerKeys = [
  'allow_credentials',
  'allowCredentials',
  'allowed_credentials',
  'allowedCredentials',
  'exclude_credentials',
  'excludeCredentials',
  'excluded_credentials',
  'excludedCredentials',
  'credentials',
  'credential_descriptors',
  'credentialDescriptors',
  'public_key_credentials',
  'publicKeyCredentials',
  'public_key_credential_descriptors',
  'publicKeyCredentialDescriptors',
  'descriptors',
  'items',
  'entries',
  'records',
  'rows',
  'results',
  'list',
  'collection',
  'data',
  'resource',
  'payload',
];

const _biometricCredentialWrapperKeys = [
  'credential',
  'credential_descriptor',
  'credentialDescriptor',
  'public_key_credential',
  'publicKeyCredential',
  'public_key_credential_descriptor',
  'publicKeyCredentialDescriptor',
  'webauthn_credential',
  'webAuthnCredential',
  'webauthnCredential',
  'passkey',
  'biometric_credential',
  'biometricCredential',
  'device',
  'descriptor',
  'resource',
  'data',
  'payload',
];

List<Map<String, dynamic>>? _biometricCredentialDescriptorRows(
  Object? value, [
  int depth = 0,
]) {
  if (value == null || depth >= 5) return null;
  if (value is String || value is num || value is bool) {
    final descriptor = _biometricCredentialDescriptor(value);
    return descriptor == null ? null : [descriptor];
  }
  if (value is Iterable) {
    final rows = <Map<String, dynamic>>[];
    for (final item in value) {
      final nested = _biometricCredentialDescriptorRows(item, depth + 1);
      if (nested != null) rows.addAll(nested);
    }
    return rows.isEmpty ? null : rows;
  }

  final descriptor = _biometricCredentialDescriptor(value);
  if (descriptor != null) return [descriptor];

  final map = _asBiometricMap(value);
  if (map.isEmpty) return null;
  for (final key in _biometricCredentialListContainerKeys) {
    if (!map.containsKey(key)) continue;
    final nested = _biometricCredentialDescriptorRows(map[key], depth + 1);
    if (nested != null && nested.isNotEmpty) return nested;
  }
  return null;
}

Map<String, dynamic>? _biometricCredentialDescriptor(Object? value) {
  final map = _biometricCredentialDescriptorMap(value);
  if (map.isEmpty) {
    final scalar = _firstString([value]);
    if (scalar.isNotEmpty) {
      return {'type': 'public-key', 'id': scalar};
    }
    return null;
  }

  final descriptor = <String, dynamic>{};
  for (final entry in map.entries) {
    final key = entry.key.toString().trim();
    if (key.isEmpty) continue;
    final channelValue = _biometricChannelValue(entry.value);
    if (channelValue == null) continue;
    descriptor[key] = channelValue;
  }

  final id = _biometricCredentialDescriptorIdFromMap(map);
  if (id.isNotEmpty) descriptor['id'] = id;

  final type = _firstString([
    map['type'],
    map['credential_type'],
    map['credentialType'],
  ]);
  descriptor['type'] = type.isEmpty ? 'public-key' : type;

  return descriptor['id'] == null ? null : descriptor;
}

Map<String, dynamic> _biometricCredentialDescriptorMap(
  Object? value, [
  int depth = 0,
]) {
  final map = _asBiometricMap(value);
  if (map.isEmpty || depth >= 4) return map;
  if (_biometricCredentialDescriptorIdFromMap(map).isNotEmpty) return map;

  for (final key in _biometricCredentialWrapperKeys) {
    if (!map.containsKey(key)) continue;
    final nested = _biometricCredentialDescriptorMap(map[key], depth + 1);
    if (nested.isEmpty) continue;
    if (_biometricCredentialDescriptorIdFromMap(nested).isEmpty) continue;
    final wrapper = <String, dynamic>{...map}..remove(key);
    return {...wrapper, ...nested};
  }
  return map;
}

String _biometricCredentialDescriptorIdFromMap(Map<String, dynamic> map) {
  return _firstString([
    map['id'],
    map['credential_id'],
    map['credentialId'],
    map['credentialID'],
    map['raw_id'],
    map['rawId'],
    map['rawID'],
    map['credential_raw_id'],
    map['credentialRawId'],
    map['credentialRawID'],
    map['device_id'],
    map['deviceId'],
    map['deviceID'],
    map['native_device_id'],
    map['nativeDeviceId'],
    map['local_device_id'],
    map['localDeviceId'],
    map['external_device_id'],
    map['externalDeviceId'],
    map['value'],
    map['code'],
    map['key'],
    map['base64'],
    map['base64_url'],
    map['base64url'],
    map['base64Url'],
    map['base64URL'],
    map['url_safe_base64'],
    map['urlSafeBase64'],
    map['urlsafeBase64'],
  ]);
}

String biometricPinAssertionTokenFromResponse(Object? response) {
  final payload = _unwrapBiometricPayload(response, const [
    'verification',
    'biometric_verification',
    'biometricVerification',
    'pin_assertion',
    'pinAssertion',
    'assertion',
    'auth_result',
    'authResult',
    'verify',
    'verifyResult',
    'verificationResult',
    'credential',
    'biometric_credential',
    'biometricCredential',
  ]);
  return _firstString([
    payload['pin_assertion_token'],
    payload['pinAssertionToken'],
    payload['assertion_token'],
    payload['assertionToken'],
    payload['pin_token'],
    payload['pinToken'],
    payload['pin_assertion_jwt'],
    payload['pinAssertionJwt'],
    payload['pin_assertion_jws'],
    payload['pinAssertionJws'],
    payload['assertion_jwt'],
    payload['assertionJwt'],
    payload['assertion_jws'],
    payload['assertionJws'],
    payload['pin_assertion'],
    payload['pinAssertion'],
    payload['pin_proof'],
    payload['pinProof'],
    payload['proof_token'],
    payload['proofToken'],
    payload['verification_token'],
    payload['verificationToken'],
    payload['credential_assertion'],
    payload['credentialAssertion'],
    payload['token'],
  ]);
}

Map<String, dynamic> _unwrapBiometricPayload(
  Object? response,
  List<String> wrapperKeys,
) {
  final payload = _asBiometricMap(response);
  if (payload.isEmpty) return unwrapPayload(response);
  return _unwrapBiometricMap(payload, wrapperKeys);
}

Map<String, dynamic> _unwrapBiometricMap(
  Map<String, dynamic> payload,
  List<String> wrapperKeys, [
  int depth = 0,
]) {
  if (depth >= 6 || payload.isEmpty) return payload;

  for (final key in [...wrapperKeys, 'resource', 'data', 'result', 'payload']) {
    final nested = _asBiometricMap(payload[key]);
    if (nested.isEmpty) continue;
    final resolved = _unwrapBiometricMap(nested, wrapperKeys, depth + 1);
    final wrapper = <String, dynamic>{...payload}..remove(key);
    return {...wrapper, ...resolved};
  }
  return payload;
}

Map<String, dynamic> _asBiometricMap(Object? value) {
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

String _firstScalarString(Iterable<Object?> values) {
  for (final value in values) {
    final stringValue = _biometricScalarText(value);
    if (stringValue.isNotEmpty) return stringValue;
  }
  return '';
}

String _firstBiometricPublicKeyString(Iterable<Object?> values) {
  for (final value in values) {
    final stringValue = _biometricPublicKeyText(value);
    if (stringValue.isNotEmpty) return stringValue;
  }
  return '';
}

String _biometricPublicKeyText(Object? value) {
  final scalar = _biometricScalarText(value);
  if (scalar.isNotEmpty) return scalar;

  final unwrapped = _biometricScalarObjectValue(value);
  if (unwrapped == null) return '';

  final map = _asBiometricMap(unwrapped);
  if (map.isNotEmpty) return convert.jsonEncode(map);

  if (unwrapped is Iterable) {
    return convert.jsonEncode(unwrapped.toList(growable: false));
  }

  return '';
}

Object? _biometricScalarObjectValue(Object? value, [int depth = 0]) {
  if (depth >= 4) return value;
  final map = _asBiometricMap(value);
  if (map.isEmpty) return value;
  for (final key in const [
    'value',
    'json',
    'jwk',
    'base64',
    'base64_url',
    'base64url',
    'base64Url',
    'base64URL',
    'url_safe_base64',
    'urlSafeBase64',
    'urlsafeBase64',
    'public_key_jwk',
    'publicKeyJwk',
    'publicKeyJWK',
  ]) {
    if (!map.containsKey(key)) continue;
    return _biometricScalarObjectValue(map[key], depth + 1);
  }
  return value;
}

String _biometricScalarText(Object? value, [int depth = 0]) {
  if (value == null) return '';
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.startsWith('{') && depth < 4) {
      final map = _asBiometricMap(trimmed);
      if (map.isNotEmpty) {
        final text = _biometricScalarText(map, depth + 1);
        if (text.isNotEmpty) return text;
      }
    }
    return trimmed;
  }
  if (value is num || value is bool) return value.toString().trim();
  if (depth >= 4 || value is Iterable) return '';

  final map = _asBiometricMap(value);
  if (map.isEmpty) return '';

  for (final key in const [
    'value',
    'code',
    'key',
    'base64',
    'base64_url',
    'base64url',
    'base64Url',
    'base64URL',
    'url_safe_base64',
    'urlSafeBase64',
    'urlsafeBase64',
    'device',
    'biometric_device',
    'biometricDevice',
    'native_device',
    'nativeDevice',
    'credential',
    'biometric_credential',
    'biometricCredential',
    'key_pair',
    'keyPair',
    'native_key_pair',
    'nativeKeyPair',
    'biometric_key_pair',
    'biometricKeyPair',
    'biometric_key',
    'biometricKey',
    'native_key',
    'nativeKey',
    'challenge',
    'biometric_challenge',
    'biometricChallenge',
    'auth_challenge',
    'authChallenge',
    'credential_challenge',
    'credentialChallenge',
    'verification',
    'biometric_verification',
    'biometricVerification',
    'pin_assertion',
    'pinAssertion',
    'assertion',
    'auth_result',
    'authResult',
    'verify',
    'verifyResult',
    'verificationResult',
    'id',
    'uuid',
    'token',
    'device_id',
    'deviceId',
    'deviceID',
    'biometric_device_id',
    'biometricDeviceId',
    'biometricDeviceID',
    'credential_id',
    'credentialId',
    'credentialID',
    'raw_id',
    'rawId',
    'rawID',
    'credential_raw_id',
    'credentialRawId',
    'credentialRawID',
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
    'public_key_pem',
    'publicKeyPem',
    'publicKeyPEM',
    'public_key',
    'publicKey',
    'public_key_base64',
    'publicKeyBase64',
    'public_key_spki',
    'publicKeySpki',
    'publicKeySPKI',
    'public_key_der',
    'publicKeyDer',
    'publicKeyDER',
    'public_key_der_base64',
    'publicKeyDerBase64',
    'publicKeyDERBase64',
    'public_key_jwk',
    'publicKeyJwk',
    'publicKeyJWK',
    'public_jwk',
    'publicJwk',
    'credential_public_key',
    'credentialPublicKey',
    'key_pem',
    'keyPem',
    'pem_encoded',
    'pemEncoded',
    'pem',
    'key',
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
    'challenge_id',
    'challengeId',
    'biometric_challenge_id',
    'biometricChallengeId',
    'auth_challenge_id',
    'authChallengeId',
    'request_id',
    'requestId',
    'request_token',
    'requestToken',
    'transaction_id',
    'transactionId',
    'reference_id',
    'referenceId',
    'ref_id',
    'refId',
    'challenge_token_id',
    'challengeTokenId',
    'payload',
    'signed_payload',
    'signedPayload',
    'challenge_payload',
    'challengePayload',
    'challenge_data',
    'challengeData',
    'challenge_string',
    'challengeString',
    'challenge_nonce',
    'challengeNonce',
    'signing_payload',
    'signingPayload',
    'auth_payload',
    'authPayload',
    'payload_to_sign',
    'payloadToSign',
    'signing_data',
    'signingData',
    'server_challenge',
    'serverChallenge',
    'challenge_token',
    'challengeToken',
    'request_token',
    'requestToken',
    'credential_challenge',
    'credentialChallenge',
    'client_data_json',
    'clientDataJson',
    'clientDataJSON',
    'nonce',
    'signature',
    'signature_base64',
    'signatureBase64',
    'base64_signature',
    'base64Signature',
    'encoded_signature',
    'encodedSignature',
    'native_signature',
    'nativeSignature',
    'signature_data',
    'signatureData',
    'biometric_signature',
    'biometricSignature',
    'signature_payload',
    'signaturePayload',
    'signature_jws',
    'signatureJws',
    'raw_signature',
    'rawSignature',
    'signature_raw',
    'signatureRaw',
    'signature_der',
    'signatureDer',
    'signature_urlsafe',
    'signatureUrlSafe',
    'response',
    'authenticator_response',
    'authenticatorResponse',
    'credential_response',
    'credentialResponse',
    'assertion_response',
    'assertionResponse',
    'assertion_signature',
    'assertionSignature',
    'assertion_jws',
    'assertionJws',
    'assertion_jwt',
    'assertionJwt',
    'credential_signature',
    'credentialSignature',
    'credential_assertion',
    'credentialAssertion',
    'signed_jws',
    'signedJws',
    'signed_data',
    'signedData',
    'jws',
    'proof',
    'signed',
    'pin_assertion_token',
    'pinAssertionToken',
    'assertion_token',
    'assertionToken',
    'pin_token',
    'pinToken',
    'pin_assertion_jwt',
    'pinAssertionJwt',
    'pin_assertion_jws',
    'pinAssertionJws',
    'assertion_jwt',
    'assertionJwt',
    'assertion_jws',
    'assertionJws',
    'pin_assertion',
    'pinAssertion',
    'pin_proof',
    'pinProof',
    'proof_token',
    'proofToken',
    'verification_token',
    'verificationToken',
    'credential_assertion',
    'credentialAssertion',
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
