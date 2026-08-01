import 'package:customer_flutter/features/profile/data/account_deletion_repository.dart';
import 'package:customer_flutter/features/profile/presentation/account_deletion_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('account deletion explains consequences before continuing', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const AccountDeletionStatus(
          request: null,
          eligible: true,
          blockers: [],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('โปรดอ่านก่อนลบบัญชี'), findsOneWidget);
    expect(find.textContaining('90 วัน'), findsOneWidget);
    expect(find.text('บัญชีพร้อมส่งคำขอลบ'), findsOneWidget);
    expect(find.text('ดำเนินการต่อ'), findsOneWidget);
  });

  testWidgets('account deletion lists outstanding blockers', (tester) async {
    await tester.pumpWidget(
      _app(
        const AccountDeletionStatus(
          request: null,
          eligible: false,
          blockers: [
            AccountDeletionBlocker(
              code: 'wallet_balance',
              routeKey: 'wallet',
              details: {'balance_amount': 100},
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Wallet balance remains'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'ดำเนินการต่อ'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('pending request shows countdown and cancellation action', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        AccountDeletionStatus(
          eligible: true,
          blockers: const [],
          request: AccountDeletionRequest(
            id: 'cad_test',
            status: 'pending',
            reasonCode: 'privacy',
            scheduledFor: DateTime.now().add(const Duration(days: 7)),
            remainingSeconds: 604800,
            blockers: const [],
            readOnly: true,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('กำลังรอลบบัญชี'), findsOneWidget);
    expect(find.textContaining('7d'), findsOneWidget);
    expect(find.text('ยกเลิกการลบบัญชี'), findsOneWidget);
  });
}

Widget _app(AccountDeletionStatus status) {
  return ProviderScope(
    overrides: [
      accountDeletionStatusProvider.overrideWith((ref) async => status),
    ],
    child: const MaterialApp(
      locale: Locale('th'),
      home: AccountDeletionScreen(),
    ),
  );
}
