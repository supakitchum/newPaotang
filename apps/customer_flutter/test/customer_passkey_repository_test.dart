import 'package:customer_flutter/core/auth/auth_token_store.dart';
import 'package:customer_flutter/core/auth/customer_passkey_repository.dart';
import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/network/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('challenge rejects an RP ID outside the active tenant host', () {
    expect(
      () => CustomerPasskeyChallenge.fromJson(
        const {
          'challenge_id': 'challenge-1',
          'rp_id': 'other.example.test',
          'options': {
            'challenge': 'base64url-challenge',
            'rpId': 'other.example.test',
          },
        },
        registration: false,
        expectedTenantHost: 'passkey.example.test',
      ),
      throwsFormatException,
    );
  });

  test(
    'login verifies the tenant challenge and persists the session',
    () async {
      final api = _PasskeyApiClient();
      final tokens = _MemoryTokenStore();
      final authenticator = _FakePasskeyAuthenticator();
      final repository = CustomerPasskeyRepository(
        api: api,
        tokenStore: tokens,
        authenticator: authenticator,
      );

      final session = await repository.login();

      expect(api.requests, [
        'POST /customer/auth/passkeys/login/options',
        'POST /customer/auth/passkeys/login/verify',
      ]);
      expect(
        authenticator.authenticationOptions?['rpId'],
        'passkey.example.test',
      );
      expect(api.loginCredential, _authenticationCredential);
      expect(api.loginIdempotencyKey, startsWith('customer_passkey_login_'));
      expect(session.sessionId, 'session-passkey');
      expect(session.customerId, 'cus-passkey');
      expect(session.pinRequired, isTrue);
      expect(tokens.accessToken, 'access-passkey');
      expect(tokens.refreshToken, 'refresh-passkey');
      expect(tokens.customerId, 'cus-passkey');
      expect(tokens.sessionId, 'session-passkey');
    },
  );

  test('management lists, registers and revokes tenant passkeys', () async {
    final api = _PasskeyApiClient();
    final authenticator = _FakePasskeyAuthenticator();
    final repository = CustomerPasskeyRepository(
      api: api,
      tokenStore: _MemoryTokenStore(),
      authenticator: authenticator,
    );

    final collection = await repository.list();
    final passkey = await repository.register(name: '  Work iPhone  ');
    await repository.revoke('passkey-2');

    expect(collection.enabled, isTrue);
    expect(collection.canRegister, isTrue);
    expect(collection.relyingPartyId, 'passkey.example.test');
    expect(collection.maxPasskeys, 5);
    expect(collection.items.single.name, 'Personal iPhone');
    expect(collection.items.single.isActive, isTrue);
    expect(authenticator.registrationOptions?['rp'], {
      'id': 'passkey.example.test',
      'name': 'Tenant Lottery',
    });
    expect(api.registrationCredential, _registrationCredential);
    expect(api.registrationName, 'Work iPhone');
    expect(
      api.registrationIdempotencyKey,
      startsWith('customer_passkey_register_'),
    );
    expect(passkey.id, 'passkey-2');
    expect(passkey.name, 'Work iPhone');
    expect(api.revokedPath, '/customer/auth/passkeys/passkey-2');
  });
}

const _authenticationCredential = <String, dynamic>{
  'id': 'credential-auth',
  'rawId': 'credential-auth',
  'type': 'public-key',
  'response': {
    'clientDataJSON': 'client-data',
    'authenticatorData': 'authenticator-data',
    'signature': 'signature',
    'userHandle': 'customer-handle',
  },
};

const _registrationCredential = <String, dynamic>{
  'id': 'credential-register',
  'rawId': 'credential-register',
  'type': 'public-key',
  'response': {
    'clientDataJSON': 'client-data',
    'attestationObject': 'attestation-object',
  },
};

class _FakePasskeyAuthenticator implements CustomerPasskeyAuthenticator {
  Map<String, dynamic>? authenticationOptions;
  Map<String, dynamic>? registrationOptions;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<Map<String, dynamic>> authenticate(
    Map<String, dynamic> options,
  ) async {
    authenticationOptions = Map<String, dynamic>.from(options);
    return _authenticationCredential;
  }

  @override
  Future<Map<String, dynamic>> register(Map<String, dynamic> options) async {
    registrationOptions = Map<String, dynamic>.from(options);
    return _registrationCredential;
  }
}

class _PasskeyApiClient extends ApiClient {
  _PasskeyApiClient()
    : super(
        const AppConfig(
          apiBaseUrl: 'https://api.example.test/api/v1',
          defaultLocale: 'th-TH',
          tenantHost: 'passkey.example.test',
        ),
        AuthTokenStore(),
        localeTag: 'th-TH',
      );

  final requests = <String>[];
  Map<String, dynamic>? loginCredential;
  String loginIdempotencyKey = '';
  Map<String, dynamic>? registrationCredential;
  String registrationName = '';
  String registrationIdempotencyKey = '';
  String revokedPath = '';

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? query,
    bool auth = true,
  }) async {
    requests.add('GET $path');
    return _response<T>(path, {
      'data': [
        {
          'id': 'passkey-1',
          'name': 'Personal iPhone',
          'authenticator': 'iCloud Keychain',
          'status': 'active',
          'registered_at': '2026-07-30T08:00:00+07:00',
        },
      ],
      'enabled': true,
      'can_register': true,
      'rp_id': 'passkey.example.test',
      'max_passkeys': 5,
    });
  }

  @override
  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    bool auth = true,
  }) async {
    requests.add('POST $path');
    if (path.endsWith('/login/options')) {
      expect(auth, isFalse);
      return _response<T>(path, {
        'challenge_id': 'challenge-login',
        'rp_id': 'passkey.example.test',
        'options': {
          'challenge': 'login-challenge',
          'rpId': 'passkey.example.test',
          'userVerification': 'required',
        },
      });
    }
    if (path.endsWith('/register/options')) {
      expect(auth, isTrue);
      return _response<T>(path, {
        'challenge_id': 'challenge-register',
        'rp_id': 'passkey.example.test',
        'options': {
          'challenge': 'register-challenge',
          'rp': {'id': 'passkey.example.test', 'name': 'Tenant Lottery'},
          'user': {
            'id': 'customer-handle',
            'name': '0812345678',
            'displayName': 'Demo Customer',
          },
        },
      });
    }
    throw StateError('Unexpected POST path: $path');
  }

  @override
  Future<Response<T>> postWithHeaders<T>(
    String path, {
    Object? data,
    bool auth = true,
    Map<String, String> headers = const {},
  }) async {
    requests.add('POST $path');
    final payload = Map<String, dynamic>.from(data as Map);
    if (path.endsWith('/login/verify')) {
      expect(auth, isFalse);
      expect(payload['challenge_id'], 'challenge-login');
      loginCredential = Map<String, dynamic>.from(payload['credential'] as Map);
      loginIdempotencyKey = headers['Idempotency-Key'] ?? '';
      return _response<T>(path, {
        'session_id': 'session-passkey',
        'access_token': 'access-passkey',
        'refresh_token': 'refresh-passkey',
        'pin_required': true,
        'pin_setup_required': false,
        'passkey_login': true,
        'user': {'id': 'cus-passkey'},
      });
    }
    if (path == '/customer/auth/passkeys') {
      expect(auth, isTrue);
      expect(payload['challenge_id'], 'challenge-register');
      registrationCredential = Map<String, dynamic>.from(
        payload['credential'] as Map,
      );
      registrationName = payload['name']?.toString() ?? '';
      registrationIdempotencyKey = headers['Idempotency-Key'] ?? '';
      return _response<T>(path, {
        'data': {
          'id': 'passkey-2',
          'name': registrationName,
          'authenticator': 'Android Credential Manager',
          'status': 'active',
          'registered_at': '2026-07-30T09:00:00+07:00',
        },
      });
    }
    throw StateError('Unexpected POST path: $path');
  }

  @override
  Future<Response<T>> deleteWithHeaders<T>(
    String path, {
    Object? data,
    bool auth = true,
    Map<String, String> headers = const {},
  }) async {
    requests.add('DELETE $path');
    revokedPath = path;
    return _response<T>(path, {
      'data': {'id': 'passkey-2', 'revoked': true},
    });
  }

  Response<T> _response<T>(String path, Map<String, dynamic> data) {
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: data as T,
    );
  }
}

class _MemoryTokenStore extends AuthTokenStore {
  @override
  String? accessToken;

  @override
  String? refreshToken;

  @override
  String? customerId;

  @override
  String? sessionId;

  @override
  Future<void> save({
    required String accessToken,
    required String refreshToken,
    String? customerId,
  }) async {
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
    this.customerId = customerId;
  }

  @override
  Future<void> saveSessionId(String? sessionId) async {
    this.sessionId = sessionId;
  }
}
