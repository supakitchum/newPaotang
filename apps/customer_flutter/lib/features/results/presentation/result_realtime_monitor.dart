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
  void didUpdateWidget(covariant ResultRealtimeMonitor oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleSync());
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
      (_, __) =>
          WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleSync()),
    );
    ref.listen<AsyncValue<RewardResultBundle>>(
      currentResultProvider,
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
    if (!mounted || !ref.read(resultRealtimeEnabledProvider)) {
      await _stop();
      return;
    }

    final bootstrap = ref.read(mobileBootstrapProvider).valueOrNull;
    if (bootstrap == null || !bootstrap.realtime.configured) {
      await _stop();
      return;
    }

    final gameId = _resultRealtimeGameId(
      ref.read(currentResultProvider).valueOrNull,
    );
    final channels = [
      publicLatestResultChannel(),
      if (gameId.isNotEmpty) publicGameResultChannel(gameId: gameId),
    ];
    final signature = [
      bootstrap.realtime.url,
      bootstrap.realtime.key,
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
    await _events?.cancel();
    _events = null;
    await _client?.dispose();
    _client = null;
    _subscriptionTracker.clear();
  }

  void _handleEvent(CustomerRealtimeEvent event) {
    if (_subscriptionTracker.register(event)) {
      if (event.channel.trim() == publicLatestResultChannel()) {
        final currentGameId = _resultRealtimeGameId(
          ref.read(currentResultProvider).valueOrNull,
        );
        _refreshResults(currentGameId);
      }
      return;
    }

    if (normalizeRealtimeEventNameWithPayload(
          eventName: event.name,
          payload: event.payload,
        ) !=
        'reward.result.live.updated') {
      return;
    }

    final payload = normalizeRealtimePayload(event.payload);
    final gameId = _resultRealtimeScalarText(
      payload['game_id'] ??
          payload['gameId'] ??
          payload['current_game_id'] ??
          payload['currentGameId'] ??
          payload['reward_game_id'] ??
          payload['rewardGameId'] ??
          payload['result_game_id'] ??
          payload['resultGameId'] ??
          payload['lottery_game_id'] ??
          payload['lotteryGameId'] ??
          payload['selected_game_id'] ??
          payload['selectedGameId'] ??
          _gameIdFromRealtimePayload(payload),
    );
    _refreshResults(gameId);
  }

  void _refreshResults(String gameId) {
    ref.invalidate(currentResultProvider);
    ref.invalidate(legacyResultProvider);
    ref.invalidate(resultDetailProvider(null));
    ref.invalidate(publishedResultDetailProvider(null));
    final normalizedGameId = gameId.trim();
    if (normalizedGameId.isNotEmpty) {
      ref.invalidate(resultDetailProvider(normalizedGameId));
      ref.invalidate(publishedResultDetailProvider(normalizedGameId));
    }
  }
}

String _resultRealtimeGameId(RewardResultBundle? result) {
  final currentGameId = result?.currentGame?.id.trim() ?? '';
  if (currentGameId.isNotEmpty) return currentGameId;

  return result?.selectedResult?.id.trim() ?? '';
}

String? _gameIdFromRealtimePayload(Map<String, dynamic> payload) {
  for (final key in const [
    'game',
    'current_game',
    'currentGame',
    'reward_game',
    'rewardGame',
    'result_game',
    'resultGame',
    'lottery_game',
    'lotteryGame',
    'selected_game',
    'selectedGame',
  ]) {
    final value = payload[key];
    if (value is! Map) continue;
    final id = _resultRealtimeScalarText(
      value['id'] ??
          value['uuid'] ??
          value['current_game_id'] ??
          value['currentGameId'] ??
          value['game_id'] ??
          value['gameId'] ??
          value['reward_game_id'] ??
          value['rewardGameId'] ??
          value['result_game_id'] ??
          value['resultGameId'] ??
          value['lottery_game_id'] ??
          value['lotteryGameId'] ??
          value['selected_game_id'] ??
          value['selectedGameId'] ??
          value['value'] ??
          value['code'] ??
          value['key'],
    );
    if (id.isNotEmpty) return id;
  }
  return null;
}

String _resultRealtimeScalarText(Object? value, [int depth = 0]) {
  if (value == null || depth > 3) return '';
  if (value is Map) {
    for (final key in const [
      'value',
      'code',
      'key',
      'id',
      'uuid',
      'current_game_id',
      'currentGameId',
      'game_id',
      'gameId',
      'reward_game_id',
      'rewardGameId',
      'result_game_id',
      'resultGameId',
      'lottery_game_id',
      'lotteryGameId',
      'selected_game_id',
      'selectedGameId',
    ]) {
      final nested = _resultRealtimeScalarText(value[key], depth + 1);
      if (nested.isNotEmpty) return nested;
    }
    return '';
  }
  if (value is Iterable) {
    for (final item in value) {
      final nested = _resultRealtimeScalarText(item, depth + 1);
      if (nested.isNotEmpty) return nested;
    }
    return '';
  }
  return value.toString().trim();
}
