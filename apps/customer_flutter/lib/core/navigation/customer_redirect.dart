const _guestOnlyRedirectPaths = {
  '/login',
  '/register',
  '/forgot-password',
  '/reset-password',
};

const _blockedRedirectPaths = {
  ..._guestOnlyRedirectPaths,
  '/pin',
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

  if (_blockedRedirectPaths.contains(uri.path)) {
    return '/';
  }

  return redirect;
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
