import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/utils/api_errors.dart';

String customerErrorMessage(Object error, String fallback) {
  final message = ApiErrorInfo.fromObject(error).message.trim();
  if (message.isEmpty) return fallback;
  if (error is DioException || error is Map) return message;
  return fallback;
}

Future<bool> handleCustomerOperationalError({
  required WidgetRef ref,
  required BuildContext context,
  required Object error,
  bool handlePinRedirect = true,
}) async {
  final info = ApiErrorInfo.fromObject(error);
  if (!handlePinRedirect && info.isPinRequired) return false;
  final redirect = info.operationalRedirectPath;
  if (redirect == null) return false;

  if (info.isAuthenticationExpired) {
    await ref.read(authControllerProvider).logout();
  }

  if (!context.mounted) return true;
  context.go(redirect);
  return true;
}
