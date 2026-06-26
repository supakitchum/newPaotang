import 'package:customer_flutter/features/lottery/presentation/sale_closure_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 6, 26, 12);

  test('does not watch non-sale routes', () {
    expect(saleClosureShouldWatchPath('/'), isFalse);
    expect(saleClosureShouldWatchPath('/tickets'), isFalse);
    expect(saleClosureShouldWatchPath('/waiting-result'), isFalse);
    expect(saleClosureShouldWatchPath('/buy'), isTrue);
    expect(saleClosureShouldWatchPath('/buy/search'), isTrue);
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

  test('redirects buy routes to waiting result after sale close time', () {
    expect(
      saleClosureRedirectPath(
        path: '/buy',
        gameStatus: 'open',
        saleCloseAt: now.subtract(const Duration(seconds: 1)).toIso8601String(),
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
  });

  test('redirects cart and checkout when game status is already closed', () {
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
