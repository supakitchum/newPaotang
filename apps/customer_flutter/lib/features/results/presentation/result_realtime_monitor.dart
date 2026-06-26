import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/realtime/customer_realtime_client.dart';
import '../../../core/realtime/customer_realtime_monitor.dart';
import '../../../core/realtime/customer_realtime_protocol.dart';
import '../../../core/tenant/mobile_bootstrap_controller.dart';
import '../data/result_repository.dart';

final resultRealtimeEnabledProvider = Provider<bool>((_) => true);

class ResultRealtimeMonitor extends ConsumerStatefulWidget {
  const ResultRealtimeMonitor({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ResultRealtimeMonitor> createState() =>
      _ResultRealtimeMonitorState();
}

class _ResultRealtimeMonitorState extends ConsumerState<ResultRealtimeMonitor> {
  CustomerRealtimeClient? _client;
  StreamSubscription<CustomerRealtimeEvent>? _events;
  String _signature = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void didUpdateWidget(covariant ResultRealtimeMonitor oldWidget) {
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
    return widget.child;
  }

  Future<void> _sync() async {
    if (!mounted || !ref.read(resultRealtimeEnabledProvider)) {
      await _stop();
      return;
    }

    final bootstrap = ref.read(mobileBootstrapProvider).valueOrNull;
    if (bootstrap == null || !bootstrap.realtime.configured) {
      await _stop();
      return;
    }

    final channels = [publicLatestResultChannel()];
    final signature = [
      bootstrap.realtime.url,
      bootstrap.realtime.key,
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
  }

  void _handleEvent(CustomerRealtimeEvent event) {
    if (event.name != 'reward.result.live.updated') return;

    ref.invalidate(currentResultProvider);

    final gameId =
        (event.payload['game_id'] ?? event.payload['gameId'] ?? '').toString();
    if (gameId.trim().isNotEmpty) {
      ref.invalidate(resultDetailProvider(gameId.trim()));
    }
  }
}
