import 'package:dio/dio.dart';

import 'api_payload.dart';

class ApiErrorInfo {
  const ApiErrorInfo({
    required this.code,
    required this.message,
    required this.details,
    this.statusCode,
    this.requestPath = '',
  });

  factory ApiErrorInfo.fromObject(Object? error) {
    final statusCode = error is DioException
        ? error.response?.statusCode
        : null;
    final requestPath = error is DioException ? error.requestOptions.path : '';
    final data = error is DioException ? error.response?.data : error;
    final payload = asMap(data);
    if (payload.isEmpty) {
      return ApiErrorInfo(
        code: '',
        message: data?.toString() ?? '',
        details: const <String, dynamic>{},
        statusCode: statusCode,
        requestPath: requestPath,
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
    final validationMessage =
        _validationMessage(errorPayload['errors']) ??
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
      requestPath: requestPath,
    );
  }

  final String code;
  final String message;
  final Map<String, dynamic> details;
  final int? statusCode;
  final String requestPath;

  bool get isSmsOtpProviderNotConfigured =>
      code == 'sms_otp_provider_not_configured';

  bool get providerRequired => details['provider_required'] == true;

  bool get isOptionalSmsOtpProviderMissing =>
      isSmsOtpProviderNotConfigured && !providerRequired;

  bool get isCustomerSuspended => code == 'customer_suspended';
  bool get isCustomerSessionReplaced => code == 'customer_session_replaced';
  bool get isMaintenanceActive => code == 'maintenance_active';
  bool get isPinRequired =>
      code == 'pin_required' || code == 'pin_setup_required';
  bool get isAuthenticationExpired {
    if (_isPasswordLoginRequest) return false;
    const expiredCodes = {
      'authentication_required',
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

  String get replacementSessionId => _firstText([
    details['replacement_session_id'],
    details['replacementSessionId'],
  ]);

  bool get _isPasswordLoginRequest {
    final normalized = requestPath.trim().toLowerCase();
    return normalized.endsWith('/customer/auth/login') ||
        normalized == 'customer/auth/login';
  }

  Map<String, dynamic> get suspension {
    final nested = _firstMap([
      details['suspension'],
      details['account_suspension'],
      details['accountSuspension'],
      details['customer_suspension'],
      details['customerSuspension'],
    ]);
    return nested.isEmpty ? details : nested;
  }

  String? get operationalRedirectPath {
    if (isAuthenticationExpired || isCustomerSessionReplaced) return '/login';
    if (isMaintenanceActive) return '/maintenance';
    if (isPinRequired) return '/pin';
    if (isCustomerSuspended) return customerSuspendedPath;
    return null;
  }

  String get customerSuspendedPath {
    final data = suspension;
    final reason = _firstText([
      data['reason'],
      data['suspension_reason'],
      data['suspensionReason'],
      data['message'],
    ]);
    final suspendedUntil = _firstText([
      data['suspended_until'],
      data['suspendedUntil'],
      data['until'],
      data['ends_at'],
      data['endsAt'],
    ]);
    final permanent = _firstBool([
      data['is_permanent'],
      data['isPermanent'],
      data['permanent'],
      data['permanent_suspension'],
      data['permanentSuspension'],
    ]);
    return Uri(
      path: '/account-suspended',
      queryParameters: {
        if (reason.isNotEmpty) 'reason': reason,
        if (suspendedUntil.isNotEmpty) 'suspended_until': suspendedUntil,
        if (permanent) 'permanent': '1',
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

bool _firstBool(Iterable<Object?> values) {
  for (final value in values) {
    if (value == null) continue;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final normalized = value.toString().trim().toLowerCase();
    if (normalized.isEmpty) continue;
    if (const {
      '1',
      'true',
      'yes',
      'on',
      'permanent',
      'permanently',
    }.contains(normalized)) {
      return true;
    }
    if (const {'0', 'false', 'no', 'off', 'temporary'}.contains(normalized)) {
      return false;
    }
  }
  return false;
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
