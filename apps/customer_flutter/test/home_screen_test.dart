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
import 'package:customer_flutter/features/home/presentation/home_screen.dart';
import 'package:customer_flutter/features/news/data/news_models.dart';
import 'package:customer_flutter/features/news/data/news_repository.dart';
import 'package:customer_flutter/features/results/data/result_models.dart';
import 'package:customer_flutter/features/results/data/result_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('home screen renders live result summary on the first page', (
    tester,
  ) async {
    await _pumpHome(tester, activities: _activityFixtures);

    await tester.pumpAndSettle();

    expect(find.text('ซื้อสลากดิจิทัล'), findsWidgets);
    expect(find.text('สแกนซื้อสลากฯ'), findsOneWidget);
    expect(find.text('เริ่มซื้อสลากดิจิทัล'), findsOneWidget);
    expect(find.text('เข้าสู่ระบบ'), findsOneWidget);
    expect(find.text('สมัครใช้งาน'), findsOneWidget);
    expect(find.text('ยอดเงินในกระเป๋า'), findsNothing);

    expect(find.text('287184', skipOffstage: false), findsOneWidget);
    expect(find.text('48', skipOffstage: false), findsOneWidget);
    expect(find.text('434', skipOffstage: false), findsOneWidget);
    expect(find.text('758', skipOffstage: false), findsOneWidget);

    expect(find.text('ข่าวสาร', skipOffstage: false), findsWidgets);
    expect(find.text('ดูทั้งหมด', skipOffstage: false), findsWidgets);
    expect(find.byKey(const ValueKey('home-news-carousel')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('home-news-slide-news_1')),
      findsOneWidget,
    );
    expect(find.text('ประกาศปิดปรับปรุง', skipOffstage: false), findsNothing);
    expect(find.byIcon(Icons.close), findsNothing);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('home-result-section'))).dy,
      lessThan(
        tester
            .getTopLeft(find.byKey(const ValueKey('home-activities-section')))
            .dy,
      ),
    );
  });

  testWidgets('home screen keeps the hero usable on narrow mobile viewports', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpHome(tester);
    await tester.pumpAndSettle();

    expect(find.text('ซื้อสลากดิจิทัล'), findsWidgets);
    expect(find.text('ค้นหาเลขเด็ด'), findsOneWidget);
    final sheet = tester.getRect(
      find.byKey(const ValueKey('home-content-sheet')),
    );
    expect(sheet.bottom, greaterThanOrEqualTo(780));

    final headerFinder = find.byKey(const ValueKey('home-scroll-header'));
    final initialHeaderRect = tester.getRect(headerFinder);
    await tester.drag(
      find.byKey(const ValueKey('home-page-scroll')),
      const Offset(0, -240),
    );
    await tester.pumpAndSettle();

    expect(tester.getRect(headerFinder).top, lessThan(initialHeaderRect.top));
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('home-content-sheet'))).dy,
      lessThan(sheet.top),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('home shows the API sale cutoff notice only on draw day', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpHome(
      tester,
      currentGame: const CurrentGame(
        id: 'draw-day-game',
        name: 'งวดวันที่ 16 ก.ค. 2569',
        status: 'open',
        drawAt: '2026-07-16T16:00:00+07:00',
        saleCloseAt: '2026-07-16T14:00:00+07:00',
        serverTime: '2026-07-16T12:20:00+07:00',
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('home-draw-day-sale-notice')),
      findsOneWidget,
    );
    expect(find.textContaining('14:00', findRichText: true), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    await _pumpHome(
      tester,
      currentGame: const CurrentGame(
        id: 'before-draw-game',
        name: 'งวดวันที่ 16 ก.ค. 2569',
        status: 'open',
        drawAt: '2026-07-16T16:00:00+07:00',
        saleCloseAt: '2026-07-16T14:00:00+07:00',
        serverTime: '2026-07-15T12:20:00+07:00',
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('home-draw-day-sale-notice')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('home activities rail stays aligned on wide viewports', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpHome(tester, activities: _activityFixtures);
    await tester.pumpAndSettle();

    final activityList = find.byWidgetPredicate(
      (widget) =>
          widget is ListView && widget.scrollDirection == Axis.horizontal,
    );

    expect(activityList, findsOneWidget);
    expect(find.text('กิจกรรมที่ 1'), findsOneWidget);
    expect(find.text('กิจกรรมที่ 2'), findsOneWidget);
    expect(find.text('คืนเงิน 5%'), findsOneWidget);

    final listRect = tester.getRect(activityList);
    expect(listRect.width, lessThanOrEqualTo(920));
    expect(listRect.left, greaterThan(100));
    expect(listRect.right, lessThan(1100));
    final artwork = tester.getRect(
      find.byKey(const ValueKey('home-activity-artwork-activity_1')),
    );
    expect(artwork.width / artwork.height, closeTo(16 / 9, 0.01));
    expect(artwork.width, lessThan(300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('authenticated home omits the wallet panel', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
      ],
    );
    addTearDown(router.dispose);

    await _pumpHomeRouter(tester, router);
    await tester.pumpAndSettle();

    expect(find.text('ยอดเงินในกระเป๋า', skipOffstage: false), findsNothing);
    expect(find.text('เติมเงิน', skipOffstage: false), findsNothing);
    expect(find.text('เข้าสู่ระบบ', skipOffstage: false), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home quick actions preserve Nuxt buy and store routes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
        GoRoute(
          path: '/buy',
          builder: (context, state) => _RouteEcho(uri: state.uri),
        ),
        GoRoute(
          path: '/stores',
          builder: (context, state) => _RouteEcho(uri: state.uri),
        ),
      ],
    );
    addTearDown(router.dispose);

    await _pumpHomeRouter(tester, router);
    await tester.pumpAndSettle();

    await tester.tap(find.text('ซื้อสลากดิจิทัล').last);
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.uri.toString(), '/buy');
    expect(find.text('/buy'), findsOneWidget);

    router.go('/');
    await tester.pumpAndSettle();

    await tester.tap(find.text('สแกนซื้อสลากฯ'));
    await tester.pumpAndSettle();

    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/stores',
    );
    expect(find.text('/stores'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home engagement cards preserve Nuxt activity and news routes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
        GoRoute(
          path: '/activities/:slug',
          builder: (context, state) => _RouteEcho(uri: state.uri),
        ),
        GoRoute(
          path: '/campaign/special',
          builder: (context, state) => _RouteEcho(uri: state.uri),
        ),
      ],
    );
    addTearDown(router.dispose);

    await _pumpHomeRouter(
      tester,
      router,
      activities: const [
        ActivityItem(
          id: 'activity_spaced',
          name: 'กิจกรรม slug เว้นวรรค',
          slug: 'summer sale',
          type: 'lucky_board',
          imageUrl: '',
          conditionText: 'ทุก 10 ใบ ได้ 1 สิทธิ์',
          remainingNumbers: 88,
          hasRight: true,
          estimatedCashbackAmount: 0,
        ),
      ],
      news: const [
        NewsItem(
          id: 'news_url',
          title: 'ข่าว URL ภายใน',
          summary: 'เปิดจาก url ที่ backend ส่งมา',
          body: '',
          slug: 'fallback-news',
          url: '/campaign/special?ref=home',
          coverUrl: '',
          publishedAt: '2026-06-08T13:14:00+07:00',
        ),
      ],
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('กิจกรรม slug เว้นวรรค'));
    await tester.tap(find.text('กิจกรรม slug เว้นวรรค'));
    await tester.pumpAndSettle();

    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/activities/summer%20sale',
    );
    expect(find.text('/activities/summer%20sale'), findsOneWidget);

    router.go('/');
    await tester.pumpAndSettle();

    final newsSlide = find.byKey(const ValueKey('home-news-slide-news_url'));
    await tester.drag(
      find.byKey(const ValueKey('home-page-scroll')),
      const Offset(0, -360),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(newsSlide);
    await tester.tap(newsSlide);
    await tester.pumpAndSettle();

    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/campaign/special?ref=home',
    );
    expect(find.text('/campaign/special?ref=home'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpHome(
  WidgetTester tester, {
  List<ActivityItem> activities = const <ActivityItem>[],
  List<NewsItem> news = _homeNewsFixtures,
  CurrentGame? currentGame,
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(
            apiBaseUrl: 'https://partner.example.com/api/v1',
            defaultLocale: 'th-TH',
          ),
        ),
        authTokenStoreProvider.overrideWithValue(AuthTokenStore()),
        activityListProvider.overrideWith((_) async => activities),
        newsListProvider.overrideWith((_) async => news),
        currentResultProvider.overrideWith((_) async {
          return RewardResultBundle(
            currentGame: currentGame,
            selectedResult: RewardResultGame.fromPublicSummary({
              'game_id': 'game_1',
              'game_name': 'งวดวันที่ 1 ก.ค. 2569',
              'status': 'live_unconfirmed',
              'official_status': 'draft',
              'prizes': [
                {
                  'prize_type': 'first_prize',
                  'prize_number': '287184',
                  'amount': {'amount': 600000000, 'currency': 'THB'},
                },
                {
                  'prize_type': 'back2',
                  'prize_number': '48',
                  'amount': {'amount': 200000, 'currency': 'THB'},
                },
                {
                  'prize_type': 'front3',
                  'prize_number': '434',
                  'amount': {'amount': 400000, 'currency': 'THB'},
                },
                {
                  'prize_type': 'front3',
                  'prize_number': '758',
                  'amount': {'amount': 400000, 'currency': 'THB'},
                },
              ],
            }),
            history: const [],
          );
        }),
      ],
      child: MaterialApp(
        locale: fallbackCustomerLocale,
        supportedLocales: supportedCustomerLocales,
        localizationsDelegates: const [
          CustomerLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.light(),
        home: const HomeScreen(),
      ),
    ),
  );
}

Future<void> _pumpHomeRouter(
  WidgetTester tester,
  GoRouter router, {
  List<ActivityItem> activities = const <ActivityItem>[],
  List<NewsItem> news = _homeNewsFixtures,
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(_testConfig),
        authTokenStoreProvider.overrideWithValue(AuthTokenStore()),
        authControllerProvider.overrideWith((_) => _authenticatedController()),
        activityListProvider.overrideWith((_) async => activities),
        newsListProvider.overrideWith((_) async => news),
        currentResultProvider.overrideWith((_) async => _homeResultBundle()),
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

RewardResultBundle _homeResultBundle() {
  return RewardResultBundle(
    currentGame: null,
    selectedResult: RewardResultGame.fromPublicSummary({
      'game_id': 'game_1',
      'game_name': 'งวดวันที่ 1 ก.ค. 2569',
      'status': 'live_unconfirmed',
      'official_status': 'draft',
      'prizes': [
        {
          'prize_type': 'first_prize',
          'prize_number': '287184',
          'amount': {'amount': 600000000, 'currency': 'THB'},
        },
        {
          'prize_type': 'back2',
          'prize_number': '48',
          'amount': {'amount': 200000, 'currency': 'THB'},
        },
        {
          'prize_type': 'front3',
          'prize_number': '434',
          'amount': {'amount': 400000, 'currency': 'THB'},
        },
        {
          'prize_type': 'front3',
          'prize_number': '758',
          'amount': {'amount': 400000, 'currency': 'THB'},
        },
      ],
    }),
    history: const [],
  );
}

AuthController _authenticatedController() {
  final tokenStore = AuthTokenStore();
  final api = ApiClient(_testConfig, tokenStore, localeTag: 'th-TH');
  return AuthController(
      authRepository: AuthRepository(api: api, tokenStore: tokenStore),
      tokenStore: tokenStore,
      biometricAuth: BiometricAuthService(api),
    )
    ..isAuthenticated = true
    ..pinRequired = false;
}

const _testConfig = AppConfig(
  apiBaseUrl: 'https://partner.example.com/api/v1',
  defaultLocale: 'th-TH',
);

class _RouteEcho extends StatelessWidget {
  const _RouteEcho({required this.uri});

  final Uri uri;

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text(uri.toString())));
  }
}

const _homeNewsFixtures = [
  NewsItem(
    id: 'news_1',
    title: 'ประกาศปิดปรับปรุง',
    summary: 'ปรับปรุงระบบชำระเงินเวลา 23:00 น.',
    body: '',
    slug: 'maintenance',
    url: '',
    coverUrl: '',
    publishedAt: '2026-06-08T13:14:00+07:00',
  ),
];

const _activityFixtures = [
  ActivityItem(
    id: 'activity_1',
    name: 'กิจกรรมที่ 1',
    slug: 'activity-1',
    type: 'lucky_board',
    imageUrl: '',
    conditionText: 'ทุก 10 ใบ ได้ 1 สิทธิ์',
    remainingNumbers: 97,
    hasRight: true,
    estimatedCashbackAmount: 0,
  ),
  ActivityItem(
    id: 'activity_2',
    name: 'กิจกรรมที่ 2',
    slug: 'activity-2',
    type: 'lucky_board',
    imageUrl: '',
    conditionText: 'ทุก 20 ใบ ได้ 1 สิทธิ์',
    remainingNumbers: 100,
    hasRight: false,
    estimatedCashbackAmount: 0,
  ),
  ActivityItem(
    id: 'activity_3',
    name: 'คืนเงิน 5%',
    slug: 'cashback-5',
    type: 'cashback',
    imageUrl: '',
    conditionText: 'ไม่ถูกรางวัลและซื้อครบ 50 ใบ',
    remainingNumbers: 0,
    hasRight: false,
    estimatedCashbackAmount: 0,
  ),
];
