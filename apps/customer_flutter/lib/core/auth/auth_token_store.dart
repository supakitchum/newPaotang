import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final authTokenStoreProvider = Provider<AuthTokenStore>(
  (_) => AuthTokenStore(),
);

class AuthTokenStore {
  static const _accessKey = 'customer_access_token';
  static const _refreshKey = 'customer_refresh_token';
  static const _customerIdKey = 'customer_id';

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  String? _accessToken;
  String? _refreshToken;
  String? _customerId;

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
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
    await _storage.delete(key: _customerIdKey);
  }
}
