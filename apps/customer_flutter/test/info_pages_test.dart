import 'package:customer_flutter/core/i18n/app_locale.dart';
import 'package:customer_flutter/core/i18n/customer_localizations.dart';
import 'package:customer_flutter/core/tenant/mobile_bootstrap_controller.dart';
import 'package:customer_flutter/core/theme/app_theme.dart';
import 'package:customer_flutter/features/content/presentation/info_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  Finder infoText(String text) => find.text(text, skipOffstage: false);
  Finder infoTextContaining(String text) =>
      find.textContaining(text, skipOffstage: false);

  testWidgets('legal content pages render runtime html as readable text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: '/terms',
      routes: [
        GoRoute(path: '/', builder: (_, __) => const Text('Home')),
        GoRoute(path: '/profile', builder: (_, __) => const Text('Profile')),
        GoRoute(path: '/tickets', builder: (_, __) => const Text('Tickets')),
        GoRoute(path: '/terms', builder: (_, __) => const TermsScreen()),
        GoRoute(
          path: '/privacy',
          builder: (_, __) => const PrivacyPolicyScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mobileBootstrapProvider.overrideWith(
            (_) async => MobileBootstrap.fromJson(const {
              'site': {'name': 'Alpha Shop'},
              'legal': {
                'terms': {
                  'html':
                      '&amp;lt;h1&amp;gt;ข้อตกลงการใช้งาน&amp;lt;/h1&amp;gt;&amp;lt;p&amp;gt;1. ซื้อผ่าน Alpha Shop เท่านั้น&amp;lt;/p&amp;gt;&amp;lt;p&amp;gt;2. ค่าบริการ &amp;amp; เงื่อนไขเป็นไปตามร้านค้า&amp;lt;/p&amp;gt;',
                },
                'privacy': {
                  'html':
                      '<h1>นโยบายข้อมูลส่วนบุคคล</h1><p>1. ใช้ข้อมูลเพื่อให้บริการ</p><p>2. ติดต่อ support@example.test</p>',
                },
              },
            }),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: fallbackCustomerLocale,
          supportedLocales: supportedCustomerLocales,
          localizationsDelegates: const [
            CustomerLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: AppTheme.light(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(infoText('ข้อตกลงและเงื่อนไข'), findsOneWidget);
    expect(infoText('ข้อตกลงการใช้งาน'), findsNothing);
    expect(
      find.byKey(const ValueKey('legal-reading-surface')),
      findsOneWidget,
    );
    expect(infoText('ซื้อผ่าน Alpha Shop เท่านั้น'), findsOneWidget);
    expect(infoText('ค่าบริการ & เงื่อนไขเป็นไปตามร้านค้า'), findsOneWidget);
    expect(infoTextContaining('<h1>'), findsNothing);
    expect(infoTextContaining('&lt;'), findsNothing);
    expect(infoTextContaining('&amp;'), findsNothing);

    router.go('/privacy');
    await tester.pumpAndSettle();

    expect(infoText('นโยบายความเป็นส่วนตัว'), findsOneWidget);
    expect(infoText('นโยบายข้อมูลส่วนบุคคล'), findsNothing);
    expect(infoText('ใช้ข้อมูลเพื่อให้บริการ'), findsOneWidget);
    expect(infoText('ติดต่อ support@example.test'), findsOneWidget);
    expect(infoTextContaining('<p>'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('legal content pages render runtime markdown as readable text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: '/terms',
      routes: [
        GoRoute(path: '/', builder: (_, __) => const Text('Home')),
        GoRoute(path: '/profile', builder: (_, __) => const Text('Profile')),
        GoRoute(path: '/tickets', builder: (_, __) => const Text('Tickets')),
        GoRoute(path: '/terms', builder: (_, __) => const TermsScreen()),
        GoRoute(
          path: '/privacy',
          builder: (_, __) => const PrivacyPolicyScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mobileBootstrapProvider.overrideWith(
            (_) async => MobileBootstrap.fromJson(const {
              'site': {'name': 'Alpha Shop'},
              'legal': {
                'terms': {
                  'markdown':
                      '# เงื่อนไขบริการ\n1) อ่าน **รายละเอียด** ให้ครบ\n- [x] ยอมรับผ่าน [ทีมงาน](https://support.example.test)',
                },
                'privacy': {
                  'markdown':
                      '# นโยบายข้อมูล\n1) ใช้ _ข้อมูล_ เพื่อให้บริการ\n> ติดต่อ `privacy@example.test`',
                },
              },
            }),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: fallbackCustomerLocale,
          supportedLocales: supportedCustomerLocales,
          localizationsDelegates: const [
            CustomerLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: AppTheme.light(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(infoText('ข้อตกลงและเงื่อนไข'), findsOneWidget);
    expect(infoText('เงื่อนไขบริการ'), findsNothing);
    expect(infoText('อ่าน รายละเอียด ให้ครบ'), findsOneWidget);
    expect(infoText('ยอมรับผ่าน ทีมงาน'), findsOneWidget);
    expect(infoTextContaining('**'), findsNothing);
    expect(infoTextContaining('[ทีมงาน]'), findsNothing);

    router.go('/privacy');
    await tester.pumpAndSettle();

    expect(infoText('นโยบายความเป็นส่วนตัว'), findsOneWidget);
    expect(infoText('นโยบายข้อมูล'), findsNothing);
    expect(infoText('ใช้ ข้อมูล เพื่อให้บริการ'), findsOneWidget);
    expect(infoText('ติดต่อ privacy@example.test'), findsOneWidget);
    expect(infoTextContaining('`'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
