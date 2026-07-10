import 'dart:convert';
import 'dart:typed_data';

import 'package:customer_flutter/core/auth/auth_token_store.dart';
import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/network/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('auth requests refresh expired access token and retry once', () async {
    final tokenStore = _MemoryTokenStore();
    await tokenStore.save(
      accessToken: 'expired-access',
      refreshToken: 'refresh-token',
      customerId: 'cus_1',
    );
    final adapter = _RefreshingAuthAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final api = ApiClient(
      const AppConfig(
        apiBaseUrl: 'https://partner.example.com/api/v1',
        defaultLocale: 'th-TH',
      ),
      tokenStore,
      localeTag: 'th-TH',
      dio: dio,
    );

    final response = await api.post<Map<String, dynamic>>(
      '/customer/auth/pin/verify',
      data: {'pin': '123456'},
    );

    expect(response.data?['ok'], isTrue);
    expect(adapter.paths, [
      'customer/auth/pin/verify',
      'customer/auth/refresh',
      'customer/auth/pin/verify',
    ]);
    expect(adapter.authorizationHeaders, [
      'Bearer expired-access',
      null,
      'Bearer fresh-access',
    ]);
    expect(tokenStore.accessToken, 'fresh-access');
    expect(tokenStore.refreshToken, 'fresh-refresh');
    expect(tokenStore.customerId, 'cus_1');
  });
}

class _RefreshingAuthAdapter implements HttpClientAdapter {
  final paths = <String>[];
  final authorizationHeaders = <String?>[];
  int _pinAttempts = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path.replaceFirst(RegExp(r'^/+'), '');
    paths.add(path);
    authorizationHeaders.add(options.headers['Authorization']?.toString());

    if (path == 'customer/auth/pin/verify') {
      _pinAttempts += 1;
      if (_pinAttempts == 1) {
        return _json(
          401,
          const {
            'code': 'authentication_required',
            'message':
                'Authentication token is missing, invalid, expired, or revoked.',
          },
        );
      }
      return _json(200, const {'ok': true});
    }

    if (path == 'customer/auth/refresh') {
      return _json(
        200,
        const {
          'resource': {
            'token': 'fresh-access',
            'refresh_token': 'fresh-refresh',
            'user': {'id': 'cus_1'},
          },
        },
      );
    }

    return _json(404, {'message': 'Unexpected path $path'});
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int statusCode, Map<String, dynamic> body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

class _MemoryTokenStore extends AuthTokenStore {
  String? _accessToken;
  String? _refreshToken;
  String? _customerId;

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
  }
}
