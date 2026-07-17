import 'dart:math';

import 'package:customer_flutter/core/utils/idempotency_key.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('newIdempotencyKey falls back when secure random is unavailable', () {
    var attempts = 0;

    final key = newIdempotencyKey(
      'customer_topup',
      secureRandomFactory: () {
        attempts++;
        throw UnsupportedError('secure random unavailable');
      },
    );

    expect(attempts, 1);
    expect(key, startsWith('customer_topup_'));
    expect(key.split('_'), hasLength(4));
    expect(key, isNot(contains(' ')));
  });

  test('newIdempotencyKey keeps secure random path when available', () {
    final key = newIdempotencyKey(
      'customer-reservation',
      secureRandomFactory: () => Random(1),
    );

    expect(key, startsWith('customer-reservation_'));
    expect(key.split('_').last, hasLength(16));
  });
}
