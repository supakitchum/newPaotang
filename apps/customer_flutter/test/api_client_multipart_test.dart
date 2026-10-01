import 'dart:convert';
import 'dart:typed_data';

import 'package:customer_flutter/core/auth/auth_token_store.dart';
import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/network/api_client.dart';
import 'package:customer_flutter/features/topup/data/topup_models.dart';
import 'package:customer_flutter/features/topup/data/topup_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('multipart requests clone form data when token refresh retries',
      () async {
    final adapter = _RefreshingMultipartAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final tokenStore = _MemoryAuthTokenStore(
      accessToken: 'expired-access',
      refreshToken: 'refresh-token',
    );
    final api = ApiClient(
      const AppConfig(
        apiBaseUrl: 'https://partner.example.test/api/v1',
        defaultLocale: 'th-TH',
      ),
      tokenStore,
      localeTag: 'th-TH',
      dio: dio,
    );
    final repository = TopupRepository(api);

    final item = await repository.create(
      channel: TopupChannel.bankTransfer,
      amount: 800,
      transferAt: DateTime.parse('2026-06-26T10:15:00+07:00'),
      slip: TopupSlipUpload(
        filename: 'slip.jpg',
        bytes: Uint8List.fromList([1, 2, 3, 4]),
      ),
    );

    expect(item.id, 'topup_1');
    expect(adapter.topupCalls, 2);
    expect(adapter.refreshCalls, 1);
    expect(tokenStore.accessToken, 'fresh-access');
    expect(adapter.authorizationHeaders, [
      'Bearer expired-access',
      'Bearer fresh-access',
    ]);
    expect(adapter.multipartBodyLengths, hasLength(2));
    expect(adapter.multipartBodyLengths.every((length) => length > 0), isTrue);
  });
}

class _RefreshingMultipartAdapter implements HttpClientAdapter {
  int topupCalls = 0;
  int refreshCalls = 0;
  final authorizationHeaders = <String>[];
  final multipartBodyLengths = <int>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    if (path.endsWith('/customer/topups')) {
      topupCalls += 1;
      authorizationHeaders
          .add(options.headers['Authorization']?.toString() ?? '');
      multipartBodyLengths.add(await _drainLength(requestStream));
      if (topupCalls == 1) {
        return _json({'message': 'Unauthenticated'}, 401);
      }
      return _json(
        {
          'data': {
            'result': {
              'id': 'topup_1',
              'amount': {'amount': 80000, 'currency': 'THB'},
              'bonus_amount': {'amount': 0, 'currency': 'THB'},
              'status': 'pending_review',
              'channel': 'bank_transfer',
              'provider': '',
              'created_at': '2026-06-26T10:00:00+07:00',
            },
          },
        },
        201,
      );
    }

    if (path.endsWith('/customer/auth/refresh')) {
      refreshCalls += 1;
      return _json({
        'data': {
          'access_token': 'fresh-access',
          'refresh_token': 'fresh-refresh',
          'customer_id': 'customer_1',
        },
      });
    }

    return _json({'message': 'Not found'}, 404);
  }

  @override
  void close({bool force = false}) {}

  Future<int> _drainLength(Stream<Uint8List>? stream) async {
    if (stream == null) return 0;
    var total = 0;
    await for (final chunk in stream) {
      total += chunk.length;
    }
    return total;
  }

  ResponseBody _json(Map<String, dynamic> body, [int statusCode = 200]) {
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

class _MemoryAuthTokenStore extends AuthTokenStore {
  _MemoryAuthTokenStore({
    required String accessToken,
    required String refreshToken,
  })  : _accessToken = accessToken,
        _refreshToken = refreshToken;

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
  bool get hasAccessToken => (_accessToken ?? '').isNotEmpty;

  @override
  Future<void> restore() async {}

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
