import 'package:customer_flutter/core/auth/auth_token_store.dart';
import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/network/api_client.dart';
import 'package:customer_flutter/features/purchase_history/data/purchase_history_models.dart';
import 'package:customer_flutter/features/purchase_history/data/purchase_history_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy order history wrappers preserve rows and pagination', () {
    final page = PurchaseHistoryPage.fromJson({
      'result': {
        'orders': [
          {
            'id': 'order_2',
            'total': 160,
            'ticket_count': 2,
            'game': {'draw_at': '2026-07-16T09:00:00+07:00'},
          },
        ],
        'pagination': {'current_page': 2, 'last_page': 4},
      },
    });

    expect(page.items, hasLength(1));
    expect(page.items.single.id, 'order_2');
    expect(page.items.single.ticketCount, 2);
    expect(page.currentPage, 2);
    expect(page.lastPage, 4);
  });

  test('order history accepts production camelCase page metadata', () {
    final page = PurchaseHistoryPage.fromJson({
      'payload': {
        'histories': [
          {
            'orderId': 'order_camel',
            'amount': 80,
            'ticketCount': 1,
          },
        ],
        'pagination': {
          'currentPage': 2,
          'totalPages': 5,
        },
      },
    });

    expect(page.items.single.id, 'order_camel');
    expect(page.currentPage, 2);
    expect(page.lastPage, 5);
    expect(page.hasMore, isTrue);
  });

  test('receipt wrappers merge receipt totals into nested order', () {
    final order = PurchaseHistoryOrder.fromJson({
      'data': {
        'receipt': {
          'count': 3,
          'total': 240,
          'reference': 'PAY-1234567890',
          'order': {
            'id': 'order_3',
            'payment_method': 'wallet',
            'wallet': {'name': 'Customer Wallet'},
            'lotteries': [
              {
                'id': 'ticket_1',
                'full_number': '123456',
                'game': {'name': '16 กรกฎาคม 2569'},
              },
            ],
          },
        },
      },
    });

    expect(order.id, 'order_3');
    expect(order.total, 240);
    expect(order.ticketCount, 3);
    expect(order.reference, 'PAY-1234567890');
    expect(order.walletName, 'Customer Wallet');
  });

  test(
      'receipt parser preserves runtime wallet identity and object scalar aliases',
      () {
    final order = PurchaseHistoryOrder.fromJson({
      'data': {
        'receipt': {
          'purchaseOrder': {
            'orderId': {'value': 'order_runtime'},
            'paymentMethod': {'code': 'wallet'},
            'grandTotal': {'amount': 16000, 'currency': 'THB'},
            'ticketCount': {'value': 2},
            'customerTickets': [
              {
                'id': {'value': 'ticket_runtime'},
                'number': {'value': '123456'},
              },
            ],
          },
          'primaryWallet': {
            'walletId': {'value': 'wallet_0061234567891244'},
            'displayName': {'value': 'Runtime Wallet'},
          },
          'lotteryGame': {
            'displayName': {'value': 'Runtime Draw'},
            'drawAt': {'value': '2026-07-16T16:00:00+07:00'},
          },
          'paymentChannel': {
            'displayName': {'value': 'Runtime Provider'},
          },
          'seller': {
            'displayName': {'value': 'Runtime Store'},
          },
          'referenceCode': {'value': 'ORDER-RUNTIME'},
        },
      },
    });

    expect(order.id, 'order_runtime');
    expect(order.total, 160);
    expect(order.ticketCount, 2);
    expect(order.tickets.single.number, '123456');
    expect(order.walletId, 'wallet_0061234567891244');
    expect(order.walletName, 'Runtime Wallet');
    expect(order.gameName, 'Runtime Draw');
    expect(order.drawAt, '2026-07-16T16:00:00+07:00');
    expect(order.paymentProvider, 'Runtime Provider');
    expect(order.storeName, 'Runtime Store');
    expect(order.reference, 'ORDER-RUNTIME');
    expect(order.maskedPaymentReference, '006 XXXXXXXXX 1244');
  });

  test('receipt reference fallback matches Nuxt for missing identity', () {
    final order = PurchaseHistoryOrder.fromJson(const {});

    expect(order.displayReference, '-');
    expect(order.walletName, isEmpty);
    expect(order.maskedPaymentReference, isEmpty);
  });

  test('repository encodes detail id and preserves list query', () async {
    final api = _PurchaseHistoryApiClient();
    final repository = PurchaseHistoryRepository(api);

    final page = await repository.list(page: 3, perPage: 12);
    final detail = await repository.detail('order/with space');

    expect(page.items.single.id, 'order_1');
    expect(api.listQuery, {'page': 3, 'per_page': 12});
    expect(api.detailPath, '/customer/orders/order%2Fwith%20space');
    expect(detail.id, 'order_1');
  });
}

class _PurchaseHistoryApiClient extends ApiClient {
  _PurchaseHistoryApiClient()
      : super(
          const AppConfig(
            apiBaseUrl: 'https://partner.example.test/api/v1',
            defaultLocale: 'th-TH',
          ),
          AuthTokenStore(),
          localeTag: 'th-TH',
        );

  Map<String, dynamic> listQuery = {};
  String detailPath = '';

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? query,
    bool auth = true,
  }) async {
    if (path == '/customer/orders') {
      listQuery = Map<String, dynamic>.from(query ?? const {});
    } else {
      detailPath = path;
    }
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: {
        if (path == '/customer/orders')
          'data': [_orderPayload()]
        else
          'data': _orderPayload(),
        if (path == '/customer/orders')
          'meta': {'current_page': 3, 'last_page': 3},
      } as T,
    );
  }

  Map<String, dynamic> _orderPayload() => {
        'id': 'order_1',
        'reference': 'ORDER-1',
        'total': 80,
        'ticket_count': 1,
        'payment_method': 'wallet',
        'wallet': {'name': 'G Wallet'},
      };
}
