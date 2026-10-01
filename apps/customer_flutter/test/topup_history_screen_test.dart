import 'dart:async';

import 'package:customer_flutter/core/i18n/app_locale.dart';
import 'package:customer_flutter/core/i18n/customer_localizations.dart';
import 'package:customer_flutter/core/theme/app_theme.dart';
import 'package:customer_flutter/core/utils/formatters.dart';
import 'package:customer_flutter/features/topup/data/topup_models.dart';
import 'package:customer_flutter/features/topup/data/topup_repository.dart';
import 'package:customer_flutter/features/topup/presentation/topup_history_screen.dart';
import 'package:customer_flutter/features/topup/presentation/topup_realtime_monitor.dart';
import 'package:customer_flutter/shared/widgets/customer_gradient_button.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('topup history follows Nuxt hero and list spacing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpTopupHistory(
      tester,
      {
        1: _overview(
          histories: [_topup(id: 'top_layout_1', amount: 500)],
        ),
      },
    );
    await tester.pumpAndSettle();

    final hero = find.byKey(const ValueKey('topup-history-hero'));
    final back = find.byKey(const ValueKey('topup-history-back-action'));
    final summary = find.byKey(const ValueKey('topup-history-summary'));
    final sheet = find.byKey(const ValueKey('topup-history-sheet'));
    final item = find.byKey(
      const ValueKey('topup-history-item-top_layout_1'),
    );

    final heroHeight = tester.getSize(hero).height;
    final itemHeight = tester.getSize(item).height;
    expect(heroHeight, greaterThanOrEqualTo(220));
    expect(tester.getTopLeft(back).dy, 62);
    expect(tester.getSize(back), const Size.square(42));
    expect(tester.getTopLeft(summary).dy, 120);
    expect(tester.getTopLeft(sheet).dy, heroHeight);
    expect(itemHeight, inInclusiveRange(96, 140));
    expect(tester.takeException(), isNull);
  });

  testWidgets('topup history uses transfer time and renders bonus amount', (
    tester,
  ) async {
    const transferAt = '2026-06-26T13:04:00+07:00';
    const createdAt = '2026-06-20T08:00:00+07:00';

    await _pumpTopupHistory(
      tester,
      {
        1: _overview(
          histories: [
            _topup(
              id: 'top_1',
              amount: 500,
              bonusAmount: 25,
              status: TopupStatus.approved,
              transferAt: transferAt,
              createdAt: createdAt,
            ),
          ],
        ),
      },
    );

    await tester.pumpAndSettle();

    expect(find.text('เติมเงินเข้า Runtime Blue Wallet'), findsOneWidget);
    expect(find.text('500'), findsOneWidget);
    expect(find.text('บาท'), findsOneWidget);
    expect(find.text('500 บาท'), findsNothing);
    expect(find.text('อนุมัติแล้ว'), findsOneWidget);
    expect(find.text('รายการ #top_1'), findsOneWidget);
    expect(find.text('QR Code'), findsNothing);
    expect(find.text('โบนัส 25 บาท'), findsOneWidget);
    expect(
      find.textContaining(formatLocalizedDateTime(transferAt, 'th-TH')),
      findsOneWidget,
    );
    expect(
      find.textContaining(formatLocalizedDateTime(createdAt, 'th-TH')),
      findsNothing,
    );
    expect(find.byType(Card), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('topup history uses Nuxt-style page buttons', (tester) async {
    await _pumpTopupHistory(
      tester,
      {
        1: _overview(
          histories: [_topup(id: 'top_page_1', amount: 500)],
          currentPage: 1,
          lastPage: 3,
        ),
        2: _overview(
          histories: [
            _topup(
              id: 'top_page_2',
              amount: 700,
              status: TopupStatus.pendingReview,
            ),
          ],
          currentPage: 2,
          lastPage: 3,
        ),
      },
    );
    await tester.pumpAndSettle();

    expect(find.text('รายการ #top_page_1'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '1'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '2'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '3'), findsOneWidget);

    final pageTwoButton = find.widgetWithText(TextButton, '2');
    await tester.ensureVisible(pageTwoButton);
    await tester.pumpAndSettle();
    await tester.tap(pageTwoButton);
    await tester.pumpAndSettle();

    expect(find.text('รายการ #top_page_1'), findsNothing);
    expect(find.text('รายการ #top_page_2'), findsOneWidget);
    expect(find.text('รอตรวจสอบ'), findsOneWidget);
    expect(find.text('700'), findsOneWidget);
    expect(find.byType(Card), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('topup history refreshes current page on realtime tick', (
    tester,
  ) async {
    var loads = 0;
    final container = ProviderContainer(
      overrides: [
        topupHistoryProvider(1).overrideWith((_) async {
          loads++;
          return _overview(
            histories: [
              loads == 1
                  ? _topup(id: 'top_before_realtime', amount: 500)
                  : _topup(
                      id: 'top_after_realtime',
                      amount: 700,
                      status: TopupStatus.pendingReview,
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
          home: const TopupHistoryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(loads, 1);
    expect(find.text('รายการ #top_before_realtime'), findsOneWidget);

    container.read(topupRealtimeTickProvider.notifier).state++;
    await tester.pump();
    await tester.pumpAndSettle();

    expect(loads, 2);
    expect(find.text('รายการ #top_before_realtime'), findsNothing);
    expect(find.text('รายการ #top_after_realtime'), findsOneWidget);
    expect(find.text('รอตรวจสอบ'), findsOneWidget);
    expect(find.text('700'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('topup history remains readable on compact mobile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpTopupHistory(
      tester,
      {
        1: _overview(
          histories: [
            _topup(
              id: 'top_compact_1',
              amount: 1234,
              bonusAmount: 50,
              status: TopupStatus.rejected,
            ),
          ],
        ),
      },
    );
    await tester.pumpAndSettle();

    expect(find.text('รายการเติมเงินล่าสุด'), findsOneWidget);
    expect(find.text('เติมเงินเข้า Runtime Blue Wallet'), findsOneWidget);
    expect(find.text('รายการ #top_compact_1'), findsOneWidget);
    expect(find.text('ไม่อนุมัติ'), findsOneWidget);
    expect(find.text('1,234'), findsOneWidget);
    expect(find.text('โบนัส 50 บาท'), findsOneWidget);
    expect(find.byType(Card), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('topup history loading and error states use Nuxt copy', (
    tester,
  ) async {
    final completer = Completer<TopupOverview>();

    await _pumpTopupHistoryWithOverrides(
      tester,
      [
        topupHistoryProvider(1).overrideWith((_) => completer.future),
      ],
    );
    await tester.pump();

    expect(find.text('กำลังโหลดข้อมูล...'), findsOneWidget);

    completer.complete(_overview(histories: []));
    await tester.pumpAndSettle();

    expect(find.text('ยังไม่มีประวัติเติมเงิน'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    var calls = 0;
    await _pumpTopupHistoryWithOverrides(
      tester,
      [
        topupHistoryProvider(1).overrideWith((_) async {
          calls++;
          throw StateError('topup history failed');
        }),
      ],
    );
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(find.text('โหลดประวัติไม่สำเร็จ'), findsOneWidget);
    expect(find.text('topup history failed'), findsNothing);
    expect(find.text('ลองใหม่'), findsOneWidget);

    final retryButton = find.text('ลองใหม่');
    await tester.ensureVisible(retryButton);
    await tester.pumpAndSettle();
    await tester.tap(retryButton);
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('topup history API error uses server copy like Nuxt', (
    tester,
  ) async {
    await _pumpTopupHistoryWithOverrides(
      tester,
      [
        topupHistoryProvider(1).overrideWith((_) async {
          throw _apiException('ระบบเติมเงินปิดปรับปรุง');
        }),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('ระบบเติมเงินปิดปรับปรุง'), findsOneWidget);
    expect(find.text('โหลดประวัติไม่สำเร็จ'), findsNothing);
    expect(find.text('ลองใหม่'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('topup history header back returns to topup like Nuxt', (
    tester,
  ) async {
    await _pumpTopupHistoryRoute(
      tester,
      _overview(
        histories: [_topup(id: 'top_back_1', amount: 500)],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('รายการเติมเงินล่าสุด'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsNothing);

    await tester.tap(find.byTooltip('ย้อนกลับ'));
    await tester.pumpAndSettle();

    expect(find.text('Topup route'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('topup history empty action returns to topup like Nuxt', (
    tester,
  ) async {
    await _pumpTopupHistoryRoute(
      tester,
      _overview(histories: []),
    );
    await tester.pumpAndSettle();

    expect(find.text('ยังไม่มีประวัติเติมเงิน'), findsOneWidget);
    expect(
      find.text('เมื่อเติมเงินสำเร็จ รายการจะแสดงที่หน้านี้'),
      findsOneWidget,
    );

    final topupButton = find.widgetWithText(CustomerGradientButton, 'เติมเงิน');
    await tester.ensureVisible(topupButton);
    await tester.pumpAndSettle();

    await tester.tap(topupButton);
    await tester.pumpAndSettle();

    expect(find.text('Topup route'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpTopupHistory(
  WidgetTester tester,
  Map<int, TopupOverview> pages,
) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        for (final entry in pages.entries)
          topupHistoryProvider(entry.key)
              .overrideWith((_) async => entry.value),
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
        home: const TopupHistoryScreen(),
      ),
    ),
  );
}

Future<void> _pumpTopupHistoryWithOverrides(
  WidgetTester tester,
  List<Override> overrides,
) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
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
        home: const TopupHistoryScreen(),
      ),
    ),
  );
}

Future<void> _pumpTopupHistoryRoute(
  WidgetTester tester,
  TopupOverview overview,
) {
  final router = GoRouter(
    initialLocation: '/topup/history',
    routes: [
      GoRoute(
        path: '/topup/history',
        builder: (context, state) => const TopupHistoryScreen(),
      ),
      GoRoute(
        path: '/topup',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Topup route')),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);

  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        topupHistoryProvider(1).overrideWith((_) async => overview),
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
}

TopupOverview _overview({
  required List<TopupRequestItem> histories,
  int currentPage = 1,
  int lastPage = 1,
}) {
  return TopupOverview(
    walletName: 'Runtime Blue Wallet',
    bank: const TopupBankAccount(
      bankName: '',
      accountName: '',
      accountNumber: '',
    ),
    paymentMethods: const [],
    enabledPaymentMethods: const {},
    waiting: null,
    currentPage: currentPage,
    lastPage: lastPage,
    histories: histories,
  );
}

TopupRequestItem _topup({
  required String id,
  required double amount,
  double bonusAmount = 0,
  TopupStatus status = TopupStatus.approved,
  TopupChannel channel = TopupChannel.qr,
  Object? transferAt = '2026-06-26T13:04:00+07:00',
  Object? createdAt = '2026-06-20T08:00:00+07:00',
}) {
  return TopupRequestItem(
    id: id,
    amount: amount,
    bonusAmount: bonusAmount,
    status: status,
    channel: channel,
    provider: 'deepay_kbank',
    transferAt: transferAt,
    createdAt: createdAt,
    slipUrl: '',
    slipThumbUrl: '',
    qrCode: '',
    redirectUrl: '',
    message: '',
  );
}

DioException _apiException(String message) {
  final requestOptions = RequestOptions(path: '/customer/topups');
  return DioException(
    requestOptions: requestOptions,
    response: Response<Map<String, dynamic>>(
      requestOptions: requestOptions,
      statusCode: 503,
      data: {'message': message},
    ),
  );
}
