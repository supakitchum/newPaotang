import 'dart:async';

import 'package:customer_flutter/core/i18n/app_locale.dart';
import 'package:customer_flutter/core/i18n/customer_localizations.dart';
import 'package:customer_flutter/core/theme/app_theme.dart';
import 'package:customer_flutter/features/profile/data/profile_settings_models.dart';
import 'package:customer_flutter/features/profile/data/profile_settings_repository.dart';
import 'package:customer_flutter/features/wallet/data/wallet_models.dart';
import 'package:customer_flutter/features/wallet/data/wallet_repository.dart';
import 'package:customer_flutter/features/wallet/presentation/wallet_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('wallet header only contains the menu title', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
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

    final headerRect = tester.getRect(
      find.byKey(const ValueKey('customer-fixed-hero')),
    );
    final sheetTop = tester
        .getTopLeft(find.byKey(const ValueKey('wallet-content-sheet')))
        .dy;
    final walletCardTop = tester.getTopLeft(find.text('ยอดเงินในกระเป๋า')).dy;

    expect(headerRect.height, 150);
    expect(sheetTop, 150);
    expect(walletCardTop, greaterThan(sheetTop));
    expect(find.text('กระเป๋าของฉัน'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wallet history tabs filter incoming and outgoing entries', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
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
        ledger: [
          WalletLedgerEntry(
            id: 'credit_1',
            entryType: 'credit',
            referenceType: 'topup',
            referenceId: 'topup_1',
            reason: '',
            amount: 500,
            balanceAfter: 2320,
            createdAt: '2026-07-16T10:00:00+07:00',
          ),
          WalletLedgerEntry(
            id: 'debit_1',
            entryType: 'debit',
            referenceType: 'order',
            referenceId: 'order_1',
            reason: '',
            amount: -80,
            balanceAfter: 2240,
            createdAt: '2026-07-16T11:00:00+07:00',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ล่าสุด'), findsOneWidget);
    expect(find.text('เงินเข้า'), findsOneWidget);
    expect(find.text('เงินออก'), findsOneWidget);
    expect(find.text('เติมเงินเข้า G Wallet'), findsOneWidget);
    expect(find.text('ชำระค่าสลากดิจิทัล'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('wallet-filter-incoming')));
    await tester.pumpAndSettle();

    expect(find.text('เติมเงินเข้า G Wallet'), findsOneWidget);
    expect(find.text('ชำระค่าสลากดิจิทัล'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('wallet-filter-outgoing')));
    await tester.pumpAndSettle();

    expect(find.text('เติมเงินเข้า G Wallet'), findsNothing);
    expect(find.text('ชำระค่าสลากดิจิทัล'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('wallet-filter-latest')));
    await tester.pumpAndSettle();

    expect(find.text('เติมเงินเข้า G Wallet'), findsOneWidget);
    expect(find.text('ชำระค่าสลากดิจิทัล'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wallet filtered history loads server pages beyond latest seed', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _PagedWalletRepository();
    await _pumpWallet(
      tester,
      const WalletSummary(
        wallets: [
          CustomerWallet(
            id: 'wallet_1',
            name: 'Runtime Wallet',
            type: 'primary',
            balance: 2240,
          ),
        ],
        ledger: [
          WalletLedgerEntry(
            id: 'seed_debit',
            entryType: 'debit',
            referenceType: 'order',
            referenceId: 'order_seed',
            reason: 'รายการล่าสุด',
            amount: -80,
            balanceAfter: 2240,
            createdAt: '2026-07-16T11:00:00+07:00',
          ),
        ],
        ledgerNextCursor: 'v1.seed-cursor',
        ledgerHasMore: true,
      ),
      overrides: [
        walletRepositoryProvider.overrideWithValue(repository),
      ],
    );
    await tester.pumpAndSettle();

    final incomingTab = find.byKey(const ValueKey('wallet-filter-incoming'));
    await tester.ensureVisible(incomingTab);
    await tester.pumpAndSettle();
    await tester.tap(incomingTab);
    await tester.pumpAndSettle();

    expect(find.text('เงินเข้าหน้าแรก'), findsOneWidget);
    expect(find.text('รายการล่าสุด'), findsNothing);
    expect(repository.calls, [
      const _LedgerCall(WalletLedgerDirection.incoming, ''),
    ]);

    await tester.tap(find.byKey(const ValueKey('wallet-ledger-load-more')));
    await tester.pumpAndSettle();

    expect(find.text('เงินเข้าหน้าแรก'), findsOneWidget);
    expect(find.text('เงินเข้าหน้าถัดไป'), findsOneWidget);
    expect(repository.calls, [
      const _LedgerCall(WalletLedgerDirection.incoming, ''),
      const _LedgerCall(WalletLedgerDirection.incoming, 'v1.incoming-next'),
    ]);
    expect(find.byKey(const ValueKey('wallet-ledger-load-more')), findsNothing);
    expect(tester.takeException(), isNull);
  });

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
    expect(find.text('กระเป๋าของฉัน'), findsOneWidget);
    expect(find.text('ประวัติรายการเดินเงินล่าสุด'), findsOneWidget);
    expect(
      find.text('รายการเติมเงิน ชำระเงิน และรับเงินรางวัล'),
      findsOneWidget,
    );
    expect(find.text('เติมเงินเข้า G Wallet'), findsOneWidget);
    expect(
      tester.widget<Text>(find.textContaining('+500.00').first).style?.color,
      const Color(0xFF078254),
    );
    expect(find.byType(Card), findsNothing);
    expect(find.byType(AppBar), findsNothing);
    expect(find.byType(RefreshIndicator), findsNothing);

    final refreshButton = find.byTooltip('โหลดรายการใหม่');
    await tester.ensureVisible(refreshButton);
    await tester.pumpAndSettle();
    await tester.tap(refreshButton);
    await tester.pumpAndSettle();

    expect(loads, 2);
  });

  testWidgets('wallet screen shows Nuxt-style member code on wallet card', (
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
        customerNo: 'CUS001234',
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('ยอดเงินในกระเป๋า'), findsOneWidget);
    expect(find.text('รหัสสมาชิก : CUS001234'), findsOneWidget);
    expect(find.text('ยังไม่มีรายการเดินเงิน'), findsOneWidget);
    expect(find.byType(Card), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wallet screen falls back to profile member code like Nuxt', (
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
      ),
      overrides: [
        customerProfileSettingsProvider.overrideWith(
          (_) async => _profileWithCustomerNo('CUS-PROFILE'),
        ),
      ],
    );

    await tester.pumpAndSettle();

    expect(find.text('รหัสสมาชิก : CUS-PROFILE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wallet card actions preserve Nuxt topup back and history anchor',
      (
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
          path: '/topup',
          builder: (context, state) => Scaffold(
            body: Center(child: Text(state.uri.toString())),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          walletSummaryProvider.overrideWith(
            (_) async => const WalletSummary(
              wallets: [
                CustomerWallet(
                  id: 'wallet_1',
                  name: 'G Wallet',
                  type: '1',
                  balance: 2240,
                ),
              ],
              ledger: [],
              customerNo: 'CUS001234',
            ),
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

    await tester.tap(find.text('เติมเงิน').first);
    await tester.pumpAndSettle();

    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/topup?back=/my-wallet',
    );
    expect(find.text('/topup?back=/my-wallet'), findsOneWidget);

    router.go('/my-wallet');
    await tester.pumpAndSettle();

    await tester.tap(find.text('ประวัติ').first);
    await tester.pumpAndSettle();

    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/my-wallet#transactions',
    );
    expect(tester.takeException(), isNull);
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
    expect(
      find.ancestor(
        of: find.text('กรุณาลองใหม่อีกครั้ง'),
        matching: find.byType(Card),
      ),
      findsNothing,
    );
    final retryButton = find.widgetWithText(OutlinedButton, 'ลองใหม่');
    expect(retryButton, findsOneWidget);
    expect(
      find.descendant(of: retryButton, matching: find.byIcon(Icons.refresh)),
      findsNothing,
    );

    await tester.ensureVisible(retryButton);
    await tester.pumpAndSettle();
    await tester.tap(retryButton);
    await tester.pumpAndSettle();

    expect(loads, 2);
    expect(find.text('เติมเงินเข้า G Wallet'), findsOneWidget);
    expect(find.text('โหลดประวัติไม่สำเร็จ'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wallet refresh failure stays in the wallet error surface', (
    tester,
  ) async {
    var loads = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          walletSummaryProvider.overrideWith((_) async {
            loads++;
            if (loads == 1) {
              return const WalletSummary(
                wallets: [
                  CustomerWallet(
                    id: 'wallet_1',
                    name: 'G Wallet',
                    type: '1',
                    balance: 2240,
                  ),
                ],
                ledger: [
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
              );
            }
            throw StateError('wallet refresh failed');
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
    expect(find.text('อ้างอิง topup_1'), findsOneWidget);

    final refreshButton = find.byTooltip('โหลดรายการใหม่');
    await tester.ensureVisible(refreshButton);
    await tester.pumpAndSettle();
    await tester.tap(refreshButton);
    await tester.pumpAndSettle();

    expect(loads, 2);
    expect(find.text('โหลดประวัติไม่สำเร็จ'), findsOneWidget);
    expect(find.text('กรุณาลองใหม่อีกครั้ง'), findsOneWidget);
    expect(find.textContaining('wallet refresh failed'), findsNothing);
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
    expect(
      find.ancestor(
        of: find.text('ระบบประวัติกระเป๋าปิดปรับปรุง'),
        matching: find.byType(Card),
      ),
      findsNothing,
    );
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
    expect(find.text('เติมเงินเข้า G Wallet'), findsOneWidget);
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

Future<void> _pumpWallet(
  WidgetTester tester,
  WalletSummary summary, {
  List<Override> overrides = const [],
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        walletSummaryProvider.overrideWith((_) async => summary),
        ...overrides,
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

CustomerProfileSettings _profileWithCustomerNo(String customerNo) {
  return CustomerProfileSettings(
    id: 'customer_profile',
    name: 'Customer',
    customerNo: customerNo,
    phone: '0812345678',
    bankAccount: const RewardBankAccount(
      bankName: '',
      accountName: '',
      accountNumber: '',
    ),
    autoReward: const AutoRewardSetting(
      enabled: false,
      payoutMethod: 'wallet_credit',
      type: 'wallet_credit',
    ),
  );
}

class _PagedWalletRepository implements WalletRepository {
  final calls = <_LedgerCall>[];

  @override
  Future<WalletLedgerPage> ledgerPage({
    int limit = 12,
    String cursor = '',
    WalletLedgerDirection direction = WalletLedgerDirection.all,
  }) async {
    calls.add(_LedgerCall(direction, cursor));
    if (direction == WalletLedgerDirection.incoming && cursor.isEmpty) {
      return const WalletLedgerPage(
        entries: [
          WalletLedgerEntry(
            id: 'incoming_1',
            entryType: 'credit',
            referenceType: 'topup',
            referenceId: 'topup_1',
            reason: 'เงินเข้าหน้าแรก',
            amount: 500,
            balanceAfter: 2740,
            createdAt: '2026-07-15T10:00:00+07:00',
          ),
        ],
        nextCursor: 'v1.incoming-next',
        hasMore: true,
      );
    }
    if (direction == WalletLedgerDirection.incoming) {
      return const WalletLedgerPage(
        entries: [
          WalletLedgerEntry(
            id: 'incoming_2',
            entryType: 'credit',
            referenceType: 'reward_claim',
            referenceId: 'claim_1',
            reason: 'เงินเข้าหน้าถัดไป',
            amount: 100,
            balanceAfter: 2840,
            createdAt: '2026-07-14T10:00:00+07:00',
          ),
        ],
      );
    }
    return const WalletLedgerPage(entries: []);
  }

  @override
  Future<List<WalletLedgerEntry>> ledger({
    int limit = 12,
    WalletLedgerDirection direction = WalletLedgerDirection.all,
  }) async {
    return (await ledgerPage(limit: limit, direction: direction)).entries;
  }

  @override
  Future<WalletSummary> summary() async =>
      const WalletSummary(wallets: [], ledger: []);

  @override
  Future<List<CustomerWallet>> wallets() async => const [];
}

class _LedgerCall {
  const _LedgerCall(this.direction, this.cursor);

  final WalletLedgerDirection direction;
  final String cursor;

  @override
  bool operator ==(Object other) =>
      other is _LedgerCall &&
      other.direction == direction &&
      other.cursor == cursor;

  @override
  int get hashCode => Object.hash(direction, cursor);
}
