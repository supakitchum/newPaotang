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
    expect(
      api.headers['Idempotency-Key'],
      startsWith('customer_activity_claim_'),
    );
  });

  test('create can use biometric assertion token instead of PIN', () async {
    final api = _ActivityClaimApiClient();
    final repository = ActivityClaimRepository(api);

    final claim = await repository.create(
      awardId: 'award_1',
      payoutMethod: ActivityClaimPayoutMethod.walletCredit,
      pin: '123456',
      pinAssertionToken: 'assertion-token',
    );

    expect(api.payload.containsKey('pin'), isFalse);
    expect(api.payload['pin_assertion_token'], 'assertion-token');
    expect(claim.id, 'activity_claim_1');
  });

  test('detail preserves wrapper context around nested claim resources',
      () async {
    final api = _ActivityClaimApiClient();
    final repository = ActivityClaimRepository(api);

    final claim = await repository.detail('acl_wrapped');

    expect(api.paths, ['/customer/activity-claims/acl_wrapped']);
    expect(claim.id, 'acl_wrapped');
    expect(claim.displayReference, 'ACT-WRAPPED');
    expect(claim.customerName, 'ลูกค้ากิจกรรม Wrapper');
    expect(claim.activityName, 'ภารกิจ Wrapper');
    expect(claim.award?.id, 'award_wrapped');
    expect(claim.type, 'cashback');
    expect(claim.amount, 990);
    expect(claim.status, ActivityClaimStatus.paid);
    expect(claim.payoutMethod, 'bank_transfer');
    expect(claim.payoutLedgerId, 'ledger_activity_wrapped');
    expect(claim.bankName, 'ธนาคารกรุงไทย');
    expect(claim.bankAccountNumber, '006123456789');
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
  Map<String, String> headers = {};
  final paths = <String>[];

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? query,
    bool auth = true,
  }) async {
    paths.add(path);

    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: {
        'customerDisplayName': 'ลูกค้ากิจกรรม Wrapper',
        'activityName': 'ภารกิจ Wrapper',
        'award': {
          'activityAwardId': 'award_wrapped',
          'activityName': 'ภารกิจ Wrapper',
          'rewardType': 'cashback',
          'rewardAmount': {'amount': 99000, 'currency': 'THB'},
        },
        'data': {
          'resource': {
            'activityClaimId': 'acl_wrapped',
            'claimReference': 'ACT-WRAPPED',
            'claimStatus': 'claim_paid',
            'payout': {
              'method': 'bankTransfer',
              'ledgerId': 'ledger_activity_wrapped',
              'bankAccount': {
                'bankDisplayName': 'ธนาคารกรุงไทย',
                'bankDepositNo': '006123456789',
              },
            },
            'paidAt': '2026-07-01T11:00:00+07:00',
          },
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
