import 'package:customer_flutter/core/auth/auth_token_store.dart';
import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/i18n/app_locale.dart';
import 'package:customer_flutter/core/i18n/customer_localizations.dart';
import 'package:customer_flutter/core/network/api_client.dart';
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

  testWidgets('stores screen exposes Nuxt-style all-ticket tab navigation', (
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
        storeRepositoryProvider.overrideWithValue(_FakeStoreRepository()),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('สลากฯ ทั้งหมด'), findsOneWidget);
    expect(find.text('ร้านค้า'), findsWidgets);
    expect(find.text('ร้านสลากฯ แนะนำ'), findsOneWidget);
    expect(find.text('ร้านทดสอบ'), findsOneWidget);

    await tester.tap(find.text('สลากฯ ทั้งหมด'));
    await tester.pumpAndSettle();

    expect(find.text('Buy'), findsOneWidget);
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
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
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

ApiClient _testApiClient() {
  return ApiClient(
    const AppConfig(
      apiBaseUrl: 'https://partner.example.test/api/v1',
      defaultLocale: 'th-TH',
    ),
    AuthTokenStore(),
    localeTag: 'th-TH',
  );
}
