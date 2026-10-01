import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';
import '../utils/api_payload.dart';
import 'auth_repository.dart';

final customerSocialAccountRepositoryProvider =
    Provider<CustomerSocialAccountRepository>((ref) {
      return CustomerSocialAccountRepository(api: ref.watch(apiClientProvider));
    });

final customerSocialAccountsProvider =
    FutureProvider.autoDispose<List<CustomerSocialAccount>>((ref) {
      return ref.watch(customerSocialAccountRepositoryProvider).list();
    });

class CustomerSocialAccountRepository {
  const CustomerSocialAccountRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;

  Future<List<CustomerSocialAccount>> list() async {
    final response = await _api.get<Map<String, dynamic>>(
      '/customer/auth/social/accounts',
    );
    return _accountRows(response.data)
        .map(CustomerSocialAccount.fromJson)
        .where((account) => account.provider.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<CustomerSocialAccount>> unlink(String provider) async {
    final normalized = normalizeSocialAuthProvider(provider);
    if (normalized.isEmpty) {
      throw const FormatException('Social provider is required.');
    }
    final response = await _api.deleteWithHeaders<Map<String, dynamic>>(
      '/customer/auth/social/accounts/${Uri.encodeComponent(normalized)}',
    );
    return _accountRows(response.data)
        .map(CustomerSocialAccount.fromJson)
        .where((account) => account.provider.isNotEmpty)
        .toList(growable: false);
  }
}

class CustomerSocialAccount {
  const CustomerSocialAccount({
    required this.provider,
    required this.linked,
    required this.displayName,
    required this.email,
    required this.pictureUrl,
    required this.linkedAt,
    required this.lastLoginAt,
  });

  factory CustomerSocialAccount.fromJson(Map<String, dynamic> json) {
    return CustomerSocialAccount(
      provider: normalizeSocialAuthProvider(
        (json['provider'] ?? json['provider_name'] ?? '').toString(),
      ),
      linked: _truthy(json['linked'] ?? json['is_linked']),
      displayName: (json['display_name'] ?? json['displayName'] ?? '')
          .toString()
          .trim(),
      email: (json['email'] ?? '').toString().trim(),
      pictureUrl:
          (json['picture_url'] ??
                  json['pictureUrl'] ??
                  json['avatar_url'] ??
                  json['avatarUrl'] ??
                  '')
              .toString()
              .trim(),
      linkedAt: DateTime.tryParse(
        (json['linked_at'] ?? json['linkedAt'] ?? '').toString(),
      ),
      lastLoginAt: DateTime.tryParse(
        (json['last_login_at'] ?? json['lastLoginAt'] ?? '').toString(),
      ),
    );
  }

  final String provider;
  final bool linked;
  final String displayName;
  final String email;
  final String pictureUrl;
  final DateTime? linkedAt;
  final DateTime? lastLoginAt;
}

List<Map<String, dynamic>> _accountRows(Object? value, [int depth = 0]) {
  if (value is List) return asMapList(value);
  if (depth >= 5) return const [];

  final payload = asMap(value);
  if (payload.isEmpty) return const [];
  for (final key in const [
    'accounts',
    'social_accounts',
    'socialAccounts',
    'items',
    'data',
    'result',
    'resource',
  ]) {
    if (!payload.containsKey(key)) continue;
    final rows = _accountRows(payload[key], depth + 1);
    if (rows.isNotEmpty || payload[key] is List) return rows;
  }
  return const [];
}

bool _truthy(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  return const {
    '1',
    'true',
    'yes',
    'on',
    'linked',
  }.contains(value?.toString().trim().toLowerCase());
}
