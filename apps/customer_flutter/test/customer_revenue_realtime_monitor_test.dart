import 'dart:async';

import 'package:customer_flutter/core/auth/auth_controller.dart';
import 'package:customer_flutter/core/auth/auth_repository.dart';
import 'package:customer_flutter/core/auth/auth_token_store.dart';
import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/network/api_client.dart';
import 'package:customer_flutter/core/realtime/customer_realtime_client.dart';
import 'package:customer_flutter/core/realtime/customer_realtime_monitor.dart';
import 'package:customer_flutter/core/realtime/customer_realtime_protocol.dart';
import 'package:customer_flutter/core/security/biometric_auth_service.dart';
import 'package:customer_flutter/core/tenant/mobile_bootstrap_controller.dart';
import 'package:customer_flutter/features/lottery/presentation/customer_revenue_realtime_monitor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('revenue realtime extracts ticket ids from order item aliases', () {
    expect(
      ticketIdsFromRealtimePayload({
        'orderItems': [
          {
            'ticket': {
              'id': {'value': 'tic_object'},
            },
          },
          {
            'customerTicketId': {'code': 'tic_customer'},
          },
        ],
        'items': [
          {
            'lotteryTicket': {'uuid': 'tic_lottery'},
          },
        ],
      }),
      {'tic_object', 'tic_customer', 'tic_lottery'},
    );
  });

  test('revenue realtime extracts order ids from supported aliases', () {
    expect(
      orderIdsFromRealtimePayload({
        'order_id': 'ord_direct',
        'checkoutOrder': {
          'id': {'value': 'ord_nested'},
        },
        'orders': [
          {'purchaseOrderId': 'ord_list'},
        ],
      }),
      {'ord_direct', 'ord_nested', 'ord_list'},
    );
  });

  testWidgets('revenue realtime monitor subscribes cart order ticket channels',
      (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    final tokenStore = AuthTokenStore();
    await tokenStore.save(
      accessToken: 'access',
      refreshToken: 'refresh',
      customerId: 'cus_revenue',
    );
    final client = _FakeRealtimeClient();
    final controller = _authController(tokenStore: tokenStore)
      ..isAuthenticated = true
      ..pinRequired = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authTokenStoreProvider.overrideWithValue(tokenStore),
          authControllerProvider.overrideWith((_) => controller),
          mobileBootstrapProvider.overrideWith((_) async => _bootstrap()),
          customerRealtimeClientFactoryProvider.overrideWithValue(
            (_) => client,
          ),
        ],
        child: const _RevenueRealtimeHarness(),
      ),
    );

    await tester.pumpAndSettle();

    expect(client.connectedChannels, hasLength(1));
    expect(
      client.connectedChannels.single,
      [
        customerCartChannel(
          tenantId: 'ten_revenue',
          customerId: 'cus_revenue',
        ),
        customerOrdersChannel(
          tenantId: 'ten_revenue',
          customerId: 'cus_revenue',
        ),
        customerTicketsChannel(
          tenantId: 'ten_revenue',
          customerId: 'cus_revenue',
        ),
      ],
    );
  });

  testWidgets('revenue realtime monitor ticks cart and tickets on events',
      (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    final tokenStore = AuthTokenStore();
    await tokenStore.save(
      accessToken: 'access',
      refreshToken: 'refresh',
      customerId: 'cus_revenue',
    );
    final client = _FakeRealtimeClient();
    final controller = _authController(tokenStore: tokenStore)
      ..isAuthenticated = true
      ..pinRequired = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authTokenStoreProvider.overrideWithValue(tokenStore),
          authControllerProvider.overrideWith((_) => controller),
          mobileBootstrapProvider.overrideWith((_) async => _bootstrap()),
          customerRealtimeClientFactoryProvider.overrideWithValue(
            (_) => client,
          ),
        ],
        child: const _RevenueRealtimeHarness(),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('cart:0 tickets:0 purchases:0'), findsOneWidget);

    client.emit(
      CustomerRealtimeEvent(
        name: 'reservation.expired.v1',
        channel: customerCartChannel(
          tenantId: 'ten_revenue',
          customerId: 'cus_revenue',
        ),
        payload: const {'reservation_id': 'res_1'},
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('cart:1 tickets:0 purchases:0'), findsOneWidget);

    client.emit(
      CustomerRealtimeEvent(
        name: 'order.paid.v1',
        channel: customerOrdersChannel(
          tenantId: 'ten_revenue',
          customerId: 'cus_revenue',
        ),
        payload: const {
          'order_id': 'ord_1',
          'ticket_ids': ['tic_1'],
        },
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('cart:2 tickets:1 purchases:1'), findsOneWidget);

    final ordersChannel = customerOrdersChannel(
      tenantId: 'ten_revenue',
      customerId: 'cus_revenue',
    );
    client.emit(
      CustomerRealtimeEvent(
        name: 'pusher_internal:subscription_succeeded',
        channel: ordersChannel,
        payload: const {},
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('cart:2 tickets:1 purchases:1'), findsOneWidget);

    client.emit(
      CustomerRealtimeEvent(
        name: 'pusher_internal:subscription_succeeded',
        channel: ordersChannel,
        payload: const {},
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('cart:3 tickets:2 purchases:2'), findsOneWidget);
  });
}

class _RevenueRealtimeHarness extends ConsumerWidget {
  const _RevenueRealtimeHarness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartTick = ref.watch(cartRealtimeTickProvider);
    final ticketTick = ref.watch(ticketRealtimeTickProvider);
    final purchaseTick = ref.watch(purchaseHistoryRefreshTickProvider);

    return MaterialApp(
      home: CustomerRevenueRealtimeMonitor(
        child: Text(
          'cart:$cartTick tickets:$ticketTick purchases:$purchaseTick',
          textDirection: TextDirection.ltr,
        ),
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

AuthController _authController({required AuthTokenStore tokenStore}) {
  final api = _apiClient(tokenStore: tokenStore);
  return AuthController(
    authRepository: AuthRepository(api: api, tokenStore: tokenStore),
    tokenStore: tokenStore,
    biometricAuth: BiometricAuthService(api),
  );
}

MobileBootstrap _bootstrap() {
  return MobileBootstrap.fromJson({
    'tenant_id': 'ten_revenue',
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

ApiClient _apiClient({AuthTokenStore? tokenStore}) {
  return ApiClient(
    const AppConfig(
      apiBaseUrl: 'https://partner.example.test/api/v1',
      defaultLocale: 'th-TH',
    ),
    tokenStore ?? AuthTokenStore(),
    localeTag: 'th-TH',
  );
}
