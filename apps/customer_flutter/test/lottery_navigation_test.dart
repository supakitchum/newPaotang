import 'package:customer_flutter/features/lottery/presentation/lottery_navigation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lotterySearchPath preserves digit filters and store context', () {
    final uri = Uri.parse(
      lotterySearchPath(
        digits: ['2', 'x', '3', '', '7', '09'],
        storeId: 'store_1',
        storeName: 'ร้านทดสอบ',
      ),
    );

    expect(uri.path, '/buy/search');
    expect(uri.queryParameters['d1'], '2');
    expect(uri.queryParameters.containsKey('d2'), isFalse);
    expect(uri.queryParameters['d3'], '3');
    expect(uri.queryParameters['d5'], '7');
    expect(uri.queryParameters['d6'], '0');
    expect(uri.queryParameters['store_id'], 'store_1');
    expect(uri.queryParameters['store_name'], 'ร้านทดสอบ');
  });

  test('lotteryStorePath preserves the selected store identity', () {
    final uri = Uri.parse(
      lotteryStorePath(
        storeId: ' store_1 ',
        storeName: ' ร้านทดสอบ ',
      ),
    );

    expect(uri.path, '/stores/lotteries');
    expect(uri.queryParameters['store_id'], 'store_1');
    expect(uri.queryParameters['store_name'], 'ร้านทดสอบ');
  });

  test('lotterySearchPath uses exact number before digit filters', () {
    final uri = Uri.parse(
      lotterySearchPath(
        number: '12-34-56-99',
        digits: const ['9', '9', '9', '9', '9', '9'],
      ),
    );

    expect(uri.queryParameters['number'], '123456');
    expect(uri.queryParameters.containsKey('d1'), isFalse);
  });

  test('isExactLotterySearch detects exact search inputs', () {
    expect(isExactLotterySearch(number: '123456'), isTrue);
    expect(isExactLotterySearch(number: '12345'), isFalse);
    expect(
      isExactLotterySearch(digits: const ['1', '2', '3', '4', '5', '6']),
      isTrue,
    );
    expect(
      isExactLotterySearch(digits: const ['1', '', '3', '4', '5', '6']),
      isFalse,
    );
  });

  test('lotteryMorePath carries safe back path for search restore', () {
    final back = lotterySearchPath(
      digits: const ['2', '', '3'],
      storeId: 'store_1',
    );
    final uri = Uri.parse(
      lotteryMorePath(
        number: '273707',
        storeId: 'store_1',
        backPath: back,
      ),
    );

    expect(uri.path, '/buy/more');
    expect(uri.queryParameters['number'], '273707');
    expect(uri.queryParameters['store_id'], 'store_1');
    expect(uri.queryParameters['back'], back);
  });

  test('lotteryMorePath carries safe store-scoped back path', () {
    final uri = Uri.parse(
      lotteryMorePath(
        number: '273707',
        storeId: 'store_1',
        backPath: '/stores/lotteries?store_id=store_1',
      ),
    );

    expect(uri.path, '/buy/more');
    expect(uri.queryParameters['number'], '273707');
    expect(uri.queryParameters['store_id'], 'store_1');
    expect(uri.queryParameters['back'], '/stores/lotteries?store_id=store_1');
  });

  test('shouldPopLotteryMoreBack only restores stacked lottery routes', () {
    expect(
      shouldPopLotteryMoreBack(
        canPop: true,
        explicitBackPath: '/buy/search?d1=2',
      ),
      isTrue,
    );
    expect(
      shouldPopLotteryMoreBack(canPop: false, explicitBackPath: '/buy/search'),
      isFalse,
    );
    expect(
      shouldPopLotteryMoreBack(canPop: true, explicitBackPath: ''),
      isFalse,
    );
  });

  test('safeLotteryBackPath rejects external and non-lottery destinations', () {
    expect(safeLotteryBackPath('https://evil.test/buy'), '/buy');
    expect(safeLotteryBackPath('//evil.test/buy'), '/buy');
    expect(safeLotteryBackPath('/profile'), '/buy');
    expect(
      safeLotteryBackPath('/buy/search?number=123456&store_id=store_1'),
      '/buy/search?number=123456&store_id=store_1',
    );
    expect(
      safeLotteryBackPath('/stores/lotteries?store_id=store_1'),
      '/stores/lotteries?store_id=store_1',
    );
  });

  test('lotteryMorePath omits unsafe back path', () {
    final uri = Uri.parse(
      lotteryMorePath(
        number: '273707',
        backPath: 'https://evil.test/buy/search',
      ),
    );

    expect(uri.queryParameters.containsKey('back'), isFalse);
  });
}
