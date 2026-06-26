import 'package:customer_flutter/core/i18n/customer_localizations.dart';
import 'package:customer_flutter/core/tenant/mobile_bootstrap_controller.dart';
import 'package:customer_flutter/shared/widgets/app_splash.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AppSplashHost keeps splash for minimum duration then hides', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSplashMinimumDurationProvider.overrideWithValue(
            const Duration(milliseconds: 120),
          ),
          appSplashFadeDurationProvider.overrideWithValue(Duration.zero),
          mobileBootstrapProvider.overrideWith(
            (_) async => MobileBootstrap.fromJson({
              'site': {'display_name': 'Demo Shop', 'locale': 'th-TH'},
            }),
          ),
        ],
        child: const _SplashHarness(),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Ready content'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 120));
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Ready content'), findsOneWidget);
  });

  testWidgets('AppSplashHost hides even when bootstrap fails', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSplashMinimumDurationProvider.overrideWithValue(Duration.zero),
          appSplashFadeDurationProvider.overrideWithValue(Duration.zero),
          mobileBootstrapProvider.overrideWith(
            (_) async => throw StateError('bootstrap failed'),
          ),
        ],
        child: const _SplashHarness(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Ready content'), findsOneWidget);
  });
}

class _SplashHarness extends StatelessWidget {
  const _SplashHarness();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      locale: Locale('th', 'TH'),
      supportedLocales: [Locale('th', 'TH'), Locale('en', 'US')],
      localizationsDelegates: [
        CustomerLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      home: AppSplashHost(
        child: Scaffold(body: Center(child: Text('Ready content'))),
      ),
    );
  }
}
