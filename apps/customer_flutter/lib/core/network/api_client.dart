import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_token_store.dart';
import '../config/app_config.dart';
import '../i18n/app_locale.dart';
import '../i18n/customer_locale_controller.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  final config = ref.watch(appConfigProvider);
  final tokenStore = ref.watch(authTokenStoreProvider);
  final locale = ref.watch(customerLocaleProvider);
  return ApiClient(config, tokenStore, localeTag: localeTag(locale));
});

class ApiClient {
  ApiClient(
    AppConfig config,
    this._tokenStore, {
    required String localeTag,
    Dio? dio,
  })  : _localeTag = localeTag,
        _tenantHost = config.normalizedTenantHost,
        _dio = _configuredDio(config.apiBaseUrl, dio);

  final AuthTokenStore _tokenStore;
  final String _localeTag;
  final String _tenantHost;
  final Dio _dio;
  Future<bool>? _refreshInFlight;

  String get currentLocaleTag => _localeTag;
  String get currentTenantHost => _tenantHost;

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? query,
    bool auth = true,
  }) {
    return _requestWithTokenRefresh<T>(
      path: path,
      auth: auth,
      request: () => _dio.get<T>(
        _path(path),
        queryParameters: query,
        options: Options(headers: _headers(auth: auth)),
      ),
    );
  }

  Future<Response<T>> post<T>(String path, {Object? data, bool auth = true}) {
    return _requestWithTokenRefresh<T>(
      path: path,
      auth: auth,
      request: () => _dio.post<T>(
        _path(path),
        data: data,
        options: Options(headers: _headers(auth: auth)),
      ),
    );
  }

  Future<Response<T>> postWithHeaders<T>(
    String path, {
    Object? data,
    bool auth = true,
    Map<String, String> headers = const {},
  }) {
    return _requestWithTokenRefresh<T>(
      path: path,
      auth: auth,
      request: () => _dio.post<T>(
        _path(path),
        data: data,
        options: Options(headers: {..._headers(auth: auth), ...headers}),
      ),
    );
  }

  Future<Response<T>> patchWithHeaders<T>(
    String path, {
    Object? data,
    bool auth = true,
    Map<String, String> headers = const {},
  }) {
    return _requestWithTokenRefresh<T>(
      path: path,
      auth: auth,
      request: () => _dio.patch<T>(
        _path(path),
        data: data,
        options: Options(headers: {..._headers(auth: auth), ...headers}),
      ),
    );
  }

  Future<Response<T>> postMultipart<T>(
    String path, {
    required FormData data,
    bool auth = true,
    Map<String, String> headers = const {},
  }) {
    return _requestWithTokenRefresh<T>(
      path: path,
      auth: auth,
      request: () => _dio.post<T>(
        _path(path),
        data: data,
        options: Options(headers: {..._headers(auth: auth), ...headers}),
      ),
    );
  }

  Future<Response<T>> deleteWithHeaders<T>(
    String path, {
    Object? data,
    bool auth = true,
    Map<String, String> headers = const {},
  }) {
    return _requestWithTokenRefresh<T>(
      path: path,
      auth: auth,
      request: () => _dio.delete<T>(
        _path(path),
        data: data,
        options: Options(headers: {..._headers(auth: auth), ...headers}),
      ),
    );
  }

  String _path(String path) => path.startsWith('/') ? path.substring(1) : path;

  static String _normalizeBaseUrl(String value) {
    final trimmed = value.trim();
    return trimmed.endsWith('/') ? trimmed : '$trimmed/';
  }

  static Dio _configuredDio(String apiBaseUrl, Dio? dio) {
    final client = dio ?? Dio();
    client.options.baseUrl = _normalizeBaseUrl(apiBaseUrl);
    return client;
  }

  Future<Response<T>> _requestWithTokenRefresh<T>({
    required String path,
    required bool auth,
    required Future<Response<T>> Function() request,
  }) async {
    try {
      return await request();
    } on DioException catch (error) {
      if (!_shouldAttemptTokenRefresh(path: path, auth: auth, error: error)) {
        rethrow;
      }

      final refreshed = await _refreshAccessToken();
      if (!refreshed) rethrow;
      return request();
    }
  }

  bool _shouldAttemptTokenRefresh({
    required String path,
    required bool auth,
    required DioException error,
  }) {
    if (!auth || _isRefreshPath(path)) return false;
    if (error.response?.statusCode != 401) return false;
    final refreshToken = _tokenStore.refreshToken?.trim() ?? '';
    return refreshToken.isNotEmpty;
  }

  bool _isRefreshPath(String path) {
    final normalized = path.startsWith('/') ? path.substring(1) : path;
    return normalized == 'customer/auth/refresh';
  }

  Future<bool> _refreshAccessToken() async {
    final pending = _refreshInFlight;
    if (pending != null) return pending;

    final future = _refreshAccessTokenNow();
    _refreshInFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_refreshInFlight, future)) {
        _refreshInFlight = null;
      }
    }
  }

  Future<bool> _refreshAccessTokenNow() async {
    final currentRefreshToken = _tokenStore.refreshToken?.trim() ?? '';
    if (currentRefreshToken.isEmpty) return false;

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        _path('/customer/auth/refresh'),
        data: {'refresh_token': currentRefreshToken},
        options: Options(headers: _headers(auth: false)),
      );
      final payload = _sessionPayload(_asMap(response.data));
      final user = _asMap(payload['user']);
      final customer = _asMap(payload['customer']);
      final accessToken = _firstString([
        payload['access_token'],
        payload['accessToken'],
        payload['token'],
        payload['jwt'],
        user['access_token'],
        user['accessToken'],
        customer['access_token'],
        customer['accessToken'],
      ]);
      if (accessToken.isEmpty) return false;

      final nextRefreshToken = _firstString([
        payload['refresh_token'],
        payload['refreshToken'],
        user['refresh_token'],
        user['refreshToken'],
        customer['refresh_token'],
        customer['refreshToken'],
      ]);
      final customerId = _firstString([
        payload['customer_id'],
        payload['customerId'],
        payload['id'],
        user['id'],
        user['customer_id'],
        user['customerId'],
        customer['id'],
        customer['customer_id'],
        customer['customerId'],
      ]);
      await _tokenStore.save(
        accessToken: accessToken,
        refreshToken:
            nextRefreshToken.isEmpty ? currentRefreshToken : nextRefreshToken,
        customerId: customerId.isEmpty ? _tokenStore.customerId : customerId,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Map<String, String> _headers({required bool auth}) {
    final token = _tokenStore.accessToken;
    return {
      'Accept': 'application/json',
      'Accept-Language': _localeTag,
      'X-Locale': _localeTag,
      'X-Client-App': 'customer_flutter',
      if (_tenantHost.isNotEmpty) 'X-Tenant-Host': _tenantHost,
      if (_tenantHost.isNotEmpty) 'X-Forwarded-Host': _tenantHost,
      if (auth && token != null && token.isNotEmpty)
        'Authorization': 'Bearer $token',
    };
  }
}

const _sessionWrapperKeys = [
  'session',
  'customer_session',
  'customerSession',
  'auth_session',
  'authSession',
  'auth',
  'resource',
  'data',
  'result',
  'payload',
];

Map<String, dynamic> _sessionPayload(Map<String, dynamic> json) {
  var payload = json;
  for (var depth = 0; depth < 8; depth += 1) {
    Map<String, dynamic>? next;
    for (final key in _sessionWrapperKeys) {
      final value = payload[key];
      if (value is Map) {
        next = _asMap(value);
        break;
      }
    }
    if (next == null || identical(next, payload)) return payload;
    payload = next;
  }
  return payload;
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  return const {};
}

String _firstString(List<Object?> values) {
  for (final value in values) {
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
  }
  return '';
}
