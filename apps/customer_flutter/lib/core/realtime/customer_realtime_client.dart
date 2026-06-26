import 'dart:async';
import 'dart:convert' as convert;

import 'package:web_socket_channel/web_socket_channel.dart';

import '../network/api_client.dart';
import '../tenant/mobile_bootstrap_controller.dart';
import '../utils/api_payload.dart';
import 'customer_realtime_protocol.dart';

typedef CustomerRealtimeSocketFactory = CustomerRealtimeSocket Function(
  Uri uri,
);

enum CustomerRealtimeStatus {
  idle,
  unavailable,
  connecting,
  authenticating,
  connected,
  error,
}

class CustomerRealtimeEvent {
  const CustomerRealtimeEvent({
    required this.name,
    required this.channel,
    required this.payload,
  });

  final String name;
  final String channel;
  final Map<String, dynamic> payload;
}

abstract class CustomerRealtimeSocket {
  Stream<Object?> get stream;

  void send(String value);

  Future<void> close();
}

class WebSocketCustomerRealtimeSocket implements CustomerRealtimeSocket {
  WebSocketCustomerRealtimeSocket(Uri uri)
      : _channel = WebSocketChannel.connect(uri);

  final WebSocketChannel _channel;

  @override
  Stream<Object?> get stream => _channel.stream;

  @override
  void send(String value) {
    _channel.sink.add(value);
  }

  @override
  Future<void> close() async {
    await _channel.sink.close();
  }
}

class CustomerRealtimeClient {
  CustomerRealtimeClient({
    required MobileRealtimeConfig config,
    required ApiClient api,
    CustomerRealtimeSocketFactory? socketFactory,
  })  : _config = config,
        _api = api,
        _socketFactory =
            socketFactory ?? ((uri) => WebSocketCustomerRealtimeSocket(uri));

  final MobileRealtimeConfig _config;
  final ApiClient _api;
  final CustomerRealtimeSocketFactory _socketFactory;
  final StreamController<CustomerRealtimeEvent> _events =
      StreamController<CustomerRealtimeEvent>.broadcast();
  final Set<String> _desiredChannels = {};
  final Set<String> _subscribedChannels = {};
  final Set<String> _subscribingChannels = {};

  CustomerRealtimeSocket? _socket;
  StreamSubscription<Object?>? _subscription;
  String _socketId = '';

  CustomerRealtimeStatus status = CustomerRealtimeStatus.idle;
  String error = '';

  Stream<CustomerRealtimeEvent> get events => _events.stream;

  Future<void> connect(Iterable<String> channels) async {
    updateChannels(channels);
    if (!_config.configured || _desiredChannels.isEmpty) {
      status = _config.configured
          ? CustomerRealtimeStatus.idle
          : CustomerRealtimeStatus.unavailable;
      return;
    }

    await disconnect(sendUnsubscribe: false);
    status = CustomerRealtimeStatus.connecting;
    error = '';

    try {
      _socket = _socketFactory(CustomerRealtimeProtocol.socketUri(_config));
      _subscription = _socket!.stream.listen(
        (raw) => unawaited(_handleRaw(raw)),
        onError: (Object err) {
          error = err.toString();
          status = CustomerRealtimeStatus.error;
        },
        onDone: () {
          _socket = null;
          _socketId = '';
          _subscribedChannels.clear();
          _subscribingChannels.clear();
          if (status != CustomerRealtimeStatus.idle) {
            status = CustomerRealtimeStatus.unavailable;
          }
        },
      );
    } catch (err) {
      error = err.toString();
      status = CustomerRealtimeStatus.error;
    }
  }

  void updateChannels(Iterable<String> channels) {
    _desiredChannels
      ..clear()
      ..addAll(
        channels
            .map((channel) => channel.trim())
            .where((channel) => channel.isNotEmpty),
      );
    _syncSubscriptions();
  }

  Future<void> disconnect({bool sendUnsubscribe = true}) async {
    final socket = _socket;
    _socket = null;
    _socketId = '';

    if (sendUnsubscribe && socket != null) {
      for (final channel in _subscribedChannels) {
        _send(socket, {
          'event': 'pusher:unsubscribe',
          'data': {'channel': channel},
        });
      }
    }

    _subscribedChannels.clear();
    _subscribingChannels.clear();
    await _subscription?.cancel();
    _subscription = null;
    await socket?.close();
    status = CustomerRealtimeStatus.idle;
  }

  Future<void> dispose() async {
    await disconnect();
    await _events.close();
  }

  Future<void> _handleRaw(Object? raw) async {
    final message = parseRealtimeMessage(raw);

    if (message.event == 'pusher:connection_established') {
      _socketId = message.dataMap['socket_id']?.toString() ?? '';
      _syncSubscriptions();
      return;
    }

    if (message.event == 'pusher:ping') {
      final socket = _socket;
      if (socket != null) {
        _send(socket, {'event': 'pusher:pong', 'data': <String, dynamic>{}});
      }
      return;
    }

    if (message.event == 'pusher_internal:subscription_succeeded') {
      if (status != CustomerRealtimeStatus.error) {
        status = CustomerRealtimeStatus.connected;
      }
      _events.add(
        CustomerRealtimeEvent(
          name: message.event,
          channel: message.channel,
          payload: message.dataMap,
        ),
      );
      return;
    }

    final eventName = message.normalizedEvent;
    if (eventName.isEmpty) return;

    _events.add(
      CustomerRealtimeEvent(
        name: eventName,
        channel: message.channel,
        payload: message.dataMap,
      ),
    );
  }

  void _syncSubscriptions() {
    final socket = _socket;
    if (socket == null || _socketId.isEmpty) return;

    for (final channel in _desiredChannels) {
      if (_subscribedChannels.contains(channel) ||
          _subscribingChannels.contains(channel)) {
        continue;
      }
      unawaited(_subscribe(socket, channel));
    }
  }

  Future<void> _subscribe(CustomerRealtimeSocket socket, String channel) async {
    _subscribingChannels.add(channel);
    try {
      final data = <String, dynamic>{'channel': channel};
      if (isAuthorizedRealtimeChannel(channel)) {
        status = CustomerRealtimeStatus.authenticating;
        final auth = await _authorize(channel);
        data['auth'] = auth['auth'];
        if (auth['channel_data'] != null) {
          data['channel_data'] = auth['channel_data'];
        }
      }

      if (_socket != socket || _socketId.isEmpty) return;

      _send(socket, {'event': 'pusher:subscribe', 'data': data});
      _subscribedChannels.add(channel);
    } catch (err) {
      error = err.toString();
      status = CustomerRealtimeStatus.error;
    } finally {
      _subscribingChannels.remove(channel);
    }
  }

  Future<Map<String, dynamic>> _authorize(String channel) async {
    final response = await _api.post<Map<String, dynamic>>(
      _config.authEndpoint,
      data: {
        'socket_id': _socketId,
        'channel_name': channel,
      },
    );
    return unwrapPayload(response.data);
  }

  void _send(CustomerRealtimeSocket socket, Map<String, dynamic> payload) {
    socket.send(convert.jsonEncode(payload));
  }
}
