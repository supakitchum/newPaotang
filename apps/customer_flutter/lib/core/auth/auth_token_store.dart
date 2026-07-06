import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final authTokenStoreProvider = Provider<AuthTokenStore>(
  (_) => AuthTokenStore(),
);

class AuthTokenStore {
  static const _accessKey = 'customer_access_token';
  static const _refreshKey = 'customer_refresh_token';
  static const _customerIdKey = 'customer_id';
  static const _socialCallbackAuthStatesKey =
      'customer_social_callback_auth_states';

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  String? _accessToken;
  String? _refreshToken;
  String? _customerId;
  final _socialCallbackAuthStates = <String, bool>{};

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  String? get customerId => _customerId;
  bool get hasAccessToken => _accessToken != null && _accessToken!.isNotEmpty;

  Future<void> restore() async {
    try {
      _accessToken = await _storage.read(key: _accessKey);
      _refreshToken = await _storage.read(key: _refreshKey);
      _customerId = await _storage.read(key: _customerIdKey);
    } catch (_) {
      _accessToken = null;
      _refreshToken = null;
      _customerId = null;
    }
    await _restoreSocialCallbackAuthStates();
  }

  Future<void> save({
    required String accessToken,
    required String refreshToken,
    String? customerId,
  }) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _customerId = customerId?.trim();
    await _storage.write(key: _accessKey, value: accessToken);
    await _storage.write(key: _refreshKey, value: refreshToken);
    if (_customerId == null || _customerId!.isEmpty) {
      await _storage.delete(key: _customerIdKey);
    } else {
      await _storage.write(key: _customerIdKey, value: _customerId);
    }
  }

  Future<void> clear() async {
    _accessToken = null;
    _refreshToken = null;
    _customerId = null;
    _socialCallbackAuthStates.clear();
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
    await _storage.delete(key: _customerIdKey);
    await _storage.delete(key: _socialCallbackAuthStatesKey);
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

  Future<void> _restoreSocialCallbackAuthStates() async {
    try {
      final encoded = await _storage.read(key: _socialCallbackAuthStatesKey);
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
        await _storage.delete(key: _socialCallbackAuthStatesKey);
        return;
      }
      await _storage.write(
        key: _socialCallbackAuthStatesKey,
        value: jsonEncode(_socialCallbackAuthStates),
      );
    } catch (_) {
      // Pending OAuth state is a safety hint; storage failures should not block
      // auth or profile-link flows.
    }
  }
}
