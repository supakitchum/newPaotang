import 'package:customer_flutter/core/i18n/app_locale.dart';
import 'package:customer_flutter/core/i18n/customer_localizations.dart';
import 'package:customer_flutter/core/theme/app_theme.dart';
import 'package:customer_flutter/features/results/data/result_models.dart';
import 'package:customer_flutter/features/results/data/result_repository.dart';
import 'package:customer_flutter/features/results/presentation/result_detail_screen.dart';
import 'package:customer_flutter/features/results/presentation/result_screen.dart';
import 'package:customer_flutter/features/results/presentation/result_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('result summary card uses exact Nuxt colors', (tester) async {
    await tester.pumpWidget(
      _wrapResultWidget(
        ResultSummaryCard(result: _publishedResult(), featured: true),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      _hasTextColor(tester, 'ผลรางวัลสลากฯ', const Color(0xFF15171C)),
      isTrue,
    );
    expect(
      _hasTextColor(tester, 'รางวัลที่ 1', const Color(0xFF8A8F98)),
      isTrue,
    );
    expect(_hasTextColor(tester, '123456', const Color(0xFF20385F)), isTrue);
    expect(_hasTextColor(tester, '111', const Color(0xFF22262D)), isTrue);
  });

  testWidgets('result index keeps Nuxt history sheet title color', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentResultProvider.overrideWith((_) async {
            return RewardResultBundle(
              currentGame: null,
              selectedResult: _publishedResult(),
              history: [_historyResult()],
            );
          }),
        ],
        child: _materialApp(const ResultScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      _hasTextColor(
        tester,
        'ผลรางวัลสลากฯ ย้อนหลัง',
        const Color(0xFF15171C),
      ),
      isTrue,
    );
  });

  testWidgets('result detail uses Nuxt-style dated hero and prize rows', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrapResultDetail(
        RewardResultBundle(
          currentGame: null,
          selectedResult: _publishedResult(),
          history: const [],
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(_text('ผลรางวัลงวดวันที่ 1 ก.ค. 2569'), findsOneWidget);
    expect(_text('งวดวันที่ 1 ก.ค. 2569'), findsNothing);
    expect(_text('รางวัลที่ 1'), findsOneWidget);
    expect(_text('123456'), findsOneWidget);
    expect(_text('รางวัลที่ 2'), findsOneWidget);
    expect(_text('234567'), findsOneWidget);
    expect(
      _text(
        'คุณสามารถขึ้นเงินรางวัลได้ที่ ธนาคารกรุงไทย ธ.ก.ส. ออมสิน ทุกสาขา หรือสำนักงานสลากกินแบ่งรัฐบาล',
      ),
      findsOneWidget,
    );
  });

  testWidgets('result detail shows waiting state before numbers resolve', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrapResultDetail(
        const RewardResultBundle(
          currentGame: null,
          selectedResult: RewardResultGame(
            id: 'game_pending',
            name: '1 ก.ค. 2569',
            status: 'closed',
            resultStatus: '',
            officialStatus: '',
            completionPercent: 0,
            drawAt: null,
            rewards: [],
          ),
          history: [],
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(_text('ผลรางวัลงวดวันที่ 1 ก.ค. 2569'), findsOneWidget);
    expect(_text('กำลังรอออกผล'), findsOneWidget);
    expect(_text('xxxxxx'), findsNothing);
    expect(_text('รางวัลที่ 2'), findsNothing);
  });
}

Widget _wrapResultDetail(RewardResultBundle bundle) {
  return ProviderScope(
    overrides: [
      resultDetailProvider('game_1').overrideWith((_) async => bundle),
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
      home: const ResultDetailScreen(gameId: 'game_1'),
    ),
  );
}

Widget _wrapResultWidget(Widget child) {
  return _materialApp(Scaffold(body: Center(child: child)));
}

Widget _materialApp(Widget home) {
  return MaterialApp(
    locale: fallbackCustomerLocale,
    supportedLocales: supportedCustomerLocales,
    localizationsDelegates: const [
      CustomerLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    theme: AppTheme.light(),
    home: home,
  );
}

RewardResultGame _publishedResult() {
  return const RewardResultGame(
    id: 'game_1',
    name: '1 ก.ค. 2569',
    status: 'published',
    resultStatus: 'published',
    officialStatus: 'published',
    completionPercent: 100,
    drawAt: null,
    rewards: [
      RewardValue(
        slug: 'reward_1',
        title: 'รางวัลที่ 1',
        amount: 6000000,
        numbers: ['123456'],
      ),
      RewardValue(
        slug: 'reward_two_digit',
        title: 'เลขท้าย 2 ตัว',
        amount: 2000,
        numbers: ['12'],
      ),
      RewardValue(
        slug: 'reward_three_digit_1',
        title: 'เลขหน้า 3 ตัว',
        amount: 4000,
        numbers: ['111', '222'],
      ),
      RewardValue(
        slug: 'reward_three_digit_2',
        title: 'เลขท้าย 3 ตัว',
        amount: 4000,
        numbers: ['333', '444'],
      ),
      RewardValue(
        slug: 'reward_2',
        title: 'รางวัลที่ 2',
        amount: 200000,
        numbers: ['234567', '345678'],
      ),
    ],
  );
}

RewardResultGame _historyResult() {
  return const RewardResultGame(
    id: 'game_history',
    name: '16 มิ.ย. 2569',
    status: 'published',
    resultStatus: 'published',
    officialStatus: 'published',
    completionPercent: 100,
    drawAt: null,
    rewards: [
      RewardValue(
        slug: 'reward_1',
        title: 'รางวัลที่ 1',
        amount: 6000000,
        numbers: ['654321'],
      ),
      RewardValue(
        slug: 'reward_two_digit',
        title: 'เลขท้าย 2 ตัว',
        amount: 2000,
        numbers: ['21'],
      ),
    ],
  );
}

Finder _text(String value) => find.text(value, skipOffstage: false);

bool _hasTextColor(WidgetTester tester, String text, Color color) {
  return tester
      .widgetList<Text>(_text(text))
      .any((widget) => widget.style?.color == color);
}
