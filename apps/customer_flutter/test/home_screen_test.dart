import 'package:customer_flutter/core/auth/auth_token_store.dart';
import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/i18n/app_locale.dart';
import 'package:customer_flutter/core/i18n/customer_localizations.dart';
import 'package:customer_flutter/core/theme/app_theme.dart';
import 'package:customer_flutter/features/activities/data/activity_models.dart';
import 'package:customer_flutter/features/activities/data/activity_repository.dart';
import 'package:customer_flutter/features/home/presentation/home_screen.dart';
import 'package:customer_flutter/features/news/data/news_models.dart';
import 'package:customer_flutter/features/news/data/news_repository.dart';
import 'package:customer_flutter/features/results/data/result_models.dart';
import 'package:customer_flutter/features/results/data/result_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('home screen renders live result summary on the first page', (
    tester,
  ) async {
    await _pumpHome(tester);

    await tester.pumpAndSettle();

    expect(find.text('ซื้อสลากดิจิทัล'), findsWidgets);
    expect(find.text('สแกนซื้อสลากฯ'), findsOneWidget);
    expect(find.text('เริ่มซื้อสลากดิจิทัล'), findsOneWidget);
    expect(find.text('เข้าสู่ระบบ'), findsOneWidget);
    expect(find.text('สมัครใช้งาน'), findsOneWidget);
    expect(find.text('ยอดเงินในกระเป๋า'), findsNothing);

    await tester.drag(find.byType(ListView), const Offset(0, -360));
    await tester.pumpAndSettle();

    expect(find.text('ผลรางวัลสลากฯ'), findsOneWidget);
    expect(
      find.text('ผลรางวัลนี้เป็นผลแสดงสดอย่างไม่เป็นทางการ'),
      findsOneWidget,
    );
    expect(find.text('287184'), findsOneWidget);
    expect(find.text('48'), findsOneWidget);
    expect(find.text('434'), findsOneWidget);
    expect(find.text('758'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();

    expect(find.text('ข่าวสาร'), findsWidgets);
    expect(find.text('ดูทั้งหมด'), findsWidgets);
    expect(find.text('ประกาศปิดปรับปรุง'), findsOneWidget);
    expect(find.text('ปรับปรุงระบบชำระเงินเวลา 23:00 น.'), findsOneWidget);
  });

  testWidgets('home screen keeps the hero usable on narrow mobile viewports', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpHome(tester);
    await tester.pumpAndSettle();

    expect(find.text('ซื้อสลากดิจิทัล'), findsWidgets);
    expect(find.text('ค้นหาเลขเด็ด'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home activities rail stays aligned on wide viewports', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpHome(tester, activities: _activityFixtures);
    await tester.pumpAndSettle();

    final activityList = find.byWidgetPredicate(
      (widget) =>
          widget is ListView && widget.scrollDirection == Axis.horizontal,
    );

    expect(activityList, findsOneWidget);
    expect(find.text('กิจกรรมที่ 1'), findsOneWidget);
    expect(find.text('กิจกรรมที่ 2'), findsOneWidget);
    expect(find.text('คืนเงิน 5%'), findsOneWidget);

    final listRect = tester.getRect(activityList);
    expect(listRect.width, lessThanOrEqualTo(900));
    expect(listRect.left, greaterThan(100));
    expect(listRect.right, lessThan(1100));
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpHome(
  WidgetTester tester, {
  List<ActivityItem> activities = const <ActivityItem>[],
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(
            apiBaseUrl: 'https://partner.example.com/api/v1',
            defaultLocale: 'th-TH',
          ),
        ),
        authTokenStoreProvider.overrideWithValue(AuthTokenStore()),
        activityListProvider.overrideWith((_) async => activities),
        newsListProvider.overrideWith(
          (_) async => const [
            NewsItem(
              id: 'news_1',
              title: 'ประกาศปิดปรับปรุง',
              summary: 'ปรับปรุงระบบชำระเงินเวลา 23:00 น.',
              body: '',
              slug: 'maintenance',
              url: '',
              coverUrl: '',
              publishedAt: '2026-06-08T13:14:00+07:00',
            ),
          ],
        ),
        currentResultProvider.overrideWith((_) async {
          return RewardResultBundle(
            currentGame: null,
            selectedResult: RewardResultGame.fromPublicSummary({
              'game_id': 'game_1',
              'game_name': 'งวดวันที่ 1 ก.ค. 2569',
              'status': 'live_unconfirmed',
              'official_status': 'draft',
              'prizes': [
                {
                  'prize_type': 'first_prize',
                  'prize_number': '287184',
                  'amount': {'amount': 600000000, 'currency': 'THB'},
                },
                {
                  'prize_type': 'back2',
                  'prize_number': '48',
                  'amount': {'amount': 200000, 'currency': 'THB'},
                },
                {
                  'prize_type': 'front3',
                  'prize_number': '434',
                  'amount': {'amount': 400000, 'currency': 'THB'},
                },
                {
                  'prize_type': 'front3',
                  'prize_number': '758',
                  'amount': {'amount': 400000, 'currency': 'THB'},
                },
              ],
            }),
            history: const [],
          );
        }),
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
        home: const HomeScreen(),
      ),
    ),
  );
}

const _activityFixtures = [
  ActivityItem(
    id: 'activity_1',
    name: 'กิจกรรมที่ 1',
    slug: 'activity-1',
    type: 'lucky_board',
    imageUrl: '',
    conditionText: 'ทุก 10 ใบ ได้ 1 สิทธิ์',
    remainingNumbers: 97,
    hasRight: true,
    estimatedCashbackAmount: 0,
  ),
  ActivityItem(
    id: 'activity_2',
    name: 'กิจกรรมที่ 2',
    slug: 'activity-2',
    type: 'lucky_board',
    imageUrl: '',
    conditionText: 'ทุก 20 ใบ ได้ 1 สิทธิ์',
    remainingNumbers: 100,
    hasRight: false,
    estimatedCashbackAmount: 0,
  ),
  ActivityItem(
    id: 'activity_3',
    name: 'คืนเงิน 5%',
    slug: 'cashback-5',
    type: 'cashback',
    imageUrl: '',
    conditionText: 'ไม่ถูกรางวัลและซื้อครบ 50 ใบ',
    remainingNumbers: 0,
    hasRight: false,
    estimatedCashbackAmount: 0,
  ),
];
