import 'dart:async';
import 'dart:convert';

import 'package:customer_flutter/core/i18n/app_locale.dart';
import 'package:customer_flutter/core/i18n/customer_localizations.dart';
import 'package:customer_flutter/core/navigation/customer_link_launcher.dart';
import 'package:customer_flutter/core/theme/app_theme.dart';
import 'package:customer_flutter/core/tenant/mobile_bootstrap_controller.dart';
import 'package:customer_flutter/features/purchase_history/data/purchase_history_models.dart';
import 'package:customer_flutter/features/purchase_history/data/purchase_history_repository.dart';
import 'package:customer_flutter/features/purchase_history/presentation/purchase_history_detail_screen.dart';
import 'package:customer_flutter/features/content/presentation/info_pages.dart';
import 'package:customer_flutter/features/results/data/result_models.dart';
import 'package:customer_flutter/features/system/presentation/system_pages.dart';
import 'package:customer_flutter/shared/widgets/customer_loading_indicator.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

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

  test('maintenanceSupportUrlUri keeps only safe external support URLs', () {
    expect(
      maintenanceSupportUrlUri(
        'https://partner.example.com/support',
      )?.toString(),
      'https://partner.example.com/support',
    );
    expect(
      maintenanceSupportUrlUri('http://partner.example.com/support'),
      isNull,
    );
    expect(maintenanceSupportUrlUri('javascript:alert(1)'), isNull);
    expect(maintenanceSupportUrlUri('   '), isNull);
  });

  test('systemSupportEmailUri builds safe mailto support links', () {
    expect(
      systemSupportEmailUri('support@example.test')?.toString(),
      'mailto:support@example.test',
    );
    expect(systemSupportEmailUri('bad email@example.test'), isNull);
    expect(systemSupportEmailUri('support.example.test'), isNull);
    expect(systemSupportEmailUri('   '), isNull);
  });

  test('shared customer contact URIs reject unsafe runtime values', () {
    expect(
      customerHttpsUri('https://support.example.test/help')?.toString(),
      'https://support.example.test/help',
    );
    expect(customerHttpsUri('http://support.example.test/help'), isNull);
    expect(customerHttpsUri('https://user@support.example.test/help'), isNull);
    expect(customerPhoneUri('02-111-2222')?.toString(), 'tel:021112222');
    expect(
      customerEmailUri('support@example.test')?.toString(),
      'mailto:support@example.test',
    );
  });

  testWidgets('lottery knowledge uses runtime support website and phone', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final launcher = _RecordingLinkLauncher();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mobileBootstrapProvider.overrideWith(
            (_) async => MobileBootstrap.fromJson({
              'site': {
                'name': 'Alpha Shop',
                'support_phone': '02-111-2222',
                'support_url': 'https://support.alpha.example.test/lottery',
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
          home: const LotteryKnowledgeScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('ข้อควรรู้การซื้อ-ขายสลากฯ'), findsOneWidget);

    final website = find.text('support.alpha.example.test');
    await tester.ensureVisible(website);
    await tester.tap(website);
    await tester.pump();

    expect(
      launcher.openedUri?.toString(),
      'https://support.alpha.example.test/lottery',
    );

    final phone = find.text('02-111-2222');
    await tester.ensureVisible(phone);
    await tester.tap(phone);
    await tester.pump();

    expect(launcher.openedUri?.toString(), 'tel:021112222');
    expect(find.textContaining('glo.or.th'), findsNothing);
    expect(find.text('02-528-9682'), findsNothing);
  });

  testWidgets('lottery knowledge hides contact footer without runtime config', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mobileBootstrapProvider.overrideWith(
            (_) async => MobileBootstrap.fromJson({
              'site': {'name': 'Alpha Shop'},
            }),
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
          home: const LotteryKnowledgeScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('ข้อควรรู้การซื้อ-ขายสลากฯ'), findsOneWidget);
    expect(find.text('ศึกษารายละเอียดเพิ่มเติม ได้ที่'), findsNothing);
    expect(find.textContaining('glo.or.th'), findsNothing);
    expect(find.text('02-528-9682'), findsNothing);
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
              'site': {'name': 'Alpha Shop', 'support_phone': '02-528-9682'},
              'maintenance': {'active': true, 'message': 'Maintenance window'},
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

  testWidgets('maintenance support button falls back to runtime support URL', (
    tester,
  ) async {
    final launcher = _RecordingLinkLauncher();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mobileBootstrapProvider.overrideWith(
            (_) async => MobileBootstrap.fromJson({
              'site': {'name': 'Alpha Shop'},
              'supportConfig': {
                'supportUrl': 'https://partner.example.com/support',
              },
              'maintenance': {'active': true, 'message': 'Maintenance window'},
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

    expect(find.text('ติดต่อฝ่ายบริการ'), findsOneWidget);
    await tester.tap(find.byType(OutlinedButton));
    await tester.pump();

    expect(
      launcher.openedUri?.toString(),
      'https://partner.example.com/support',
    );
  });

  testWidgets(
    'maintenance support button falls back to runtime support email',
    (tester) async {
      final launcher = _RecordingLinkLauncher();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mobileBootstrapProvider.overrideWith(
              (_) async => MobileBootstrap.fromJson({
                'site': {
                  'name': 'Alpha Shop',
                  'support_email': 'support@example.test',
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

      expect(find.text('ติดต่อฝ่ายบริการ'), findsOneWidget);
      await tester.ensureVisible(find.byType(OutlinedButton));
      await tester.tap(find.byType(OutlinedButton));
      await tester.pump();

      expect(launcher.openedUri?.toString(), 'mailto:support@example.test');
    },
  );

  testWidgets('maintenance support button prefers callable phone over URL', (
    tester,
  ) async {
    final launcher = _RecordingLinkLauncher();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mobileBootstrapProvider.overrideWith(
            (_) async => MobileBootstrap.fromJson({
              'site': {'name': 'Alpha Shop', 'support_phone': '02-528-9682'},
              'supportConfig': {
                'supportUrl': 'https://partner.example.com/support',
              },
              'maintenance': {'active': true, 'message': 'Maintenance window'},
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

  testWidgets('account suspended follows the Nuxt single-action card', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mobileBootstrapProvider.overrideWith(
            (_) async => MobileBootstrap.fromJson({
              'site': {'name': 'Alpha Shop', 'support_phone': '02-528-9682'},
              'supportConfig': {
                'supportUrl': 'https://partner.example.com/support',
              },
            }),
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
          home: const AccountSuspendedScreen(reason: 'Risk review'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('กลับไปหน้าเข้าสู่ระบบ'), findsOneWidget);
    expect(find.text('ติดต่อฝ่ายบริการ'), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
  });

  test('account suspension duration matches Nuxt permanent fallback', () {
    const l10n = CustomerLocalizations(fallbackCustomerLocale);

    expect(
      accountSuspensionDurationText(
        l10n,
        permanent: false,
        suspendedUntil: null,
      ),
      'ระงับถาวร',
    );
    expect(
      accountSuspensionDurationText(
        l10n,
        permanent: false,
        suspendedUntil: 'not-a-date',
      ),
      'ระงับชั่วคราว',
    );
  });

  test('system schedule timestamps are rendered in Bangkok time', () {
    const l10n = CustomerLocalizations(fallbackCustomerLocale);

    expect(
      accountSuspensionDurationText(
        l10n,
        permanent: false,
        suspendedUntil: '2026-07-01T17:30:00Z',
      ),
      'ถึง 2 ก.ค. 2569 00:30',
    );
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
    final exportCoordinator = _RecordingReceiptExportCoordinator();
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
          mobileBootstrapProvider.overrideWith(
            (_) async => MobileBootstrap.fromJson(const {
              'site': {'display_name': 'ร้านค้าสลากฯ เดโม'},
              'brand': {'logo_url': _receiptLogoDataUri},
              'mobile': {'lottery_product_label': 'L6'},
            }),
          ),
          purchaseHistoryDetailProvider(
            'ord_1',
          ).overrideWith((_) async => order),
          receiptExportCoordinatorProvider.overrideWithValue(exportCoordinator),
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
    expect(find.text('L6'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('จำนวนสลากฯ'), findsOneWidget);
    expect(find.text('1 ใบ'), findsOneWidget);
    expect(find.text('ชำระเงินให้'), findsOneWidget);
    expect(find.text('ร้านค้าสลากฯ เดโม'), findsOneWidget);
    expect(find.text('ช่องทางชำระเงิน'), findsOneWidget);
    expect(find.textContaining('G Wallet'), findsOneWidget);
    expect(find.text('ยอดชำระทั้งหมด'), findsOneWidget);
    expect(find.text('80.00'), findsOneWidget);
    expect(find.text('บาท'), findsOneWidget);
    expect(find.textContaining('วันที่ทำรายการ'), findsOneWidget);
    expect(find.textContaining('รหัสอ้างอิง'), findsOneWidget);
    expect(find.textContaining('ORD-25690701-0001'), findsOneWidget);
    expect(find.text('บันทึก'), findsOneWidget);
    expect(find.text('แชร์'), findsNothing);

    final saveButton = find.widgetWithText(OutlinedButton, 'บันทึก');
    await tester.ensureVisible(saveButton);
    await tester.pumpAndSettle();
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(find.text('เปิดตัวเลือกการแชร์แล้ว'), findsOneWidget);
    expect(exportCoordinator.calls, 1);
    expect(exportCoordinator.text, contains('ORD-25690701-0001'));
    expect(exportCoordinator.text, contains('ซื้อสลากหกหลักแบบดิจิทัลสำเร็จ'));
    expect(exportCoordinator.imageFileName, 'receipt-ord-25690701-0001.png');
    expect(exportCoordinator.pdfFileName, 'receipt-ord-25690701-0001.pdf');
    expect(exportCoordinator.boundaryKey?.currentContext, isNotNull);
  });

  testWidgets('success screen keeps Nuxt receipt vertical rhythm', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mobileBootstrapProvider.overrideWith(
            (_) async => MobileBootstrap.fromJson(const {
              'site': {'display_name': 'ร้านค้าสลากฯ เดโม'},
              'brand': {'logo_url': _receiptLogoDataUri},
              'mobile': {'lottery_product_label': 'L6'},
            }),
          ),
          purchaseHistoryDetailProvider(
            'ord_1',
          ).overrideWith((_) async => _successOrder()),
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

    final receipt = find.byKey(const ValueKey('success-receipt-card'));
    final saveAction = find.byKey(const ValueKey('success-save-action'));
    final primaryAction = find.byKey(const ValueKey('success-primary-action'));
    expect(receipt, findsOneWidget);
    expect(saveAction, findsOneWidget);
    expect(primaryAction, findsOneWidget);

    final receiptRect = tester.getRect(receipt);
    final saveRect = tester.getRect(saveAction);
    final primaryRect = tester.getRect(primaryAction);

    expect(receiptRect.top, closeTo(54, 1));
    expect(saveRect.top - receiptRect.bottom, closeTo(24, 1));
    expect(primaryRect.top - saveRect.bottom, closeTo(238, 1));
    expect(find.byType(AppBar), findsNothing);
    expect(find.byIcon(Icons.arrow_back_ios_new), findsNothing);
  });

  testWidgets('success receipt loading state uses Nuxt payment copy', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final completer = Completer<PurchaseHistoryOrder>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mobileBootstrapProvider.overrideWith(
            (_) async => MobileBootstrap.fromJson(const {
              'site': {'display_name': 'ร้านค้าสลากฯ เดโม'},
            }),
          ),
          purchaseHistoryDetailProvider(
            'ord_loading',
          ).overrideWith((_) => completer.future),
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
          home: const SuccessScreen(orderId: 'ord_loading'),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('ซื้อสลากหกหลักแบบดิจิทัลสำเร็จ'), findsOneWidget);
    expect(
      find.text('คุณสามารถดูสลากฯ ได้ที่เมนู ‘สลากฯ ของฉัน’'),
      findsOneWidget,
    );
    expect(find.byType(CustomerLoadingMark), findsOneWidget);
    expect(find.text('กำลังโหลดข้อมูลการชำระเงิน...'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'บันทึก'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'ดูสลากฯ ของฉัน'), findsOneWidget);
    expect(tester.takeException(), isNull);

    completer.complete(_successOrder());
  });

  testWidgets('success receipt load error keeps Nuxt-style tickets fallback', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/success?order_id=ord_error',
      routes: [
        GoRoute(
          path: '/success',
          builder: (context, state) =>
              SuccessScreen(orderId: state.uri.queryParameters['order_id']),
        ),
        GoRoute(
          path: '/tickets',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('Tickets fallback'))),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          purchaseHistoryDetailProvider(
            'ord_error',
          ).overrideWith((_) async => throw StateError('receipt unavailable')),
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

    expect(find.text('ซื้อสลากหกหลักแบบดิจิทัลสำเร็จ'), findsOneWidget);
    expect(find.text('โหลดข้อมูลการชำระเงินไม่สำเร็จ'), findsOneWidget);
    expect(
      find.widgetWithText(OutlinedButton, 'ดูสลากฯ ของฉัน'),
      findsOneWidget,
    );
    final fallbackButton = find.widgetWithText(FilledButton, 'ดูสลากฯ ของฉัน');
    expect(fallbackButton, findsOneWidget);

    await tester.ensureVisible(fallbackButton);
    await tester.pumpAndSettle();
    await tester.tap(fallbackButton);
    await tester.pumpAndSettle();

    expect(find.text('Tickets fallback'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'purchase history detail forwards maintenance errors to shared route flow',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/purchase-history/ord_maintenance',
        routes: [
          GoRoute(
            path: '/purchase-history/:orderId',
            builder: (context, state) => PurchaseHistoryDetailScreen(
              orderId: state.pathParameters['orderId'] ?? '',
            ),
          ),
          GoRoute(
            path: '/maintenance',
            builder: (context, state) =>
                const Scaffold(body: Center(child: Text('Maintenance route'))),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            purchaseHistoryDetailProvider('ord_maintenance').overrideWith(
              (_) async => throw DioException(
                requestOptions: RequestOptions(
                  path: '/customer/orders/ord_maintenance',
                ),
                response: Response<Map<String, dynamic>>(
                  requestOptions: RequestOptions(
                    path: '/customer/orders/ord_maintenance',
                  ),
                  statusCode: 503,
                  data: const {
                    'error': {
                      'code': 'maintenance_active',
                      'message': 'ระบบอยู่ระหว่างปรับปรุง',
                    },
                  },
                ),
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

      expect(find.text('Maintenance route'), findsOneWidget);
      expect(router.routeInformationProvider.value.uri.path, '/maintenance');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'success receipt forwards maintenance errors to shared route flow',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/success?order_id=ord_maintenance',
        routes: [
          GoRoute(
            path: '/success',
            builder: (context, state) =>
                SuccessScreen(orderId: state.uri.queryParameters['order_id']),
          ),
          GoRoute(
            path: '/maintenance',
            builder: (context, state) =>
                const Scaffold(body: Center(child: Text('Maintenance route'))),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            purchaseHistoryDetailProvider('ord_maintenance').overrideWith(
              (_) async => throw DioException(
                requestOptions: RequestOptions(
                  path: '/customer/orders/ord_maintenance',
                ),
                response: Response<Map<String, dynamic>>(
                  requestOptions: RequestOptions(
                    path: '/customer/orders/ord_maintenance',
                  ),
                  statusCode: 503,
                  data: const {
                    'error': {
                      'code': 'maintenance_active',
                      'message': 'ระบบอยู่ระหว่างปรับปรุง',
                    },
                  },
                ),
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

      expect(find.text('Maintenance route'), findsOneWidget);
      expect(router.routeInformationProvider.value.uri.path, '/maintenance');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('success receipt primary action returns to tickets', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/success?order_id=ord_1',
      routes: [
        GoRoute(
          path: '/success',
          builder: (context, state) =>
              SuccessScreen(orderId: state.uri.queryParameters['order_id']),
        ),
        GoRoute(
          path: '/tickets',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('Tickets route'))),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          purchaseHistoryDetailProvider(
            'ord_1',
          ).overrideWith((_) async => _successOrder()),
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

    expect(find.byIcon(Icons.arrow_back_ios_new), findsNothing);

    final primaryAction = find.widgetWithText(FilledButton, 'ดูสลากฯ ของฉัน');
    expect(primaryAction, findsOneWidget);
    await tester.ensureVisible(primaryAction);
    await tester.pumpAndSettle();
    await tester.tap(primaryAction);
    await tester.pumpAndSettle();

    expect(find.text('Tickets route'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('success receipt export file names normalize order references', () {
    final order = PurchaseHistoryOrder.fromJson({
      'id': 'ord_1',
      'reference': 'ORD 2569/07/01 0001',
    });

    expect(
      successReceiptImageFileName(order),
      'receipt-ord-2569-07-01-0001.png',
    );
    expect(successReceiptPdfFileName(order), 'receipt-ord-2569-07-01-0001.pdf');
  });

  test(
    'PdfReceiptPdfExporter builds a shareable PDF from receipt PNG',
    () async {
      final pdfBytes = await PdfReceiptPdfExporter().buildPdf(
        imageBytes: base64Decode(_transparentPngBase64),
      );

      expect(String.fromCharCodes(pdfBytes.take(4)), '%PDF');
      expect(pdfBytes.length, greaterThan(100));
    },
  );
}

class _RecordingReceiptExportCoordinator implements ReceiptExportCoordinator {
  int calls = 0;
  GlobalKey? boundaryKey;
  String text = '';
  String imageFileName = '';
  String pdfFileName = '';

  @override
  Future<ReceiptExportResult> exportReceipt({
    required GlobalKey boundaryKey,
    required String text,
    required String subject,
    required String imageFileName,
    required String pdfFileName,
    Rect? sharePositionOrigin,
  }) async {
    calls += 1;
    this.boundaryKey = boundaryKey;
    this.text = text;
    this.imageFileName = imageFileName;
    this.pdfFileName = pdfFileName;
    return ReceiptExportResult.shared;
  }
}

const _transparentPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4//8/AwAI/AL+p5qgoAAAAABJRU5ErkJggg==';

const _receiptLogoDataUri =
    'data:image/png;base64,'
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/'
    'x8AAwMCAO+/p9sAAAAASUVORK5CYII=';

PurchaseHistoryOrder _successOrder() {
  return PurchaseHistoryOrder.fromJson({
    'id': 'ord_loading',
    'reference': 'ORD-LOADING',
    'payment_method': 'wallet',
    'total': {'amount': 8000, 'currency': 'THB'},
    'ticket_count': 1,
  });
}

class _RecordingLinkLauncher extends CustomerLinkLauncher {
  Uri? openedUri;
  final openedUris = <Uri>[];

  @override
  Future<bool> openExternal(
    Uri uri, {
    bool preferSameWindowInLine = false,
  }) async {
    openedUri = uri;
    openedUris.add(uri);
    return true;
  }
}

CurrentGame _currentGame({required String status, Object? saleStartAt}) {
  return CurrentGame(
    id: 'game_1',
    name: 'Current draw',
    status: status,
    drawAt: '2026-06-26T16:00:00+07:00',
    saleStartAt: saleStartAt,
  );
}
