import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../tenant/customer_tenant_host.dart';

final authTokenStoreProvider = Provider<AuthTokenStore>(
  (_) => AuthTokenStore(),
);

class SocialCallbackContext {
  const SocialCallbackContext({
    required this.state,
    required this.auth,
    required this.redirect,
  });

  final String state;
  final bool auth;
  final String redirect;
}

class AuthTokenStore {
  AuthTokenStore({String storageScope = ''})
    : _storageScope = customerTenantStorageScope(storageScope);

  static const _accessKey = 'customer_access_token';
  static const _refreshKey = 'customer_refresh_token';
  static const _customerIdKey = 'customer_id';
  static const _sessionIdKey = 'customer_session_id';
  static const _socialCallbackAuthStatesKey =
      'customer_social_callback_auth_states';
  static const _socialCallbackRedirectStatesKey =
      'customer_social_callback_redirect_states';

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(migrateWithBackup: true),
  );
  final String _storageScope;

  String? _accessToken;
  String? _refreshToken;
  String? _customerId;
  String? _sessionId;
  final _socialCallbackAuthStates = <String, bool>{};
  final _socialCallbackRedirectStates = <String, String>{};
  String? _latestSocialCallbackState;

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  String? get customerId => _customerId;
  String? get sessionId => _sessionId;
  bool get hasAccessToken =>
      accessToken != null && accessToken!.trim().isNotEmpty;
  bool get hasRefreshToken =>
      refreshToken != null && refreshToken!.trim().isNotEmpty;
  bool get hasSessionCredential => hasAccessToken || hasRefreshToken;

  Future<void> restore() async {
    // Restore each credential independently. A damaged optional customer-id
    // entry must not discard a usable refresh token and force a fresh login.
    _accessToken = await _readCredential(_key(_accessKey));
    _refreshToken = await _readCredential(_key(_refreshKey));
    _customerId = await _readCredential(_key(_customerIdKey));
    _sessionId = await _readCredential(_key(_sessionIdKey));
    if (_storageScope.isNotEmpty && !hasSessionCredential) {
      await _restoreLegacyCredentials();
    }
    await _restoreSocialCallbackAuthStates();
    await _restoreSocialCallbackRedirectStates();
  }

  Future<void> save({
    required String accessToken,
    required String refreshToken,
    String? customerId,
  }) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _customerId = customerId?.trim();
    // Persist the recovery credential first. If a later write is interrupted,
    // startup can still rotate the refresh token into a new access token.
    await _storage.write(key: _key(_refreshKey), value: refreshToken);
    if (_customerId == null || _customerId!.isEmpty) {
      await _storage.delete(key: _key(_customerIdKey));
    } else {
      await _storage.write(key: _key(_customerIdKey), value: _customerId);
    }
    await _storage.write(key: _key(_accessKey), value: accessToken);
  }

  Future<void> saveSessionId(String? sessionId) async {
    _sessionId = sessionId?.trim();
    try {
      if (_sessionId == null || _sessionId!.isEmpty) {
        await _storage.delete(key: _key(_sessionIdKey));
        return;
      }
      await _storage.write(key: _key(_sessionIdKey), value: _sessionId);
    } catch (_) {
      // The in-memory id still protects the active runtime from a late event.
    }
  }

  Future<void> clear() async {
    _accessToken = null;
    _refreshToken = null;
    _customerId = null;
    _sessionId = null;
    _socialCallbackAuthStates.clear();
    _socialCallbackRedirectStates.clear();
    _latestSocialCallbackState = null;
    for (final key in _sessionStorageKeys(includeLegacy: true)) {
      await _storage.delete(key: key);
    }
  }

  Future<void> rememberSocialCallbackContext({
    required String state,
    required bool auth,
    required String redirect,
  }) async {
    final key = state.trim();
    if (key.isEmpty) return;
    await rememberSocialCallbackAuthMode(state: key, auth: auth);
    _socialCallbackRedirectStates[key] = redirect.trim();
    _latestSocialCallbackState = key;
    await _persistSocialCallbackRedirectStates();
  }

  Future<void> rememberSocialCallbackAuthMode({
    required String state,
    required bool auth,
  }) async {
    final key = state.trim();
    if (key.isEmpty) return;
    _socialCallbackAuthStates[key] = auth;
    await _persistSocialCallbackAuthStates();
  }

  Future<bool?> readSocialCallbackAuthMode(String state) async {
    final key = state.trim();
    if (key.isEmpty) return null;
    if (_socialCallbackAuthStates.isEmpty) {
      await _restoreSocialCallbackAuthStates();
    }
    return _socialCallbackAuthStates[key];
  }

  Future<bool?> takeSocialCallbackAuthMode(String state) async {
    final key = state.trim();
    if (key.isEmpty) return null;
    if (_socialCallbackAuthStates.isEmpty) {
      await _restoreSocialCallbackAuthStates();
    }
    final auth = _socialCallbackAuthStates.remove(key);
    if (auth != null) {
      await _persistSocialCallbackAuthStates();
    }
    return auth;
  }

  Future<SocialCallbackContext?> readSocialCallbackContext(String state) async {
    final key = state.trim();
    if (key.isEmpty) return null;
    if (_socialCallbackRedirectStates.isEmpty &&
        _latestSocialCallbackState == null) {
      await _restoreSocialCallbackRedirectStates();
    }
    final auth = await readSocialCallbackAuthMode(key);
    final hasRedirect = _socialCallbackRedirectStates.containsKey(key);
    if (auth == null && !hasRedirect) return null;
    return SocialCallbackContext(
      state: key,
      auth: auth ?? true,
      redirect: _socialCallbackRedirectStates[key] ?? '',
    );
  }

  Future<SocialCallbackContext?> takeSocialCallbackContext(String state) async {
    final key = state.trim();
    final context = await readSocialCallbackContext(key);
    if (context == null) return null;
    await takeSocialCallbackAuthMode(key);
    _socialCallbackRedirectStates.remove(key);
    if (_latestSocialCallbackState == key) {
      _latestSocialCallbackState = _socialCallbackRedirectStates.isEmpty
          ? null
          : _socialCallbackRedirectStates.keys.last;
    }
    await _persistSocialCallbackRedirectStates();
    return context;
  }

  Future<SocialCallbackContext?> takeLatestSocialCallbackContext() async {
    if (_latestSocialCallbackState == null) {
      await _restoreSocialCallbackRedirectStates();
    }
    final state = _latestSocialCallbackState?.trim() ?? '';
    if (state.isEmpty) return null;
    return takeSocialCallbackContext(state);
  }

  Future<void> _restoreSocialCallbackAuthStates() async {
    try {
      final encoded = await _readScopedOrLegacy(_socialCallbackAuthStatesKey);
      if (encoded == null || encoded.trim().isEmpty) {
        _socialCallbackAuthStates.clear();
        return;
      }
      final decoded = jsonDecode(encoded);
      _socialCallbackAuthStates.clear();
      if (decoded is Map) {
        for (final entry in decoded.entries) {
          final state = entry.key.toString().trim();
          if (state.isEmpty) continue;
          final value = entry.value;
          if (value is bool) {
            _socialCallbackAuthStates[state] = value;
          } else if (value is String) {
            _socialCallbackAuthStates[state] =
                value.trim().toLowerCase() == 'true';
          }
        }
      }
    } catch (_) {
      _socialCallbackAuthStates.clear();
    }
  }

  Future<void> _persistSocialCallbackAuthStates() async {
    try {
      if (_socialCallbackAuthStates.isEmpty) {
        await _storage.delete(key: _key(_socialCallbackAuthStatesKey));
        return;
      }
      await _storage.write(
        key: _key(_socialCallbackAuthStatesKey),
        value: jsonEncode(_socialCallbackAuthStates),
      );
    } catch (_) {
      // Pending OAuth state is a safety hint; storage failures should not block
      // auth or profile-link flows.
    }
  }

  Future<void> _restoreSocialCallbackRedirectStates() async {
    try {
      final encoded = await _readScopedOrLegacy(
        _socialCallbackRedirectStatesKey,
      );
      _socialCallbackRedirectStates.clear();
      _latestSocialCallbackState = null;
      if (encoded == null || encoded.trim().isEmpty) return;
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) return;
      final redirects = decoded['redirects'];
      if (redirects is Map) {
        for (final entry in redirects.entries) {
          final state = entry.key.toString().trim();
          if (state.isEmpty) continue;
          _socialCallbackRedirectStates[state] =
              entry.value?.toString().trim() ?? '';
        }
      }
      final latestState = decoded['latest_state']?.toString().trim() ?? '';
      if (latestState.isNotEmpty &&
          _socialCallbackRedirectStates.containsKey(latestState)) {
        _latestSocialCallbackState = latestState;
      } else {
        _latestSocialCallbackState = _socialCallbackRedirectStates.isEmpty
            ? null
            : _socialCallbackRedirectStates.keys.last;
      }
    } catch (_) {
      _socialCallbackRedirectStates.clear();
      _latestSocialCallbackState = null;
    }
  }

  Future<void> _persistSocialCallbackRedirectStates() async {
    try {
      if (_socialCallbackRedirectStates.isEmpty) {
        await _storage.delete(key: _key(_socialCallbackRedirectStatesKey));
        return;
      }
      await _storage.write(
        key: _key(_socialCallbackRedirectStatesKey),
        value: jsonEncode({
          'latest_state': _latestSocialCallbackState,
          'redirects': _socialCallbackRedirectStates,
        }),
      );
    } catch (_) {
      // Pending OAuth redirect storage must not block authentication.
    }
  }

  Future<String?> _readCredential(String key) async {
    try {
      final value = await _storage.read(key: key);
      final normalized = value?.trim() ?? '';
      return normalized.isEmpty ? null : normalized;
    } catch (_) {
      return null;
    }
  }

  Future<void> _restoreLegacyCredentials() async {
    final legacyAccessToken = await _readCredential(_accessKey);
    final legacyRefreshToken = await _readCredential(_refreshKey);
    if ((legacyAccessToken == null || legacyAccessToken.isEmpty) &&
        (legacyRefreshToken == null || legacyRefreshToken.isEmpty)) {
      return;
    }

    final legacyCustomerId = await _readCredential(_customerIdKey);
    final legacySessionId = await _readCredential(_sessionIdKey);
    _accessToken = legacyAccessToken;
    _refreshToken = legacyRefreshToken;
    _customerId = legacyCustomerId;
    _sessionId = legacySessionId;

    try {
      if (_refreshToken != null) {
        await _storage.write(key: _key(_refreshKey), value: _refreshToken);
      }
      if (_customerId != null) {
        await _storage.write(key: _key(_customerIdKey), value: _customerId);
      }
      if (_sessionId != null) {
        await _storage.write(key: _key(_sessionIdKey), value: _sessionId);
      }
      if (_accessToken != null) {
        await _storage.write(key: _key(_accessKey), value: _accessToken);
      }
      await _storage.delete(key: _accessKey);
      await _storage.delete(key: _refreshKey);
      await _storage.delete(key: _customerIdKey);
      await _storage.delete(key: _sessionIdKey);
    } catch (_) {
      // Keep the in-memory legacy session. A later startup can retry migration.
    }
  }

  Future<String?> _readScopedOrLegacy(String baseKey) async {
    final scoped = await _readCredential(_key(baseKey));
    if (scoped != null || _storageScope.isEmpty) return scoped;
    final legacy = await _readCredential(baseKey);
    if (legacy == null) return null;
    try {
      await _storage.write(key: _key(baseKey), value: legacy);
      await _storage.delete(key: baseKey);
    } catch (_) {
      // Keep reading the legacy callback state until migration can succeed.
    }
    return legacy;
  }

  Iterable<String> _sessionStorageKeys({required bool includeLegacy}) sync* {
    for (final baseKey in const [
      _accessKey,
      _refreshKey,
      _customerIdKey,
      _sessionIdKey,
      _socialCallbackAuthStatesKey,
      _socialCallbackRedirectStatesKey,
    ]) {
      yield _key(baseKey);
      if (includeLegacy && _storageScope.isNotEmpty) yield baseKey;
    }
  }

  String _key(String baseKey) {
    if (_storageScope.isEmpty) return baseKey;
    return '${baseKey}_$_storageScope';
  }
}
