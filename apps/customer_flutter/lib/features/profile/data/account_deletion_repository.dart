import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/api_payload.dart';
import '../../../core/utils/idempotency_key.dart';
import '../../../core/utils/provider_cache.dart';

final accountDeletionRepositoryProvider = Provider<AccountDeletionRepository>((
  ref,
) {
  return AccountDeletionRepository(ref.watch(apiClientProvider));
});

final accountDeletionStatusProvider =
    FutureProvider.autoDispose<AccountDeletionStatus>((ref) async {
      ref.keepForCustomerNavigation(duration: const Duration(seconds: 30));
      return ref.watch(accountDeletionRepositoryProvider).load();
    });

class AccountDeletionRepository {
  const AccountDeletionRepository(this._api);

  final ApiClient _api;

  Future<AccountDeletionStatus> load() async {
    final response = await _api.get<Map<String, dynamic>>(
      '/customer/account-deletion',
    );
    return AccountDeletionStatus.fromJson(unwrapPayload(response.data));
  }

  Future<DeletionOtpRequest> requestOtp(String pin) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/customer/account-deletion/request-otp',
      data: {'pin': pin},
    );
    return DeletionOtpRequest.fromJson(unwrapPayload(response.data));
  }

  Future<String> verifyOtp(String otp) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/customer/account-deletion/verify-otp',
      data: {'otp': otp},
    );
    return (unwrapPayload(response.data)['otp_verification_token'] ?? '')
        .toString();
  }

  Future<AccountDeletionRequest> create({
    required String reasonCode,
    required String reasonDetail,
    required String pinVerificationToken,
    required String otpVerificationToken,
  }) async {
    final response = await _api.postWithHeaders<Map<String, dynamic>>(
      '/customer/account-deletion',
      headers: {'Idempotency-Key': newIdempotencyKey('account_deletion')},
      data: {
        'reason_code': reasonCode,
        'reason_detail': reasonDetail,
        'pin_verification_token': pinVerificationToken,
        'otp_verification_token': otpVerificationToken,
      },
    );
    return AccountDeletionRequest.fromJson(unwrapPayload(response.data));
  }

  Future<AccountDeletionRequest> cancel(String pin) async {
    final response = await _api.postWithHeaders<Map<String, dynamic>>(
      '/customer/account-deletion/cancel',
      headers: {
        'Idempotency-Key': newIdempotencyKey('account_deletion_cancel'),
      },
      data: {'pin': pin},
    );
    return AccountDeletionRequest.fromJson(unwrapPayload(response.data));
  }
}

class AccountDeletionStatus {
  const AccountDeletionStatus({
    required this.request,
    required this.eligible,
    required this.blockers,
  });

  final AccountDeletionRequest? request;
  final bool eligible;
  final List<AccountDeletionBlocker> blockers;

  factory AccountDeletionStatus.fromJson(Map<String, dynamic> json) {
    final eligibility = asMap(json['eligibility']);
    final requestJson = asMap(json['request']);
    return AccountDeletionStatus(
      request: requestJson.isEmpty
          ? null
          : AccountDeletionRequest.fromJson(requestJson),
      eligible: eligibility['eligible'] == true,
      blockers: asMapList(
        eligibility['blockers'],
      ).map(AccountDeletionBlocker.fromJson).toList(growable: false),
    );
  }
}

class AccountDeletionRequest {
  const AccountDeletionRequest({
    required this.id,
    required this.status,
    required this.reasonCode,
    required this.scheduledFor,
    required this.remainingSeconds,
    required this.blockers,
    required this.readOnly,
  });

  final String id;
  final String status;
  final String reasonCode;
  final DateTime? scheduledFor;
  final int remainingSeconds;
  final List<AccountDeletionBlocker> blockers;
  final bool readOnly;

  bool get isOpen => status == 'pending' || status == 'blocked';

  factory AccountDeletionRequest.fromJson(Map<String, dynamic> json) {
    return AccountDeletionRequest(
      id: (json['id'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      reasonCode: (json['reason_code'] ?? '').toString(),
      scheduledFor: DateTime.tryParse((json['scheduled_for'] ?? '').toString()),
      remainingSeconds:
          int.tryParse((json['remaining_seconds'] ?? 0).toString()) ?? 0,
      blockers: asMapList(
        json['blockers'],
      ).map(AccountDeletionBlocker.fromJson).toList(growable: false),
      readOnly: json['read_only'] == true,
    );
  }
}

class AccountDeletionBlocker {
  const AccountDeletionBlocker({
    required this.code,
    required this.routeKey,
    required this.details,
  });

  final String code;
  final String routeKey;
  final Map<String, dynamic> details;

  factory AccountDeletionBlocker.fromJson(Map<String, dynamic> json) {
    return AccountDeletionBlocker(
      code: (json['code'] ?? '').toString(),
      routeKey: (json['route_key'] ?? '').toString(),
      details: asMap(json['details']),
    );
  }
}

class DeletionOtpRequest {
  const DeletionOtpRequest({
    required this.pinVerificationToken,
    required this.phoneMasked,
    required this.retryAfterSeconds,
  });

  final String pinVerificationToken;
  final String phoneMasked;
  final int retryAfterSeconds;

  factory DeletionOtpRequest.fromJson(Map<String, dynamic> json) {
    return DeletionOtpRequest(
      pinVerificationToken: (json['pin_verification_token'] ?? '').toString(),
      phoneMasked: (json['phone_masked'] ?? json['phoneMasked'] ?? '')
          .toString(),
      retryAfterSeconds:
          int.tryParse((json['retry_after_seconds'] ?? 60).toString()) ?? 60,
    );
  }
}
