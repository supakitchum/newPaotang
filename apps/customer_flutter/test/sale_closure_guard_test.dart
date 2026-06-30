import 'package:customer_flutter/features/lottery/presentation/sale_closure_guard.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
