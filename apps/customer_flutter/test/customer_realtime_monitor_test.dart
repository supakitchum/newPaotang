import 'dart:async';

import 'package:customer_flutter/core/auth/auth_controller.dart';
import 'package:customer_flutter/core/auth/auth_repository.dart';
import 'package:customer_flutter/core/auth/auth_token_store.dart';
import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/network/api_client.dart';
import 'package:customer_flutter/core/realtime/customer_presence_controller.dart';
import 'package:customer_flutter/core/realtime/customer_realtime_client.dart';
import 'package:customer_flutter/core/realtime/customer_realtime_monitor.dart';
import 'package:customer_flutter/core/realtime/customer_realtime_protocol.dart';
import 'package:customer_flutter/core/security/biometric_auth_service.dart';
import 'package:customer_flutter/core/tenant/mobile_bootstrap_controller.dart';
import 'package:customer_flutter/features/topup/presentation/topup_realtime_monitor.dart';
import 'package:customer_flutter/features/wallet/data/wallet_models.dart';
import 'package:customer_flutter/features/wallet/data/wallet_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('realtime monitor subscribes channels and refreshes bootstrap',
      (tester) async {
    var bootstrapLoads = 0;
    final client = _FakeRealtimeClient();
    final controller = _authController()..isAuthenticated = true;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith((_) => controller),
          mobileBootstrapProvider.overrideWith((_) async {
            bootstrapLoads += 1;
            return _bootstrap();
          }),
          customerRealtimeClientFactoryProvider
              .overrideWithValue((_) => client),
        ],
        child: const _RealtimeHarness(),
      ),
    );

    await tester.pumpAndSettle();

    expect(client.connectedChannels, hasLength(1));
    expect(
      client.connectedChannels.single,
      containsAll([
        siteConfigChannel(tenantId: 'ten_realtime'),
        customerPresenceChannel(tenantId: 'ten_realtime'),
      ]),
    );
    expect(bootstrapLoads, 1);

    client.emit(
      CustomerRealtimeEvent(
        name: 'TenantSiteConfigUpdated',
        channel: siteConfigChannel(tenantId: 'ten_realtime'),
        payload: const {'reason': 'maintenance'},
      ),
    );
    await tester.pumpAndSettle();

    expect(bootstrapLoads, 2);
  });

  testWidgets('realtime monitor syncs customer presence count', (tester) async {
    final client = _FakeRealtimeClient();
    final controller = _authController()..isAuthenticated = true;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith((_) => controller),
          mobileBootstrapProvider.overrideWith((_) async => _bootstrap()),
          customerRealtimeClientFactoryProvider
              .overrideWithValue((_) => client),
        ],
        child: const _RealtimeHarness(),
      ),
    );
    await tester.pumpAndSettle();

    client.emit(
      CustomerRealtimeEvent(
        name: 'pusher_internal:subscription_succeeded',
        channel: customerPresenceChannel(tenantId: 'ten_realtime'),
        payload: const {
          'presence': {
            'count': 2,
            'ids': ['cus_1', 'cus_2'],
          },
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('online:2'), findsOneWidget);

    client.emit(
      CustomerRealtimeEvent(
        name: 'pusher_internal:member_added',
        channel: customerPresenceChannel(tenantId: 'ten_realtime'),
        payload: const {'user_id': 'cus_3'},
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('online:3'), findsOneWidget);

    client.emit(
      CustomerRealtimeEvent(
        name: 'pusher_internal:member_removed',
        channel: customerPresenceChannel(tenantId: 'ten_realtime'),
        payload: const {'user_id': 'cus_2'},
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('online:2'), findsOneWidget);
  });

  testWidgets('topup realtime monitor subscribes topup and wallet channels',
      (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    final tokenStore = AuthTokenStore();
    await tokenStore.save(
      accessToken: 'access',
      refreshToken: 'refresh',
      customerId: 'cus_realtime',
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
          customerRealtimeClientFactoryProvider
              .overrideWithValue((_) => client),
        ],
        child: const MaterialApp(
          home: CustomerTopupRealtimeMonitor(
            child: Text('topup realtime', textDirection: TextDirection.ltr),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(client.connectedChannels, hasLength(1));
    expect(
      client.connectedChannels.single,
      containsAll([
        customerTopupChannel(
          tenantId: 'ten_realtime',
          customerId: 'cus_realtime',
        ),
        customerWalletChannel(
          tenantId: 'ten_realtime',
          customerId: 'cus_realtime',
        ),
      ]),
    );
    expect(client.connectedChannels.single, hasLength(2));
  });

  testWidgets('topup realtime monitor refreshes money on reconnect', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    final tokenStore = AuthTokenStore();
    await tokenStore.save(
      accessToken: 'access',
      refreshToken: 'refresh',
      customerId: 'cus_realtime',
    );
    final client = _FakeRealtimeClient();
    final controller = _authController(tokenStore: tokenStore)
      ..isAuthenticated = true
      ..pinRequired = false;
    var walletLoads = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authTokenStoreProvider.overrideWithValue(tokenStore),
          authControllerProvider.overrideWith((_) => controller),
          mobileBootstrapProvider.overrideWith((_) async => _bootstrap()),
          customerRealtimeClientFactoryProvider
              .overrideWithValue((_) => client),
          walletSummaryProvider.overrideWith((_) async {
            walletLoads++;
            return WalletSummary(
              wallets: [
                CustomerWallet(
                  id: 'wallet_1',
                  name: 'G Wallet',
                  type: '1',
                  balance: 1000 + walletLoads.toDouble(),
                ),
              ],
              ledger: const [],
            );
          }),
        ],
        child: const MaterialApp(
          home: CustomerTopupRealtimeMonitor(child: _WalletRefreshProbe()),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(walletLoads, 1);
    expect(find.text('balance:1001'), findsOneWidget);

    final channel = customerTopupChannel(
      tenantId: 'ten_realtime',
      customerId: 'cus_realtime',
    );
    client.emit(
      CustomerRealtimeEvent(
        name: 'pusher_internal:subscription_succeeded',
        channel: channel,
        payload: const {},
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();
    expect(walletLoads, 1);

    client.emit(
      CustomerRealtimeEvent(
        name: 'pusher_internal:subscription_succeeded',
        channel: channel,
        payload: const {},
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(walletLoads, 2);
    expect(find.text('balance:1002'), findsOneWidget);
  });
}

class _RealtimeHarness extends ConsumerWidget {
  const _RealtimeHarness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onlineCount =
        ref.watch(customerPresenceControllerProvider).onlineCount;

    return MaterialApp(
      home: CustomerRealtimeMonitor(
        child: Text('online:$onlineCount', textDirection: TextDirection.ltr),
      ),
    );
  }
}

class _WalletRefreshProbe extends ConsumerWidget {
  const _WalletRefreshProbe();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(walletSummaryProvider);
    final balance = summary.valueOrNull?.balance.toStringAsFixed(0) ?? '...';
    return Text('balance:$balance', textDirection: TextDirection.ltr);
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

AuthController _authController({AuthTokenStore? tokenStore}) {
  final store = tokenStore ?? AuthTokenStore();
  final api = _apiClient(tokenStore: store);

  return AuthController(
    authRepository: AuthRepository(api: api, tokenStore: store),
    tokenStore: store,
    biometricAuth: BiometricAuthService(api),
  );
}

MobileBootstrap _bootstrap() {
  return MobileBootstrap.fromJson({
    'tenant_id': 'ten_realtime',
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
