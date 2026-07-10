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
import 'package:customer_flutter/features/lottery/presentation/lottery_screens.dart';
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
  testWidgets('buy screen exposes Nuxt-style store tab navigation', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/buy',
      routes: [
        GoRoute(path: '/buy', builder: (context, state) => const BuyScreen()),
        GoRoute(
          path: '/stores',
          builder: (context, state) => const Scaffold(body: Text('Stores')),
        ),
        GoRoute(
          path: '/cart',
          builder: (context, state) => const Scaffold(body: Text('Cart')),
        ),
      ],
    );

    await _pump(
      tester,
      router: router,
      overrides: [
        resultRepositoryProvider.overrideWithValue(_FakeResultRepository()),
        lotteryRepositoryProvider.overrideWithValue(_FakeLotteryRepository()),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('ซื้อสลากดิจิทัล'), findsOneWidget);
    expect(find.text('สลากฯ ทั้งหมด'), findsOneWidget);
    expect(find.text('ร้านค้า'), findsOneWidget);
    expect(find.text('ระบบสุ่มสลับรายการทุกครั้งที่โหลดใหม่'), findsNothing);

    await tester.tap(find.text('ร้านค้า'));
    await tester.pumpAndSettle();

    expect(find.text('Stores'), findsOneWidget);
  });

  testWidgets('buy digit boxes launch the Nuxt-style search page', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/buy',
      routes: [
        GoRoute(path: '/buy', builder: (context, state) => const BuyScreen()),
        GoRoute(
          path: '/buy/search',
          builder: (context, state) => const Scaffold(body: Text('Search')),
        ),
        GoRoute(
          path: '/stores',
          builder: (context, state) => const Scaffold(body: Text('Stores')),
        ),
        GoRoute(
          path: '/cart',
          builder: (context, state) => const Scaffold(body: Text('Cart')),
        ),
      ],
    );

    await _pump(
      tester,
      router: router,
      overrides: [
        resultRepositoryProvider.overrideWithValue(_FakeResultRepository()),
        lotteryRepositoryProvider.overrideWithValue(_FakeLotteryRepository()),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('ซื้อสลากดิจิทัล'), findsOneWidget);
    expect(find.textContaining('งวดวันที่'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'ค้นหา'), findsNothing);

    await tester.tap(find.byType(TextField).first);
    await tester.pumpAndSettle();

    expect(find.text('Search'), findsOneWidget);
  });

  testWidgets('stores screen exposes Nuxt-style store row navigation and tabs',
      (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/stores',
      routes: [
        GoRoute(
          path: '/stores',
          builder: (context, state) => const StoresScreen(),
        ),
        GoRoute(
          path: '/buy',
          builder: (context, state) => const Scaffold(body: Text('Buy')),
        ),
        GoRoute(
          path: '/stores/lotteries',
          builder: (context, state) => Scaffold(
            body: Text(
              'Store lotteries ${state.uri.queryParameters['store_id']}',
            ),
          ),
        ),
      ],
    );

    await _pump(
      tester,
      router: router,
      overrides: [
        storeRepositoryProvider.overrideWithValue(_FakeStoreRepository()),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('สลากฯ ทั้งหมด'), findsOneWidget);
    expect(find.text('ร้านค้า'), findsWidgets);
    expect(find.text('ร้านสลากฯ แนะนำ'), findsOneWidget);
    expect(find.text('ร้านทดสอบ'), findsOneWidget);
    expect(find.text('รหัสร้าน ST1'), findsNothing);
    final storeRow = find.byKey(const ValueKey('store-list-row-store_1'));
    expect(storeRow, findsOneWidget);
    expect(
      find.ancestor(of: storeRow, matching: find.byType(Card)),
      findsNothing,
    );

    await tester.ensureVisible(storeRow);
    await tester.pumpAndSettle();
    await tester.tap(storeRow);
    await tester.pumpAndSettle();

    expect(find.text('Store lotteries store_1'), findsOneWidget);

    router.go('/stores');
    await tester.pumpAndSettle();

    await tester.tap(find.text('สลากฯ ทั้งหมด'));
    await tester.pumpAndSettle();

    expect(find.text('Buy'), findsOneWidget);
  });

  testWidgets('stores screen shows fixed review dock when cart is active', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final tokenStore = AuthTokenStore();
    final authController = _authenticatedController(tokenStore);
    final lottery = _ActiveCartLotteryRepository(tokenStore);
    final router = GoRouter(
      initialLocation: '/stores',
      routes: [
        GoRoute(
          path: '/stores',
          builder: (context, state) => const StoresScreen(),
        ),
        GoRoute(
          path: '/buy',
          builder: (context, state) => const Scaffold(body: Text('Buy')),
        ),
        GoRoute(
          path: '/cart',
          builder: (context, state) => const Scaffold(body: Text('Cart route')),
        ),
      ],
    );

    await _pump(
      tester,
      router: router,
      tokenStore: tokenStore,
      authController: authController,
      overrides: [
        storeRepositoryProvider.overrideWithValue(_FakeStoreRepository()),
        lotteryRepositoryProvider.overrideWithValue(lottery),
      ],
    );
    await tester.pumpAndSettle();

    expect(lottery.cartCount, 1);
    final dock = find.byKey(const ValueKey('cart-selection-dock'));
    expect(dock, findsOneWidget);
    expect(
      find.ancestor(of: dock, matching: find.byType(ListView)),
      findsNothing,
    );
    final dockDecoration =
        tester.widget<DecoratedBox>(dock).decoration as BoxDecoration;
    expect(
      dockDecoration.borderRadius,
      const BorderRadius.vertical(top: Radius.circular(12)),
    );
    expect(
      find.descendant(
        of: dock,
        matching: find.textContaining('กรุณาชำระเงินภายใน'),
      ),
      findsOneWidget,
    );
    final reviewButton = find.widgetWithText(FilledButton, 'ตรวจสอบสลากฯ');
    expect(reviewButton, findsOneWidget);
    expect(
      find.descendant(
        of: reviewButton,
        matching: find.byIcon(Icons.shopping_cart_checkout),
      ),
      findsNothing,
    );
    expect(
      find.descendant(of: reviewButton, matching: find.textContaining('นาที')),
      findsNothing,
    );
    final dockBottom = tester.getBottomLeft(dock).dy;
    await tester.drag(
      find.byType(ListView),
      const Offset(0, -260),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(tester.getBottomLeft(dock).dy, closeTo(dockBottom, 1));

    await tester.tap(reviewButton);
    await tester.pumpAndSettle();

    expect(find.text('Cart route'), findsOneWidget);
  });

  testWidgets('stores screen renders Nuxt-style skeleton rows while loading', (
    tester,
  ) async {
    final repository = _DelayedInitialStoreRepository();
    final router = GoRouter(
      initialLocation: '/stores',
      routes: [
        GoRoute(
          path: '/stores',
          builder: (context, state) => const StoresScreen(),
        ),
        GoRoute(
          path: '/buy',
          builder: (context, state) => const Scaffold(body: Text('Buy')),
        ),
      ],
    );

    await _pump(
      tester,
      router: router,
      overrides: [
        storeRepositoryProvider.overrideWithValue(repository),
      ],
    );
    await tester.pump();

    expect(_storeListSkeletons(), findsNWidgets(6));
    expect(find.byType(CircularProgressIndicator), findsNothing);

    repository.completeStores();
    await tester.pumpAndSettle();

    expect(_storeListSkeletons(), findsNothing);
    expect(find.text('ร้านทดสอบ'), findsOneWidget);
  });

  testWidgets('stores screen auto-loads the next page near the bottom', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = _PaginatedStoreRepository();
    final router = GoRouter(
      initialLocation: '/stores',
      routes: [
        GoRoute(
          path: '/stores',
          builder: (context, state) => const StoresScreen(),
        ),
        GoRoute(
          path: '/buy',
          builder: (context, state) => const Scaffold(body: Text('Buy')),
        ),
      ],
    );

    await _pump(
      tester,
      router: router,
      overrides: [
        storeRepositoryProvider.overrideWithValue(repository),
      ],
    );
    await tester.pumpAndSettle();

    expect(repository.listCount, 1);
    expect(find.text('ร้านหน้าแรก 01'), findsOneWidget);
    expect(find.text('ร้านถัดไป'), findsNothing);

    await tester.drag(find.byType(ListView), const Offset(0, -1800));
    await tester.pumpAndSettle();

    expect(repository.listCount, 2);
    expect(repository.cursors, ['', 'cursor_1']);
    expect(find.text('ร้านถัดไป'), findsOneWidget);
  });

  testWidgets(
      'stores screen appends Nuxt-style skeleton rows while loading more', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = _DelayedNextStoreRepository();
    final router = GoRouter(
      initialLocation: '/stores',
      routes: [
        GoRoute(
          path: '/stores',
          builder: (context, state) => const StoresScreen(),
        ),
        GoRoute(
          path: '/buy',
          builder: (context, state) => const Scaffold(body: Text('Buy')),
        ),
      ],
    );

    await _pump(
      tester,
      router: router,
      overrides: [
        storeRepositoryProvider.overrideWithValue(repository),
      ],
    );
    await tester.pumpAndSettle();

    expect(repository.listCount, 1);

    await tester.drag(find.byType(ListView), const Offset(0, -1800));
    await tester.pump();
    await tester.pump();

    expect(repository.listCount, 2);
    expect(repository.cursors, ['', 'cursor_1']);
    expect(find.text('ร้านหน้าแรก 01'), findsOneWidget);
    expect(_storeListSkeletons('store-list-skeleton-more'), findsNWidgets(6));
    expect(find.byType(CircularProgressIndicator), findsNothing);

    repository.completeNextPage();
    await tester.pumpAndSettle();

    expect(_storeListSkeletons('store-list-skeleton-more'), findsNothing);
    expect(find.text('ร้านถัดไป'), findsOneWidget);
  });

  testWidgets('stores screen omits Flutter load-more CTA', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 520));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = _ShortPaginatedStoreRepository();
    final router = GoRouter(
      initialLocation: '/stores',
      routes: [
        GoRoute(
          path: '/stores',
          builder: (context, state) => const StoresScreen(),
        ),
        GoRoute(
          path: '/buy',
          builder: (context, state) => const Scaffold(body: Text('Buy')),
        ),
      ],
    );

    await _pump(
      tester,
      router: router,
      overrides: [
        storeRepositoryProvider.overrideWithValue(repository),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(OutlinedButton, 'โหลดเพิ่มเติม'), findsNothing);
  });

  testWidgets('stores screen load failure shows API payload copy safely', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/stores',
      routes: [
        GoRoute(
          path: '/stores',
          builder: (context, state) => const StoresScreen(),
        ),
        GoRoute(
          path: '/buy',
          builder: (context, state) => const Scaffold(body: Text('Buy')),
        ),
      ],
    );

    await _pump(
      tester,
      router: router,
      overrides: [
        storeRepositoryProvider.overrideWithValue(
          _FailingStoreRepository(
            _apiException(
              'ยังไม่สามารถโหลดร้านค้าได้ กรุณาลองใหม่',
              path: '/public/stores',
            ),
          ),
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('โหลดร้านค้าไม่สำเร็จ'), findsOneWidget);
    expect(
      find.text('ยังไม่สามารถโหลดร้านค้าได้ กรุณาลองใหม่'),
      findsOneWidget,
    );
    expect(find.textContaining('internal store list failure'), findsNothing);
  });

  testWidgets('stores screen load failure hides internal errors', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/stores',
      routes: [
        GoRoute(
          path: '/stores',
          builder: (context, state) => const StoresScreen(),
        ),
        GoRoute(
          path: '/buy',
          builder: (context, state) => const Scaffold(body: Text('Buy')),
        ),
      ],
    );

    await _pump(
      tester,
      router: router,
      overrides: [
        storeRepositoryProvider.overrideWithValue(
          _FailingStoreRepository(StateError('internal store list failure')),
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('โหลดร้านค้าไม่สำเร็จ'), findsOneWidget);
    expect(find.text('กรุณาลองใหม่อีกครั้ง'), findsOneWidget);
    expect(find.textContaining('internal store list failure'), findsNothing);
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required GoRouter router,
  required List<Override> overrides,
  AuthTokenStore? tokenStore,
  AuthController? authController,
}) {
  final effectiveTokenStore = tokenStore ?? AuthTokenStore();
  final effectiveAuthController =
      authController ?? _unauthenticatedController(effectiveTokenStore);
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        mobileBootstrapProvider.overrideWith((_) async => _mobileBootstrap()),
        authTokenStoreProvider.overrideWithValue(effectiveTokenStore),
        authControllerProvider.overrideWith((_) => effectiveAuthController),
        ...overrides,
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
}

Finder _storeListSkeletons([String keyPrefix = 'store-list-skeleton']) {
  return find.byWidgetPredicate((widget) {
    final key = widget.key;
    return key is ValueKey<String> && key.value.startsWith('$keyPrefix-');
  });
}

MobileBootstrap _mobileBootstrap() {
  return MobileBootstrap.fromJson(const {
    'mobile': {'lottery_product_label': 'L6'},
  });
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

class _FakeLotteryRepository extends LotteryRepository {
  _FakeLotteryRepository() : super(_testApiClient());

  @override
  Future<LotteryStockPage> search({
    required String gameId,
    List<String> digits = const [],
    String number = '',
    String storeId = '',
    String cursor = '',
    String randomSeed = '',
    int limit = 20,
  }) async {
    return LotteryStockPage(
      gameId: gameId,
      items: const [],
      nextCursor: '',
      hasMore: false,
      sellerName: '',
    );
  }

  @override
  Future<LotteryCart> cart() async => LotteryCart.empty();
}

class _ActiveCartLotteryRepository extends LotteryRepository {
  _ActiveCartLotteryRepository(AuthTokenStore tokenStore)
      : super(_testApiClient(tokenStore));

  int cartCount = 0;

  @override
  Future<LotteryCart> cart() async {
    cartCount++;
    final now = DateTime.now();
    final expiresAt = now.add(const Duration(minutes: 12)).toIso8601String();
    return LotteryCart(
      reservations: [
        LotteryReservation(
          id: 'res_store_1',
          gameId: 'game_1',
          status: 'active',
          expiresAt: expiresAt,
          expiresInSeconds: 720,
          serverTime: now.toIso8601String(),
          items: const [
            LotteryStockItem(
              id: 'vstock:game_1:273707:1',
              token: 'stock-token',
              localStockItemId: 'local-stock-1',
              stockRef: 'vstock-ref-1',
              number: '273707',
              sellerName: 'ร้านทดสอบ',
              storeName: 'ร้านทดสอบ',
              price: 80,
              remainingCount: 1,
              status: 'available',
              reservationId: 'res_store_1',
              reservationExpiresAt: null,
              serverTime: null,
              imageUrl: '',
              thumbUrl: '',
              raw: {},
            ),
          ],
          total: 80,
        ),
      ],
      total: 80,
      itemCount: 1,
      serverTime: now.toIso8601String(),
      warnings: const [],
    );
  }
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

class _FakeStoreRepository extends StoreRepository {
  _FakeStoreRepository() : super(_testApiClient());

  @override
  Future<StorePage> list({
    String q = '',
    String cursor = '',
    int limit = 30,
  }) async {
    return const StorePage(
      items: [
        StoreItem(
          id: 'store_1',
          name: 'ร้านทดสอบ',
          code: 'ST1',
        ),
      ],
      nextCursor: '',
      hasMore: false,
    );
  }
}

class _DelayedInitialStoreRepository extends StoreRepository {
  _DelayedInitialStoreRepository() : super(_testApiClient());

  final _storesCompleter = Completer<StorePage>();

  void completeStores() {
    if (_storesCompleter.isCompleted) return;
    _storesCompleter.complete(
      const StorePage(
        items: [
          StoreItem(
            id: 'store_1',
            name: 'ร้านทดสอบ',
            code: 'ST1',
          ),
        ],
        nextCursor: '',
        hasMore: false,
      ),
    );
  }

  @override
  Future<StorePage> list({
    String q = '',
    String cursor = '',
    int limit = 30,
  }) {
    return _storesCompleter.future;
  }
}

class _PaginatedStoreRepository extends StoreRepository {
  _PaginatedStoreRepository() : super(_testApiClient());

  final cursors = <String>[];

  int get listCount => cursors.length;

  @override
  Future<StorePage> list({
    String q = '',
    String cursor = '',
    int limit = 30,
  }) async {
    cursors.add(cursor);
    if (cursor == 'cursor_1') {
      return const StorePage(
        items: [
          StoreItem(
            id: 'store_next',
            name: 'ร้านถัดไป',
            code: 'NEXT',
          ),
        ],
        nextCursor: '',
        hasMore: false,
      );
    }

    return StorePage(
      items: List.generate(
        24,
        (index) {
          final ordinal = (index + 1).toString().padLeft(2, '0');
          return StoreItem(
            id: 'store_$ordinal',
            name: 'ร้านหน้าแรก $ordinal',
            code: 'FIRST$ordinal',
          );
        },
      ),
      nextCursor: 'cursor_1',
      hasMore: true,
    );
  }
}

class _DelayedNextStoreRepository extends StoreRepository {
  _DelayedNextStoreRepository() : super(_testApiClient());

  final cursors = <String>[];
  final _nextPageCompleter = Completer<StorePage>();

  int get listCount => cursors.length;

  void completeNextPage() {
    if (_nextPageCompleter.isCompleted) return;
    _nextPageCompleter.complete(
      const StorePage(
        items: [
          StoreItem(
            id: 'store_next',
            name: 'ร้านถัดไป',
            code: 'NEXT',
          ),
        ],
        nextCursor: '',
        hasMore: false,
      ),
    );
  }

  @override
  Future<StorePage> list({
    String q = '',
    String cursor = '',
    int limit = 30,
  }) {
    cursors.add(cursor);
    if (cursor.isEmpty) {
      return Future.value(
        StorePage(
          items: List.generate(
            24,
            (index) {
              final ordinal = (index + 1).toString().padLeft(2, '0');
              return StoreItem(
                id: 'store_$ordinal',
                name: 'ร้านหน้าแรก $ordinal',
                code: 'FIRST$ordinal',
              );
            },
          ),
          nextCursor: 'cursor_1',
          hasMore: true,
        ),
      );
    }
    return _nextPageCompleter.future;
  }
}

class _ShortPaginatedStoreRepository extends StoreRepository {
  _ShortPaginatedStoreRepository() : super(_testApiClient());

  final cursors = <String>[];

  int get listCount => cursors.length;

  @override
  Future<StorePage> list({
    String q = '',
    String cursor = '',
    int limit = 30,
  }) async {
    cursors.add(cursor);
    if (cursor == 'cursor_1') {
      return const StorePage(
        items: [
          StoreItem(
            id: 'store_next',
            name: 'ร้านถัดไป',
            code: 'NEXT',
          ),
        ],
        nextCursor: '',
        hasMore: false,
      );
    }

    return const StorePage(
      items: [
        StoreItem(
          id: 'store_first',
          name: 'ร้านหน้าแรก',
          code: 'FIRST',
        ),
      ],
      nextCursor: 'cursor_1',
      hasMore: true,
    );
  }
}

class _FailingStoreRepository extends StoreRepository {
  _FailingStoreRepository(this.error) : super(_testApiClient());

  final Object error;

  @override
  Future<StorePage> list({
    String q = '',
    String cursor = '',
    int limit = 30,
  }) async {
    throw error;
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
    const AppConfig(
      apiBaseUrl: 'https://partner.example.test/api/v1',
      defaultLocale: 'th-TH',
    ),
    tokenStore ?? AuthTokenStore(),
    localeTag: 'th-TH',
  );
}
