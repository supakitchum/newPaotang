import 'package:customer_flutter/core/auth/auth_token_store.dart';
import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/i18n/app_locale.dart';
import 'package:customer_flutter/core/i18n/customer_localizations.dart';
import 'package:customer_flutter/core/network/api_client.dart';
import 'package:customer_flutter/features/lottery/data/lottery_models.dart';
import 'package:customer_flutter/features/lottery/data/lottery_repository.dart';
import 'package:customer_flutter/features/lottery/presentation/sale_closure_guard.dart';
import 'package:customer_flutter/features/results/data/result_models.dart';
import 'package:customer_flutter/features/results/data/result_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  final now = DateTime(2026, 6, 26, 12);

  test('does not watch non-sale routes', () {
    expect(saleClosureShouldWatchPath('/tickets'), isFalse);
    expect(saleClosureShouldWatchPath('/waiting-result'), isFalse);
    expect(saleClosureShouldWatchPath('/'), isTrue);
    expect(saleClosureShouldWatchPath('/search'), isTrue);
    expect(saleClosureShouldWatchPath('/buy'), isTrue);
    expect(saleClosureShouldWatchPath('/buy/search'), isTrue);
    expect(saleClosureShouldWatchPath('/stores'), isTrue);
    expect(saleClosureShouldWatchPath('/stores/lotteries'), isTrue);
    expect(saleClosureShouldWatchPath('/cart'), isTrue);
    expect(saleClosureShouldWatchPath('/checkout'), isTrue);
  });

  test('keeps customer on buy routes before sale close time', () {
    expect(
      saleClosureRedirectPath(
        path: '/buy/search',
        gameStatus: 'open',
        saleCloseAt: now.add(const Duration(minutes: 1)).toIso8601String(),
        now: now,
      ),
      isNull,
    );
  });

  test('redirects open games after the API close_at time has passed', () {
    expect(
      saleClosureRedirectPath(
        path: '/buy/search',
        gameStatus: 'open',
        saleCloseAt: now.subtract(const Duration(seconds: 1)).toIso8601String(),
        now: now,
      ),
      '$waitingResultPath?$saleClosedNoticeQuery=1',
    );
  });

  test('uses wrapped camelCase current game fields for sale-close redirects',
      () {
    final game = CurrentGame.fromJson({
      'result': {
        'game': {
          'gameId': 'game_wrapped',
          'gameName': 'งวด Wrapped',
          'statusCode': 1,
          'saleCloseAt':
              now.subtract(const Duration(seconds: 1)).toIso8601String(),
          'serverTime': now.toIso8601String(),
        },
      },
    });

    expect(
      saleClosureRedirectPath(
        path: '/checkout',
        gameStatus: game.status,
        saleCloseAt: game.saleCloseAt,
        now: now,
      ),
      '$waitingResultPath?$saleClosedNoticeQuery=1',
    );
  });

  test('redirects sale routes to countdown before sale start', () {
    for (final path in [
      '/',
      '/search',
      '/buy',
      '/stores',
      '/stores/lotteries',
    ]) {
      expect(
        saleClosureRedirectPath(
          path: path,
          gameStatus: 'open',
          saleStartAt: now.add(const Duration(minutes: 5)).toIso8601String(),
          saleCloseAt: now.add(const Duration(days: 1)).toIso8601String(),
          now: now,
        ),
        countdownPath,
        reason: path,
      );
    }
  });

  test(
      'redirects browsing routes to waiting result after sale close time without cart',
      () {
    expect(
      saleClosureRedirectPath(
        path: '/',
        gameStatus: 'open',
        saleCloseAt: now.subtract(const Duration(seconds: 1)).toIso8601String(),
        now: now,
      ),
      '$waitingResultPath?$saleClosedNoticeQuery=1',
    );
    expect(
      saleClosureRedirectPath(
        path: '/search',
        gameStatus: 'open',
        saleCloseAt: now.toIso8601String(),
        now: now,
      ),
      '$waitingResultPath?$saleClosedNoticeQuery=1',
    );
    expect(
      saleClosureRedirectPath(
        path: '/buy/more',
        gameStatus: 'open',
        saleCloseAt: now.toIso8601String(),
        now: now,
      ),
      '$waitingResultPath?$saleClosedNoticeQuery=1',
    );
    expect(
      saleClosureRedirectPath(
        path: '/stores/lotteries',
        gameStatus: 'open',
        saleCloseAt: now.toIso8601String(),
        now: now,
      ),
      '$waitingResultPath?$saleClosedNoticeQuery=1',
    );
  });

  test(
      'redirects browsing routes to cart after sale close time when cart has items',
      () {
    for (final path in [
      '/',
      '/search',
      '/buy/search',
      '/stores',
      '/stores/lotteries',
    ]) {
      expect(
        saleClosureRedirectPath(
          path: path,
          gameStatus: 'open',
          saleCloseAt: now.toIso8601String(),
          now: now,
          hasActiveCart: true,
        ),
        '/cart',
        reason: path,
      );
    }
  });

  test('treats cart as active only while reservations have time left', () {
    final activeCart = _cart(
      expiresAt: now.add(const Duration(minutes: 5)).toIso8601String(),
      serverTime: now.toIso8601String(),
    );
    final expiredCart = _cart(
      expiresAt: now.subtract(const Duration(seconds: 1)).toIso8601String(),
      serverTime: now.toIso8601String(),
    );

    expect(
      saleClosureCartHasActiveReservations(activeCart, localNow: now),
      isTrue,
    );
    expect(
      saleClosureCartHasActiveReservations(expiredCart, localNow: now),
      isFalse,
    );
    expect(
      saleClosureRedirectPath(
        path: '/buy/search',
        gameStatus: 'closed',
        saleCloseAt: null,
        now: now,
        hasActiveCart: saleClosureCartHasActiveReservations(
          expiredCart,
          localNow: now,
        ),
      ),
      '$waitingResultPath?$saleClosedNoticeQuery=1',
    );
  });

  test('does not treat cart rows without a countdown deadline as active', () {
    expect(
      saleClosureCartHasActiveReservations(_cart(), localNow: now),
      isFalse,
    );
    expect(
      saleClosureCartHasActiveReservations(
        _cart(
          status: 'released',
          expiresAt: now.add(const Duration(minutes: 5)).toIso8601String(),
          serverTime: now.toIso8601String(),
        ),
        localNow: now,
      ),
      isFalse,
    );
  });

  test('uses cart payload server time when reservation rows omit it', () {
    final localNow = DateTime.parse('2026-06-26T10:00:00+07:00');
    final cart = _cart(
      expiresAt: '2026-06-26T12:00:00+07:00',
      serverTime: '2026-06-26T12:00:01+07:00',
    );

    expect(
      saleClosureCartHasActiveReservations(cart, localNow: localNow),
      isFalse,
    );
  });

  test('keeps cart and checkout available after sale close when cart has items',
      () {
    for (final path in ['/cart', '/checkout']) {
      expect(
        saleClosureRedirectPath(
          path: path,
          gameStatus: 'closed',
          saleCloseAt: null,
          now: now,
          hasActiveCart: true,
        ),
        isNull,
        reason: path,
      );
    }
  });

  test('redirects cart and checkout after sale close when cart is empty', () {
    for (final path in ['/cart', '/checkout']) {
      expect(
        saleClosureRedirectPath(
          path: path,
          gameStatus: 'closed',
          saleCloseAt: null,
          now: now,
        ),
        '$waitingResultPath?$saleClosedNoticeQuery=1',
        reason: path,
      );
    }
  });

  test('redirects sale and checkout routes to result after publication', () {
    for (final path in [
      '/search',
      '/buy',
      '/stores/lotteries',
      '/cart',
      '/checkout',
    ]) {
      expect(
        saleClosureRedirectPath(
          path: path,
          gameStatus: 'reward_published',
          saleCloseAt: null,
          now: now,
          hasActiveCart: true,
        ),
        resultPath,
        reason: path,
      );
    }
    expect(
      saleClosureRedirectPath(
        path: '/',
        gameStatus: 'reward_published',
        saleCloseAt: null,
        now: now,
        hasActiveCart: true,
      ),
      isNull,
    );
  });

  test('shows sale-closed notice only for waiting-result redirects', () {
    expect(
      saleClosureShouldShowClosedNotice(
        '$waitingResultPath?$saleClosedNoticeQuery=1',
      ),
      isTrue,
    );
    expect(saleClosureShouldShowClosedNotice(countdownPath), isFalse);
    expect(saleClosureShouldShowClosedNotice(resultPath), isFalse);
  });

  test('treats reward processing statuses as waiting-for-result states', () {
    for (final status in [
      'reward_recorded',
      'reward_checking',
      'reward_verified',
    ]) {
      expect(
        saleClosureRedirectPath(
          path: '/buy',
          gameStatus: status,
          saleCloseAt: null,
          now: now,
        ),
        '$waitingResultPath?$saleClosedNoticeQuery=1',
        reason: status,
      );
    }
  });

  test('uses server time plus elapsed local time for sale window checks', () {
    final fetchedAt = DateTime.utc(2026, 6, 26, 4, 59, 50);
    final fallbackNow = DateTime.utc(2026, 6, 26, 5, 0, 5);

    expect(
      saleClosureNow(
        gameServerTime: '2026-06-26T11:59:50+07:00',
        gameFetchedAt: fetchedAt,
        fallbackNow: fallbackNow,
      ),
      DateTime.parse('2026-06-26T12:00:05+07:00').toLocal(),
    );
  });

  test('ignores unsupported paths even when game is closed', () {
    expect(
      saleClosureRedirectPath(
        path: '/tickets',
        gameStatus: 'closed',
        saleCloseAt: now.subtract(const Duration(days: 1)).toIso8601String(),
        now: now,
      ),
      isNull,
    );
  });

  testWidgets('reloads active cart state after a sale-route location changes', (
    tester,
  ) async {
    final lottery = _SaleClosureLotteryRepository();
    final router = GoRouter(
      initialLocation: '/buy',
      routes: [
        GoRoute(
          path: '/buy',
          builder: (context, state) => const Scaffold(body: Text('Buy route')),
        ),
        GoRoute(
          path: '/cart',
          builder: (context, state) => const Scaffold(body: Text('Cart route')),
        ),
        GoRoute(
          path: waitingResultPath,
          builder: (context, state) => const Scaffold(
            body: Text('Waiting result route'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          resultRepositoryProvider.overrideWithValue(
            _ClosedSaleResultRepository(),
          ),
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
          routerConfig: router,
          builder: (context, child) => SaleClosureGuard(
            router: router,
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump();

    expect(lottery.cartCalls, greaterThanOrEqualTo(1));
    expect(router.routeInformationProvider.value.uri.toString(), '/cart');
    expect(find.text('Cart route'), findsOneWidget);

    final callsAfterCartRedirect = lottery.cartCalls;
    lottery.expired = true;
    router.go('/buy');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump();

    expect(lottery.cartCalls, greaterThan(callsAfterCartRedirect));
    expect(
      router.routeInformationProvider.value.uri.toString(),
      '$waitingResultPath?$saleClosedNoticeQuery=1',
    );
    expect(find.text('Waiting result route'), findsOneWidget);
    expect(lottery.releasedReservationIds, ['res_1']);
  });

  testWidgets('sale closure guard follows backend maintenance redirect', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/buy',
      routes: [
        GoRoute(
          path: '/buy',
          builder: (context, state) => const Scaffold(body: Text('Buy route')),
        ),
        GoRoute(
          path: '/maintenance',
          builder: (context, state) =>
              const Scaffold(body: Text('Maintenance route')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          resultRepositoryProvider.overrideWithValue(
            _FailingSaleResultRepository(),
          ),
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
          routerConfig: router,
          builder: (context, child) => SaleClosureGuard(
            router: router,
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump();

    expect(router.routeInformationProvider.value.uri.path, '/maintenance');
    expect(find.text('Maintenance route'), findsOneWidget);
  });
}

LotteryCart _cart({
  String status = 'active',
  Object? expiresAt,
  int expiresInSeconds = 0,
  Object? serverTime,
  Object? reservationServerTime,
}) {
  return LotteryCart.fromJson({
    'reservations': [
      {
        'id': 'res_1',
        'game_id': 'game_1',
        'status': status,
        'expires_at': expiresAt,
        'expires_in_seconds': expiresInSeconds,
        'server_time': reservationServerTime,
        'items': [
          {
            'id': 'stock_1',
            'local_stock_item_id': 'stock_1',
            'full_number': '273707',
            'price': 80,
            'seller_name': 'ร้านตัวอย่าง',
          },
        ],
        'total': 80,
      },
    ],
    'item_count': 1,
    'total': 80,
    'server_time': serverTime,
  });
}

class _ClosedSaleResultRepository extends ResultRepository {
  _ClosedSaleResultRepository() : super(_testApiClient());

  @override
  Future<CurrentGame?> currentGame() async {
    final now = DateTime.now();
    return CurrentGame(
      id: 'game_1',
      name: 'งวดทดสอบ',
      status: 'closed',
      drawAt: now.toIso8601String(),
      saleCloseAt: now.subtract(const Duration(minutes: 1)).toIso8601String(),
      serverTime: now.toIso8601String(),
    );
  }
}

class _FailingSaleResultRepository extends ResultRepository {
  _FailingSaleResultRepository() : super(_testApiClient());

  @override
  Future<CurrentGame?> currentGame() async {
    final request = RequestOptions(path: '/public/results/current-game');
    throw DioException(
      requestOptions: request,
      response: Response<Map<String, dynamic>>(
        requestOptions: request,
        statusCode: 503,
        data: const {
          'error': {
            'code': 'maintenance_active',
            'message': 'ระบบอยู่ระหว่างปิดปรับปรุง',
          },
        },
      ),
    );
  }
}

class _SaleClosureLotteryRepository extends LotteryRepository {
  _SaleClosureLotteryRepository() : super(_testApiClient());

  bool expired = false;
  int cartCalls = 0;
  final List<String> releasedReservationIds = [];

  @override
  Future<LotteryCart> cart() async {
    cartCalls++;
    final now = DateTime.now();
    return _cart(
      expiresAt: now
          .add(
            expired ? const Duration(seconds: -1) : const Duration(minutes: 5),
          )
          .toIso8601String(),
      serverTime: now.toIso8601String(),
    );
  }

  @override
  Future<LotteryCart> releaseReservation(String reservationId) async {
    releasedReservationIds.add(reservationId);
    return LotteryCart.empty();
  }
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
