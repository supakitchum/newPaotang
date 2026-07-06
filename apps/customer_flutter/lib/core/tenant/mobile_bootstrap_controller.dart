import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../i18n/app_locale.dart';
import '../payment/checkout_payment_config.dart';
import '../security/web_privacy_mode.dart';
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
    required this.supportEmail,
    required this.supportUrl,
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
    final mobile = _asMap(json['mobile'] ?? json['mobileConfig']);
    final site = _asMap(json['site'] ?? json['siteConfig']);
    final tenant = _asMap(json['tenant'] ?? site['tenant']);
    final rootAppearance = _runtimeAppearanceConfig(json);
    final mobileAppearance = _runtimeAppearanceConfig(mobile);
    final storeReadiness = _mergeConfigMaps([
      json['store_readiness'],
      json['storeReadiness'],
      json['store_listing'],
      json['storeListing'],
      json['store_listing_metadata'],
      json['storeListingMetadata'],
      json['app_store'],
      json['appStore'],
      json['play_store'],
      json['playStore'],
      site['store_readiness'],
      site['storeReadiness'],
      site['store_listing'],
      site['storeListing'],
      site['store_listing_metadata'],
      site['storeListingMetadata'],
      site['app_store'],
      site['appStore'],
      site['play_store'],
      site['playStore'],
      mobile['store_readiness'],
      mobile['storeReadiness'],
      mobile['store_listing'],
      mobile['storeListing'],
      mobile['store_listing_metadata'],
      mobile['storeListingMetadata'],
      mobile['app_store'],
      mobile['appStore'],
      mobile['play_store'],
      mobile['playStore'],
    ]);
    final compliance = _mergeConfigMaps([
      json['compliance'],
      json['complianceConfig'],
      site['compliance'],
      site['complianceConfig'],
      mobile['compliance'],
      mobile['complianceConfig'],
      storeReadiness['compliance'],
      storeReadiness['complianceConfig'],
    ]);
    final legal = _mergeMaps([
      json['legal'],
      json['legalConfig'],
      json['store_readiness'],
      json['storeReadiness'],
      json['compliance'],
      json['complianceConfig'],
      site['legal'],
      site['legalConfig'],
      site['store_readiness'],
      site['storeReadiness'],
      site['compliance'],
      site['complianceConfig'],
      mobile['legal'],
      mobile['legalConfig'],
      mobile['store_readiness'],
      mobile['storeReadiness'],
      mobile['compliance'],
      mobile['complianceConfig'],
      storeReadiness['legal'],
      storeReadiness['legalConfig'],
      storeReadiness['links'],
      storeReadiness['urls'],
      storeReadiness,
      compliance['legal'],
      compliance['legalConfig'],
      compliance['links'],
      compliance['urls'],
      compliance,
    ]);
    final legalTerms = _mergeMaps([
      legal['terms'],
      legal['terms_of_service'],
      legal['termsOfService'],
    ]);
    final legalPrivacy = _mergeMaps([
      legal['privacy'],
      legal['privacy_policy'],
      legal['privacyPolicy'],
    ]);
    final legalAccountDeletion = _mergeMaps([
      legal['account_deletion'],
      legal['accountDeletion'],
      legal['delete_account'],
      legal['deleteAccount'],
      legal['data_deletion'],
      legal['dataDeletion'],
      legal['deletion'],
    ]);
    final legalPrivacyPolicyLink = _runtimeLinkForAliases(
      [
        legalPrivacy,
        legal['privacy_policy_link'],
        legal['privacyPolicyLink'],
        legal['privacy_link'],
        legal['privacyLink'],
        legal['links'],
        legal['link'],
        legal['urls'],
        legal['url'],
        legal['actions'],
        legal['items'],
        legal,
      ],
      _privacyPolicyLinkAliases,
    );
    final legalAccountDeletionLink = _runtimeLinkForAliases(
      [
        legalAccountDeletion,
        legal['account_deletion_link'],
        legal['accountDeletionLink'],
        legal['delete_account_link'],
        legal['deleteAccountLink'],
        legal['data_deletion_link'],
        legal['dataDeletionLink'],
        legal['links'],
        legal['link'],
        legal['urls'],
        legal['url'],
        legal['actions'],
        legal['items'],
        legal,
      ],
      _accountDeletionLinkAliases,
    );
    final brand = _mergeConfigMaps([
      rootAppearance,
      rootAppearance['brand'],
      rootAppearance['brandConfig'],
      rootAppearance['branding'],
      rootAppearance['brandingConfig'],
      site['brand'],
      site['brandConfig'],
      json['brand'],
      json['brandConfig'],
      mobileAppearance,
      mobileAppearance['brand'],
      mobileAppearance['brandConfig'],
      mobileAppearance['branding'],
      mobileAppearance['brandingConfig'],
      mobile['brand'],
      mobile['brandConfig'],
    ]);
    final theme = _mergeConfigMaps([
      rootAppearance,
      rootAppearance['theme'],
      rootAppearance['themeConfig'],
      rootAppearance['designTokens'],
      rootAppearance['design_tokens'],
      site['theme'],
      site['themeConfig'],
      json['theme'],
      json['themeConfig'],
      mobileAppearance,
      mobileAppearance['theme'],
      mobileAppearance['themeConfig'],
      mobileAppearance['designTokens'],
      mobileAppearance['design_tokens'],
      mobile['theme'],
      mobile['themeConfig'],
    ]);
    final maintenance = _mergeConfigMaps([
      _maintenanceFlatConfig(json),
      json['maintenance'],
      json['maintenanceConfig'],
      json['maintenance_mode'],
      json['maintenanceMode'],
      _maintenanceFlatConfig(site),
      site['maintenance'],
      site['maintenanceConfig'],
      site['maintenance_mode'],
      site['maintenanceMode'],
      _maintenanceFlatConfig(mobile),
      mobile['maintenance'],
      mobile['maintenanceConfig'],
      mobile['maintenance_mode'],
      mobile['maintenanceMode'],
    ]);
    final auth = _mergeConfigMaps([
      json['auth'],
      json['authConfig'],
      json['authentication'],
      json['authenticationConfig'],
      mobile['auth'],
      mobile['authConfig'],
      mobile['authentication'],
      mobile['authenticationConfig'],
    ]);
    final social = _mergeConfigMaps([
      json['social'],
      json['socialConfig'],
      json['socialAuth'],
      json['socialAuthConfig'],
      json['socialLogin'],
      json['socialLoginConfig'],
      auth['social'],
      auth['socialConfig'],
      auth['socialAuth'],
      auth['socialAuthConfig'],
      auth['socialLogin'],
      auth['socialLoginConfig'],
      mobile['social'],
      mobile['socialConfig'],
      mobile['socialAuth'],
      mobile['socialAuthConfig'],
      mobile['socialLogin'],
      mobile['socialLoginConfig'],
    ]);
    final providerRows = _socialProviderRows([
      auth,
      social,
      auth['providers'],
      auth['auth_providers'],
      auth['authProviders'],
      auth['social_providers'],
      auth['socialProviders'],
      social['providers'],
      social['auth_providers'],
      social['authProviders'],
      social['social_providers'],
      social['socialProviders'],
      mobile['auth_providers'],
      mobile['authProviders'],
      mobile['social_providers'],
      mobile['socialProviders'],
      json['auth_providers'],
      json['authProviders'],
      json['social_providers'],
      json['socialProviders'],
    ]);
    final seenProviders = <String>{};
    final providers = providerRows
        .map(SocialAuthProvider.fromJson)
        .where((value) => value.enabled && value.supported)
        .where((value) => seenProviders.add(value.provider))
        .toList(growable: false);
    final security = _mergeConfigMaps([
      json['security'],
      json['securityConfig'],
      json['mobileSecurity'],
      json['mobileSecurityConfig'],
      mobile['security'],
      mobile['securityConfig'],
      mobile['mobileSecurity'],
      mobile['mobileSecurityConfig'],
    ]);
    final biometric = _mergeConfigMaps([
      security['biometric'],
      security['biometricConfig'],
      security['biometrics'],
      security['biometricsConfig'],
      json['biometric'],
      json['biometricConfig'],
      json['biometrics'],
      json['biometricsConfig'],
      json['nativeBiometric'],
      json['nativeBiometricConfig'],
      mobile['biometric'],
      mobile['biometricConfig'],
      mobile['biometrics'],
      mobile['biometricsConfig'],
      mobile['nativeBiometric'],
      mobile['nativeBiometricConfig'],
    ]);
    final screenSecurity = _mergeMaps([
      _screenSecurityFlatConfig(json),
      _screenSecurityFlatConfig(mobile),
      _screenSecurityFlatConfig(security),
      json['screen_security'],
      json['screenSecurity'],
      security['screen_security'],
      security['screenSecurity'],
      mobile['screen_security'],
      mobile['screenSecurity'],
    ]);
    final featureFlags = _mergeFeatureFlagMaps([
      tenant['features'],
      tenant['feature_flags'],
      tenant['featureFlags'],
      site['features'],
      site['feature_flags'],
      site['featureFlags'],
      json['features'],
      json['feature_flags'],
      json['featureFlags'],
      json['feature_config'],
      json['featureConfig'],
      json['featureToggles'],
      json['feature_toggles'],
      json['plugins'],
      json['pluginConfig'],
      json['plugin_config'],
      json['pluginSettings'],
      json['plugin_settings'],
      json['enabledPlugins'],
      json['enabled_plugins'],
      json['modules'],
      json['capabilities'],
      mobile['features'],
      mobile['feature_flags'],
      mobile['featureFlags'],
      mobile['feature_config'],
      mobile['featureConfig'],
      mobile['featureToggles'],
      mobile['feature_toggles'],
      mobile['plugins'],
      mobile['pluginConfig'],
      mobile['plugin_config'],
      mobile['pluginSettings'],
      mobile['plugin_settings'],
      mobile['enabledPlugins'],
      mobile['enabled_plugins'],
      mobile['modules'],
      mobile['capabilities'],
    ]);
    final contact = _mergeMaps([
      json['contact'],
      json['contactConfig'],
      json['support'],
      json['supportConfig'],
      site['contact'],
      site['contactConfig'],
      site['support'],
      site['supportConfig'],
      mobile['contact'],
      mobile['contactConfig'],
      mobile['support'],
      mobile['supportConfig'],
      storeReadiness['contact'],
      storeReadiness['contactConfig'],
      storeReadiness['support'],
      storeReadiness['supportConfig'],
      storeReadiness['developer_contact'],
      storeReadiness['developerContact'],
      storeReadiness['developer_support'],
      storeReadiness['developerSupport'],
      storeReadiness['customer_support'],
      storeReadiness['customerSupport'],
      storeReadiness['help_center'],
      storeReadiness['helpCenter'],
      storeReadiness,
      compliance['contact'],
      compliance['contactConfig'],
      compliance['support'],
      compliance['supportConfig'],
      compliance['developer_contact'],
      compliance['developerContact'],
      compliance['customer_support'],
      compliance['customerSupport'],
    ]);
    final contactSupportLink = _runtimeLinkForAliases(
      [
        contact['support_link'],
        contact['supportLink'],
        contact['support_url'],
        contact['supportUrl'],
        contact['help_url'],
        contact['helpUrl'],
        contact['contact_url'],
        contact['contactUrl'],
        contact['links'],
        contact['link'],
        contact['urls'],
        contact['url'],
        contact['actions'],
        contact['items'],
        contact['channels'],
        contact,
      ],
      _supportLinkAliases,
    );
    final line = _mergeConfigMaps([
      _lineConfigMap(json['line']),
      _lineConfigMap(json['lineConfig']),
      _lineConfigMap(json['line_login']),
      _lineConfigMap(json['lineLogin']),
      _lineConfigMap(auth['line']),
      _lineConfigMap(auth['lineConfig']),
      _lineConfigMap(auth['line_login']),
      _lineConfigMap(auth['lineLogin']),
      _lineConfigMap(social['line']),
      _lineConfigMap(social['lineConfig']),
      _lineConfigMap(social['line_login']),
      _lineConfigMap(social['lineLogin']),
      _lineConfigMap(mobile['line']),
      _lineConfigMap(mobile['lineConfig']),
      _lineConfigMap(mobile['line_login']),
      _lineConfigMap(mobile['lineLogin']),
    ]);
    final realtime = _mergeConfigMaps([
      _realtimeConfigMap(json['realtime']),
      _realtimeConfigMap(json['realtimeConfig']),
      _realtimeConfigMap(json['real_time']),
      _realtimeConfigMap(json['realTime']),
      _realtimeConfigMap(json['broadcast']),
      _realtimeConfigMap(json['broadcastConfig']),
      _realtimeConfigMap(json['broadcasting']),
      _realtimeConfigMap(json['broadcastingConfig']),
      _realtimeConfigMap(json['websocket']),
      _realtimeConfigMap(json['webSocket']),
      _realtimeConfigMap(json['websocketConfig']),
      _realtimeConfigMap(json['webSocketConfig']),
      _realtimeConfigMap(json['pusher']),
      _realtimeConfigMap(json['pusherConfig']),
      _realtimeConfigMap(mobile['realtime']),
      _realtimeConfigMap(mobile['realtimeConfig']),
      _realtimeConfigMap(mobile['real_time']),
      _realtimeConfigMap(mobile['realTime']),
      _realtimeConfigMap(mobile['broadcast']),
      _realtimeConfigMap(mobile['broadcastConfig']),
      _realtimeConfigMap(mobile['broadcasting']),
      _realtimeConfigMap(mobile['broadcastingConfig']),
      _realtimeConfigMap(mobile['websocket']),
      _realtimeConfigMap(mobile['webSocket']),
      _realtimeConfigMap(mobile['websocketConfig']),
      _realtimeConfigMap(mobile['webSocketConfig']),
      _realtimeConfigMap(mobile['pusher']),
      _realtimeConfigMap(mobile['pusherConfig']),
    ]);
    final live = _mergeConfigMaps([
      _liveConfigMap(json['live']),
      _liveConfigMap(json['liveConfig']),
      _liveConfigMap(mobile['live']),
      _liveConfigMap(mobile['liveConfig']),
    ]);
    final payment = _mergeConfigMaps([
      json['payment'],
      json['paymentConfig'],
      json['payments'],
      json['paymentsConfig'],
      json['checkout'],
      json['checkoutConfig'],
      json['checkoutPayment'],
      json['checkoutPaymentConfig'],
      json['checkout_payment'],
      json['checkout_payment_config'],
      mobile['payment'],
      mobile['paymentConfig'],
      mobile['payments'],
      mobile['paymentsConfig'],
      mobile['checkout'],
      mobile['checkoutConfig'],
      mobile['checkoutPayment'],
      mobile['checkoutPaymentConfig'],
      mobile['checkout_payment'],
      mobile['checkout_payment_config'],
    ]);

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
      siteName: _stringFrom(
        [
          site['display_name'],
          site['displayName'],
          site['site_name'],
          site['siteName'],
          site['name'],
          site['title'],
          json['site_name'],
          json['siteName'],
        ],
        fallback: defaultSiteName,
      ),
      tenantId: _stringFrom([
        json['tenant_id'],
        json['tenantId'],
        site['tenant_id'],
        site['tenantId'],
        tenant['id'],
        tenant['tenant_id'],
        tenant['tenantId'],
        tenant['uuid'],
      ]),
      locale: parseCustomerLocale(
        site['locale']?.toString() ?? mobile['locale']?.toString(),
        fallback: parseCustomerLocale(defaultLocale),
      ),
      supportPhone: _runtimeContactValueFrom(
        [
          site['support_phone'],
          site['supportPhone'],
          json['support_phone'],
          json['supportPhone'],
          mobile['support_phone'],
          mobile['supportPhone'],
          contact['support_phone'],
          contact['supportPhone'],
          contact['phone'],
          contact['phoneNumber'],
          contact['tel'],
          contact['telephone'],
          contact['channels'],
          contact['contacts'],
          contact['items'],
          contact['rows'],
          contact,
        ],
        _supportPhoneContactAliases,
      ),
      supportEmail: _runtimeContactValueFrom(
        [
          site['support_email'],
          site['supportEmail'],
          json['support_email'],
          json['supportEmail'],
          mobile['support_email'],
          mobile['supportEmail'],
          contact['support_email'],
          contact['supportEmail'],
          contact['email'],
          contact['emailAddress'],
          contact['mail'],
          contact['channels'],
          contact['contacts'],
          contact['items'],
          contact['rows'],
          contact,
        ],
        _supportEmailContactAliases,
      ),
      supportUrl: _runtimeUrlFrom([
        site['support_url'],
        site['supportUrl'],
        site['store_support_url'],
        site['storeSupportUrl'],
        site['help_url'],
        site['helpUrl'],
        site['contact_url'],
        site['contactUrl'],
        json['support_url'],
        json['supportUrl'],
        json['store_support_url'],
        json['storeSupportUrl'],
        json['help_url'],
        json['helpUrl'],
        json['contact_url'],
        json['contactUrl'],
        mobile['support_url'],
        mobile['supportUrl'],
        mobile['store_support_url'],
        mobile['storeSupportUrl'],
        mobile['help_url'],
        mobile['helpUrl'],
        mobile['contact_url'],
        mobile['contactUrl'],
        contact['support_url'],
        contact['supportUrl'],
        contact['store_support_url'],
        contact['storeSupportUrl'],
        contact['help_url'],
        contact['helpUrl'],
        contact['contact_url'],
        contact['contactUrl'],
        contact['url'],
        contact['href'],
        contact['link'],
        contactSupportLink,
      ]),
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
      termsContent: _runtimeTextFrom([
        legal['terms_content'],
        legal['termsContent'],
        legal['terms_text'],
        legal['termsText'],
        legal['terms'],
        legalTerms['content'],
        legalTerms['body'],
        legalTerms['text'],
      ]),
      privacyContent: _runtimeTextFrom([
        legal['privacy_content'],
        legal['privacyContent'],
        legal['privacy_text'],
        legal['privacyText'],
        legal['privacy_policy_content'],
        legal['privacyPolicyContent'],
        legal['privacy'],
        legalPrivacy['content'],
        legalPrivacy['body'],
        legalPrivacy['text'],
      ]),
      privacyPolicyUrl: _runtimeUrlFrom([
        legal['privacy_policy_url'],
        legal['privacyPolicyUrl'],
        legal['privacy_url'],
        legal['privacyUrl'],
        legal['privacy_policy_link'],
        legal['privacyPolicyLink'],
        legal['privacy_link'],
        legal['privacyLink'],
        legalPrivacy['url'],
        legalPrivacy['policy_url'],
        legalPrivacy['policyUrl'],
        legalPrivacy['href'],
        legalPrivacy['link'],
        legalPrivacyPolicyLink,
      ]),
      accountDeletionUrl: _runtimeUrlFrom([
        legal['account_deletion_url'],
        legal['accountDeletionUrl'],
        legal['account_deletion_link'],
        legal['accountDeletionLink'],
        legal['delete_account_url'],
        legal['deleteAccountUrl'],
        legal['account_delete_url'],
        legal['accountDeleteUrl'],
        legal['data_deletion_url'],
        legal['dataDeletionUrl'],
        legal['deletion_url'],
        legal['deletionUrl'],
        legal['request_url'],
        legal['requestUrl'],
        legalAccountDeletion['url'],
        legalAccountDeletion['request_url'],
        legalAccountDeletion['requestUrl'],
        legalAccountDeletion['href'],
        legalAccountDeletion['link'],
        legalAccountDeletionLink,
      ]),
      maintenance: MaintenanceConfig.fromJson(maintenance),
    );
  }

  final String siteName;
  final String tenantId;
  final Locale locale;
  final String supportPhone;
  final String supportEmail;
  final String supportUrl;
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
      [
        json['checkout_payment_methods'],
        json['checkoutPaymentMethods'],
        json['checkout_methods'],
        json['checkoutMethods'],
        json['enabled_checkout_payment_methods'],
        json['enabledCheckoutPaymentMethods'],
        json['payment_methods'],
        json['paymentMethods'],
        json['enabled_payment_methods'],
        json['enabledPaymentMethods'],
        json['enabled_methods'],
        json['enabledMethods'],
        json['methods'],
        json['items'],
      ],
    );
    final method = normalizeCheckoutPaymentMethod(
      json['checkout_payment_method'] ??
          json['checkoutPaymentMethod'] ??
          json['default_checkout_payment_method'] ??
          json['defaultCheckoutPaymentMethod'] ??
          json['default_checkout_method'] ??
          json['defaultCheckoutMethod'] ??
          json['default_payment_method'] ??
          json['defaultPaymentMethod'] ??
          json['default_method'] ??
          json['defaultMethod'] ??
          json['selected_method'] ??
          json['selectedMethod'] ??
          json['preferred_method'] ??
          json['preferredMethod'] ??
          json['method'] ??
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
      waitingResultYoutubeUrl: _stringFrom([
        json['waiting_result_youtube_url'],
        json['waitingResultYoutubeUrl'],
        json['waiting_result_url'],
        json['waitingResultUrl'],
        json['youtube_url'],
        json['youtubeUrl'],
        json['url'],
      ]),
      waitingResultYoutubeEmbedUrl: _stringFrom([
        json['waiting_result_youtube_embed_url'],
        json['waitingResultYoutubeEmbedUrl'],
        json['waiting_result_embed_url'],
        json['waitingResultEmbedUrl'],
        json['youtube_embed_url'],
        json['youtubeEmbedUrl'],
        json['embed_url'],
        json['embedUrl'],
      ]),
      source: _stringFrom(
        [
          json['source'],
          json['provider'],
          json['sourceName'],
          json['source_name'],
        ],
        fallback: 'not_configured',
      ),
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
    final url = _stringFrom([
      json['url'],
      json['socket_url'],
      json['socketUrl'],
      json['websocket_url'],
      json['websocketUrl'],
      json['ws_url'],
      json['wsUrl'],
      json['realtime_url'],
      json['realtimeUrl'],
      json['endpoint'],
    ]);
    final key = _stringFrom([
      json['key'],
      json['app_key'],
      json['appKey'],
      json['pusher_app_key'],
      json['pusherAppKey'],
      json['pusher_key'],
      json['pusherKey'],
      json['broadcast_key'],
      json['broadcastKey'],
      json['public_key'],
      json['publicKey'],
    ]);
    final client = _stringFrom([
      json['client'],
      json['client_name'],
      json['clientName'],
    ]);
    return MobileRealtimeConfig(
      enabled: _boolFrom(json['enabled']) && url.isNotEmpty && key.isNotEmpty,
      url: url,
      key: key,
      authEndpoint: _stringFrom(
        [
          json['auth_endpoint'],
          json['authEndpoint'],
          json['auth_url'],
          json['authUrl'],
          json['auth_path'],
          json['authPath'],
          json['authorization_endpoint'],
          json['authorizationEndpoint'],
          json['channel_auth_endpoint'],
          json['channelAuthEndpoint'],
        ],
        fallback: '/customer/realtime/auth',
      ),
      protocol: _intFrom(json['protocol']) ?? 7,
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
    final liff = _mergeConfigMaps([
      json['liff'],
      json['liffConfig'],
      json['line_liff'],
      json['lineLiff'],
    ]);
    final bot = _mergeConfigMaps([
      json['bot'],
      json['botConfig'],
      json['line_bot'],
      json['lineBot'],
      json['messaging_bot'],
      json['messagingBot'],
    ]);
    final liffId = _stringFrom([
      json['liffId'],
      json['liff_id'],
      json['line_liff_id'],
      json['lineLiffId'],
      liff['id'],
      liff['liff_id'],
      liff['liffId'],
      liff['app_id'],
      liff['appId'],
    ]);
    final botBasicId = _stringFrom([
      json['botBasicId'],
      json['bot_basic_id'],
      json['basicId'],
      json['basic_id'],
      json['lineBasicId'],
      json['line_basic_id'],
      bot['basic_id'],
      bot['basicId'],
      bot['bot_basic_id'],
      bot['botBasicId'],
      bot['id'],
    ]);

    return MobileLineConfig(
      liffId: liffId,
      liffEnabled: _boolFrom(
        json['liff_enabled'] ??
            json['liffEnabled'] ??
            json['line_liff_enabled'] ??
            json['lineLiffEnabled'] ??
            json['line_available'] ??
            json['lineAvailable'] ??
            json['enabled'] ??
            json['active'] ??
            json['available'] ??
            json['ready'] ??
            json['configured'] ??
            json['status'] ??
            liff['enabled'] ??
            liff['active'] ??
            liff['available'] ??
            liff['ready'] ??
            liff['configured'] ??
            liff['status'],
        fallback: liffId.isNotEmpty,
      ),
      botBasicId: botBasicId,
      addFriendUrl: _stringFrom([
        json['addFriendUrl'],
        json['add_friend_url'],
        json['addFriendLink'],
        json['add_friend_link'],
        json['friendUrl'],
        json['friend_url'],
        json['lineAddFriendUrl'],
        json['line_add_friend_url'],
        json['lineFriendUrl'],
        json['line_friend_url'],
        bot['add_friend_url'],
        bot['addFriendUrl'],
        bot['friend_url'],
        bot['friendUrl'],
      ]),
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
    final assets = _mergeConfigMaps([
      json['asset'],
      json['assets'],
      json['image'],
      json['images'],
      json['media'],
    ]);
    final logo = _mergeConfigMaps([
      json['logo'],
      json['logoImage'],
      json['logoAsset'],
      json['brandLogo'],
      assets['logo'],
      assets['logoImage'],
      assets['logoAsset'],
      assets['brandLogo'],
      assets['brand_logo'],
    ]);
    final favicon = _mergeConfigMaps([
      json['favicon'],
      json['faviconImage'],
      json['faviconAsset'],
      json['icon'],
      json['appIcon'],
      assets['favicon'],
      assets['faviconImage'],
      assets['faviconAsset'],
      assets['icon'],
      assets['appIcon'],
    ]);
    final ogImage = _mergeConfigMaps([
      json['ogImage'],
      json['og_image'],
      json['socialImage'],
      json['shareImage'],
      assets['ogImage'],
      assets['og_image'],
      assets['openGraphImage'],
      assets['socialImage'],
      assets['shareImage'],
    ]);
    return MobileBrandConfig(
      logoUrl: _stringFrom([
        json['logo_url'],
        json['logoUrl'],
        json['logoURL'],
        json['logo_uri'],
        json['logoUri'],
        json['logo_path'],
        json['logoPath'],
        _stringIfScalar(json['logo']),
        _stringIfScalar(json['logoImage']),
        _stringIfScalar(json['logoAsset']),
        json['logo_full_url'],
        json['logoFullUrl'],
        json['logo_asset_url'],
        json['logoAssetUrl'],
        json['logo_public_url'],
        json['logoPublicUrl'],
        json['logo_href'],
        json['logoHref'],
        json['brand_logo'],
        _stringIfScalar(json['brandLogo']),
        json['brandLogoUrl'],
        json['brandLogoURL'],
        json['brandLogoFullUrl'],
        json['brandLogoAssetUrl'],
        json['brandLogoPath'],
        json['image_url'],
        json['imageUrl'],
        _stringIfScalar(assets['logo']),
        _stringIfScalar(assets['brandLogo']),
        logo['url'],
        logo['src'],
        logo['source'],
        logo['path'],
        logo['uri'],
        logo['href'],
        logo['link'],
        logo['full_url'],
        logo['fullUrl'],
        logo['asset_url'],
        logo['assetUrl'],
        logo['public_url'],
        logo['publicUrl'],
        logo['secure_url'],
        logo['secureUrl'],
        logo['original_url'],
        logo['originalUrl'],
      ]),
      faviconUrl: _stringFrom([
        json['favicon_url'],
        json['faviconUrl'],
        json['faviconURL'],
        json['favicon_uri'],
        json['faviconUri'],
        json['favicon_path'],
        json['faviconPath'],
        _stringIfScalar(json['favicon']),
        _stringIfScalar(json['faviconImage']),
        _stringIfScalar(json['faviconAsset']),
        _stringIfScalar(json['icon']),
        _stringIfScalar(json['appIcon']),
        json['icon_url'],
        json['iconUrl'],
        json['app_icon_url'],
        json['appIconUrl'],
        json['favicon_full_url'],
        json['faviconFullUrl'],
        json['favicon_asset_url'],
        json['faviconAssetUrl'],
        json['favicon_public_url'],
        json['faviconPublicUrl'],
        _stringIfScalar(assets['favicon']),
        _stringIfScalar(assets['icon']),
        favicon['url'],
        favicon['src'],
        favicon['source'],
        favicon['path'],
        favicon['uri'],
        favicon['href'],
        favicon['link'],
        favicon['full_url'],
        favicon['fullUrl'],
        favicon['asset_url'],
        favicon['assetUrl'],
        favicon['public_url'],
        favicon['publicUrl'],
        favicon['secure_url'],
        favicon['secureUrl'],
        favicon['original_url'],
        favicon['originalUrl'],
      ]),
      ogImageUrl: _stringFrom([
        json['og_image_url'],
        json['ogImageUrl'],
        json['ogImageURL'],
        json['open_graph_image_url'],
        json['openGraphImageUrl'],
        json['share_image_url'],
        json['shareImageUrl'],
        json['social_image_url'],
        json['socialImageUrl'],
        _stringIfScalar(json['ogImage']),
        _stringIfScalar(json['og_image']),
        _stringIfScalar(json['openGraphImage']),
        _stringIfScalar(json['shareImage']),
        _stringIfScalar(json['socialImage']),
        json['og_image_full_url'],
        json['ogImageFullUrl'],
        json['og_image_asset_url'],
        json['ogImageAssetUrl'],
        json['og_image_public_url'],
        json['ogImagePublicUrl'],
        _stringIfScalar(assets['ogImage']),
        _stringIfScalar(assets['og_image']),
        _stringIfScalar(assets['shareImage']),
        ogImage['url'],
        ogImage['src'],
        ogImage['source'],
        ogImage['path'],
        ogImage['uri'],
        ogImage['href'],
        ogImage['link'],
        ogImage['full_url'],
        ogImage['fullUrl'],
        ogImage['asset_url'],
        ogImage['assetUrl'],
        ogImage['public_url'],
        ogImage['publicUrl'],
        ogImage['secure_url'],
        ogImage['secureUrl'],
        ogImage['original_url'],
        ogImage['originalUrl'],
      ]),
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
    this.brandColor,
    this.buttonBackgroundColor,
    this.buttonForegroundColor,
  });

  factory SocialAuthProvider.fromJson(Map<String, dynamic> json) {
    final style = _mergeConfigMaps([
      json['style'],
      json['styles'],
      json['appearance'],
      json['appearanceConfig'],
      json['brand'],
      json['brandConfig'],
      json['theme'],
      json['themeConfig'],
      json['colors'],
    ]);
    final provider = _normalizeSocialProvider(
      _stringFrom([
        json['provider'],
        json['key'],
        json['code'],
        json['slug'],
      ]),
    );
    final label = _stringFrom([
      json['label'],
      json['display_label'],
      json['displayLabel'],
      json['display_name'],
      json['displayName'],
      json['name'],
      json['title'],
    ]);

    return SocialAuthProvider(
      provider: provider,
      label: label.isEmpty ? _defaultSocialProviderLabel(provider) : label,
      brandColor: _runtimeColorFrom([
        json['brand_color'],
        json['brandColor'],
        json['provider_color'],
        json['providerColor'],
        json['social_color'],
        json['socialColor'],
        json['accent_color'],
        json['accentColor'],
        json['color'],
        json['colour'],
        style['brand_color'],
        style['brandColor'],
        style['provider_color'],
        style['providerColor'],
        style['accent_color'],
        style['accentColor'],
        style['primary'],
        style['primaryColor'],
        style['color'],
        style['colour'],
      ]),
      buttonBackgroundColor: _runtimeColorFrom([
        json['button_background_color'],
        json['buttonBackgroundColor'],
        json['button_bg_color'],
        json['buttonBgColor'],
        json['background_color'],
        json['backgroundColor'],
        json['button_color'],
        json['buttonColor'],
        style['button_background_color'],
        style['buttonBackgroundColor'],
        style['button_color'],
        style['buttonColor'],
        style['background_color'],
        style['backgroundColor'],
      ]),
      buttonForegroundColor: _runtimeColorFrom([
        json['button_foreground_color'],
        json['buttonForegroundColor'],
        json['button_text_color'],
        json['buttonTextColor'],
        json['foreground_color'],
        json['foregroundColor'],
        json['text_color'],
        json['textColor'],
        json['on_color'],
        json['onColor'],
        style['button_foreground_color'],
        style['buttonForegroundColor'],
        style['button_text_color'],
        style['buttonTextColor'],
        style['foreground_color'],
        style['foregroundColor'],
        style['text_color'],
        style['textColor'],
        style['on_color'],
        style['onColor'],
      ]),
      enabled: _boolFrom(
        json['enabled'] ??
            json['is_enabled'] ??
            json['isEnabled'] ??
            json['active'] ??
            json['available'] ??
            json['ready'] ??
            json['is_ready'] ??
            json['isReady'] ??
            json['configured'] ??
            json['status'],
      ),
    );
  }

  final String provider;
  final String label;
  final bool enabled;
  final Color? brandColor;
  final Color? buttonBackgroundColor;
  final Color? buttonForegroundColor;

  bool get supported => _supportedSocialProviders.contains(provider);
}

class MobileBiometricConfig {
  const MobileBiometricConfig({
    required this.enabled,
    required this.requiresPinSetup,
    required this.assertionTokenTtlSeconds,
    required this.promptReason,
    required this.setupPromptReason,
    required this.promptReasons,
    required this.platforms,
  });

  factory MobileBiometricConfig.fromJson(Map<String, dynamic> json) {
    final prompt = _mergeMaps([
      json['prompt'],
      json['prompts'],
      json['promptCopy'],
      json['biometricPromptCopy'],
      json['biometric_prompt_copy'],
      json['biometricPrompt'],
      json['biometric_prompt'],
      json['authenticationPrompt'],
      json['authentication_prompt'],
      json['authenticationPromptCopy'],
      json['authentication_prompt_copy'],
      json['authPrompt'],
      json['auth_prompt'],
      json['localAuthPrompt'],
      json['local_auth_prompt'],
      json['localAuthPromptCopy'],
      json['local_auth_prompt_copy'],
      json['localAuth'],
      json['local_auth'],
    ]);
    final promptReasons = _mergeBiometricPromptReasonMaps([
      prompt['reasons'],
      prompt['purpose_reasons'],
      prompt['purposeReasons'],
      prompt['localized_reasons'],
      prompt['localizedReasons'],
      json['prompt_reasons'],
      json['promptReasons'],
      json['purpose_reasons'],
      json['purposeReasons'],
      json['localized_reasons'],
      json['localizedReasons'],
      _directBiometricPromptReasons(json),
      _directBiometricPromptReasons(prompt),
    ]);
    final promptReason = _stringFrom([
      prompt['reason'],
      prompt['localized_reason'],
      prompt['localizedReason'],
      prompt['message'],
      prompt['description'],
      prompt['prompt_reason'],
      prompt['promptReason'],
      json['localized_reason'],
      json['localizedReason'],
      json['prompt_reason'],
      json['promptReason'],
      json['biometric_prompt_reason'],
      json['biometricPromptReason'],
      json['authentication_reason'],
      json['authenticationReason'],
    ]);
    return MobileBiometricConfig(
      enabled: _boolFrom(json['enabled'], fallback: true),
      requiresPinSetup: _boolFrom(
        json['requires_pin_setup'] ?? json['requiresPinSetup'],
        fallback: true,
      ),
      assertionTokenTtlSeconds: _intFrom(
            json['assertion_token_ttl_seconds'] ??
                json['assertionTokenTtlSeconds'],
          ) ??
          180,
      promptReason: promptReason,
      setupPromptReason: _stringFrom(
        [
          prompt['setup_reason'],
          prompt['setupReason'],
          prompt['register_reason'],
          prompt['registerReason'],
          prompt['registration_reason'],
          prompt['registrationReason'],
          prompt['device_setup_reason'],
          prompt['deviceSetupReason'],
          prompt['device_registration_reason'],
          prompt['deviceRegistrationReason'],
          json['setup_reason'],
          json['setupReason'],
          json['biometric_setup_reason'],
          json['biometricSetupReason'],
          json['device_registration_reason'],
          json['deviceRegistrationReason'],
          json['register_reason'],
          json['registerReason'],
          json['registration_reason'],
          json['registrationReason'],
        ],
        fallback: promptReason,
      ),
      promptReasons: promptReasons,
      platforms: _mergePlatformMaps([
        json['platforms'],
        json['supported_platforms'],
        json['supportedPlatforms'],
        json['available_platforms'],
        json['availablePlatforms'],
        json['platform_requirements'],
        json['platformRequirements'],
      ]),
    );
  }

  final bool enabled;
  final bool requiresPinSetup;
  final int assertionTokenTtlSeconds;
  final String promptReason;
  final String setupPromptReason;
  final Map<String, String> promptReasons;
  final Map<String, List<String>> platforms;

  bool supportsPlatform(String platform) {
    return platforms[platform.trim().toLowerCase()]?.isNotEmpty == true;
  }

  String promptReasonForPurpose(
    String purpose, {
    required String fallback,
    bool setup = false,
  }) {
    final purposeKey = _featureFlagKey(purpose);
    final keys = <String>[
      if (purposeKey.isNotEmpty) purposeKey,
      if (setup) ...[
        'biometric_setup',
        'setup',
        'register',
        'registration',
        'device_setup',
        'device_registration',
      ],
    ];
    for (final key in keys) {
      final value = promptReasons[key]?.trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    if (setup && setupPromptReason.trim().isNotEmpty) {
      return setupPromptReason.trim();
    }
    if (promptReason.trim().isNotEmpty) return promptReason.trim();
    return fallback;
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
    required this.privacyOverlayTitle,
    required this.privacyOverlayDescription,
    required this.sensitiveRoutes,
  });

  factory MobileScreenSecurityConfig.fromJson(Map<String, dynamic> json) {
    final android = _asMap(json['android']);
    final ios = _asMap(json['ios']);
    final web = _asMap(json['web']);
    return MobileScreenSecurityConfig(
      androidFlagSecure: _boolFrom(
        android['flag_secure'] ??
            android['flagSecure'] ??
            json['android_flag_secure'] ??
            json['androidFlagSecure'] ??
            json['flag_secure'] ??
            json['flagSecure'],
        fallback: true,
      ),
      androidProtectRecentAppPreview: _boolFrom(
        android['protect_recent_app_preview'] ??
            android['protectRecentAppPreview'] ??
            json['android_protect_recent_app_preview'] ??
            json['androidProtectRecentAppPreview'] ??
            json['protect_recent_app_preview'] ??
            json['protectRecentAppPreview'],
        fallback: true,
      ),
      iosScreenshotPolicy: _stringFrom(
        [
          ios['screenshot_policy'],
          ios['screenshotPolicy'],
          json['ios_screenshot_policy'],
          json['iosScreenshotPolicy'],
          json['screenshot_policy'],
          json['screenshotPolicy'],
        ],
        fallback: 'lock_and_blank',
      ),
      iosScreenCaptureOverlay: _boolFrom(
        ios['screen_capture_overlay'] ??
            ios['screenCaptureOverlay'] ??
            json['ios_screen_capture_overlay'] ??
            json['iosScreenCaptureOverlay'] ??
            json['screen_capture_overlay'] ??
            json['screenCaptureOverlay'],
        fallback: true,
      ),
      iosExitApp: _boolFrom(
        ios['exit_app'] ??
            ios['exitApp'] ??
            json['ios_exit_app'] ??
            json['iosExitApp'] ??
            json['exit_app'] ??
            json['exitApp'],
      ),
      webSensitiveScreenMode: normalizeWebPrivacyMode(
        _stringFrom(
          [
            web['sensitive_screen_mode'],
            web['sensitiveScreenMode'],
            web['mode'],
            json['web_sensitive_screen_mode'],
            json['webSensitiveScreenMode'],
            json['sensitive_screen_mode'],
            json['sensitiveScreenMode'],
            json['mode'],
          ],
          fallback: webPrivacyModeLimited,
        ),
      ),
      webWatermarkEnabled: _boolFrom(
        web['watermark_enabled'] ??
            web['watermarkEnabled'] ??
            json['web_watermark_enabled'] ??
            json['webWatermarkEnabled'] ??
            json['watermark_enabled'] ??
            json['watermarkEnabled'],
      ),
      privacyOverlayTitle: _stringFrom([
        ios['privacy_overlay_title'],
        ios['privacyOverlayTitle'],
        ios['overlay_title'],
        ios['overlayTitle'],
        ios['screen_capture_title'],
        ios['screenCaptureTitle'],
        ios['security_capture_title'],
        ios['securityCaptureTitle'],
        json['ios_privacy_overlay_title'],
        json['iosPrivacyOverlayTitle'],
        json['privacy_overlay_title'],
        json['privacyOverlayTitle'],
        json['overlay_title'],
        json['overlayTitle'],
        json['screen_capture_title'],
        json['screenCaptureTitle'],
        json['security_capture_title'],
        json['securityCaptureTitle'],
      ]),
      privacyOverlayDescription: _stringFrom([
        ios['privacy_overlay_description'],
        ios['privacyOverlayDescription'],
        ios['overlay_description'],
        ios['overlayDescription'],
        ios['screen_capture_description'],
        ios['screenCaptureDescription'],
        ios['security_capture_description'],
        ios['securityCaptureDescription'],
        json['ios_privacy_overlay_description'],
        json['iosPrivacyOverlayDescription'],
        json['privacy_overlay_description'],
        json['privacyOverlayDescription'],
        json['overlay_description'],
        json['overlayDescription'],
        json['screen_capture_description'],
        json['screenCaptureDescription'],
        json['security_capture_description'],
        json['securityCaptureDescription'],
      ]),
      sensitiveRoutes: _screenSecurityRoutes(json, android, ios, web),
    );
  }

  final bool androidFlagSecure;
  final bool androidProtectRecentAppPreview;
  final String iosScreenshotPolicy;
  final bool iosScreenCaptureOverlay;
  final bool iosExitApp;
  final String webSensitiveScreenMode;
  final bool webWatermarkEnabled;
  final String privacyOverlayTitle;
  final String privacyOverlayDescription;
  final List<String> sensitiveRoutes;

  bool get nativeProtectionEnabled =>
      androidFlagSecure || iosScreenCaptureOverlay;

  bool isSensitiveRoute(String route) {
    final path = _normalizeScreenSecurityPolicyRoute(route);
    if (path.isEmpty) return false;
    return sensitiveRoutes.any(
      (sensitive) =>
          _routePatternMatches(sensitive, path) ||
          path == sensitive ||
          path.startsWith('$sensitive/'),
    );
  }
}

bool _routePatternMatches(String pattern, String path) {
  final normalizedPattern = _normalizeScreenSecurityPolicyRoute(pattern);
  final normalizedPath = _normalizeScreenSecurityPolicyRoute(path);
  if (normalizedPattern.isEmpty || normalizedPath.isEmpty) return false;
  if (normalizedPattern == normalizedPath) return true;

  final patternParts =
      normalizedPattern.split('/').where((part) => part.isNotEmpty).toList();
  final pathParts =
      normalizedPath.split('/').where((part) => part.isNotEmpty).toList();
  var pathIndex = 0;
  for (var patternIndex = 0;
      patternIndex < patternParts.length;
      patternIndex++) {
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

class MobileFeatureFlags {
  const MobileFeatureFlags(this.values);

  factory MobileFeatureFlags.fromJson(Map<String, dynamic> json) {
    return MobileFeatureFlags(
      json.map(
        (key, value) => MapEntry(_featureFlagKey(key), _boolFrom(value)),
      ),
    );
  }

  final Map<String, bool> values;

  bool contains(String key) {
    return values.containsKey(_featureFlagKey(key));
  }

  bool enabled(String key, {bool fallback = false}) {
    return values[_featureFlagKey(key)] ?? fallback;
  }
}

class MaintenanceConfig {
  const MaintenanceConfig({
    required this.active,
    required this.message,
    required this.expectedEndAt,
    required this.retryAfterSeconds,
    required this.mode,
    required this.allowedRoutes,
    required this.blockedRoutePatterns,
  });

  factory MaintenanceConfig.fromJson(Map<String, dynamic> json) {
    final routes = _mergeConfigMaps([
      json['routes'],
      json['routeConfig'],
      json['route_config'],
      json['routing'],
    ]);
    return MaintenanceConfig(
      active: _maintenanceActiveFrom(
        json['active'] ??
            json['enabled'] ??
            json['is_active'] ??
            json['isActive'] ??
            json['maintenance_active'] ??
            json['maintenanceActive'] ??
            json['status'],
      ),
      message: _stringFrom([
        json['message'],
        json['description'],
        json['notice'],
        json['body'],
      ]),
      expectedEndAt: json['expected_end_at'] ??
          json['expectedEndAt'] ??
          json['expected_end'] ??
          json['expectedEnd'] ??
          json['end_at'] ??
          json['endAt'] ??
          json['ends_at'] ??
          json['endsAt'] ??
          json['until_at'] ??
          json['untilAt'] ??
          json['until'],
      retryAfterSeconds: _intFrom(
        json['retry_after_seconds'] ??
            json['retryAfterSeconds'] ??
            json['retry_after'] ??
            json['retryAfter'] ??
            json['retry_seconds'] ??
            json['retrySeconds'],
      ),
      mode: _stringFrom([
        json['mode'],
        json['maintenance_mode'],
        json['maintenanceMode'],
        json['scope'],
      ]),
      allowedRoutes: _maintenanceRouteList([
        json['allowed_routes'],
        json['allowedRoutes'],
        json['allow_routes'],
        json['allowRoutes'],
        json['allowlist_routes'],
        json['allowlistRoutes'],
        routes['allowed'],
        routes['allowed_routes'],
        routes['allowedRoutes'],
        routes['allowlist'],
      ]),
      blockedRoutePatterns: _maintenanceRouteList([
        json['blocked_route_patterns'],
        json['blockedRoutePatterns'],
        json['blocked_routes'],
        json['blockedRoutes'],
        json['block_routes'],
        json['blockRoutes'],
        routes['blocked'],
        routes['blocked_routes'],
        routes['blockedRoutes'],
        routes['blocked_patterns'],
        routes['blockedPatterns'],
      ]),
    );
  }

  final bool active;
  final String message;
  final Object? expectedEndAt;
  final int? retryAfterSeconds;
  final String mode;
  final List<String> allowedRoutes;
  final List<String> blockedRoutePatterns;

  bool blocksRoute(String path) {
    if (!active) return false;
    final normalizedPath = _maintenancePath(path);
    if (_maintenanceRouteMatchesAny(
      _alwaysAllowedMaintenanceRoutes,
      normalizedPath,
    )) {
      return false;
    }
    if (_maintenanceRouteMatchesAny(allowedRoutes, normalizedPath)) {
      return false;
    }

    if (_maintenanceRouteMatchesAny(blockedRoutePatterns, normalizedPath)) {
      return true;
    }

    final normalizedMode = mode.trim().toLowerCase();
    if (normalizedMode == 'checkout_payment_only') {
      return _maintenanceRouteMatchesAny(
        _checkoutPaymentMaintenanceRoutes,
        normalizedPath,
        includeChildren: true,
      );
    }
    if (normalizedMode == 'scheduled' ||
        normalizedMode == 'admin_only' ||
        normalizedMode == 'read_only') {
      return false;
    }
    if (normalizedMode.isEmpty ||
        normalizedMode == 'full_site' ||
        normalizedMode == 'customer_web_only') {
      return true;
    }
    return _maintenanceRouteMatchesAny(
      _protectedMaintenanceRoutes,
      normalizedPath,
      includeChildren: true,
    );
  }
}

const _checkoutPaymentMaintenanceRoutes = ['/checkout', '/topup'];

const _alwaysAllowedMaintenanceRoutes = ['/maintenance', '/robots.txt'];

const _protectedMaintenanceRoutes = [
  '/',
  '/buy',
  '/buy/search',
  '/buy/more',
  '/stores',
  '/stores/lotteries',
  '/countdown',
  '/result',
  '/result/full',
  '/results',
  '/results/full',
  '/cart',
  '/checkout',
  '/success',
  '/topup',
  '/topup/history',
  '/my-wallet',
  '/purchase-history',
  '/tickets',
  '/tickets/history',
  '/tickets/view',
  '/profile/auto-reward',
  '/profile',
];

Map<String, dynamic> _maintenanceFlatConfig(Map<String, dynamic> json) {
  final config = <String, dynamic>{};
  void add(String key, Iterable<Object?> values) {
    final value = _firstPresent(values);
    if (value != null) config[key] = value;
  }

  add('active', [
    json['maintenance_active'],
    json['maintenanceActive'],
    json['is_maintenance_active'],
    json['isMaintenanceActive'],
  ]);
  add('mode', [
    json['maintenance_mode'],
    json['maintenanceMode'],
    json['maintenance_scope'],
    json['maintenanceScope'],
  ]);
  add('message', [
    json['maintenance_message'],
    json['maintenanceMessage'],
    json['maintenance_notice'],
    json['maintenanceNotice'],
  ]);
  add('expected_end_at', [
    json['maintenance_expected_end_at'],
    json['maintenanceExpectedEndAt'],
    json['maintenance_expected_end'],
    json['maintenanceExpectedEnd'],
    json['maintenance_until_at'],
    json['maintenanceUntilAt'],
  ]);
  add('retry_after_seconds', [
    json['maintenance_retry_after_seconds'],
    json['maintenanceRetryAfterSeconds'],
    json['maintenance_retry_after'],
    json['maintenanceRetryAfter'],
  ]);
  add('allowed_routes', [
    json['maintenance_allowed_routes'],
    json['maintenanceAllowedRoutes'],
    json['maintenance_allowlist_routes'],
    json['maintenanceAllowlistRoutes'],
  ]);
  add('blocked_route_patterns', [
    json['maintenance_blocked_route_patterns'],
    json['maintenanceBlockedRoutePatterns'],
    json['maintenance_blocked_routes'],
    json['maintenanceBlockedRoutes'],
  ]);
  return config;
}

Object? _firstPresent(Iterable<Object?> values) {
  for (final value in values) {
    if (value != null) return value;
  }
  return null;
}

Map<String, String> _mergeBiometricPromptReasonMaps(Iterable<Object?> values) {
  final merged = <String, String>{};
  for (final value in values) {
    merged.addAll(_biometricPromptReasonMap(value));
  }
  merged.removeWhere((key, value) => key.isEmpty || value.trim().isEmpty);
  return Map.unmodifiable(merged);
}

Map<String, String> _biometricPromptReasonMap(Object? value) {
  if (value == null) return const <String, String>{};
  if (value is Iterable && value is! String) {
    final merged = <String, String>{};
    for (final item in value) {
      merged.addAll(_biometricPromptReasonMap(item));
    }
    return merged;
  }

  final json = _asMap(value);
  if (json.isEmpty) return const <String, String>{};
  final directKey = _stringFrom([
    json['purpose'],
    json['key'],
    json['code'],
    json['name'],
    json['type'],
  ]);
  if (directKey.isNotEmpty) {
    final reason = _stringFrom([
      json['localized_reason'],
      json['localizedReason'],
      json['reason'],
      json['message'],
      json['description'],
      json['prompt'],
      json['text'],
      json['label'],
      json['value'],
    ]);
    return reason.isEmpty ? const {} : {_featureFlagKey(directKey): reason};
  }

  final reasons = <String, String>{};
  for (final entry in json.entries) {
    final key = _featureFlagKey(entry.key);
    if (key.isEmpty) continue;
    final reason = _biometricPromptReasonText(entry.value);
    if (reason.isNotEmpty) reasons[key] = reason;
  }
  return reasons;
}

String _biometricPromptReasonText(Object? value) {
  final direct = _stringIfScalar(value) ?? '';
  if (direct.isNotEmpty) return direct;
  final json = _asMap(value);
  if (json.isEmpty) return '';
  return _stringFrom([
    json['localized_reason'],
    json['localizedReason'],
    json['reason'],
    json['message'],
    json['description'],
    json['prompt'],
    json['text'],
    json['label'],
    json['value'],
  ]);
}

Map<String, String> _directBiometricPromptReasons(Map<String, dynamic> json) {
  final reasons = <String, String>{};
  void add(String key, Iterable<Object?> values) {
    final reason = _stringFrom(values);
    if (reason.isNotEmpty) reasons[_featureFlagKey(key)] = reason;
  }

  add('pin_unlock', [
    json['pin_unlock_reason'],
    json['pinUnlockReason'],
    json['unlock_reason'],
    json['unlockReason'],
    json['pin_reason'],
    json['pinReason'],
  ]);
  add('profile_update', [
    json['profile_update_reason'],
    json['profileUpdateReason'],
    json['profile_reason'],
    json['profileReason'],
    json['bank_update_reason'],
    json['bankUpdateReason'],
    json['reward_bank_update_reason'],
    json['rewardBankUpdateReason'],
    json['bank_account_update_reason'],
    json['bankAccountUpdateReason'],
  ]);
  add('reward_claim', [
    json['reward_claim_reason'],
    json['rewardClaimReason'],
    json['claim_reward_reason'],
    json['claimRewardReason'],
    json['ticket_claim_reason'],
    json['ticketClaimReason'],
    json['claim_ticket_reason'],
    json['claimTicketReason'],
  ]);
  add('activity_claim', [
    json['activity_claim_reason'],
    json['activityClaimReason'],
    json['claim_activity_reason'],
    json['claimActivityReason'],
    json['award_claim_reason'],
    json['awardClaimReason'],
    json['activity_award_claim_reason'],
    json['activityAwardClaimReason'],
  ]);
  add('biometric_setup', [
    json['biometric_setup_reason'],
    json['biometricSetupReason'],
    json['setup_reason'],
    json['setupReason'],
    json['enable_reason'],
    json['enableReason'],
    json['device_setup_reason'],
    json['deviceSetupReason'],
    json['device_registration_reason'],
    json['deviceRegistrationReason'],
    json['register_reason'],
    json['registerReason'],
    json['registration_reason'],
    json['registrationReason'],
  ]);
  return reasons;
}

bool _maintenanceActiveFrom(Object? value) {
  if (value == null) return false;
  if (value is String) {
    final normalized = value.trim().toLowerCase().replaceAll('-', '_');
    if (normalized == 'maintenance' ||
        normalized == 'under_maintenance' ||
        normalized == 'maintenance_active') {
      return true;
    }
  }
  return _boolFrom(value);
}

List<String> _maintenanceRouteList(Iterable<Object?> values) {
  final routes = <String>[];
  final seen = <String>{};
  for (final value in values) {
    for (final route in _maintenanceRouteItems(value)) {
      final normalized = _maintenancePath(route);
      if (normalized.isNotEmpty && seen.add(normalized)) {
        routes.add(normalized);
      }
    }
  }
  return routes;
}

Iterable<String> _maintenanceRouteItems(Object? value) sync* {
  if (value == null) return;
  if (value is String) {
    yield* _stringList(value);
    return;
  }
  if (value is Iterable) {
    for (final item in value) {
      yield* _maintenanceRouteItems(item);
    }
    return;
  }
  if (value is! Map) return;

  final map = _asMap(value);
  final rowPath = _stringFrom(
    _screenSecurityRouteValueKeys.map((key) => map[key]),
  );
  if (rowPath.isNotEmpty) {
    if (_boolFrom(
      map['enabled'] ??
          map['active'] ??
          map['allowed'] ??
          map['supported'] ??
          map['visible'],
      fallback: true,
    )) {
      yield rowPath;
    }
    return;
  }

  for (final entry in map.entries) {
    final key = entry.key.toString().trim();
    if (key.isEmpty) continue;
    final raw = entry.value;
    if (_isBooleanLike(raw)) {
      if (_boolFrom(raw)) yield key;
      continue;
    }
    if (raw is Map) {
      final row = _asMap(raw);
      if (!_boolFrom(
        row['enabled'] ??
            row['active'] ??
            row['allowed'] ??
            row['supported'] ??
            row['visible'],
        fallback: true,
      )) {
        continue;
      }
      final nestedPath = _stringFrom(
        _screenSecurityRouteValueKeys.map((key) => row[key]),
      );
      yield nestedPath.isNotEmpty ? nestedPath : key;
      continue;
    }
    if (raw is Iterable) {
      yield* _maintenanceRouteItems(raw);
    }
  }
}

bool _maintenanceRouteMatchesAny(
  Iterable<String> patterns,
  String path, {
  bool includeChildren = false,
}) {
  return patterns.any(
    (pattern) => _maintenanceRouteMatches(
      pattern,
      path,
      includeChildren: includeChildren,
    ),
  );
}

bool _maintenanceRouteMatches(
  String pattern,
  String path, {
  bool includeChildren = false,
}) {
  final normalizedPattern = _maintenancePath(pattern);
  final normalizedPath = _maintenancePath(path);
  if (normalizedPattern.endsWith('*')) {
    return normalizedPath.startsWith(
      normalizedPattern.substring(0, normalizedPattern.length - 1),
    );
  }
  return normalizedPath == normalizedPattern ||
      (includeChildren && normalizedPath.startsWith('$normalizedPattern/'));
}

String _maintenancePath(Object? value) {
  final normalized = _normalizeScreenSecurityPolicyRoute(
    value?.toString().trim() ?? '',
  );
  return normalized.isEmpty ? '/' : normalized;
}

Map<String, List<String>> _platformMap(Object? value) {
  if (value is List) {
    final entries = <String, List<String>>{};
    for (final item in value) {
      if (item is Map) {
        final row = _asMap(item);
        if (!_boolFrom(
          row['enabled'] ??
              row['is_enabled'] ??
              row['isEnabled'] ??
              row['active'] ??
              row['available'],
          fallback: true,
        )) {
          continue;
        }
        final platform = _stringFrom([
          row['platform'],
          row['key'],
          row['code'],
          row['os'],
          row['name'],
        ]).toLowerCase();
        if (platform.isEmpty) continue;
        final capabilities = _stringList(
          row['capabilities'] ??
              row['features'] ??
              row['methods'] ??
              row['requirements'],
        );
        entries[platform] = capabilities.isEmpty ? [platform] : capabilities;
      } else {
        final platform = item.toString().trim().toLowerCase();
        if (platform.isNotEmpty) entries[platform] = [platform];
      }
    }
    return entries;
  }
  if (value is! Map) return const {};
  final entries = <String, List<String>>{};
  for (final entry in value.entries) {
    final platform = entry.key.toString().trim().toLowerCase();
    if (platform.isEmpty) continue;
    final raw = entry.value;
    if (_isBooleanLike(raw)) {
      if (_boolFrom(raw)) entries[platform] = [platform];
      continue;
    }
    if (raw is Map) {
      final row = _asMap(raw);
      if (!_boolFrom(
        row['enabled'] ??
            row['is_enabled'] ??
            row['isEnabled'] ??
            row['active'] ??
            row['available'] ??
            row['supported'] ??
            row['allowed'],
        fallback: true,
      )) {
        continue;
      }
      final capabilities = _stringList(
        row['capabilities'] ??
            row['features'] ??
            row['methods'] ??
            row['requirements'] ??
            row['items'],
      );
      entries[platform] = capabilities.isEmpty ? [platform] : capabilities;
      continue;
    }
    final capabilities = _stringList(raw);
    if (capabilities.isNotEmpty) entries[platform] = capabilities;
  }
  return entries;
}

Map<String, List<String>> _mergePlatformMaps(Iterable<Object?> values) {
  final merged = <String, List<String>>{};
  for (final value in values) {
    merged.addAll(_platformMap(value));
    for (final disabled in _disabledPlatforms(value)) {
      merged.remove(disabled);
    }
  }
  return merged;
}

Set<String> _disabledPlatforms(Object? value) {
  if (value is Iterable) {
    return value.expand(_disabledPlatforms).toSet();
  }
  if (value is! Map) return const {};

  final json = _asMap(value);
  final disabled = <String>{};
  final directPlatform = _stringFrom([
    json['platform'],
    json['key'],
    json['code'],
    json['os'],
    json['name'],
  ]).toLowerCase();
  if (directPlatform.isNotEmpty &&
      !_boolFrom(
        json['enabled'] ??
            json['is_enabled'] ??
            json['isEnabled'] ??
            json['active'] ??
            json['available'] ??
            json['supported'] ??
            json['allowed'],
        fallback: true,
      )) {
    disabled.add(directPlatform);
  }

  for (final entry in json.entries) {
    final platform = entry.key.toString().trim().toLowerCase();
    if (platform.isEmpty) continue;
    final raw = entry.value;
    if (_isBooleanLike(raw) && !_boolFrom(raw)) {
      disabled.add(platform);
      continue;
    }
    if (raw is Map) {
      final row = _asMap(raw);
      if (!_boolFrom(
        row['enabled'] ??
            row['is_enabled'] ??
            row['isEnabled'] ??
            row['active'] ??
            row['available'] ??
            row['supported'] ??
            row['allowed'],
        fallback: true,
      )) {
        disabled.add(platform);
      }
    } else if (raw is Iterable) {
      disabled.addAll(_disabledPlatforms(raw));
    }
  }

  return disabled;
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}

Map<String, dynamic> _mergeMaps(Iterable<Object?> values) {
  final merged = <String, dynamic>{};
  for (final value in values) {
    merged.addAll(_asMap(value));
  }
  return merged;
}

Map<String, dynamic> _mergeConfigMaps(Iterable<Object?> values) {
  final merged = <String, dynamic>{};
  for (final value in values) {
    _deepMergeConfigMap(merged, _asMap(value));
  }
  return merged;
}

Map<String, dynamic> _mergeFeatureFlagMaps(Iterable<Object?> values) {
  final merged = <String, dynamic>{};
  for (final value in values) {
    merged.addAll(_featureFlagMap(value));
  }
  return merged;
}

Map<String, dynamic> _featureFlagMap(Object? value) {
  if (value == null) return const <String, dynamic>{};
  if (value is String) {
    final flags = _stringList(value);
    return {
      for (final flag in flags) _featureFlagKey(flag): true,
    }..removeWhere((key, _) => key.isEmpty);
  }
  if (value is Iterable) {
    final merged = <String, dynamic>{};
    for (final item in value) {
      merged.addAll(_featureFlagMap(item));
    }
    return merged;
  }
  if (value is! Map) return const <String, dynamic>{};

  final row = _asMap(value);
  final directKey = _featureFlagRowKey(row);
  if (directKey.isNotEmpty) {
    return {_featureFlagKey(directKey): _featureFlagEnabled(row)};
  }

  final merged = <String, dynamic>{};
  for (final nestedKey in const [
    'features',
    'feature_flags',
    'featureFlags',
    'feature_config',
    'featureConfig',
    'featureToggles',
    'feature_toggles',
    'flags',
    'toggles',
    'items',
    'rows',
    'plugins',
    'pluginConfig',
    'plugin_config',
    'pluginSettings',
    'plugin_settings',
    'enabledPlugins',
    'enabled_plugins',
    'modules',
    'capabilities',
  ]) {
    merged.addAll(_featureFlagMap(row[nestedKey]));
  }

  for (final entry in row.entries) {
    final rawKey = entry.key.toString().trim();
    if (rawKey.isEmpty ||
        const {
          'features',
          'feature_flags',
          'featureFlags',
          'feature_config',
          'featureConfig',
          'featureToggles',
          'feature_toggles',
          'flags',
          'toggles',
          'items',
          'rows',
          'plugins',
          'pluginConfig',
          'plugin_config',
          'pluginSettings',
          'plugin_settings',
          'enabledPlugins',
          'enabled_plugins',
          'modules',
          'capabilities',
        }.contains(rawKey)) {
      continue;
    }

    final key = _featureFlagKey(rawKey);
    if (key.isEmpty) continue;
    final rawValue = entry.value;
    if (rawValue is Map) {
      final rawMap = _asMap(rawValue);
      final nestedKey = _featureFlagRowKey(rawMap);
      if (nestedKey.isNotEmpty || _featureFlagRowHasState(rawMap)) {
        merged[nestedKey.isNotEmpty ? _featureFlagKey(nestedKey) : key] =
            _featureFlagEnabled(rawMap);
      } else {
        merged.addAll(_featureFlagMap(rawMap));
      }
    } else {
      merged[key] = _boolFrom(rawValue);
    }
  }
  return merged;
}

String _featureFlagRowKey(Map<String, dynamic> row) {
  return _stringFrom([
    row['key'],
    row['code'],
    row['slug'],
    row['feature'],
    row['feature_key'],
    row['featureKey'],
    row['flag'],
    row['flag_key'],
    row['flagKey'],
    row['setting'],
    row['setting_key'],
    row['settingKey'],
    row['module'],
    row['module_key'],
    row['moduleKey'],
    row['plugin'],
    row['plugin_key'],
    row['pluginKey'],
    row['provider'],
  ]);
}

bool _featureFlagEnabled(Map<String, dynamic> row) {
  if (_boolFrom(
    row['disabled'] ??
        row['is_disabled'] ??
        row['isDisabled'] ??
        row['hidden'] ??
        row['is_hidden'] ??
        row['isHidden'] ??
        row['unsupported'] ??
        row['is_unsupported'] ??
        row['isUnsupported'],
    fallback: false,
  )) {
    return false;
  }
  final supported = row['supported'] ??
      row['is_supported'] ??
      row['isSupported'] ??
      row['allowed'] ??
      row['is_allowed'] ??
      row['isAllowed'] ??
      row['available'] ??
      row['is_available'] ??
      row['isAvailable'] ??
      row['visible'] ??
      row['is_visible'] ??
      row['isVisible'];
  if (supported != null && !_boolFrom(supported, fallback: true)) {
    return false;
  }
  return _boolFrom(
    row['enabled'] ??
        row['is_enabled'] ??
        row['isEnabled'] ??
        row['active'] ??
        row['is_active'] ??
        row['isActive'] ??
        row['configured'] ??
        row['is_configured'] ??
        row['isConfigured'] ??
        row['status'] ??
        row['state'] ??
        row['value'],
    fallback: true,
  );
}

bool _featureFlagRowHasState(Map<String, dynamic> row) {
  return const {
    'enabled',
    'is_enabled',
    'isEnabled',
    'active',
    'is_active',
    'isActive',
    'available',
    'is_available',
    'isAvailable',
    'configured',
    'is_configured',
    'isConfigured',
    'supported',
    'is_supported',
    'isSupported',
    'allowed',
    'is_allowed',
    'isAllowed',
    'visible',
    'is_visible',
    'isVisible',
    'disabled',
    'is_disabled',
    'isDisabled',
    'hidden',
    'is_hidden',
    'isHidden',
    'unsupported',
    'is_unsupported',
    'isUnsupported',
    'status',
    'state',
    'value',
  }.any(row.containsKey);
}

String _featureFlagKey(Object? value) {
  final raw = value?.toString().trim() ?? '';
  if (raw.isEmpty) return '';
  final withSnakeCase = raw.replaceAllMapped(
    RegExp(r'([a-z0-9])([A-Z])'),
    (match) => '${match.group(1)}_${match.group(2)}',
  );
  return withSnakeCase
      .replaceAll(RegExp(r'[\s\-.]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .toLowerCase();
}

Map<String, dynamic> _runtimeAppearanceConfig(Map<String, dynamic> json) {
  return _mergeConfigMaps([
    json['appearance'],
    json['appearance_config'],
    json['appearanceConfig'],
    json['branding'],
    json['branding_config'],
    json['brandingConfig'],
    json['design'],
    json['design_config'],
    json['designConfig'],
    json['theme_settings'],
    json['themeSettings'],
  ]);
}

Map<String, dynamic> _liveConfigMap(Object? value) {
  final json = _asMap(value);
  if (json.isEmpty) return const <String, dynamic>{};

  final config = <String, dynamic>{...json};
  final youtubeUrl = _stringFrom([
    json['waiting_result_youtube_url'],
    json['waitingResultYoutubeUrl'],
    json['waiting_result_url'],
    json['waitingResultUrl'],
    json['youtube_url'],
    json['youtubeUrl'],
    json['url'],
  ]);
  final youtubeEmbedUrl = _stringFrom([
    json['waiting_result_youtube_embed_url'],
    json['waitingResultYoutubeEmbedUrl'],
    json['waiting_result_embed_url'],
    json['waitingResultEmbedUrl'],
    json['youtube_embed_url'],
    json['youtubeEmbedUrl'],
    json['embed_url'],
    json['embedUrl'],
  ]);
  final source = _stringFrom([
    json['source'],
    json['provider'],
    json['sourceName'],
    json['source_name'],
  ]);

  if (youtubeUrl.isNotEmpty) {
    config['waiting_result_youtube_url'] = youtubeUrl;
  }
  if (youtubeEmbedUrl.isNotEmpty) {
    config['waiting_result_youtube_embed_url'] = youtubeEmbedUrl;
  }
  if (source.isNotEmpty) {
    config['source'] = source;
  }
  return config;
}

Map<String, dynamic> _realtimeConfigMap(Object? value) {
  final json = _asMap(value);
  if (json.isEmpty) return const <String, dynamic>{};

  final config = <String, dynamic>{...json};
  final url = _stringFrom([
    json['url'],
    json['socket_url'],
    json['socketUrl'],
    json['websocket_url'],
    json['websocketUrl'],
    json['ws_url'],
    json['wsUrl'],
    json['realtime_url'],
    json['realtimeUrl'],
    json['endpoint'],
  ]);
  final key = _stringFrom([
    json['key'],
    json['app_key'],
    json['appKey'],
    json['pusher_app_key'],
    json['pusherAppKey'],
    json['pusher_key'],
    json['pusherKey'],
    json['broadcast_key'],
    json['broadcastKey'],
    json['public_key'],
    json['publicKey'],
  ]);
  final authEndpoint = _stringFrom([
    json['auth_endpoint'],
    json['authEndpoint'],
    json['auth_url'],
    json['authUrl'],
    json['auth_path'],
    json['authPath'],
    json['authorization_endpoint'],
    json['authorizationEndpoint'],
    json['channel_auth_endpoint'],
    json['channelAuthEndpoint'],
  ]);
  final client = _stringFrom([
    json['client'],
    json['client_name'],
    json['clientName'],
  ]);

  if (url.isNotEmpty) config['url'] = url;
  if (key.isNotEmpty) config['key'] = key;
  if (authEndpoint.isNotEmpty) config['authEndpoint'] = authEndpoint;
  if (client.isNotEmpty) config['client'] = client;
  return config;
}

Map<String, dynamic> _lineConfigMap(Object? value) {
  final json = _asMap(value);
  if (json.isEmpty) return const <String, dynamic>{};

  final config = <String, dynamic>{...json};
  final liff = _mergeConfigMaps([
    json['liff'],
    json['liffConfig'],
    json['line_liff'],
    json['lineLiff'],
  ]);
  final bot = _mergeConfigMaps([
    json['bot'],
    json['botConfig'],
    json['line_bot'],
    json['lineBot'],
    json['messaging_bot'],
    json['messagingBot'],
  ]);
  final liffId = _stringFrom([
    json['liffId'],
    json['liff_id'],
    json['line_liff_id'],
    json['lineLiffId'],
    liff['id'],
    liff['liff_id'],
    liff['liffId'],
    liff['app_id'],
    liff['appId'],
  ]);
  final botBasicId = _stringFrom([
    json['botBasicId'],
    json['bot_basic_id'],
    json['basicId'],
    json['basic_id'],
    json['lineBasicId'],
    json['line_basic_id'],
    bot['basic_id'],
    bot['basicId'],
    bot['bot_basic_id'],
    bot['botBasicId'],
    bot['id'],
  ]);
  final addFriendUrl = _stringFrom([
    json['addFriendUrl'],
    json['add_friend_url'],
    json['addFriendLink'],
    json['add_friend_link'],
    json['friendUrl'],
    json['friend_url'],
    json['lineAddFriendUrl'],
    json['line_add_friend_url'],
    json['lineFriendUrl'],
    json['line_friend_url'],
    bot['add_friend_url'],
    bot['addFriendUrl'],
    bot['friend_url'],
    bot['friendUrl'],
  ]);

  if (liffId.isNotEmpty) config['liffId'] = liffId;
  if (botBasicId.isNotEmpty) config['botBasicId'] = botBasicId;
  if (addFriendUrl.isNotEmpty) config['addFriendUrl'] = addFriendUrl;
  return config;
}

void _deepMergeConfigMap(
  Map<String, dynamic> target,
  Map<String, dynamic> source,
) {
  for (final entry in source.entries) {
    final value = entry.value;
    if (_isBlankConfigValue(value)) continue;

    final current = target[entry.key];
    if (current is Map && value is Map) {
      final nested = Map<String, dynamic>.from(current);
      _deepMergeConfigMap(nested, Map<String, dynamic>.from(value));
      target[entry.key] = nested;
      continue;
    }

    target[entry.key] = value;
  }
}

bool _isBlankConfigValue(Object? value) {
  if (value == null) return true;
  return value is String && value.trim().isEmpty;
}

String? _stringIfScalar(Object? value) {
  if (value is Map || value is Iterable) return null;
  final stringValue = value?.toString().trim() ?? '';
  return stringValue.isEmpty ? null : stringValue;
}

Map<String, dynamic> _screenSecurityFlatConfig(Map<String, dynamic> json) {
  const keys = [
    'android_flag_secure',
    'androidFlagSecure',
    'flag_secure',
    'flagSecure',
    'android_protect_recent_app_preview',
    'androidProtectRecentAppPreview',
    'protect_recent_app_preview',
    'protectRecentAppPreview',
    'ios_screenshot_policy',
    'iosScreenshotPolicy',
    'screenshot_policy',
    'screenshotPolicy',
    'ios_screen_capture_overlay',
    'iosScreenCaptureOverlay',
    'screen_capture_overlay',
    'screenCaptureOverlay',
    'ios_exit_app',
    'iosExitApp',
    'exit_app',
    'exitApp',
    'web_sensitive_screen_mode',
    'webSensitiveScreenMode',
    'sensitive_screen_mode',
    'sensitiveScreenMode',
    'web_watermark_enabled',
    'webWatermarkEnabled',
    'watermark_enabled',
    'watermarkEnabled',
    'ios_privacy_overlay_title',
    'iosPrivacyOverlayTitle',
    'privacy_overlay_title',
    'privacyOverlayTitle',
    'overlay_title',
    'overlayTitle',
    'screen_capture_title',
    'screenCaptureTitle',
    'security_capture_title',
    'securityCaptureTitle',
    'ios_privacy_overlay_description',
    'iosPrivacyOverlayDescription',
    'privacy_overlay_description',
    'privacyOverlayDescription',
    'overlay_description',
    'overlayDescription',
    'screen_capture_description',
    'screenCaptureDescription',
    'security_capture_description',
    'securityCaptureDescription',
    'sensitive_routes',
    'sensitiveRoutes',
    'sensitive_route_patterns',
    'sensitiveRoutePatterns',
    'sensitive_paths',
    'sensitivePaths',
    'protected_routes',
    'protectedRoutes',
    'secure_routes',
    'secureRoutes',
    'privacy_routes',
    'privacyRoutes',
    'route_patterns',
    'routePatterns',
    'routes',
  ];
  final config = <String, dynamic>{};
  for (final key in keys) {
    if (json.containsKey(key)) config[key] = json[key];
  }
  return config;
}

List<String> _screenSecurityRoutes(
  Map<String, dynamic> json,
  Map<String, dynamic> android,
  Map<String, dynamic> ios,
  Map<String, dynamic> web,
) {
  final routes = <String>[];
  final seen = <String>{};
  for (final source in [json, android, ios, web]) {
    for (final key in _screenSecurityRouteKeys) {
      for (final route in _screenSecurityRouteList(source[key])) {
        final normalized = _normalizeScreenSecurityPolicyRoute(route);
        if (normalized.isEmpty) continue;
        if (seen.add(normalized)) routes.add(normalized);
      }
    }
  }
  return routes;
}

const _screenSecurityRouteKeys = [
  'sensitive_routes',
  'sensitiveRoutes',
  'sensitive_route_patterns',
  'sensitiveRoutePatterns',
  'sensitive_paths',
  'sensitivePaths',
  'protected_routes',
  'protectedRoutes',
  'secure_routes',
  'secureRoutes',
  'privacy_routes',
  'privacyRoutes',
  'route_patterns',
  'routePatterns',
  'routes',
];

const _screenSecurityRouteValueKeys = [
  'route',
  'routeName',
  'route_name',
  'routePath',
  'route_path',
  'routeFullPath',
  'route_full_path',
  'currentRoute',
  'current_route',
  'activeRoute',
  'active_route',
  'targetRoute',
  'target_route',
  'path',
  'pattern',
  'uri',
  'href',
  'url',
  'urlString',
  'url_string',
  'fullPath',
  'full_path',
  'currentPath',
  'current_path',
  'activePath',
  'active_path',
  'targetPath',
  'target_path',
  'currentUrl',
  'current_url',
  'activeUrl',
  'active_url',
  'targetUrl',
  'target_url',
  'routeUrl',
  'route_url',
  'routerUrl',
  'router_url',
  'requestUrl',
  'request_url',
  'returnUrl',
  'return_url',
  'redirectUrl',
  'redirect_url',
  'redirect',
  'redirectUri',
  'redirect_uri',
  'continueUrl',
  'continue_url',
  'callbackUrl',
  'callback_url',
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
  'screen',
  'screenName',
  'screen_name',
  'screenPath',
  'screen_path',
  'screenUrl',
  'screen_url',
  'page',
  'pageName',
  'page_name',
  'pagePath',
  'page_path',
  'pageUrl',
  'page_url',
  'hash',
  'hashRoute',
  'hash_route',
  'hashPath',
  'hash_path',
  'fragment',
  'query',
  'queryString',
  'query_string',
  'location',
  'link',
  'linkUrl',
  'link_url',
];

List<String> _screenSecurityRouteList(Object? value) {
  if (value is String) return _stringList(value);
  if (value is Iterable) {
    return value.expand(_screenSecurityRouteList).toList(growable: false);
  }
  if (value is! Map) return const [];

  final json = _asMap(value);
  final enabled = _boolFrom(
    json['enabled'] ??
        json['is_enabled'] ??
        json['isEnabled'] ??
        json['active'] ??
        json['available'] ??
        json['status'],
    fallback: true,
  );
  if (!enabled) return const [];

  final route = _stringFrom(
    _screenSecurityRouteValueKeys.map((key) => json[key]),
  );
  if (route.isNotEmpty) return [route];

  final routes = <String>[];
  for (final key in [
    ..._screenSecurityRouteKeys,
    'items',
    'patterns',
    'paths',
    'pages',
  ]) {
    routes.addAll(_screenSecurityRouteList(json[key]));
  }

  for (final entry in json.entries) {
    final key = entry.key.toString().trim();
    if (key.isEmpty || _screenSecurityRouteKeys.contains(key)) continue;
    final raw = entry.value;
    if (_isBooleanLike(raw)) {
      if (_boolFrom(raw) && _looksLikeRoutePattern(key)) routes.add(key);
      continue;
    }
    if (raw is Map || raw is Iterable) {
      routes.addAll(_screenSecurityRouteList(raw));
    }
  }

  return routes;
}

String _normalizeScreenSecurityPolicyRoute(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '';

  final decoded = _decodeScreenSecurityPolicyRoute(trimmed);
  if (decoded != trimmed) {
    final decodedRoute = _normalizeScreenSecurityPolicyRoute(decoded);
    if (decodedRoute.isNotEmpty) return decodedRoute;
  }

  final queryPath = _screenSecurityPolicyPathFromQuery(trimmed);
  if (queryPath.isNotEmpty) return queryPath;

  final parsed = Uri.tryParse(trimmed);
  if (parsed != null) {
    final fragmentPath = _screenSecurityPolicyPathFromFragment(
      parsed.fragment,
    );
    if (fragmentPath.isNotEmpty) return fragmentPath;

    final parsedQueryPath = _screenSecurityPolicyPathFromQuery(parsed.query);
    if (parsedQueryPath.isNotEmpty) return parsedQueryPath;

    final hasUrlShape = parsed.hasScheme ||
        trimmed.startsWith('//') ||
        trimmed.startsWith('/') ||
        trimmed.startsWith('?');
    if (hasUrlShape) return _normalizeScreenSecurityPath(parsed.path);
  }

  return _normalizeScreenSecurityPath(
    trimmed.split('?').first.split('#').first,
  );
}

String _screenSecurityPolicyPathFromQuery(String query) {
  final trimmed = query.trim();
  final queryValue = trimmed.startsWith('?') ? trimmed.substring(1) : trimmed;
  if (!queryValue.contains('=')) return '';
  try {
    final params = Uri.splitQueryString(queryValue);
    for (final key in _screenSecurityRouteValueKeys) {
      final value = params[key]?.trim() ?? '';
      if (value.isEmpty) continue;
      return _normalizeScreenSecurityPolicyRoute(value);
    }
  } on FormatException {
    return '';
  }
  return '';
}

String _screenSecurityPolicyPathFromFragment(String fragment) {
  final decoded = _decodeScreenSecurityPolicyRoute(fragment.trim());
  final trimmed =
      decoded.startsWith('!') ? decoded.substring(1).trim() : decoded;
  if (trimmed.isEmpty) return '';

  final queryPath = _screenSecurityPolicyPathFromQuery(trimmed);
  if (queryPath.isNotEmpty) return queryPath;

  final parsed = Uri.tryParse(trimmed.startsWith('/') ? trimmed : '/$trimmed');
  if (parsed == null) return _normalizeScreenSecurityPath(trimmed);
  final parsedQueryPath = _screenSecurityPolicyPathFromQuery(parsed.query);
  if (parsedQueryPath.isNotEmpty) return parsedQueryPath;
  return _normalizeScreenSecurityPath(parsed.path);
}

String _decodeScreenSecurityPolicyRoute(String value) {
  if (!value.contains('%')) return value;
  try {
    final decoded = Uri.decodeComponent(value).trim();
    return decoded.isEmpty ? value : decoded;
  } on FormatException {
    return value;
  }
}

String _normalizeScreenSecurityPath(String value) {
  final path = value.trim();
  if (path.isEmpty) return '';
  final normalized = path.startsWith('/') ? path : '/$path';
  if (normalized.length == 1) return normalized;
  return normalized.replaceFirst(RegExp(r'/+$'), '');
}

bool _looksLikeRoutePattern(String value) {
  final trimmed = value.trim();
  return trimmed.startsWith('/') ||
      trimmed.startsWith(':') ||
      trimmed.contains('/') ||
      trimmed.contains('*');
}

List<Map<String, dynamic>> _socialProviderRows(Iterable<Object?> values) {
  final rows = <Map<String, dynamic>>[];
  for (final value in values) {
    rows.addAll(_socialProviderRowsFrom(value));
  }
  return rows;
}

List<Map<String, dynamic>> _socialProviderRowsFrom(Object? value) {
  if (value is List) {
    return value.expand(_socialProviderRowsFrom).toList(growable: false);
  }

  if (value is String) {
    final provider = value.trim();
    if (provider.isEmpty) return const [];
    return [
      {'provider': provider, 'enabled': true},
    ];
  }

  if (value is! Map) return const [];

  final json = Map<String, dynamic>.from(value);
  final directProvider = _stringFrom([
    json['provider'],
    json['key'],
    json['code'],
    json['slug'],
  ]);
  if (directProvider.isNotEmpty) return [json];

  final nestedRows = <Map<String, dynamic>>[];
  for (final nested in [
    json['providers'],
    json['auth_providers'],
    json['authProviders'],
    json['social_providers'],
    json['socialProviders'],
    json['items'],
  ]) {
    nestedRows.addAll(_socialProviderRowsFrom(nested));
  }

  for (final entry in json.entries) {
    final provider = _normalizeSocialProvider(entry.key.toString());
    if (!_supportedSocialProviders.contains(provider)) continue;

    final raw = entry.value;
    if (raw is Map) {
      final row = Map<String, dynamic>.from(raw);
      row.putIfAbsent('provider', () => provider);
      nestedRows.add(row);
    } else if (raw is bool) {
      nestedRows.add({'provider': provider, 'enabled': raw});
    } else if (raw != null) {
      nestedRows.add({'provider': provider, 'enabled': raw});
    }
  }

  return nestedRows;
}

String _runtimeTextFrom(Iterable<Object?> values, {String fallback = ''}) {
  for (final value in values) {
    final scalar = _stringIfScalar(value);
    if (scalar != null) return scalar;

    if (value is Iterable && value is! String) {
      final nested = _runtimeTextFrom(value);
      if (nested.isNotEmpty) return nested;
      continue;
    }

    final json = _asMap(value);
    if (json.isEmpty) continue;
    final nested = _runtimeTextFrom([
      json['content'],
      json['content_html'],
      json['contentHtml'],
      json['html'],
      json['markdown'],
      json['body'],
      json['text'],
      json['description'],
      json['message'],
      json['value'],
    ]);
    if (nested.isNotEmpty) return nested;
  }
  return fallback;
}

String _runtimeUrlFrom(Iterable<Object?> values, {String fallback = ''}) {
  for (final value in values) {
    final scalar = _stringIfScalar(value);
    if (scalar != null) return scalar;

    if (value is Iterable && value is! String) {
      final nested = _runtimeUrlFrom(value);
      if (nested.isNotEmpty) return nested;
      continue;
    }

    final json = _asMap(value);
    if (json.isEmpty) continue;
    final nested = _runtimeUrlFrom([
      json['url'],
      json['href'],
      json['uri'],
      json['link'],
      json['target'],
      json['target_url'],
      json['targetUrl'],
      json['action_url'],
      json['actionUrl'],
      json['request_url'],
      json['requestUrl'],
      json['policy_url'],
      json['policyUrl'],
      json['full_url'],
      json['fullUrl'],
      json['public_url'],
      json['publicUrl'],
      json['asset_url'],
      json['assetUrl'],
      json['value'],
    ]);
    if (nested.isNotEmpty) return nested;
  }
  return fallback;
}

Map<String, dynamic> _runtimeLinkForAliases(
  Iterable<Object?> values,
  Set<String> aliases,
) {
  for (final value in values) {
    final link = _runtimeLinkForAliasesFrom(value, aliases);
    if (link.isNotEmpty) return link;
  }
  return const <String, dynamic>{};
}

Map<String, dynamic> _runtimeLinkForAliasesFrom(
  Object? value,
  Set<String> aliases,
) {
  if (value == null) return const <String, dynamic>{};
  if (value is Iterable && value is! String) {
    for (final item in value) {
      final link = _runtimeLinkForAliasesFrom(item, aliases);
      if (link.isNotEmpty) return link;
    }
    return const <String, dynamic>{};
  }

  final json = _asMap(value);
  if (json.isEmpty) return const <String, dynamic>{};
  final rel = _runtimeAliasKey(
    _stringFrom([
      json['rel'],
      json['relation'],
      json['type'],
      json['kind'],
      json['key'],
      json['code'],
      json['name'],
    ]),
  );
  if (aliases.contains(rel)) return json;

  for (final entry in json.entries) {
    final key = _runtimeAliasKey(entry.key);
    if (!aliases.contains(key)) continue;
    return _runtimeLinkMap(entry.value);
  }

  for (final nestedKey in const [
    'links',
    'link',
    'urls',
    'url',
    'actions',
    'items',
    'rows',
    'external_links',
    'externalLinks',
    'store_links',
    'storeLinks',
    'legal_links',
    'legalLinks',
  ]) {
    final link = _runtimeLinkForAliasesFrom(json[nestedKey], aliases);
    if (link.isNotEmpty) return link;
  }

  return const <String, dynamic>{};
}

Map<String, dynamic> _runtimeLinkMap(Object? value) {
  final json = _asMap(value);
  if (json.isNotEmpty) return json;
  final scalar = _stringIfScalar(value);
  return scalar == null ? const <String, dynamic>{} : {'url': scalar};
}

String _runtimeContactValueFrom(
  Iterable<Object?> values,
  Set<String> aliases, {
  String fallback = '',
}) {
  for (final value in values) {
    final scalar = _stringIfScalar(value);
    if (scalar != null) return scalar;

    if (value is Iterable && value is! String) {
      final nested = _runtimeContactValueFrom(value, aliases);
      if (nested.isNotEmpty) return nested;
      continue;
    }

    final json = _asMap(value);
    if (json.isEmpty) continue;
    final rel = _runtimeAliasKey(
      _stringFrom([
        json['rel'],
        json['relation'],
        json['type'],
        json['kind'],
        json['channel'],
        json['key'],
        json['code'],
        json['name'],
      ]),
    );
    if (aliases.contains(rel)) {
      final direct = _runtimeContactDirectValue(json);
      if (direct.isNotEmpty) return direct;
    }

    for (final entry in json.entries) {
      final key = _runtimeAliasKey(entry.key);
      if (!aliases.contains(key)) continue;
      final nested = _runtimeContactValueFrom([entry.value], aliases);
      if (nested.isNotEmpty) return nested;
    }

    for (final nestedKey in const [
      'contact',
      'contacts',
      'channels',
      'support',
      'supportConfig',
      'support_channels',
      'supportChannels',
      'items',
      'rows',
    ]) {
      final nested = _runtimeContactValueFrom([json[nestedKey]], aliases);
      if (nested.isNotEmpty) return nested;
    }
  }
  return fallback;
}

String _runtimeContactDirectValue(Map<String, dynamic> json) {
  return _stringFrom([
    json['value'],
    json['label'],
    json['display_value'],
    json['displayValue'],
    json['address'],
    json['email'],
    json['emailAddress'],
    json['mail'],
    json['phone'],
    json['phoneNumber'],
    json['tel'],
    json['telephone'],
    json['url'],
    json['href'],
    json['uri'],
    json['link'],
  ]);
}

String _runtimeAliasKey(Object? value) => _featureFlagKey(value);

String _stringFrom(Iterable<Object?> values, {String fallback = ''}) {
  for (final value in values) {
    final stringValue = value?.toString().trim() ?? '';
    if (stringValue.isNotEmpty) return stringValue;
  }
  return fallback;
}

Color? _runtimeColorFrom(Iterable<Object?> values) {
  for (final value in values) {
    final color = AppThemeTokens.fromJson({'primary': value}).primaryColor;
    if (color != null) return color;
  }
  return null;
}

bool _boolFrom(Object? value, {bool fallback = false}) {
  if (value == null) return fallback;
  if (value is bool) return value;
  if (value is num) return value != 0;
  final normalized = value.toString().trim().toLowerCase();
  if (normalized.isEmpty) return fallback;
  return normalized == 'true' ||
      normalized == '1' ||
      normalized == 'yes' ||
      normalized == 'y' ||
      normalized == 'on' ||
      normalized == 'enable' ||
      normalized == 'enabled' ||
      normalized == 'active' ||
      normalized == 'available' ||
      normalized == 'allow' ||
      normalized == 'allowed' ||
      normalized == 'ready' ||
      normalized == 'configured' ||
      normalized == 'support' ||
      normalized == 'supported';
}

bool _isBooleanLike(Object? value) {
  if (value is bool || value is num) return true;
  final normalized = value?.toString().trim().toLowerCase() ?? '';
  return {
    'true',
    'false',
    '1',
    '0',
    'yes',
    'no',
    'y',
    'n',
    'on',
    'off',
    'enable',
    'enabled',
    'disable',
    'disabled',
    'active',
    'inactive',
    'available',
    'unavailable',
    'allow',
    'allowed',
    'deny',
    'denied',
    'ready',
    'configured',
    'support',
    'supported',
    'unsupported',
  }.contains(normalized);
}

int? _intFrom(Object? value) {
  return int.tryParse(value?.toString().trim() ?? '');
}

List<String> _stringList(Object? value) {
  if (value is String) {
    return value
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
  if (value is! Iterable) return const [];
  return value
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

const _supportedSocialProviders = {'line', 'google', 'apple'};

const _privacyPolicyLinkAliases = {
  'privacy',
  'privacy_policy',
  'privacy_policy_url',
  'privacy_policy_link',
  'privacy_notice',
  'privacy_notice_url',
  'policy',
  'data_privacy',
  'store_privacy',
  'store_privacy_policy',
  'store_privacy_policy_url',
  'listing_privacy_policy',
  'listing_privacy_policy_url',
  'app_privacy',
  'app_privacy_policy',
  'app_privacy_policy_url',
  'app_store_privacy',
  'app_store_privacy_policy',
  'app_store_privacy_policy_url',
  'play_store_privacy',
  'play_store_privacy_policy',
  'play_store_privacy_policy_url',
  'developer_privacy',
  'developer_privacy_policy',
};

const _accountDeletionLinkAliases = {
  'account_deletion',
  'account_deletion_url',
  'account_deletion_link',
  'account_delete',
  'account_delete_url',
  'delete_account',
  'delete_account_url',
  'data_deletion',
  'data_deletion_url',
  'data_deletion_link',
  'data_delete',
  'data_delete_url',
  'deletion',
  'deletion_url',
  'delete_profile',
  'profile_deletion',
  'erase_account',
  'store_account_deletion',
  'store_account_deletion_url',
  'listing_account_deletion',
  'listing_account_deletion_url',
  'app_store_account_deletion',
  'play_store_account_deletion',
  'customer_account_deletion',
};

const _supportPhoneContactAliases = {
  'support_phone',
  'store_support_phone',
  'listing_support_phone',
  'developer_phone',
  'developer_support_phone',
  'customer_service_phone',
  'phone',
  'phone_number',
  'telephone',
  'tel',
  'call',
  'hotline',
  'customer_support_phone',
  'support_call',
};

const _supportEmailContactAliases = {
  'support_email',
  'store_support_email',
  'listing_support_email',
  'developer_email',
  'developer_support_email',
  'customer_service_email',
  'email',
  'email_address',
  'mail',
  'mailto',
  'customer_support_email',
  'support_mail',
};

const _supportLinkAliases = {
  'support',
  'support_url',
  'support_link',
  'store_support',
  'store_support_url',
  'store_support_link',
  'store_listing_support',
  'store_listing_support_url',
  'listing_support',
  'listing_support_url',
  'app_store_support',
  'app_store_support_url',
  'play_store_support',
  'play_store_support_url',
  'developer_contact',
  'developer_contact_url',
  'developer_support',
  'developer_support_url',
  'developer_website',
  'customer_support',
  'customer_support_url',
  'customer_service',
  'customer_service_url',
  'help',
  'help_url',
  'help_link',
  'help_center',
  'help_center_url',
  'support_center',
  'support_center_url',
  'service_center',
  'service_center_url',
  'contact',
  'contact_url',
  'contact_link',
  'contact_us',
  'contact_us_url',
  'website',
  'support_website',
  'support_page',
};

String _normalizeSocialProvider(String value) {
  final token = value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[\s\-.]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  return switch (token) {
    'gmail' || 'google_login' || 'google_oauth' || 'google_oauth2' => 'google',
    'apple_id' || 'apple_login' || 'sign_in_with_apple' => 'apple',
    'line_login' || 'line_oa' || 'line_oauth' => 'line',
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
