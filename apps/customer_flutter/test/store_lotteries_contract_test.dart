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

  test('store list does not expose store lottery navigation before phase', () {
    final source = File('lib/features/stores/presentation/store_screens.dart')
        .readAsStringSync();
    final storeCardSource =
        source.substring(source.indexOf('class _StoreCard'));
    final storeCardEnd = storeCardSource.indexOf('class _LotteryTicketCard');
    final storeCard = storeCardSource.substring(0, storeCardEnd);

    expect(storeCard, isNot(contains('/stores/lotteries')));
    expect(storeCard, isNot(contains('onTap:')));
    expect(storeCard, isNot(contains('Icons.chevron_right')));
  });
}
