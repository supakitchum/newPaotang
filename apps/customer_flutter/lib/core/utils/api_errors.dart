import 'package:dio/dio.dart';

import 'api_payload.dart';

class ApiErrorInfo {
  const ApiErrorInfo({
    required this.code,
    required this.message,
    required this.details,
  });

  factory ApiErrorInfo.fromObject(Object? error) {
    final data = error is DioException ? error.response?.data : error;
    final payload = asMap(data);
    final errorPayload = asMap(payload['error']);
    final details = asMap(errorPayload['details']);
    return ApiErrorInfo(
      code: errorPayload['code']?.toString() ?? '',
      message: errorPayload['message']?.toString() ??
          payload['message']?.toString() ??
          '',
      details: details,
    );
  }

  final String code;
  final String message;
  final Map<String, dynamic> details;

  bool get isSmsOtpProviderNotConfigured =>
      code == 'sms_otp_provider_not_configured';

  bool get providerRequired => details['provider_required'] == true;

  bool get isOptionalSmsOtpProviderMissing =>
      isSmsOtpProviderNotConfigured && !providerRequired;

  bool get isCustomerSuspended => code == 'customer_suspended';
  bool get isMaintenanceActive => code == 'maintenance_active';
  bool get isPinRequired =>
      code == 'pin_required' || code == 'pin_setup_required';

  Map<String, dynamic> get suspension {
    final nested = asMap(details['suspension']);
    return nested.isEmpty ? details : nested;
  }

  String? get operationalRedirectPath {
    if (isMaintenanceActive) return '/maintenance';
    if (isPinRequired) return '/pin';
    if (isCustomerSuspended) return customerSuspendedPath;
    return null;
  }

  String get customerSuspendedPath {
    final data = suspension;
    return Uri(
      path: '/account-suspended',
      queryParameters: {
        if ((data['reason']?.toString() ?? '').trim().isNotEmpty)
          'reason': data['reason'].toString(),
        if ((data['suspended_until']?.toString() ?? '').trim().isNotEmpty)
          'suspended_until': data['suspended_until'].toString(),
        if (data['is_permanent'] == true) 'permanent': '1',
      },
    ).toString();
  }
}
