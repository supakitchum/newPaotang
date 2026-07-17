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
  reconnecting,
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

class CustomerRealtimeSubscriptionTracker {
  final Set<String> _activeChannels = {};
  final Set<String> _seenChannels = {};

  void updateChannels(Iterable<String> channels) {
    final nextChannels = channels
        .map((channel) => channel.trim())
        .where((channel) => channel.isNotEmpty)
        .toSet();
    _activeChannels
      ..clear()
      ..addAll(nextChannels);
    _seenChannels.retainAll(nextChannels);
  }

  bool register(CustomerRealtimeEvent event) {
    if (event.name != 'pusher_internal:subscription_succeeded') return false;
    final channel = event.channel.trim();
    if (channel.isEmpty || !_activeChannels.contains(channel)) return false;

    final seenBefore = _seenChannels.contains(channel);
    _seenChannels.add(channel);
    return seenBefore;
  }

  bool contains(String channel) => _activeChannels.contains(channel.trim());

  void clear() {
    _activeChannels.clear();
    _seenChannels.clear();
  }
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
    Duration reconnectDelay = const Duration(seconds: 10),
  })  : _config = config,
        _api = api,
        _reconnectDelay = reconnectDelay,
        _socketFactory =
            socketFactory ?? ((uri) => WebSocketCustomerRealtimeSocket(uri));

  final MobileRealtimeConfig _config;
  final ApiClient _api;
  final CustomerRealtimeSocketFactory _socketFactory;
  final Duration _reconnectDelay;
  final StreamController<CustomerRealtimeEvent> _events =
      StreamController<CustomerRealtimeEvent>.broadcast();
  final Set<String> _desiredChannels = {};
  final Set<String> _subscribedChannels = {};
  final Set<String> _subscribingChannels = {};

  CustomerRealtimeSocket? _socket;
  StreamSubscription<Object?>? _subscription;
  Timer? _reconnectTimer;
  String _socketId = '';
  bool _disposed = false;

  CustomerRealtimeStatus status = CustomerRealtimeStatus.idle;
  String error = '';

  Stream<CustomerRealtimeEvent> get events => _events.stream;

  Future<void> connect(Iterable<String> channels) async {
    updateChannels(channels);
    if (!_config.configured || _desiredChannels.isEmpty) {
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      status = _config.configured
          ? CustomerRealtimeStatus.idle
          : CustomerRealtimeStatus.unavailable;
      return;
    }

    await disconnect(sendUnsubscribe: false);
    await _openSocket(reconnecting: false);
  }

  Future<void> _openSocket({required bool reconnecting}) async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    status = reconnecting
        ? CustomerRealtimeStatus.reconnecting
        : CustomerRealtimeStatus.connecting;
    error = '';

    try {
      final socket =
          _socketFactory(CustomerRealtimeProtocol.socketUri(_config));
      _socket = socket;
      _subscription = socket.stream.listen(
        (raw) => unawaited(_handleRaw(socket, raw)),
        onError: (Object err) {
          unawaited(_recoverSocket(socket, err));
        },
        onDone: () => _handleSocketDone(socket),
      );
    } catch (err) {
      error = err.toString();
      status = CustomerRealtimeStatus.error;
      _scheduleReconnect();
    }
  }

  void updateChannels(Iterable<String> channels) {
    final nextChannels = channels
        .map((channel) => channel.trim())
        .where((channel) => channel.isNotEmpty)
        .toSet();
    final removedChannels = _subscribedChannels
        .where((channel) => !nextChannels.contains(channel))
        .toList(growable: false);

    _desiredChannels
      ..clear()
      ..addAll(nextChannels);

    final socket = _socket;
    if (socket != null && _socketId.isNotEmpty) {
      for (final channel in removedChannels) {
        try {
          _send(socket, {
            'event': 'pusher:unsubscribe',
            'data': {'channel': channel},
          });
        } catch (err) {
          unawaited(_recoverSocket(socket, err));
          break;
        }
        _subscribedChannels.remove(channel);
        _subscribingChannels.remove(channel);
      }
    }

    if (_desiredChannels.isEmpty) {
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
    }
    _syncSubscriptions();
  }

  Future<void> disconnect({bool sendUnsubscribe = true}) async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    final socket = _socket;
    _socket = null;
    _socketId = '';

    if (sendUnsubscribe && socket != null) {
      for (final channel in _subscribedChannels) {
        try {
          _send(socket, {
            'event': 'pusher:unsubscribe',
            'data': {'channel': channel},
          });
        } catch (_) {
          break;
        }
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
    _disposed = true;
    await disconnect();
    await _events.close();
  }

  Future<void> _handleRaw(
    CustomerRealtimeSocket socket,
    Object? raw,
  ) async {
    if (_disposed || _socket != socket) return;
    final message = parseRealtimeMessage(raw);

    if (message.event == 'pusher:connection_established') {
      final socketId = message.dataMap['socket_id']?.toString().trim() ?? '';
      if (socketId.isEmpty) {
        await _recoverSocket(
          socket,
          StateError('Realtime handshake did not include a socket id.'),
        );
        return;
      }
      _socketId = socketId;
      _syncSubscriptions();
      return;
    }

    if (message.event == 'pusher:ping') {
      try {
        _send(socket, {'event': 'pusher:pong', 'data': <String, dynamic>{}});
      } catch (err) {
        await _recoverSocket(socket, err);
      }
      return;
    }

    if (_isProtocolFailureEvent(message.event)) {
      await _recoverSocket(
        socket,
        StateError(_protocolFailureMessage(message)),
      );
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

    final dataMap = message.dataMap;
    final eventName = normalizeRealtimeEventNameWithPayload(
      eventName: message.event,
      payload: dataMap,
    );
    if (eventName.isEmpty) return;

    _events.add(
      CustomerRealtimeEvent(
        name: eventName,
        channel: message.channel,
        payload: dataMap,
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
        final authorization = auth['auth']?.toString().trim() ?? '';
        if (authorization.isEmpty) {
          throw StateError(
            'Realtime authorization response did not include an auth token.',
          );
        }
        data['auth'] = authorization;
        if (auth['channel_data'] != null) {
          data['channel_data'] = auth['channel_data'];
        }
      }

      if (_socket != socket || _socketId.isEmpty) return;

      _send(socket, {'event': 'pusher:subscribe', 'data': data});
      _subscribedChannels.add(channel);
    } catch (err) {
      await _recoverSocket(socket, err);
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

  void _handleSocketDone(CustomerRealtimeSocket socket) {
    if (_socket != socket) return;

    _socket = null;
    _subscription = null;
    _socketId = '';
    _subscribedChannels.clear();
    _subscribingChannels.clear();
    if (status == CustomerRealtimeStatus.idle || _disposed) return;

    if (_config.configured && _desiredChannels.isNotEmpty) {
      _scheduleReconnect();
    } else {
      status = CustomerRealtimeStatus.unavailable;
    }
  }

  Future<void> _recoverSocket(
    CustomerRealtimeSocket socket,
    Object failure,
  ) async {
    if (_disposed || _socket != socket) return;

    error = failure.toString();
    status = CustomerRealtimeStatus.error;
    _socket = null;
    _socketId = '';
    _subscribedChannels.clear();
    _subscribingChannels.clear();

    final subscription = _subscription;
    _subscription = null;
    try {
      await subscription?.cancel();
    } catch (_) {
      // Recovery continues even when the transport cannot cancel cleanly.
    }
    try {
      await socket.close();
    } catch (_) {
      // The reconnect timer remains authoritative after a failed close.
    }

    if (_disposed) return;
    if (_config.configured && _desiredChannels.isNotEmpty) {
      _scheduleReconnect();
    } else {
      status = _config.configured
          ? CustomerRealtimeStatus.idle
          : CustomerRealtimeStatus.unavailable;
    }
  }

  void _scheduleReconnect() {
    if (_disposed ||
        !_config.configured ||
        _desiredChannels.isEmpty ||
        _reconnectTimer != null) {
      return;
    }

    status = CustomerRealtimeStatus.reconnecting;
    _reconnectTimer = Timer(_reconnectDelay, () {
      _reconnectTimer = null;
      if (_disposed || !_config.configured || _desiredChannels.isEmpty) {
        return;
      }
      unawaited(_openSocket(reconnecting: true));
    });
  }

  void _send(CustomerRealtimeSocket socket, Map<String, dynamic> payload) {
    socket.send(convert.jsonEncode(payload));
  }
}

bool _isProtocolFailureEvent(String event) {
  return event == 'pusher:error' ||
      event == 'pusher:subscription_error' ||
      event == 'pusher_internal:subscription_error';
}

String _protocolFailureMessage(CustomerRealtimeMessage message) {
  final data = message.dataMap;
  for (final key in ['message', 'error', 'reason', 'code']) {
    final value = data[key]?.toString().trim() ?? '';
    if (value.isNotEmpty) return '${message.event}: $value';
  }
  return message.event;
}
