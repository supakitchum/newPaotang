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
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('stock card toggles select and remove from the live cart state', (
    tester,
  ) async {
    final lottery = _FakeLotteryRepository();
    final router = GoRouter(
      initialLocation: '/buy/search?number=273707',
      routes: [
        GoRoute(
          path: '/buy/search',
          builder: (context, state) => BuySearchScreen(
            query: state.uri.queryParameters,
          ),
        ),
        GoRoute(
          path: '/buy',
          builder: (context, state) => const SizedBox.shrink(),
        ),
        GoRoute(
          path: '/cart',
          builder: (context, state) => const SizedBox.shrink(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          resultRepositoryProvider.overrideWithValue(_FakeResultRepository()),
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

    expect(lottery.searchCount, 1);
    expect(find.text('273707'), findsOneWidget);
    expect(find.text('เลือก'), findsOneWidget);
    expect(find.text('เอาออก'), findsNothing);

    await tester.tap(find.text('เลือก'));
    await tester.pumpAndSettle();

    expect(lottery.reserveCount, 1);
    expect(find.text('เพิ่มสลากลงตะกร้าแล้ว'), findsOneWidget);
    expect(find.text('เลือก'), findsNothing);
    expect(find.text('เอาออก'), findsOneWidget);

    await tester.tap(find.text('เอาออก'));
    await tester.pumpAndSettle();

    expect(lottery.releaseCount, 1);
    expect(find.text('เลือก'), findsOneWidget);
    expect(find.text('เอาออก'), findsNothing);
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

  bool _reserved = false;
  int searchCount = 0;
  int reserveCount = 0;
  int releaseCount = 0;

  @override
  Future<LotteryStockPage> search({
    required String gameId,
    List<String> digits = const [],
    String number = '',
    String storeId = '',
    String cursor = '',
    int limit = 20,
  }) async {
    searchCount++;
    return LotteryStockPage(
      gameId: gameId,
      items: [_stockItem()],
      nextCursor: '',
      hasMore: false,
      sellerName: 'ร้านทดสอบ',
    );
  }

  @override
  Future<LotteryReservation> reserve({
    required String gameId,
    required LotteryStockItem item,
  }) async {
    reserveCount++;
    _reserved = true;
    return LotteryReservation(
      id: 'reservation_1',
      gameId: gameId,
      status: 'active',
      expiresAt: '2026-06-29T12:30:00+07:00',
      expiresInSeconds: 900,
      serverTime: '2026-06-29T12:15:00+07:00',
      items: [_stockItem(reservationId: 'reservation_1')],
      total: 80,
    );
  }

  @override
  Future<LotteryCart> cart() async {
    return _reserved ? _reservedCart() : LotteryCart.empty();
  }

  @override
  Future<LotteryCart> releaseReservation(String reservationId) async {
    releaseCount++;
    _reserved = false;
    return LotteryCart.empty();
  }

  LotteryCart _reservedCart() {
    return LotteryCart(
      reservations: [
        LotteryReservation(
          id: 'reservation_1',
          gameId: 'game_1',
          status: 'active',
          expiresAt: '2026-06-29T12:30:00+07:00',
          expiresInSeconds: 900,
          serverTime: '2026-06-29T12:15:00+07:00',
          items: [_stockItem(reservationId: 'reservation_1')],
          total: 80,
        ),
      ],
      total: 80,
      itemCount: 1,
      serverTime: '2026-06-29T12:15:00+07:00',
      warnings: const [],
    );
  }

  LotteryStockItem _stockItem({String reservationId = ''}) {
    return LotteryStockItem(
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
      reservationId: reservationId,
      reservationExpiresAt: null,
      serverTime: null,
      imageUrl: '',
      thumbUrl: '',
      raw: const {},
    );
  }
}

ApiClient _testApiClient() {
  return ApiClient(
    const AppConfig(
      apiBaseUrl: 'https://partner.example.com/api/v1',
      defaultLocale: 'th-TH',
    ),
    AuthTokenStore(),
    localeTag: 'th-TH',
  );
}
