import 'dart:async';
import 'dart:convert' as convert;

import 'package:customer_flutter/core/auth/auth_token_store.dart';
import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/network/api_client.dart';
import 'package:customer_flutter/core/realtime/customer_realtime_client.dart';
import 'package:customer_flutter/core/realtime/customer_realtime_protocol.dart';
import 'package:customer_flutter/core/tenant/mobile_bootstrap_controller.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('realtime client subscribes public and authorized channels', () async {
    final socket = _FakeRealtimeSocket();
    final api = _FakeApiClient();
    final client = CustomerRealtimeClient(
      config: _config(),
      api: api,
      socketFactory: (_) => socket,
    );

    await client.connect([
      siteConfigChannel(tenantId: 'ten_1'),
      customerPresenceChannel(tenantId: 'ten_1'),
    ]);
    socket.addServerMessage({
      'event': 'pusher:connection_established',
      'data': '{"socket_id":"123.456"}',
    });
    await _flushAsync();

    expect(
      api.authorizedChannels,
      ['presence-customer.tenant.ten_1.customers'],
    );
    expect(socket.sentEvents('pusher:subscribe'), hasLength(2));
    expect(
      socket.sentPayloads('pusher:subscribe').map((payload) {
        final data = payload['data'] as Map<String, dynamic>;
        return data['channel'];
      }),
      containsAll([
        'customer.tenant.ten_1.site-config',
        'presence-customer.tenant.ten_1.customers',
      ]),
    );
    expect(
      socket.sentPayloads('pusher:subscribe').any((payload) {
        final data = payload['data'] as Map<String, dynamic>;
        return data['channel'] == 'presence-customer.tenant.ten_1.customers' &&
            data['auth'] == 'realtime-auth';
      }),
      isTrue,
    );
  });

  test('realtime client emits app events and responds to pings', () async {
    final socket = _FakeRealtimeSocket();
    final client = CustomerRealtimeClient(
      config: _config(),
      api: _FakeApiClient(),
      socketFactory: (_) => socket,
    );
    final events = <CustomerRealtimeEvent>[];
    final subscription = client.events.listen(events.add);

    await client.connect([siteConfigChannel(tenantId: 'ten_1')]);
    socket.addServerMessage({
      'event': 'pusher:connection_established',
      'data': '{"socket_id":"123.456"}',
    });
    socket.addServerMessage({'event': 'pusher:ping', 'data': {}});
    socket.addServerMessage({
      'event': 'site-config.updated',
      'channel': 'customer.tenant.ten_1.site-config',
      'data': '{"reason":"maintenance"}',
    });
    await _flushAsync();

    expect(socket.sentEvents('pusher:pong'), hasLength(1));
    expect(events, hasLength(1));
    expect(events.single.name, 'site-config.updated');
    expect(events.single.payload['reason'], 'maintenance');

    await subscription.cancel();
  });
}

MobileRealtimeConfig _config() {
  return MobileRealtimeConfig.fromJson({
    'enabled': true,
    'url': 'https://realtime.example.com',
    'key': 'customer-key',
  });
}

Future<void> _flushAsync() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

class _FakeRealtimeSocket implements CustomerRealtimeSocket {
  final StreamController<Object?> _controller = StreamController<Object?>();
  final List<Map<String, dynamic>> sent = [];

  @override
  Stream<Object?> get stream => _controller.stream;

  @override
  void send(String value) {
    sent.add(Map<String, dynamic>.from(convert.jsonDecode(value) as Map));
  }

  @override
  Future<void> close() async {
    await _controller.close();
  }

  void addServerMessage(Map<String, dynamic> message) {
    _controller.add(convert.jsonEncode(message));
  }

  List<Map<String, dynamic>> sentPayloads(String event) {
    return sent.where((payload) => payload['event'] == event).toList();
  }

  List<String> sentEvents(String event) {
    return sent
        .where((payload) => payload['event'] == event)
        .map((payload) => payload['event'].toString())
        .toList();
  }
}

class _FakeApiClient extends ApiClient {
  _FakeApiClient()
      : super(
          const AppConfig(
            apiBaseUrl: 'https://tenant.example.test/api/v1',
            defaultLocale: 'th-TH',
          ),
          AuthTokenStore(),
          localeTag: 'th-TH',
        );

  final List<String> authorizedChannels = [];

  @override
  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    bool auth = true,
  }) async {
    final payload = data as Map<String, dynamic>;
    authorizedChannels.add(payload['channel_name']?.toString() ?? '');
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: {
        'data': {
          'auth': 'realtime-auth',
          'channel_data': '{"user_id":"cus_1"}',
        },
      } as T,
    );
  }
}
