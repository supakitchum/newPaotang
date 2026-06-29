import 'package:customer_flutter/core/i18n/app_locale.dart';
import 'package:customer_flutter/core/i18n/customer_localizations.dart';
import 'package:customer_flutter/core/theme/app_theme.dart';
import 'package:customer_flutter/core/utils/formatters.dart';
import 'package:customer_flutter/features/topup/data/topup_models.dart';
import 'package:customer_flutter/features/topup/data/topup_repository.dart';
import 'package:customer_flutter/features/topup/presentation/topup_history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('topup history uses transfer time and renders bonus amount', (
    tester,
  ) async {
    const transferAt = '2026-06-26T13:04:00+07:00';
    const createdAt = '2026-06-20T08:00:00+07:00';

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          topupHistoryProvider(1).overrideWith(
            (_) async => TopupOverview(
              bank: const TopupBankAccount(
                bankName: '',
                accountName: '',
                accountNumber: '',
              ),
              paymentMethods: const [],
              enabledPaymentMethods: const {},
              waiting: null,
              currentPage: 1,
              lastPage: 1,
              histories: [
                TopupRequestItem(
                  id: 'top_1',
                  amount: 500,
                  bonusAmount: 25,
                  status: TopupStatus.approved,
                  channel: TopupChannel.qr,
                  provider: 'deepay_kbank',
                  transferAt: transferAt,
                  createdAt: createdAt,
                  slipUrl: '',
                  slipThumbUrl: '',
                  qrCode: '',
                  redirectUrl: '',
                  message: '',
                ),
              ],
            ),
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
          home: const TopupHistoryScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('เติมเงินเข้า G-Wallet'), findsOneWidget);
    expect(find.text('500.00 บาท'), findsOneWidget);
    expect(find.text('อนุมัติแล้ว'), findsOneWidget);
    expect(find.text('โบนัส 25.00 บาท'), findsOneWidget);
    expect(
      find.textContaining(formatLocalizedDateTime(transferAt, 'th-TH')),
      findsOneWidget,
    );
    expect(
      find.textContaining(formatLocalizedDateTime(createdAt, 'th-TH')),
      findsNothing,
    );
  });
}
