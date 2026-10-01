import '../shared/models/customer_feature_route.dart';

const customerFeatureRoutes = <CustomerFeatureRoute>[
  CustomerFeatureRoute(
    path: '/support',
    key: 'support',
    group: CustomerFeatureGroup.system,
    sensitive: true,
  ),
  CustomerFeatureRoute(
    path: '/support/new',
    key: 'support_new',
    group: CustomerFeatureGroup.system,
    sensitive: true,
  ),
  CustomerFeatureRoute(
    path: '/support/tickets',
    key: 'support_tickets',
    group: CustomerFeatureGroup.system,
    sensitive: true,
  ),
  CustomerFeatureRoute(
    path: '/support/tickets/:ticketId',
    key: 'support_ticket',
    group: CustomerFeatureGroup.system,
    sensitive: true,
  ),
  CustomerFeatureRoute(
    path: '/',
    key: 'home',
    group: CustomerFeatureGroup.storefront,
    descriptionKey: 'home',
    public: true,
  ),
  CustomerFeatureRoute(
    path: '/buy',
    key: 'buy',
    group: CustomerFeatureGroup.lottery,
    descriptionKey: 'buy',
  ),
  CustomerFeatureRoute(
    path: '/buy/search',
    key: 'buy_search',
    group: CustomerFeatureGroup.lottery,
    descriptionKey: 'buy_search',
  ),
  CustomerFeatureRoute(
    path: '/search',
    key: 'search',
    group: CustomerFeatureGroup.lottery,
    descriptionKey: 'buy_search',
  ),
  CustomerFeatureRoute(
    path: '/buy/more',
    key: 'buy_more',
    group: CustomerFeatureGroup.lottery,
    descriptionKey: 'buy_more',
  ),
  CustomerFeatureRoute(
    path: '/cart',
    key: 'cart',
    group: CustomerFeatureGroup.lottery,
    sensitive: true,
  ),
  CustomerFeatureRoute(
    path: '/checkout',
    key: 'checkout',
    group: CustomerFeatureGroup.lottery,
    sensitive: true,
  ),
  CustomerFeatureRoute(
    path: '/checkout/pending',
    key: 'checkout_pending',
    group: CustomerFeatureGroup.lottery,
    sensitive: true,
  ),
  CustomerFeatureRoute(
    path: '/tickets',
    key: 'tickets',
    group: CustomerFeatureGroup.lottery,
    descriptionKey: 'tickets',
    sensitive: true,
  ),
  CustomerFeatureRoute(
    path: '/tickets/search',
    key: 'tickets_search',
    group: CustomerFeatureGroup.lottery,
    sensitive: true,
  ),
  CustomerFeatureRoute(
    path: '/tickets/history',
    key: 'tickets_history',
    group: CustomerFeatureGroup.lottery,
    sensitive: true,
  ),
  CustomerFeatureRoute(
    path: '/tickets/view',
    key: 'tickets_view',
    group: CustomerFeatureGroup.lottery,
    sensitive: true,
  ),
  CustomerFeatureRoute(
    path: '/tickets/claim/:ticketId',
    key: 'ticket_claim',
    group: CustomerFeatureGroup.lottery,
    sensitive: true,
  ),
  CustomerFeatureRoute(
    path: '/result',
    key: 'result',
    group: CustomerFeatureGroup.lottery,
    descriptionKey: 'result',
    public: true,
  ),
  CustomerFeatureRoute(
    path: '/result/full',
    key: 'result_full',
    group: CustomerFeatureGroup.lottery,
    public: true,
  ),
  CustomerFeatureRoute(
    path: '/results',
    key: 'results',
    group: CustomerFeatureGroup.lottery,
    public: true,
  ),
  CustomerFeatureRoute(
    path: '/results/full',
    key: 'results_full',
    group: CustomerFeatureGroup.lottery,
    public: true,
  ),
  CustomerFeatureRoute(
    path: '/waiting-result',
    key: 'waiting_result',
    group: CustomerFeatureGroup.lottery,
    public: true,
  ),
  CustomerFeatureRoute(
    path: '/wait-result',
    key: 'wait_result',
    group: CustomerFeatureGroup.lottery,
    public: true,
  ),
  CustomerFeatureRoute(
    path: '/my-wallet',
    key: 'my_wallet',
    group: CustomerFeatureGroup.wallet,
    descriptionKey: 'my_wallet',
    sensitive: true,
  ),
  CustomerFeatureRoute(
    path: '/topup',
    key: 'topup',
    group: CustomerFeatureGroup.wallet,
  ),
  CustomerFeatureRoute(
    path: '/topup/:topupId',
    key: 'topup_detail',
    group: CustomerFeatureGroup.wallet,
  ),
  CustomerFeatureRoute(
    path: '/topup/history',
    key: 'topup_history',
    group: CustomerFeatureGroup.wallet,
  ),
  CustomerFeatureRoute(
    path: '/reward-claims',
    key: 'reward_claims',
    group: CustomerFeatureGroup.wallet,
    sensitive: true,
  ),
  CustomerFeatureRoute(
    path: '/reward-claims/:claimId',
    key: 'reward_claim_detail',
    group: CustomerFeatureGroup.wallet,
    sensitive: true,
  ),
  CustomerFeatureRoute(
    path: '/activity-claims',
    key: 'activity_claims',
    group: CustomerFeatureGroup.wallet,
    sensitive: true,
  ),
  CustomerFeatureRoute(
    path: '/activity-claims/:claimId',
    key: 'activity_claim_detail',
    group: CustomerFeatureGroup.wallet,
    sensitive: true,
  ),
  CustomerFeatureRoute(
    path: '/activities',
    key: 'activities',
    group: CustomerFeatureGroup.storefront,
    descriptionKey: 'activities',
    public: true,
  ),
  CustomerFeatureRoute(
    path: '/activities/history',
    key: 'activities_history',
    group: CustomerFeatureGroup.storefront,
    public: true,
  ),
  CustomerFeatureRoute(
    path: '/activities/:slug',
    key: 'activity_detail',
    group: CustomerFeatureGroup.storefront,
    public: true,
  ),
  CustomerFeatureRoute(
    path: '/affiliate',
    key: 'affiliate',
    group: CustomerFeatureGroup.account,
  ),
  CustomerFeatureRoute(
    path: '/affiliate/referral',
    key: 'affiliate_referral',
    group: CustomerFeatureGroup.account,
  ),
  CustomerFeatureRoute(
    path: '/affiliate/rankings',
    key: 'affiliate_rankings',
    group: CustomerFeatureGroup.account,
  ),
  CustomerFeatureRoute(
    path: '/affiliate/campaigns',
    key: 'affiliate_campaigns',
    group: CustomerFeatureGroup.account,
  ),
  CustomerFeatureRoute(
    path: '/affiliate/withdraw',
    key: 'affiliate_withdraw',
    group: CustomerFeatureGroup.account,
  ),
  CustomerFeatureRoute(
    path: '/affiliate/commissions',
    key: 'affiliate_commissions',
    group: CustomerFeatureGroup.account,
  ),
  CustomerFeatureRoute(
    path: '/affiliate/payouts',
    key: 'affiliate_payouts',
    group: CustomerFeatureGroup.account,
  ),
  CustomerFeatureRoute(
    path: '/profile',
    key: 'profile',
    group: CustomerFeatureGroup.account,
    sensitive: true,
  ),
  CustomerFeatureRoute(
    path: '/profile/language',
    key: 'profile_language',
    group: CustomerFeatureGroup.account,
    sensitive: true,
  ),
  CustomerFeatureRoute(
    path: '/profile/auto-reward',
    key: 'profile_auto_reward',
    group: CustomerFeatureGroup.account,
    sensitive: true,
  ),
  CustomerFeatureRoute(
    path: '/profile/line-notifications',
    key: 'profile_line_notifications',
    group: CustomerFeatureGroup.account,
    sensitive: true,
  ),
  CustomerFeatureRoute(
    path: '/profile/reward-bank',
    key: 'profile_reward_bank',
    group: CustomerFeatureGroup.account,
    sensitive: true,
  ),
  CustomerFeatureRoute(
    path: '/profile/biometrics',
    key: 'profile_biometrics',
    group: CustomerFeatureGroup.account,
    sensitive: true,
  ),
  CustomerFeatureRoute(
    path: '/profile/passkeys',
    key: 'profile_passkeys',
    group: CustomerFeatureGroup.account,
    sensitive: true,
  ),
  CustomerFeatureRoute(
    path: '/profile/social-accounts',
    key: 'profile_social_accounts',
    group: CustomerFeatureGroup.account,
    sensitive: true,
  ),
  CustomerFeatureRoute(
    path: '/profile/account-deletion',
    key: 'profile_account_deletion',
    group: CustomerFeatureGroup.account,
    sensitive: true,
  ),
  CustomerFeatureRoute(
    path: '/purchase-history',
    key: 'purchase_history',
    group: CustomerFeatureGroup.account,
    sensitive: true,
  ),
  CustomerFeatureRoute(
    path: '/purchase-history/:orderId',
    key: 'purchase_history_detail',
    group: CustomerFeatureGroup.account,
    sensitive: true,
  ),
  CustomerFeatureRoute(
    path: '/notifications',
    key: 'notifications',
    group: CustomerFeatureGroup.account,
    sensitive: true,
  ),
  CustomerFeatureRoute(
    path: '/stores',
    key: 'stores',
    group: CustomerFeatureGroup.storefront,
    public: true,
  ),
  CustomerFeatureRoute(
    path: '/stores/lotteries',
    key: 'store_lotteries',
    group: CustomerFeatureGroup.storefront,
    public: true,
  ),
  CustomerFeatureRoute(
    path: '/news',
    key: 'news',
    group: CustomerFeatureGroup.content,
    public: true,
  ),
  CustomerFeatureRoute(
    path: '/news/:slug',
    key: 'news_detail',
    group: CustomerFeatureGroup.content,
    public: true,
  ),
  CustomerFeatureRoute(
    path: '/terms',
    key: 'terms',
    group: CustomerFeatureGroup.content,
    public: true,
  ),
  CustomerFeatureRoute(
    path: '/privacy',
    key: 'privacy',
    group: CustomerFeatureGroup.content,
    public: true,
  ),
  CustomerFeatureRoute(
    path: '/term-reward',
    key: 'term_reward',
    group: CustomerFeatureGroup.content,
    public: true,
  ),
  CustomerFeatureRoute(
    path: '/lottery-knowledge',
    key: 'lottery_knowledge',
    group: CustomerFeatureGroup.content,
    public: true,
  ),
  CustomerFeatureRoute(
    path: '/login',
    key: 'login',
    group: CustomerFeatureGroup.system,
    public: true,
  ),
  CustomerFeatureRoute(
    path: '/login/otp',
    key: 'login_otp',
    group: CustomerFeatureGroup.system,
    public: true,
  ),
  CustomerFeatureRoute(
    path: '/register',
    key: 'register',
    group: CustomerFeatureGroup.system,
    public: true,
  ),
  CustomerFeatureRoute(
    path: '/register/otp',
    key: 'register_otp',
    group: CustomerFeatureGroup.system,
    public: true,
  ),
  CustomerFeatureRoute(
    path: '/forgot-password',
    key: 'forgot_password',
    group: CustomerFeatureGroup.system,
    public: true,
  ),
  CustomerFeatureRoute(
    path: '/reset-password',
    key: 'reset_password',
    group: CustomerFeatureGroup.system,
    public: true,
  ),
  CustomerFeatureRoute(
    path: '/line/callback',
    key: 'line_callback',
    group: CustomerFeatureGroup.system,
    public: true,
  ),
  CustomerFeatureRoute(
    path: '/line/link-phone',
    key: 'line_link_phone',
    group: CustomerFeatureGroup.system,
    public: true,
  ),
  CustomerFeatureRoute(
    path: '/social/:provider/callback',
    key: 'social_callback',
    group: CustomerFeatureGroup.system,
    public: true,
  ),
  CustomerFeatureRoute(
    path: '/social/:provider/link-phone',
    key: 'social_link_phone',
    group: CustomerFeatureGroup.system,
    public: true,
  ),
  CustomerFeatureRoute(
    path: '/pin',
    key: 'pin',
    group: CustomerFeatureGroup.system,
    sensitive: true,
  ),
  CustomerFeatureRoute(
    path: '/security-lock',
    key: 'security_lock',
    group: CustomerFeatureGroup.system,
    sensitive: true,
  ),
  CustomerFeatureRoute(
    path: '/maintenance',
    key: 'maintenance',
    group: CustomerFeatureGroup.system,
    public: true,
  ),
  CustomerFeatureRoute(
    path: '/account-suspended',
    key: 'account_suspended',
    group: CustomerFeatureGroup.system,
    public: true,
  ),
  CustomerFeatureRoute(
    path: '/countdown',
    key: 'countdown',
    group: CustomerFeatureGroup.system,
    public: true,
  ),
  CustomerFeatureRoute(
    path: '/success',
    key: 'success',
    group: CustomerFeatureGroup.system,
    sensitive: true,
  ),
];

final publicCustomerPaths = customerFeatureRoutes
    .where((route) => route.public)
    .map((route) => route.path)
    .toSet();

bool isPublicCustomerPath(String path) {
  final normalizedPath = normalizeCustomerRoutePath(path);
  return customerFeatureRoutes.any(
    (route) =>
        route.public && isCustomerRoutePatternMatch(route.path, normalizedPath),
  );
}

bool isSensitiveCustomerPath(
  String path, {
  Iterable<String> extraSensitiveRoutes = const [],
}) {
  final normalizedPath = normalizeCustomerRoutePath(path);
  if (normalizedPath.isEmpty) return false;
  if (isCustomerScreenSecurityExemptPath(normalizedPath)) return false;

  final routeSensitive = customerFeatureRoutes.any(
    (route) =>
        route.sensitive &&
        isCustomerRoutePatternMatch(route.path, normalizedPath),
  );
  if (routeSensitive) return true;

  return extraSensitiveRoutes.any(
    (route) => _isSensitivePathPrefixMatch(route, normalizedPath),
  );
}

bool isCustomerScreenSecurityExemptPath(String path) {
  final normalizedPath = normalizeCustomerRoutePath(path);
  return normalizedPath == '/topup' ||
      normalizedPath.startsWith('/topup/') ||
      normalizedPath == '/affiliate' ||
      normalizedPath.startsWith('/affiliate/');
}

CustomerFeatureRoute? customerFeatureByPath(String path) {
  final normalizedPath = normalizeCustomerRoutePath(path);
  for (final route in customerFeatureRoutes) {
    if (isCustomerRoutePatternMatch(route.path, normalizedPath)) return route;
  }
  return null;
}

bool isCustomerRoutePatternMatch(String pattern, String path) {
  final normalizedPattern = _stripCustomerRouteQuery(pattern.trim());
  final normalizedPath = normalizeCustomerRoutePath(path);
  if (normalizedPattern == normalizedPath) return true;
  final patternParts = normalizedPattern
      .split('/')
      .where((part) => part.isNotEmpty)
      .toList();
  final pathParts = normalizedPath
      .split('/')
      .where((part) => part.isNotEmpty)
      .toList();
  var pathIndex = 0;
  for (
    var patternIndex = 0;
    patternIndex < patternParts.length;
    patternIndex++
  ) {
    final patternPart = patternParts[patternIndex];
    final lastPatternPart = patternIndex == patternParts.length - 1;
    if (patternPart == '*') {
      return lastPatternPart && pathIndex < pathParts.length;
    }
    if (pathIndex >= pathParts.length) return false;
    if (patternPart.startsWith(':')) {
      pathIndex++;
      continue;
    }
    if (patternPart != pathParts[pathIndex]) return false;
    pathIndex++;
  }
  return pathIndex == pathParts.length;
}

bool _isSensitivePathPrefixMatch(String pattern, String path) {
  final sensitive = _stripCustomerRouteQuery(pattern.trim());
  if (sensitive.isEmpty) return false;
  if (isCustomerRoutePatternMatch(sensitive, path)) return true;
  return path == sensitive || path.startsWith('$sensitive/');
}

String normalizeCustomerRoutePath(String path) {
  final trimmed = path.trim();
  if (trimmed.isEmpty) return '';

  final parsed = Uri.tryParse(trimmed);
  if (parsed != null && parsed.hasScheme) {
    final fragmentPath = _customerRoutePathFromFragment(parsed.fragment);
    if (fragmentPath.isNotEmpty) return fragmentPath;
    return _stripCustomerRouteQuery(parsed.path.isEmpty ? '/' : parsed.path);
  }

  final fragmentPath = _customerRoutePathFromFragment(trimmed);
  if (fragmentPath.isNotEmpty) return fragmentPath;
  return _stripCustomerRouteQuery(trimmed);
}

String _customerRoutePathFromFragment(String value) {
  var fragment = value.trim();
  if (fragment.isEmpty) return '';
  if (fragment.startsWith('#')) fragment = fragment.substring(1).trim();
  if (fragment.startsWith('!')) fragment = fragment.substring(1).trim();
  if (fragment.isEmpty) return '';

  final decoded = _decodeCustomerRouteValue(fragment);
  if (decoded.startsWith('/')) return _stripCustomerRouteQuery(decoded);
  final decodedUri = Uri.tryParse(decoded);
  if (decodedUri != null && decodedUri.hasScheme) {
    return normalizeCustomerRoutePath(decoded);
  }

  final query = decoded.startsWith('?') ? decoded.substring(1) : decoded;
  final params = _safeCustomerRouteQueryParameters(query);
  for (final key in const [
    'route',
    'path',
    'screen',
    'page',
    'currentPath',
    'currentUrl',
    'activeUrl',
    'targetUrl',
    'routeUrl',
    'returnUrl',
    'redirectUrl',
    'href',
    'uri',
  ]) {
    final nested = params[key]?.trim() ?? '';
    if (nested.isEmpty) continue;
    final nestedPath = normalizeCustomerRoutePath(nested);
    if (nestedPath.isNotEmpty) return nestedPath;
  }
  return '';
}

String _stripCustomerRouteQuery(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '';
  final index = trimmed.indexOf(RegExp(r'[?#]'));
  final path = index == -1 ? trimmed : trimmed.substring(0, index);
  if (path.isEmpty && trimmed.startsWith('/')) return '/';
  return path;
}

Map<String, String> _safeCustomerRouteQueryParameters(String value) {
  if (!value.contains('=')) return const {};
  try {
    return Uri.splitQueryString(value);
  } on FormatException {
    return const {};
  }
}

String _decodeCustomerRouteValue(String value) {
  var decoded = value.trim();
  for (var index = 0; index < 2; index++) {
    final next = Uri.tryParse(decoded)?.toString();
    try {
      final decodedOnce = Uri.decodeFull(next ?? decoded).trim();
      if (decodedOnce == decoded || decodedOnce.isEmpty) return decoded;
      decoded = decodedOnce;
    } on FormatException {
      return decoded;
    }
  }
  return decoded;
}
