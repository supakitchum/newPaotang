import 'package:customer_flutter/core/i18n/app_locale.dart';
import 'package:customer_flutter/core/i18n/customer_localizations.dart';
import 'package:customer_flutter/core/navigation/customer_back_navigation.dart';
import 'package:customer_flutter/core/tenant/mobile_bootstrap_controller.dart';
import 'package:customer_flutter/core/theme/app_theme.dart';
import 'package:customer_flutter/shared/widgets/app_shell.dart';
import 'package:customer_flutter/shared/widgets/customer_fixed_header_layout.dart';
import 'package:customer_flutter/shared/widgets/customer_page_body.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  test('default back destinations follow Nuxt route families', () {
    expect(customerDefaultBackPathFor('/result/full'), '/result');
    expect(customerDefaultBackPathFor('/results/full'), '/results');
    expect(customerDefaultBackPathFor('/topup'), '/my-wallet');
    expect(customerDefaultBackPathFor('/topup/demo'), '/my-wallet');
    expect(customerDefaultBackPathFor('/affiliate'), '/profile');
    expect(customerDefaultBackPathFor('/affiliate/rankings'), '/affiliate');
    expect(customerDefaultBackPathFor('/affiliate/referral'), '/affiliate');
    expect(customerDefaultBackPathFor('/term-reward'), '/');
  });

  testWidgets('AppShell bottom navigation spans wide viewport like Nuxt', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpShell(tester);
    await tester.pumpAndSettle();

    expect(find.text('Content'), findsOneWidget);

    final navRect = tester.getRect(_bottomNavFinder);

    expect(navRect.left, 0);
    expect(navRect.right, 1200);
    expect(navRect.width, 1200);
    expect(find.text('หน้าหลัก'), findsOneWidget);
    expect(find.text('สลากฯ ของฉัน'), findsOneWidget);
    expect(find.text('อื่นๆ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'AppShell defaults to no bottom navigation like Nuxt MobileShell',
    (tester) async {
      await _pumpShell(tester, showBottomNavigation: null);
      await tester.pumpAndSettle();

      expect(find.text('Content'), findsOneWidget);
      expect(_bottomNavFinder, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('AppShell keeps a transparent primary status bar', (
    tester,
  ) async {
    await _pumpShell(tester, showBottomNavigation: null);
    await tester.pumpAndSettle();

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    final style = appBar.systemOverlayStyle;
    expect(style, isNotNull);
    expect(style?.statusBarColor, Colors.transparent);
    expect(style?.statusBarIconBrightness, Brightness.light);
    expect(style?.statusBarBrightness, Brightness.dark);
  });

  testWidgets('AppShell bottom navigation spans mobile viewport like Nuxt', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpShell(tester);
    await tester.pumpAndSettle();

    expect(find.text('Content'), findsOneWidget);

    final navRect = tester.getRect(_bottomNavFinder);

    expect(navRect.left, 0);
    expect(navRect.right, 360);
    expect(navRect.width, 360);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AppShell bottom navigation keeps Nuxt blue identity', (
    tester,
  ) async {
    await _pumpShell(
      tester,
      theme: AppTheme.light(
        tokens: const AppThemeTokens(
          primaryColor: Color(0xFF22C55E),
          secondaryColor: Color(0xFF10B981),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final selectedIcon = tester.widget<Icon>(find.byIcon(Icons.home_outlined));
    final selectedLabel = tester.widget<Text>(find.text('หน้าหลัก'));

    expect(selectedIcon.color, AppTheme.appBottomNavActive);
    expect(selectedLabel.style?.color, AppTheme.appBottomNavActive);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AppShell bottom navigation selects Home for home route group', (
    tester,
  ) async {
    await _pumpShell(
      tester,
      currentPath: '/news',
      theme: AppTheme.light(
        tokens: const AppThemeTokens(
          primaryColor: Color(0xFF22C55E),
          secondaryColor: Color(0xFF10B981),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final selectedIcon = tester.widget<Icon>(find.byIcon(Icons.home_outlined));
    final selectedLabel = tester.widget<Text>(find.text('หน้าหลัก'));

    expect(selectedIcon.color, AppTheme.appBottomNavActive);
    expect(selectedLabel.style?.color, AppTheme.appBottomNavActive);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AppShell bottom navigation hides disabled feature routes', (
    tester,
  ) async {
    await _pumpShell(
      tester,
      bootstrapPayload: const {
        'featureFlags': {'tickets': false},
      },
    );
    await tester.pumpAndSettle();

    expect(find.text('หน้าหลัก'), findsOneWidget);
    expect(find.text('สลากฯ ของฉัน'), findsNothing);
    expect(find.text('อื่นๆ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('CustomerPageBody includes bottom safe area by default', (
    tester,
  ) async {
    await _pumpPageBody(tester, bottom: 22, bottomSafeArea: 34);

    final padding = tester.widget<Padding>(
      find.descendant(
        of: find.byType(CustomerPageBody),
        matching: find.byType(Padding),
      ),
    );

    expect(padding.padding.resolve(TextDirection.ltr).bottom, 56);
    expect(tester.takeException(), isNull);
  });

  testWidgets('CustomerPageBody can opt out of bottom safe area', (
    tester,
  ) async {
    await _pumpPageBody(
      tester,
      bottom: 22,
      bottomSafeArea: 34,
      includeBottomSafeArea: false,
    );

    final padding = tester.widget<Padding>(
      find.descendant(
        of: find.byType(CustomerPageBody),
        matching: find.byType(Padding),
      ),
    );

    expect(padding.padding.resolve(TextDirection.ltr).bottom, 22);
    expect(tester.takeException(), isNull);
  });

  testWidgets('CustomerPageBody keeps page content aligned to the top', (
    tester,
  ) async {
    await _pumpPageBody(tester, bottom: 0, bottomSafeArea: 0);

    expect(
      tester.getTopLeft(find.byKey(const Key('page-body-test-child'))).dy,
      0,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('fixed header gives content only the remaining viewport height', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomerFixedHeaderLayout(
            headerHeight: 150,
            header: const ColoredBox(color: Colors.blue),
            content: ListView(
              padding: EdgeInsets.zero,
              children: [
                ColoredBox(
                  key: const Key('fixed-content-sheet'),
                  color: Colors.white,
                  child: CustomerPageBody(
                    top: 0,
                    bottom: 0,
                    minViewportHeight: true,
                    child: const SizedBox(height: 10),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byType(CustomerPageBody)).height, 630);
    expect(
      tester.getRect(find.byKey(const Key('fixed-content-sheet'))).bottom,
      780,
    );
    expect(
      tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position
          .maxScrollExtent,
      0,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('expanded AppShell applies the shared rounded content edge', (
    tester,
  ) async {
    await _pumpShellWithHero(tester);
    await tester.pumpAndSettle();

    final layout = tester.widget<CustomerFixedHeaderLayout>(
      find.byType(CustomerFixedHeaderLayout),
    );
    expect(layout.contentTopRadius, customerContentSheetTopRadius);
    expect(layout.contentBackdropColor, AppTheme.appBlue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact AppShell uses the My Tickets header title size', (
    tester,
  ) async {
    await _pumpShellWithHero(tester);
    await tester.pumpAndSettle();

    final title = tester.widget<Text>(find.text('History'));
    expect(title.style?.fontSize, customerHeaderTitleFontSize);
    expect(title.style?.fontWeight, FontWeight.w700);
  });

  testWidgets(
    'AppShell auto back uses actual route instead of nav group path',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/purchase-history',
        routes: [
          GoRoute(
            path: '/profile',
            builder: (context, state) =>
                const Scaffold(body: Center(child: Text('Profile route'))),
          ),
          GoRoute(
            path: '/purchase-history',
            builder: (context, state) => const AppShell(
              title: 'History',
              currentPath: '/profile',
              child: Center(child: Text('History route')),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await _pumpRouterShell(tester, router);
      await tester.pumpAndSettle();

      expect(find.text('History route'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_ios_new), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
      await tester.pumpAndSettle();

      expect(find.text('Profile route'), findsOneWidget);
      expect(router.routerDelegate.currentConfiguration.uri.path, '/profile');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('AppShell back returns to the actual previous go route', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: Center(
              child: FilledButton(
                key: const Key('open-profile-route'),
                onPressed: () => context.go('/profile'),
                child: const Text('Open profile'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => Scaffold(
            body: Center(
              child: FilledButton(
                key: const Key('open-news-route'),
                onPressed: () => context.go('/news'),
                child: const Text('Open news'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/news',
          builder: (context, state) => const AppShell(
            title: 'News',
            backPath: '/fallback',
            child: Center(child: Text('News route')),
          ),
        ),
        GoRoute(
          path: '/fallback',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('Fallback route'))),
        ),
      ],
    );
    customerBackNavigationHistory.attach(router);
    addTearDown(() {
      customerBackNavigationHistory.detach(router);
      router.dispose();
    });

    await _pumpRouterShell(tester, router);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-profile-route')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-news-route')));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('open-news-route')), findsOneWidget);
    expect(find.text('Fallback route'), findsNothing);
    expect(router.routerDelegate.currentConfiguration.uri.path, '/profile');
    expect(tester.takeException(), isNull);
  });

  testWidgets('AppShell direct entry back uses its flow fallback', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/news',
      routes: [
        GoRoute(
          path: '/profile',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('Profile fallback'))),
        ),
        GoRoute(
          path: '/news',
          builder: (context, state) => const AppShell(
            title: 'News',
            backPath: '/profile',
            child: Center(child: Text('Direct news route')),
          ),
        ),
      ],
    );
    customerBackNavigationHistory.attach(router);
    addTearDown(() {
      customerBackNavigationHistory.detach(router);
      router.dispose();
    });

    await _pumpRouterShell(tester, router);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    await tester.pumpAndSettle();

    expect(find.text('Profile fallback'), findsOneWidget);
    expect(router.routerDelegate.currentConfiguration.uri.path, '/profile');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'AppShell back pops a pushed route without recreating its parent',
    (tester) async {
      var parentLoads = 0;
      final router = GoRouter(
        initialLocation: '/profile',
        routes: [
          GoRoute(
            path: '/profile',
            builder: (context, state) =>
                _LoadOnceRoute(onLoad: () => parentLoads++),
          ),
          GoRoute(
            path: '/news',
            builder: (context, state) => const AppShell(
              title: 'News',
              backPath: '/profile',
              child: Center(child: Text('Pushed news route')),
            ),
          ),
        ],
      );
      customerBackNavigationHistory.attach(router);
      addTearDown(() {
        customerBackNavigationHistory.detach(router);
        router.dispose();
      });

      await _pumpRouterShell(tester, router);
      await tester.pumpAndSettle();
      expect(parentLoads, 1);

      await tester.tap(find.byKey(const Key('push-news-route')));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('push-news-route')), findsOneWidget);
      expect(parentLoads, 1);
      expect(router.routerDelegate.currentConfiguration.uri.path, '/profile');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('AppShell shows back on a root tab reached through push', (
    tester,
  ) async {
    var parentLoads = 0;
    final router = GoRouter(
      initialLocation: '/profile',
      routes: [
        GoRoute(
          path: '/profile',
          builder: (context, state) =>
              _LoadOnceRoute(target: '/tickets', onLoad: () => parentLoads++),
        ),
        GoRoute(
          path: '/tickets',
          builder: (context, state) => const AppShell(
            title: 'Tickets',
            currentPath: '/tickets',
            child: Center(child: Text('Pushed root route')),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await _pumpRouterShell(tester, router);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('push-news-route')));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.arrow_back_ios_new), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    await tester.pumpAndSettle();

    expect(parentLoads, 1);
    expect(router.routerDelegate.currentConfiguration.uri.path, '/profile');
    expect(tester.takeException(), isNull);
  });

  testWidgets('AppShell does not auto back on root tab routes', (tester) async {
    final router = GoRouter(
      initialLocation: '/profile',
      routes: [
        GoRoute(
          path: '/profile',
          builder: (context, state) => const AppShell(
            title: 'Profile',
            currentPath: '/profile',
            child: Center(child: Text('Profile route')),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await _pumpRouterShell(tester, router);
    await tester.pumpAndSettle();

    expect(find.text('Profile route'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_ios_new), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('expanded hero stays fixed while its content sheet scrolls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mobileBootstrapProvider.overrideWith(
            (_) async => MobileBootstrap.fromJson(const <String, dynamic>{}),
          ),
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
          home: AppShell(
            title: 'ข่าวประชาสัมพันธ์',
            currentPath: '/news',
            heroMinHeight: 214,
            heroSheetOverlap: 54,
            heroContent: const SizedBox.shrink(),
            child: ListView(
              padding: EdgeInsets.zero,
              children: const [
                SizedBox(
                  key: Key('expanded-sheet-start'),
                  height: 1200,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Text('News content'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final titleFinder = find.text('ข่าวประชาสัมพันธ์');
    final headerFinder = find.byKey(const Key('customer-fixed-hero'));
    final initialHeaderRect = tester.getRect(headerFinder);
    expect(titleFinder, findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const Key('expanded-sheet-start'))).dy,
      closeTo(160, 0.1),
    );

    await tester.drag(find.text('News content'), const Offset(0, -220));
    await tester.pumpAndSettle();

    expect(titleFinder, findsOneWidget);
    expect(tester.getRect(headerFinder), initialHeaderRect);
    expect(
      tester.getTopLeft(find.byKey(const Key('expanded-sheet-start'))).dy,
      lessThan(0),
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpShell(
  WidgetTester tester, {
  ThemeData? theme,
  Map<String, dynamic> bootstrapPayload = const <String, dynamic>{},
  String currentPath = '/',
  bool? showBottomNavigation = true,
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        mobileBootstrapProvider.overrideWith(
          (_) async => MobileBootstrap.fromJson(bootstrapPayload),
        ),
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
        theme: theme ?? AppTheme.light(),
        home: showBottomNavigation == null
            ? AppShell(
                title: 'Home',
                currentPath: currentPath,
                child: const Center(child: Text('Content')),
              )
            : AppShell(
                title: 'Home',
                currentPath: currentPath,
                showBottomNavigation: showBottomNavigation,
                child: const Center(child: Text('Content')),
              ),
      ),
    ),
  );
}

Future<void> _pumpRouterShell(WidgetTester tester, GoRouter router) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        mobileBootstrapProvider.overrideWith(
          (_) async => MobileBootstrap.fromJson(const <String, dynamic>{}),
        ),
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

const _bottomNavKey = Key('customer_bottom_nav');
final _bottomNavFinder = find.byKey(_bottomNavKey, skipOffstage: false);

Future<void> _pumpPageBody(
  WidgetTester tester, {
  required double bottom,
  required double bottomSafeArea,
  bool includeBottomSafeArea = true,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(390, 780),
          padding: EdgeInsets.only(bottom: bottomSafeArea),
        ),
        child: Scaffold(
          body: CustomerPageBody(
            top: 0,
            bottom: bottom,
            includeBottomSafeArea: includeBottomSafeArea,
            child: const SizedBox(
              key: Key('page-body-test-child'),
              height: 10,
              width: 10,
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _pumpShellWithHero(WidgetTester tester) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        mobileBootstrapProvider.overrideWith(
          (_) async => MobileBootstrap.fromJson(const <String, dynamic>{}),
        ),
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
        home: const AppShell(
          title: 'History',
          currentPath: '/purchase-history',
          heroContent: SizedBox.shrink(),
          child: SizedBox.expand(),
        ),
      ),
    ),
  );
}

class _LoadOnceRoute extends StatefulWidget {
  const _LoadOnceRoute({required this.onLoad, this.target = '/news'});

  final VoidCallback onLoad;
  final String target;

  @override
  State<_LoadOnceRoute> createState() => _LoadOnceRouteState();
}

class _LoadOnceRouteState extends State<_LoadOnceRoute> {
  @override
  void initState() {
    super.initState();
    widget.onLoad();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          key: const Key('push-news-route'),
          onPressed: () => context.push(widget.target),
          child: const Text('Push news'),
        ),
      ),
    );
  }
}
