import 'package:dio/dio.dart';

import '../i18n/customer_localizations.dart';
import '../utils/api_errors.dart';

String authErrorMessage(Object error, String fallback) {
  return authApiErrorMessage(error) ?? fallback;
}

String authOtpErrorMessage({
  required Object error,
  required String fallback,
  required String otpProviderUnavailable,
}) {
  final info = ApiErrorInfo.fromObject(error);
  if (info.isSmsOtpProviderNotConfigured) return otpProviderUnavailable;
  return authErrorMessage(error, fallback);
}

String loginErrorMessage(
  Object error,
  CustomerLocalizations l10n, {
  required String fallback,
}) {
  final info = ApiErrorInfo.fromObject(error);
  final localized = switch (info.code) {
    'customer_account_not_found' => l10n.loginAccountNotFound,
    'invalid_login_credentials' => l10n.loginInvalidCredentials,
    'customer_account_inactive' => l10n.loginAccountInactive,
    'authentication_required' ||
    'unauthenticated' ||
    'authentication_expired' ||
    'auth_expired' ||
    'token_expired' ||
    'invalid_token' ||
    'session_expired' => l10n.loginSessionEnded,
    'login_otp_challenge_invalid' => l10n.loginOtpExpired,
    'login_otp_phone_missing' => l10n.loginOtpPhoneMissing,
    'otp_invalid' => l10n.loginOtpIncorrect,
    'otp_attempts_exceeded' => l10n.loginOtpAttemptsExceeded,
    'otp_cooldown' => l10n.loginOtpCooldown,
    'otp_rate_limited' => l10n.loginOtpRateLimited,
    'sms_otp_provider_not_configured' => l10n.loginOtpProviderUnavailable,
    'sms_send_failed' => l10n.loginOtpSendFailed,
    'sms_verify_failed' => l10n.loginOtpVerifyFailed,
    _ => '',
  };
  if (localized.isNotEmpty) return localized;

  final message = info.message.trim();
  if (message.isEmpty || _looksLikeTechnicalAuthMessage(message)) {
    return fallback;
  }
  return message;
}

String? authApiErrorMessage(Object error) {
  final message = ApiErrorInfo.fromObject(error).message.trim();
  if (message.isEmpty) return null;
  if (error is DioException || error is Map) return message;
  return null;
}

bool _looksLikeTechnicalAuthMessage(String message) {
  final normalized = message.toLowerCase();
  return normalized.contains('token') ||
      normalized.contains('unauthenticated') ||
      normalized.contains('authentication required') ||
      normalized.contains('challenge') ||
      normalized.contains('credential') ||
      normalized.contains('internal') ||
      normalized.startsWith('bad state:') ||
      normalized.contains('exception') ||
      normalized.contains('stack trace');
}
