import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/api_payload.dart';
import '../../../core/utils/idempotency_key.dart';
import 'profile_settings_models.dart';

final profileSettingsRepositoryProvider =
    Provider<ProfileSettingsRepository>((ref) {
  return ProfileSettingsRepository(ref.watch(apiClientProvider));
});

final customerProfileSettingsProvider =
    FutureProvider.autoDispose<CustomerProfileSettings>((ref) async {
  return ref.watch(profileSettingsRepositoryProvider).load();
});

class ProfileSettingsRepository {
  const ProfileSettingsRepository(this._api);

  final ApiClient _api;

  Future<CustomerProfileSettings> load() async {
    final response = await _api.get<Map<String, dynamic>>('/customer/profile');
    return CustomerProfileSettings.fromJson(unwrapPayload(response.data));
  }

  Future<CustomerProfileSettings> saveRewardBank({
    required RewardBankAccount bankAccount,
    String pin = '',
    String pinAssertionToken = '',
  }) async {
    final response = await _api.patchWithHeaders<Map<String, dynamic>>(
      '/customer/profile',
      headers: {'Idempotency-Key': newIdempotencyKey('customer_profile_bank')},
      data: {
        'reward_payout_bank_account': bankAccount.toJson(),
        if (pinAssertionToken.isNotEmpty)
          'pin_assertion_token': pinAssertionToken
        else
          'pin': pin,
      },
    );
    return CustomerProfileSettings.fromJson(unwrapPayload(response.data));
  }

  Future<CustomerProfileSettings> saveAutoReward({
    required bool enabled,
    required String payoutMethod,
    String pin = '',
    String pinAssertionToken = '',
  }) async {
    final response = await _api.patchWithHeaders<Map<String, dynamic>>(
      '/customer/profile',
      headers: {'Idempotency-Key': newIdempotencyKey('customer_profile_auto')},
      data: {
        'auto_reward_claim': {
          'enabled': enabled,
          'type': payoutMethod,
          'payout_method': payoutMethod == 'bank_transfer'
              ? 'bank_transfer'
              : 'wallet_credit',
        },
        if (pinAssertionToken.isNotEmpty)
          'pin_assertion_token': pinAssertionToken
        else if (pin.isNotEmpty)
          'pin': pin,
      },
    );
    return CustomerProfileSettings.fromJson(unwrapPayload(response.data));
  }

  Future<CustomerProfileSettings> savePreferredLocale(String localeTag) async {
    final response = await _api.patchWithHeaders<Map<String, dynamic>>(
      '/customer/profile',
      headers: {
        'Idempotency-Key': newIdempotencyKey('customer_profile_locale'),
      },
      data: {'preferred_locale': localeTag},
    );
    return CustomerProfileSettings.fromJson(unwrapPayload(response.data));
  }
}
