import 'package:customer_flutter/core/auth/auth_token_store.dart';
import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/i18n/customer_localizations.dart';
import 'package:customer_flutter/core/network/api_client.dart';
import 'package:customer_flutter/features/wallet/data/wallet_repository.dart';
import 'package:customer_flutter/features/wallet/presentation/wallet_localization.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('summary preserves API message when ledger load fails', () async {
    final api = _WalletApiClient(
      ledgerError: _apiException('ระบบประวัติกระเป๋าปิดปรับปรุง'),
    );
    final repository = WalletRepository(api);

    final summary = await repository.summary();

    expect(summary.balance, 2240);
    expect(summary.customerNo, 'CUS001234');
    expect(summary.ledger, isEmpty);
    expect(summary.ledgerLoadFailed, isTrue);
    expect(summary.ledgerErrorMessage, 'ระบบประวัติกระเป๋าปิดปรับปรุง');
    expect(summary.customerNo, 'CUS001234');
    expect(api.paths, ['/customer/wallet', '/customer/wallet/ledger']);
  });

  test('summary hides internal ledger errors behind localized UI fallback',
      () async {
    final api = _WalletApiClient(
      ledgerError: StateError('internal ledger parser failed'),
    );
    final repository = WalletRepository(api);

    final summary = await repository.summary();

    expect(summary.balance, 2240);
    expect(summary.ledger, isEmpty);
    expect(summary.ledgerLoadFailed, isTrue);
    expect(summary.ledgerErrorMessage, isEmpty);
  });

  test('summary maps wrapped wallet and ledger payload aliases', () async {
    final api = _WrappedWalletApiClient();
    final repository = WalletRepository(api);

    final summary = await repository.summary();

    expect(summary.customerNo, 'CUS-WRAPPED-ID');
    expect(summary.balance, 1500);
    expect(summary.primaryWallet?.id, 'wallet_wrapped');
    expect(summary.primaryWallet?.name, 'Runtime Wallet');
    expect(summary.ledgerLoadFailed, isFalse);
    expect(summary.ledger.single.id, 'ledger_wrapped');
    expect(summary.ledger.single.referenceType, 'order');
    expect(summary.ledger.single.referenceId, 'ord_wrapped');
    expect(summary.ledger.single.reason, 'ชำระค่าสลาก wrapper');
    expect(summary.ledger.single.amount, -80);
    expect(summary.ledger.single.balanceAfter, 1420);
    expect(summary.ledger.single.createdAt, '2026-07-01T10:30:00+07:00');
    expect(api.paths, ['/customer/wallet', '/customer/wallet/ledger']);
  });

  test('summary maps recursive wallet and ledger page wrappers', () async {
    final api = _PagedWalletApiClient();
    final repository = WalletRepository(api);

    final summary = await repository.summary();

    expect(summary.customerNo, 'CUS-PAGED-ID');
    expect(summary.balance, 1880);
    expect(summary.primaryWallet?.id, 'wallet_paged');
    expect(summary.primaryWallet?.name, 'Paged Wallet');
    expect(summary.ledgerLoadFailed, isFalse);
    expect(summary.ledger.single.id, 'ledger_paged');
    expect(summary.ledger.single.referenceType, 'topup');
    expect(summary.ledger.single.referenceId, 'top_paged');
    expect(summary.ledger.single.amount, 500);
    expect(summary.ledger.single.balanceAfter, 1880);
    expect(summary.ledger.single.createdAt, '2026-07-01T11:30:00+07:00');
    expect(api.paths, ['/customer/wallet', '/customer/wallet/ledger']);
  });

  test('summary maps wallet transaction history details and label aliases',
      () async {
    final api = _NestedWalletTransactionApiClient();
    final repository = WalletRepository(api);

    final summary = await repository.summary();

    expect(summary.balance, 2120);
    expect(summary.ledger, hasLength(3));

    final order = summary.ledger.first;
    expect(order.id, 'txn_nested_order');
    expect(order.entryType, 'out-flow');
    expect(order.referenceType, 'order');
    expect(order.referenceId, 'ORD-NESTED');
    expect(order.reason, 'ชำระค่าสลากจากรายละเอียด');
    expect(order.amount, -120);
    expect(order.balanceAfter, 2120);
    expect(
      walletLedgerTitle(CustomerLocalizations.fallback, order),
      'ชำระค่าสลากดิจิทัล',
    );

    final reward = summary.ledger[1];
    expect(reward.id, 'txn_nested_reward');
    expect(reward.referenceType, 'rewardClaim');
    expect(reward.referenceId, 'CLAIM-NESTED');
    expect(reward.amount, 350);
    expect(reward.balanceAfter, 2470);
    expect(
      walletLedgerTitle(CustomerLocalizations.fallback, reward),
      'รับเงินรางวัลสลากฯ',
    );

    final cashback = summary.ledger.last;
    expect(cashback.id, 'txn_nested_activity_cashback');
    expect(cashback.referenceType, 'activityClaim');
    expect(cashback.reason, 'เงินคืนกิจกรรมจากแคมเปญ');
    expect(cashback.amount, 45);
    expect(
      walletLedgerTitle(CustomerLocalizations.fallback, cashback),
      'เงินคืนกิจกรรม',
    );
  });
}

class _WalletApiClient extends ApiClient {
  _WalletApiClient({required this.ledgerError})
      : super(
          const AppConfig(
            apiBaseUrl: 'https://partner.example.test/api/v1',
            defaultLocale: 'th-TH',
          ),
          AuthTokenStore(),
          localeTag: 'th-TH',
        );

  final Object ledgerError;
  final paths = <String>[];

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? query,
    bool auth = true,
  }) async {
    paths.add(path);
    if (path == '/customer/wallet/ledger') throw ledgerError;

    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: {
        'data': [
          {
            'id': 'wallet_1',
            'name': 'G Wallet',
            'type': 'primary',
            'balance': {'amount': 224000, 'currency': 'THB'},
          },
        ],
        'customer_no': {'value': 'CUS001234'},
      } as T,
    );
  }
}

class _WrappedWalletApiClient extends ApiClient {
  _WrappedWalletApiClient()
      : super(
          const AppConfig(
            apiBaseUrl: 'https://partner.example.test/api/v1',
            defaultLocale: 'th-TH',
          ),
          AuthTokenStore(),
          localeTag: 'th-TH',
        );

  final paths = <String>[];

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? query,
    bool auth = true,
  }) async {
    paths.add(path);
    if (path == '/customer/wallet/ledger') {
      return Response<T>(
        requestOptions: RequestOptions(path: path),
        data: {
          'data': {
            'resource': {
              'transactions': [
                {
                  'memo': 'ชำระค่าสลาก wrapper',
                  'result': {
                    'transaction': {
                      'transactionId': 'ledger_wrapped',
                      'entryType': 'debit',
                      'referenceType': 'order',
                      'referenceId': 'ord_wrapped',
                      'transactionAmount': {
                        'amount': 8000,
                        'currency': 'THB',
                      },
                      'balanceAfter': {'amount': 142000, 'currency': 'THB'},
                      'postedAt': '2026-07-01T10:30:00+07:00',
                    },
                  },
                },
              ],
            },
          },
        } as T,
      );
    }

    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: {
        'data': {
          'resource': {
            'wallets': [
              {
                'walletName': 'Runtime Wallet',
                'result': {
                  'primaryWallet': {
                    'walletId': 'wallet_wrapped',
                    'walletType': 'primary',
                    'availableBalance': {
                      'amount': 150000,
                      'currency': 'THB',
                    },
                  },
                },
              },
            ],
            'user': {'id': 'CUS-WRAPPED-ID'},
          },
        },
      } as T,
    );
  }
}

class _PagedWalletApiClient extends ApiClient {
  _PagedWalletApiClient()
      : super(
          const AppConfig(
            apiBaseUrl: 'https://partner.example.test/api/v1',
            defaultLocale: 'th-TH',
          ),
          AuthTokenStore(),
          localeTag: 'th-TH',
        );

  final paths = <String>[];

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? query,
    bool auth = true,
  }) async {
    paths.add(path);
    if (path == '/customer/wallet/ledger') {
      return Response<T>(
        requestOptions: RequestOptions(path: path),
        data: {
          'data': {
            'resource': {
              'walletLedgerPage': {
                'transactions': [
                  {
                    'transactionId': 'ledger_paged',
                    'entryType': 'credit',
                    'referenceType': 'topup',
                    'referenceId': 'top_paged',
                    'transactionAmount': {
                      'amount': 50000,
                      'currency': 'THB',
                    },
                    'balanceAfter': {'amount': 188000, 'currency': 'THB'},
                    'postedAt': '2026-07-01T11:30:00+07:00',
                  },
                ],
              },
            },
          },
        } as T,
      );
    }

    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: {
        'data': {
          'resource': {
            'walletPage': {
              'wallets': [
                {
                  'walletId': 'wallet_paged',
                  'walletName': 'Paged Wallet',
                  'walletType': 'primary',
                  'availableBalance': {
                    'amount': 188000,
                    'currency': 'THB',
                  },
                },
              ],
            },
            'customer': {'id': 'CUS-PAGED-ID'},
          },
        },
      } as T,
    );
  }
}

class _NestedWalletTransactionApiClient extends ApiClient {
  _NestedWalletTransactionApiClient()
      : super(
          const AppConfig(
            apiBaseUrl: 'https://partner.example.test/api/v1',
            defaultLocale: 'th-TH',
          ),
          AuthTokenStore(),
          localeTag: 'th-TH',
        );

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? query,
    bool auth = true,
  }) async {
    if (path == '/customer/wallet/ledger') {
      return Response<T>(
        requestOptions: RequestOptions(path: path),
        data: {
          'data': {
            'resource': {
              'walletTransactionsPage': {
                'history': [
                  {
                    'walletTransactionId': 'txn_nested_order',
                    'flowType': 'out-flow',
                    'grossAmount': {'amount': 12000, 'currency': 'THB'},
                    'createdAt': '2026-07-02T09:00:00+07:00',
                    'details': {
                      'description': 'ชำระค่าสลากจากรายละเอียด',
                      'balanceAfter': {'amount': 212000, 'currency': 'THB'},
                      'reference': {'type': 'order', 'id': 'ORD-NESTED'},
                    },
                  },
                  {
                    'walletTransactionId': 'txn_nested_reward',
                    'amount': {'amount': 35000, 'currency': 'THB'},
                    'postedAt': '2026-07-02T10:00:00+07:00',
                    'details': {
                      'title': 'รับเงินรางวัลจาก claim',
                      'balanceAfter': {'amount': 247000, 'currency': 'THB'},
                      'reference': {
                        'type': 'rewardClaim',
                        'id': 'CLAIM-NESTED',
                      },
                    },
                  },
                  {
                    'walletTransactionId': 'txn_nested_activity_cashback',
                    'amount': {'amount': 4500, 'currency': 'THB'},
                    'createdAt': '2026-07-02T11:00:00+07:00',
                    'details': {
                      'title': 'เงินคืนกิจกรรมจากแคมเปญ',
                      'balanceAfter': {'amount': 251500, 'currency': 'THB'},
                      'reference': {
                        'type': 'activityClaim',
                        'id': 'ACT-CLAIM-NESTED',
                      },
                    },
                  },
                ],
              },
            },
          },
        } as T,
      );
    }

    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: {
        'data': {
          'wallet': {
            'walletId': 'wallet_nested',
            'walletType': 'primary',
            'currentBalance': {'amount': 212000, 'currency': 'THB'},
          },
          'customer': {'customerNo': 'CUS-NESTED'},
        },
      } as T,
    );
  }
}

DioException _apiException(String message) {
  final requestOptions = RequestOptions(path: '/customer/wallet/ledger');
  return DioException(
    requestOptions: requestOptions,
    response: Response<Map<String, dynamic>>(
      requestOptions: requestOptions,
      statusCode: 503,
      data: {'message': message},
    ),
    type: DioExceptionType.badResponse,
  );
}
