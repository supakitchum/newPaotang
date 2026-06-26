import 'package:customer_flutter/core/i18n/customer_localizations.dart';
import 'package:customer_flutter/core/tenant/mobile_bootstrap_controller.dart';
import 'package:customer_flutter/features/auth/presentation/forgot_password_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('forgot password shows LINE reset when tenant enables LINE login',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mobileBootstrapProvider.overrideWith(
            (_) async => MobileBootstrap.fromJson({
              'mobile': {
                'auth_providers': [
                  {'provider': 'line', 'label': 'LINE', 'enabled': true},
                ],
              },
            }),
          ),
        ],
        child: const _ForgotPasswordTestApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Reset with LINE'), findsWidgets);
    expect(find.textContaining('If you have connected LINE'), findsOneWidget);
  });

  testWidgets(
      'forgot password hides LINE reset when tenant disables LINE login',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mobileBootstrapProvider.overrideWith(
            (_) async => MobileBootstrap.fromJson({
              'mobile': {
                'auth_providers': [
                  {'provider': 'line', 'label': 'LINE', 'enabled': false},
                ],
              },
            }),
          ),
        ],
        child: const _ForgotPasswordTestApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Reset with LINE'), findsNothing);
  });
}

class _ForgotPasswordTestApp extends StatelessWidget {
  const _ForgotPasswordTestApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      locale: Locale('en', 'US'),
      supportedLocales: [Locale('th', 'TH'), Locale('en', 'US')],
      localizationsDelegates: [
        CustomerLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      home: ForgotPasswordScreen(),
    );
  }
}
