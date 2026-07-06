import 'package:customer_flutter/core/tenant/mobile_bootstrap_controller.dart';
import 'package:customer_flutter/features/profile/presentation/account_deletion_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('account deletion screen shows configured request link',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        MobileBootstrap.fromJson(const {
          'site': {'display_name': 'Partner Shop'},
          'legal': {
            'account_deletion_url':
                'https://partner.example.com/account/delete',
          },
        }),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('คำขอลบบัญชี'), findsOneWidget);
    expect(find.text('ส่งคำขอลบบัญชี'), findsOneWidget);
    expect(find.textContaining('ยังไม่ได้ตั้งค่าลิงก์'), findsNothing);
  });

  testWidgets('account deletion screen explains fallback when link is missing',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        MobileBootstrap.fromJson(const {
          'site': {'display_name': 'Partner Shop'},
        }),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('คำขอลบบัญชี'), findsOneWidget);
    expect(find.textContaining('ยังไม่ได้ตั้งค่าลิงก์'), findsOneWidget);
  });

  testWidgets('account deletion screen shows support email fallback',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        MobileBootstrap.fromJson(const {
          'site': {'display_name': 'Partner Shop'},
          'support': {'email': 'support@example.test'},
        }),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('ยังไม่ได้ตั้งค่าลิงก์'), findsOneWidget);
    expect(find.text('ติดต่อร้านค้า support@example.test'), findsOneWidget);
  });

  testWidgets('account deletion screen shows runtime support URL fallback',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        MobileBootstrap.fromJson(const {
          'site': {'display_name': 'Partner Shop'},
          'supportConfig': {
            'channels': [
              {
                'type': 'supportUrl',
                'value': 'https://partner.example.com/support',
              },
            ],
          },
        }),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('ยังไม่ได้ตั้งค่าลิงก์'), findsOneWidget);
    expect(find.text('ติดต่อร้านค้าผ่านเว็บไซต์'), findsOneWidget);
  });
}

Widget _buildTestApp(MobileBootstrap bootstrap) {
  return ProviderScope(
    overrides: [
      mobileBootstrapProvider.overrideWith((ref) async => bootstrap),
    ],
    child: const MaterialApp(home: AccountDeletionScreen()),
  );
}
