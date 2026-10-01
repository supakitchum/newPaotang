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

  test('realtime client falls back to payload event aliases for bridge events',
      () async {
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
    socket.addServerMessage({
      'event': 'sync.outbox',
      'channel': siteConfigChannel(tenantId: 'ten_1'),
      'data': '{"event_type":"maintenance.changed.v1","reason":"maintenance"}',
    });
    socket.addServerMessage({
      'event': 'bridge.message',
      'channel': customerOrdersChannel(
        tenantId: 'ten_1',
        customerId: 'cus_1',
      ),
      'data': '{"payload":{"action":"order.paid.v1","order_id":"ord_1"}}',
    });
    await _flushAsync();

    expect(events, hasLength(2));
    expect(events.first.name, 'site-config.updated');
    expect(events.first.payload['event_type'], 'maintenance.changed.v1');
    expect(events.first.payload['reason'], 'maintenance');
    expect(events.last.name, 'order.updated');
    expect(events.last.payload['payload'], isA<Map>());

    await subscription.cancel();
  });

  test('realtime client reconnects after socket close', () async {
    final sockets = <_FakeRealtimeSocket>[];
    final client = CustomerRealtimeClient(
      config: _config(),
      api: _FakeApiClient(),
      reconnectDelay: const Duration(milliseconds: 1),
      socketFactory: (_) {
        final socket = _FakeRealtimeSocket();
        sockets.add(socket);
        return socket;
      },
    );

    await client.connect([siteConfigChannel(tenantId: 'ten_1')]);
    expect(sockets, hasLength(1));
    sockets.first.addServerMessage({
      'event': 'pusher:connection_established',
      'data': '{"socket_id":"123.456"}',
    });
    await _flushAsync();
    expect(sockets.first.sentEvents('pusher:subscribe'), hasLength(1));

    await sockets.first.closeFromServer();
    await Future<void>.delayed(const Duration(milliseconds: 5));

    expect(client.status, CustomerRealtimeStatus.reconnecting);
    expect(sockets, hasLength(2));
    sockets[1].addServerMessage({
      'event': 'pusher:connection_established',
      'data': '{"socket_id":"789.000"}',
    });
    await _flushAsync();

    expect(sockets[1].sentEvents('pusher:subscribe'), hasLength(1));
    await client.dispose();
  });

  test('realtime client reconnects and resubscribes after stream error',
      () async {
    final sockets = <_FakeRealtimeSocket>[];
    final client = CustomerRealtimeClient(
      config: _config(),
      api: _FakeApiClient(),
      reconnectDelay: const Duration(milliseconds: 1),
      socketFactory: (_) {
        final socket = _FakeRealtimeSocket();
        sockets.add(socket);
        return socket;
      },
    );

    await client.connect([siteConfigChannel(tenantId: 'ten_1')]);
    sockets.first.addServerMessage({
      'event': 'pusher:connection_established',
      'data': '{"socket_id":"123.456"}',
    });
    await _flushAsync();
    expect(sockets.first.sentEvents('pusher:subscribe'), hasLength(1));

    sockets.first.addServerError(StateError('transport interrupted'));
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(sockets, hasLength(2));
    sockets[1].addServerMessage({
      'event': 'pusher:connection_established',
      'data': '{"socket_id":"789.000"}',
    });
    await _flushAsync();

    expect(sockets[1].sentEvents('pusher:subscribe'), hasLength(1));
    await client.dispose();
  });

  test('realtime client retries private channel authorization after failure',
      () async {
    final sockets = <_FakeRealtimeSocket>[];
    final api = _FakeApiClient(authorizationFailures: 1);
    final client = CustomerRealtimeClient(
      config: _config(),
      api: api,
      reconnectDelay: const Duration(milliseconds: 1),
      socketFactory: (_) {
        final socket = _FakeRealtimeSocket();
        sockets.add(socket);
        return socket;
      },
    );

    await client.connect([customerPresenceChannel(tenantId: 'ten_1')]);
    sockets.first.addServerMessage({
      'event': 'pusher:connection_established',
      'data': '{"socket_id":"123.456"}',
    });
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(sockets, hasLength(2));
    expect(api.authorizedChannels, hasLength(1));
    sockets[1].addServerMessage({
      'event': 'pusher:connection_established',
      'data': '{"socket_id":"789.000"}',
    });
    await _flushAsync();

    expect(api.authorizedChannels, hasLength(2));
    expect(sockets[1].sentEvents('pusher:subscribe'), hasLength(1));
    await client.dispose();
  });

  test('realtime client recovers from malformed handshake and protocol error',
      () async {
    final sockets = <_FakeRealtimeSocket>[];
    final client = CustomerRealtimeClient(
      config: _config(),
      api: _FakeApiClient(),
      reconnectDelay: const Duration(milliseconds: 1),
      socketFactory: (_) {
        final socket = _FakeRealtimeSocket();
        sockets.add(socket);
        return socket;
      },
    );

    await client.connect([siteConfigChannel(tenantId: 'ten_1')]);
    sockets.first.addServerMessage({
      'event': 'pusher:connection_established',
      'data': <String, dynamic>{},
    });
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(sockets, hasLength(2));
    sockets[1].addServerMessage({
      'event': 'pusher:connection_established',
      'data': '{"socket_id":"789.000"}',
    });
    await _flushAsync();
    sockets[1].addServerMessage({
      'event': 'pusher:subscription_error',
      'data': {'message': 'channel authorization expired'},
    });
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(sockets, hasLength(3));
    await client.dispose();
  });

  test('realtime client unsubscribes channels removed from desired set',
      () async {
    final socket = _FakeRealtimeSocket();
    final client = CustomerRealtimeClient(
      config: _config(),
      api: _FakeApiClient(),
      socketFactory: (_) => socket,
    );

    await client.connect([
      siteConfigChannel(tenantId: 'ten_1'),
      salePriceChannel(tenantId: 'ten_1'),
    ]);
    socket.addServerMessage({
      'event': 'pusher:connection_established',
      'data': '{"socket_id":"123.456"}',
    });
    await _flushAsync();

    client.updateChannels([siteConfigChannel(tenantId: 'ten_1')]);
    await _flushAsync();

    expect(socket.sentEvents('pusher:unsubscribe'), hasLength(1));
    expect(
      socket.sentPayloads('pusher:unsubscribe').single['data'],
      {'channel': salePriceChannel(tenantId: 'ten_1')},
    );
    await client.dispose();
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

  Future<void> closeFromServer() async {
    await _controller.close();
  }

  void addServerMessage(Map<String, dynamic> message) {
    _controller.add(convert.jsonEncode(message));
  }

  void addServerError(Object error) {
    _controller.addError(error);
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
  _FakeApiClient({int authorizationFailures = 0})
      : _authorizationFailures = authorizationFailures,
        super(
          const AppConfig(
            apiBaseUrl: 'https://tenant.example.test/api/v1',
            defaultLocale: 'th-TH',
          ),
          AuthTokenStore(),
          localeTag: 'th-TH',
        );

  final List<String> authorizedChannels = [];
  int _authorizationFailures;

  @override
  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    bool auth = true,
  }) async {
    final payload = data as Map<String, dynamic>;
    authorizedChannels.add(payload['channel_name']?.toString() ?? '');
    if (_authorizationFailures > 0) {
      _authorizationFailures--;
      throw DioException(
        requestOptions: RequestOptions(path: path),
        error: 'authorization unavailable',
      );
    }
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
