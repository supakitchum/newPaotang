import 'package:customer_flutter/core/auth/auth_token_store.dart';
import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/network/api_client.dart';
import 'package:customer_flutter/core/payment/checkout_payment_config.dart';
import 'package:customer_flutter/features/lottery/data/lottery_models.dart';
import 'package:customer_flutter/features/lottery/data/lottery_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lottery reserve sends virtual stock reference required by backend',
      () async {
    final api = _CheckoutApiClient();
    final repository = LotteryRepository(api);

    await repository.reserve(
      gameId: 'game_1',
      item: LotteryStockItem.fromJson(const {
        'id': 'local_stock_1',
        'local_stock_item_id': 'local_stock_1',
        'stock_ref': 'vstock:tenant_1:game_1:273707:1',
        'full_number': '273707',
      }),
    );

    expect(api.path, '/customer/reservations');
    expect(api.payload['game_id'], 'game_1');
    expect(api.payload['local_stock_item_ids'], [
      'vstock:tenant_1:game_1:273707:1',
    ]);
    expect(
      api.headers['Idempotency-Key'],
      startsWith('customer-reservation_'),
    );
  });

  test('lottery checkout sends the configured payment method', () async {
    final api = _CheckoutApiClient();
    final repository = LotteryRepository(api);

    await repository.checkout(
      ['res_1', ' res_2 '],
      paymentMethod: checkoutPaymentMethodExternalPayment,
    );

    expect(api.path, '/customer/checkout');
    expect(api.payload['reservation_id'], 'res_1');
    expect(api.payload['reservation_ids'], ['res_1', 'res_2']);
    expect(api.payload['payment_method'], checkoutPaymentMethodExternalPayment);
    expect(api.headers['Idempotency-Key'], startsWith('customer-checkout_'));
  });

  test('lottery checkout falls back to wallet for unsupported methods',
      () async {
    final api = _CheckoutApiClient();
    final repository = LotteryRepository(api);

    await repository.checkout(['res_1'], paymentMethod: 'cash');

    expect(api.payload['payment_method'], checkoutPaymentMethodWallet);
  });

  test('lottery release uses idempotency and refreshes server cart', () async {
    final api = _CheckoutApiClient();
    final repository = LotteryRepository(api);

    final cart = await repository.releaseReservation('res_1');

    expect(api.path, '/customer/reservations/res_1/release');
    expect(api.payload, isEmpty);
    expect(
      api.headers['Idempotency-Key'],
      startsWith('customer-reservation-release_'),
    );
    expect(api.getPaths, ['/customer/cart']);
    expect(cart.itemCount, 1);
    expect(cart.reservationIds, ['res_fresh']);
  });
}

class _CheckoutApiClient extends ApiClient {
  _CheckoutApiClient()
      : super(
          const AppConfig(
            apiBaseUrl: 'https://partner.example.test/api/v1',
            defaultLocale: 'th-TH',
          ),
          AuthTokenStore(),
          localeTag: 'th-TH',
        );

  String path = '';
  Map<String, dynamic> payload = {};
  Map<String, String> headers = {};
  final List<String> getPaths = [];

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? query,
    bool auth = true,
  }) async {
    getPaths.add(path);
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: {
        'result': {
          'reservations': [
            {
              'id': 'res_fresh',
              'game_id': 'game_1',
              'status': 'active',
              'expires_at': '2026-07-01T12:15:00+07:00',
              'items': [
                {
                  'id': 'stock_1',
                  'local_stock_item_id': 'stock_1',
                  'full_number': '273707',
                  'price': {'amount': 8000, 'currency': 'THB'},
                },
              ],
              'total': {'amount': 8000, 'currency': 'THB'},
            },
          ],
          'item_count': 1,
          'total': {'amount': 8000, 'currency': 'THB'},
          'server_time': '2026-07-01T12:00:00+07:00',
        },
      } as T,
    );
  }

  @override
  Future<Response<T>> postWithHeaders<T>(
    String path, {
    Object? data,
    bool auth = true,
    Map<String, String> headers = const {},
  }) async {
    this.path = path;
    payload = Map<String, dynamic>.from(data! as Map);
    this.headers = Map<String, String>.from(headers);

    if (path == '/customer/reservations') {
      return Response<T>(
        requestOptions: RequestOptions(path: path),
        data: {
          'id': 'res_1',
          'game_id': payload['game_id'],
          'status': 'active',
          'expires_at': '2026-07-01T12:15:00+07:00',
          'items': [
            {
              'id': 'local_stock_1',
              'stock_ref': payload['local_stock_item_ids'].first,
              'full_number': '273707',
              'price': {'amount': 8000, 'currency': 'THB'},
            },
          ],
          'total': {'amount': 8000, 'currency': 'THB'},
        } as T,
      );
    }

    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: {
        'result': {
          'order': {
            'id': 'ord_1',
            'reference': 'ORDER-1',
            'status': 'paid',
            'payment_status': 'paid',
            'payment_method': payload['payment_method'],
            'total': {'amount': 8000, 'currency': 'THB'},
            'ticket_count': 1,
          },
        },
      } as T,
    );
  }
}
