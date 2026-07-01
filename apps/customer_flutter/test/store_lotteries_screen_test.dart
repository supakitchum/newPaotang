import 'dart:async';

import 'package:customer_flutter/core/auth/auth_controller.dart';
import 'package:customer_flutter/core/auth/auth_repository.dart';
import 'package:customer_flutter/core/auth/auth_token_store.dart';
import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/i18n/app_locale.dart';
import 'package:customer_flutter/core/i18n/customer_localizations.dart';
import 'package:customer_flutter/core/network/api_client.dart';
import 'package:customer_flutter/core/security/biometric_auth_service.dart';
import 'package:customer_flutter/core/tenant/mobile_bootstrap_controller.dart';
import 'package:customer_flutter/core/theme/app_theme.dart';
import 'package:customer_flutter/features/lottery/data/lottery_models.dart';
import 'package:customer_flutter/features/lottery/data/lottery_repository.dart';
import 'package:customer_flutter/features/lottery/presentation/lottery_stock_realtime_monitor.dart';
import 'package:customer_flutter/features/results/data/result_models.dart';
import 'package:customer_flutter/features/results/data/result_repository.dart';
import 'package:customer_flutter/features/stores/data/store_models.dart';
import 'package:customer_flutter/features/stores/data/store_repository.dart';
import 'package:customer_flutter/features/stores/presentation/store_screens.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('store lotteries search submits six Nuxt-style digit filters', (
    tester,
  ) async {
    final store = _FakeStoreRepository();
    final tokenStore = AuthTokenStore();
    final authController = _unauthenticatedController(tokenStore);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_testConfig),
          mobileBootstrapProvider.overrideWith((_) async => _mobileBootstrap()),
          authTokenStoreProvider.overrideWithValue(tokenStore),
          authControllerProvider.overrideWith((_) => authController),
          resultRepositoryProvider.overrideWithValue(_FakeResultRepository()),
          storeRepositoryProvider.overrideWithValue(store),
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
          home: const StoreLotteriesScreen(
            storeId: 'store_1',
            storeName: 'ร้านทดสอบ',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(store.searchCount, 1);
    expect(find.text('ร้านสลากหกหลักแบบดิจิทัล'), findsOneWidget);
    final storeHero = find.byKey(const ValueKey('store-lotteries-hero'));
    expect(storeHero, findsOneWidget);
    expect(
      find.ancestor(of: storeHero, matching: find.byType(Card)),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('store-lotteries-hero-favorite')),
      findsOneWidget,
    );
    expect(find.text('ค้นหาเลขสลากฯ ในร้านค้า'), findsOneWidget);
    expect(find.textContaining('งวดวันที่'), findsOneWidget);
    final searchPanel =
        find.byKey(const ValueKey('store-lotteries-search-panel'));
    expect(searchPanel, findsOneWidget);
    expect(
      find.ancestor(of: searchPanel, matching: find.byType(Card)),
      findsNothing,
    );
    expect(store.lastDigits, ['', '', '', '', '', '']);
    expect(find.byType(TextField), findsNWidgets(6));
    expect(find.text('เลือก'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('lottery-stock-brand-row')),
      findsWidgets,
    );
    expect(
      find.byKey(const ValueKey('lottery-stock-seller-row')),
      findsWidgets,
    );
    expect(find.text('สลากกินแบ่งรัฐบาล'), findsWidgets);
    expect(find.text('L6'), findsWidgets);
    expect(find.text('ร้านทดสอบ'), findsWidgets);
    final searchButton = find.widgetWithText(FilledButton, 'ค้นหาเลข');
    expect(searchButton, findsOneWidget);
    expect(
      find.descendant(of: searchButton, matching: find.byIcon(Icons.search)),
      findsNothing,
    );
    final clearButton = find.widgetWithText(OutlinedButton, 'ล้างค่า');
    expect(clearButton, findsOneWidget);
    expect(
      find.descendant(of: clearButton, matching: find.byIcon(Icons.refresh)),
      findsNothing,
    );

    await tester.enterText(find.byType(TextField).at(0), '4');
    await tester.enterText(find.byType(TextField).at(2), '5');
    await tester.enterText(find.byType(TextField).at(5), '6');
    await tester.tap(searchButton);
    await tester.pumpAndSettle();

    expect(store.searchCount, 2);
    expect(store.lastStoreId, 'store_1');
    expect(store.lastGameId, 'game_1');
    expect(store.lastDigits, ['4', '', '5', '', '', '6']);
    expect(find.text('เลือก'), findsOneWidget);

    await tester.tap(clearButton);
    await tester.pumpAndSettle();

    expect(store.searchCount, 3);
    expect(store.lastDigits, ['', '', '', '', '', '']);
    for (var index = 0; index < 6; index++) {
      expect(
        tester
            .widget<TextField>(find.byType(TextField).at(index))
            .controller
            ?.text,
        '',
      );
    }
  });

  testWidgets('store lotteries refresh enters Nuxt-style cooldown', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = _FakeStoreRepository();
    final tokenStore = AuthTokenStore();
    final authController = _unauthenticatedController(tokenStore);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_testConfig),
          mobileBootstrapProvider.overrideWith((_) async => _mobileBootstrap()),
          authTokenStoreProvider.overrideWithValue(tokenStore),
          authControllerProvider.overrideWith((_) => authController),
          resultRepositoryProvider.overrideWithValue(_FakeResultRepository()),
          storeRepositoryProvider.overrideWithValue(store),
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
          home: const StoreLotteriesScreen(
            storeId: 'store_1',
            storeName: 'ร้านทดสอบ',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(store.searchCount, 1);
    expect(find.text('เลขสลากดิจิทัล'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'แสดงเลขใหม่'));
    await tester.pump();
    await tester.pump();

    expect(store.searchCount, 2);
    expect(find.widgetWithText(TextButton, 'รอ 10 วิ'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'รอ 10 วิ'))
          .onPressed,
      isNull,
    );

    await tester.pump(const Duration(seconds: 1));
    expect(find.widgetWithText(TextButton, 'รอ 9 วิ'), findsOneWidget);
    expect(store.searchCount, 2);

    await tester.pump(const Duration(seconds: 9));
    final refreshButton = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'แสดงเลขใหม่'),
    );
    expect(refreshButton.onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('store lotteries refreshes stock on realtime tick', (
    tester,
  ) async {
    final store = _FakeStoreRepository();
    final tokenStore = AuthTokenStore();
    final authController = _unauthenticatedController(tokenStore);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_testConfig),
          mobileBootstrapProvider.overrideWith((_) async => _mobileBootstrap()),
          authTokenStoreProvider.overrideWithValue(tokenStore),
          authControllerProvider.overrideWith((_) => authController),
          resultRepositoryProvider.overrideWithValue(_FakeResultRepository()),
          storeRepositoryProvider.overrideWithValue(store),
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
          home: const StoreLotteriesScreen(
            storeId: 'store_1',
            storeName: 'ร้านทดสอบ',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(store.searchCount, 1);
    expect(find.text('เลือก'), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(StoreLotteriesScreen)),
      listen: false,
    );
    container.read(lotteryStockRealtimeTickProvider.notifier).state++;
    await tester.pump();
    await tester.pumpAndSettle();

    expect(store.searchCount, 2);
    expect(store.lastStoreId, 'store_1');
    expect(store.lastGameId, 'game_1');
    expect(find.text('เลือก'), findsOneWidget);
  });

  testWidgets('store lotteries shows Nuxt-style selected-cart dock', (
    tester,
  ) async {
    final store = _FakeStoreRepository();
    final lottery = _SuccessfulReservationLotteryRepository();
    final tokenStore = AuthTokenStore();
    final authController = _authenticatedController(tokenStore);
    final router = GoRouter(
      initialLocation: '/stores/lotteries',
      routes: [
        GoRoute(
          path: '/stores/lotteries',
          builder: (context, state) => const StoreLotteriesScreen(
            storeId: 'store_1',
            storeName: 'ร้านทดสอบ',
          ),
        ),
        GoRoute(
          path: '/cart',
          builder: (context, state) => const Scaffold(
            body: Text('Cart route'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_testConfig),
          mobileBootstrapProvider.overrideWith((_) async => _mobileBootstrap()),
          authTokenStoreProvider.overrideWithValue(tokenStore),
          authControllerProvider.overrideWith((_) => authController),
          resultRepositoryProvider.overrideWithValue(_FakeResultRepository()),
          storeRepositoryProvider.overrideWithValue(store),
          lotteryRepositoryProvider.overrideWithValue(lottery),
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

    expect(find.text('จำนวนที่เลือก'), findsNothing);
    expect(find.text('คุณมีสลากฯ ที่เลือกไว้'), findsNothing);

    await tester.tap(find.text('เลือก'));
    await tester.pumpAndSettle();

    expect(lottery.reserveCount, 1);
    expect(find.text('คุณมีสลากฯ ที่เลือกไว้'), findsNothing);
    expect(find.text('จำนวนที่เลือก'), findsOneWidget);
    expect(find.text('1 ใบ'), findsOneWidget);
    expect(find.textContaining('กรุณาชำระเงินภายใน'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    final reviewButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'ตรวจสอบสลากฯ'),
    );
    expect(
      find.descendant(
        of: find.widgetWithText(FilledButton, 'ตรวจสอบสลากฯ'),
        matching: find.byIcon(Icons.shopping_cart_checkout),
      ),
      findsNothing,
    );
    expect(reviewButton.onPressed, isNotNull);
    reviewButton.onPressed!();
    await tester.pumpAndSettle();

    expect(find.text('Cart route'), findsOneWidget);
  });

  testWidgets('store lotteries handles unavailable reservation races like Nuxt',
      (
    tester,
  ) async {
    final store = _FakeStoreRepository();
    final lottery = _UnavailableReservationLotteryRepository();
    final tokenStore = AuthTokenStore();
    final authController = _authenticatedController(tokenStore);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_testConfig),
          mobileBootstrapProvider.overrideWith((_) async => _mobileBootstrap()),
          authTokenStoreProvider.overrideWithValue(tokenStore),
          authControllerProvider.overrideWith((_) => authController),
          resultRepositoryProvider.overrideWithValue(_FakeResultRepository()),
          storeRepositoryProvider.overrideWithValue(store),
          lotteryRepositoryProvider.overrideWithValue(lottery),
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
          home: const StoreLotteriesScreen(
            storeId: 'store_1',
            storeName: 'ร้านทดสอบ',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(lottery.cartCount, 1);
    expect(find.text('เลือก'), findsOneWidget);

    await tester.tap(find.text('เลือก'));
    await tester.pumpAndSettle();

    expect(lottery.reserveCount, 1);
    expect(lottery.cartCount, 2);
    expect(find.text('สลากใบนี้ถูกซื้อแล้ว'), findsOneWidget);
    expect(
      find.text('ขออภัย สลากที่ท่านเลือกมีคนซื้อแล้ว กรุณาเลือกสลากใบอื่น'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'รับทราบ'));
    await tester.pumpAndSettle();

    expect(find.text('เลือก'), findsNothing);
    expect(find.text('ยังไม่มีสลากให้เลือก'), findsOneWidget);
  });

  testWidgets('store lotteries disables new reservations when sales are closed',
      (
    tester,
  ) async {
    final store = _ClosedStoreLotteryRepository();
    final lottery = _CountingLotteryRepository();
    final tokenStore = AuthTokenStore();
    final authController = _authenticatedController(tokenStore);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_testConfig),
          mobileBootstrapProvider.overrideWith((_) async => _mobileBootstrap()),
          authTokenStoreProvider.overrideWithValue(tokenStore),
          authControllerProvider.overrideWith((_) => authController),
          resultRepositoryProvider.overrideWithValue(_FakeResultRepository()),
          storeRepositoryProvider.overrideWithValue(store),
          lotteryRepositoryProvider.overrideWithValue(lottery),
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
          home: const StoreLotteriesScreen(
            storeId: 'store_1',
            storeName: 'ร้านทดสอบ',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('ขณะนี้ไม่สามารถซื้อสลากได้'), findsOneWidget);
    expect(find.text('ปิดรับซื้อ'), findsOneWidget);
    final reserveButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'ปิดรับซื้อ'),
    );
    expect(reserveButton.onPressed, isNull);
    expect(lottery.reserveCount, 0);
  });

  testWidgets('store lotteries auto-loads the next page near the bottom', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = _PaginatedStoreLotteryRepository();
    final tokenStore = AuthTokenStore();
    final authController = _unauthenticatedController(tokenStore);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_testConfig),
          mobileBootstrapProvider.overrideWith((_) async => _mobileBootstrap()),
          authTokenStoreProvider.overrideWithValue(tokenStore),
          authControllerProvider.overrideWith((_) => authController),
          resultRepositoryProvider.overrideWithValue(_FakeResultRepository()),
          storeRepositoryProvider.overrideWithValue(store),
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
          home: const StoreLotteriesScreen(
            storeId: 'store_1',
            storeName: 'ร้านทดสอบ',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(store.searchCount, 1);
    expect(store.cursors, ['']);
    expect(find.text('ร้านหน้าแรก 01'), findsOneWidget);
    expect(find.text('ร้านถัดไป'), findsNothing);

    final listView = tester.widget<ListView>(find.byType(ListView));
    final position = listView.controller!.position;
    expect(position.maxScrollExtent, greaterThan(180));
    position.jumpTo(position.maxScrollExtent - 160);
    await tester.pumpAndSettle();

    expect(store.searchCount, 2);
    expect(store.cursors, ['', 'cursor_1']);
    expect(find.text('ร้านถัดไป'), findsOneWidget);
  });

  testWidgets(
    'store lotteries fallback load-more stays text-only like Nuxt',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final store = _ShortPaginatedStoreLotteryRepository();
      final tokenStore = AuthTokenStore();
      final authController = _unauthenticatedController(tokenStore);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWithValue(_testConfig),
            mobileBootstrapProvider
                .overrideWith((_) async => _mobileBootstrap()),
            authTokenStoreProvider.overrideWithValue(tokenStore),
            authControllerProvider.overrideWith((_) => authController),
            resultRepositoryProvider.overrideWithValue(_FakeResultRepository()),
            storeRepositoryProvider.overrideWithValue(store),
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
            home: const StoreLotteriesScreen(
              storeId: 'store_1',
              storeName: 'ร้านทดสอบ',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final loadMoreButton =
          find.widgetWithText(OutlinedButton, 'โหลดเพิ่มเติม');
      expect(loadMoreButton, findsOneWidget);
      expect(
        find.descendant(
          of: loadMoreButton,
          matching: find.byIcon(Icons.expand_more),
        ),
        findsNothing,
      );

      await tester.tap(loadMoreButton);
      await tester.pumpAndSettle();

      expect(store.searchCount, 2);
      expect(store.cursors, ['', 'cursor_1']);
      expect(find.text('ร้านถัดไป'), findsOneWidget);
    },
  );

  testWidgets(
    'store lotteries renders Nuxt-style skeletons while initially loading',
    (tester) async {
      final store = _DelayedInitialStoreLotteryRepository();
      final tokenStore = AuthTokenStore();
      final authController = _unauthenticatedController(tokenStore);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWithValue(_testConfig),
            mobileBootstrapProvider
                .overrideWith((_) async => _mobileBootstrap()),
            authTokenStoreProvider.overrideWithValue(tokenStore),
            authControllerProvider.overrideWith((_) => authController),
            resultRepositoryProvider.overrideWithValue(_FakeResultRepository()),
            storeRepositoryProvider.overrideWithValue(store),
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
            home: const StoreLotteriesScreen(
              storeId: 'store_1',
              storeName: 'ร้านทดสอบ',
            ),
          ),
        ),
      );

      await tester.pump();

      expect(_storeLotteryStockSkeletons(), findsNWidgets(5));
      expect(find.byType(CircularProgressIndicator), findsNothing);

      store.completeLotteries();
      await tester.pumpAndSettle();

      expect(_storeLotteryStockSkeletons(), findsNothing);
      expect(find.text('เลือก'), findsOneWidget);
    },
  );

  testWidgets('store lotteries appends Nuxt-style skeletons while loading more',
      (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = _DelayedNextStoreLotteryRepository();
    final tokenStore = AuthTokenStore();
    final authController = _unauthenticatedController(tokenStore);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_testConfig),
          mobileBootstrapProvider.overrideWith((_) async => _mobileBootstrap()),
          authTokenStoreProvider.overrideWithValue(tokenStore),
          authControllerProvider.overrideWith((_) => authController),
          resultRepositoryProvider.overrideWithValue(_FakeResultRepository()),
          storeRepositoryProvider.overrideWithValue(store),
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
          home: const StoreLotteriesScreen(
            storeId: 'store_1',
            storeName: 'ร้านทดสอบ',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(store.searchCount, 1);
    expect(_storeLotteryStockSkeletons(), findsNothing);

    final listView = tester.widget<ListView>(find.byType(ListView));
    final position = listView.controller!.position;
    expect(position.maxScrollExtent, greaterThan(180));
    position.jumpTo(position.maxScrollExtent - 160);
    await tester.pump();
    await tester.pump();

    expect(store.searchCount, 2);
    expect(store.cursors, ['', 'cursor_1']);
    expect(find.text('ร้านหน้าแรก 01'), findsOneWidget);
    expect(
      _storeLotteryStockSkeletons('store-lottery-stock-skeleton-more'),
      findsNWidgets(5),
    );

    store.completeNextPage();
    await tester.pumpAndSettle();

    expect(
      _storeLotteryStockSkeletons('store-lottery-stock-skeleton-more'),
      findsNothing,
    );
    expect(find.text('ร้านถัดไป'), findsOneWidget);
  });

  testWidgets(
    'store lotteries load failure shows API payload copy safely',
    (tester) async {
      final tokenStore = AuthTokenStore();
      final authController = _unauthenticatedController(tokenStore);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWithValue(_testConfig),
            mobileBootstrapProvider
                .overrideWith((_) async => _mobileBootstrap()),
            authTokenStoreProvider.overrideWithValue(tokenStore),
            authControllerProvider.overrideWith((_) => authController),
            resultRepositoryProvider.overrideWithValue(_FakeResultRepository()),
            storeRepositoryProvider.overrideWithValue(
              _FailingStoreLotteryRepository(
                _apiException(
                  'ยังไม่สามารถโหลดเลขสลากได้ กรุณาลองใหม่',
                  path: '/public/stores/store_1/lotteries',
                ),
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
            home: const StoreLotteriesScreen(
              storeId: 'store_1',
              storeName: 'ร้านทดสอบ',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('โหลดเลขสลากไม่สำเร็จ'), findsOneWidget);
      expect(
        find.text('ยังไม่สามารถโหลดเลขสลากได้ กรุณาลองใหม่'),
        findsOneWidget,
      );
      expect(
        find.textContaining('internal store lottery failure'),
        findsNothing,
      );
    },
  );

  testWidgets('store lotteries load failure hides internal errors', (
    tester,
  ) async {
    final tokenStore = AuthTokenStore();
    final authController = _unauthenticatedController(tokenStore);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_testConfig),
          mobileBootstrapProvider.overrideWith((_) async => _mobileBootstrap()),
          authTokenStoreProvider.overrideWithValue(tokenStore),
          authControllerProvider.overrideWith((_) => authController),
          resultRepositoryProvider.overrideWithValue(_FakeResultRepository()),
          storeRepositoryProvider.overrideWithValue(
            _FailingStoreLotteryRepository(
              StateError('internal store lottery failure'),
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
          home: const StoreLotteriesScreen(
            storeId: 'store_1',
            storeName: 'ร้านทดสอบ',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('โหลดเลขสลากไม่สำเร็จ'), findsOneWidget);
    expect(find.text('กรุณาลองใหม่อีกครั้ง'), findsOneWidget);
    expect(find.textContaining('internal store lottery failure'), findsNothing);
  });
}

const _testConfig = AppConfig(
  apiBaseUrl: 'https://partner.example.test/api/v1',
  defaultLocale: 'th-TH',
);

MobileBootstrap _mobileBootstrap() {
  return MobileBootstrap.fromJson(const {
    'mobile': {'lottery_product_label': 'L6'},
  });
}

AuthController _unauthenticatedController(AuthTokenStore tokenStore) {
  final api = _testApiClient(tokenStore);
  return AuthController(
    authRepository: AuthRepository(api: api, tokenStore: tokenStore),
    tokenStore: tokenStore,
    biometricAuth: BiometricAuthService(api),
  )
    ..isAuthenticated = false
    ..pinRequired = false;
}

AuthController _authenticatedController(AuthTokenStore tokenStore) {
  final api = _testApiClient(tokenStore);
  return AuthController(
    authRepository: AuthRepository(api: api, tokenStore: tokenStore),
    tokenStore: tokenStore,
    biometricAuth: BiometricAuthService(api),
  )
    ..isAuthenticated = true
    ..pinRequired = false;
}

class _FakeResultRepository extends ResultRepository {
  _FakeResultRepository() : super(_testApiClient());

  @override
  Future<CurrentGame?> currentGame() async {
    return const CurrentGame(
      id: 'game_1',
      name: 'งวดทดสอบ',
      status: 'open',
      drawAt: '2026-07-01T17:00:00+07:00',
    );
  }
}

class _FakeStoreRepository extends StoreRepository {
  _FakeStoreRepository() : super(_testApiClient());

  int searchCount = 0;
  String lastStoreId = '';
  String lastGameId = '';
  List<String> lastDigits = const [];

  @override
  Future<StoreLotteryPage> lotteries({
    required String storeId,
    required String gameId,
    List<String> digits = const [],
    String cursor = '',
    int limit = 20,
  }) async {
    searchCount++;
    lastStoreId = storeId;
    lastGameId = gameId;
    lastDigits = List<String>.from(digits);
    final searched = digits.any((digit) => digit.trim().isNotEmpty);
    return StoreLotteryPage(
      items: [
        _ticket(number: searched ? '456456' : '123123'),
      ],
      nextCursor: '',
      hasMore: false,
      gameId: gameId,
      sellerName: 'ร้านทดสอบ',
    );
  }

  StoreLotteryTicket _ticket({
    required String number,
    String sellerName = 'ร้านทดสอบ',
  }) {
    return StoreLotteryTicket(
      id: 'stock_$number',
      token: 'token_$number',
      localStockItemId: 'local_$number',
      stockRef: 'ref_$number',
      number: number,
      sellerName: sellerName,
      storeName: sellerName,
      price: 80,
      remainingCount: 1,
      status: 'available',
      reservationId: '',
    );
  }
}

class _FailingStoreLotteryRepository extends _FakeStoreRepository {
  _FailingStoreLotteryRepository(this.error);

  final Object error;

  @override
  Future<StoreLotteryPage> lotteries({
    required String storeId,
    required String gameId,
    List<String> digits = const [],
    String cursor = '',
    int limit = 20,
  }) async {
    searchCount++;
    lastStoreId = storeId;
    lastGameId = gameId;
    lastDigits = List<String>.from(digits);
    throw error;
  }
}

class _PaginatedStoreLotteryRepository extends _FakeStoreRepository {
  final cursors = <String>[];

  @override
  Future<StoreLotteryPage> lotteries({
    required String storeId,
    required String gameId,
    List<String> digits = const [],
    String cursor = '',
    int limit = 20,
  }) async {
    searchCount++;
    lastStoreId = storeId;
    lastGameId = gameId;
    lastDigits = List<String>.from(digits);
    cursors.add(cursor);
    if (cursor.isEmpty) {
      return StoreLotteryPage(
        items: [
          for (var index = 1; index <= 12; index++)
            _ticket(
              number: (120000 + index).toString(),
              sellerName: 'ร้านหน้าแรก ${index.toString().padLeft(2, '0')}',
            ),
        ],
        nextCursor: 'cursor_1',
        hasMore: true,
        gameId: gameId,
        sellerName: 'ร้านทดสอบ',
      );
    }
    return StoreLotteryPage(
      items: [
        _ticket(number: '999999', sellerName: 'ร้านถัดไป'),
      ],
      nextCursor: '',
      hasMore: false,
      gameId: gameId,
      sellerName: 'ร้านทดสอบ',
    );
  }
}

class _ShortPaginatedStoreLotteryRepository extends _FakeStoreRepository {
  final cursors = <String>[];

  @override
  Future<StoreLotteryPage> lotteries({
    required String storeId,
    required String gameId,
    List<String> digits = const [],
    String cursor = '',
    int limit = 20,
  }) async {
    searchCount++;
    lastStoreId = storeId;
    lastGameId = gameId;
    lastDigits = List<String>.from(digits);
    cursors.add(cursor);
    if (cursor.isEmpty) {
      return StoreLotteryPage(
        items: [_ticket(number: '120001', sellerName: 'ร้านหน้าแรก')],
        nextCursor: 'cursor_1',
        hasMore: true,
        gameId: gameId,
        sellerName: 'ร้านทดสอบ',
      );
    }
    return StoreLotteryPage(
      items: [_ticket(number: '999999', sellerName: 'ร้านถัดไป')],
      nextCursor: '',
      hasMore: false,
      gameId: gameId,
      sellerName: 'ร้านทดสอบ',
    );
  }
}

class _ClosedStoreLotteryRepository extends _FakeStoreRepository {
  @override
  Future<StoreLotteryPage> lotteries({
    required String storeId,
    required String gameId,
    List<String> digits = const [],
    String cursor = '',
    int limit = 20,
  }) async {
    searchCount++;
    lastStoreId = storeId;
    lastGameId = gameId;
    lastDigits = List<String>.from(digits);
    return StoreLotteryPage(
      items: [_ticket(number: '123123')],
      nextCursor: '',
      hasMore: false,
      gameId: gameId,
      sellerName: 'ร้านทดสอบ',
      canReserve: false,
    );
  }
}

class _DelayedInitialStoreLotteryRepository extends _FakeStoreRepository {
  final _lotteriesCompleter = Completer<StoreLotteryPage>();

  void completeLotteries() {
    if (_lotteriesCompleter.isCompleted) return;
    _lotteriesCompleter.complete(
      StoreLotteryPage(
        items: [_ticket(number: '123123')],
        nextCursor: '',
        hasMore: false,
        gameId: 'game_1',
        sellerName: 'ร้านทดสอบ',
      ),
    );
  }

  @override
  Future<StoreLotteryPage> lotteries({
    required String storeId,
    required String gameId,
    List<String> digits = const [],
    String cursor = '',
    int limit = 20,
  }) {
    searchCount++;
    lastStoreId = storeId;
    lastGameId = gameId;
    lastDigits = List<String>.from(digits);
    return _lotteriesCompleter.future;
  }
}

class _DelayedNextStoreLotteryRepository extends _FakeStoreRepository {
  final cursors = <String>[];
  final _nextPageCompleter = Completer<StoreLotteryPage>();

  void completeNextPage() {
    if (_nextPageCompleter.isCompleted) return;
    _nextPageCompleter.complete(
      StoreLotteryPage(
        items: [_ticket(number: '999999', sellerName: 'ร้านถัดไป')],
        nextCursor: '',
        hasMore: false,
        gameId: 'game_1',
        sellerName: 'ร้านทดสอบ',
      ),
    );
  }

  @override
  Future<StoreLotteryPage> lotteries({
    required String storeId,
    required String gameId,
    List<String> digits = const [],
    String cursor = '',
    int limit = 20,
  }) {
    searchCount++;
    lastStoreId = storeId;
    lastGameId = gameId;
    lastDigits = List<String>.from(digits);
    cursors.add(cursor);
    if (cursor.isEmpty) {
      return Future.value(
        StoreLotteryPage(
          items: [
            for (var index = 1; index <= 12; index++)
              _ticket(
                number: (120000 + index).toString(),
                sellerName: 'ร้านหน้าแรก ${index.toString().padLeft(2, '0')}',
              ),
          ],
          nextCursor: 'cursor_1',
          hasMore: true,
          gameId: gameId,
          sellerName: 'ร้านทดสอบ',
        ),
      );
    }
    return _nextPageCompleter.future;
  }
}

class _UnavailableReservationLotteryRepository extends LotteryRepository {
  _UnavailableReservationLotteryRepository() : super(_testApiClient());

  int cartCount = 0;
  int reserveCount = 0;

  @override
  Future<LotteryCart> cart() async {
    cartCount++;
    return LotteryCart.empty();
  }

  @override
  Future<LotteryReservation> reserve({
    required String gameId,
    required LotteryStockItem item,
  }) async {
    reserveCount++;
    throw DioException(
      requestOptions: RequestOptions(path: '/customer/reservations'),
      response: Response(
        requestOptions: RequestOptions(path: '/customer/reservations'),
        statusCode: 409,
        data: const {
          'error': {
            'code': 'reservation_unavailable',
            'message': 'The requested stock is no longer available.',
          },
        },
      ),
    );
  }
}

class _SuccessfulReservationLotteryRepository extends LotteryRepository {
  _SuccessfulReservationLotteryRepository() : super(_testApiClient());

  int cartCount = 0;
  int reserveCount = 0;

  @override
  Future<LotteryCart> cart() async {
    cartCount++;
    return LotteryCart.empty();
  }

  @override
  Future<LotteryReservation> reserve({
    required String gameId,
    required LotteryStockItem item,
  }) async {
    reserveCount++;
    return LotteryReservation(
      id: 'res_store_1',
      gameId: gameId,
      status: 'active',
      expiresAt: null,
      expiresInSeconds: 600,
      serverTime: DateTime.now().toIso8601String(),
      items: [item],
      total: item.price,
    );
  }
}

class _CountingLotteryRepository extends LotteryRepository {
  _CountingLotteryRepository() : super(_testApiClient());

  int cartCount = 0;
  int reserveCount = 0;

  @override
  Future<LotteryCart> cart() async {
    cartCount++;
    return LotteryCart.empty();
  }

  @override
  Future<LotteryReservation> reserve({
    required String gameId,
    required LotteryStockItem item,
  }) async {
    reserveCount++;
    throw StateError('Reserve should stay disabled while sales are closed.');
  }
}

DioException _apiException(String message, {required String path}) {
  final request = RequestOptions(path: path);
  return DioException(
    requestOptions: request,
    response: Response<Map<String, dynamic>>(
      requestOptions: request,
      statusCode: 422,
      data: {'message': message},
    ),
  );
}

ApiClient _testApiClient([AuthTokenStore? tokenStore]) {
  return ApiClient(
    _testConfig,
    tokenStore ?? AuthTokenStore(),
    localeTag: 'th-TH',
  );
}

Finder _storeLotteryStockSkeletons([
  String keyPrefix = 'store-lottery-stock-skeleton',
]) {
  return find.byWidgetPredicate((widget) {
    final key = widget.key;
    return key is ValueKey<String> && key.value.startsWith('$keyPrefix-');
  });
}
