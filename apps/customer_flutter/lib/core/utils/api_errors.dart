import 'package:dio/dio.dart';

import 'api_payload.dart';

class ApiErrorInfo {
  const ApiErrorInfo({
    required this.code,
    required this.message,
    required this.details,
    this.statusCode,
  });

  factory ApiErrorInfo.fromObject(Object? error) {
    final statusCode =
        error is DioException ? error.response?.statusCode : null;
    final data = error is DioException ? error.response?.data : error;
    final payload = asMap(data);
    if (payload.isEmpty) {
      return ApiErrorInfo(
        code: '',
        message: data?.toString() ?? '',
        details: const <String, dynamic>{},
        statusCode: statusCode,
      );
    }

    final errorPayload = asMap(payload['error']);
    final topLevelError = payload['error'];
    final details = _firstMap([
      errorPayload['details'],
      errorPayload['errors'],
      payload['details'],
      payload['errors'],
    ]);
    final validationMessage = _validationMessage(
          errorPayload['errors'],
        ) ??
        _validationMessage(payload['errors']);

    final message = _firstText([
      errorPayload['message'],
      payload['message'],
      if (topLevelError is String) topLevelError,
      validationMessage,
    ]);

    final code = _firstText([
      errorPayload['code'],
      errorPayload['error_code'],
      errorPayload['errorCode'],
      payload['code'],
      payload['error_code'],
      payload['errorCode'],
    ]);

    return ApiErrorInfo(
      code: code,
      message: message,
      details: details,
      statusCode: statusCode,
    );
  }

  final String code;
  final String message;
  final Map<String, dynamic> details;
  final int? statusCode;

  bool get isSmsOtpProviderNotConfigured =>
      code == 'sms_otp_provider_not_configured';

  bool get providerRequired => details['provider_required'] == true;

  bool get isOptionalSmsOtpProviderMissing =>
      isSmsOtpProviderNotConfigured && !providerRequired;

  bool get isCustomerSuspended => code == 'customer_suspended';
  bool get isMaintenanceActive => code == 'maintenance_active';
  bool get isPinRequired =>
      code == 'pin_required' || code == 'pin_setup_required';
  bool get isAuthenticationExpired {
    const expiredCodes = {
      'unauthenticated',
      'authentication_expired',
      'auth_expired',
      'token_expired',
      'invalid_token',
      'session_expired',
    };
    if (expiredCodes.contains(code)) return true;
    if (statusCode != 401) return false;

    final normalizedMessage = message.trim().toLowerCase();
    if (normalizedMessage.isEmpty) return true;
    return normalizedMessage.contains('unauthenticated') ||
        normalizedMessage.contains('token expired') ||
        normalizedMessage.contains('invalid token') ||
        normalizedMessage.contains('session expired') ||
        normalizedMessage.contains('session has expired');
  }

  Map<String, dynamic> get suspension {
    final nested = asMap(details['suspension']);
    return nested.isEmpty ? details : nested;
  }

  String? get operationalRedirectPath {
    if (isAuthenticationExpired) return '/login';
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

String _firstText(Iterable<Object?> values) {
  for (final value in values) {
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty) return text;
  }
  return '';
}

Map<String, dynamic> _firstMap(Iterable<Object?> values) {
  for (final value in values) {
    final map = asMap(value);
    if (map.isNotEmpty) return map;
  }
  return const <String, dynamic>{};
}

String? _validationMessage(Object? value) {
  if (value is List && value.isNotEmpty) {
    return _firstText(value);
  }

  final map = asMap(value);
  for (final entry in map.entries) {
    final item = entry.value;
    if (item is List && item.isNotEmpty) {
      final text = _firstText(item);
      if (text.isNotEmpty) return text;
    }
    final text = item?.toString().trim() ?? '';
    if (text.isNotEmpty) return text;
  }

  return null;
}
