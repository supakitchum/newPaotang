import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../network/api_client.dart';
import '../tenant/mobile_bootstrap_controller.dart';
import 'customer_presence_controller.dart';
import 'customer_realtime_client.dart';
import 'customer_realtime_protocol.dart';

final customerRealtimeEnabledProvider = Provider<bool>((_) => true);

final customerRealtimeClientFactoryProvider =
    Provider<CustomerRealtimeClient Function(MobileRealtimeConfig)>((ref) {
  final api = ref.watch(apiClientProvider);
  return (config) => CustomerRealtimeClient(config: config, api: api);
});

class CustomerRealtimeMonitor extends ConsumerStatefulWidget {
  const CustomerRealtimeMonitor({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<CustomerRealtimeMonitor> createState() =>
      _CustomerRealtimeMonitorState();
}

class _CustomerRealtimeMonitorState
    extends ConsumerState<CustomerRealtimeMonitor> {
  CustomerRealtimeClient? _client;
  StreamSubscription<CustomerRealtimeEvent>? _events;
  final Set<String> _presenceMemberIds = {};
  String _signature = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void didUpdateWidget(covariant CustomerRealtimeMonitor oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void dispose() {
    unawaited(_events?.cancel());
    unawaited(_client?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<MobileBootstrap>>(
      mobileBootstrapProvider,
      (_, __) => WidgetsBinding.instance.addPostFrameCallback((_) => _sync()),
    );
    ref.listen<AuthController>(
      authControllerProvider,
      (_, __) => WidgetsBinding.instance.addPostFrameCallback((_) => _sync()),
    );
    return widget.child;
  }

  Future<void> _sync() async {
    if (!mounted || !ref.read(customerRealtimeEnabledProvider)) {
      await _stop();
      return;
    }

    final bootstrap = ref.read(mobileBootstrapProvider).valueOrNull;
    final auth = ref.read(authControllerProvider);
    if (bootstrap == null ||
        bootstrap.tenantId.isEmpty ||
        !bootstrap.realtime.configured) {
      await _stop();
      return;
    }

    final channels = <String>[
      siteConfigChannel(tenantId: bootstrap.tenantId),
      if (auth.isAuthenticated)
        customerPresenceChannel(tenantId: bootstrap.tenantId),
    ];
    final signature = [
      bootstrap.tenantId,
      bootstrap.realtime.url,
      bootstrap.realtime.key,
      auth.isAuthenticated ? 'auth' : 'guest',
      ...channels,
    ].join('|');

    if (_client != null && _signature == signature) {
      _client!.updateChannels(channels);
      return;
    }

    await _stop();
    _signature = signature;
    final client =
        ref.read(customerRealtimeClientFactoryProvider)(bootstrap.realtime);
    _client = client;
    _events = client.events.listen(_handleEvent);
    await client.connect(channels);
  }

  Future<void> _stop() async {
    _signature = '';
    await _events?.cancel();
    _events = null;
    await _client?.dispose();
    _client = null;
    _presenceMemberIds.clear();
  }

  void _handleEvent(CustomerRealtimeEvent event) {
    if (event.name == 'site-config.updated') {
      ref.invalidate(mobileBootstrapProvider);
      return;
    }

    if (event.name == 'pusher_internal:member_added' ||
        event.name == 'pusher_internal:member_removed') {
      _syncPresenceMember(
        event.payload,
        isOnline: event.name == 'pusher_internal:member_added',
      );
      return;
    }

    if (event.name == 'pusher_internal:subscription_succeeded') {
      _syncPresenceCount(event.payload);
    }
  }

  void _syncPresenceCount(Map<String, dynamic> payload) {
    final presence = payload['presence'] is Map
        ? Map<String, dynamic>.from(payload['presence'] as Map)
        : payload;
    final count = int.tryParse(presence['count']?.toString() ?? '');
    final ids = presence['ids'];
    if (ids is List) {
      _presenceMemberIds
        ..clear()
        ..addAll(ids.map((id) => id.toString()).where((id) => id.isNotEmpty));
    } else if (presence['hash'] is Map) {
      _presenceMemberIds
        ..clear()
        ..addAll((presence['hash'] as Map).keys.map((id) => id.toString()));
    }
    ref
        .read(customerPresenceControllerProvider)
        .setOnlineCount(count ?? _presenceMemberIds.length);
  }

  void _syncPresenceMember(
    Map<String, dynamic> payload, {
    required bool isOnline,
  }) {
    final member = payload['member'] is Map
        ? Map<String, dynamic>.from(payload['member'] as Map)
        : payload;
    final userId =
        (payload['user_id'] ?? member['user_id'] ?? member['id'] ?? '')
            .toString()
            .trim();
    if (userId.isEmpty) return;
    if (isOnline) {
      _presenceMemberIds.add(userId);
    } else {
      _presenceMemberIds.remove(userId);
    }
    ref
        .read(customerPresenceControllerProvider)
        .setOnlineCount(_presenceMemberIds.length);
  }
}
