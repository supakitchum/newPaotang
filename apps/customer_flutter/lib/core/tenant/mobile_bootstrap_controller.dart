import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../i18n/app_locale.dart';
import '../payment/checkout_payment_config.dart';
import '../theme/app_theme.dart';
import 'mobile_bootstrap_repository.dart';

final mobileBootstrapProvider = FutureProvider<MobileBootstrap>((ref) async {
  final config = ref.watch(appConfigProvider);
  final data = await ref.watch(mobileBootstrapRepositoryProvider).load();
  return MobileBootstrap.fromJson(
    data,
    defaultLocale: config.defaultLocale,
    defaultSiteName: config.runtimeDisplayName,
  );
});

class MobileBootstrap {
  const MobileBootstrap({
    required this.siteName,
    required this.tenantId,
    required this.locale,
    required this.supportPhone,
    required this.brand,
    required this.theme,
    required this.authProviders,
    required this.line,
    required this.realtime,
    required this.live,
    required this.lotteryProductLabel,
    required this.ticketImageWatermark,
    this.payment = const MobilePaymentConfig.defaults(),
    required this.biometric,
    required this.screenSecurity,
    required this.featureFlags,
    required this.termsContent,
    required this.privacyContent,
    required this.privacyPolicyUrl,
    required this.accountDeletionUrl,
    required this.maintenance,
  });

  factory MobileBootstrap.fromJson(
    Map<String, dynamic> json, {
    String defaultLocale = 'th-TH',
    String defaultSiteName = 'Customer',
  }) {
    final mobile = json['mobile'] is Map<String, dynamic>
        ? json['mobile'] as Map<String, dynamic>
        : <String, dynamic>{};
    final site = json['site'] is Map<String, dynamic>
        ? json['site'] as Map<String, dynamic>
        : <String, dynamic>{};
    final legal = json['legal'] is Map<String, dynamic>
        ? json['legal'] as Map<String, dynamic>
        : <String, dynamic>{};
    final brand = json['brand'] is Map<String, dynamic>
        ? json['brand'] as Map<String, dynamic>
        : <String, dynamic>{};
    final theme = json['theme'] is Map<String, dynamic>
        ? json['theme'] as Map<String, dynamic>
        : <String, dynamic>{};
    final maintenance = json['maintenance'] is Map<String, dynamic>
        ? json['maintenance'] as Map<String, dynamic>
        : <String, dynamic>{};
    final providers = mobile['auth_providers'] is List
        ? (mobile['auth_providers'] as List)
            .whereType<Map>()
            .map(
              (value) => SocialAuthProvider.fromJson(
                Map<String, dynamic>.from(value),
              ),
            )
            .where((value) => value.enabled && value.supported)
            .toList()
        : <SocialAuthProvider>[];
    final biometric = mobile['biometric'] is Map<String, dynamic>
        ? mobile['biometric'] as Map<String, dynamic>
        : <String, dynamic>{};
    final screenSecurity = mobile['screen_security'] is Map<String, dynamic>
        ? mobile['screen_security'] as Map<String, dynamic>
        : <String, dynamic>{};
    final featureFlags = mobile['feature_flags'] is Map<String, dynamic>
        ? mobile['feature_flags'] as Map<String, dynamic>
        : <String, dynamic>{};
    final line = mobile['line'] is Map<String, dynamic>
        ? mobile['line'] as Map<String, dynamic>
        : json['line'] is Map<String, dynamic>
            ? json['line'] as Map<String, dynamic>
            : <String, dynamic>{};
    final realtime = mobile['realtime'] is Map<String, dynamic>
        ? mobile['realtime'] as Map<String, dynamic>
        : <String, dynamic>{};
    final live = mobile['live'] is Map<String, dynamic>
        ? mobile['live'] as Map<String, dynamic>
        : json['live'] is Map<String, dynamic>
            ? json['live'] as Map<String, dynamic>
            : <String, dynamic>{};
    final payment = mobile['payment'] is Map<String, dynamic>
        ? mobile['payment'] as Map<String, dynamic>
        : json['payment'] is Map<String, dynamic>
            ? json['payment'] as Map<String, dynamic>
            : <String, dynamic>{};

    final lotteryProductLabel = (mobile['lottery_product_label'] ??
            mobile['product_marker'] ??
            json['lottery_product_label'] ??
            json['product_marker'] ??
            '')
        .toString()
        .trim();
    final ticketImageWatermark = (mobile['ticket_image_watermark'] ??
            mobile['lottery_ticket_image_watermark'] ??
            json['ticket_image_watermark'] ??
            json['lottery_ticket_image_watermark'] ??
            lotteryProductLabel)
        .toString()
        .trim();

    return MobileBootstrap(
      siteName: site['display_name']?.toString() ??
          site['site_name']?.toString() ??
          defaultSiteName,
      tenantId: json['tenant_id']?.toString() ?? '',
      locale: parseCustomerLocale(
        site['locale']?.toString() ?? mobile['locale']?.toString(),
        fallback: parseCustomerLocale(defaultLocale),
      ),
      supportPhone: site['support_phone']?.toString() ?? '',
      brand: MobileBrandConfig.fromJson(brand),
      theme: AppThemeTokens.fromJson(theme),
      authProviders: providers,
      line: MobileLineConfig.fromJson(line),
      realtime: MobileRealtimeConfig.fromJson(realtime),
      live: MobileLiveConfig.fromJson(live),
      lotteryProductLabel: lotteryProductLabel,
      ticketImageWatermark: ticketImageWatermark,
      payment: MobilePaymentConfig.fromJson(payment),
      biometric: MobileBiometricConfig.fromJson(biometric),
      screenSecurity: MobileScreenSecurityConfig.fromJson(screenSecurity),
      featureFlags: MobileFeatureFlags.fromJson(featureFlags),
      termsContent: legal['terms_content']?.toString() ?? '',
      privacyContent: legal['privacy_content']?.toString() ?? '',
      privacyPolicyUrl: legal['privacy_policy_url']?.toString().trim() ?? '',
      accountDeletionUrl:
          legal['account_deletion_url']?.toString().trim() ?? '',
      maintenance: MaintenanceConfig.fromJson(maintenance),
    );
  }

  final String siteName;
  final String tenantId;
  final Locale locale;
  final String supportPhone;
  final MobileBrandConfig brand;
  final AppThemeTokens theme;
  final List<SocialAuthProvider> authProviders;
  final MobileLineConfig line;
  final MobileRealtimeConfig realtime;
  final MobileLiveConfig live;
  final String lotteryProductLabel;
  final String ticketImageWatermark;
  final MobilePaymentConfig payment;
  final MobileBiometricConfig biometric;
  final MobileScreenSecurityConfig screenSecurity;
  final MobileFeatureFlags featureFlags;
  final String termsContent;
  final String privacyContent;
  final String privacyPolicyUrl;
  final String accountDeletionUrl;
  final MaintenanceConfig maintenance;
}

class MobilePaymentConfig {
  const MobilePaymentConfig({
    required this.checkoutPaymentMethod,
    required this.checkoutPaymentMethods,
  });

  const MobilePaymentConfig.defaults()
      : checkoutPaymentMethod = checkoutPaymentMethodWallet,
        checkoutPaymentMethods = const [checkoutPaymentMethodWallet];

  factory MobilePaymentConfig.fromJson(Map<String, dynamic> json) {
    var methods = normalizeCheckoutPaymentMethods(
      json['checkout_payment_methods'] ??
          json['checkout_methods'] ??
          json['payment_methods'],
    );
    final method = normalizeCheckoutPaymentMethod(
      json['checkout_payment_method'] ??
          json['default_checkout_payment_method'] ??
          json['default_checkout_method'] ??
          (methods.isNotEmpty ? methods.first : null),
    );
    if (!methods.contains(method)) {
      methods = [method, ...methods];
    }
    return MobilePaymentConfig(
      checkoutPaymentMethod: method,
      checkoutPaymentMethods: methods,
    );
  }

  final String checkoutPaymentMethod;
  final List<String> checkoutPaymentMethods;
}

class MobileLiveConfig {
  const MobileLiveConfig({
    required this.waitingResultYoutubeUrl,
    required this.waitingResultYoutubeEmbedUrl,
    required this.source,
  });

  factory MobileLiveConfig.fromJson(Map<String, dynamic> json) {
    return MobileLiveConfig(
      waitingResultYoutubeUrl:
          json['waiting_result_youtube_url']?.toString().trim() ?? '',
      waitingResultYoutubeEmbedUrl:
          json['waiting_result_youtube_embed_url']?.toString().trim() ?? '',
      source: json['source']?.toString().trim() ?? 'not_configured',
    );
  }

  final String waitingResultYoutubeUrl;
  final String waitingResultYoutubeEmbedUrl;
  final String source;

  bool get configured =>
      waitingResultYoutubeEmbedUrl.isNotEmpty ||
      waitingResultYoutubeUrl.isNotEmpty;

  Uri? get launchUri {
    final raw = waitingResultYoutubeEmbedUrl.isNotEmpty
        ? waitingResultYoutubeEmbedUrl
        : waitingResultYoutubeUrl;
    if (raw.isEmpty) return null;

    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme) return null;
    return uri;
  }
}

class MobileRealtimeConfig {
  const MobileRealtimeConfig({
    required this.enabled,
    required this.url,
    required this.key,
    required this.authEndpoint,
    required this.protocol,
    required this.client,
  });

  factory MobileRealtimeConfig.fromJson(Map<String, dynamic> json) {
    final url = json['url']?.toString().trim() ?? '';
    final key = json['key']?.toString().trim() ?? '';
    final client = json['client']?.toString().trim() ?? '';
    return MobileRealtimeConfig(
      enabled: json['enabled'] == true && url.isNotEmpty && key.isNotEmpty,
      url: url,
      key: key,
      authEndpoint: json['auth_endpoint']?.toString().trim().isNotEmpty == true
          ? json['auth_endpoint'].toString().trim()
          : '/customer/realtime/auth',
      protocol: int.tryParse(json['protocol']?.toString() ?? '') ?? 7,
      client: client.isEmpty ? 'customer-flutter' : client,
    );
  }

  final bool enabled;
  final String url;
  final String key;
  final String authEndpoint;
  final int protocol;
  final String client;

  bool get configured => enabled && url.isNotEmpty && key.isNotEmpty;
}

class MobileLineConfig {
  const MobileLineConfig({
    required this.liffId,
    required this.liffEnabled,
    required this.botBasicId,
    required this.addFriendUrl,
  });

  factory MobileLineConfig.fromJson(Map<String, dynamic> json) {
    final liffId = json['liff_id']?.toString().trim() ?? '';
    final botBasicId = json['bot_basic_id']?.toString().trim() ?? '';

    return MobileLineConfig(
      liffId: liffId,
      liffEnabled: json['liff_enabled'] == true || liffId.isNotEmpty,
      botBasicId: botBasicId,
      addFriendUrl: json['add_friend_url']?.toString().trim() ?? '',
    );
  }

  final String liffId;
  final bool liffEnabled;
  final String botBasicId;
  final String addFriendUrl;

  bool get configured => liffEnabled && liffId.isNotEmpty;
}

class MobileBrandConfig {
  const MobileBrandConfig({
    required this.logoUrl,
    required this.faviconUrl,
    required this.ogImageUrl,
  });

  factory MobileBrandConfig.fromJson(Map<String, dynamic> json) {
    return MobileBrandConfig(
      logoUrl: json['logo_url']?.toString() ?? '',
      faviconUrl: json['favicon_url']?.toString() ?? '',
      ogImageUrl: json['og_image_url']?.toString() ?? '',
    );
  }

  final String logoUrl;
  final String faviconUrl;
  final String ogImageUrl;
}

class SocialAuthProvider {
  const SocialAuthProvider({
    required this.provider,
    required this.label,
    required this.enabled,
  });

  factory SocialAuthProvider.fromJson(Map<String, dynamic> json) {
    final provider = _normalizeSocialProvider(
      json['provider']?.toString() ?? json['key']?.toString() ?? '',
    );
    final label = json['label']?.toString().trim() ?? '';

    return SocialAuthProvider(
      provider: provider,
      label: label.isEmpty ? _defaultSocialProviderLabel(provider) : label,
      enabled: json['enabled'] == true,
    );
  }

  final String provider;
  final String label;
  final bool enabled;

  bool get supported => _supportedSocialProviders.contains(provider);
}

class MobileBiometricConfig {
  const MobileBiometricConfig({
    required this.enabled,
    required this.requiresPinSetup,
    required this.assertionTokenTtlSeconds,
    required this.platforms,
  });

  factory MobileBiometricConfig.fromJson(Map<String, dynamic> json) {
    return MobileBiometricConfig(
      enabled: json['enabled'] != false,
      requiresPinSetup: json['requires_pin_setup'] != false,
      assertionTokenTtlSeconds: int.tryParse(
            json['assertion_token_ttl_seconds']?.toString() ?? '',
          ) ??
          180,
      platforms: _platformMap(json['platforms']),
    );
  }

  final bool enabled;
  final bool requiresPinSetup;
  final int assertionTokenTtlSeconds;
  final Map<String, List<String>> platforms;

  bool supportsPlatform(String platform) {
    return platforms[platform.trim().toLowerCase()]?.isNotEmpty == true;
  }
}

class MobileScreenSecurityConfig {
  const MobileScreenSecurityConfig({
    required this.androidFlagSecure,
    required this.androidProtectRecentAppPreview,
    required this.iosScreenshotPolicy,
    required this.iosScreenCaptureOverlay,
    required this.iosExitApp,
    required this.webSensitiveScreenMode,
    required this.webWatermarkEnabled,
    required this.sensitiveRoutes,
  });

  factory MobileScreenSecurityConfig.fromJson(Map<String, dynamic> json) {
    final android = json['android'] is Map<String, dynamic>
        ? json['android'] as Map<String, dynamic>
        : <String, dynamic>{};
    final ios = json['ios'] is Map<String, dynamic>
        ? json['ios'] as Map<String, dynamic>
        : <String, dynamic>{};
    final web = json['web'] is Map<String, dynamic>
        ? json['web'] as Map<String, dynamic>
        : <String, dynamic>{};
    return MobileScreenSecurityConfig(
      androidFlagSecure: android['flag_secure'] != false,
      androidProtectRecentAppPreview:
          android['protect_recent_app_preview'] != false,
      iosScreenshotPolicy:
          ios['screenshot_policy']?.toString() ?? 'lock_and_blank',
      iosScreenCaptureOverlay: ios['screen_capture_overlay'] != false,
      iosExitApp: ios['exit_app'] == true,
      webSensitiveScreenMode:
          web['sensitive_screen_mode']?.toString() ?? 'limited',
      webWatermarkEnabled: web['watermark_enabled'] == true,
      sensitiveRoutes: _stringList(json['sensitive_routes']),
    );
  }

  final bool androidFlagSecure;
  final bool androidProtectRecentAppPreview;
  final String iosScreenshotPolicy;
  final bool iosScreenCaptureOverlay;
  final bool iosExitApp;
  final String webSensitiveScreenMode;
  final bool webWatermarkEnabled;
  final List<String> sensitiveRoutes;

  bool get nativeProtectionEnabled =>
      androidFlagSecure || iosScreenCaptureOverlay;

  bool isSensitiveRoute(String route) {
    final path = route.trim();
    if (path.isEmpty) return false;
    return sensitiveRoutes.any(
      (sensitive) => path == sensitive || path.startsWith('$sensitive/'),
    );
  }
}

class MobileFeatureFlags {
  const MobileFeatureFlags(this.values);

  factory MobileFeatureFlags.fromJson(Map<String, dynamic> json) {
    return MobileFeatureFlags(
      json.map(
        (key, value) => MapEntry(key, value == true || value == 'true'),
      ),
    );
  }

  final Map<String, bool> values;

  bool enabled(String key, {bool fallback = false}) {
    return values[key] ?? fallback;
  }
}

class MaintenanceConfig {
  const MaintenanceConfig({
    required this.active,
    required this.message,
    required this.expectedEndAt,
    required this.retryAfterSeconds,
  });

  factory MaintenanceConfig.fromJson(Map<String, dynamic> json) {
    return MaintenanceConfig(
      active: json['active'] == true,
      message: json['message']?.toString() ?? '',
      expectedEndAt: json['expected_end_at'],
      retryAfterSeconds: int.tryParse(
        json['retry_after_seconds']?.toString() ?? '',
      ),
    );
  }

  final bool active;
  final String message;
  final Object? expectedEndAt;
  final int? retryAfterSeconds;
}

Map<String, List<String>> _platformMap(Object? value) {
  if (value is! Map) return const {};
  return value.map((key, raw) {
    return MapEntry(
      key.toString().trim().toLowerCase(),
      _stringList(raw),
    );
  });
}

List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return value
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

const _supportedSocialProviders = {'line', 'google', 'apple'};

String _normalizeSocialProvider(String value) {
  return switch (value.trim().toLowerCase()) {
    'gmail' || 'google_login' || 'google_oauth' => 'google',
    'apple_id' || 'sign_in_with_apple' => 'apple',
    'line_login' || 'line_oa' => 'line',
    final provider => provider,
  };
}

String _defaultSocialProviderLabel(String provider) {
  return switch (provider) {
    'google' => 'Google',
    'apple' => 'Apple ID',
    'line' => 'LINE',
    _ => provider,
  };
}
