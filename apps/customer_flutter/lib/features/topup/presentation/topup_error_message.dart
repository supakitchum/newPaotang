import 'package:dio/dio.dart';

import '../../../core/utils/api_errors.dart';

String topupErrorMessage(Object error, String fallback) {
  final message = ApiErrorInfo.fromObject(error).message.trim();
  if (message.isEmpty) return fallback;
  if (error is DioException || error is Map) return message;
  return fallback;
}
