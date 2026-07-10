import 'package:customer_flutter/core/i18n/app_locale.dart';
import 'package:customer_flutter/core/i18n/customer_localizations.dart';
import 'package:customer_flutter/core/tenant/mobile_bootstrap_controller.dart';
import 'package:customer_flutter/core/theme/app_theme.dart';
import 'package:customer_flutter/shared/widgets/app_shell.dart';
import 'package:customer_flutter/shared/widgets/customer_page_body.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
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
    await _pumpPageBody(
      tester,
      bottom: 22,
      bottomSafeArea: 34,
    );

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

  testWidgets('AppShell auto back uses actual route instead of nav group path',
      (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/purchase-history',
      routes: [
        GoRoute(
          path: '/profile',
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('Profile route')),
          ),
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
}

Future<void> _pumpShell(
  WidgetTester tester, {
  ThemeData? theme,
  Map<String, dynamic> bootstrapPayload = const <String, dynamic>{},
  String currentPath = '/',
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
        home: AppShell(
          title: 'Home',
          currentPath: currentPath,
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
            child: const SizedBox(height: 10, width: 10),
          ),
        ),
      ),
    ),
  );
}
