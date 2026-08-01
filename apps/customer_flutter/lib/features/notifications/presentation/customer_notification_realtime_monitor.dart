import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/customer_session_replacement_controller.dart';
import '../../../core/auth/auth_token_store.dart';
import '../../../core/realtime/customer_realtime_client.dart';
import '../../../core/realtime/customer_realtime_monitor.dart';
import '../../../core/realtime/customer_realtime_protocol.dart';
import '../../../core/tenant/mobile_bootstrap_controller.dart';
import '../data/customer_notification_repository.dart';

final customerNotificationRealtimeEnabledProvider = Provider<bool>((_) => true);
final customerNotificationRealtimeTickProvider = StateProvider<int>((_) => 0);

bool shouldRefreshNotificationsFromRealtimeEvent(CustomerRealtimeEvent event) {
  final name = normalizeRealtimeEventNameWithPayload(
    eventName: event.name,
    payload: event.payload,
  );
  return name == 'customer.notification.created' ||
      name == 'customer.notification.read' ||
      name == 'customer.notification.updated';
}

bool isCustomerSessionReplacementRealtimeEvent(CustomerRealtimeEvent event) {
  return normalizeRealtimeEventNameWithPayload(
        eventName: event.name,
        payload: event.payload,
      ) ==
      'customer.auth.session-replaced';
}

class CustomerNotificationRealtimeMonitor extends ConsumerStatefulWidget {
  const CustomerNotificationRealtimeMonitor({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<CustomerNotificationRealtimeMonitor> createState() =>
      _CustomerNotificationRealtimeMonitorState();
}

class _CustomerNotificationRealtimeMonitorState
    extends ConsumerState<CustomerNotificationRealtimeMonitor> {
  CustomerRealtimeClient? _client;
  StreamSubscription<CustomerRealtimeEvent>? _events;
  Timer? _refreshThrottle;
  final CustomerRealtimeSubscriptionTracker _subscriptionTracker =
      CustomerRealtimeSubscriptionTracker();
  Future<void> _syncQueue = Future<void>.value();
  String _signature = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleSync());
  }

  @override
  void didUpdateWidget(
    covariant CustomerNotificationRealtimeMonitor oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleSync());
  }

  @override
  void dispose() {
    _refreshThrottle?.cancel();
    unawaited(_events?.cancel());
    unawaited(_client?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<MobileBootstrap>>(
      mobileBootstrapProvider,
      (_, __) =>
          WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleSync()),
    );
    ref.listen<AuthController>(
      authControllerProvider,
      (_, __) =>
          WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleSync()),
    );
    return widget.child;
  }

  void _scheduleSync() {
    _syncQueue = _syncQueue.then((_) async {
      if (mounted) await _sync();
    });
  }

  Future<void> _sync() async {
    if (!mounted || !ref.read(customerNotificationRealtimeEnabledProvider)) {
      await _stop();
      return;
    }

    final bootstrap = ref.read(mobileBootstrapProvider).valueOrNull;
    final auth = ref.read(authControllerProvider);
    final customerId =
        ref.read(authTokenStoreProvider).customerId?.trim() ?? '';
    if (bootstrap == null ||
        bootstrap.tenantId.isEmpty ||
        !bootstrap.realtime.configured ||
        !auth.isAuthenticated ||
        auth.pinRequired ||
        auth.pinSetupRequired ||
        customerId.isEmpty) {
      await _stop();
      return;
    }

    final channels = [
      customerNotificationChannel(
        tenantId: bootstrap.tenantId,
        customerId: customerId,
      ),
    ];
    final signature = [
      bootstrap.tenantId,
      bootstrap.realtime.url,
      bootstrap.realtime.key,
      customerId,
      ...channels,
    ].join('|');

    if (_client != null && _signature == signature) {
      _client!.updateChannels(channels);
      return;
    }

    await _stop();
    if (!mounted) return;
    _subscriptionTracker.updateChannels(channels);
    _signature = signature;
    final client = ref.read(customerRealtimeClientFactoryProvider)(
      bootstrap.realtime,
    );
    _client = client;
    _events = client.events.listen(_handleEvent);
    await client.connect(channels);
  }

  Future<void> _stop() async {
    _signature = '';
    _subscriptionTracker.clear();
    _refreshThrottle?.cancel();
    _refreshThrottle = null;
    await _events?.cancel();
    _events = null;
    await _client?.dispose();
    _client = null;
  }

  void _handleEvent(CustomerRealtimeEvent event) {
    if (isCustomerSessionReplacementRealtimeEvent(event)) {
      ref
          .read(customerSessionReplacementControllerProvider.notifier)
          .notify(replacementSessionId: _replacementSessionId(event.payload));
      return;
    }

    if (!shouldRefreshNotificationsFromRealtimeEvent(event) &&
        !_subscriptionTracker.register(event)) {
      return;
    }
    if (_refreshThrottle?.isActive ?? false) return;

    _refreshThrottle = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      ref.invalidate(customerNotificationUnreadCountProvider);
      ref.read(customerNotificationRealtimeTickProvider.notifier).state++;
    });
  }
}

String _replacementSessionId(Map<String, dynamic> payload) {
  for (final key in const ['replacement_session_id', 'replacementSessionId']) {
    final value = payload[key]?.toString().trim() ?? '';
    if (value.isNotEmpty) return value;
  }
  for (final key in const ['data', 'payload', 'resource']) {
    final nested = payload[key];
    if (nested is Map) {
      final value = _replacementSessionId(
        nested.map((key, value) => MapEntry(key.toString(), value)),
      );
      if (value.isNotEmpty) return value;
    }
  }
  return '';
}
