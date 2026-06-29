import 'package:customer_flutter/core/auth/auth_token_store.dart';
import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/network/api_client.dart';
import 'package:customer_flutter/features/affiliate/data/affiliate_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('commissions requests cursor pagination endpoint', () async {
    final api = _AffiliateApiClient();
    final repository = AffiliateRepository(api);

    final page = await repository.commissions(cursor: 'com_100', limit: 12);

    expect(api.path, '/customer/affiliate/commissions');
    expect(api.query, {'limit': 12, 'cursor': 'com_100'});
    expect(page.hasMore, isTrue);
    expect(page.nextCursor, 'com_200');
    expect(page.items, hasLength(1));
    expect(page.items.single.id, 'com_101');
    expect(page.items.single.orderId, 'ord_001');
    expect(page.items.single.amount, 25);
  });

  test('payouts requests cursor pagination endpoint', () async {
    final api = _AffiliateApiClient();
    final repository = AffiliateRepository(api);

    final page = await repository.payouts(limit: 8);

    expect(api.path, '/customer/affiliate/payouts');
    expect(api.query, {'limit': 8});
    expect(page.hasMore, isFalse);
    expect(page.nextCursor, '');
    expect(page.items, hasLength(1));
    expect(page.items.single.id, 'pay_101');
    expect(page.items.single.payoutMethod, 'wallet_credit');
    expect(page.items.single.amount, 300);
  });

  test('createPayout sends PIN confirmation when provided', () async {
    final api = _AffiliateApiClient();
    final repository = AffiliateRepository(api);

    await repository.createPayout(
      amount: 1200,
      payoutMethod: 'bank_transfer',
      pin: '123456',
      bankAccount: {'bank_code': 'kbank'},
    );

    expect(api.path, '/customer/affiliate/payouts');
    expect(api.payload['amount'], {'amount': 120000, 'currency': 'THB'});
    expect(api.payload['payout_method'], 'bank_transfer');
    expect(api.payload['pin'], '123456');
    expect(api.payload.containsKey('pin_assertion_token'), isFalse);
    expect(api.payload['bank_account'], {'bank_code': 'kbank'});
  });

  test('createPayout prefers biometric assertion token over PIN', () async {
    final api = _AffiliateApiClient();
    final repository = AffiliateRepository(api);

    await repository.createPayout(
      amount: 850,
      payoutMethod: 'wallet_credit',
      pin: '123456',
      pinAssertionToken: 'assertion-token',
    );

    expect(api.path, '/customer/affiliate/payouts');
    expect(api.payload.containsKey('pin'), isFalse);
    expect(api.payload['pin_assertion_token'], 'assertion-token');
  });
}

class _AffiliateApiClient extends ApiClient {
  _AffiliateApiClient()
      : super(
          const AppConfig(
            apiBaseUrl: 'https://partner.example.test/api/v1',
            defaultLocale: 'th-TH',
          ),
          AuthTokenStore(),
          localeTag: 'th-TH',
        );

  String path = '';
  Map<String, dynamic> query = {};
  Map<String, dynamic> payload = {};

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? query,
    bool auth = true,
  }) async {
    this.path = path;
    this.query = Map<String, dynamic>.from(query ?? {});

    final payload = path.endsWith('/commissions')
        ? {
            'data': [
              {
                'id': 'com_101',
                'order_id': 'ord_001',
                'status': 'approved',
                'amount': {'amount': 2500, 'currency': 'THB'},
                'calculated_at': '2026-06-26T09:00:00+07:00',
              },
            ],
            'meta': {'next_cursor': 'com_200', 'has_more': true},
          }
        : {
            'data': [
              {
                'id': 'pay_101',
                'status': 'pending',
                'payout_method': 'wallet_credit',
                'amount': {'amount': 30000, 'currency': 'THB'},
                'created_at': '2026-06-26T10:00:00+07:00',
              },
            ],
            'meta': {'next_cursor': null, 'has_more': false},
          };

    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: payload as T,
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

    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: {
        'data': {
          'id': 'pay_created',
          'status': 'pending',
          'payout_method': payload['payout_method'],
          'amount': payload['amount'],
          'created_at': '2026-06-26T10:10:00+07:00',
        },
      } as T,
    );
  }
}
