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
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

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

  testWidgets('topup screen honors allowed Nuxt back query targets', (
    tester,
  ) async {
    await _pumpTopupRoute(tester, '/topup?back=/checkout');

    await tester.tap(find.byTooltip('ย้อนกลับ'));
    await tester.pumpAndSettle();

    expect(find.text('checkout route'), findsOneWidget);
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
    expect(find.text('750.00 บาท'), findsOneWidget);
    expect(find.text('โบนัส 35.00 บาท'), findsOneWidget);
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
    expect(find.text('Credit QR Code'), findsOneWidget);
    expect(find.text('โอนธนาคาร'), findsOneWidget);
    expect(find.text('ปิดบริการชั่วคราว'), findsNWidgets(2));
    expect(find.text('ธนาคารทดสอบ'), findsNothing);

    final bankTile = find.ancestor(
      of: find.text('โอนธนาคาร'),
      matching: find.byType(InkWell),
    );
    await tester.ensureVisible(bankTile);
    await tester.pumpAndSettle();
    await tester.tap(bankTile);
    await tester.pumpAndSettle();

    expect(find.text('ธนาคารทดสอบ'), findsOneWidget);
    expect(find.text('ยืนยันการชำระเงิน'), findsOneWidget);
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
    expect(find.widgetWithText(OutlinedButton, '100.00'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '1,000.00'), findsOneWidget);
    expect(find.byType(ActionChip), findsNothing);
    expect(
      find.text('สร้าง QR Code แล้วแนบสลิปหลังชำระเงินเพื่อให้ร้านค้าตรวจสอบ'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(OutlinedButton, '1,000.00'));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      '1000',
    );

    await tester.tap(find.byIcon(Icons.close).last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Credit QR Code'));
    await tester.pumpAndSettle();

    expect(find.text('จำนวนเงินที่ต้องการเติม'), findsOneWidget);
    expect(
      find.text('ช่องทางนี้จะแสดงเป็น QR Code และแนบสลิปหลังชำระเงินได้'),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'สร้าง QR Code'), findsOneWidget);
    expect(find.text('สร้าง Credit QR Code'), findsNothing);
  });

  testWidgets('bank transfer requires a slip before creating request', (
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

    await tester.ensureVisible(find.text('โอนธนาคาร'));
    await tester.tap(find.text('โอนธนาคาร'));
    await tester.pumpAndSettle();

    expect(find.text('วันเวลาที่โอน'), findsOneWidget);
    expect(
      find.widgetWithText(OutlinedButton, 'เลือกวันเวลาที่โอน'),
      findsOneWidget,
    );
    expect(find.text('สลิปโอนเงิน'), findsOneWidget);
    expect(find.text('แนบสลิป'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('วันเวลาที่โอน')).dy,
      lessThan(tester.getTopLeft(find.text('แนบสลิป')).dy),
    );

    final transferTimeButton = find.widgetWithText(
      OutlinedButton,
      'เลือกวันเวลาที่โอน',
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

    final submit = find.widgetWithText(FilledButton, 'ยืนยันการชำระเงิน');
    final submitButton = tester.widget<FilledButton>(submit);
    submitButton.onPressed!();
    await tester.pump();

    expect(
      find.text('กรุณาแนบรูปสลิปก่อนส่งให้แอดมินตรวจสอบ'),
      findsOneWidget,
    );
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
    expect(find.text('500.00 บาท'), findsOneWidget);
    expect(find.text('โบนัส 25.00 บาท'), findsOneWidget);
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
    expect(find.text('1,200.00 บาท'), findsOneWidget);
    expect(find.text('โบนัส 80.00 บาท'), findsOneWidget);
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

  testWidgets('unfinished topup blocks creating a new request', (
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

    expect(find.text('มีรายการเติมเงินค้างอยู่'), findsOneWidget);
    expect(
      find.text('กรุณาชำระหรือยกเลิกรายการเดิมก่อนสร้างรายการใหม่'),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'สร้าง QR Code'), findsNothing);

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
    await tester.tap(find.widgetWithText(FilledButton, 'สร้าง QR Code'));
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
    await tester.tap(find.widgetWithText(FilledButton, 'สร้าง QR Code'));
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
    final repository = _CancelTopupRepository();

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
    expect(find.text('ยกเลิกรายการเติมเงินนี้?'), findsOneWidget);
    expect(
      find.text(
        'รายการ #top_waiting_bank จะถูกยกเลิก และคุณสามารถสร้างรายการเติมเงินใหม่ได้ทันที',
      ),
      findsOneWidget,
    );
    expect(find.text('ยอดเติมเงิน'), findsWidgets);
    expect(find.text('800.00 บาท'), findsWidgets);
    expect(find.widgetWithText(OutlinedButton, 'ไม่ยกเลิก'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'ยืนยันยกเลิก'), findsOneWidget);

    await tester.tap(find.text('ไม่ยกเลิก'));
    await tester.pumpAndSettle();
    expect(repository.cancelCalls, 0);

    await tapCancelWaiting();
    await tester.tap(find.text('ยืนยันยกเลิก'));
    await tester.pumpAndSettle();

    expect(repository.cancelCalls, 1);
    expect(repository.cancelledIds, ['top_waiting_bank']);
    expect(find.text('ยกเลิกรายการเติมเงินแล้ว'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
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
  String initialLocation,
) async {
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
        builder: (context, state) => const Scaffold(
          body: Text('checkout route'),
        ),
      ),
      GoRoute(
        path: '/my-wallet',
        builder: (context, state) => const Scaffold(
          body: Text('wallet route'),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        topupOverviewProvider.overrideWith((_) async => _emptyTopupOverview()),
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
    waiting: null,
    histories: const [],
    currentPage: 1,
    lastPage: 1,
  );
}

TopupOverview _waitingTopupOverview(TopupRequestItem waiting) {
  return TopupOverview(
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

class _CancelTopupRepository extends TopupRepository {
  _CancelTopupRepository({this.error}) : super(_testApiClient());

  final Object? error;

  int cancelCalls = 0;
  final cancelledIds = <String>[];

  @override
  Future<TopupRequestItem> cancel(String id) async {
    cancelCalls++;
    cancelledIds.add(id);
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
