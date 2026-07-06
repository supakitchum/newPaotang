import 'dart:async';

import 'package:customer_flutter/core/auth/auth_token_store.dart';
import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/network/api_client.dart';
import 'package:customer_flutter/core/realtime/customer_realtime_client.dart';
import 'package:customer_flutter/core/realtime/customer_realtime_monitor.dart';
import 'package:customer_flutter/core/realtime/customer_realtime_protocol.dart';
import 'package:customer_flutter/core/tenant/mobile_bootstrap_controller.dart';
import 'package:customer_flutter/features/lottery/data/lottery_repository.dart';
import 'package:customer_flutter/features/lottery/presentation/lottery_stock_realtime_monitor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lottery stock realtime price patch parses Nuxt payload shapes', () {
    final moneyPatch = lotteryStockPricePatchFromRealtimeEvent(
      CustomerRealtimeEvent(
        name: 'stock.price.updated',
        channel: salePriceChannel(tenantId: 'ten_stock'),
        payload: const {
          'game_id': 'game_1',
          'set_size': 1,
          'price': {'amount': 9000},
        },
      ),
    );

    expect(moneyPatch, isNotNull);
    expect(moneyPatch!.gameId, 'game_1');
    expect(moneyPatch.price, 90);

    final legacyPatch = lotteryStockPricePatchFromRealtimeEvent(
      CustomerRealtimeEvent(
        name: 'SalePriceUpdated',
        channel: salePriceChannel(tenantId: 'ten_stock'),
        payload: const {'priceAmount': 7500},
      ),
    );

    expect(legacyPatch, isNotNull);
    expect(legacyPatch!.price, 75);

    final wrappedPatch = lotteryStockPricePatchFromRealtimeEvent(
      CustomerRealtimeEvent(
        name: 'sync.outbox',
        channel: salePriceChannel(tenantId: 'ten_stock'),
        payload: const {
          'payload':
              '{"event_type":"stock.price.updated","game":{"id":"game_wrapped"},"priceAmount":8800}',
        },
      ),
    );

    expect(wrappedPatch, isNotNull);
    expect(wrappedPatch!.gameId, 'game_wrapped');
    expect(wrappedPatch.price, 88);

    expect(
      lotteryStockPricePatchFromRealtimeEvent(
        CustomerRealtimeEvent(
          name: 'stock.price.updated',
          channel: salePriceChannel(tenantId: 'ten_stock'),
          payload: const {'set_size': 2, 'price_amount': 9000},
        ),
      ),
      isNull,
    );
  });

  test('lottery stock realtime parses object-scalar provider rows', () {
    final pricePatch = lotteryStockPricePatchFromRealtimeEvent(
      CustomerRealtimeEvent(
        name: 'stock.price.updated',
        channel: salePriceChannel(tenantId: 'ten_stock'),
        payload: const {
          'game': {'value': 'game_scalar'},
          'setSize': {'value': '1'},
          'salePrice': {
            'amount': {'value': '9100'},
          },
        },
      ),
    );

    expect(pricePatch, isNotNull);
    expect(pricePatch!.gameId, 'game_scalar');
    expect(pricePatch.price, 91);

    final availabilityPatch = lotteryStockAvailabilityPatchFromRealtimeEvent(
      CustomerRealtimeEvent(
        name: 'stock.availability.updated',
        channel: stockAvailabilityChannel(
          tenantId: 'ten_stock',
          gameId: 'game_scalar',
        ),
        payload: const {
          'game': {'key': 'game_scalar'},
          'fullNumber': {'value': '12345'},
          'availableCount': {'value': '4'},
          'availabilityStatus': {'code': 'available'},
        },
      ),
    );

    expect(availabilityPatch, isNotNull);
    expect(availabilityPatch!.gameId, 'game_scalar');
    expect(availabilityPatch.number, '012345');
    expect(availabilityPatch.remainingCount, 4);
    expect(availabilityPatch.status, 'available');
  });

  test('lottery stock realtime availability patch parses Nuxt payload', () {
    final patch = lotteryStockAvailabilityPatchFromRealtimeEvent(
      CustomerRealtimeEvent(
        name: 'stock_availability_updated',
        channel: stockAvailabilityChannel(
          tenantId: 'ten_stock',
          gameId: 'game_1',
        ),
        payload: const {
          'gameId': 'game_1',
          'fullNumber': '273707',
          'availableCount': 0,
          'availabilityStatus': 'sold_out',
        },
      ),
    );

    expect(patch, isNotNull);
    expect(patch!.number, '273707');
    expect(patch.remainingCount, 0);
    expect(patch.status, 'sold_out');
    expect(patch.matchesGame('game_1'), isTrue);
    expect(patch.matchesNumber('273707'), isTrue);
    expect(patch.matchesNumber('999999'), isFalse);

    final wrappedPatch = lotteryStockAvailabilityPatchFromRealtimeEvent(
      CustomerRealtimeEvent(
        name: 'bridge.message',
        channel: stockAvailabilityChannel(
          tenantId: 'ten_stock',
          gameId: 'game_1',
        ),
        payload: const {
          'eventPayload':
              '{"eventName":"stock.availability.updated","gameId":"game_1","fullNumber":"000123","remaining":3}',
        },
      ),
    );

    expect(wrappedPatch, isNotNull);
    expect(wrappedPatch!.number, '000123');
    expect(wrappedPatch.remainingCount, 3);
    expect(wrappedPatch.status, 'available');
  });

  testWidgets(
    'lottery stock realtime monitor subscribes and ticks on stock availability',
    (tester) async {
      final client = _FakeRealtimeClient();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mobileBootstrapProvider.overrideWith((_) async => _bootstrap()),
            currentGameIdProvider.overrideWith((_) async => 'game_1'),
            customerRealtimeClientFactoryProvider.overrideWithValue(
              (_) => client,
            ),
          ],
          child: const _StockRealtimeHarness(),
        ),
      );

      await tester.pumpAndSettle();

      expect(client.connectedChannels, hasLength(1));
      expect(client.connectedChannels.single, [
        stockAvailabilityChannel(tenantId: 'ten_stock', gameId: 'game_1'),
        salePriceChannel(tenantId: 'ten_stock'),
      ]);
      expect(find.text('tick:0'), findsOneWidget);

      client.emit(
        CustomerRealtimeEvent(
          name: 'topup.updated',
          channel: salePriceChannel(tenantId: 'ten_stock'),
          payload: const {'game_id': 'game_1'},
        ),
      );
      await tester.pump(const Duration(milliseconds: 800));

      expect(find.text('tick:0'), findsOneWidget);

      client.emit(
        CustomerRealtimeEvent(
          name: 'stock.availability.updated',
          channel: stockAvailabilityChannel(
            tenantId: 'ten_stock',
            gameId: 'game_1',
          ),
          payload: const {'game_id': 'game_2'},
        ),
      );
      await tester.pump(const Duration(milliseconds: 800));

      expect(find.text('tick:1'), findsOneWidget);
    },
  );

  testWidgets('lottery stock realtime monitor filters sale price by game', (
    tester,
  ) async {
    final client = _FakeRealtimeClient();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mobileBootstrapProvider.overrideWith((_) async => _bootstrap()),
          currentGameIdProvider.overrideWith((_) async => 'game_1'),
          customerRealtimeClientFactoryProvider.overrideWithValue(
            (_) => client,
          ),
        ],
        child: const _StockRealtimeHarness(),
      ),
    );

    await tester.pumpAndSettle();

    client.emit(
      CustomerRealtimeEvent(
        name: 'stock.price.updated',
        channel: salePriceChannel(tenantId: 'ten_stock'),
        payload: const {'game_id': 'game_2'},
      ),
    );
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('tick:0'), findsOneWidget);

    client.emit(
      CustomerRealtimeEvent(
        name: 'stock.price.updated',
        channel: salePriceChannel(tenantId: 'ten_stock'),
        payload: const {'game_id': 'game_1'},
      ),
    );
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('tick:1'), findsOneWidget);
  });

  testWidgets('lottery stock realtime monitor waits for a current game id', (
    tester,
  ) async {
    final client = _FakeRealtimeClient();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mobileBootstrapProvider.overrideWith((_) async => _bootstrap()),
          currentGameIdProvider.overrideWith((_) async => ''),
          customerRealtimeClientFactoryProvider.overrideWithValue(
            (_) => client,
          ),
        ],
        child: const _StockRealtimeHarness(),
      ),
    );

    await tester.pumpAndSettle();

    expect(client.connectedChannels, isEmpty);
    expect(find.text('tick:0'), findsOneWidget);
  });
}

class _StockRealtimeHarness extends ConsumerWidget {
  const _StockRealtimeHarness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tick = ref.watch(lotteryStockRealtimeTickProvider);

    return MaterialApp(
      home: LotteryStockRealtimeMonitor(
        child: Text('tick:$tick', textDirection: TextDirection.ltr),
      ),
    );
  }
}

class _FakeRealtimeClient extends CustomerRealtimeClient {
  _FakeRealtimeClient()
      : super(
          config: _realtimeConfig(),
          api: _apiClient(),
        );

  final StreamController<CustomerRealtimeEvent> _events =
      StreamController<CustomerRealtimeEvent>.broadcast();
  final List<List<String>> connectedChannels = [];
  final List<List<String>> updatedChannels = [];

  @override
  Stream<CustomerRealtimeEvent> get events => _events.stream;

  @override
  Future<void> connect(Iterable<String> channels) async {
    connectedChannels.add(channels.toList(growable: false));
  }

  @override
  void updateChannels(Iterable<String> channels) {
    updatedChannels.add(channels.toList(growable: false));
  }

  void emit(CustomerRealtimeEvent event) {
    _events.add(event);
  }

  @override
  Future<void> dispose() async {
    await _events.close();
  }
}

MobileBootstrap _bootstrap() {
  return MobileBootstrap.fromJson({
    'tenant_id': 'ten_stock',
    'mobile': {
      'realtime': {
        'enabled': true,
        'url': 'https://realtime.example.test',
        'key': 'customer-key',
      },
    },
  });
}

MobileRealtimeConfig _realtimeConfig() {
  return MobileRealtimeConfig.fromJson({
    'enabled': true,
    'url': 'https://realtime.example.test',
    'key': 'customer-key',
  });
}

ApiClient _apiClient() {
  return ApiClient(
    const AppConfig(
      apiBaseUrl: 'https://partner.example.test/api/v1',
      defaultLocale: 'th-TH',
    ),
    AuthTokenStore(),
    localeTag: 'th-TH',
  );
}
