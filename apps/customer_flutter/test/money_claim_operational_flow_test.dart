import 'package:customer_flutter/core/auth/auth_token_store.dart';
import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/i18n/app_locale.dart';
import 'package:customer_flutter/core/i18n/customer_localizations.dart';
import 'package:customer_flutter/core/network/api_client.dart';
import 'package:customer_flutter/core/tenant/mobile_bootstrap_controller.dart';
import 'package:customer_flutter/core/theme/app_theme.dart';
import 'package:customer_flutter/features/activity_claims/data/activity_claim_models.dart';
import 'package:customer_flutter/features/activity_claims/data/activity_claim_repository.dart';
import 'package:customer_flutter/features/activity_claims/presentation/activity_claim_detail_screen.dart';
import 'package:customer_flutter/features/activity_claims/presentation/activity_claims_screen.dart';
import 'package:customer_flutter/features/reward_claims/data/reward_claim_models.dart';
import 'package:customer_flutter/features/reward_claims/data/reward_claim_repository.dart';
import 'package:customer_flutter/features/reward_claims/presentation/reward_claim_detail_screen.dart';
import 'package:customer_flutter/features/reward_claims/presentation/reward_claims_screen.dart';
import 'package:customer_flutter/features/tickets/data/ticket_models.dart';
import 'package:customer_flutter/features/tickets/data/ticket_repository.dart';
import 'package:customer_flutter/features/tickets/presentation/tickets_screen.dart';
import 'package:customer_flutter/features/topup/data/topup_repository.dart';
import 'package:customer_flutter/features/topup/presentation/topup_history_screen.dart';
import 'package:customer_flutter/features/topup/presentation/topup_screen.dart';
import 'package:customer_flutter/features/wallet/data/wallet_repository.dart';
import 'package:customer_flutter/features/wallet/presentation/wallet_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  for (final testCase in _providerLoadCases()) {
    testWidgets('${testCase.name} provider load follows maintenance redirect', (
      tester,
    ) async {
      final router = await _pumpOperationalRoute(tester, testCase);

      expect(find.text('Maintenance route'), findsOneWidget);
      expect(router.routeInformationProvider.value.uri.path, '/maintenance');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('ticket history load follows maintenance redirect', (
    tester,
  ) async {
    final router = await _pumpOperationalRoute(
      tester,
      _OperationalRouteCase(
        name: 'ticket history',
        initialLocation: '/tickets/history',
        routePattern: '/tickets/history',
        screen: const TicketHistoryScreen(),
        overrides: [
          ticketRepositoryProvider.overrideWithValue(
            _OperationalTicketRepository(_maintenanceError()),
          ),
        ],
      ),
    );

    expect(find.text('Maintenance route'), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, '/maintenance');
  });

  testWidgets('reward claim history returns through centralized PIN route', (
    tester,
  ) async {
    final router = await _pumpOperationalRoute(
      tester,
      _OperationalRouteCase(
        name: 'reward claim history',
        initialLocation: '/reward-claims',
        routePattern: '/reward-claims',
        screen: const RewardClaimsScreen(),
        overrides: [
          rewardClaimRepositoryProvider.overrideWithValue(
            _OperationalRewardClaimRepository(_pinRequiredError()),
          ),
        ],
      ),
    );

    final uri = router.routeInformationProvider.value.uri;
    expect(find.text('PIN route'), findsOneWidget);
    expect(uri.path, '/pin');
    expect(uri.queryParameters['redirect'], '/reward-claims');
  });

  testWidgets('activity claim history load follows maintenance redirect', (
    tester,
  ) async {
    final router = await _pumpOperationalRoute(
      tester,
      _OperationalRouteCase(
        name: 'activity claim history',
        initialLocation: '/activity-claims',
        routePattern: '/activity-claims',
        screen: const ActivityClaimsScreen(),
        overrides: [
          activityClaimRepositoryProvider.overrideWithValue(
            _OperationalActivityClaimRepository(_maintenanceError()),
          ),
        ],
      ),
    );

    expect(find.text('Maintenance route'), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, '/maintenance');
  });

  testWidgets('ticket claim optional loads do not swallow maintenance', (
    tester,
  ) async {
    final router = await _pumpOperationalRoute(
      tester,
      _OperationalRouteCase(
        name: 'ticket claim',
        initialLocation: '/tickets/claim/ticket_operational',
        routePattern: '/tickets/claim/:ticketId',
        screen: const TicketClaimScreen(
          ticketId: 'ticket_operational',
          fromHistory: false,
        ),
        overrides: [
          ticketRepositoryProvider.overrideWithValue(
            _OperationalTicketClaimRepository(_maintenanceError()),
          ),
        ],
      ),
    );

    expect(find.text('Maintenance route'), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, '/maintenance');
  });
}

List<_OperationalRouteCase> _providerLoadCases() {
  final maintenance = _maintenanceError();
  return [
    _OperationalRouteCase(
      name: 'wallet',
      initialLocation: '/my-wallet',
      routePattern: '/my-wallet',
      screen: const WalletScreen(),
      overrides: [
        walletSummaryProvider.overrideWith((_) async => throw maintenance),
      ],
    ),
    _OperationalRouteCase(
      name: 'topup',
      initialLocation: '/topup',
      routePattern: '/topup',
      screen: const TopupScreen(),
      overrides: [
        topupOverviewProvider.overrideWith((_) async => throw maintenance),
      ],
    ),
    _OperationalRouteCase(
      name: 'topup detail',
      initialLocation: '/topup/topup_operational',
      routePattern: '/topup/:topupId',
      screen: const TopupScreen(detailTopupId: 'topup_operational'),
      overrides: [
        topupDetailProvider('topup_operational')
            .overrideWith((_) async => throw maintenance),
      ],
    ),
    _OperationalRouteCase(
      name: 'topup history',
      initialLocation: '/topup/history',
      routePattern: '/topup/history',
      screen: const TopupHistoryScreen(),
      overrides: [
        topupHistoryProvider(1).overrideWith((_) async => throw maintenance),
      ],
    ),
    _OperationalRouteCase(
      name: 'current tickets',
      initialLocation: '/tickets',
      routePattern: '/tickets',
      screen: const TicketsScreen(),
      overrides: [
        currentTicketsProvider.overrideWith((_) async => throw maintenance),
      ],
    ),
    _OperationalRouteCase(
      name: 'ticket detail',
      initialLocation: '/tickets/view?id=ticket_operational',
      routePattern: '/tickets/view',
      screen: const TicketViewScreen(
        ticketId: 'ticket_operational',
        ticketNumber: '',
        orderId: '',
        gameId: '',
        fromHistory: false,
      ),
      overrides: [
        ticketRepositoryProvider.overrideWithValue(
          _OperationalTicketRepository(maintenance),
        ),
      ],
    ),
    _OperationalRouteCase(
      name: 'reward claim detail',
      initialLocation: '/reward-claims/reward_operational',
      routePattern: '/reward-claims/:claimId',
      screen: const RewardClaimDetailScreen(claimId: 'reward_operational'),
      overrides: [
        rewardClaimDetailProvider('reward_operational')
            .overrideWith((_) async => throw maintenance),
      ],
    ),
    _OperationalRouteCase(
      name: 'activity claim detail',
      initialLocation: '/activity-claims/activity_operational',
      routePattern: '/activity-claims/:claimId',
      screen: const ActivityClaimDetailScreen(claimId: 'activity_operational'),
      overrides: [
        activityClaimDetailProvider('activity_operational')
            .overrideWith((_) async => throw maintenance),
      ],
    ),
  ];
}

Future<GoRouter> _pumpOperationalRoute(
  WidgetTester tester,
  _OperationalRouteCase testCase,
) async {
  final router = GoRouter(
    initialLocation: testCase.initialLocation,
    routes: [
      GoRoute(
        path: testCase.routePattern,
        builder: (_, __) => testCase.screen,
      ),
      GoRoute(
        path: '/maintenance',
        builder: (_, __) => const Scaffold(
          body: Center(child: Text('Maintenance route')),
        ),
      ),
      GoRoute(
        path: '/pin',
        builder: (_, __) => const Scaffold(
          body: Center(child: Text('PIN route')),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mobileBootstrapProvider.overrideWith(
          (_) async => MobileBootstrap.fromJson(const {}),
        ),
        ...testCase.overrides,
      ],
      child: MaterialApp.router(
        locale: fallbackCustomerLocale,
        supportedLocales: supportedCustomerLocales,
        localizationsDelegates: const [
          CustomerLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.light(),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

class _OperationalRouteCase {
  const _OperationalRouteCase({
    required this.name,
    required this.initialLocation,
    required this.routePattern,
    required this.screen,
    required this.overrides,
  });

  final String name;
  final String initialLocation;
  final String routePattern;
  final Widget screen;
  final List<Override> overrides;
}

class _OperationalTicketRepository extends TicketRepository {
  _OperationalTicketRepository(this.error) : super(_testApiClient());

  final Object error;

  @override
  Future<List<CustomerTicket>> currentAll({
    int limit = TicketRepository.defaultPageLimit,
    int maxPages = TicketRepository.maxAutoPages,
  }) async {
    throw error;
  }

  @override
  Future<TicketPage> history({
    int limit = 20,
    String? cursor,
    String? gameId,
  }) async {
    throw error;
  }

  @override
  Future<CustomerTicket> detail(String id) async {
    throw error;
  }
}

class _OperationalTicketClaimRepository extends TicketRepository {
  _OperationalTicketClaimRepository(this.error) : super(_testApiClient());

  final Object error;

  @override
  Future<CustomerTicket> detail(String id) async {
    return CustomerTicket.fromJson(const {
      'id': 'ticket_operational',
      'game_id': 'game_operational',
      'full_number': '123456',
      'status': 'won',
      'reward_status': {
        'status': 'won',
        'claimable': true,
        'prize_amount': {'amount': 200000},
      },
    });
  }

  @override
  Future<TicketRewardStatus> rewardStatus(String id) async {
    throw error;
  }
}

class _OperationalRewardClaimRepository extends RewardClaimRepository {
  _OperationalRewardClaimRepository(this.error) : super(_testApiClient());

  final Object error;

  @override
  Future<RewardClaimPage> list({int limit = 20, String? cursor}) async {
    throw error;
  }
}

class _OperationalActivityClaimRepository extends ActivityClaimRepository {
  _OperationalActivityClaimRepository(this.error) : super(_testApiClient());

  final Object error;

  @override
  Future<ActivityClaimPage> list({int limit = 20, String? cursor}) async {
    throw error;
  }
}

DioException _maintenanceError() {
  return _operationalError(
    code: 'maintenance_active',
    message: 'ร้านค้าปิดปรับปรุงชั่วคราว',
    statusCode: 503,
  );
}

DioException _pinRequiredError() {
  return _operationalError(
    code: 'pin_required',
    message: 'กรุณายืนยัน PIN',
    statusCode: 403,
  );
}

DioException _operationalError({
  required String code,
  required String message,
  required int statusCode,
}) {
  final request = RequestOptions(path: '/customer/operational-test');
  return DioException(
    requestOptions: request,
    response: Response<Map<String, dynamic>>(
      requestOptions: request,
      statusCode: statusCode,
      data: {
        'code': code,
        'message': message,
      },
    ),
  );
}

ApiClient _testApiClient() {
  return ApiClient(
    const AppConfig(
      apiBaseUrl: 'https://partner.example.test/api/v1',
      defaultLocale: 'th-TH',
    ),
    AuthTokenStore(),
    localeTag: 'th-TH',
  );
}
