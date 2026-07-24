import 'dart:convert';
import 'dart:io';

import 'package:customer_flutter/core/auth/auth_token_store.dart';
import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/network/api_client.dart';
import 'package:customer_flutter/features/support/data/support_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('support realtime binding uses isolated broker configuration', () async {
    final api = _SupportBrokerApiClient();
    final repository = SupportRepository(api, localeResolver: () => 'th-TH');

    final binding = await repository.realtimeBinding('stk_01');

    expect(api.path, '/customer/support-session');
    expect(binding, isNotNull);
    expect(
      binding!.channels,
      containsAll({
        'private-support.tenant.ten_01.customer.cus_01',
        'private-support.tenant.ten_01.ticket.stk_01',
      }),
    );
    await binding.client.dispose();
  });

  test('support close and rating forward caller idempotency keys', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final receivedKeys = <String?>[];
    final subscription = server.listen((request) async {
      receivedKeys.add(request.headers.value('Idempotency-Key'));
      request.response.headers.contentType = ContentType.json;
      if (request.uri.path.endsWith('/close')) {
        request.response.write(
          jsonEncode({
            'ticket': {
              'id': 'stic_01',
              'public_no': 'SUP-000001',
              'status': 'closed',
            },
          }),
        );
      } else {
        request.response.write(
          jsonEncode({
            'rating': {'stars': 5, 'comment': 'Great'},
          }),
        );
      }
      await request.response.close();
    });
    addTearDown(() async {
      await subscription.cancel();
      await server.close(force: true);
    });

    final api = _SupportBrokerApiClient(
      apiUrl: 'http://127.0.0.1:${server.port}/v1/',
    );
    final repository = SupportRepository(api, localeResolver: () => 'th-TH');

    await repository.close('stic_01', idempotencyKey: 'close-key');
    await repository.rate(
      'stic_01',
      stars: 5,
      comment: 'Great',
      idempotencyKey: 'rating-key',
    );

    expect(receivedKeys, ['close-key', 'rating-key']);
  });
}

class _SupportBrokerApiClient extends ApiClient {
  _SupportBrokerApiClient({this.apiUrl = 'https://support.example.test/v1/'})
    : super(
        const AppConfig(
          apiBaseUrl: 'https://partner.example.test/api/v1',
          defaultLocale: 'th-TH',
        ),
        AuthTokenStore(),
        localeTag: 'th-TH',
      );

  final String apiUrl;
  String path = '';

  @override
  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    bool auth = true,
  }) async {
    this.path = path;
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data:
          {
                'token': 'support-token',
                'expires_at': '2099-07-23T10:00:00+07:00',
                'api_url': apiUrl,
                'realtime': {
                  'url': 'wss://support.example.test',
                  'key': 'support-key',
                  'auth_path': '/customer/realtime/auth',
                  'channel_prefix': 'private-support.tenant.ten_01',
                  'channels': ['private-support.tenant.ten_01.customer.cus_01'],
                },
              }
              as T,
    );
  }
}
