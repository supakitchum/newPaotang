import 'package:customer_flutter/core/theme/app_theme.dart';
import 'package:customer_flutter/shared/widgets/customer_section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('CustomerSectionHeader keeps action usable on narrow screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: CustomerSectionHeader(
              title: 'หัวข้อภาษาไทยที่ยาวมากสำหรับทดสอบการตัดบรรทัด',
              actionLabel: 'ดูทั้งหมด',
              onAction: () => tapped = true,
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('หัวข้อภาษาไทย'), findsOneWidget);
    expect(find.text('ดูทั้งหมด'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('ดูทั้งหมด'));

    expect(tapped, isTrue);
  });

  testWidgets('CustomerSectionHeader supports subtitle and icon actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var refreshed = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: CustomerSectionHeader(
              title: 'เลขสลากดิจิทัล',
              subtitle: 'สลากกินแบ่งรัฐบาล',
              action: TextButton.icon(
                onPressed: () => refreshed = true,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('แสดงเลขใหม่'),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('เลขสลากดิจิทัล'), findsOneWidget);
    expect(find.text('สลากกินแบ่งรัฐบาล'), findsOneWidget);
    expect(find.text('แสดงเลขใหม่'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('แสดงเลขใหม่'));

    expect(refreshed, isTrue);
  });
}
