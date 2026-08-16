import 'dart:async';
import 'dart:typed_data';

import 'package:customer_flutter/core/auth/auth_token_store.dart';
import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/i18n/app_locale.dart';
import 'package:customer_flutter/core/i18n/customer_localizations.dart';
import 'package:customer_flutter/core/network/api_client.dart';
import 'package:customer_flutter/core/theme/app_theme.dart';
import 'package:customer_flutter/features/topup/data/topup_models.dart';
import 'package:customer_flutter/features/topup/data/topup_repository.dart';
import 'package:customer_flutter/features/topup/presentation/topup_realtime_monitor.dart';
import 'package:customer_flutter/features/topup/presentation/topup_screen.dart';
import 'package:customer_flutter/shared/services/receipt_export_service.dart';
import 'package:customer_flutter/shared/widgets/customer_gradient_button.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _runtimeTopupLogo =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=';

void main() {
  test('safeTopupBackPath follows the Nuxt return allowlist', () {
    expect(safeTopupBackPath('/'), '/');
    expect(safeTopupBackPath('/checkout'), '/checkout');
    expect(safeTopupBackPath('/my-wallet'), '/my-wallet');
    expect(safeTopupBackPath('/profile'), '/profile');
    expect(safeTopupBackPath('/tickets'), '/my-wallet');
    expect(safeTopupBackPath('https://example.invalid'), '/my-wallet');
    expect(safeTopupBackPath(null), '/my-wallet');
  });

  test('topup detail location keeps a safe return path', () {
    expect(
      topupDetailLocation('topup_1', backPath: '/checkout'),
      '/topup/topup_1?back=%2Fcheckout',
    );
    expect(
      topupDetailLocation('top up/1', backPath: '/topup/history'),
      '/topup/top%20up%2F1?back=%2Ftopup%2Fhistory',
    );
    expect(
      topupDetailLocation('topup_2', backPath: 'https://example.invalid'),
      '/topup/topup_2?back=%2Fmy-wallet',
    );
  });

  test('topup landing location keeps a safe return path after cancel', () {
    expect(topupLocation(backPath: '/checkout'), '/topup?back=%2Fcheckout');
    expect(
      topupLocation(backPath: 'https://example.invalid'),
      '/topup?back=%2Fmy-wallet',
    );
  });

  testWidgets('topup screen honors allowed Nuxt back query targets', (
    tester,
  ) async {
    await _pumpTopupRoute(tester, '/topup?back=/checkout');

    await tester.tap(find.byTooltip('ย้อนกลับ'));
    await tester.pumpAndSettle();

    expect(find.text('checkout route'), findsOneWidget);
  });

  testWidgets('topup entry redirects unfinished request to detail', (
    tester,
  ) async {
    await _pumpTopupRoute(
      tester,
      '/topup?back=/checkout',
      overview: _waitingTopupOverview(
        const TopupRequestItem(
          id: 'top_waiting_redirect',
          amount: 800,
          bonusAmount: 0,
          status: TopupStatus.pendingReview,
          channel: TopupChannel.bankTransfer,
          provider: 'manual',
          transferAt: null,
          createdAt: '2026-06-26T10:00:00+07:00',
          slipUrl: '',
          slipThumbUrl: '',
          qrCode: '',
          redirectUrl: '',
          message: '',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('topup detail route top_waiting_redirect back=/checkout'),
      findsOneWidget,
    );
  });

  testWidgets('topup launcher follows the Nuxt hero controls', (tester) async {
    await _pumpTopupRoute(tester, '/topup');

    expect(find.text('เติมเงินเข้า Runtime Blue Wallet'), findsWidgets);
    expect(find.text('ดูประวัติเติมเงิน'), findsOneWidget);
    expect(find.text('เลือกช่องทางการเติมเงิน'), findsOneWidget);
    expect(find.text('วิธีการเติมเงินผ่านธนาคาร'), findsNothing);
    expect(
      find.byKey(const ValueKey('topup-channel-method-logo-qr')),
      findsNothing,
    );
    expect(
      find.ancestor(
        of: find.text('เลือกช่องทางการเติมเงิน'),
        matching: find.byType(Card),
      ),
      findsNothing,
    );
    expect(
      find.ancestor(of: find.text('QR Code'), matching: find.byType(Card)),
      findsNothing,
    );
  });

  testWidgets('topup screen refreshes waiting request on realtime tick', (
    tester,
  ) async {
    var loads = 0;
    final container = ProviderContainer(
      overrides: [
        topupOverviewProvider.overrideWith((_) async {
          loads++;
          return loads == 1
              ? _emptyTopupOverview()
              : _waitingTopupOverview(
                  const TopupRequestItem(
                    id: 'top_realtime_pending',
                    amount: 750,
                    bonusAmount: 35,
                    status: TopupStatus.pendingPayment,
                    channel: TopupChannel.qr,
                    provider: 'runtime_qr',
                    transferAt: null,
                    createdAt: '2026-06-26T10:00:00+07:00',
                    slipUrl: '',
                    slipThumbUrl: '',
                    qrCode: '',
                    redirectUrl: '',
                    message: '',
                  ),
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
          home: const TopupScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(loads, 1);
    expect(find.text('รายการเติมเงินที่ยังไม่เสร็จ'), findsNothing);

    container.read(topupRealtimeTickProvider.notifier).state++;
    await tester.pump();
    await tester.pumpAndSettle();

    expect(loads, 2);
    expect(find.text('รายการเติมเงินที่ยังไม่เสร็จ'), findsOneWidget);
    expect(find.text('รายการ #top_realtime_pending'), findsOneWidget);
    expect(find.text('750 บาท'), findsOneWidget);
    expect(find.text('โบนัส 35 บาท'), findsOneWidget);
    expect(find.text('สลิปชำระเงิน'), findsOneWidget);
    expect(find.text('แนบสลิปชำระเงิน'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('topup screen keeps disabled payment channels visible', (
    tester,
  ) async {
    await _pumpTopupScreen(
      tester,
      TopupOverview(
        bank: const TopupBankAccount(
          bankName: 'ธนาคารทดสอบ',
          accountName: 'ร้านทดสอบ',
          accountNumber: '123-4-56789-0',
        ),
        banks: const [
          TopupBankAccount(
            bankName: 'ธนาคารทดสอบ',
            accountName: 'ร้านทดสอบ',
            accountNumber: '123-4-56789-0',
          ),
          TopupBankAccount(
            bankName: 'ธนาคารสำรอง',
            accountName: 'ร้านทดสอบ',
            accountNumber: '987-6-54321-0',
          ),
        ],
        paymentMethods: const [
          TopupPaymentMethod(
            key: 'qr',
            label: 'QR Code',
            enabled: false,
            description: '',
          ),
          TopupPaymentMethod(
            key: 'credit_card',
            label: 'Credit QR Code',
            enabled: false,
            description: '',
          ),
          TopupPaymentMethod(
            key: 'bank_transfer',
            label: 'โอนธนาคาร',
            enabled: true,
            description: '',
          ),
        ],
        enabledPaymentMethods: const {'bank_transfer'},
        waiting: null,
        histories: const [],
        currentPage: 1,
        lastPage: 1,
      ),
    );

    expect(find.text('QR Code'), findsOneWidget);
    expect(find.text('Credit Card QR'), findsOneWidget);
    expect(find.text('โอนธนาคาร'), findsOneWidget);
    expect(find.text('ปิดบริการชั่วคราว'), findsNWidgets(2));
    expect(find.text('วิธีการเติมเงินผ่านธนาคาร'), findsNothing);
    expect(find.text('ธนาคารทดสอบ'), findsNothing);
    expect(find.text('ธนาคารสำรอง'), findsNothing);
    expect(find.text('123-4-56789-0'), findsNothing);

    final bankTile = find
        .ancestor(
          of: find.text('โอนธนาคาร'),
          matching: find.byType(GestureDetector),
        )
        .first;
    await tester.ensureVisible(bankTile);
    await tester.pumpAndSettle();
    await tester.tap(bankTile);
    await tester.pumpAndSettle();

    expect(find.text('จำนวนเงินที่ต้องการเติม'), findsOneWidget);
    expect(find.text('ธนาคารทดสอบ'), findsNothing);
    expect(find.text('123-4-56789-0'), findsNothing);
    expect(
      find.widgetWithText(CustomerGradientButton, 'ชำระเงิน'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(CustomerGradientButton, 'ชำระเงิน'));
    await tester.pumpAndSettle();

    expect(find.text('ธนาคารทดสอบ'), findsOneWidget);
    expect(find.text('123-4-56789-0'), findsOneWidget);
    expect(
      find.widgetWithText(CustomerGradientButton, 'ยืนยันชำระเงิน'),
      findsOneWidget,
    );
  });

  testWidgets('qr and credit sheets match Nuxt amount and slip-note layout', (
    tester,
  ) async {
    await _pumpTopupScreen(
      tester,
      TopupOverview(
        bank: const TopupBankAccount(
          bankName: 'ธนาคารทดสอบ',
          accountName: 'ร้านทดสอบ',
          accountNumber: '123-4-56789-0',
        ),
        paymentMethods: const [
          TopupPaymentMethod(
            key: 'qr',
            label: 'QR Code',
            enabled: true,
            description: '',
          ),
          TopupPaymentMethod(
            key: 'credit_card',
            label: 'Credit QR Code',
            enabled: true,
            description: '',
          ),
          TopupPaymentMethod(
            key: 'bank_transfer',
            label: 'โอนธนาคาร',
            enabled: true,
            description: '',
          ),
        ],
        enabledPaymentMethods: const {'qr', 'credit_card', 'bank_transfer'},
        waiting: null,
        histories: const [],
        currentPage: 1,
        lastPage: 1,
      ),
    );

    await tester.tap(find.text('QR Code'));
    await tester.pumpAndSettle();

    expect(find.text('จำนวนเงินที่ต้องการเติม'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '100'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '1,000'), findsOneWidget);
    expect(find.byType(ActionChip), findsNothing);
    expect(
      find.text('สร้าง QR Code แล้วแนบสลิปหลังชำระเงินเพื่อให้ร้านค้าตรวจสอบ'),
      findsNothing,
    );
    expect(find.text('ข้อมูลการชำระเงิน'), findsNothing);
    expect(
      find.widgetWithText(CustomerGradientButton, 'ชำระเงิน'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField), '1000');
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      '1000',
    );
    expect(
      find.text('สร้าง QR Code แล้วแนบสลิปหลังชำระเงินเพื่อให้ร้านค้าตรวจสอบ'),
      findsNothing,
    );

    await tester.tap(find.byIcon(Icons.close).last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Credit Card QR'));
    await tester.pumpAndSettle();

    expect(find.text('จำนวนเงินที่ต้องการเติม'), findsOneWidget);
    expect(
      find.text('ช่องทางนี้จะแสดงเป็น QR Code และแนบสลิปหลังชำระเงินได้'),
      findsNothing,
    );
    expect(
      find.widgetWithText(CustomerGradientButton, 'ชำระเงิน'),
      findsOneWidget,
    );
    expect(
      find.text('ช่องทางนี้จะแสดงเป็น QR Code และแนบสลิปหลังชำระเงินได้'),
      findsNothing,
    );
    expect(find.text('สร้าง Credit QR Code'), findsNothing);
  });

  testWidgets('topup sheet is bottom anchored and capped to 90 percent', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 520);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpTopupScreen(tester, _emptyTopupOverview());

    await tester.tap(find.text('QR Code'));
    await tester.pumpAndSettle();

    final sheet = find.byKey(const ValueKey('topup-modal-bottom-sheet'));
    expect(sheet, findsOneWidget);

    final sheetRect = tester.getRect(sheet);
    expect(sheetRect.bottom, moreOrLessEquals(520, epsilon: 0.5));
    expect(sheetRect.height, lessThanOrEqualTo(520 * 0.9 + 0.5));
    expect(sheetRect.left, moreOrLessEquals(0, epsilon: 0.5));
    expect(sheetRect.right, moreOrLessEquals(390, epsilon: 0.5));

    final createQr = find.widgetWithText(CustomerGradientButton, 'ชำระเงิน');
    final createRect = tester.getRect(createQr);
    expect(sheetRect.bottom - createRect.bottom, lessThanOrEqualTo(18));
  });

  testWidgets('topup uses Nuxt labels with runtime payment minimums', (
    tester,
  ) async {
    final repository = _FailingCreateTopupRepository(
      StateError('should not submit below runtime minimum'),
    );

    await _pumpTopupScreen(
      tester,
      TopupOverview(
        bank: const TopupBankAccount(
          bankName: '',
          accountName: '',
          accountNumber: '',
        ),
        paymentMethods: const [
          TopupPaymentMethod(
            key: 'qr',
            label: 'QR Code',
            enabled: true,
            description: '',
          ),
          TopupPaymentMethod(
            key: 'credit_card',
            label: 'Credit Runtime QR',
            enabled: true,
            description: 'ขั้นต่ำตาม provider ของร้านค้า',
            minimumAmount: 750,
          ),
          TopupPaymentMethod(
            key: 'bank_transfer',
            label: 'โอนธนาคาร',
            enabled: true,
            description: '',
          ),
        ],
        enabledPaymentMethods: const {'qr', 'credit_card', 'bank_transfer'},
        waiting: null,
        histories: const [],
        currentPage: 1,
        lastPage: 1,
      ),
      repository: repository,
    );

    expect(find.text('Credit Card QR'), findsOneWidget);
    expect(find.text('Credit Runtime QR'), findsNothing);
    expect(find.text('ขั้นต่ำตาม provider ของร้านค้า'), findsNothing);

    await tester.tap(find.text('Credit Card QR'));
    await tester.pumpAndSettle();

    expect(find.text('ขั้นต่ำตาม provider ของร้านค้า'), findsNothing);

    final createQr = find.widgetWithText(CustomerGradientButton, 'ชำระเงิน');
    tester.widget<CustomerGradientButton>(createQr).onPressed!();
    await tester.pump();

    expect(repository.createCalls, 0);
    expect(find.text('Credit Card QR ขั้นต่ำ 750 บาท'), findsOneWidget);
    expect(find.text('ข้อมูลการชำระเงิน'), findsNothing);
    expect(
      find.textContaining('should not submit below runtime minimum'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('bank transfer requires a slip before creating request', (
    tester,
  ) async {
    await _pumpTopupScreen(
      tester,
      TopupOverview(
        bank: const TopupBankAccount(
          bankCode: 'kbank',
          bankName: 'ธนาคารทดสอบ',
          accountName: 'ร้านทดสอบ',
          accountNumber: '123-4-56789-0',
        ),
        paymentMethods: const [
          TopupPaymentMethod(
            key: 'qr',
            label: 'QR Code',
            enabled: true,
            description: '',
          ),
          TopupPaymentMethod(
            key: 'credit_card',
            label: 'Credit QR Code',
            enabled: true,
            description: '',
          ),
          TopupPaymentMethod(
            key: 'bank_transfer',
            label: 'โอนธนาคาร',
            enabled: true,
            description: '',
          ),
        ],
        enabledPaymentMethods: const {'qr', 'credit_card', 'bank_transfer'},
        waiting: null,
        histories: const [],
        currentPage: 1,
        lastPage: 1,
      ),
    );

    await tester.ensureVisible(find.text('โอนธนาคาร'));
    await tester.tap(find.text('โอนธนาคาร'));
    await tester.pumpAndSettle();

    expect(find.text('จำนวนเงินที่ต้องการเติม'), findsOneWidget);
    expect(find.text('วันเวลาที่โอน'), findsNothing);
    expect(find.text('สลิปโอนเงิน'), findsNothing);
    expect(find.text('ธนาคารทดสอบ'), findsNothing);

    await tester.tap(find.widgetWithText(CustomerGradientButton, 'ชำระเงิน'));
    await tester.pumpAndSettle();

    expect(find.text('ยอดที่ต้องชำระ'), findsOneWidget);
    expect(find.text('500 บาท'), findsOneWidget);
    expect(find.text('ธนาคารทดสอบ'), findsOneWidget);
    expect(find.byKey(const ValueKey('topup-bank-logo-kbank')), findsOneWidget);
    expect(find.text('ชื่อบัญชี'), findsOneWidget);
    expect(find.text('เลขที่บัญชี'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('topup-bank-copy-account')),
      findsOneWidget,
    );
    String? copiedAccountNumber;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copiedAccountNumber = (call.arguments as Map<Object?, Object?>)['text']
              ?.toString();
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });
    await tester.ensureVisible(
      find.byKey(const ValueKey('topup-bank-copy-account')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('topup-bank-copy-account')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(copiedAccountNumber, '123-4-56789-0');
    expect(find.text('คัดลอกแล้ว'), findsOneWidget);
    expect(find.text('วันเวลาที่โอน'), findsOneWidget);
    final transferTimeButton = find.ancestor(
      of: find.byIcon(Icons.schedule),
      matching: find.byType(OutlinedButton),
    );
    expect(transferTimeButton, findsOneWidget);
    expect(find.text('สลิปโอนเงิน'), findsOneWidget);
    expect(find.text('แนบสลิป'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('วันเวลาที่โอน')).dy,
      lessThan(tester.getTopLeft(find.text('แนบสลิป')).dy),
    );

    await Scrollable.ensureVisible(
      tester.element(transferTimeButton),
      alignment: 0.45,
    );
    await tester.pumpAndSettle();
    await tester.tap(transferTimeButton);
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('ยกเลิก').last);
    await tester.pumpAndSettle();

    final submit = find.widgetWithText(
      CustomerGradientButton,
      'ยืนยันชำระเงิน',
    );
    final submitButton = tester.widget<CustomerGradientButton>(submit);
    submitButton.onPressed!();
    await tester.pump();

    expect(find.text('กรุณาแนบรูปสลิปก่อนส่งให้แอดมินตรวจสอบ'), findsOneWidget);
  });

  testWidgets('pending QR topup can upload a slip after QR creation', (
    tester,
  ) async {
    await _pumpTopupScreen(
      tester,
      TopupOverview(
        bank: const TopupBankAccount(
          bankName: '',
          accountName: '',
          accountNumber: '',
        ),
        paymentMethods: const [
          TopupPaymentMethod(
            key: 'qr',
            label: 'QR Code',
            enabled: true,
            description: '',
          ),
          TopupPaymentMethod(
            key: 'credit_card',
            label: 'Credit QR Code',
            enabled: true,
            description: '',
          ),
          TopupPaymentMethod(
            key: 'bank_transfer',
            label: 'โอนธนาคาร',
            enabled: true,
            description: '',
          ),
        ],
        enabledPaymentMethods: const {'qr', 'credit_card', 'bank_transfer'},
        waiting: const TopupRequestItem(
          id: 'top_waiting_qr',
          amount: 500,
          bonusAmount: 25,
          status: TopupStatus.pendingPayment,
          channel: TopupChannel.qr,
          provider: 'deepay_kbank',
          transferAt: null,
          createdAt: '2026-06-26T10:00:00+07:00',
          slipUrl: '',
          slipThumbUrl: '',
          qrCode:
              'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=',
          redirectUrl: '',
          message: '',
        ),
        histories: const [],
        currentPage: 1,
        lastPage: 1,
      ),
    );

    expect(find.text('รายการเติมเงินที่ยังไม่เสร็จ'), findsOneWidget);
    expect(find.text('รายการ #top_waiting_qr'), findsOneWidget);
    expect(find.text('500 บาท'), findsOneWidget);
    expect(find.text('โบนัส 25 บาท'), findsOneWidget);
    expect(find.text('สแกน QR Code เพื่อชำระเงิน'), findsOneWidget);
    expect(find.textContaining('26 มิ.ย.'), findsOneWidget);
    expect(find.textContaining('QR Code •'), findsNothing);
    expect(find.text('แนบสลิปชำระเงิน'), findsOneWidget);
    expect(find.text('ยกเลิกรายการเติมเงินนี้'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text('รายการ #top_waiting_qr'),
        matching: find.byType(Card),
      ),
      findsNothing,
    );
  });

  testWidgets('waiting topup card remains readable on compact mobile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpTopupScreen(
      tester,
      TopupOverview(
        bank: const TopupBankAccount(
          bankName: '',
          accountName: '',
          accountNumber: '',
        ),
        paymentMethods: const [],
        enabledPaymentMethods: const {},
        waiting: const TopupRequestItem(
          id: 'top_waiting_compact_bank',
          amount: 1200,
          bonusAmount: 80,
          status: TopupStatus.pendingReview,
          channel: TopupChannel.bankTransfer,
          provider: 'manual',
          transferAt: '2026-06-26T09:30:00+07:00',
          createdAt: '2026-06-26T10:00:00+07:00',
          slipUrl: 'https://partner.example.test/slip.jpg',
          slipThumbUrl: '',
          qrCode: '',
          redirectUrl: '',
          message: 'รายการนี้รอทีมงานตรวจสอบ',
        ),
        histories: const [],
        currentPage: 1,
        lastPage: 1,
      ),
    );

    expect(find.text('รายการเติมเงินที่ยังไม่เสร็จ'), findsOneWidget);
    expect(find.text('รายการ #top_waiting_compact_bank'), findsOneWidget);
    expect(find.text('1,200 บาท'), findsWidgets);
    expect(find.text('โบนัส 80 บาท'), findsOneWidget);
    expect(find.text('สลิปชำระเงิน'), findsOneWidget);
    expect(find.text('ส่งแล้ว'), findsOneWidget);
    expect(find.text('อัพโหลดสลิปใหม่'), findsOneWidget);
    expect(find.text('รายการนี้รอทีมงานตรวจสอบ'), findsOneWidget);
    expect(find.textContaining('26 มิ.ย.'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text('รายการ #top_waiting_compact_bank'),
        matching: find.byType(Card),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('unfinished topup blocks creating a new request', (tester) async {
    await _pumpTopupScreen(
      tester,
      TopupOverview(
        bank: const TopupBankAccount(
          bankName: 'ธนาคารทดสอบ',
          accountName: 'ร้านทดสอบ',
          accountNumber: '123-4-56789-0',
        ),
        paymentMethods: const [
          TopupPaymentMethod(
            key: 'qr',
            label: 'QR Code',
            enabled: true,
            description: '',
          ),
          TopupPaymentMethod(
            key: 'credit_card',
            label: 'Credit QR Code',
            enabled: true,
            description: '',
          ),
          TopupPaymentMethod(
            key: 'bank_transfer',
            label: 'โอนธนาคาร',
            enabled: true,
            description: '',
          ),
        ],
        enabledPaymentMethods: const {'qr', 'credit_card', 'bank_transfer'},
        waiting: const TopupRequestItem(
          id: 'top_waiting_qr',
          amount: 500,
          bonusAmount: 0,
          status: TopupStatus.pendingPayment,
          channel: TopupChannel.qr,
          provider: 'deepay_kbank',
          transferAt: null,
          createdAt: '2026-06-26T10:00:00+07:00',
          slipUrl: '',
          slipThumbUrl: '',
          qrCode: '',
          redirectUrl: '',
          message: '',
        ),
        histories: const [],
        currentPage: 1,
        lastPage: 1,
      ),
    );

    expect(find.text('มีรายการเติมเงินค้างอยู่'), findsNothing);
    expect(
      find.text('กรุณาชำระหรือยกเลิกรายการเดิมก่อนสร้างรายการใหม่'),
      findsNothing,
    );
    expect(find.text('รายการเติมเงินที่ยังไม่เสร็จ'), findsOneWidget);
    expect(
      find.widgetWithText(CustomerGradientButton, 'ชำระเงิน'),
      findsNothing,
    );

    await tester.ensureVisible(find.text('โอนธนาคาร'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('โอนธนาคาร'));
    await tester.pumpAndSettle();

    expect(find.text('ธนาคารทดสอบ'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('topup create API error uses server copy like Nuxt', (
    tester,
  ) async {
    final repository = _FailingCreateTopupRepository(
      _apiException('ระบบเติมเงินปิดปรับปรุง'),
    );

    await _pumpTopupScreen(
      tester,
      _emptyTopupOverview(),
      repository: repository,
    );

    await tester.tap(find.text('QR Code'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CustomerGradientButton, 'ชำระเงิน'));
    await tester.pumpAndSettle();

    expect(repository.createCalls, 0);
    await tester.tap(
      find.widgetWithText(CustomerGradientButton, 'ยืนยันชำระเงิน'),
    );
    await tester.pumpAndSettle();

    expect(repository.createCalls, 1);
    expect(repository.createdChannel, TopupChannel.qr);
    expect(find.text('ระบบเติมเงินปิดปรับปรุง'), findsOneWidget);
    expect(
      find.text('สร้างรายการเติมเงินไม่สำเร็จ กรุณาลองใหม่'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('topup create internal error falls back to localized copy', (
    tester,
  ) async {
    final repository = _FailingCreateTopupRepository(
      StateError('internal topup create failed'),
    );

    await _pumpTopupScreen(
      tester,
      _emptyTopupOverview(),
      repository: repository,
    );

    await tester.tap(find.text('QR Code'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CustomerGradientButton, 'ชำระเงิน'));
    await tester.pumpAndSettle();

    expect(repository.createCalls, 0);
    await tester.tap(
      find.widgetWithText(CustomerGradientButton, 'ยืนยันชำระเงิน'),
    );
    await tester.pumpAndSettle();

    expect(repository.createCalls, 1);
    expect(
      find.text('สร้างรายการเติมเงินไม่สำเร็จ กรุณาลองใหม่'),
      findsOneWidget,
    );
    expect(find.textContaining('internal topup create failed'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('topup cancel API error uses server copy like Nuxt', (
    tester,
  ) async {
    final repository = _CancelTopupRepository(
      error: _apiException('ยกเลิกรายการนี้ไม่ได้'),
    );

    await _pumpTopupScreen(
      tester,
      _waitingTopupOverview(
        const TopupRequestItem(
          id: 'top_waiting_bank',
          amount: 800,
          bonusAmount: 0,
          status: TopupStatus.pendingReview,
          channel: TopupChannel.bankTransfer,
          provider: 'manual',
          transferAt: null,
          createdAt: '2026-06-26T10:00:00+07:00',
          slipUrl: '',
          slipThumbUrl: '',
          qrCode: '',
          redirectUrl: '',
          message: '',
        ),
      ),
      repository: repository,
    );

    await _cancelWaitingTopup(tester);
    await tester.tap(find.text('ยืนยันยกเลิก'));
    await tester.pumpAndSettle();

    expect(repository.cancelCalls, 1);
    expect(repository.cancelledIds, ['top_waiting_bank']);
    expect(find.text('ยกเลิกรายการนี้ไม่ได้'), findsOneWidget);
    expect(find.text('ยกเลิกรายการไม่สำเร็จ'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('topup cancel internal error falls back to localized copy', (
    tester,
  ) async {
    final repository = _CancelTopupRepository(
      error: StateError('internal topup cancel failed'),
    );

    await _pumpTopupScreen(
      tester,
      _waitingTopupOverview(
        const TopupRequestItem(
          id: 'top_waiting_bank',
          amount: 800,
          bonusAmount: 0,
          status: TopupStatus.pendingReview,
          channel: TopupChannel.bankTransfer,
          provider: 'manual',
          transferAt: null,
          createdAt: '2026-06-26T10:00:00+07:00',
          slipUrl: '',
          slipThumbUrl: '',
          qrCode: '',
          redirectUrl: '',
          message: '',
        ),
      ),
      repository: repository,
    );

    await _cancelWaitingTopup(tester);
    await tester.tap(find.text('ยืนยันยกเลิก'));
    await tester.pumpAndSettle();

    expect(repository.cancelCalls, 1);
    expect(find.text('ยกเลิกรายการไม่สำเร็จ'), findsOneWidget);
    expect(find.textContaining('internal topup cancel failed'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('waiting topup asks for confirmation before cancelling', (
    tester,
  ) async {
    final cancelGate = Completer<void>();
    final repository = _CancelTopupRepository(cancelGate: cancelGate);

    await _pumpTopupScreen(
      tester,
      TopupOverview(
        bank: const TopupBankAccount(
          bankName: '',
          accountName: '',
          accountNumber: '',
        ),
        paymentMethods: const [],
        enabledPaymentMethods: const {},
        waiting: const TopupRequestItem(
          id: 'top_waiting_bank',
          amount: 800,
          bonusAmount: 0,
          status: TopupStatus.pendingReview,
          channel: TopupChannel.bankTransfer,
          provider: 'manual',
          transferAt: null,
          createdAt: '2026-06-26T10:00:00+07:00',
          slipUrl: '',
          slipThumbUrl: '',
          qrCode: '',
          redirectUrl: '',
          message: '',
        ),
        histories: const [],
        currentPage: 1,
        lastPage: 1,
      ),
      repository: repository,
    );

    final cancelWaiting = find.widgetWithText(
      OutlinedButton,
      'ยกเลิกรายการเติมเงินนี้',
    );
    Future<void> tapCancelWaiting() async {
      await Scrollable.ensureVisible(
        tester.element(cancelWaiting),
        alignment: 0.45,
      );
      await tester.pumpAndSettle();
      await tester.tap(cancelWaiting);
      await tester.pumpAndSettle();
    }

    await tapCancelWaiting();

    expect(repository.cancelCalls, 0);
    expect(find.byType(AlertDialog), findsNothing);
    expect(
      find.text('คุณต้องการยกเลิกรายการเติมเงินนี้ใช่หรือไม่'),
      findsOneWidget,
    );
    expect(
      find.text(
        'รายการ #top_waiting_bank จะถูกยกเลิก และคุณสามารถสร้างรายการเติมเงินใหม่ได้ทันที',
      ),
      findsNothing,
    );
    final confirmDialog = find.byType(Dialog);
    expect(
      find.descendant(of: confirmDialog, matching: find.text('ยอดเติมเงิน')),
      findsNothing,
    );
    expect(
      find.descendant(of: confirmDialog, matching: find.text('800 บาท')),
      findsNothing,
    );
    expect(find.widgetWithText(OutlinedButton, 'ไม่ยกเลิก'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'ยืนยันยกเลิก'), findsOneWidget);

    await tester.tap(find.text('ไม่ยกเลิก'));
    await tester.pumpAndSettle();
    expect(repository.cancelCalls, 0);

    await tapCancelWaiting();
    await tester.tap(find.text('ยืนยันยกเลิก'));
    await tester.pump();

    expect(find.text('กำลังยกเลิก...'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'กำลังยกเลิก...'),
          )
          .onPressed,
      isNull,
    );

    cancelGate.complete();
    await tester.pumpAndSettle();

    expect(repository.cancelCalls, 1);
    expect(repository.cancelledIds, ['top_waiting_bank']);
    expect(find.text('ยกเลิกรายการเติมเงินแล้ว'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('topup create navigates to created request detail', (
    tester,
  ) async {
    final repository = _CreateTopupRepository(
      const TopupRequestItem(
        id: 'top_created_qr',
        amount: 500,
        bonusAmount: 0,
        status: TopupStatus.pendingPayment,
        channel: TopupChannel.qr,
        provider: 'deepay_kbank',
        transferAt: null,
        createdAt: '2026-06-26T10:00:00+07:00',
        slipUrl: '',
        slipThumbUrl: '',
        qrCode: 'data:image/png;base64,QR',
        redirectUrl: '',
        message: '',
      ),
    );

    await _pumpTopupRoute(
      tester,
      '/topup?back=/my-wallet',
      repository: repository,
    );

    await tester.tap(find.text('QR Code'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, '500'));
    await tester.pumpAndSettle();

    expect(repository.createCalls, 0);
    await tester.tap(find.widgetWithText(CustomerGradientButton, 'ชำระเงิน'));
    await tester.pumpAndSettle();
    expect(repository.createCalls, 0);
    await tester.tap(
      find.widgetWithText(CustomerGradientButton, 'ยืนยันชำระเงิน'),
    );
    await tester.pumpAndSettle();

    expect(repository.createCalls, 1);
    expect(repository.createdChannel, TopupChannel.qr);
    expect(
      find.text('topup detail route top_created_qr back=/my-wallet'),
      findsOneWidget,
    );
  });

  testWidgets('quick amount waits for confirmation before creating one QR', (
    tester,
  ) async {
    final createGate = Completer<void>();
    final repository = _CreateTopupRepository(
      const TopupRequestItem(
        id: 'top_quick_qr',
        amount: 500,
        bonusAmount: 0,
        status: TopupStatus.pendingPayment,
        channel: TopupChannel.qr,
        provider: 'deepay_kbank',
        transferAt: null,
        createdAt: '2026-08-12T10:00:00+07:00',
        slipUrl: '',
        slipThumbUrl: '',
        qrCode: 'data:image/png;base64,QR',
        redirectUrl: '',
        message: '',
        paymentExpiresAt: '2026-08-12T10:05:00+07:00',
        paymentExpiresInSeconds: 300,
        serverTime: '2026-08-12T10:00:00+07:00',
      ),
      createGate: createGate,
    );

    await _pumpTopupRoute(tester, '/topup', repository: repository);
    await tester.tap(find.text('QR Code'));
    await tester.pumpAndSettle();

    final quickAmount = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, '500'),
    );
    quickAmount.onPressed!();
    quickAmount.onPressed!();
    await tester.pumpAndSettle();

    expect(repository.createCalls, 0);
    expect(find.text('กำลังสร้าง QR...'), findsNothing);

    await tester.tap(find.widgetWithText(CustomerGradientButton, 'ชำระเงิน'));
    await tester.pumpAndSettle();

    expect(repository.createCalls, 0);
    final confirm = tester.widget<CustomerGradientButton>(
      find.widgetWithText(CustomerGradientButton, 'ยืนยันชำระเงิน'),
    );
    confirm.onPressed!();
    confirm.onPressed!();
    await tester.pump();

    expect(repository.createCalls, 1);
    expect(find.text('กำลังสร้าง QR...'), findsWidgets);
    final loadingDialog = find.byKey(
      const ValueKey('topup-create-loading-dialog'),
    );
    final logicalSize = tester.view.physicalSize / tester.view.devicePixelRatio;
    final loadingCenter = tester.getCenter(loadingDialog);
    expect(loadingCenter.dx, closeTo(logicalSize.width / 2, 1));
    expect(loadingCenter.dy, closeTo(logicalSize.height / 2, 1));

    createGate.complete();
    await tester.pumpAndSettle();

    expect(
      find.text('topup detail route top_quick_qr back=/my-wallet'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('topup detail screen renders the selected request', (
    tester,
  ) async {
    final repository = _DetailTopupRepository(
      const TopupRequestItem(
        id: 'top_detail_1',
        amount: 1200,
        bonusAmount: 80,
        status: TopupStatus.pendingReview,
        channel: TopupChannel.bankTransfer,
        provider: 'manual',
        transferAt: '2026-06-26T09:30:00+07:00',
        createdAt: '2026-06-26T10:00:00+07:00',
        slipUrl: 'https://partner.example.test/slip.jpg',
        slipThumbUrl: '',
        qrCode: '',
        redirectUrl: '',
        message: 'รายการนี้รอทีมงานตรวจสอบ',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          topupRepositoryProvider.overrideWithValue(repository),
          topupOverviewProvider.overrideWith(
            (_) async => _emptyTopupOverview(),
          ),
        ],
        child: MaterialApp(
          locale: fallbackCustomerLocale,
          supportedLocales: supportedCustomerLocales,
          localizationsDelegates: [
            CustomerLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: AppTheme.light(),
          home: const TopupScreen(
            detailTopupId: 'top_detail_1',
            backPath: '/my-wallet',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.detailCalls, 1);
    expect(repository.detailIds, ['top_detail_1']);
    expect(
      find.byKey(const ValueKey('topup-detail-headerless-page')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('topup-detail-fixed-header')),
      findsNothing,
    );
    expect(find.text('ข้อมูลรายการเติมเงิน'), findsOneWidget);
    expect(find.text('รายการ #top_detail_1'), findsOneWidget);
    expect(find.text('1,200 บาท'), findsOneWidget);
    expect(find.text('โบนัส 80 บาท'), findsOneWidget);
    expect(find.text('รายการนี้รอทีมงานตรวจสอบ'), findsOneWidget);
  });

  testWidgets('QR detail centers payment art and keeps values right aligned', (
    tester,
  ) async {
    final imageExporter = _RecordingTopupQrImageExporter();
    final shareService = _RecordingTopupQrShareService();
    final repository = _DetailTopupRepository(
      const TopupRequestItem(
        id: 'qr_detail_1',
        reference: 'QR-REF-001',
        amount: 500,
        bonusAmount: 0,
        status: TopupStatus.pendingPayment,
        channel: TopupChannel.qr,
        provider: 'deepay_kbank',
        transferAt: null,
        createdAt: '2026-08-12T10:00:00+07:00',
        slipUrl: '',
        slipThumbUrl: '',
        qrCode:
            'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAgAAAAIAQAAAADsdIMmAAAAIGNIUk0AAHomAACAhAAA+gAAAIDoAAB1MAAA6mAAADqYAAAXcJy6UTwAAAACYktHRAAB3YoTpAAAAAd0SU1FB+oIDAwjImN+qdwAAAAldEVYdGRhdGU6Y3JlYXRlADIwMjYtMDgtMTJUMTI6MzU6MzQrMDA6MDCPkhVfAAAAJXRFWHRkYXRlOm1vZGlmeQAyMDI2LTA4LTEyVDEyOjM1OjM0KzAwOjAw/s+t4wAAACh0RVh0ZGF0ZTp0aW1lc3RhbXAAMjAyNi0wOC0xMlQxMjozNTozNCswMDowMKnajDwAAAAPSURBVAjXY+BngMAPEAgAEeAD/ReYei0AAAAASUVORK5CYII=',
        redirectUrl: '',
        message: '',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          topupRepositoryProvider.overrideWithValue(repository),
          receiptImageExporterProvider.overrideWithValue(imageExporter),
          receiptShareServiceProvider.overrideWithValue(shareService),
          topupQrImagePreloaderProvider.overrideWithValue((_, __) async {}),
          topupOverviewProvider.overrideWith(
            (_) async => _emptyTopupOverview(),
          ),
        ],
        child: MaterialApp(
          locale: fallbackCustomerLocale,
          supportedLocales: supportedCustomerLocales,
          localizationsDelegates: [
            CustomerLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: AppTheme.light(),
          home: const TopupScreen(
            detailTopupId: 'qr_detail_1',
            backPath: '/my-wallet',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('THAI QR PAYMENT'), findsOneWidget);
    expect(find.text('บันทึก QR Code'), findsOneWidget);
    expect(find.text('สำหรับเติมเงิน Siamblend เท่านั้น'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('topup-qr-red-watermark')),
      findsOneWidget,
    );
    expect(find.text('แจ้งปัญหา'), findsOneWidget);
    expect(find.text('รายการเติมเงินของคุณ'), findsNothing);
    expect(find.text('500 บาท'), findsOneWidget);
    expect(tester.widget<Text>(find.text('500 บาท')).textAlign, TextAlign.end);
    expect(find.text('QR-REF-001'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('QR-REF-001')).textAlign,
      TextAlign.end,
    );
    final detailBackground = tester.widget<ColoredBox>(
      find.byKey(const ValueKey('topup-detail-headerless-page')),
    );
    expect(detailBackground.color, AppTheme.light().colorScheme.primary);
    expect(find.text('ยกเลิก'), findsOneWidget);
    expect(find.text('แนบสลิป'), findsOneWidget);
    final paymentCard = find.byKey(const ValueKey('topup-qr-payment-card'));
    expect(paymentCard, findsOneWidget);
    expect(
      find.descendant(
        of: paymentCard,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName ==
                  'assets/images/topup/siamblend_qr_footer.png',
        ),
      ),
      findsOneWidget,
    );

    final saveButton = find.widgetWithText(OutlinedButton, 'บันทึก QR Code');
    final summary = find.byKey(const ValueKey('topup-qr-detail-summary'));
    expect(
      tester.getTopLeft(saveButton).dy,
      lessThan(tester.getTopLeft(summary).dy),
    );
    expect(
      tester
          .getTopLeft(find.byKey(const ValueKey('topup-qr-compact-actions')))
          .dy,
      greaterThan(tester.getTopLeft(find.text('QR-REF-001')).dy),
    );
    await Scrollable.ensureVisible(tester.element(saveButton), alignment: 0.5);
    await tester.pumpAndSettle();
    final saveAction = tester.widget<OutlinedButton>(saveButton).onPressed;
    expect(saveAction, isNotNull);
    saveAction!();
    await tester.pump();
    await tester.pump(Duration.zero);
    await tester.pump(const Duration(milliseconds: 1));

    expect(imageExporter.captureCalls, 1);
    expect(imageExporter.boundaryAttached, isTrue);
    expect(shareService.shareCalls, 1);
    expect(shareService.fileName, 'siamblend-topup-qr_detail_1.png');
    expect(shareService.imageBytes, orderedEquals([1, 2, 3]));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('topup-feedback-dialog')), findsOneWidget);
    expect(find.text('เตรียมไฟล์ QR Code สำหรับบันทึกแล้ว'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('topup-feedback-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('topup-feedback-dialog')), findsNothing);
  });

  testWidgets('expired QR cancels once and explains the timeout', (
    tester,
  ) async {
    final repository = _DetailTopupRepository(
      const TopupRequestItem(
        id: 'qr_expiring_1',
        reference: 'QR-EXP-001',
        amount: 100,
        bonusAmount: 0,
        status: TopupStatus.pendingPayment,
        channel: TopupChannel.qr,
        provider: 'deepay_kbank',
        transferAt: null,
        createdAt: '2026-08-12T10:00:00+07:00',
        slipUrl: '',
        slipThumbUrl: '',
        qrCode: _runtimeTopupLogo,
        redirectUrl: '',
        message: '',
        paymentExpiresInSeconds: 0,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [topupRepositoryProvider.overrideWithValue(repository)],
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
          home: const TopupScreen(
            detailTopupId: 'qr_expiring_1',
            backPath: '/my-wallet',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.cancelCalls, 1);
    expect(repository.cancelledReasons, ['payment_qr_expired']);
    final feedbackDialog = find.byKey(const ValueKey('topup-feedback-dialog'));
    expect(feedbackDialog, findsOneWidget);
    expect(
      find.descendant(
        of: feedbackDialog,
        matching: find.text(
          'รายการเติมเงินถูกยกเลิก เนื่องจาก QR Code หมดเวลา',
        ),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('topup-feedback-close')));
    await tester.pumpAndSettle();
    expect(repository.cancelCalls, 1);
  });

  testWidgets('expired QR with a submitted slip waits for admin review', (
    tester,
  ) async {
    final repository = _DetailTopupRepository(
      const TopupRequestItem(
        id: 'qr_review_1',
        reference: 'QR-REVIEW-001',
        amount: 100,
        bonusAmount: 0,
        status: TopupStatus.pendingReview,
        channel: TopupChannel.qr,
        provider: 'deepay_kbank',
        transferAt: null,
        createdAt: '2026-08-12T10:00:00+07:00',
        slipUrl: 'https://partner.example.test/slip.webp',
        slipThumbUrl: 'https://partner.example.test/slip-thumb.webp',
        qrCode: '',
        redirectUrl: '',
        message: '',
        paymentExpiresInSeconds: 0,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [topupRepositoryProvider.overrideWithValue(repository)],
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
          home: const TopupScreen(
            detailTopupId: 'qr_review_1',
            backPath: '/my-wallet',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.cancelCalls, 0);
    expect(find.text('แอดมินกำลังตรวจสอบหลักฐานการโอนเงิน'), findsOneWidget);
  });

  testWidgets('approved QR payment returns to the wallet', (tester) async {
    final repository = _DetailTopupRepository(
      const TopupRequestItem(
        id: 'topup_paid_1',
        reference: 'TOP-PAID-001',
        amount: 500,
        bonusAmount: 0,
        status: TopupStatus.approved,
        channel: TopupChannel.qr,
        provider: 'deepay_kbank',
        transferAt: null,
        createdAt: '2026-08-12T10:00:00+07:00',
        slipUrl: '',
        slipThumbUrl: '',
        qrCode: '',
        redirectUrl: '',
        message: '',
        paymentExpiresInSeconds: 0,
      ),
    );
    final router = GoRouter(
      initialLocation: '/topup/topup_paid_1?back=/my-wallet',
      routes: [
        GoRoute(
          path: '/topup/:topupId',
          builder: (context, state) => TopupScreen(
            detailTopupId: state.pathParameters['topupId'],
            backPath: safeTopupDetailBackPath(
              state.uri.queryParameters['back'],
            ),
          ),
        ),
        GoRoute(
          path: '/my-wallet',
          builder: (_, __) => const Scaffold(body: Text('wallet route')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [topupRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp.router(
          locale: fallbackCustomerLocale,
          supportedLocales: supportedCustomerLocales,
          localizationsDelegates: const [
            CustomerLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('wallet route'), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, '/my-wallet');
    expect(find.byKey(const ValueKey('topup-completed-detail')), findsNothing);
  });

  testWidgets(
    'pending detail refreshes after app resume and keeps polling until callback succeeds',
    (tester) async {
      final repository = _SequencedDetailTopupRepository([
        const TopupRequestItem(
          id: 'topup_callback_1',
          reference: 'TOP-CALLBACK-001',
          amount: 500,
          bonusAmount: 0,
          status: TopupStatus.pendingPayment,
          channel: TopupChannel.qr,
          provider: 'deepay_kbank',
          transferAt: null,
          createdAt: '2026-08-13T10:00:00+07:00',
          slipUrl: '',
          slipThumbUrl: '',
          qrCode: '',
          redirectUrl: '',
          message: '',
        ),
        const TopupRequestItem(
          id: 'topup_callback_1',
          reference: 'TOP-CALLBACK-001',
          amount: 500,
          bonusAmount: 0,
          status: TopupStatus.pendingPayment,
          channel: TopupChannel.qr,
          provider: 'deepay_kbank',
          transferAt: null,
          createdAt: '2026-08-13T10:00:00+07:00',
          slipUrl: '',
          slipThumbUrl: '',
          qrCode: '',
          redirectUrl: '',
          message: '',
        ),
        const TopupRequestItem(
          id: 'topup_callback_1',
          reference: 'TOP-CALLBACK-001',
          amount: 500,
          bonusAmount: 0,
          status: TopupStatus.approved,
          channel: TopupChannel.qr,
          provider: 'deepay_kbank',
          transferAt: null,
          createdAt: '2026-08-13T10:00:00+07:00',
          slipUrl: '',
          slipThumbUrl: '',
          qrCode: '',
          redirectUrl: '',
          message: '',
        ),
      ]);
      final router = GoRouter(
        initialLocation: '/topup/topup_callback_1?back=/my-wallet',
        routes: [
          GoRoute(
            path: '/topup/:topupId',
            builder: (context, state) => TopupScreen(
              detailTopupId: state.pathParameters['topupId'],
              backPath: safeTopupDetailBackPath(
                state.uri.queryParameters['back'],
              ),
            ),
          ),
          GoRoute(
            path: '/my-wallet',
            builder: (_, __) => const Scaffold(body: Text('wallet route')),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            topupRepositoryProvider.overrideWithValue(repository),
            topupPendingRefreshIntervalProvider.overrideWithValue(
              const Duration(seconds: 1),
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

      expect(repository.detailCalls, 1);
      expect(
        find.byKey(const ValueKey('topup-completed-detail')),
        findsNothing,
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(repository.detailCalls, 2);
      expect(
        find.byKey(const ValueKey('topup-completed-detail')),
        findsNothing,
      );

      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(repository.detailCalls, 3);
      expect(find.text('wallet route'), findsOneWidget);
      expect(router.routeInformationProvider.value.uri.path, '/my-wallet');
      expect(
        find.byKey(const ValueKey('topup-completed-detail')),
        findsNothing,
      );

      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(repository.detailCalls, 3);
    },
  );
}

class _RecordingTopupQrImageExporter implements ReceiptImageExporter {
  int captureCalls = 0;
  bool boundaryAttached = false;

  @override
  Future<Uint8List> capturePng(GlobalKey boundaryKey) async {
    captureCalls += 1;
    await Future<void>.delayed(Duration.zero);
    boundaryAttached = boundaryKey.currentContext != null;
    return Uint8List.fromList([1, 2, 3]);
  }
}

class _RecordingTopupQrShareService implements ReceiptShareService {
  int shareCalls = 0;
  Uint8List? imageBytes;
  String? fileName;

  @override
  Future<void> shareReceipt({
    required String text,
    required String subject,
    Uint8List? imageBytes,
    String? fileName,
    Uint8List? pdfBytes,
    String? pdfFileName,
    Rect? sharePositionOrigin,
  }) async {
    shareCalls += 1;
    this.imageBytes = imageBytes;
    this.fileName = fileName;
  }
}

Future<void> _cancelWaitingTopup(WidgetTester tester) async {
  final cancelWaiting = find.widgetWithText(
    OutlinedButton,
    'ยกเลิกรายการเติมเงินนี้',
  );
  await Scrollable.ensureVisible(
    tester.element(cancelWaiting),
    alignment: 0.45,
  );
  await tester.pumpAndSettle();
  await tester.tap(cancelWaiting);
  await tester.pumpAndSettle();
}

Future<void> _pumpTopupRoute(
  WidgetTester tester,
  String initialLocation, {
  TopupOverview? overview,
  TopupRepository? repository,
}) async {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/topup',
        builder: (context, state) => TopupScreen(
          backPath: safeTopupBackPath(state.uri.queryParameters['back']),
        ),
      ),
      GoRoute(
        path: '/checkout',
        builder: (context, state) =>
            const Scaffold(body: Text('checkout route')),
      ),
      GoRoute(
        path: '/my-wallet',
        builder: (context, state) => const Scaffold(body: Text('wallet route')),
      ),
      GoRoute(
        path: '/topup/history',
        builder: (context, state) =>
            const Scaffold(body: Text('topup history route')),
      ),
      GoRoute(
        path: '/topup/:topupId',
        builder: (context, state) => Scaffold(
          body: Text(
            'topup detail route ${state.pathParameters['topupId']} '
            'back=${state.uri.queryParameters['back']}',
          ),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        topupOverviewProvider.overrideWith(
          (_) async => overview ?? _emptyTopupOverview(),
        ),
        if (repository != null)
          topupRepositoryProvider.overrideWithValue(repository),
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
}

Future<void> _pumpTopupScreen(
  WidgetTester tester,
  TopupOverview overview, {
  TopupRepository? repository,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        topupOverviewProvider.overrideWith((_) async => overview),
        if (repository != null)
          topupRepositoryProvider.overrideWithValue(repository),
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
        home: const TopupScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

TopupOverview _emptyTopupOverview() {
  return TopupOverview(
    walletName: 'Runtime Blue Wallet',
    bank: const TopupBankAccount(
      bankName: '',
      accountName: '',
      accountNumber: '',
    ),
    paymentMethods: const [
      TopupPaymentMethod(
        key: 'qr',
        label: 'QR Code',
        enabled: true,
        description: '',
        iconUrl: _runtimeTopupLogo,
      ),
      TopupPaymentMethod(
        key: 'credit_card',
        label: 'Credit QR Code',
        enabled: true,
        description: '',
      ),
      TopupPaymentMethod(
        key: 'bank_transfer',
        label: 'โอนธนาคาร',
        enabled: true,
        description: '',
      ),
    ],
    enabledPaymentMethods: const {'qr', 'credit_card', 'bank_transfer'},
    waiting: null,
    histories: const [],
    currentPage: 1,
    lastPage: 1,
  );
}

TopupOverview _waitingTopupOverview(TopupRequestItem waiting) {
  return TopupOverview(
    walletName: 'Runtime Blue Wallet',
    bank: const TopupBankAccount(
      bankName: '',
      accountName: '',
      accountNumber: '',
    ),
    paymentMethods: const [
      TopupPaymentMethod(
        key: 'qr',
        label: 'QR Code',
        enabled: true,
        description: '',
      ),
      TopupPaymentMethod(
        key: 'credit_card',
        label: 'Credit QR Code',
        enabled: true,
        description: '',
      ),
      TopupPaymentMethod(
        key: 'bank_transfer',
        label: 'โอนธนาคาร',
        enabled: true,
        description: '',
      ),
    ],
    enabledPaymentMethods: const {'qr', 'credit_card', 'bank_transfer'},
    waiting: waiting,
    histories: const [],
    currentPage: 1,
    lastPage: 1,
  );
}

class _FailingCreateTopupRepository extends TopupRepository {
  _FailingCreateTopupRepository(this.error) : super(_testApiClient());

  final Object error;
  int createCalls = 0;
  TopupChannel? createdChannel;

  @override
  Future<TopupRequestItem> create({
    required TopupChannel channel,
    required double amount,
    DateTime? transferAt,
    TopupSlipUpload? slip,
  }) async {
    createCalls++;
    createdChannel = channel;
    throw error;
  }

  @override
  Future<TopupRequestItem> createCredit({required double amount}) async {
    createCalls++;
    createdChannel = TopupChannel.creditCard;
    throw error;
  }
}

class _CreateTopupRepository extends TopupRepository {
  _CreateTopupRepository(this.item, {this.createGate})
    : super(_testApiClient());

  final TopupRequestItem item;
  final Completer<void>? createGate;
  int createCalls = 0;
  TopupChannel? createdChannel;

  @override
  Future<TopupRequestItem> create({
    required TopupChannel channel,
    required double amount,
    DateTime? transferAt,
    TopupSlipUpload? slip,
  }) async {
    createCalls++;
    createdChannel = channel;
    await createGate?.future;
    return item;
  }

  @override
  Future<TopupRequestItem> createCredit({required double amount}) async {
    createCalls++;
    createdChannel = TopupChannel.creditCard;
    await createGate?.future;
    return item;
  }
}

class _DetailTopupRepository extends TopupRepository {
  _DetailTopupRepository(this.item) : super(_testApiClient());

  final TopupRequestItem item;
  int detailCalls = 0;
  int cancelCalls = 0;
  final detailIds = <String>[];
  final cancelledReasons = <String?>[];

  @override
  Future<TopupRequestItem> detail(String id) async {
    detailCalls++;
    detailIds.add(id);
    return item;
  }

  @override
  Future<TopupRequestItem> cancel(String id, {String? reason}) async {
    cancelCalls++;
    cancelledReasons.add(reason);
    return item;
  }
}

class _SequencedDetailTopupRepository extends TopupRepository {
  _SequencedDetailTopupRepository(this.items) : super(_testApiClient());

  final List<TopupRequestItem> items;
  int detailCalls = 0;

  @override
  Future<TopupRequestItem> detail(String id) async {
    final index = detailCalls < items.length ? detailCalls : items.length - 1;
    detailCalls++;
    return items[index];
  }
}

class _CancelTopupRepository extends TopupRepository {
  _CancelTopupRepository({this.error, this.cancelGate})
    : super(_testApiClient());

  final Object? error;
  final Completer<void>? cancelGate;

  int cancelCalls = 0;
  final cancelledIds = <String>[];

  @override
  Future<TopupRequestItem> cancel(String id, {String? reason}) async {
    cancelCalls++;
    cancelledIds.add(id);
    await cancelGate?.future;
    final error = this.error;
    if (error != null) throw error;
    return TopupRequestItem(
      id: id,
      amount: 800,
      bonusAmount: 0,
      status: TopupStatus.cancelled,
      channel: TopupChannel.bankTransfer,
      provider: 'manual',
      transferAt: null,
      createdAt: '2026-06-26T10:00:00+07:00',
      slipUrl: '',
      slipThumbUrl: '',
      qrCode: '',
      redirectUrl: '',
      message: '',
    );
  }
}

DioException _apiException(String message, {String path = '/customer/topups'}) {
  final requestOptions = RequestOptions(path: path);
  return DioException(
    requestOptions: requestOptions,
    response: Response<Map<String, dynamic>>(
      requestOptions: requestOptions,
      statusCode: 422,
      data: {'message': message},
    ),
    type: DioExceptionType.badResponse,
  );
}

ApiClient _testApiClient() {
  return ApiClient(
    const AppConfig(
      apiBaseUrl: 'https://partner.example.test/api/v1',
      defaultLocale: 'th-TH',
    ),
    AuthTokenStore(),
    localeTag: 'th-TH',
  );
}
