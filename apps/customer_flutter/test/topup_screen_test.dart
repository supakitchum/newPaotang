import 'package:customer_flutter/core/i18n/app_locale.dart';
import 'package:customer_flutter/core/i18n/customer_localizations.dart';
import 'package:customer_flutter/core/theme/app_theme.dart';
import 'package:customer_flutter/features/topup/data/topup_models.dart';
import 'package:customer_flutter/features/topup/data/topup_repository.dart';
import 'package:customer_flutter/features/topup/presentation/topup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
    expect(find.text('ธนาคารทดสอบ'), findsOneWidget);
    expect(find.text('สร้างรายการโอนธนาคาร'), findsOneWidget);
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
          bonusAmount: 0,
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
    expect(find.text('แนบสลิปชำระเงิน'), findsOneWidget);
    expect(find.text('ยกเลิกรายการเติมเงินนี้'), findsOneWidget);
  });
}

Future<void> _pumpTopupScreen(
  WidgetTester tester,
  TopupOverview overview,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        topupOverviewProvider.overrideWith((_) async => overview),
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
