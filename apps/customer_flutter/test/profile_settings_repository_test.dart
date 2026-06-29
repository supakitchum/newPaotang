import 'package:customer_flutter/core/auth/auth_token_store.dart';
import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/network/api_client.dart';
import 'package:customer_flutter/features/profile/data/profile_settings_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('saveAutoReward sends PIN for profile update confirmation', () async {
    final api = _CaptureApiClient();
    final repository = ProfileSettingsRepository(api);

    await repository.saveAutoReward(
      enabled: true,
      payoutMethod: 'wallet',
      pin: '123456',
    );

    expect(api.path, '/customer/profile');
    expect(api.payload['pin'], '123456');
    expect(api.payload.containsKey('pin_assertion_token'), isFalse);
    expect(api.payload['auto_reward_claim'], {
      'enabled': true,
      'type': 'wallet',
      'payout_method': 'wallet_credit',
    });
    expect(
      api.headers['Idempotency-Key'],
      startsWith('customer_profile_auto_'),
    );
  });

  test('saveAutoReward prefers biometric assertion token over PIN', () async {
    final api = _CaptureApiClient();
    final repository = ProfileSettingsRepository(api);

    await repository.saveAutoReward(
      enabled: true,
      payoutMethod: 'bank_transfer',
      pin: '123456',
      pinAssertionToken: 'assertion-token',
    );

    expect(api.payload.containsKey('pin'), isFalse);
    expect(api.payload['pin_assertion_token'], 'assertion-token');
    expect(api.payload['auto_reward_claim'], {
      'enabled': true,
      'type': 'bank_transfer',
      'payout_method': 'bank_transfer',
    });
  });
}

class _CaptureApiClient extends ApiClient {
  _CaptureApiClient()
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

  @override
  Future<Response<T>> patchWithHeaders<T>(
    String path, {
    Object? data,
    bool auth = true,
    Map<String, String> headers = const {},
  }) async {
    this.path = path;
    payload = Map<String, dynamic>.from(data as Map);
    this.headers = Map<String, String>.from(headers);
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: {
        'data': {
          'id': 'cus_1',
          'member_no': 'CUS001234',
          'name': 'Demo Customer',
          'phone': '0812345678',
          'reward_payout_bank_account': {},
          'auto_reward_claim': payload['auto_reward_claim'],
        },
      } as T,
    );
  }
}
