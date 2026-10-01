import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/auth_token_store.dart';
import '../../../core/realtime/customer_realtime_client.dart';
import '../../../core/realtime/customer_realtime_monitor.dart';
import '../../../core/realtime/customer_realtime_protocol.dart';
import '../../../core/tenant/mobile_bootstrap_controller.dart';
import '../../wallet/data/wallet_repository.dart';

final topupRealtimeEnabledProvider = Provider<bool>((_) => true);

final topupRealtimeTickProvider = StateProvider<int>((_) => 0);

bool shouldRefreshTopupsFromRealtimeEvent(CustomerRealtimeEvent event) {
  return normalizeRealtimeEventNameWithPayload(
        eventName: event.name,
        payload: event.payload,
      ) ==
      'topup.updated';
}

class CustomerTopupRealtimeMonitor extends ConsumerStatefulWidget {
  const CustomerTopupRealtimeMonitor({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<CustomerTopupRealtimeMonitor> createState() =>
      _CustomerTopupRealtimeMonitorState();
}

class _CustomerTopupRealtimeMonitorState
    extends ConsumerState<CustomerTopupRealtimeMonitor> {
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
  void didUpdateWidget(covariant CustomerTopupRealtimeMonitor oldWidget) {
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
    if (!mounted || !ref.read(topupRealtimeEnabledProvider)) {
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
        customerId.isEmpty) {
      await _stop();
      return;
    }

    final channels = [
      customerTopupChannel(
        tenantId: bootstrap.tenantId,
        customerId: customerId,
      ),
      customerWalletChannel(
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
    final client =
        ref.read(customerRealtimeClientFactoryProvider)(bootstrap.realtime);
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
    if (!_shouldRefreshFromEvent(event)) return;
    if (_refreshThrottle?.isActive ?? false) return;

    _refreshThrottle = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      ref.invalidate(walletSummaryProvider);
      ref.read(topupRealtimeTickProvider.notifier).state++;
    });
  }

  bool _shouldRefreshFromEvent(CustomerRealtimeEvent event) {
    if (shouldRefreshTopupsFromRealtimeEvent(event)) return true;
    return _subscriptionTracker.register(event);
  }
}
