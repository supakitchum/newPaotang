import 'package:customer_flutter/core/auth/auth_token_store.dart';
import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/network/api_client.dart';
import 'package:customer_flutter/features/reward_claims/data/reward_claim_models.dart';
import 'package:customer_flutter/features/reward_claims/data/reward_claim_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('detail preserves wrapper context around nested claim resources',
      () async {
    final api = _RewardClaimApiClient();
    final repository = RewardClaimRepository(api);

    final claim = await repository.detail('rcl_wrapped');

    expect(api.paths, ['/customer/reward-claims/rcl_wrapped']);
    expect(claim.id, 'rcl_wrapped');
    expect(claim.displayReference, 'RWD-WRAPPED');
    expect(claim.customerName, 'ลูกค้า Wrapper');
    expect(claim.status, RewardClaimStatus.paid);
    expect(claim.payoutMethod, 'bank_transfer');
    expect(claim.payoutLedgerId, 'ledger_wrapped');
    expect(claim.bankName, 'ธนาคารกสิกรไทย');
    expect(claim.bankAccountNumber, '1234567890');
    expect(claim.ticket?.id, 'ticket_wrapped');
    expect(claim.ticket?.number, '987654');
    expect(claim.prizes.single.prizeType, 'front3');
    expect(claim.prizeAmount, 4000);
  });
}

class _RewardClaimApiClient extends ApiClient {
  _RewardClaimApiClient()
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

    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: {
        'customerName': 'ลูกค้า Wrapper',
        'ticketNumber': '987654',
        'gameName': 'งวดวันที่ 1 กรกฎาคม 2569',
        'ticket': {
          'id': 'ticket_wrapped',
          'rewardStatus': {
            'prizes': [
              {
                'rewardType': 'front3',
                'rewardNumber': '123',
                'rewardAmount': {'amount': 400000, 'currency': 'THB'},
              },
            ],
          },
        },
        'data': {
          'resource': {
            'claimId': 'rcl_wrapped',
            'claimReference': 'RWD-WRAPPED',
            'claimStatus': 'claim_paid',
            'payout': {
              'method': 'bankTransfer',
              'ledgerId': 'ledger_wrapped',
              'bankAccount': {
                'bankDisplayName': 'ธนาคารกสิกรไทย',
                'bankDepositNo': '1234567890',
              },
            },
            'paidAt': '2026-07-01T11:00:00+07:00',
          },
        },
      } as T,
    );
  }
}
