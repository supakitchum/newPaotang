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

const lotteryStockPriceTrendUp = 'up';
const lotteryStockPriceTrendDown = 'down';

final lotteryStockPricePatchProvider =
    StateProvider<LotteryStockPricePatch?>((_) => null);

final lotteryStockAvailabilityPatchProvider =
    StateProvider<LotteryStockAvailabilityPatch?>((_) => null);

int _lotteryStockPricePatchSequence = 0;
int _lotteryStockAvailabilityPatchSequence = 0;

class LotteryStockPricePatch {
  const LotteryStockPricePatch({
    required this.price,
    required this.gameId,
    required this.flashKey,
  });

  final double price;
  final String gameId;
  final int flashKey;

  bool matchesGame(String currentGameId) {
    final normalizedPatchGameId = gameId.trim();
    final normalizedCurrentGameId = currentGameId.trim();
    return normalizedPatchGameId.isEmpty ||
        normalizedCurrentGameId.isEmpty ||
        normalizedPatchGameId == normalizedCurrentGameId;
  }
}

class LotteryStockAvailabilityPatch {
  const LotteryStockAvailabilityPatch({
    required this.number,
    required this.remainingCount,
    required this.status,
    required this.gameId,
    required this.flashKey,
  });

  final String number;
  final int remainingCount;
  final String status;
  final String gameId;
  final int flashKey;

  bool matchesGame(String currentGameId) {
    final normalizedPatchGameId = gameId.trim();
    final normalizedCurrentGameId = currentGameId.trim();
    return normalizedPatchGameId.isEmpty ||
        normalizedCurrentGameId.isEmpty ||
        normalizedPatchGameId == normalizedCurrentGameId;
  }

  bool matchesNumber(String candidate) {
    final candidateDigits =
        candidate.replaceAll(RegExp(r'\D'), '').padLeft(6, '0');
    return number.isNotEmpty && candidateDigits.endsWith(number);
  }
}

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

LotteryStockPricePatch? lotteryStockPricePatchFromRealtimeEvent(
  CustomerRealtimeEvent event,
) {
  if (event.name != 'stock.price.updated') return null;
  if (int.tryParse(event.payload['set_size']?.toString() ?? '1') != 1) {
    return null;
  }
  final price = _realtimePriceDisplayAmount(event.payload);
  if (price <= 0) return null;
  _lotteryStockPricePatchSequence += 1;
  return LotteryStockPricePatch(
    price: price,
    gameId: (event.payload['game_id'] ?? event.payload['gameId'] ?? '')
        .toString()
        .trim(),
    flashKey: _lotteryStockPricePatchSequence,
  );
}

LotteryStockAvailabilityPatch? lotteryStockAvailabilityPatchFromRealtimeEvent(
  CustomerRealtimeEvent event,
) {
  if (event.name != 'stock.availability.updated') return null;
  final number = _realtimeLotteryNumber(event.payload);
  if (number.isEmpty) return null;
  final remainingCount =
      int.tryParse(event.payload['remaining_count']?.toString() ?? '') ??
          int.tryParse(event.payload['available_count']?.toString() ?? '') ??
          0;
  final normalizedStatus = (event.payload['status'] ??
          event.payload['availability_status'] ??
          (remainingCount > 0 ? 'available' : 'sold_out'))
      .toString()
      .trim()
      .toLowerCase();
  _lotteryStockAvailabilityPatchSequence += 1;
  return LotteryStockAvailabilityPatch(
    number: number,
    remainingCount: remainingCount,
    status: normalizedStatus.isEmpty
        ? (remainingCount > 0 ? 'available' : 'sold_out')
        : normalizedStatus,
    gameId: (event.payload['game_id'] ?? event.payload['gameId'] ?? '')
        .toString()
        .trim(),
    flashKey: _lotteryStockAvailabilityPatchSequence,
  );
}

String _realtimeLotteryNumber(Map<String, Object?> payload) {
  final raw = (payload['full_number'] ??
          payload['number'] ??
          payload['lottery_number'] ??
          payload['fullNumber'] ??
          '')
      .toString();
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return '';
  return digits.length <= 6
      ? digits.padLeft(6, '0')
      : digits.substring(digits.length - 6);
}

double _realtimePriceDisplayAmount(Map<String, Object?> payload) {
  final price = payload['price'];
  final rawAmount = price is Map
      ? _numericPrice(price['amount'])
      : _numericPrice(payload['price_amount'] ?? payload['amount']);
  if (rawAmount == null || rawAmount <= 0) return 0;
  return rawAmount >= 1000 ? rawAmount / 100 : rawAmount;
}

double? _numericPrice(Object? value) {
  if (value is num && value.isFinite) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
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

    final pricePatch = lotteryStockPricePatchFromRealtimeEvent(event);
    if (pricePatch != null && pricePatch.matchesGame(gameId)) {
      ref.read(lotteryStockPricePatchProvider.notifier).state = pricePatch;
    }
    final availabilityPatch =
        lotteryStockAvailabilityPatchFromRealtimeEvent(event);
    if (availabilityPatch != null && availabilityPatch.matchesGame(gameId)) {
      ref.read(lotteryStockAvailabilityPatchProvider.notifier).state =
          availabilityPatch;
    }

    if (_refreshThrottle?.isActive ?? false) return;

    _refreshThrottle = Timer(const Duration(milliseconds: 750), () {
      if (!mounted) return;
      ref.read(lotteryStockRealtimeTickProvider.notifier).state++;
    });
  }
}
