import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:customer_flutter/core/auth/auth_repository.dart';
import 'package:customer_flutter/core/auth/auth_token_store.dart';
import 'package:customer_flutter/core/auth/native_apple_auth_service.dart';
import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/network/api_client.dart';
import 'package:customer_flutter/core/tenant/mobile_bootstrap_controller.dart';

void main() {
  final originalPlatform = debugDefaultTargetPlatformOverride;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = originalPlatform;
  });

  test(
    'native Apple service hashes nonce and sends raw nonce to API',
    () async {
      final repository = _CapturingAppleRepository();
      late String receivedHashedNonce;
      final service = NativeAppleAuthService(
        repository: repository,
        isAvailable: () async => true,
        generateRawNonce: () => 'raw-nonce',
        loadCredential: (hashedNonce) async {
          receivedHashedNonce = hashedNonce;
          return const NativeAppleCredential(
            authorizationCode: 'authorization-code',
            identityToken: 'identity-token',
            email: 'apple@example.test',
            givenName: 'Ada',
            familyName: 'Lovelace',
          );
        },
      );

      final result = await service.authenticate(redirect: '/tickets');

      expect(
        receivedHashedNonce,
        sha256.convert('raw-nonce'.codeUnits).toString(),
      );
      expect(repository.authorizationCode, 'authorization-code');
      expect(repository.identityToken, 'identity-token');
      expect(repository.nonce, 'raw-nonce');
      expect(repository.email, 'apple@example.test');
      expect(repository.firstName, 'Ada');
      expect(repository.lastName, 'Lovelace');
      expect(result?.provider, 'apple');
    },
  );

  test(
    'native Apple service returns null when capability is unavailable',
    () async {
      final repository = _CapturingAppleRepository();
      final service = NativeAppleAuthService(
        repository: repository,
        isAvailable: () async => false,
        loadCredential: (_) => throw StateError('must not load credentials'),
      );

      expect(await service.authenticate(), isNull);
      expect(repository.authorizationCode, isNull);
    },
  );

  test('native Apple provider is added only on iOS when absent', () {
    final providers = nativeAppleProvidersForPlatform(const []);

    expect(providers, hasLength(1));
    expect(providers.single.provider, 'apple');
    expect(providers.single.enabled, isTrue);
  });

  test('native Apple provider does not duplicate runtime configuration', () {
    const runtimeApple = SocialAuthProvider(
      provider: 'apple',
      label: 'Apple',
      enabled: false,
    );

    final providers = nativeAppleProvidersForPlatform(const [runtimeApple]);

    expect(providers, same(const [runtimeApple]));
  });
}

class _CapturingAppleRepository extends AuthRepository {
  _CapturingAppleRepository()
    : super(
        api: ApiClient(
          const AppConfig(
            apiBaseUrl: 'https://partner.example.test/api/v1',
            defaultLocale: 'th-TH',
          ),
          AuthTokenStore(),
          localeTag: 'th-TH',
          dio: Dio(),
        ),
        tokenStore: AuthTokenStore(),
      );

  String? authorizationCode;
  String? identityToken;
  String? nonce;
  String? email;
  String? firstName;
  String? lastName;

  @override
  Future<SocialCallbackResult> nativeAppleLogin({
    required String authorizationCode,
    required String identityToken,
    required String nonce,
    String? email,
    String? firstName,
    String? lastName,
    String purpose = 'login',
    String? redirect,
    bool auth = false,
  }) async {
    this.authorizationCode = authorizationCode;
    this.identityToken = identityToken;
    this.nonce = nonce;
    this.email = email;
    this.firstName = firstName;
    this.lastName = lastName;
    return SocialCallbackResult.fromJson({
      'provider': 'apple',
      'social_link_required': true,
      'link_token': 'apple-link-token',
    });
  }
}
