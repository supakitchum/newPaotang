import 'package:customer_flutter/core/i18n/app_locale.dart';
import 'package:customer_flutter/core/i18n/customer_localizations.dart';
import 'package:customer_flutter/core/theme/app_theme.dart';
import 'package:customer_flutter/features/wallet/data/wallet_models.dart';
import 'package:customer_flutter/features/wallet/data/wallet_repository.dart';
import 'package:customer_flutter/features/wallet/presentation/wallet_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('wallet screen refresh button reloads wallet summary', (
    tester,
  ) async {
    var loads = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          walletSummaryProvider.overrideWith((_) async {
            loads++;
            return WalletSummary(
              wallets: [
                CustomerWallet(
                  id: 'wallet_1',
                  name: 'G Wallet',
                  type: '1',
                  balance: 2240 + loads.toDouble(),
                ),
              ],
              ledger: const [
                WalletLedgerEntry(
                  id: 'ledger_1',
                  entryType: 'credit',
                  referenceType: 'topup',
                  referenceId: 'top_1',
                  reason: '',
                  amount: 500,
                  balanceAfter: 2240,
                  createdAt: '2026-06-12T11:12:00+07:00',
                ),
              ],
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
          home: const WalletScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(loads, 1);
    expect(find.text('ประวัติรายการเดินเงินล่าสุด'), findsOneWidget);
    expect(find.text('เติมเงินเข้า G-Wallet'), findsOneWidget);

    await tester.tap(find.byTooltip('โหลดรายการใหม่'));
    await tester.pumpAndSettle();

    expect(loads, 2);
  });

  testWidgets('wallet screen keeps ledger readable on narrow viewports', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpWallet(
      tester,
      WalletSummary(
        wallets: const [
          CustomerWallet(
            id: 'wallet_1',
            name: 'G Wallet',
            type: '1',
            balance: 2240,
          ),
        ],
        ledger: const [
          WalletLedgerEntry(
            id: 'ledger_1',
            entryType: 'credit',
            referenceType: 'topup',
            referenceId: 'top_01KTX0DJS70GQ07FPF5CEXTRALONG',
            reason: '',
            amount: 123456.78,
            balanceAfter: 987654.32,
            createdAt: '2026-06-12T11:12:00+07:00',
          ),
        ],
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('ประวัติรายการเดินเงินล่าสุด'), findsOneWidget);
    expect(find.text('เติมเงินเข้า G-Wallet'), findsOneWidget);
    expect(find.textContaining('+123,456.78'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wallet screen aligns content with wide page body', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpWallet(
      tester,
      const WalletSummary(
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
    );

    await tester.pumpAndSettle();

    final walletCardRect = tester.getRect(
      find.text('ยอดเงินในกระเป๋า').first,
    );

    expect(walletCardRect.left, greaterThan(140));
    expect(walletCardRect.right, lessThan(1060));
    expect(find.text('ยังไม่มีรายการเดินเงิน'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpWallet(WidgetTester tester, WalletSummary summary) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        walletSummaryProvider.overrideWith((_) async => summary),
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
        home: const WalletScreen(),
      ),
    ),
  );
}
