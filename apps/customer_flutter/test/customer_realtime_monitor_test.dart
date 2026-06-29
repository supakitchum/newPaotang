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
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
        name: 'site-config.updated',
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

AuthController _authController() {
  final tokenStore = AuthTokenStore();
  final api = _apiClient(tokenStore: tokenStore);

  return AuthController(
    authRepository: AuthRepository(api: api, tokenStore: tokenStore),
    tokenStore: tokenStore,
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
