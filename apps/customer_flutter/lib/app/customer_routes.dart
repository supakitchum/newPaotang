import '../shared/models/customer_feature_route.dart';

const customerFeatureRoutes = <CustomerFeatureRoute>[
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
    sensitive: true,
  ),
  CustomerFeatureRoute(
    path: '/topup/history',
    key: 'topup_history',
    group: CustomerFeatureGroup.wallet,
    sensitive: true,
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
    sensitive: true,
  ),
  CustomerFeatureRoute(
    path: '/profile',
    key: 'profile',
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
    path: '/register',
    key: 'register',
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
  return customerFeatureRoutes.any(
    (route) => route.public && isCustomerRoutePatternMatch(route.path, path),
  );
}

bool isSensitiveCustomerPath(
  String path, {
  Iterable<String> extraSensitiveRoutes = const [],
}) {
  final normalizedPath = path.trim();
  if (normalizedPath.isEmpty) return false;

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

CustomerFeatureRoute? customerFeatureByPath(String path) {
  for (final route in customerFeatureRoutes) {
    if (isCustomerRoutePatternMatch(route.path, path)) return route;
  }
  return null;
}

bool isCustomerRoutePatternMatch(String pattern, String path) {
  if (pattern == path) return true;
  final patternParts =
      pattern.split('/').where((part) => part.isNotEmpty).toList();
  final pathParts = path.split('/').where((part) => part.isNotEmpty).toList();
  if (patternParts.length != pathParts.length) return false;
  for (var index = 0; index < patternParts.length; index++) {
    final patternPart = patternParts[index];
    if (patternPart.startsWith(':')) continue;
    if (patternPart != pathParts[index]) return false;
  }
  return true;
}

bool _isSensitivePathPrefixMatch(String pattern, String path) {
  final sensitive = pattern.trim();
  if (sensitive.isEmpty) return false;
  if (isCustomerRoutePatternMatch(sensitive, path)) return true;
  return path == sensitive || path.startsWith('$sensitive/');
}
