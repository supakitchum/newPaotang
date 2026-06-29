import 'package:customer_flutter/core/i18n/app_locale.dart';
import 'package:customer_flutter/core/i18n/customer_localizations.dart';
import 'package:customer_flutter/core/theme/app_theme.dart';
import 'package:customer_flutter/shared/widgets/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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
}

Future<void> _pumpShell(WidgetTester tester) {
  return tester.pumpWidget(
    MaterialApp(
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
        title: 'Home',
        currentPath: '/',
        child: Center(child: Text('Content')),
      ),
    ),
  );
}

const _bottomNavKey = Key('customer_bottom_nav');
final _bottomNavFinder = find.byKey(_bottomNavKey, skipOffstage: false);
