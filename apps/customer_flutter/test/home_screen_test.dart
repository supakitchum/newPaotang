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
import 'package:customer_flutter/features/wallet/data/wallet_models.dart';
import 'package:customer_flutter/features/wallet/data/wallet_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('home screen renders live result summary on the first page', (
    tester,
  ) async {
    await _pumpHome(tester);

    await tester.pumpAndSettle();

    expect(find.text('ซื้อสลากดิจิทัล'), findsWidgets);
    expect(find.text('สแกนซื้อสลากฯ'), findsOneWidget);
    expect(find.text('เริ่มซื้อสลากดิจิทัล'), findsOneWidget);
    expect(find.text('เข้าสู่ระบบ'), findsOneWidget);
    expect(find.text('สมัครใช้งาน'), findsOneWidget);
    expect(find.text('ยอดเงินในกระเป๋า'), findsNothing);

    await tester.drag(find.byType(ListView), const Offset(0, -360));
    await tester.pumpAndSettle();

    expect(find.text('ผลรางวัลสลากฯ'), findsOneWidget);
    expect(
      find.text('ผลรางวัลนี้เป็นผลแสดงสดอย่างไม่เป็นทางการ'),
      findsOneWidget,
    );
    expect(find.text('287184'), findsOneWidget);
    expect(find.text('48'), findsOneWidget);
    expect(find.text('434'), findsOneWidget);
    expect(find.text('758'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();

    expect(find.text('ข่าวสาร'), findsWidgets);
    expect(find.text('ดูทั้งหมด'), findsWidgets);
    expect(find.text('ประกาศปิดปรับปรุง'), findsOneWidget);
    expect(find.text('ปรับปรุงระบบชำระเงินเวลา 23:00 น.'), findsOneWidget);
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
    expect(listRect.width, lessThanOrEqualTo(900));
    expect(listRect.left, greaterThan(100));
    expect(listRect.right, lessThan(1100));
    expect(tester.takeException(), isNull);
  });

  testWidgets('home wallet actions preserve Nuxt topup back and history anchor',
      (
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
          path: '/topup',
          builder: (context, state) => Scaffold(
            body: Center(child: Text(state.uri.toString())),
          ),
        ),
        GoRoute(
          path: '/my-wallet',
          builder: (context, state) => Scaffold(
            body: Center(child: Text(state.uri.toString())),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await _pumpHomeRouter(tester, router);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('เติมเงิน').first);
    await tester.tap(find.text('เติมเงิน').first);
    await tester.pumpAndSettle();

    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/topup?back=/',
    );
    expect(find.text('/topup?back=/'), findsOneWidget);

    router.go('/');
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('ประวัติ').first);
    await tester.tap(find.text('ประวัติ').first);
    await tester.pumpAndSettle();

    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/my-wallet#transactions',
    );
    expect(find.text('/my-wallet#transactions'), findsOneWidget);
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

    await tester.ensureVisible(find.text('ข่าว URL ภายใน'));
    await tester.drag(find.byType(ListView).first, const Offset(0, -180));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ข่าว URL ภายใน'));
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
        walletSummaryProvider.overrideWith(
          (_) async => const WalletSummary(
            wallets: [
              CustomerWallet(
                id: 'wallet_1',
                name: 'G Wallet',
                type: '1',
                balance: 2240,
              ),
            ],
            ledger: [],
          ),
        ),
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
