import 'package:customer_flutter/core/i18n/app_locale.dart';
import 'package:customer_flutter/core/i18n/customer_localizations.dart';
import 'package:customer_flutter/core/tenant/mobile_bootstrap_controller.dart';
import 'package:customer_flutter/core/theme/app_theme.dart';
import 'package:customer_flutter/shared/widgets/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AppShell bottom navigation aligns with wide page content', (
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

    expect(navRect.width, 920);
    expect(navRect.left, 140);
    expect(navRect.right, 1060);
    expect(find.text('หน้าหลัก'), findsOneWidget);
    expect(find.text('สลากฯ ของฉัน'), findsOneWidget);
    expect(find.text('อื่นๆ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AppShell bottom navigation keeps mobile safe margins', (
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

    expect(navRect.left, 16);
    expect(navRect.right, 344);
    expect(navRect.width, 328);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AppShell bottom navigation uses runtime partner theme color', (
    tester,
  ) async {
    const partnerPrimary = Color(0xFF224488);

    await _pumpShell(
      tester,
      theme: AppTheme.light(
        tokens: const AppThemeTokens(
          primaryColor: partnerPrimary,
          secondaryColor: Color(0xFF0EA5E9),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final selectedIcon = tester.widget<Icon>(find.byIcon(Icons.home));
    final selectedLabel = tester.widget<Text>(find.text('หน้าหลัก'));

    expect(selectedIcon.color, partnerPrimary);
    expect(selectedLabel.style?.color, partnerPrimary);
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
}

Future<void> _pumpShell(
  WidgetTester tester, {
  ThemeData? theme,
  Map<String, dynamic> bootstrapPayload = const <String, dynamic>{},
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
        home: const AppShell(
          title: 'Home',
          currentPath: '/',
          child: Center(child: Text('Content')),
        ),
      ),
    ),
  );
}

const _bottomNavKey = Key('customer_bottom_nav');
final _bottomNavFinder = find.byKey(_bottomNavKey, skipOffstage: false);
