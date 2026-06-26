import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/realtime/customer_realtime_client.dart';
import '../../../core/realtime/customer_realtime_monitor.dart';
import '../../../core/realtime/customer_realtime_protocol.dart';
import '../../../core/tenant/mobile_bootstrap_controller.dart';
import '../data/lottery_repository.dart';

final lotteryStockRealtimeEnabledProvider = Provider<bool>((_) => true);

final lotteryStockRealtimeTickProvider = StateProvider<int>((_) => 0);

bool shouldRefreshLotteryStockFromRealtimeEvent({
  required CustomerRealtimeEvent event,
  required String gameId,
}) {
  final normalizedGameId = gameId.trim();

  if (event.name == 'stock.availability.updated') {
    return true;
  }

  if (event.name != 'stock.price.updated') {
    return false;
  }

  final payloadGameId =
      (event.payload['game_id'] ?? event.payload['gameId'] ?? '')
          .toString()
          .trim();

  return payloadGameId.isEmpty ||
      normalizedGameId.isEmpty ||
      payloadGameId == normalizedGameId;
}

class LotteryStockRealtimeMonitor extends ConsumerStatefulWidget {
  const LotteryStockRealtimeMonitor({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<LotteryStockRealtimeMonitor> createState() =>
      _LotteryStockRealtimeMonitorState();
}

class _LotteryStockRealtimeMonitorState
    extends ConsumerState<LotteryStockRealtimeMonitor> {
  CustomerRealtimeClient? _client;
  StreamSubscription<CustomerRealtimeEvent>? _events;
  String _signature = '';
  Timer? _refreshThrottle;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void didUpdateWidget(covariant LotteryStockRealtimeMonitor oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
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
    final bootstrap = ref.watch(mobileBootstrapProvider).valueOrNull;

    ref.listen<AsyncValue<MobileBootstrap>>(
      mobileBootstrapProvider,
      (_, __) => WidgetsBinding.instance.addPostFrameCallback((_) => _sync()),
    );
    if (bootstrap != null &&
        bootstrap.tenantId.isNotEmpty &&
        bootstrap.realtime.configured) {
      ref.listen<AsyncValue<String>>(
        currentGameIdProvider,
        (_, __) => WidgetsBinding.instance.addPostFrameCallback((_) => _sync()),
      );
    }
    return widget.child;
  }

  Future<void> _sync() async {
    if (!mounted || !ref.read(lotteryStockRealtimeEnabledProvider)) {
      await _stop();
      return;
    }

    final bootstrap = ref.read(mobileBootstrapProvider).valueOrNull;
    if (bootstrap == null ||
        bootstrap.tenantId.isEmpty ||
        !bootstrap.realtime.configured) {
      await _stop();
      return;
    }

    final gameId = ref.read(currentGameIdProvider).valueOrNull?.trim() ?? '';
    if (gameId.isEmpty) {
      await _stop();
      return;
    }

    final channels = [
      stockAvailabilityChannel(tenantId: bootstrap.tenantId, gameId: gameId),
      salePriceChannel(tenantId: bootstrap.tenantId),
    ];
    final signature = [
      bootstrap.tenantId,
      bootstrap.realtime.url,
      bootstrap.realtime.key,
      gameId,
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
    _events = client.events.listen((event) => _handleEvent(event, gameId));
    await client.connect(channels);
  }

  Future<void> _stop() async {
    _signature = '';
    _refreshThrottle?.cancel();
    _refreshThrottle = null;
    await _events?.cancel();
    _events = null;
    await _client?.dispose();
    _client = null;
  }

  void _handleEvent(CustomerRealtimeEvent event, String gameId) {
    if (!shouldRefreshLotteryStockFromRealtimeEvent(
      event: event,
      gameId: gameId,
    )) {
      return;
    }

    if (_refreshThrottle?.isActive ?? false) return;

    _refreshThrottle = Timer(const Duration(milliseconds: 750), () {
      if (!mounted) return;
      ref.read(lotteryStockRealtimeTickProvider.notifier).state++;
    });
  }
}
