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
  final eventName = normalizeRealtimeEventNameWithPayload(
    eventName: event.name,
    payload: event.payload,
  );
  final normalizedGameId = gameId.trim();

  if (eventName == 'stock.availability.updated') {
    return true;
  }

  if (eventName != 'stock.price.updated') {
    return false;
  }

  final payload = normalizeRealtimePayload(event.payload);
  final payloadGameId = _realtimePayloadText(
    payload,
    const ['game_id', 'gameId', 'game', 'game_uuid', 'gameUuid'],
  );

  return payloadGameId.isEmpty ||
      normalizedGameId.isEmpty ||
      payloadGameId == normalizedGameId;
}

LotteryStockPricePatch? lotteryStockPricePatchFromRealtimeEvent(
  CustomerRealtimeEvent event,
) {
  if (normalizeRealtimeEventNameWithPayload(
        eventName: event.name,
        payload: event.payload,
      ) !=
      'stock.price.updated') {
    return null;
  }
  final payload = normalizeRealtimePayload(event.payload);
  final setSize = _realtimePayloadText(
    payload,
    const ['set_size', 'setSize', 'quantity', 'bundle_size', 'bundleSize'],
    fallback: '1',
  );
  if (int.tryParse(setSize) != 1) {
    return null;
  }
  final price = _realtimePriceDisplayAmount(payload);
  if (price <= 0) return null;
  _lotteryStockPricePatchSequence += 1;
  return LotteryStockPricePatch(
    price: price,
    gameId: _realtimePayloadText(
      payload,
      const ['game_id', 'gameId', 'game', 'game_uuid', 'gameUuid'],
    ),
    flashKey: _lotteryStockPricePatchSequence,
  );
}

LotteryStockAvailabilityPatch? lotteryStockAvailabilityPatchFromRealtimeEvent(
  CustomerRealtimeEvent event,
) {
  if (normalizeRealtimeEventNameWithPayload(
        eventName: event.name,
        payload: event.payload,
      ) !=
      'stock.availability.updated') {
    return null;
  }
  final payload = normalizeRealtimePayload(event.payload);
  final number = _realtimeLotteryNumber(payload);
  if (number.isEmpty) return null;
  final remainingCount = _realtimePayloadInt(
    payload,
    const [
      'remaining_count',
      'remainingCount',
      'available_count',
      'availableCount',
      'available',
      'remaining',
      'count',
    ],
  );
  final normalizedStatus = (_realtimePayloadText(
    payload,
    const ['status', 'availability_status', 'availabilityStatus'],
    fallback: remainingCount > 0 ? 'available' : 'sold_out',
  )).toString().trim().toLowerCase();
  _lotteryStockAvailabilityPatchSequence += 1;
  return LotteryStockAvailabilityPatch(
    number: number,
    remainingCount: remainingCount,
    status: normalizedStatus.isEmpty
        ? (remainingCount > 0 ? 'available' : 'sold_out')
        : normalizedStatus,
    gameId: _realtimePayloadText(
      payload,
      const ['game_id', 'gameId', 'game', 'game_uuid', 'gameUuid'],
    ),
    flashKey: _lotteryStockAvailabilityPatchSequence,
  );
}

String _realtimeLotteryNumber(Map<String, Object?> payload) {
  final raw = _realtimePayloadText(payload, const [
    'full_number',
    'fullNumber',
    'number',
    'lottery_number',
    'lotteryNumber',
    'lottery_no',
    'lotteryNo',
  ]);
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return '';
  return digits.length <= 6
      ? digits.padLeft(6, '0')
      : digits.substring(digits.length - 6);
}

double _realtimePriceDisplayAmount(Map<String, Object?> payload) {
  final price = payload['price'];
  final rawAmount = price is Map
      ? _numericPrice(
          price['amount'] ??
              price['value'] ??
              price['display_amount'] ??
              price['displayAmount'],
        )
      : _numericPrice(
          payload['price_amount'] ??
              payload['priceAmount'] ??
              payload['sale_price'] ??
              payload['salePrice'] ??
              payload['unit_price'] ??
              payload['unitPrice'] ??
              payload['amount'] ??
              payload['display_price'] ??
              payload['displayPrice'],
        );
  if (rawAmount == null || rawAmount <= 0) return 0;
  return rawAmount >= 1000 ? rawAmount / 100 : rawAmount;
}

String _realtimePayloadText(
  Map<String, Object?> payload,
  List<String> keys, {
  String fallback = '',
}) {
  for (final key in keys) {
    final value = payload[key];
    if (value == null) continue;
    final text = _realtimeScalarText(value);
    if (text.isNotEmpty) return text;
  }
  return fallback;
}

int _realtimePayloadInt(Map<String, Object?> payload, List<String> keys) {
  for (final key in keys) {
    final value = payload[key];
    if (value is num && value.isFinite) return value.toInt();
    final parsed = int.tryParse(_realtimeScalarText(value));
    if (parsed != null) return parsed;
  }
  return 0;
}

double? _numericPrice(Object? value) {
  if (value is num && value.isFinite) return value.toDouble();
  final scalar = _realtimeScalarText(value);
  if (scalar.isNotEmpty) return double.tryParse(scalar);
  return null;
}

String _realtimeScalarText(Object? value, [int depth = 0]) {
  if (value == null || depth > 3) return '';
  if (value is Map) {
    for (final key in const [
      'value',
      'code',
      'key',
      'id',
      'uuid',
      'game_id',
      'gameId',
      'amount',
    ]) {
      final nested = _realtimeScalarText(value[key], depth + 1);
      if (nested.isNotEmpty) return nested;
    }
    return '';
  }
  if (value is Iterable) {
    for (final item in value) {
      final nested = _realtimeScalarText(item, depth + 1);
      if (nested.isNotEmpty) return nested;
    }
    return '';
  }
  return value.toString().trim();
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
