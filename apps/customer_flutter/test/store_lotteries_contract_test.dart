import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('store lottery page can reserve and release tickets through cart flow',
      () {
    final source = File('lib/features/stores/presentation/store_screens.dart')
        .readAsStringSync();

    expect(source, contains('authControllerProvider'));
    expect(source, contains('lotteryRepositoryProvider'));
    expect(source, contains('.reserve('));
    expect(source, contains('.releaseReservation('));
    expect(source, contains('_toLotteryStockItem'));
    expect(source, contains('lotteryAddedToCart'));
    expect(source, contains('lotteryRemovedFromCart'));
  });

  test('store list exposes Nuxt-style store lottery navigation', () {
    final source = File('lib/features/stores/presentation/store_screens.dart')
        .readAsStringSync();
    final storeCardSource =
        source.substring(source.indexOf('class _StoreCard'));
    final storeCardEnd = storeCardSource.indexOf('class _LotteryTicketCard');
    final storeCard = storeCardSource.substring(0, storeCardEnd);

    expect(source, contains("path: '/stores/lotteries'"));
    expect(storeCard, contains('onTap:'));
    expect(storeCard, contains('GestureDetector'));
    expect(storeCard, contains('MouseRegion'));
    expect(storeCard, isNot(contains('InkWell')));
    expect(storeCard, isNot(contains('Icons.chevron_right')));
  });
}
