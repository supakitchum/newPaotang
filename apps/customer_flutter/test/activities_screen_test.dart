import 'package:customer_flutter/core/auth/auth_token_store.dart';
import 'package:customer_flutter/core/auth/auth_controller.dart';
import 'package:customer_flutter/core/auth/auth_repository.dart';
import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/i18n/app_locale.dart';
import 'package:customer_flutter/core/i18n/customer_localizations.dart';
import 'package:customer_flutter/core/network/api_client.dart';
import 'package:customer_flutter/core/security/biometric_auth_service.dart';
import 'package:customer_flutter/core/tenant/mobile_bootstrap_controller.dart';
import 'package:customer_flutter/core/theme/app_theme.dart';
import 'package:customer_flutter/features/activities/data/activity_models.dart';
import 'package:customer_flutter/features/activities/data/activity_repository.dart';
import 'package:customer_flutter/features/activities/presentation/activities_screen.dart';
import 'package:dio/dio.dart';
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
    expect(find.text('ดูงวดที่แล้ว'), findsOneWidget);
    expect(find.text('แผงเลขนำโชค'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('ดูงวดที่แล้ว')).style?.color,
      const Color(0xFF0875DF),
    );
    expect(
      tester.widget<Text>(find.text('กิจกรรมทายเลข 2 ตัว')).style?.color,
      const Color(0xFF1F2937),
    );
    expect(
      tester.widget<Text>(find.text('ทุก 10 ใบ ได้ 1 สิทธิ์')).style?.color,
      const Color(0xFF6B7280),
    );
    expect(
      tester.widget<Text>(find.text('แผงเลขนำโชค')).style?.color,
      const Color(0xFF0875DF),
    );
    expect(tester.takeException(), isNull);

    final titleRect = tester.getRect(find.text('กิจกรรมทายเลข 2 ตัว'));

    expect(titleRect.left, greaterThanOrEqualTo(140));
    expect(titleRect.right, lessThanOrEqualTo(1060));
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

  testWidgets('ActivitiesScreen redirects PIN-required users before loading', (
    tester,
  ) async {
    final repository = _FakeActivityRepository();

    await _pumpActivities(
      tester,
      repository,
      authController: _pinRequiredController(),
    );
    await tester.pumpAndSettle();

    expect(repository.calls, isEmpty);
    expect(find.text('Pin redirect: /activities'), findsOneWidget);
  });

  testWidgets('ActivitiesHistoryScreen preserves game query through PIN', (
    tester,
  ) async {
    final repository = _FakeActivityRepository();

    await _pumpActivities(
      tester,
      repository,
      authController: _pinRequiredController(setupRequired: true),
      initialLocation: '/activities/history?game_id=game_prev',
    );
    await tester.pumpAndSettle();

    expect(repository.calls, isEmpty);
    expect(
      find.text('Pin redirect: /activities/history?game_id=game_prev'),
      findsOneWidget,
    );
  });

  testWidgets('ActivitiesScreen uses Nuxt current loading copy', (
    tester,
  ) async {
    await _pumpActivities(tester, _FakeActivityRepository());
    await tester.pump();

    expect(find.text('กำลังโหลดกิจกรรม'), findsOneWidget);
    expect(
      find.byKey(const Key('activities-loading-progress')),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('ActivitiesScreen error uses API copy when available', (
    tester,
  ) async {
    await _pumpActivities(
      tester,
      _FakeActivityRepository(
        error: _apiException('ระบบกิจกรรมปิดปรับปรุง'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ระบบกิจกรรมปิดปรับปรุง'), findsOneWidget);
    expect(find.text('โหลดกิจกรรมไม่สำเร็จ'), findsNothing);
    expect(find.text('ยังไม่มีกิจกรรมในงวดนี้'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ActivitiesScreen internal error falls back to localized copy', (
    tester,
  ) async {
    await _pumpActivities(
      tester,
      _FakeActivityRepository(
        error: StateError('internal activities failure'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('โหลดกิจกรรมไม่สำเร็จ'), findsOneWidget);
    expect(find.textContaining('internal activities failure'), findsNothing);
    expect(find.text('ยังไม่มีกิจกรรมในงวดนี้'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ActivitiesHistoryScreen error uses API copy when available', (
    tester,
  ) async {
    await _pumpActivities(
      tester,
      _FakeActivityRepository(
        error: _apiException('โหลดกิจกรรมงวดย้อนหลังไม่ได้'),
      ),
      initialLocation: '/activities/history',
    );
    await tester.pumpAndSettle();

    expect(find.text('โหลดกิจกรรมงวดย้อนหลังไม่ได้'), findsOneWidget);
    expect(find.text('โหลดกิจกรรมไม่สำเร็จ'), findsNothing);
    expect(find.text('ยังไม่มีกิจกรรมย้อนหลัง'), findsNothing);
    expect(tester.takeException(), isNull);
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

    expect(find.text('งวดปัจจุบัน'), findsWidgets);
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

    expect(repository.calls.map((call) => call.history), contains(true));

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
    expect(find.text('มีสิทธิ์ 2 สิทธิ์'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('มีสิทธิ์ 2 สิทธิ์')).style?.color,
      const Color(0xFF15803D),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('ActivitiesScreen marks closed lucky boards and sorts them down',
      (
    tester,
  ) async {
    final repository = _FakeActivityRepository(
      items: [_closedLuckyFixture, _activityFixtures.first],
    );

    await _pumpActivities(
      tester,
      repository,
      authController: _authenticatedController(),
    );
    await tester.pumpAndSettle();

    final openTop = tester.getTopLeft(find.text('กิจกรรมทายเลข 2 ตัว')).dy;
    final closedTop = tester.getTopLeft(find.text('กิจกรรมปิดรับแล้ว')).dy;

    expect(openTop, lessThan(closedTop));
    expect(find.text('หมดเวลาเข้าร่วมแล้ว'), findsOneWidget);
    expect(find.text('หมดเวลาเข้าร่วม'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('หมดเวลาเข้าร่วม')).style?.color,
      const Color(0xFFB42318),
    );
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
      GoRoute(
        path: '/pin',
        builder: (context, state) => Scaffold(
          body: Center(
            child: Text(
              'Pin redirect: ${state.uri.queryParameters['redirect'] ?? ''}',
            ),
          ),
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
        mobileBootstrapProvider.overrideWith((_) async => _mobileBootstrap()),
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
  _FakeActivityRepository({List<ActivityItem>? items, this.error})
      : _items = items ?? _activityFixtures,
        super(_testApiClient(), (value) => value);

  final calls = <_ActivityCall>[];
  final List<ActivityItem> _items;
  final Object? error;

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
    final error = this.error;
    if (error != null) throw error;
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

AuthController _pinRequiredController({bool setupRequired = false}) {
  final tokenStore = AuthTokenStore();
  final api = _testApiClient(tokenStore);
  return AuthController(
    authRepository: AuthRepository(api: api, tokenStore: tokenStore),
    tokenStore: tokenStore,
    biometricAuth: BiometricAuthService(api),
  )
    ..isAuthenticated = true
    ..pinRequired = true
    ..pinSetupRequired = setupRequired;
}

MobileBootstrap _mobileBootstrap() {
  return MobileBootstrap.fromJson(
    const {
      'site': {'display_name': 'กิจกรรมดี'},
    },
    defaultSiteName: 'กิจกรรมดี',
  );
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

const _closedLuckyFixture = ActivityItem(
  id: 'act_closed',
  name: 'กิจกรรมปิดรับแล้ว',
  slug: 'closed-board',
  type: 'lucky_board',
  imageUrl: '',
  conditionText: 'ทุก 10 ใบ ได้ 1 สิทธิ์',
  remainingNumbers: 80,
  hasRight: true,
  estimatedCashbackAmount: 0,
  rights: ActivityRights(
    earnedCount: 4,
    usedCount: 0,
    remainingCount: 4,
    ticketCount: 40,
    availableTicketCount: 40,
    consumedTicketCount: 0,
    qualifyingOrderCount: 0,
    eligibilityRule: 'cumulative_tickets',
    thresholdTickets: 10,
    entryDeadlineAt: '2020-01-01T14:30:00+07:00',
    entryClosed: false,
  ),
  numberBoard: ActivityNumberBoard(
    predictionType: 'last2',
    digits: 2,
    totalCount: 100,
    reservedCount: 20,
    remainingCount: 80,
    reservedNumbers: {},
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

DioException _apiException(String message) {
  final requestOptions = RequestOptions(path: '/customer/activities');
  return DioException(
    requestOptions: requestOptions,
    response: Response<Map<String, dynamic>>(
      requestOptions: requestOptions,
      statusCode: 503,
      data: {'message': message},
    ),
    type: DioExceptionType.badResponse,
  );
}
