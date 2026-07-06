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
    expect(tokenStore.accessToken, 'access-recursive-login');
    expect(tokenStore.refreshToken, 'refresh-recursive-login');
    expect(tokenStore.customerId, 'cus_recursive_login');
  });

  test('socialLoginUrl saves unauthenticated callback mode for login flows',
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
      query: {
        'code': 'callback-code',
        'state': 'google-launch-state',
      },
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
  });

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
      password: 'secret1234',
      passwordConfirmation: 'secret1234',
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
      'password': 'secret1234',
      'password_confirmation': 'secret1234',
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
      query: {
        'code': 'callback-code',
        'state': 'line-profile-state',
      },
    );

    expect(url, 'https://auth.example.test/line?state=line-profile-state');
    expect(api.paths, [
      '/customer/auth/social/line/login',
      '/customer/auth/social/line/callback',
    ]);
    expect(api.authFlags, [false, true]);
    expect(callback.session?.accessToken, 'access-line-linked');
    expect(callback.redirectPath, '/profile/line-notifications');
  });

  test('social callback auth mode accepts callbackState aliases', () async {
    final tokenStore = _MemoryTokenStore();
    final api = _AuthApiClient(tokenStore);
    final repository = AuthRepository(api: api, tokenStore: tokenStore);

    final url = await repository.socialLoginUrl(
      'google',
      purpose: 'profile_link',
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
    expect(api.authFlags, [false, true]);
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

  test('social launch and callback accept metadata OAuth wrapper aliases',
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
  });

  test('social launch remembers payload state and hyphen provider aliases',
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
      query: {
        'code': 'apple-code',
        'state': 'apple-payload-state',
      },
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
  });

  test('social callback accepts nested password reset resources', () async {
    final tokenStore = _MemoryTokenStore();
    final api = _AuthApiClient(tokenStore);
    final repository = AuthRepository(api: api, tokenStore: tokenStore);

    final callback = await repository.socialCallback(
      provider: 'line-login',
      query: {
        'code': 'reset-code',
        'state': 'line-reset-state',
      },
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
  final authFlags = <bool>[];
  final payloads = <Map<String, dynamic>>[];

  @override
  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    bool auth = true,
  }) async {
    paths.add(path);
    authFlags.add(auth);
    payloads.add(Map<String, dynamic>.from(data! as Map));

    final response = switch (path) {
      '/customer/auth/login' => {
          'pinRequired': true,
          'data': {
            'resource': {
              'customerSession': {
                'accessToken': 'access-recursive-login',
                'refreshToken': 'refresh-recursive-login',
                'customer': {'customerId': 'cus_recursive_login'},
              },
            },
          },
        },
      '/customer/auth/social/google/login' => {
          'data': {
            'resource': {
              'socialLogin': switch (payloads.last['purpose']) {
                'profile_link' => {
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
                'details': {
                  'phoneMasked': '08xxxxx678',
                },
              },
            },
          },
        },
      '/customer/auth/otp/verify' => {
          'result': {
            'resource': {
              'otpVerification': {
                'otpVerificationToken': 'otp-verify-recursive',
              },
            },
          },
        },
      '/customer/auth/social/line/callback' => {
          if (payloads.last['state'] == 'line-reset-state')
            'data': {
              'resource': {
                'socialCallback': {
                  'provider': 'line_login',
                  'resetPassword': {
                    'token': 'line-reset-token-nested',
                  },
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
  Future<bool?> takeSocialCallbackAuthMode(String state) async {
    return _socialCallbackAuthModes.remove(state.trim());
  }
}
