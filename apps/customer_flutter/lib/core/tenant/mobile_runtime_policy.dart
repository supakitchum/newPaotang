import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../security/web_privacy_mode.dart';
import 'mobile_bootstrap_controller.dart';

final customerPlatformKeyProvider = Provider<String>((_) {
  return currentCustomerPlatformKey();
});

String currentCustomerPlatformKey({
  bool isWeb = kIsWeb,
  TargetPlatform? targetPlatform,
}) {
  if (isWeb) return 'web';
  return switch (targetPlatform ?? defaultTargetPlatform) {
    TargetPlatform.iOS => 'ios',
    TargetPlatform.android => 'android',
    TargetPlatform.macOS => 'macos',
    TargetPlatform.windows => 'windows',
    TargetPlatform.linux => 'linux',
    TargetPlatform.fuchsia => 'fuchsia',
  };
}

bool mobileBiometricAllowedForPlatform(
  MobileBootstrap bootstrap,
  String platform,
) {
  final platformKey = platform.trim().toLowerCase();
  if (!const {'ios', 'android'}.contains(platformKey)) return false;
  if (!bootstrap.biometric.enabled) return false;
  if (!bootstrap.featureFlags.enabled(
    'native_biometric_unlock',
    fallback: true,
  )) {
    return false;
  }
  if (bootstrap.biometric.platforms.isEmpty) return true;
  return bootstrap.biometric.supportsPlatform(platformKey);
}

String mobileBiometricPromptReason(
  MobileBootstrap? bootstrap, {
  required String purpose,
  required String fallback,
  bool setup = false,
}) {
  if (bootstrap == null) return fallback;
  return bootstrap.biometric.promptReasonForPurpose(
    purpose,
    fallback: fallback,
    setup: setup,
  );
}

bool mobileNativeScreenSecurityAllowedForPlatform(
  MobileBootstrap bootstrap,
  String platform,
) {
  final platformKey = platform.trim().toLowerCase();
  final iosScreenshotPolicy = bootstrap.screenSecurity.iosScreenshotPolicy
      .trim()
      .toLowerCase();
  final iosScreenshotProtectionEnabled =
      iosScreenshotPolicy.isNotEmpty &&
      !{'none', 'off', 'disabled'}.contains(iosScreenshotPolicy);
  if (!bootstrap.featureFlags.enabled(
    'screen_security_native',
    fallback: true,
  )) {
    return false;
  }

  return switch (platformKey) {
    'android' =>
      bootstrap.screenSecurity.androidFlagSecure ||
          bootstrap.screenSecurity.androidProtectRecentAppPreview,
    'ios' =>
      bootstrap.screenSecurity.iosScreenCaptureOverlay ||
          iosScreenshotProtectionEnabled,
    _ => false,
  };
}

bool mobileNativeScreenSecurityFallbackForPlatform(String platform) {
  final platformKey = platform.trim().toLowerCase();
  return platformKey == 'android' || platformKey == 'ios';
}

bool mobileNativeScreenSecurityLocksOnCapture(
  MobileScreenSecurityConfig config,
  String platform,
) {
  final platformKey = platform.trim().toLowerCase();
  if (platformKey == 'android') return true;
  if (platformKey != 'ios') return false;
  if (config.iosExitApp) return true;

  final policy = config.iosScreenshotPolicy.trim().toLowerCase();
  if ({'none', 'off', 'disabled'}.contains(policy)) return false;
  if ({
    'overlay',
    'overlay_only',
    'monitor',
    'monitor_only',
    'report_only',
  }.contains(policy)) {
    return false;
  }
  return true;
}

bool mobileWebPrivacyGuardAllowedForPlatform(
  MobileBootstrap bootstrap,
  String platform,
) {
  final platformKey = platform.trim().toLowerCase();
  if (platformKey != 'web') return false;

  return webPrivacyModeAllowsGuard(
    bootstrap.screenSecurity.webSensitiveScreenMode,
    watermarkEnabled: bootstrap.screenSecurity.webWatermarkEnabled,
  );
}

bool mobileWebPrivacyGuardFallbackForPlatform(String platform) {
  return platform.trim().toLowerCase() == 'web';
}

bool mobileCustomerRouteAllowed(MobileBootstrap? bootstrap, String route) {
  if (bootstrap == null) return true;
  final path = _customerFeaturePath(route);
  final policy = _customerRouteFeaturePolicy(path);
  if (policy == null) return true;
  return _featureKeysAllowed(bootstrap.featureFlags, policy.featureKeys);
}

String? mobileCustomerDisabledRouteRedirect(
  MobileBootstrap? bootstrap,
  String route,
) {
  if (mobileCustomerRouteAllowed(bootstrap, route)) return null;
  final path = _customerFeaturePath(route);
  final fallbacks = _customerRouteFallbacks(path);
  for (final fallback in fallbacks) {
    if (fallback == path) continue;
    if (mobileCustomerRouteAllowed(bootstrap, fallback)) return fallback;
  }
  return path == '/' ? null : '/';
}

bool _featureKeysAllowed(MobileFeatureFlags flags, Iterable<String> keys) {
  for (final key in keys) {
    if (flags.contains(key) && !flags.enabled(key)) return false;
  }
  return true;
}

_CustomerRouteFeaturePolicy? _customerRouteFeaturePolicy(String path) {
  for (final policy in _customerRouteFeaturePolicies) {
    if (policy.matches(path)) return policy;
  }
  return null;
}

List<String> _customerRouteFallbacks(String path) {
  if (_pathMatchesAny(path, const ['/topup'])) {
    return const ['/my-wallet', '/profile', '/'];
  }
  if (_pathMatchesAny(path, const ['/cart', '/checkout'])) {
    return const ['/buy', '/'];
  }
  if (_pathMatchesAny(path, const [
    '/support',
    '/tickets',
    '/my-wallet',
    '/reward-claims',
    '/activity-claims',
    '/affiliate',
    '/profile/auto-reward',
    '/profile/line-notifications',
    '/profile/reward-bank',
    '/profile/biometrics',
    '/profile/passkeys',
    '/profile/social-accounts',
    '/profile/account-deletion',
    '/purchase-history',
  ])) {
    return const ['/profile', '/'];
  }
  if (_pathMatchesAny(path, const ['/buy', '/search', '/stores'])) {
    return const ['/'];
  }
  return const ['/'];
}

bool _pathMatchesAny(String path, Iterable<String> prefixes) {
  return prefixes.any(
    (prefix) => path == prefix || path.startsWith('$prefix/'),
  );
}

String _customerFeaturePath(String route) {
  final trimmed = route.trim();
  if (trimmed.isEmpty) return '/';

  final decoded = _decodeCustomerFeatureRouteValue(trimmed);
  if (decoded != trimmed) {
    final decodedPath = _customerFeaturePath(decoded);
    if (decodedPath.isNotEmpty) return decodedPath;
  }

  final queryOnly = _customerFeatureRouteQuery(trimmed);
  if (queryOnly.isNotEmpty) {
    final queryPath = _customerFeaturePathFromQuery(Uri(query: queryOnly));
    if (queryPath.isNotEmpty) return queryPath;
  }

  final uri = Uri.tryParse(trimmed);
  if (uri != null) {
    final fragmentPath = _customerFeaturePathFromFragment(uri.fragment);
    if (fragmentPath.isNotEmpty) return fragmentPath;

    final queryPath = _customerFeaturePathFromQuery(uri);
    if (queryPath.isNotEmpty) return queryPath;

    final hasUrlShape =
        uri.hasScheme ||
        trimmed.startsWith('//') ||
        trimmed.startsWith('/') ||
        trimmed.startsWith('?');
    if (hasUrlShape) return _customerFeaturePlainPath(uri.path);
  }

  final withoutQuery = trimmed.split('?').first.split('#').first.trim();
  return _customerFeaturePlainPath(withoutQuery);
}

String _customerFeaturePathFromQuery(Uri uri) {
  for (final key in _customerFeatureRouteKeys) {
    final value = uri.queryParameters[key]?.trim() ?? '';
    if (value.isEmpty) continue;
    return _customerFeaturePath(value);
  }
  return '';
}

String _customerFeaturePathFromFragment(String fragment) {
  final decoded = _decodeCustomerFeatureRouteValue(fragment.trim());
  final trimmed = decoded.startsWith('!')
      ? decoded.substring(1).trim()
      : decoded;
  if (trimmed.isEmpty) return '';

  final queryOnly = _customerFeatureRouteQuery(trimmed);
  if (queryOnly.isNotEmpty) {
    final queryPath = _customerFeaturePathFromQuery(Uri(query: queryOnly));
    if (queryPath.isNotEmpty) return queryPath;
  }

  final uri = Uri.tryParse(trimmed.startsWith('/') ? trimmed : '/$trimmed');
  if (uri != null) {
    final queryPath = _customerFeaturePathFromQuery(uri);
    if (queryPath.isNotEmpty) return queryPath;
  }
  return _customerFeaturePlainPath(uri?.path ?? trimmed);
}

String _customerFeatureRouteQuery(String value) {
  final trimmed = value.trim();
  if (trimmed.startsWith('?')) return trimmed.substring(1);
  final startsWithRouteKey = _customerFeatureRouteKeys.any(
    (key) => trimmed.startsWith('$key='),
  );
  if (!startsWithRouteKey) return '';
  return trimmed;
}

String _decodeCustomerFeatureRouteValue(String value) {
  if (!value.contains('%')) return value;
  try {
    final decoded = Uri.decodeComponent(value).trim();
    return decoded.isEmpty ? value : decoded;
  } catch (_) {
    return value;
  }
}

String _customerFeaturePlainPath(String value) {
  final path = value.trim();
  if (path.isEmpty) return '/';
  final normalized = path.startsWith('/') ? path : '/$path';
  if (normalized.length == 1) return normalized;
  return normalized.replaceFirst(RegExp(r'/+$'), '');
}

const _customerFeatureRouteKeys = [
  'route',
  'routeName',
  'route_name',
  'routePath',
  'route_path',
  'routeFullPath',
  'route_full_path',
  'routeUrl',
  'route_url',
  'currentRoute',
  'current_route',
  'activeRoute',
  'active_route',
  'targetRoute',
  'target_route',
  'path',
  'fullPath',
  'full_path',
  'screen',
  'screenName',
  'screen_name',
  'screenUrl',
  'screen_url',
  'page',
  'pageName',
  'page_name',
  'pageUrl',
  'page_url',
  'url',
  'urlString',
  'url_string',
  'currentUrl',
  'current_url',
  'activeUrl',
  'active_url',
  'targetUrl',
  'target_url',
  'webUrl',
  'web_url',
  'deepLink',
  'deep_link',
  'deepLinkUrl',
  'deep_link_url',
  'appLink',
  'app_link',
  'appLinkUrl',
  'app_link_url',
  'universalLink',
  'universal_link',
  'returnUrl',
  'return_url',
  'redirect',
  'redirectUrl',
  'redirect_url',
  'redirectUri',
  'redirect_uri',
  'continueUrl',
  'continue_url',
  'callbackUrl',
  'callback_url',
  'fragment',
  'hash',
  'hashRoute',
  'hash_route',
  'query',
  'queryString',
  'query_string',
  'location',
  'href',
  'uri',
  'link',
  'linkUrl',
  'link_url',
];

class _CustomerRouteFeaturePolicy {
  const _CustomerRouteFeaturePolicy({
    required this.prefixes,
    required this.featureKeys,
  });

  final List<String> prefixes;
  final List<String> featureKeys;

  bool matches(String path) => _pathMatchesAny(path, prefixes);
}

const _customerRouteFeaturePolicies = [
  _CustomerRouteFeaturePolicy(
    prefixes: ['/buy', '/search', '/stores'],
    featureKeys: [
      'lottery',
      'buy',
      'buy_search',
      'lottery_purchase',
      'store_stock',
    ],
  ),
  _CustomerRouteFeaturePolicy(
    prefixes: ['/cart'],
    featureKeys: ['lottery', 'cart', 'lottery_cart'],
  ),
  _CustomerRouteFeaturePolicy(
    prefixes: ['/checkout'],
    featureKeys: ['lottery', 'checkout', 'lottery_checkout'],
  ),
  _CustomerRouteFeaturePolicy(
    prefixes: ['/tickets'],
    featureKeys: ['lottery', 'tickets', 'customer_tickets'],
  ),
  _CustomerRouteFeaturePolicy(
    prefixes: ['/result', '/results'],
    featureKeys: ['lottery', 'results', 'lottery_results', 'reward_check'],
  ),
  _CustomerRouteFeaturePolicy(
    prefixes: ['/waiting-result', '/wait-result'],
    featureKeys: [
      'lottery',
      'results',
      'lottery_results',
      'reward_check',
      'waiting_result',
    ],
  ),
  _CustomerRouteFeaturePolicy(
    prefixes: ['/my-wallet'],
    featureKeys: ['wallet', 'my_wallet', 'customer_wallet'],
  ),
  _CustomerRouteFeaturePolicy(
    prefixes: ['/topup'],
    featureKeys: ['wallet', 'topup', 'wallet_topup'],
  ),
  _CustomerRouteFeaturePolicy(
    prefixes: ['/reward-claims'],
    featureKeys: ['wallet', 'reward_claims', 'reward_claim', 'ticket_claims'],
  ),
  _CustomerRouteFeaturePolicy(
    prefixes: ['/activity-claims'],
    featureKeys: ['wallet', 'activity_claims', 'activity_claim'],
  ),
  _CustomerRouteFeaturePolicy(
    prefixes: ['/activities'],
    featureKeys: ['activities', 'activity'],
  ),
  _CustomerRouteFeaturePolicy(
    prefixes: ['/affiliate'],
    featureKeys: ['affiliate', 'referral'],
  ),
  _CustomerRouteFeaturePolicy(
    prefixes: ['/profile/auto-reward'],
    featureKeys: ['auto_reward', 'profile_auto_reward'],
  ),
  _CustomerRouteFeaturePolicy(
    prefixes: ['/profile/line-notifications'],
    featureKeys: [
      'line_notifications',
      'line_notification',
      'profile_line_notifications',
    ],
  ),
  _CustomerRouteFeaturePolicy(
    prefixes: ['/profile/reward-bank'],
    featureKeys: ['reward_bank', 'profile_reward_bank', 'payout_bank'],
  ),
  _CustomerRouteFeaturePolicy(
    prefixes: ['/profile/biometrics'],
    featureKeys: [
      'biometrics',
      'profile_biometrics',
      'native_biometric_unlock',
    ],
  ),
  _CustomerRouteFeaturePolicy(
    prefixes: ['/profile/passkeys'],
    featureKeys: ['passkey_login', 'passkeys', 'profile_passkeys'],
  ),
  _CustomerRouteFeaturePolicy(
    prefixes: ['/profile/account-deletion'],
    featureKeys: ['account_deletion', 'profile_account_deletion'],
  ),
  _CustomerRouteFeaturePolicy(
    prefixes: ['/purchase-history'],
    featureKeys: ['purchase_history', 'orders', 'order_history'],
  ),
  _CustomerRouteFeaturePolicy(
    prefixes: ['/news'],
    featureKeys: ['news', 'announcements'],
  ),
];
