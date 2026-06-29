import 'package:customer_flutter/core/auth/auth_token_store.dart';
import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/network/api_client.dart';
import 'package:customer_flutter/features/activity_claims/data/activity_claim_models.dart';
import 'package:customer_flutter/features/activity_claims/data/activity_claim_repository.dart';
import 'package:customer_flutter/features/profile/data/profile_settings_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('create sends PIN confirmation when provided', () async {
    final api = _ActivityClaimApiClient();
    final repository = ActivityClaimRepository(api);

    await repository.create(
      awardId: 'award_1',
      payoutMethod: ActivityClaimPayoutMethod.bankTransfer,
      pin: '123456',
      bankAccount: const RewardBankAccount(
        bankName: 'Kasikorn',
        accountNumber: '1234567890',
        accountName: 'Demo Customer',
      ),
    );

    expect(api.path, '/customer/activity-claims');
    expect(api.payload['award_id'], 'award_1');
    expect(api.payload['payout_method'], 'bank_transfer');
    expect(api.payload['pin'], '123456');
    expect(api.payload.containsKey('pin_assertion_token'), isFalse);
    expect(api.payload['bank_account'], containsPair('bank_name', 'Kasikorn'));
  });

  test('create can use biometric assertion token instead of PIN', () async {
    final api = _ActivityClaimApiClient();
    final repository = ActivityClaimRepository(api);

    await repository.create(
      awardId: 'award_1',
      payoutMethod: ActivityClaimPayoutMethod.walletCredit,
      pin: '123456',
      pinAssertionToken: 'assertion-token',
    );

    expect(api.payload.containsKey('pin'), isFalse);
    expect(api.payload['pin_assertion_token'], 'assertion-token');
  });
}

class _ActivityClaimApiClient extends ApiClient {
  _ActivityClaimApiClient()
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
          'id': 'activity_claim_1',
          'reference': 'ACL-001',
          'status': 'submitted',
          'payout_method': payload['payout_method'],
          'amount': {'amount': 50000, 'currency': 'THB'},
          'award': {
            'id': payload['award_id'],
            'activity_name': 'Lucky board',
            'type': 'lucky_board',
            'amount': {'amount': 50000, 'currency': 'THB'},
          },
        },
      } as T,
    );
  }
}
