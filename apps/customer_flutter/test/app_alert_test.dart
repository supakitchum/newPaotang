import 'package:customer_flutter/core/i18n/customer_localizations.dart';
import 'package:customer_flutter/shared/widgets/app_alert.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('AppAlertHost shows and closes a global alert', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          locale: Locale('th', 'TH'),
          localizationsDelegates: [
            CustomerLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: [Locale('th', 'TH'), Locale('en', 'US')],
          home: AppAlertHost(child: _ShowAlertButton()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('show-app-alert')));
    await tester.pumpAndSettle();

    expect(find.text('หมดเวลาจำหน่ายสลากแล้ว'), findsOneWidget);
    expect(find.text('ระบบพาไปหน้ารอออกผลแล้ว'), findsOneWidget);
    expect(find.text('รับทราบ'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('app-alert-close-button')));
    await tester.pumpAndSettle();

    expect(find.text('หมดเวลาจำหน่ายสลากแล้ว'), findsNothing);
  });
}

class _ShowAlertButton extends ConsumerWidget {
  const _ShowAlertButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: TextButton(
          key: const ValueKey('show-app-alert'),
          onPressed: () {
            ref.read(appAlertControllerProvider.notifier).show(
                  title: 'หมดเวลาจำหน่ายสลากแล้ว',
                  message: 'ระบบพาไปหน้ารอออกผลแล้ว',
                  variant: AppAlertVariant.warning,
                );
          },
          child: const Text('show'),
        ),
      ),
    );
  }
}
