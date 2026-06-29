import 'package:customer_flutter/core/i18n/app_locale.dart';
import 'package:customer_flutter/core/i18n/customer_localizations.dart';
import 'package:customer_flutter/core/navigation/customer_link_launcher.dart';
import 'package:customer_flutter/core/theme/app_theme.dart';
import 'package:customer_flutter/core/tenant/mobile_bootstrap_controller.dart';
import 'package:customer_flutter/features/purchase_history/data/purchase_history_models.dart';
import 'package:customer_flutter/features/purchase_history/data/purchase_history_repository.dart';
import 'package:customer_flutter/features/system/presentation/system_pages.dart';
import 'package:customer_flutter/features/results/data/result_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maintenanceSupportPhoneUri builds safe tel links', () {
    expect(
      maintenanceSupportPhoneUri('02-528-9682')?.toString(),
      'tel:025289682',
    );
    expect(
      maintenanceSupportPhoneUri('+66 2 528 9682')?.toString(),
      'tel:+6625289682',
    );
    expect(maintenanceSupportPhoneUri('   '), isNull);
    expect(maintenanceSupportPhoneUri('++++'), isNull);
  });

  testWidgets('maintenance support button uses shared external link policy', (
    tester,
  ) async {
    final launcher = _RecordingLinkLauncher();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mobileBootstrapProvider.overrideWith(
            (_) async => MobileBootstrap.fromJson({
              'site': {
                'name': 'Alpha Shop',
                'support_phone': '02-528-9682',
              },
              'maintenance': {
                'active': true,
                'message': 'Maintenance window',
              },
            }),
          ),
          customerLinkLauncherProvider.overrideWithValue(launcher),
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
          home: const MaintenanceScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byType(OutlinedButton));
    await tester.pump();

    expect(launcher.openedUri?.toString(), 'tel:025289682');
  });

  test('countdown stays while open game sale start is still in the future', () {
    final now = DateTime.parse('2026-06-26T09:59:00+07:00');
    final game = _currentGame(
      status: 'open',
      saleStartAt: '2026-06-26T10:00:00+07:00',
    );

    expect(countdownShouldStayOnPage(game, now), isTrue);
  });

  test('countdown redirects to buy when open game sale start has arrived', () {
    final now = DateTime.parse('2026-06-26T10:00:00+07:00');
    final game = _currentGame(
      status: 'open',
      saleStartAt: '2026-06-26T10:00:00+07:00',
    );

    expect(countdownShouldStayOnPage(game, now), isFalse);
    expect(countdownTargetPathForGame(game), '/buy');
  });

  test('countdown redirects closed games to waiting result', () {
    expect(
      countdownTargetPathForGame(_currentGame(status: 'closed')),
      '/waiting-result',
    );
    expect(
      countdownTargetPathForGame(_currentGame(status: 'draft')),
      '/waiting-result',
    );
    expect(countdownTargetPathForGame(null), '/waiting-result');
  });

  test('countdown redirects published result statuses to result page', () {
    for (final status in ['2', 'published', 'resulted', 'completed']) {
      expect(
        countdownTargetPathForGame(_currentGame(status: status)),
        '/result',
      );
    }
  });

  testWidgets('success screen renders receipt details from purchase history', (
    tester,
  ) async {
    final order = PurchaseHistoryOrder.fromJson({
      'id': 'ord_1',
      'reference': 'ORD-25690701-0001',
      'payment_method': 'wallet',
      'total': {'amount': 8000, 'currency': 'THB'},
      'ticket_count': 1,
      'game': {
        'name': 'งวดวันที่ 1 ก.ค. 2569',
        'draw_at': '2026-07-01T16:00:00+07:00',
      },
      'wallet': {'name': 'G Wallet'},
      'payment': {'provider_reference': '0061234567891244'},
      'store': {'name': 'ร้านค้าสลากฯ เดโม'},
      'paid_at': '2026-06-26T13:04:00+07:00',
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          purchaseHistoryDetailProvider('ord_1').overrideWith(
            (_) async => order,
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
          home: const SuccessScreen(orderId: 'ord_1'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('ซื้อสลากหกหลักแบบดิจิทัลสำเร็จ'), findsOneWidget);
    expect(find.text('จำนวนสลากฯ'), findsOneWidget);
    expect(find.text('1 ใบ'), findsOneWidget);
    expect(find.text('ชำระเงินให้'), findsOneWidget);
    expect(find.text('ร้านค้าสลากฯ เดโม'), findsOneWidget);
    expect(find.text('ช่องทางชำระเงิน'), findsOneWidget);
    expect(find.textContaining('G Wallet'), findsOneWidget);
    expect(find.text('ยอดชำระทั้งหมด'), findsOneWidget);
    expect(find.text('80.00 บาท'), findsOneWidget);
    expect(find.text('วันที่ทำรายการ'), findsOneWidget);
    expect(find.text('รหัสอ้างอิง'), findsOneWidget);
    expect(find.text('ORD-25690701-0001'), findsOneWidget);
  });
}

class _RecordingLinkLauncher extends CustomerLinkLauncher {
  Uri? openedUri;

  @override
  Future<bool> openExternal(
    Uri uri, {
    bool preferSameWindowInLine = false,
  }) async {
    openedUri = uri;
    return true;
  }
}

CurrentGame _currentGame({
  required String status,
  Object? saleStartAt,
}) {
  return CurrentGame(
    id: 'game_1',
    name: 'Current draw',
    status: status,
    drawAt: '2026-06-26T16:00:00+07:00',
    saleStartAt: saleStartAt,
  );
}
