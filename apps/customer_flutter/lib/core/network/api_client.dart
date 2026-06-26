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
  ApiClient(AppConfig config, this._tokenStore, {required String localeTag})
      : _localeTag = localeTag,
        _tenantHost = config.normalizedTenantHost,
        _dio = Dio(BaseOptions(baseUrl: _normalizeBaseUrl(config.apiBaseUrl)));

  final AuthTokenStore _tokenStore;
  final String _localeTag;
  final String _tenantHost;
  final Dio _dio;

  String get currentLocaleTag => _localeTag;
  String get currentTenantHost => _tenantHost;

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? query,
    bool auth = true,
  }) {
    return _dio.get<T>(
      _path(path),
      queryParameters: query,
      options: Options(headers: _headers(auth: auth)),
    );
  }

  Future<Response<T>> post<T>(String path, {Object? data, bool auth = true}) {
    return _dio.post<T>(
      _path(path),
      data: data,
      options: Options(headers: _headers(auth: auth)),
    );
  }

  Future<Response<T>> postWithHeaders<T>(
    String path, {
    Object? data,
    bool auth = true,
    Map<String, String> headers = const {},
  }) {
    return _dio.post<T>(
      _path(path),
      data: data,
      options: Options(headers: {..._headers(auth: auth), ...headers}),
    );
  }

  Future<Response<T>> patchWithHeaders<T>(
    String path, {
    Object? data,
    bool auth = true,
    Map<String, String> headers = const {},
  }) {
    return _dio.patch<T>(
      _path(path),
      data: data,
      options: Options(headers: {..._headers(auth: auth), ...headers}),
    );
  }

  Future<Response<T>> postMultipart<T>(
    String path, {
    required FormData data,
    bool auth = true,
    Map<String, String> headers = const {},
  }) {
    return _dio.post<T>(
      _path(path),
      data: data,
      options: Options(headers: {..._headers(auth: auth), ...headers}),
    );
  }

  Future<Response<T>> deleteWithHeaders<T>(
    String path, {
    Object? data,
    bool auth = true,
    Map<String, String> headers = const {},
  }) {
    return _dio.delete<T>(
      _path(path),
      data: data,
      options: Options(headers: {..._headers(auth: auth), ...headers}),
    );
  }

  String _path(String path) => path.startsWith('/') ? path.substring(1) : path;

  static String _normalizeBaseUrl(String value) {
    final trimmed = value.trim();
    return trimmed.endsWith('/') ? trimmed : '$trimmed/';
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
