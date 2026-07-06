import 'dart:async';
import 'dart:convert';

import 'package:customer_flutter/core/i18n/app_locale.dart';
import 'package:customer_flutter/core/i18n/customer_localizations.dart';
import 'package:customer_flutter/core/navigation/customer_link_launcher.dart';
import 'package:customer_flutter/core/theme/app_theme.dart';
import 'package:customer_flutter/core/tenant/mobile_bootstrap_controller.dart';
import 'package:customer_flutter/features/purchase_history/data/purchase_history_models.dart';
import 'package:customer_flutter/features/purchase_history/data/purchase_history_repository.dart';
import 'package:customer_flutter/features/results/data/result_models.dart';
import 'package:customer_flutter/features/system/presentation/system_pages.dart';
import 'package:customer_flutter/shared/widgets/customer_loading_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      maintenanceSupportUrlUri('https://partner.example.com/support')
          ?.toString(),
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

    expect(find.text('ติดต่อฝ่ายบริการผ่านเว็บไซต์'), findsOneWidget);
    await tester.tap(find.byType(OutlinedButton));
    await tester.pump();

    expect(
      launcher.openedUri?.toString(),
      'https://partner.example.com/support',
    );
  });

  testWidgets('maintenance support button falls back to runtime support email',
      (
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

    expect(find.text('ติดต่อฝ่ายบริการ support@example.test'), findsOneWidget);
    await tester.ensureVisible(find.byType(OutlinedButton));
    await tester.tap(find.byType(OutlinedButton));
    await tester.pump();

    expect(launcher.openedUri?.toString(), 'mailto:support@example.test');
  });

  testWidgets('maintenance support button prefers callable phone over URL', (
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
              'supportConfig': {
                'supportUrl': 'https://partner.example.com/support',
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

  testWidgets(
    'account suspended support button falls back to runtime support URL',
    (tester) async {
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
            home: const AccountSuspendedScreen(reason: 'Risk review'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('ติดต่อฝ่ายบริการผ่านเว็บไซต์'), findsOneWidget);
      await tester.ensureVisible(find.byType(OutlinedButton));
      await tester.tap(find.byType(OutlinedButton));
      await tester.pump();

      expect(
        launcher.openedUri?.toString(),
        'https://partner.example.com/support',
      );
    },
  );

  testWidgets(
      'account suspended support button prefers callable phone over URL',
      (tester) async {
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
              'supportConfig': {
                'supportUrl': 'https://partner.example.com/support',
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
          home: const AccountSuspendedScreen(reason: 'Risk review'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('ติดต่อฝ่ายบริการ 02-528-9682'), findsOneWidget);
    await tester.ensureVisible(find.byType(OutlinedButton));
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
    String? clipboardText;
    final shareService = _RecordingReceiptShareService();
    final imageExporter = _FakeReceiptImageExporter();
    final pdfExporter = _FakeReceiptPdfExporter();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboardText = (call.arguments as Map?)?['text']?.toString();
        return null;
      }
      if (call.method == 'Clipboard.getData') {
        return {'text': clipboardText};
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

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
          purchaseHistoryDetailProvider('ord_1').overrideWith(
            (_) async => order,
          ),
          receiptShareServiceProvider.overrideWithValue(shareService),
          receiptImageExporterProvider.overrideWithValue(imageExporter),
          receiptPdfExporterProvider.overrideWithValue(pdfExporter),
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
    expect(find.text('80.00 บาท'), findsOneWidget);
    expect(find.textContaining('วันที่ทำรายการ'), findsOneWidget);
    expect(find.textContaining('รหัสอ้างอิง'), findsOneWidget);
    expect(find.textContaining('ORD-25690701-0001'), findsOneWidget);
    expect(find.text('บันทึก'), findsOneWidget);

    final saveButton = find.widgetWithText(OutlinedButton, 'บันทึก');
    await tester.ensureVisible(saveButton);
    await tester.pumpAndSettle();
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(find.text('บันทึกข้อมูลการชำระเงินแล้ว'), findsOneWidget);
    final clipboard = await Clipboard.getData('text/plain');
    expect(clipboard?.text, contains('ORD-25690701-0001'));
    expect(clipboard?.text, contains('ซื้อสลากหกหลักแบบดิจิทัลสำเร็จ'));

    final shareButton = find.widgetWithText(OutlinedButton, 'แชร์');
    await tester.ensureVisible(shareButton);
    await tester.pumpAndSettle();
    await tester.tap(shareButton);
    await tester.pumpAndSettle();

    expect(shareService.subject, 'ซื้อสลากหกหลักแบบดิจิทัลสำเร็จ');
    expect(shareService.text, contains('ORD-25690701-0001'));
    expect(shareService.text, contains('ร้านค้าสลากฯ เดโม'));
    expect(shareService.fileName, 'receipt-ord-25690701-0001.png');
    expect(shareService.imageBytes, imageExporter.bytes);
    expect(shareService.pdfFileName, 'receipt-ord-25690701-0001.pdf');
    expect(shareService.pdfBytes, pdfExporter.bytes);
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
          purchaseHistoryDetailProvider('ord_loading').overrideWith(
            (_) => completer.future,
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
          home: const SuccessScreen(orderId: 'ord_loading'),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('ซื้อสลากหกหลักแบบดิจิทัลสำเร็จ'), findsOneWidget);
    expect(
      find.text('คุณสามารถดูสลากฯ ได้ที่เมนู สลากฯ ของฉัน'),
      findsOneWidget,
    );
    expect(find.byType(CustomerLoadingMark), findsOneWidget);
    expect(find.text('กำลังโหลดข้อมูลการชำระเงิน...'), findsOneWidget);
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
          builder: (context, state) => SuccessScreen(
            orderId: state.uri.queryParameters['order_id'],
          ),
        ),
        GoRoute(
          path: '/tickets',
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('Tickets fallback')),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          purchaseHistoryDetailProvider('ord_error').overrideWith(
            (_) async => throw StateError('receipt unavailable'),
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

    expect(find.text('ซื้อสลากหกหลักแบบดิจิทัลสำเร็จ'), findsOneWidget);
    expect(find.text('โหลดข้อมูลการชำระเงินไม่สำเร็จ'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'ลองใหม่'), findsOneWidget);
    final fallbackButton = find.widgetWithText(FilledButton, 'ดูสลากฯ ของฉัน');
    expect(fallbackButton, findsOneWidget);

    await tester.ensureVisible(fallbackButton);
    await tester.pumpAndSettle();
    await tester.tap(fallbackButton);
    await tester.pumpAndSettle();

    expect(find.text('Tickets fallback'), findsOneWidget);
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
    expect(
      successReceiptPdfFileName(order),
      'receipt-ord-2569-07-01-0001.pdf',
    );
  });

  test('PdfReceiptPdfExporter builds a shareable PDF from receipt PNG',
      () async {
    final pdfBytes = await PdfReceiptPdfExporter().buildPdf(
      imageBytes: base64Decode(_transparentPngBase64),
    );

    expect(String.fromCharCodes(pdfBytes.take(4)), '%PDF');
    expect(pdfBytes.length, greaterThan(100));
  });
}

const _transparentPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4//8/AwAI/AL+p5qgoAAAAABJRU5ErkJggg==';

class _RecordingReceiptShareService implements ReceiptShareService {
  String? text;
  String? subject;
  Uint8List? imageBytes;
  String? fileName;
  Uint8List? pdfBytes;
  String? pdfFileName;

  @override
  Future<void> shareReceipt({
    required String text,
    required String subject,
    Uint8List? imageBytes,
    String? fileName,
    Uint8List? pdfBytes,
    String? pdfFileName,
  }) async {
    this.text = text;
    this.subject = subject;
    this.imageBytes = imageBytes;
    this.fileName = fileName;
    this.pdfBytes = pdfBytes;
    this.pdfFileName = pdfFileName;
  }
}

class _FakeReceiptImageExporter implements ReceiptImageExporter {
  final bytes = Uint8List.fromList([0x89, 0x50, 0x4e, 0x47]);

  @override
  Future<Uint8List> capturePng(GlobalKey boundaryKey) async {
    return bytes;
  }
}

class _FakeReceiptPdfExporter implements ReceiptPdfExporter {
  final bytes = Uint8List.fromList([0x25, 0x50, 0x44, 0x46]);

  @override
  Future<Uint8List> buildPdf({required Uint8List imageBytes}) async {
    return bytes;
  }
}

const _receiptLogoDataUri = 'data:image/png;base64,'
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
