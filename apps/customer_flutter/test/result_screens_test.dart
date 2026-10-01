import 'package:customer_flutter/core/i18n/app_locale.dart';
import 'package:customer_flutter/core/i18n/customer_localizations.dart';
import 'package:customer_flutter/core/theme/app_theme.dart';
import 'package:customer_flutter/features/results/data/result_models.dart';
import 'package:customer_flutter/features/results/data/result_repository.dart';
import 'package:customer_flutter/features/results/presentation/result_detail_screen.dart';
import 'package:customer_flutter/features/results/presentation/result_screen.dart';
import 'package:customer_flutter/features/results/presentation/result_widgets.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  test('result detail back path preserves the Nuxt route alias family', () {
    expect(resultDetailBackPathFor('/result/full'), '/result');
    expect(resultDetailBackPathFor('/results/full'), '/results');
  });

  test('result index links preserve the Nuxt route alias family', () {
    expect(resultIndexPathFor('/result'), '/result');
    expect(resultIndexPathFor('/results'), '/results');
    expect(resultFullPathFor('/results', 'game_1'), '/results/full');
    expect(
      resultFullPathFor('/result', 'game / 1'),
      '/result/full?game_id=game+%2F+1',
    );
  });

  testWidgets('result summary card uses exact Nuxt colors', (tester) async {
    await tester.pumpWidget(
      _wrapResultWidget(
        ResultSummaryCard(
          result: _publishedResult(),
          variant: ResultSummaryCardVariant.featured,
        ),
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
      _hasTextColor(tester, 'ผลรางวัลสลากฯ ย้อนหลัง', const Color(0xFF15171C)),
      isTrue,
    );
  });

  testWidgets('result index responds without a fixed mobile hero gap', (
    tester,
  ) async {
    Future<void> pumpAt(Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
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

      final featured = tester.getRect(
        find.byKey(const ValueKey('result-featured-card')),
      );
      final historySheet = tester.getRect(
        find.byKey(const ValueKey('result-history-sheet')),
      );
      final backButton = tester.getRect(
        find.byKey(const ValueKey('result-back-button')),
      );

      expect(historySheet.top - featured.bottom, closeTo(12, 0.5));
      expect(backButton.left, greaterThanOrEqualTo(0));
      expect(backButton.right, lessThanOrEqualTo(size.width));
      expect(tester.takeException(), isNull);
    }

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpAt(const Size(320, 700));
    await pumpAt(const Size(768, 900));
    await pumpAt(const Size(1280, 900));
  });

  testWidgets('result index shows at most three previous draws', (
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
              history: List.generate(
                4,
                (index) => _historyResult(
                  id: 'game_history_$index',
                  firstPrize: '65432$index',
                ),
              ),
            );
          }),
        ],
        child: _materialApp(const ResultScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(ResultSummaryCard), findsNWidgets(4));
    expect(_text('654323'), findsNothing);
  });

  testWidgets('unofficial result notice is shown only in the bottom dock', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentResultProvider.overrideWith(
            (_) async => RewardResultBundle(
              currentGame: null,
              selectedResult: _unofficialResult(),
              history: const [],
            ),
          ),
        ],
        child: _materialApp(const ResultScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(ResultUnofficialDock), findsOneWidget);
    expect(_text('ผลรางวัลนี้เป็นผลแสดงสดอย่างไม่เป็นทางการ'), findsOneWidget);
  });

  testWidgets('legacy result index uses the legacy latest-result provider', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentResultProvider.overrideWith(
            (_) async => throw StateError('modern provider must not load'),
          ),
          legacyResultProvider.overrideWith(
            (_) async => RewardResultBundle(
              currentGame: null,
              selectedResult: _historyResult(),
              history: const [],
            ),
          ),
        ],
        child: _materialApp(const ResultScreen(routePath: '/results')),
      ),
    );

    await tester.pumpAndSettle();

    expect(_text('654321'), findsOneWidget);
    expect(_text('123456'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('current result detail keeps title hero and in-sheet draw date', (
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

    expect(_text('ผลรางวัลสลากฯ'), findsOneWidget);
    expect(_text('ผลรางวัลงวดวันที่ 1 ก.ค. 2569'), findsNothing);
    expect(_text('งวดวันที่ 1 ก.ค. 2569'), findsOneWidget);
    expect(_text('รางวัลที่ 1'), findsOneWidget);
    expect(_text('123456'), findsOneWidget);
    expect(_text('รางวัลที่ 2'), findsOneWidget);
    expect(_text('234567'), findsOneWidget);
    expect(find.byType(ResultUnofficialDock), findsNothing);
  });

  testWidgets('legacy results detail keeps dated hero without content date', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrapResultDetail(
        RewardResultBundle(
          currentGame: null,
          selectedResult: _publishedResult(),
          history: const [],
        ),
        backPath: '/results',
      ),
    );

    await tester.pumpAndSettle();

    expect(_text('ผลรางวัลงวดวันที่ 1 ก.ค. 2569'), findsOneWidget);
    expect(_text('งวดวันที่ 1 ก.ค. 2569'), findsNothing);
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

    expect(_text('ผลรางวัลสลากฯ'), findsOneWidget);
    expect(_text('งวดวันที่ 1 ก.ค. 2569'), findsOneWidget);
    expect(_text('1 ก.ค. 2569'), findsOneWidget);
    expect(_text('กำลังรอออกผล'), findsOneWidget);
    expect(_text('xxxxxx'), findsNothing);
    expect(_text('รางวัลที่ 2'), findsNothing);
  });

  testWidgets('result detail preserves backend error copy and retries', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          resultDetailProvider('game_error').overrideWith((_) async {
            attempts++;
            throw _resultApiException('ระบบผลรางวัลปิดปรับปรุง');
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
          home: const ResultDetailScreen(gameId: 'game_error'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(_text('ระบบผลรางวัลปิดปรับปรุง'), findsOneWidget);
    expect(_text('ลองใหม่'), findsOneWidget);
    expect(attempts, 1);

    await tester.tap(_text('ลองใหม่'));
    await tester.pumpAndSettle();

    expect(attempts, 2);
  });

  testWidgets('result index forwards maintenance to the shared system route', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/result',
      routes: [
        GoRoute(path: '/result', builder: (_, __) => const ResultScreen()),
        GoRoute(
          path: '/maintenance',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('Maintenance route'))),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentResultProvider.overrideWith(
            (_) async => throw _maintenanceException(),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: fallbackCustomerLocale,
          supportedLocales: supportedCustomerLocales,
          localizationsDelegates: const [
            CustomerLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: AppTheme.light(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(_text('Maintenance route'), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, '/maintenance');
    expect(tester.takeException(), isNull);
  });
}

Widget _wrapResultDetail(
  RewardResultBundle bundle, {
  String backPath = '/result',
}) {
  return ProviderScope(
    overrides: backPath == '/results'
        ? [
            publishedResultDetailProvider(
              'game_1',
            ).overrideWith((_) async => bundle),
          ]
        : [resultDetailProvider('game_1').overrideWith((_) async => bundle)],
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
      home: ResultDetailScreen(gameId: 'game_1', backPath: backPath),
    ),
  );
}

DioException _resultApiException(String message) {
  final request = RequestOptions(path: '/public/results/game_error');
  return DioException(
    requestOptions: request,
    response: Response<Map<String, dynamic>>(
      requestOptions: request,
      statusCode: 503,
      data: {
        'error': {'code': 'result_unavailable', 'message': message},
      },
    ),
  );
}

DioException _maintenanceException() {
  final request = RequestOptions(path: '/public/results/live/latest');
  return DioException(
    requestOptions: request,
    response: Response<Map<String, dynamic>>(
      requestOptions: request,
      statusCode: 503,
      data: const {
        'error': {
          'code': 'maintenance_active',
          'message': 'ระบบอยู่ระหว่างปรับปรุง',
        },
      },
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

RewardResultGame _historyResult({
  String id = 'game_history',
  String firstPrize = '654321',
}) {
  return RewardResultGame(
    id: id,
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
        numbers: [firstPrize],
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

RewardResultGame _unofficialResult() {
  final published = _publishedResult();
  return RewardResultGame(
    id: 'game_live',
    name: published.name,
    status: 'live_draft',
    resultStatus: 'live_draft',
    officialStatus: 'draft',
    completionPercent: 75,
    drawAt: published.drawAt,
    rewards: published.rewards,
  );
}

Finder _text(String value) => find.text(value, skipOffstage: false);

bool _hasTextColor(WidgetTester tester, String text, Color color) {
  return tester
      .widgetList<Text>(_text(text))
      .any((widget) => widget.style?.color == color);
}
