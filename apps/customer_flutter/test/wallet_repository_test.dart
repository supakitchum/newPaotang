import 'package:customer_flutter/core/auth/auth_token_store.dart';
import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/network/api_client.dart';
import 'package:customer_flutter/features/wallet/data/wallet_repository.dart';
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
    expect(summary.ledger, isEmpty);
    expect(summary.ledgerLoadFailed, isTrue);
    expect(summary.ledgerErrorMessage, 'ระบบประวัติกระเป๋าปิดปรับปรุง');
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
