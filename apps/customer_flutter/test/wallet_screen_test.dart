import 'dart:async';

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
import 'package:go_router/go_router.dart';

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
    expect(
      find.text('รายการเติมเงิน ชำระเงิน และรับเงินรางวัล'),
      findsOneWidget,
    );
    expect(find.text('เติมเงินเข้า G-Wallet'), findsOneWidget);

    await tester.tap(find.byTooltip('โหลดรายการใหม่'));
    await tester.pumpAndSettle();

    expect(loads, 2);
  });

  testWidgets('wallet screen reloads when realtime invalidates summary', (
    tester,
  ) async {
    var loads = 0;
    final container = ProviderContainer(
      overrides: [
        walletSummaryProvider.overrideWith((_) async {
          loads++;
          return WalletSummary(
            wallets: [
              CustomerWallet(
                id: 'wallet_1',
                name: 'G Wallet',
                type: '1',
                balance: loads == 1 ? 2240 : 2740,
              ),
            ],
            ledger: [
              WalletLedgerEntry(
                id: 'ledger_$loads',
                entryType: 'credit',
                referenceType: 'topup',
                referenceId: 'topup_$loads',
                reason: '',
                amount: loads == 1 ? 500 : 900,
                balanceAfter: loads == 1 ? 2240 : 2740,
                createdAt: '2026-06-12T11:12:00+07:00',
              ),
            ],
          );
        }),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
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
    expect(find.text('อ้างอิง topup_1'), findsOneWidget);
    expect(find.textContaining('+500.00'), findsOneWidget);

    container.invalidate(walletSummaryProvider);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(loads, 2);
    expect(find.text('อ้างอิง topup_1'), findsNothing);
    expect(find.text('อ้างอิง topup_2'), findsOneWidget);
    expect(find.textContaining('+900.00'), findsOneWidget);
  });

  testWidgets('wallet screen shows Nuxt-style ledger loading copy', (
    tester,
  ) async {
    final completer = Completer<WalletSummary>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          walletSummaryProvider.overrideWith((_) => completer.future),
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

    await tester.pump();

    expect(find.text('กำลังโหลดรายการ...'), findsOneWidget);

    completer.complete(const WalletSummary(wallets: [], ledger: []));
    await tester.pumpAndSettle();

    expect(find.text('ยังไม่มีรายการเดินเงิน'), findsOneWidget);
  });

  testWidgets('wallet screen keeps balance visible when ledger fails', (
    tester,
  ) async {
    var loads = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          walletSummaryProvider.overrideWith((_) async {
            loads++;
            return WalletSummary(
              wallets: const [
                CustomerWallet(
                  id: 'wallet_1',
                  name: 'G Wallet',
                  type: '1',
                  balance: 2240,
                ),
              ],
              ledger: loads == 1
                  ? const []
                  : const [
                      WalletLedgerEntry(
                        id: 'ledger_1',
                        entryType: 'credit',
                        referenceType: 'topup',
                        referenceId: 'topup_1',
                        reason: '',
                        amount: 500,
                        balanceAfter: 2740,
                        createdAt: '2026-06-12T11:12:00+07:00',
                      ),
                    ],
              ledgerLoadFailed: loads == 1,
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
    expect(find.text('ยอดเงินในกระเป๋า'), findsOneWidget);
    expect(find.text('โหลดประวัติไม่สำเร็จ'), findsOneWidget);
    expect(find.text('กรุณาลองใหม่อีกครั้ง'), findsOneWidget);
    expect(find.text('ยังไม่มีรายการเดินเงิน'), findsNothing);

    await tester.tap(find.text('ลองใหม่'));
    await tester.pumpAndSettle();

    expect(loads, 2);
    expect(find.text('เติมเงินเข้า G-Wallet'), findsOneWidget);
    expect(find.text('โหลดประวัติไม่สำเร็จ'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wallet ledger failure shows API copy like Nuxt', (
    tester,
  ) async {
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
        ledgerLoadFailed: true,
        ledgerErrorMessage: 'ระบบประวัติกระเป๋าปิดปรับปรุง',
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('ยอดเงินในกระเป๋า'), findsOneWidget);
    expect(find.text('โหลดประวัติไม่สำเร็จ'), findsOneWidget);
    expect(find.text('ระบบประวัติกระเป๋าปิดปรับปรุง'), findsOneWidget);
    expect(find.text('กรุณาลองใหม่อีกครั้ง'), findsNothing);
    expect(find.text('ยังไม่มีรายการเดินเงิน'), findsNothing);
    expect(tester.takeException(), isNull);
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
    expect(
      find.text('รายการเติมเงิน ชำระเงิน และรับเงินรางวัลจะแสดงที่นี่'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('wallet screen back action returns to profile like Nuxt', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/my-wallet',
      routes: [
        GoRoute(
          path: '/my-wallet',
          builder: (context, state) => const WalletScreen(),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('Profile route')),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          walletSummaryProvider.overrideWith(
            (_) async => const WalletSummary(wallets: [], ledger: []),
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
    await tester.pumpAndSettle();

    expect(find.byTooltip('ย้อนกลับ'), findsOneWidget);
    expect(find.text('Profile route'), findsNothing);

    await tester.tap(find.byTooltip('ย้อนกลับ'));
    await tester.pumpAndSettle();

    expect(find.text('Profile route'), findsOneWidget);
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
