import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/navigation/customer_redirect.dart';
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
  GoRouter? router,
  String? returnPathOverride,
}) async {
  final info = ApiErrorInfo.fromObject(error);
  if (!handlePinRedirect && info.isPinRequired) return false;
  var redirect = info.operationalRedirectPath;
  if (redirect == null) return false;

  final returnPath = _customerOperationalReturnPath(
    context,
    router: router,
    returnPathOverride: returnPathOverride,
  );
  if (info.isPinRequired) {
    redirect = customerPinRouteForRedirect(returnPath);
  } else if (info.isAuthenticationExpired) {
    redirect = customerLoginRouteForRedirect(returnPath);
  }

  if (info.isAuthenticationExpired || info.isCustomerSuspended) {
    await ref.read(authControllerProvider).logout();
  }

  if (!context.mounted) return true;
  if (router != null) {
    router.go(redirect);
  } else {
    context.go(redirect);
  }
  return true;
}

void listenForCustomerOperationalError<T>({
  required WidgetRef ref,
  required BuildContext context,
  required ProviderListenable<AsyncValue<T>> provider,
  bool handlePinRedirect = true,
}) {
  ref.listen<AsyncValue<T>>(provider, (previous, next) {
    final error = next.error;
    if (error == null || identical(previous?.error, error)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      handleCustomerOperationalError(
        ref: ref,
        context: context,
        error: error,
        handlePinRedirect: handlePinRedirect,
      );
    });
  });
}

String? _customerOperationalReturnPath(
  BuildContext context, {
  GoRouter? router,
  String? returnPathOverride,
}) {
  if (returnPathOverride != null) {
    return _normalizedOperationalReturnPath(returnPathOverride);
  }

  try {
    return _normalizedOperationalReturnPath(
      router?.routeInformationProvider.value.uri.toString() ??
          GoRouterState.of(context).uri.toString(),
    );
  } catch (_) {
    return null;
  }
}

String? _normalizedOperationalReturnPath(String? value) {
  final current = safeCustomerRedirect(value);
  final path = Uri.tryParse(current)?.path ?? '';
  if (path.isEmpty ||
      path == '/' ||
      path == '/login' ||
      path == '/register' ||
      path == '/pin' ||
      path == '/maintenance' ||
      path == '/account-suspended') {
    return null;
  }
  return current;
}
