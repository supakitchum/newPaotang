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
import 'package:customer_flutter/features/activity_claims/data/activity_claim_models.dart';
import 'package:customer_flutter/features/activity_claims/data/activity_claim_repository.dart';
import 'package:customer_flutter/features/reward_claims/presentation/claim_realtime_monitor.dart';
import 'package:customer_flutter/features/tickets/data/ticket_models.dart';
import 'package:customer_flutter/features/tickets/data/ticket_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('claim realtime extracts object-scalar claim and ticket aliases', () {
    final payload = {
      'rewardClaim': {
        'claimId': {'value': 'rcl_object'},
        'orderItems': [
          {
            'ticket': {
              'id': {'key': 'tic_order_item'},
            },
          },
        ],
      },
    };

    expect(claimIdFromRealtimePayload(payload), 'rcl_object');
    expect(
      ticketIdFromRewardClaimRealtimePayload(payload),
      'tic_order_item',
    );
    expect(
      claimIdFromRealtimePayload({
        'activityAward': {
          'id': 'award_not_claim',
          'claim': {
            'activityClaimId': {'code': 'acl_award_claim'},
          },
        },
      }),
      'acl_award_claim',
    );
    expect(
      claimIdFromRealtimePayload({
        'activityAward': {'id': 'award_not_claim'},
      }),
      isNull,
    );
  });

  testWidgets('claim realtime refreshes ticket providers for reward changes',
      (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    final tokenStore = AuthTokenStore();
    await tokenStore.save(
      accessToken: 'access',
      refreshToken: 'refresh',
      customerId: 'cus_claim',
    );
    final client = _FakeRealtimeClient();
    final controller = _authController(tokenStore: tokenStore)
      ..isAuthenticated = true
      ..pinRequired = false;
    var currentTicketLoads = 0;
    var ticketDetailLoads = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authTokenStoreProvider.overrideWithValue(tokenStore),
          authControllerProvider.overrideWith((_) => controller),
          mobileBootstrapProvider.overrideWith((_) async => _bootstrap()),
          customerRealtimeClientFactoryProvider.overrideWithValue(
            (_) => client,
          ),
          currentTicketsProvider.overrideWith((_) async {
            currentTicketLoads += 1;
            return [_ticket('tic_claim')];
          }),
          ticketDetailProvider('tic_claim').overrideWith((_) async {
            ticketDetailLoads += 1;
            return _ticket('tic_claim');
          }),
        ],
        child: _ClaimRealtimeHarness(
          currentLoads: () => currentTicketLoads,
          detailLoads: () => ticketDetailLoads,
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('tickets:1 detail:1 reward:0'), findsOneWidget);

    client.emit(
      CustomerRealtimeEvent(
        name: 'reward.claim.updated',
        channel: customerRewardClaimChannel(
          tenantId: 'ten_claim',
          customerId: 'cus_claim',
        ),
        payload: const {
          'claim_id': 'rcl_1',
          'claim': {
            'id': 'rcl_1',
            'ticket': {'id': 'tic_claim'},
          },
        },
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    expect(find.text('tickets:2 detail:2 reward:1'), findsOneWidget);
  });

  testWidgets('claim realtime refreshes activity claim detail from award rows',
      (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    final tokenStore = AuthTokenStore();
    await tokenStore.save(
      accessToken: 'access',
      refreshToken: 'refresh',
      customerId: 'cus_claim',
    );
    final client = _FakeRealtimeClient();
    final controller = _authController(tokenStore: tokenStore)
      ..isAuthenticated = true
      ..pinRequired = false;
    var detailLoads = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authTokenStoreProvider.overrideWithValue(tokenStore),
          authControllerProvider.overrideWith((_) => controller),
          mobileBootstrapProvider.overrideWith((_) async => _bootstrap()),
          customerRealtimeClientFactoryProvider.overrideWithValue(
            (_) => client,
          ),
          activityClaimDetailProvider('acl_award_claim')
              .overrideWith((_) async {
            detailLoads += 1;
            return _activityClaim('acl_award_claim');
          }),
        ],
        child: _ActivityClaimRealtimeHarness(
          detailLoads: () => detailLoads,
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('activity:1 tick:0'), findsOneWidget);

    client.emit(
      CustomerRealtimeEvent(
        name: 'activity.claim.paid',
        channel: customerActivityClaimChannel(
          tenantId: 'ten_claim',
          customerId: 'cus_claim',
        ),
        payload: const {
          'activityAward': {
            'id': 'award_not_claim',
            'claim': {
              'activityClaimId': {'value': 'acl_award_claim'},
            },
          },
        },
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    expect(find.text('activity:2 tick:1'), findsOneWidget);
  });
}

class _ClaimRealtimeHarness extends ConsumerWidget {
  const _ClaimRealtimeHarness({
    required this.currentLoads,
    required this.detailLoads,
  });

  final int Function() currentLoads;
  final int Function() detailLoads;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(currentTicketsProvider);
    ref.watch(ticketDetailProvider('tic_claim'));
    final rewardTick = ref.watch(rewardClaimRealtimeTickProvider);

    return MaterialApp(
      home: CustomerClaimRealtimeMonitor(
        child: Text(
          'tickets:${currentLoads()} detail:${detailLoads()} reward:$rewardTick',
          textDirection: TextDirection.ltr,
        ),
      ),
    );
  }
}

class _ActivityClaimRealtimeHarness extends ConsumerWidget {
  const _ActivityClaimRealtimeHarness({required this.detailLoads});

  final int Function() detailLoads;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(activityClaimDetailProvider('acl_award_claim'));
    final tick = ref.watch(activityClaimRealtimeTickProvider);

    return MaterialApp(
      home: CustomerClaimRealtimeMonitor(
        child: Text(
          'activity:${detailLoads()} tick:$tick',
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

  @override
  Stream<CustomerRealtimeEvent> get events => _events.stream;

  @override
  Future<void> connect(Iterable<String> channels) async {}

  @override
  void updateChannels(Iterable<String> channels) {}

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
    'tenant_id': 'ten_claim',
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

ActivityClaimItem _activityClaim(String id) {
  return ActivityClaimItem(
    id: id,
    reference: 'ACT-REALTIME',
    customerName: 'Customer',
    activityName: 'Activity',
    award: const ActivityClaimAward(
      id: 'award_not_claim',
      activityName: 'Activity',
      type: 'cashback',
      predictionType: '',
      amount: 100,
    ),
    type: 'cashback',
    predictionType: '',
    amount: 100,
    status: ActivityClaimStatus.paid,
    statusRaw: 'paid',
    payoutMethod: 'wallet_credit',
    payoutLedgerId: 'ledger_activity',
    bankName: '',
    bankAccountNumber: '',
    walletName: 'G Wallet',
    submittedAt: '',
    reviewedAt: '',
    paidAt: '2026-07-01T10:00:00+07:00',
    createdAt: '',
    customerNote: '',
    adminNote: '',
  );
}

CustomerTicket _ticket(String id) {
  return CustomerTicket(
    id: id,
    gameId: 'game_claim',
    gameName: '',
    drawAt: null,
    drawNumber: '',
    setNumber: '',
    number: '123456',
    status: 'winning',
    rewardStatus: const TicketRewardStatus(
      status: 'winning',
      claimStatus: 'submitted',
      claimable: false,
      prizeType: '',
      prizeNumber: '',
      prizeAmount: 0,
      prizes: [],
      rewardClaimId: 'rcl_1',
      payoutMethod: '',
      adminNote: '',
    ),
    count: 1,
    prizes: const [],
    prizeAmount: 0,
    claimable: false,
    rewardClaimId: 'rcl_1',
    imageUrl: '',
    imageThumbUrl: '',
    previewImageUrl: '',
    imageStatus: '',
    imageError: '',
  );
}
