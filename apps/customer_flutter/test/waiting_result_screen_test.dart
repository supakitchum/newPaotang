import 'package:customer_flutter/core/i18n/app_locale.dart';
import 'package:customer_flutter/core/i18n/customer_localizations.dart';
import 'package:customer_flutter/core/tenant/mobile_bootstrap_controller.dart';
import 'package:customer_flutter/core/theme/app_theme.dart';
import 'package:customer_flutter/features/results/data/result_models.dart';
import 'package:customer_flutter/features/results/data/result_repository.dart';
import 'package:customer_flutter/features/results/presentation/waiting_result_screen.dart';
import 'package:customer_flutter/shared/widgets/app_alert.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('waiting result shows placeholder numbers and live section', (
    tester,
  ) async {
    final currentGame = CurrentGame(
      id: 'game_1',
      name: 'งวดวันที่ 1 ก.ค. 2569',
      status: 'closed',
      drawAt: '2026-07-01T16:00:00+07:00',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentResultProvider.overrideWith((_) async {
            return RewardResultBundle(
              currentGame: currentGame,
              selectedResult: currentGame.toPendingRewardGame(),
              history: const [],
            );
          }),
          mobileBootstrapProvider.overrideWith((_) async {
            return MobileBootstrap.fromJson(
              const {
                'site': {'display_name': 'Alpha Lucky Shop'},
                'mobile': {'lottery_product_label': 'L6'},
                'live': {
                  'waiting_result_youtube_embed_url':
                      'https://www.youtube.com/embed/demo',
                  'source': 'tenant_override',
                },
              },
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
          home: const WaitingResultScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(_text('หมดเวลาจำหน่ายสลากแล้ว'), findsOneWidget);
    expect(_text('L6'), findsOneWidget);
    expect(_text('รอประกาศผลรางวัล'), findsOneWidget);
    expect(_text('xxxxxx'), findsOneWidget);
    expect(_text('xx'), findsOneWidget);
    expect(
      _text('ผลรางวัลนี้เป็นผลแสดงสดอย่างไม่เป็นทางการ'),
      findsNothing,
    );

    await tester.drag(
      find.byType(ListView),
      const Offset(0, -500),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    expect(_text('ถ่ายทอดสดประกาศผล'), findsOneWidget);
    expect(_text('เปิดถ่ายทอดสด'), findsOneWidget);
  });

  testWidgets('waiting result shows live empty state when not configured', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentResultProvider.overrideWith((_) async {
            return const RewardResultBundle(
              currentGame: null,
              selectedResult: null,
              history: [],
            );
          }),
          mobileBootstrapProvider.overrideWith((_) async {
            return MobileBootstrap.fromJson(
              const {'site': <String, dynamic>{}},
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
          home: const WaitingResultScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(_text('xxxxxx'), findsOneWidget);

    await tester.drag(
      find.byType(ListView),
      const Offset(0, -500),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    expect(_text('ระบบจะแสดงถ่ายทอดสดเมื่อพร้อมใช้งาน'), findsOneWidget);
    expect(_text('เปิดถ่ายทอดสด'), findsNothing);
  });

  testWidgets('waiting result consumes sale closed query like Nuxt', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/waiting-result?sale_closed=1',
      routes: [
        GoRoute(
          path: '/waiting-result',
          builder: (context, state) => WaitingResultScreen(
            showSaleClosedNotice:
                state.uri.queryParameters['sale_closed'] == '1',
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentResultProvider.overrideWith((_) async {
            return const RewardResultBundle(
              currentGame: null,
              selectedResult: null,
              history: [],
            );
          }),
          mobileBootstrapProvider.overrideWith((_) async {
            return MobileBootstrap.fromJson(
              const {'site': <String, dynamic>{}},
            );
          }),
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
          builder: (context, child) {
            return AppAlertHost(child: child ?? const SizedBox.shrink());
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/waiting-result',
    );
    expect(_text('หมดเวลาจำหน่ายสลากแล้ว'), findsNWidgets(2));
    expect(
      _text('ระบบพาไปหน้ารอออกผลแล้ว กรุณาตรวจผลรางวัลหลังประกาศผล'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('app-alert-close-button')),
      findsOneWidget,
    );
  });
}

Finder _text(String value) => find.text(value, skipOffstage: false);
