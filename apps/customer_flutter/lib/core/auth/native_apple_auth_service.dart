import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'auth_repository.dart';
import '../tenant/mobile_bootstrap_controller.dart';

final nativeAppleAuthServiceProvider = Provider<NativeAppleAuthService>((ref) {
  return NativeAppleAuthService(repository: ref.read(authRepositoryProvider));
});

List<SocialAuthProvider> nativeAppleProvidersForPlatform(
  List<SocialAuthProvider> providers,
) {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return providers;
  if (providers.any((provider) => provider.provider == 'apple')) {
    return providers;
  }
  return List.unmodifiable([
    ...providers,
    const SocialAuthProvider(
      provider: 'apple',
      label: 'Apple ID',
      enabled: true,
    ),
  ]);
}

class NativeAppleLoginCancelled implements Exception {
  const NativeAppleLoginCancelled();
}

class NativeAppleCredential {
  const NativeAppleCredential({
    required this.authorizationCode,
    required this.identityToken,
    this.email,
    this.givenName,
    this.familyName,
  });

  final String authorizationCode;
  final String identityToken;
  final String? email;
  final String? givenName;
  final String? familyName;
}

typedef NativeAppleAvailability = Future<bool> Function();
typedef NativeAppleCredentialLoader =
    Future<NativeAppleCredential> Function(String hashedNonce);

class NativeAppleAuthService {
  NativeAppleAuthService({
    required AuthRepository repository,
    NativeAppleAvailability? isAvailable,
    NativeAppleCredentialLoader? loadCredential,
    String Function()? generateRawNonce,
  }) : _repository = repository,
       _isAvailable = isAvailable ?? SignInWithApple.isAvailable,
       _loadCredential = loadCredential ?? _defaultCredentialLoader,
       _generateRawNonce = generateRawNonce ?? generateNonce;

  final AuthRepository _repository;
  final NativeAppleAvailability _isAvailable;
  final NativeAppleCredentialLoader _loadCredential;
  final String Function() _generateRawNonce;

  bool get platformSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  Future<SocialCallbackResult?> authenticate({
    String purpose = 'login',
    String redirect = '/',
    bool auth = false,
  }) async {
    if (!platformSupported || !await _isAvailable()) return null;

    final rawNonce = _generateRawNonce();
    if (rawNonce.trim().isEmpty) {
      throw StateError('Apple sign-in nonce could not be generated.');
    }
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

    try {
      final credential = await _loadCredential(hashedNonce);
      final authorizationCode = credential.authorizationCode.trim();
      final identityToken = credential.identityToken.trim();
      if (authorizationCode.isEmpty || identityToken.isEmpty) {
        throw StateError('Apple did not return complete credentials.');
      }

      return _repository.nativeAppleLogin(
        authorizationCode: authorizationCode,
        identityToken: identityToken,
        nonce: rawNonce,
        email: credential.email,
        firstName: credential.givenName,
        lastName: credential.familyName,
        purpose: purpose,
        redirect: redirect,
        auth: auth,
      );
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code == AuthorizationErrorCode.canceled) {
        throw const NativeAppleLoginCancelled();
      }
      rethrow;
    }
  }

  static Future<NativeAppleCredential> _defaultCredentialLoader(
    String hashedNonce,
  ) async {
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: const [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );
    return NativeAppleCredential(
      authorizationCode: credential.authorizationCode,
      identityToken: credential.identityToken ?? '',
      email: credential.email,
      givenName: credential.givenName,
      familyName: credential.familyName,
    );
  }
}
