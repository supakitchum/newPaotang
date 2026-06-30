import 'package:customer_flutter/core/auth/auth_token_store.dart';
import 'package:customer_flutter/core/auth/auth_controller.dart';
import 'package:customer_flutter/core/auth/auth_repository.dart';
import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/i18n/app_locale.dart';
import 'package:customer_flutter/core/i18n/customer_localizations.dart';
import 'package:customer_flutter/core/network/api_client.dart';
import 'package:customer_flutter/core/security/biometric_auth_service.dart';
import 'package:customer_flutter/core/theme/app_theme.dart';
import 'package:customer_flutter/features/activities/data/activity_models.dart';
import 'package:customer_flutter/features/activities/data/activity_repository.dart';
import 'package:customer_flutter/features/activities/presentation/activities_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('ActivitiesScreen renders current draw activities responsively', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _FakeActivityRepository();

    await _pumpActivities(tester, repository);
    await tester.pumpAndSettle();

    expect(repository.calls.single.history, isFalse);
    expect(find.text('กิจกรรมทายเลข 2 ตัว'), findsOneWidget);
    expect(find.text('คืนเงิน 5%'), findsOneWidget);
    expect(find.text('ทุก 10 ใบ ได้ 1 สิทธิ์'), findsOneWidget);
    expect(find.text('ซื้อครบ 50 ใบ รับเงินคืน 5%'), findsOneWidget);
    expect(find.text('กิจกรรมงวดย้อนหลัง'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final luckyCard = find.ancestor(
      of: find.text('กิจกรรมทายเลข 2 ตัว'),
      matching: find.byType(Card),
    );
    final cardRect = tester.getRect(luckyCard.first);

    expect(cardRect.width, lessThanOrEqualTo(920));
    expect(cardRect.left, greaterThanOrEqualTo(140));
    expect(cardRect.right, lessThanOrEqualTo(1060));
  });

  testWidgets('ActivitiesScreen exposes Nuxt-style header back to home', (
    tester,
  ) async {
    await _pumpActivities(tester, _FakeActivityRepository());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('ย้อนกลับ'));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('ActivitiesScreen uses Nuxt current loading copy', (
    tester,
  ) async {
    await _pumpActivities(tester, _FakeActivityRepository());
    await tester.pump();

    expect(find.text('กำลังโหลดกิจกรรม'), findsOneWidget);
  });

  testWidgets('ActivitiesScreen keeps compact cards usable on small phones', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpActivities(tester, _FakeActivityRepository());
    await tester.pumpAndSettle();

    expect(find.text('กิจกรรมทายเลข 2 ตัว'), findsOneWidget);
    expect(find.text('คืนเงิน 5%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ActivitiesScreen opens previous draw activity history', (
    tester,
  ) async {
    final repository = _FakeActivityRepository();

    await _pumpActivities(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.text('กิจกรรมงวดย้อนหลัง'));
    await tester.pumpAndSettle();

    expect(find.text('กลับไปกิจกรรมงวดปัจจุบัน'), findsOneWidget);
    expect(
      repository.calls.map((call) => call.history),
      containsAllInOrder([false, true]),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('ActivitiesHistoryScreen exposes Nuxt-style header back', (
    tester,
  ) async {
    final repository = _FakeActivityRepository();

    await _pumpActivities(
      tester,
      repository,
      initialLocation: '/activities/history',
    );
    await tester.pumpAndSettle();

    expect(find.text('กลับไปกิจกรรมงวดปัจจุบัน'), findsOneWidget);

    await tester.tap(find.byTooltip('ย้อนกลับ'));
    await tester.pumpAndSettle();

    expect(find.text('กิจกรรมทายเลข 2 ตัว'), findsOneWidget);
    expect(
      repository.calls.map((call) => call.history),
      containsAllInOrder([true, false]),
    );
  });

  testWidgets('ActivitiesScreen sorts authenticated activity rights first', (
    tester,
  ) async {
    final repository = _FakeActivityRepository(
      items: [_cashbackWithoutRightFixture, _activityFixtures.first],
    );

    await _pumpActivities(
      tester,
      repository,
      authController: _authenticatedController(),
    );
    await tester.pumpAndSettle();

    expect(repository.calls.single.authenticated, isTrue);

    final luckyTop = tester.getTopLeft(find.text('กิจกรรมทายเลข 2 ตัว')).dy;
    final cashbackTop = tester.getTopLeft(find.text('คืนเงิน 5%')).dy;

    expect(luckyTop, lessThan(cashbackTop));
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpActivities(
  WidgetTester tester,
  ActivityRepository repository, {
  AuthController? authController,
  String initialLocation = '/activities',
}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/activities',
        builder: (context, state) => const ActivitiesScreen(),
      ),
      GoRoute(
        path: '/activities/history',
        builder: (context, state) => const ActivitiesHistoryScreen(),
      ),
      GoRoute(
        path: '/activities/:slug',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Activity detail')),
        ),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Home')),
        ),
      ),
      GoRoute(
        path: '/tickets',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Tickets')),
        ),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Profile')),
        ),
      ),
    ],
  );

  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(
            apiBaseUrl: 'https://partner.example.test/api/v1',
            defaultLocale: 'th-TH',
          ),
        ),
        authTokenStoreProvider.overrideWithValue(AuthTokenStore()),
        activityRepositoryProvider.overrideWithValue(repository),
        if (authController != null)
          authControllerProvider.overrideWith((_) => authController),
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
}

class _FakeActivityRepository extends ActivityRepository {
  _FakeActivityRepository({List<ActivityItem>? items})
      : _items = items ?? _activityFixtures,
        super(_testApiClient(), (value) => value);

  final calls = <_ActivityCall>[];
  final List<ActivityItem> _items;

  @override
  Future<ActivityListPage> listPage({
    int limit = ActivityRepository.defaultPageLimit,
    String cursor = '',
    bool authenticated = false,
    bool history = false,
    String gameId = '',
  }) async {
    calls.add(
      _ActivityCall(
        authenticated: authenticated,
        history: history,
        gameId: gameId,
      ),
    );
    return ActivityListPage(
      items: _items,
      meta: const ActivityListMeta(
        hasHistory: true,
        hasMore: false,
        nextCursor: null,
        selectedGameId: 'game_current',
        games: [
          ActivityGameOption(id: 'game_current', label: 'งวดปัจจุบัน'),
          ActivityGameOption(id: 'game_prev', label: 'งวดย้อนหลัง'),
        ],
      ),
    );
  }
}

AuthController _authenticatedController() {
  final tokenStore = AuthTokenStore();
  final api = _testApiClient(tokenStore);
  return AuthController(
    authRepository: AuthRepository(api: api, tokenStore: tokenStore),
    tokenStore: tokenStore,
    biometricAuth: BiometricAuthService(api),
  )
    ..isAuthenticated = true
    ..pinRequired = false;
}

class _ActivityCall {
  const _ActivityCall({
    required this.authenticated,
    required this.history,
    required this.gameId,
  });

  final bool authenticated;
  final bool history;
  final String gameId;
}

final _activityFixtures = [
  ActivityItem(
    id: 'act_lucky',
    name: 'กิจกรรมทายเลข 2 ตัว',
    slug: 'lucky-board',
    type: 'lucky_board',
    imageUrl: '',
    conditionText: 'ทุก 10 ใบ ได้ 1 สิทธิ์',
    remainingNumbers: 97,
    hasRight: true,
    estimatedCashbackAmount: 0,
    rights: const ActivityRights(
      earnedCount: 2,
      usedCount: 0,
      remainingCount: 2,
      ticketCount: 20,
      availableTicketCount: 20,
      consumedTicketCount: 0,
      qualifyingOrderCount: 0,
      eligibilityRule: 'cumulative_tickets',
      thresholdTickets: 10,
      entryDeadlineAt: null,
      entryClosed: false,
    ),
    numberBoard: const ActivityNumberBoard(
      predictionType: 'last2',
      digits: 2,
      totalCount: 100,
      reservedCount: 3,
      remainingCount: 97,
      reservedNumbers: {'01', '02', '03'},
    ),
  ),
  const ActivityItem(
    id: 'act_cashback',
    name: 'คืนเงิน 5%',
    slug: 'cashback-5',
    type: 'cashback',
    imageUrl: '',
    conditionText: 'ซื้อครบ 50 ใบ รับเงินคืน 5%',
    remainingNumbers: 0,
    hasRight: true,
    estimatedCashbackAmount: 250,
    cashbackProgress: ActivityCashbackProgress(
      ticketCount: 52,
      purchaseAmount: 4160,
      minimumType: 'tickets',
      minTicketCount: 50,
      minPurchaseAmount: 0,
      isEligible: true,
      estimatedAmount: 250,
      potentialAmount: 250,
    ),
  ),
];

const _cashbackWithoutRightFixture = ActivityItem(
  id: 'act_cashback_no_right',
  name: 'คืนเงิน 5%',
  slug: 'cashback-5',
  type: 'cashback',
  imageUrl: '',
  conditionText: 'ซื้อครบ 50 ใบ รับเงินคืน 5%',
  remainingNumbers: 0,
  hasRight: false,
  estimatedCashbackAmount: 0,
  cashbackProgress: ActivityCashbackProgress(
    ticketCount: 12,
    purchaseAmount: 960,
    minimumType: 'tickets',
    minTicketCount: 50,
    minPurchaseAmount: 0,
    isEligible: false,
    estimatedAmount: 0,
    potentialAmount: 0,
  ),
);

ApiClient _testApiClient([AuthTokenStore? tokenStore]) {
  return ApiClient(
    const AppConfig(
      apiBaseUrl: 'https://partner.example.test/api/v1',
      defaultLocale: 'th-TH',
    ),
    tokenStore ?? AuthTokenStore(),
    localeTag: 'th-TH',
  );
}
