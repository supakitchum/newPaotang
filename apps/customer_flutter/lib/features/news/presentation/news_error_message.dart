import 'package:dio/dio.dart';

import '../../../core/utils/api_errors.dart';

String newsErrorMessage(Object error, String fallback) {
  final message = ApiErrorInfo.fromObject(error).message.trim();
  if (message.isEmpty) return fallback;
  if (error is DioException || error is Map) return message;
  return fallback;
}

bool newsNotFoundError(Object error) {
  final info = ApiErrorInfo.fromObject(error);
  if (info.statusCode == 404) return true;
  const missingCodes = {
    'not_found',
    'news_not_found',
    'announcement_not_found',
    'resource_not_found',
  };
  return missingCodes.contains(info.code);
}
