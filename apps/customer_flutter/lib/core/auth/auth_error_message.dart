import 'package:dio/dio.dart';

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

String? authApiErrorMessage(Object error) {
  final message = ApiErrorInfo.fromObject(error).message.trim();
  if (message.isEmpty) return null;
  if (error is DioException || error is Map) return message;
  return null;
}
