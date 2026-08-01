import 'package:customer_flutter/core/auth/auth_repository.dart';
import 'package:customer_flutter/core/auth/auth_token_store.dart';
import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/network/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('login preserves recursive session wrappers and saves tokens', () async {
    final tokenStore = _MemoryTokenStore();
    final api = _AuthApiClient(tokenStore);
    final repository = AuthRepository(api: api, tokenStore: tokenStore);

    final session = await repository.login(
      username: '0812345678',
      password: 'secret',
    );

    expect(api.paths, ['/customer/auth/login']);
    expect(api.authFlags, [false]);
    expect(api.payloads.single, {
      'username': '0812345678',
      'password': 'secret',
    });
    expect(session.accessToken, 'access-recursive-login');
    expect(session.refreshToken, 'refresh-recursive-login');
    expect(session.pinRequired, isTrue);
    expect(session.customerId, 'cus_recursive_login');
    expect(session.preferredLocale, 'en-US');
    expect(tokenStore.accessToken, 'access-recursive-login');
    expect(tokenStore.refreshToken, 'refresh-recursive-login');
    expect(tokenStore.customerId, 'cus_recursive_login');
  });

  test(
    'login OTP challenge never saves a session before verification',
    () async {
      final tokenStore = _MemoryTokenStore();
      final api = _AuthApiClient(tokenStore)..loginOtpRequired = true;
      final repository = AuthRepository(api: api, tokenStore: tokenStore);

      LoginOtpChallenge? challenge;
      try {
        await repository.login(username: '0812345678', password: 'secret');
      } on LoginOtpChallengeRequired catch (required) {
        challenge = required.challenge;
      }

      expect(challenge?.challengeToken, 'lotp-test-challenge');
      expect(challenge?.phoneMasked, '081xxxx678');
      expect(challenge?.resendAfterSeconds, 25);
      expect(tokenStore.hasAccessToken, isFalse);
      expect(tokenStore.refreshToken, isNull);

      final resent = await repository.resendLoginOtp(
        challengeToken: challenge!.challengeToken,
      );
      expect(resent.challengeToken, challenge.challengeToken);

      final session = await repository.verifyLoginOtp(
        challengeToken: challenge.challengeToken,
        otp: '123456',
      );
      expect(session.accessToken, 'access-login-otp');
      expect(session.pinRequired, isTrue);
      expect(tokenStore.accessToken, 'access-login-otp');
      expect(api.paths, [
        '/customer/auth/login',
        '/customer/auth/login/otp/resend',
        '/customer/auth/login/otp/verify',
      ]);
    },
  );

  test(
    'logout sends Nuxt parity idempotency header and clears session',
    () async {
      final tokenStore = _MemoryTokenStore();
      await tokenStore.save(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
        customerId: 'customer-id',
      );
      final api = _AuthApiClient(tokenStore);
      final repository = AuthRepository(api: api, tokenStore: tokenStore);

      await repository.logout();

      expect(api.headerPaths, ['/customer/auth/logout']);
      expect(api.headerPayloads, [<String, dynamic>{}]);
      expect(
        api.headers.single['Idempotency-Key'],
        startsWith('customer_auth_logout_'),
      );
      expect(tokenStore.hasAccessToken, isFalse);
      expect(tokenStore.refreshToken, isNull);
      expect(tokenStore.customerId, isNull);
    },
  );

  test(
    'refresh preserves stored identity when response only rotates access',
    () async {
      final tokenStore = _MemoryTokenStore();
      await tokenStore.save(
        accessToken: 'expired-access',
        refreshToken: 'stored-refresh',
        customerId: 'cus_stored',
      );
      final api = _AuthApiClient(tokenStore);
      final repository = AuthRepository(api: api, tokenStore: tokenStore);

      final session = await repository.refresh();

      expect(api.paths, ['/customer/auth/refresh']);
      expect(api.authFlags, [false]);
      expect(api.payloads, [
        {'refresh_token': 'stored-refresh'},
      ]);
      expect(session.accessToken, 'refreshed-access-only');
      expect(session.refreshToken, 'stored-refresh');
      expect(session.customerId, 'cus_stored');
      expect(tokenStore.accessToken, 'refreshed-access-only');
      expect(tokenStore.refreshToken, 'stored-refresh');
      expect(tokenStore.customerId, 'cus_stored');
    },
  );

  test(
    'currentIdentity uses profile replacement and parses PIN locale state',
    () async {
      final tokenStore = _MemoryTokenStore();
      final api = _AuthApiClient(tokenStore);
      final repository = AuthRepository(api: api, tokenStore: tokenStore);

      final identity = await repository.currentIdentity();

      expect(api.getPaths, ['/customer/profile']);
      expect(identity.customerId, 'cus_profile');
      expect(identity.hasPin, isFalse);
      expect(identity.pinRequired, isTrue);
      expect(identity.pinSetupRequired, isTrue);
      expect(identity.preferredLocale, 'en-US');
    },
  );

  test(
    'socialLoginUrl saves unauthenticated callback mode for login flows',
    () async {
      final tokenStore = _MemoryTokenStore();
      final api = _AuthApiClient(tokenStore);
      final repository = AuthRepository(api: api, tokenStore: tokenStore);

      final url = await repository.socialLoginUrl(
        'google_oauth2',
        purpose: 'password_reset',
        redirect: '/checkout?order_id=ord_social',
      );
      final callback = await repository.socialCallback(
        provider: 'google_oauth2',
        query: {'code': 'callback-code', 'state': 'google-launch-state'},
      );

      expect(url, 'https://auth.example.test/google?state=google-launch-state');
      expect(api.paths, [
        '/customer/auth/social/google/login',
        '/customer/auth/social/google/callback',
      ]);
      expect(api.authFlags, [false, false]);
      expect(api.payloads.first, {
        'purpose': 'password_reset',
        'client': 'customer_flutter',
        'callback_path': '/social/google/callback',
        'redirect': '/checkout?order_id=ord_social',
      });
      expect(api.payloads.last, {
        'code': 'callback-code',
        'state': 'google-launch-state',
      });
      expect(callback.session?.accessToken, 'access-google-callback');
      expect(callback.redirectPath, '/checkout?order_id=ord_social');
      expect(
        await tokenStore.readSocialCallbackContext('google-launch-state'),
        isNull,
      );
    },
  );

  test(
    'social callback keeps its saved context when the first attempt fails',
    () async {
      final tokenStore = _MemoryTokenStore();
      final api = _AuthApiClient(tokenStore);
      final repository = AuthRepository(api: api, tokenStore: tokenStore);

      await repository.socialLoginUrl(
        'google',
        redirect: '/profile/line-notifications',
      );
      api.googleCallbackFailuresRemaining = 1;

      await expectLater(
        repository.socialCallback(
          provider: 'google',
          query: const {
            'code': 'callback-code',
            'state': 'google-launch-state',
          },
        ),
        throwsA(isA<DioException>()),
      );

      final retained = await tokenStore.readSocialCallbackContext(
        'google-launch-state',
      );
      expect(retained?.auth, isFalse);
      expect(retained?.redirect, '/profile/line-notifications');

      final callback = await repository.socialCallback(
        provider: 'google',
        query: const {'code': 'callback-code', 'state': 'google-launch-state'},
      );

      expect(callback.session?.accessToken, 'access-google-callback');
      expect(callback.redirectPath, '/profile/line-notifications');
      expect(api.authFlags, [false, false, false]);
    },
  );

  test('requestOtp and verifyOtp preserve recursive OTP wrappers', () async {
    final tokenStore = _MemoryTokenStore();
    final api = _AuthApiClient(tokenStore);
    final repository = AuthRepository(api: api, tokenStore: tokenStore);

    final requested = await repository.requestOtp(
      phone: '0812345678',
      purpose: 'register',
    );
    final verified = await repository.verifyOtp(
      phone: '0812345678',
      purpose: 'register',
      otp: '123456',
    );

    expect(api.paths, [
      '/customer/auth/otp/request',
      '/customer/auth/otp/verify',
    ]);
    expect(requested.phoneMasked, '08xxxxx678');
    expect(requested.resendAfterSeconds, 25);
    expect(verified.verificationToken, 'otp-verify-recursive');
  });

  test('social callback and link-phone preserve saved return paths', () async {
    final tokenStore = _MemoryTokenStore();
    final api = _AuthApiClient(tokenStore);
    final repository = AuthRepository(api: api, tokenStore: tokenStore);

    final callback = await repository.socialCallback(
      provider: 'line_oauth',
      query: {'code': 'callback-code'},
    );
    final session = await repository.socialLinkPhone(
      provider: 'google_oauth2',
      linkToken: 'link-token',
      phone: '0812345678',
      firstName: 'Ada',
      lastName: 'Lovelace',
      password: 'secret1234',
      passwordConfirmation: 'secret1234',
      otpVerificationToken: 'otp-verified-social',
      acceptedTerms: true,
      redirect: '/checkout?order_id=ord_link',
    );

    expect(api.paths, [
      '/customer/auth/social/line/callback',
      '/customer/auth/social/google/link-phone',
    ]);
    expect(api.authFlags, [true, false]);
    expect(api.payloads.first, {'code': 'callback-code'});
    expect(callback.provider, 'line');
    expect(callback.lineLinkRequired, isTrue);
    expect(callback.linkToken, 'line-link-return');
    expect(callback.displayName, 'Line Customer');
    expect(callback.redirectPath, '/tickets');
    expect(api.payloads.last, {
      'link_token': 'link-token',
      'phone': '0812345678',
      'first_name': 'Ada',
      'last_name': 'Lovelace',
      'name': 'Ada Lovelace',
      'password': 'secret1234',
      'password_confirmation': 'secret1234',
      'otp_verification_token': 'otp-verified-social',
      'accepted_terms': true,
      'redirect': '/checkout?order_id=ord_link',
    });
    expect(session.accessToken, 'access-linked-social');
    expect(session.customerId, 'cus_linked_social');
  });

  test('profile social launch keeps authenticated callback mode', () async {
    final tokenStore = _MemoryTokenStore();
    final api = _AuthApiClient(tokenStore);
    final repository = AuthRepository(api: api, tokenStore: tokenStore);

    final url = await repository.socialLoginUrl(
      'line',
      redirect: '/profile/line-notifications',
      callbackUsesAuth: true,
    );
    final callback = await repository.socialCallback(
      provider: 'line',
      query: {'code': 'callback-code', 'state': 'line-profile-state'},
    );

    expect(url, 'https://auth.example.test/line?state=line-profile-state');
    expect(api.paths, [
      '/customer/auth/social/line/login',
      '/customer/auth/social/line/callback',
    ]);
    expect(api.authFlags, [true, true]);
    expect(api.payloads.first['purpose'], 'link');
    expect(callback.session?.accessToken, 'access-line-linked');
    expect(callback.redirectPath, '/profile/line-notifications');
  });

  test('social callback auth mode accepts callbackState aliases', () async {
    final tokenStore = _MemoryTokenStore();
    final api = _AuthApiClient(tokenStore);
    final repository = AuthRepository(api: api, tokenStore: tokenStore);

    final url = await repository.socialLoginUrl(
      'google',
      purpose: 'link',
      redirect: '/profile/line-notifications',
      callbackUsesAuth: true,
    );
    final callback = await repository.socialCallback(
      provider: 'google',
      query: {
        'code': 'callback-code',
        'callbackState': 'google-fragment-state',
      },
    );

    expect(
      url,
      'https://auth.example.test/google/callback#callbackState=google-fragment-state',
    );
    expect(api.paths, [
      '/customer/auth/social/google/login',
      '/customer/auth/social/google/callback',
    ]);
    expect(api.authFlags, [true, true]);
    expect(callback.session?.accessToken, 'access-google-callback');
  });

  test('social callback accepts JSON-string wrapped query aliases', () async {
    final tokenStore = _MemoryTokenStore();
    final api = _AuthApiClient(tokenStore);
    final repository = AuthRepository(api: api, tokenStore: tokenStore);
    await tokenStore.rememberSocialCallbackAuthMode(
      state: 'wrapped-callback-state',
      auth: false,
    );

    final callback = await repository.socialCallback(
      provider: 'google',
      query: {
        'payload':
            '{"authorizationCode":"wrapped-code","callbackState":"wrapped-callback-state"}',
      },
    );

    expect(api.paths, ['/customer/auth/social/google/callback']);
    expect(api.authFlags, [false]);
    expect(api.payloads.single, {
      'payload':
          '{"authorizationCode":"wrapped-code","callbackState":"wrapped-callback-state"}',
      'code': 'wrapped-code',
      'state': 'wrapped-callback-state',
    });
    expect(callback.session?.accessToken, 'access-google-callback');
  });

  test(
    'social launch and callback accept metadata OAuth wrapper aliases',
    () async {
      final tokenStore = _MemoryTokenStore();
      final api = _AuthApiClient(tokenStore);
      final repository = AuthRepository(api: api, tokenStore: tokenStore);

      final url = await repository.socialLoginUrl(
        'google',
        purpose: 'native_metadata',
        redirect: '/tickets',
      );
      final callback = await repository.socialCallback(
        provider: 'google',
        query: {
          'metadata':
              '{"oauth":{"providerCode":"metadata-code","providerState":"metadata-login-state"}}',
        },
      );

      expect(url, 'https://auth.example.test/google/metadata');
      expect(api.paths, [
        '/customer/auth/social/google/login',
        '/customer/auth/social/google/callback',
      ]);
      expect(api.authFlags, [false, false]);
      expect(api.payloads.last, {
        'metadata':
            '{"oauth":{"providerCode":"metadata-code","providerState":"metadata-login-state"}}',
        'code': 'metadata-code',
        'state': 'metadata-login-state',
      });
      expect(callback.session?.accessToken, 'access-google-callback');
    },
  );

  test(
    'social launch remembers payload state and hyphen provider aliases',
    () async {
      final tokenStore = _MemoryTokenStore();
      final api = _AuthApiClient(tokenStore);
      final repository = AuthRepository(api: api, tokenStore: tokenStore);

      final url = await repository.socialLoginUrl(
        'apple-login',
        purpose: 'login',
        redirect: '/tickets',
      );
      final callback = await repository.socialCallback(
        provider: 'apple-id',
        query: {'code': 'apple-code', 'state': 'apple-payload-state'},
      );

      expect(url, 'https://auth.example.test/apple/callback');
      expect(api.paths, [
        '/customer/auth/social/apple/login',
        '/customer/auth/social/apple/callback',
      ]);
      expect(api.authFlags, [false, false]);
      expect(api.payloads.first, {
        'purpose': 'login',
        'client': 'customer_flutter',
        'callback_path': '/social/apple/callback',
        'redirect': '/tickets',
      });
      expect(callback.session?.accessToken, 'access-apple-callback');
      expect(callback.redirectPath, '/tickets');
    },
  );

  test('social callback accepts nested password reset resources', () async {
    final tokenStore = _MemoryTokenStore();
    final api = _AuthApiClient(tokenStore);
    final repository = AuthRepository(api: api, tokenStore: tokenStore);

    final callback = await repository.socialCallback(
      provider: 'line-login',
      query: {'code': 'reset-code', 'state': 'line-reset-state'},
    );

    expect(api.paths, ['/customer/auth/social/line/callback']);
    expect(api.authFlags, [true]);
    expect(api.payloads.single, {
      'code': 'reset-code',
      'state': 'line-reset-state',
    });
    expect(callback.provider, 'line');
    expect(callback.passwordResetReady, isTrue);
    expect(callback.passwordResetToken, 'line-reset-token-nested');
    expect(callback.session, isNull);
  });
}

class _AuthApiClient extends ApiClient {
  _AuthApiClient(AuthTokenStore tokenStore)
    : super(
        const AppConfig(
          apiBaseUrl: 'https://partner.example.test/api/v1',
          defaultLocale: 'th-TH',
        ),
        tokenStore,
        localeTag: 'th-TH',
      );

  final paths = <String>[];
  final getPaths = <String>[];
  final authFlags = <bool>[];
  final payloads = <Map<String, dynamic>>[];
  int googleCallbackFailuresRemaining = 0;
  bool loginOtpRequired = false;
  final headerPaths = <String>[];
  final headerPayloads = <Map<String, dynamic>>[];
  final headers = <Map<String, String>>[];

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? query,
    bool auth = true,
  }) async {
    getPaths.add(path);
    if (path != '/customer/profile') {
      throw StateError('Unexpected auth GET path: $path');
    }
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data:
          <String, dynamic>{
                'data': {
                  'resource': {
                    'customer': {
                      'customerId': 'cus_profile',
                      'hasPin': false,
                      'pinRequired': true,
                      'pinSetupRequired': true,
                      'preferredLocale': 'en-US',
                    },
                  },
                },
              }
              as T,
    );
  }

  @override
  Future<Response<T>> postWithHeaders<T>(
    String path, {
    Object? data,
    bool auth = true,
    Map<String, String> headers = const {},
  }) async {
    headerPaths.add(path);
    headerPayloads.add(Map<String, dynamic>.from(data! as Map));
    this.headers.add(Map<String, String>.from(headers));
    if (path != '/customer/auth/logout') {
      throw StateError('Unexpected auth header path: $path');
    }
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: <String, dynamic>{} as T,
    );
  }

  @override
  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    bool auth = true,
  }) async {
    paths.add(path);
    authFlags.add(auth);
    payloads.add(Map<String, dynamic>.from(data! as Map));
    if (path == '/customer/auth/social/google/callback' &&
        googleCallbackFailuresRemaining > 0) {
      googleCallbackFailuresRemaining -= 1;
      throw DioException(
        requestOptions: RequestOptions(path: path),
        type: DioExceptionType.connectionError,
        message: 'temporary callback failure',
      );
    }

    final response = switch (path) {
      '/customer/auth/login' when loginOtpRequired => {
        'data': {
          'resource': {
            'otpChallenge': {
              'otpRequired': true,
              'loginChallengeToken': 'lotp-test-challenge',
              'phoneMasked': '081xxxx678',
              'resendAfterSeconds': 25,
              'expiresInSeconds': 600,
            },
          },
        },
      },
      '/customer/auth/login' => {
        'pinRequired': true,
        'data': {
          'resource': {
            'customerSession': {
              'accessToken': 'access-recursive-login',
              'refreshToken': 'refresh-recursive-login',
              'customer': {
                'customerId': 'cus_recursive_login',
                'preferredLocale': 'en-US',
              },
            },
          },
        },
      },
      '/customer/auth/login/otp/resend' => {
        'otp_required': true,
        'login_challenge_token': 'lotp-test-challenge',
        'phone_masked': '081xxxx678',
        'resend_after_seconds': 25,
        'expires_in_seconds': 600,
      },
      '/customer/auth/login/otp/verify' => {
        'token': 'access-login-otp',
        'refresh_token': 'refresh-login-otp',
        'pin_required': true,
        'user': {'id': 'cus_login_otp'},
      },
      '/customer/auth/refresh' => {
        'data': {
          'resource': {
            'customerSession': {
              'accessToken': 'refreshed-access-only',
              'pinRequired': true,
            },
          },
        },
      },
      '/customer/auth/social/google/login' => {
        'data': {
          'resource': {
            'socialLogin': switch (payloads.last['purpose']) {
              'link' => {
                'authorizationUrl':
                    'https://auth.example.test/google/callback#callbackState=google-fragment-state',
              },
              'native_metadata' => {
                'metadata': {
                  'oauth': {
                    'authorizationUrl':
                        'https://auth.example.test/google/metadata',
                    'providerState': 'metadata-login-state',
                  },
                },
              },
              _ => {
                'loginUrl':
                    'https://auth.example.test/google?state=google-launch-state',
              },
            },
          },
        },
      },
      '/customer/auth/social/line/login' => {
        'data': {
          'resource': {
            'socialLogin': {
              'loginUrl':
                  'https://auth.example.test/line?state=line-profile-state',
            },
          },
        },
      },
      '/customer/auth/social/apple/login' => {
        'data': {
          'resource': {
            'socialLogin': {
              'url': 'https://auth.example.test/apple/callback',
              'oauthState': 'apple-payload-state',
            },
          },
        },
      },
      '/customer/auth/otp/request' => {
        'resendAfterSeconds': '25',
        'data': {
          'resource': {
            'otpRequest': {
              'details': {'phoneMasked': '08xxxxx678'},
            },
          },
        },
      },
      '/customer/auth/otp/verify' => {
        'result': {
          'resource': {
            'otpVerification': {'otpVerificationToken': 'otp-verify-recursive'},
          },
        },
      },
      '/customer/auth/social/line/callback' => {
        if (payloads.last['state'] == 'line-reset-state')
          'data': {
            'resource': {
              'socialCallback': {
                'provider': 'line_login',
                'resetPassword': {'token': 'line-reset-token-nested'},
              },
            },
          }
        else if (payloads.last['state'] == 'line-profile-state')
          'data': {
            'resource': {
              'customerSession': {
                'accessToken': 'access-line-linked',
                'refreshToken': 'refresh-line-linked',
                'pinRequired': false,
                'customer': {'customerId': 'cus_line_linked'},
              },
              'redirect': '/profile/line-notifications',
              'lineLinked': true,
              'provider': 'line',
            },
          }
        else ...{
          'redirect': '/tickets',
          'data': {
            'resource': {
              'socialCallback': {
                'provider': 'line_oauth',
                'socialLink': {
                  'required': true,
                  'linkToken': 'line-link-return',
                  'profile': {'displayName': 'Line Customer'},
                },
              },
            },
          },
        },
      },
      '/customer/auth/social/google/callback' => {
        'data': {
          'resource': {
            'customerSession': {
              'accessToken': 'access-google-callback',
              'refreshToken': 'refresh-google-callback',
              'pinRequired': false,
              'customer': {'customerId': 'cus_google_callback'},
            },
          },
        },
      },
      '/customer/auth/social/apple/callback' => {
        'data': {
          'resource': {
            'socialCallback': {
              'customerSession': {
                'accessToken': 'access-apple-callback',
                'refreshToken': 'refresh-apple-callback',
                'pinRequired': false,
                'customer': {'customerId': 'cus_apple_callback'},
              },
              'redirectPath': '/tickets',
              'provider': 'apple_login',
            },
          },
        },
      },
      '/customer/auth/social/google/link-phone' => {
        'data': {
          'resource': {
            'customerSession': {
              'accessToken': 'access-linked-social',
              'refreshToken': 'refresh-linked-social',
              'pinRequired': false,
              'customer': {'customerId': 'cus_linked_social'},
            },
          },
        },
      },
      _ => throw StateError('Unexpected auth path: $path'),
    };

    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: response as T,
    );
  }
}

class _MemoryTokenStore extends AuthTokenStore {
  String? _accessToken;
  String? _refreshToken;
  String? _customerId;
  final _socialCallbackAuthModes = <String, bool>{};
  final _socialCallbackRedirects = <String, String>{};
  String? _latestSocialCallbackState;

  @override
  String? get accessToken => _accessToken;

  @override
  String? get refreshToken => _refreshToken;

  @override
  String? get customerId => _customerId;

  @override
  bool get hasAccessToken => _accessToken != null && _accessToken!.isNotEmpty;

  @override
  Future<void> save({
    required String accessToken,
    required String refreshToken,
    String? customerId,
  }) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _customerId = customerId;
  }

  @override
  Future<void> clear() async {
    _accessToken = null;
    _refreshToken = null;
    _customerId = null;
    _socialCallbackAuthModes.clear();
    _socialCallbackRedirects.clear();
    _latestSocialCallbackState = null;
  }

  @override
  Future<void> rememberSocialCallbackContext({
    required String state,
    required bool auth,
    required String redirect,
  }) async {
    final key = state.trim();
    if (key.isEmpty) return;
    _socialCallbackAuthModes[key] = auth;
    _socialCallbackRedirects[key] = redirect.trim();
    _latestSocialCallbackState = key;
  }

  @override
  Future<void> rememberSocialCallbackAuthMode({
    required String state,
    required bool auth,
  }) async {
    final key = state.trim();
    if (key.isNotEmpty) _socialCallbackAuthModes[key] = auth;
  }

  @override
  Future<bool?> readSocialCallbackAuthMode(String state) async {
    return _socialCallbackAuthModes[state.trim()];
  }

  @override
  Future<bool?> takeSocialCallbackAuthMode(String state) async {
    return _socialCallbackAuthModes.remove(state.trim());
  }

  @override
  Future<SocialCallbackContext?> readSocialCallbackContext(String state) async {
    final key = state.trim();
    final auth = _socialCallbackAuthModes[key];
    final hasRedirect = _socialCallbackRedirects.containsKey(key);
    if (auth == null && !hasRedirect) return null;
    return SocialCallbackContext(
      state: key,
      auth: auth ?? true,
      redirect: _socialCallbackRedirects[key] ?? '',
    );
  }

  @override
  Future<SocialCallbackContext?> takeSocialCallbackContext(String state) async {
    final key = state.trim();
    final context = await readSocialCallbackContext(key);
    if (context == null) return null;
    _socialCallbackAuthModes.remove(key);
    _socialCallbackRedirects.remove(key);
    if (_latestSocialCallbackState == key) {
      _latestSocialCallbackState = _socialCallbackRedirects.isEmpty
          ? null
          : _socialCallbackRedirects.keys.last;
    }
    return context;
  }

  @override
  Future<SocialCallbackContext?> takeLatestSocialCallbackContext() async {
    final state = _latestSocialCallbackState?.trim() ?? '';
    if (state.isEmpty) return null;
    return takeSocialCallbackContext(state);
  }
}
