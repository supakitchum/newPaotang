import 'package:customer_flutter/core/auth/auth_repository.dart';
import 'package:customer_flutter/core/auth/auth_token_store.dart';
import 'package:customer_flutter/core/auth/native_google_auth_service.dart';
import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/network/api_client.dart';
import 'package:customer_flutter/core/tenant/mobile_bootstrap_controller.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final originalPlatform = debugDefaultTargetPlatformOverride;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = originalPlatform;
  });

  test(
    'native Google uses runtime Web client ID and sends ID token to API',
    () async {
      final repository = _CapturingGoogleRepository();
      final coordinator = NativeGooglePromptCoordinator();
      var promptWasActive = false;
      final service = NativeGoogleAuthService(
        repository: repository,
        promptCoordinator: coordinator,
        serverClientIdLoader: () async => 'web-client-id',
        loadCredential: (clientId) async {
          expect(clientId, 'web-client-id');
          promptWasActive = coordinator.isActive;
          return 'signed-google-id-token';
        },
      );

      final result = await service.authenticate(
        purpose: 'link',
        redirect: '/profile/social-accounts',
        auth: true,
      );

      expect(promptWasActive, isTrue);
      expect(coordinator.isActive, isFalse);
      expect(repository.identityToken, 'signed-google-id-token');
      expect(repository.purpose, 'link');
      expect(repository.redirect, '/profile/social-accounts');
      expect(repository.auth, isTrue);
      expect(result?.provider, 'google');
    },
  );

  test(
    'native Google refuses to launch without a configured client ID',
    () async {
      final repository = _CapturingGoogleRepository();
      final service = NativeGoogleAuthService(
        repository: repository,
        promptCoordinator: NativeGooglePromptCoordinator(),
        serverClientIdLoader: () async => '',
        loadCredential: (_) => throw StateError('picker must not open'),
      );

      await expectLater(service.authenticate(), throwsStateError);
      expect(repository.identityToken, isNull);
    },
  );

  test('bootstrap parses public native Google client ID', () {
    final bootstrap = MobileBootstrap.fromJson(const {
      'mobile': {
        'auth_providers': [
          {
            'provider': 'google',
            'enabled': true,
            'native_client_id': 'web-client-id',
          },
        ],
      },
    });

    expect(bootstrap.authProviders.single.nativeClientId, 'web-client-id');
  });
}

class _CapturingGoogleRepository extends AuthRepository {
  _CapturingGoogleRepository()
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

  String? identityToken;
  String? purpose;
  String? redirect;
  bool? auth;

  @override
  Future<SocialCallbackResult> nativeGoogleLogin({
    required String identityToken,
    String purpose = 'login',
    String? redirect,
    bool auth = false,
  }) async {
    this.identityToken = identityToken;
    this.purpose = purpose;
    this.redirect = redirect;
    this.auth = auth;
    return SocialCallbackResult.fromJson(const {
      'provider': 'google',
      'social_linked': true,
    });
  }
}
