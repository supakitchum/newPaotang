import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:passkeys/authenticator.dart';
import 'package:passkeys/types.dart';

import '../network/api_client.dart';
import '../tenant/mobile_bootstrap_controller.dart';
import '../tenant/mobile_runtime_policy.dart';
import '../utils/api_payload.dart';
import '../utils/idempotency_key.dart';
import 'auth_repository.dart';
import 'auth_token_store.dart';

final customerPasskeyAuthenticatorProvider =
    Provider<CustomerPasskeyAuthenticator>((_) {
      return PluginCustomerPasskeyAuthenticator();
    });

final customerPasskeyRepositoryProvider = Provider<CustomerPasskeyRepository>((
  ref,
) {
  return CustomerPasskeyRepository(
    api: ref.watch(apiClientProvider),
    tokenStore: ref.watch(authTokenStoreProvider),
    authenticator: ref.watch(customerPasskeyAuthenticatorProvider),
  );
});

final customerPasskeyAvailabilityProvider = FutureProvider<bool>((ref) async {
  final bootstrap = await ref.watch(mobileBootstrapProvider.future);
  final platform = ref.watch(customerPlatformKeyProvider);
  if (!bootstrap.passkeys.enabled ||
      !bootstrap.featureFlags.enabled('passkey_login', fallback: true) ||
      !bootstrap.passkeys.supportsPlatform(platform)) {
    return false;
  }

  return ref.watch(customerPasskeyRepositoryProvider).isAvailable();
});

final customerPasskeysProvider =
    FutureProvider.autoDispose<CustomerPasskeyCollection>((ref) {
      return ref.watch(customerPasskeyRepositoryProvider).list();
    });

abstract interface class CustomerPasskeyAuthenticator {
  Future<bool> isAvailable();

  Future<Map<String, dynamic>> authenticate(Map<String, dynamic> options);

  Future<Map<String, dynamic>> register(Map<String, dynamic> options);
}

class PluginCustomerPasskeyAuthenticator
    implements CustomerPasskeyAuthenticator {
  PluginCustomerPasskeyAuthenticator({PasskeyAuthenticator? authenticator})
    : _authenticator = authenticator ?? PasskeyAuthenticator();

  final PasskeyAuthenticator _authenticator;

  @override
  Future<bool> isAvailable() async {
    try {
      if (kIsWeb) {
        return (await _authenticator.getAvailability().web()).hasPasskeySupport;
      }

      return switch (defaultTargetPlatform) {
        TargetPlatform.android =>
          (await _authenticator.getAvailability().android()).hasPasskeySupport,
        TargetPlatform.iOS =>
          (await _authenticator.getAvailability().iOS()).hasPasskeySupport,
        _ => false,
      };
    } catch (_) {
      return false;
    }
  }

  @override
  Future<Map<String, dynamic>> authenticate(
    Map<String, dynamic> options,
  ) async {
    final request = AuthenticateRequestType.fromJson(
      options,
      mediation: MediationType.Optional,
      preferImmediatelyAvailableCredentials: false,
    );
    final credential = await _authenticator.authenticate(request);
    return credential.toJson();
  }

  @override
  Future<Map<String, dynamic>> register(Map<String, dynamic> options) async {
    final request = RegisterRequestType.fromJson(options);
    final credential = await _authenticator.register(request);
    return credential.toJson();
  }
}

class CustomerPasskeyRepository {
  CustomerPasskeyRepository({
    required ApiClient api,
    required AuthTokenStore tokenStore,
    required CustomerPasskeyAuthenticator authenticator,
  }) : _api = api,
       _tokenStore = tokenStore,
       _authenticator = authenticator;

  final ApiClient _api;
  final AuthTokenStore _tokenStore;
  final CustomerPasskeyAuthenticator _authenticator;

  Future<bool> isAvailable() => _authenticator.isAvailable();

  Future<CustomerSession> login() async {
    final challengeResponse = await _api.post<Map<String, dynamic>>(
      '/customer/auth/passkeys/login/options',
      auth: false,
      data: const {},
    );
    final challenge = CustomerPasskeyChallenge.fromJson(
      asMap(challengeResponse.data),
      registration: false,
      expectedTenantHost: _api.currentTenantHost,
    );
    final credential = await _authenticator.authenticate(challenge.options);
    final response = await _api.postWithHeaders<Map<String, dynamic>>(
      '/customer/auth/passkeys/login/verify',
      auth: false,
      headers: {'Idempotency-Key': newIdempotencyKey('customer_passkey_login')},
      data: {'challenge_id': challenge.id, 'credential': credential},
    );
    final session = CustomerSession.fromJson(asMap(response.data));
    await _saveSession(session);
    return session;
  }

  Future<CustomerPasskeyCollection> list() async {
    final response = await _api.get<Map<String, dynamic>>(
      '/customer/auth/passkeys',
    );
    return CustomerPasskeyCollection.fromJson(asMap(response.data));
  }

  Future<CustomerPasskey> register({required String name}) async {
    final challengeResponse = await _api.post<Map<String, dynamic>>(
      '/customer/auth/passkeys/register/options',
      data: const {},
    );
    final challenge = CustomerPasskeyChallenge.fromJson(
      asMap(challengeResponse.data),
      registration: true,
      expectedTenantHost: _api.currentTenantHost,
    );
    final credential = await _authenticator.register(challenge.options);
    final response = await _api.postWithHeaders<Map<String, dynamic>>(
      '/customer/auth/passkeys',
      headers: {
        'Idempotency-Key': newIdempotencyKey('customer_passkey_register'),
      },
      data: {
        'challenge_id': challenge.id,
        'credential': credential,
        'name': name.trim(),
      },
    );
    return CustomerPasskey.fromJson(asMap(asMap(response.data)['data']));
  }

  Future<void> revoke(String id) async {
    final normalized = id.trim();
    if (normalized.isEmpty) {
      throw const FormatException('Passkey ID is required.');
    }
    await _api.deleteWithHeaders<Map<String, dynamic>>(
      '/customer/auth/passkeys/${Uri.encodeComponent(normalized)}',
    );
  }

  Future<void> _saveSession(CustomerSession session) async {
    if (session.accessToken.isEmpty || session.refreshToken.isEmpty) {
      throw const FormatException('Passkey login response is incomplete.');
    }
    await _tokenStore.save(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
      customerId: session.customerId,
    );
    await _tokenStore.saveSessionId(session.sessionId);
  }
}

class CustomerPasskeyChallenge {
  const CustomerPasskeyChallenge({
    required this.id,
    required this.relyingPartyId,
    required this.options,
  });

  factory CustomerPasskeyChallenge.fromJson(
    Map<String, dynamic> json, {
    required bool registration,
    String expectedTenantHost = '',
  }) {
    final payload = _passkeyPayload(json);
    final options = asMap(payload['options']);
    final id = _passkeyText(payload['challenge_id'] ?? payload['challengeId']);
    final relyingPartyId = _passkeyText(
      payload['rp_id'] ?? payload['rpId'],
    ).toLowerCase();
    final optionsRpId = registration
        ? _passkeyText(asMap(options['rp'])['id']).toLowerCase()
        : _passkeyText(options['rpId']).toLowerCase();
    final challenge = _passkeyText(options['challenge']);
    final expected = expectedTenantHost.trim().toLowerCase();

    if (id.isEmpty ||
        challenge.isEmpty ||
        relyingPartyId.isEmpty ||
        optionsRpId != relyingPartyId ||
        (expected.isNotEmpty && expected != relyingPartyId)) {
      throw const FormatException('Passkey challenge is invalid.');
    }

    return CustomerPasskeyChallenge(
      id: id,
      relyingPartyId: relyingPartyId,
      options: options,
    );
  }

  final String id;
  final String relyingPartyId;
  final Map<String, dynamic> options;
}

class CustomerPasskeyCollection {
  const CustomerPasskeyCollection({
    required this.items,
    required this.enabled,
    required this.canRegister,
    required this.relyingPartyId,
    required this.maxPasskeys,
  });

  factory CustomerPasskeyCollection.fromJson(Map<String, dynamic> json) {
    final payload = _passkeyPayload(json);
    final rows = payload['data'];
    return CustomerPasskeyCollection(
      items: rows is List
          ? rows
                .whereType<Map>()
                .map(
                  (row) => CustomerPasskey.fromJson(
                    row.map((key, value) => MapEntry(key.toString(), value)),
                  ),
                )
                .where((passkey) => passkey.id.isNotEmpty)
                .toList(growable: false)
          : const [],
      enabled: _passkeyBool(payload['enabled']),
      canRegister: _passkeyBool(
        payload['can_register'] ?? payload['canRegister'],
      ),
      relyingPartyId: _passkeyText(payload['rp_id'] ?? payload['rpId']),
      maxPasskeys:
          _passkeyInt(payload['max_passkeys'] ?? payload['maxPasskeys']) ?? 10,
    );
  }

  final List<CustomerPasskey> items;
  final bool enabled;
  final bool canRegister;
  final String relyingPartyId;
  final int maxPasskeys;
}

class CustomerPasskey {
  const CustomerPasskey({
    required this.id,
    required this.name,
    required this.authenticator,
    required this.status,
    required this.registeredAt,
    required this.lastUsedAt,
    required this.revokedAt,
  });

  factory CustomerPasskey.fromJson(Map<String, dynamic> json) {
    final payload = _passkeyPayload(json);
    return CustomerPasskey(
      id: _passkeyText(payload['id']),
      name: _passkeyText(payload['name']),
      authenticator: _passkeyText(payload['authenticator']),
      status: _passkeyText(payload['status']),
      registeredAt: _passkeyDate(
        payload['registered_at'] ?? payload['registeredAt'],
      ),
      lastUsedAt: _passkeyDate(
        payload['last_used_at'] ?? payload['lastUsedAt'],
      ),
      revokedAt: _passkeyDate(payload['revoked_at'] ?? payload['revokedAt']),
    );
  }

  final String id;
  final String name;
  final String authenticator;
  final String status;
  final DateTime? registeredAt;
  final DateTime? lastUsedAt;
  final DateTime? revokedAt;

  bool get isActive => status.toLowerCase() == 'active' && revokedAt == null;
}

Map<String, dynamic> _passkeyPayload(Map<String, dynamic> json) {
  var current = Map<String, dynamic>.from(json);
  for (var depth = 0; depth < 4; depth++) {
    final nested =
        current['resource'] ?? current['passkey'] ?? current['result'];
    if (nested is! Map) break;
    current = nested.map((key, value) => MapEntry(key.toString(), value));
  }
  return current;
}

String _passkeyText(Object? value) => value?.toString().trim() ?? '';

bool _passkeyBool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  return const {
    '1',
    'true',
    'yes',
    'on',
    'enabled',
    'active',
  }.contains(_passkeyText(value).toLowerCase());
}

int? _passkeyInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(_passkeyText(value));
}

DateTime? _passkeyDate(Object? value) {
  final text = _passkeyText(value);
  return text.isEmpty ? null : DateTime.tryParse(text)?.toLocal();
}
