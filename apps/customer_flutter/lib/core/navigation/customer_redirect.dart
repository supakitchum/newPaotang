const _guestOnlyRedirectPaths = {
  '/login',
  '/register',
  '/forgot-password',
  '/reset-password',
};

const _blockedRedirectPaths = {
  ..._guestOnlyRedirectPaths,
  '/pin',
  '/line/callback',
  '/line/link-phone',
  '/social',
};

const _inlinePinRedirectPaths = {
  '/affiliate',
};

String safeCustomerRedirect(String? value) {
  final redirect = value?.trim() ?? '';
  if (redirect.isEmpty ||
      !redirect.startsWith('/') ||
      redirect.startsWith('//')) {
    return '/';
  }

  final uri = Uri.tryParse(redirect);
  if (uri == null || uri.hasScheme || uri.host.isNotEmpty) {
    return '/';
  }

  if (_blockedRedirectPaths.contains(uri.path) ||
      uri.path.startsWith('/social/')) {
    return '/';
  }

  return redirect;
}

bool customerHandlesPinInline(String? value) {
  final redirect = safeCustomerRedirect(value);
  final uri = Uri.tryParse(redirect);
  if (uri == null) return false;
  return _inlinePinRedirectPaths.contains(uri.path);
}

String customerPostAuthRouteForRedirect({
  required String? redirect,
  required bool pinRequired,
  required bool pinSetupRequired,
}) {
  final safeRedirect = safeCustomerRedirect(redirect);
  if (pinSetupRequired ||
      (pinRequired && !customerHandlesPinInline(safeRedirect))) {
    return customerPinRouteForRedirect(safeRedirect);
  }
  return safeRedirect;
}

String customerRouteWithRedirect(String path, String? redirect) {
  final safeRedirect = safeCustomerRedirect(redirect);
  if (safeRedirect == '/') return path;
  return Uri(
    path: path,
    queryParameters: {'redirect': safeRedirect},
  ).toString();
}

String customerLoginRouteForRedirect(String? redirect) {
  return customerRouteWithRedirect('/login', redirect);
}

String customerRegisterRouteForRedirect(String? redirect) {
  return customerRouteWithRedirect('/register', redirect);
}

String customerPinRouteForRedirect(String? redirect) {
  return customerRouteWithRedirect('/pin', redirect);
}

String customerCheckoutPendingRouteForOrder(String? orderId) {
  final id = orderId?.trim() ?? '';
  return Uri(
    path: '/checkout/pending',
    queryParameters: {
      if (id.isNotEmpty) 'order_id': id,
    },
  ).toString();
}
