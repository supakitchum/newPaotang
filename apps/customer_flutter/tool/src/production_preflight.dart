import 'dart:convert';
import 'dart:io';

import 'deep_link_association_files.dart';
import 'release_branding.dart';

enum CustomerFlutterTarget {
  web,
  android,
  ios,
  all;

  bool get includesWeb => this == web || this == all;
  bool get includesAndroid => this == android || this == all;
  bool get includesIos => this == ios || this == all;
}

class ProductionPreflightInput {
  const ProductionPreflightInput({
    required this.target,
    required this.production,
    required this.checkFiles,
    required this.androidRequireSigning,
    this.projectRoot = '.',
    this.apiBaseUrl,
    this.appDisplayName,
    this.androidPackage,
    this.androidCallbackScheme,
    this.androidCallbackHost,
    this.androidStoreFile,
    this.androidStorePassword,
    this.androidKeyAlias,
    this.androidKeyPassword,
    this.tenantHost,
    this.iosTeamId,
    this.iosBundleId,
    this.iosUrlScheme,
    this.iosAssociatedDomain,
    this.socialAuthProviders = const [],
    this.linkAssociationDir,
    this.webAppName,
    this.webShortName,
    this.webDescription,
    this.requireStoreListingMetadata = false,
    this.storePrivacyPolicyUrl,
    this.storeSupportUrl,
    this.storeAccountDeletionUrl,
    this.requireReleaseBranding = false,
    this.releaseBrandingManifest,
  });

  final CustomerFlutterTarget target;
  final bool production;
  final bool checkFiles;
  final bool androidRequireSigning;
  final String projectRoot;
  final String? apiBaseUrl;
  final String? appDisplayName;
  final String? androidPackage;
  final String? androidCallbackScheme;
  final String? androidCallbackHost;
  final String? androidStoreFile;
  final String? androidStorePassword;
  final String? androidKeyAlias;
  final String? androidKeyPassword;
  final String? tenantHost;
  final String? iosTeamId;
  final String? iosBundleId;
  final String? iosUrlScheme;
  final String? iosAssociatedDomain;
  final List<String> socialAuthProviders;
  final String? linkAssociationDir;
  final String? webAppName;
  final String? webShortName;
  final String? webDescription;
  final bool requireStoreListingMetadata;
  final String? storePrivacyPolicyUrl;
  final String? storeSupportUrl;
  final String? storeAccountDeletionUrl;
  final bool requireReleaseBranding;
  final String? releaseBrandingManifest;
}

class ProductionPreflightIssue {
  const ProductionPreflightIssue({
    required this.code,
    required this.message,
    this.blocking = true,
  });

  final String code;
  final String message;
  final bool blocking;

  @override
  String toString() => '[$code] $message';
}

List<ProductionPreflightIssue> runCustomerFlutterProductionPreflight(
  ProductionPreflightInput input,
) {
  final issues = <ProductionPreflightIssue>[];

  _checkApiBaseUrl(input, issues);
  _checkNativeTenantHost(input, issues);
  _checkDisplayName(input, issues);
  _checkWebProductionMetadataInput(input, issues);
  _checkStoreListingMetadataInput(input, issues);
  _checkReleaseBranding(input, issues);
  _checkSocialProviderValues(input, issues);
  _checkSocialLoginStoreCompliance(input, issues);
  if (input.production && input.checkFiles) {
    _checkStoreAccountReadiness(input, issues);
    _checkDeepLinkAssociationFiles(input, issues);
    _checkForbiddenProductionSourceReferences(input, issues);
    _checkExternalLinkLaunchPolicy(input, issues);
    _checkFlutterRuntimeThemeBinding(input, issues);
    _checkFlutterSystemChromeIdentityBinding(input, issues);
    _checkFlutterSplashIdentityBinding(input, issues);
    _checkFlutterRouteRegistryBinding(input, issues);
    _checkFlutterMaintenanceRoutePolicyBinding(input, issues);
    _checkFlutterFeatureFlagRoutePolicyBinding(input, issues);
    _checkFlutterAuthOtpParserBinding(input, issues);
    _checkFlutterTenantScopedAuthStorageBinding(input, issues);
    _checkFlutterReleaseBrandingPipelineBinding(input, issues);
    _checkFlutterAffiliateCentralPinBinding(input, issues);
    _checkFlutterSocialCallbackBinding(input, issues);
    _checkFlutterSocialCallbackRouteBinding(input, issues);
    _checkFlutterSocialProviderRuntimeColorBinding(input, issues);
    _checkFlutterRealtimeBinding(input, issues);
    if (input.target.includesWeb) {
      _checkFlutterWebDeploymentFreshnessBinding(input, issues);
      _checkWebRuntimeMetadata(input, issues);
      _checkFlutterWebPrivacyBinding(input, issues);
    }
  }
  if (input.checkFiles &&
      (input.target.includesAndroid || input.target.includesIos)) {
    _checkFlutterNativePushBinding(input, issues);
    _checkFlutterScreenSecurityBinding(input, issues);
    _checkFlutterBiometricBinding(input, issues);
  }
  if (input.target.includesAndroid) _checkAndroid(input, issues);
  if (input.target.includesIos) _checkIos(input, issues);

  return issues;
}

void _checkFlutterNativePushBinding(
  ProductionPreflightInput input,
  List<ProductionPreflightIssue> issues,
) {
  final commonFiles = <String, List<String>>{
    'pubspec.yaml': const [
      'firebase_core:',
      'firebase_messaging:',
      'flutter_local_notifications:',
      'device_info_plus:',
      'package_info_plus:',
    ],
    'lib/main.dart': const [
      'CustomerPushPlatform.initialize()',
      'customerPushPlatformProvider.overrideWithValue(pushPlatform)',
    ],
    'lib/app/customer_app.dart': const ['CustomerPushLifecycleMonitor('],
    'lib/core/notifications/customer_push_platform.dart': const [
      'customerFirebaseMessagingBackgroundHandler',
      'FirebaseMessaging.onBackgroundMessage',
      'FirebaseMessaging.onMessage.listen',
      'FirebaseMessaging.onMessageOpenedApp.listen',
      'messaging.getInitialMessage()',
      'AndroidNotificationChannel(',
      "channelId = 'customer_updates'",
      '_localNotificationsReady',
      'useSystemForegroundPresentation',
    ],
    'lib/core/notifications/customer_push_lifecycle_monitor.dart': const [
      'platform.tokenRefresh.listen',
      '_syncQueue = _syncQueue.then',
      'await _syncQueue;',
      'registerBeforeLogoutHook',
      'customerPushDeviceContextLoaderProvider',
      '.registerDevice(',
      '.revokeDevice(installationId)',
      "widget.router.go('/notifications')",
    ],
    'lib/core/notifications/customer_push_device_context.dart': const [
      'CustomerPushDeviceContext.normalized(',
      '_normalizedPushMetadata(',
      '_boundedPushText(',
      "'is_physical_device'",
    ],
  };

  final missingCommon = _missingFileSnippets(input.projectRoot, commonFiles);
  if (missingCommon.isNotEmpty) {
    issues.add(
      ProductionPreflightIssue(
        code: 'flutter_native_push_binding_missing',
        message:
            'Native customer releases must initialize FCM, present foreground notifications, register refreshed tokens, preserve notification taps through auth/PIN, and revoke the installation on logout. Missing: ${missingCommon.join(', ')}',
      ),
    );
  }

  if (input.target.includesAndroid) {
    final missingAndroid = _missingFileSnippets(input.projectRoot, {
      'android/app/src/main/AndroidManifest.xml': const [
        'android.permission.POST_NOTIFICATIONS',
        'com.google.firebase.messaging.default_notification_channel_id',
        'com.google.firebase.messaging.default_notification_icon',
        '@drawable/ic_stat_customer_notification',
      ],
      'android/app/build.gradle.kts': const [
        'google-services.json',
        'com.google.gms.google-services',
        'releaseTaskRequested && !customerFirebaseConfig.exists()',
        'Firebase config is required for customer_flutter Android release builds',
      ],
      'android/app/src/main/res/drawable/ic_stat_customer_notification.xml':
          const ['<vector'],
    });
    if (missingAndroid.isNotEmpty) {
      issues.add(
        ProductionPreflightIssue(
          code: 'android_native_push_config_missing',
          message:
              'Android native push requires notification permission, a stable channel/icon, conditional Google Services wiring, and a release build failure when the injected Firebase secret is absent. Missing: ${missingAndroid.join(', ')}',
        ),
      );
    }
  }

  if (input.target.includesIos) {
    final missingIos = _missingFileSnippets(input.projectRoot, {
      'ios/Runner/Runner.entitlements': const [
        '<key>aps-environment</key>',
        r'$(CUSTOMER_FLUTTER_APS_ENVIRONMENT)',
      ],
      'ios/Runner/Info.plist': const [
        '<key>UIBackgroundModes</key>',
        '<string>remote-notification</string>',
      ],
      'ios/scripts/copy_firebase_config.sh': const [
        'CUSTOMER_FLUTTER_FIREBASE_IOS_PLIST',
        'PRODUCT_BUNDLE_IDENTIFIER',
        'GoogleService-Info.plist',
        r'configured_bundle_id="$(plist_value BUNDLE_ID)"',
      ],
      'ios/Runner.xcodeproj/project.pbxproj': const [
        'Copy Firebase Config',
        'scripts/copy_firebase_config.sh',
      ],
    });
    if (missingIos.isNotEmpty) {
      issues.add(
        ProductionPreflightIssue(
          code: 'ios_native_push_config_missing',
          message:
              'iOS native push requires the APNs entitlement, remote-notification background mode, and secret-injected Firebase plist validation against the release bundle ID. Missing: ${missingIos.join(', ')}',
        ),
      );
    }
  }
}

List<String> _missingFileSnippets(
  String projectRoot,
  Map<String, List<String>> requiredFiles,
) {
  final missing = <String>[];
  for (final entry in requiredFiles.entries) {
    final file = File(_join(projectRoot, entry.key));
    if (!file.existsSync()) {
      missing.add(entry.key);
      continue;
    }

    final source = file.readAsStringSync();
    for (final snippet in entry.value) {
      if (!source.contains(snippet)) {
        missing.add('${entry.key} missing $snippet');
      }
    }
  }
  return missing;
}

void _checkFlutterRuntimeThemeBinding(
  ProductionPreflightInput input,
  List<ProductionPreflightIssue> issues,
) {
  final app = File(_join(input.projectRoot, 'lib/app/customer_app.dart'));
  final theme = File(_join(input.projectRoot, 'lib/core/theme/app_theme.dart'));
  if (!app.existsSync() || !theme.existsSync()) {
    issues.add(
      const ProductionPreflightIssue(
        code: 'flutter_runtime_theme_binding_missing',
        message:
            'CustomerApp must apply the tenant theme returned by the runtime bootstrap API.',
      ),
    );
    return;
  }

  final appSource = app.readAsStringSync();
  final themeSource = theme.readAsStringSync();
  final appliesRuntimeTheme =
      appSource.contains('tokens: data.theme') &&
      appSource.contains('useRuntimeBrandColors: true');
  final keepsBlueFallback =
      themeSource.contains('bool useRuntimeBrandColors = false') &&
      themeSource.contains('primaryColor: AppTheme.appBlue') &&
      themeSource.contains("fontFamily: 'Kanit'");

  if (appliesRuntimeTheme && keepsBlueFallback) return;

  issues.add(
    const ProductionPreflightIssue(
      code: 'flutter_runtime_theme_binding_missing',
      message:
          'Production customer rendering must apply runtime bootstrap theme values while preserving Nuxt blue #087FF0 and Kanit as the pre-bootstrap/fallback identity.',
    ),
  );
}

void _checkFlutterWebDeploymentFreshnessBinding(
  ProductionPreflightInput input,
  List<ProductionPreflightIssue> issues,
) {
  final requiredFiles = <String, List<String>>{
    'web/flutter_bootstrap.js': const [
      '{{flutter_js}}',
      '{{flutter_build_config}}',
      'navigator.serviceWorker.getRegistrations()',
      'flutter_service_worker.js',
      'registration.unregister()',
      'navigator.serviceWorker.controller',
      'window.location.reload()',
      '_flutter.loader.load();',
    ],
    'docker/nginx.conf': const [
      'location = /customer-runtime-config.js',
      r'location ~* \.(?:css|js|mjs|wasm|json|map)$',
      'Cache-Control "no-cache, no-store, must-revalidate"',
      r'location ~* \.(?:jpg|jpeg|png|gif|svg|ico|woff2?|ttf|eot|otf|webp|avif)$',
      'Cache-Control "public, max-age=0, must-revalidate"',
    ],
    'web/index.html': const [
      '<script src="customer-runtime-config.js"></script>',
      'window.customerFlutterWebConfig',
    ],
    'web/customer-runtime-config.js': const ['window.customerFlutterWebConfig'],
    'docker/40-render-runtime-config.sh': const [
      'CUSTOMER_FLUTTER_WEB_APP_NAME',
      'CUSTOMER_FLUTTER_WEB_SHORT_NAME',
      'CUSTOMER_FLUTTER_WEB_DESCRIPTION',
      'CUSTOMER_FLUTTER_WEB_ICON_192_URL',
      'CUSTOMER_FLUTTER_WEB_ICON_512_URL',
      'CUSTOMER_FLUTTER_WEB_MASKABLE_ICON_192_URL',
      'CUSTOMER_FLUTTER_WEB_MASKABLE_ICON_512_URL',
      'CUSTOMER_FLUTTER_WEB_CANONICAL_URL',
      'with_entries(select(.value != ""))',
      'Object.assign({}, window.customerFlutterWebConfig || {},',
      r'manifest_output="$root/manifest.json"',
      r"'$value | @html'",
      'property="og:title"',
      'rel="canonical"',
      'index_template=/etc/customer/index.html.template',
      r'cp "$index_template" "$index_output"',
    ],
    'Dockerfile': const [
      'apk add --no-cache jq',
      'COPY docker/40-render-runtime-config.sh /docker-entrypoint.d/40-render-runtime-config.sh',
      'cp /usr/share/nginx/html/index.html /etc/customer/index.html.template',
    ],
  };

  final missing = <String>[];
  for (final entry in requiredFiles.entries) {
    final file = File(_join(input.projectRoot, entry.key));
    if (!file.existsSync()) {
      missing.add(entry.key);
      continue;
    }

    final source = file.readAsStringSync();
    for (final snippet in entry.value) {
      if (!source.contains(snippet)) {
        missing.add('${entry.key} missing $snippet');
      }
    }
    if (entry.key == 'web/flutter_bootstrap.js' &&
        source.contains('serviceWorkerSettings')) {
      missing.add('${entry.key} still registers a Flutter service worker');
    }
    if (entry.key == 'docker/nginx.conf' &&
        source.contains('max-age=2592000')) {
      missing.add('${entry.key} still caches mutable Flutter assets for 30d');
    }
  }

  if (missing.isEmpty) return;

  issues.add(
    ProductionPreflightIssue(
      code: 'flutter_web_deployment_freshness_missing',
      message:
          'Web production must remove the legacy Flutter service worker and revalidate mutable build assets so deployed UI/API fixes appear without a stale app shell. Missing: ${missing.join(', ')}',
    ),
  );
}

void _checkFlutterReleaseBrandingPipelineBinding(
  ProductionPreflightInput input,
  List<ProductionPreflightIssue> issues,
) {
  final requiredFiles = <String, List<String>>{
    'pubspec.yaml': const ['flutter_launcher_icons:', 'crypto:', 'image:'],
    'tool/prepare_release_branding.dart': const [
      'prepareReleaseBranding(',
      '--partner-id',
      '--icon-source',
      '--adaptive-foreground',
    ],
    'tool/src/release_branding.dart': const [
      'knownFlutterIconHashes',
      'flutter_launcher_icons',
      'verifyReleaseBrandingManifest(',
      'icon_source_sha256',
      'branding file changed after generation',
    ],
    'android/app/src/main/AndroidManifest.xml': const [
      'android:icon="@mipmap/ic_launcher"',
      'android:roundIcon="@mipmap/ic_launcher"',
    ],
  };

  final missing = <String>[];
  for (final entry in requiredFiles.entries) {
    final file = File(_join(input.projectRoot, entry.key));
    if (!file.existsSync()) {
      missing.add(entry.key);
      continue;
    }
    final source = file.readAsStringSync();
    for (final snippet in entry.value) {
      if (!source.contains(snippet)) {
        missing.add('${entry.key} missing $snippet');
      }
    }
  }

  if (missing.isEmpty) return;
  issues.add(
    ProductionPreflightIssue(
      code: 'flutter_release_branding_pipeline_missing',
      message:
          'Production releases must generate partner launcher icons and verify their hash manifest instead of shipping Flutter scaffold icons. Missing: ${missing.join(', ')}',
    ),
  );
}

void _checkReleaseBranding(
  ProductionPreflightInput input,
  List<ProductionPreflightIssue> issues,
) {
  if (!input.production || !input.requireReleaseBranding) return;

  final configuredPath = input.releaseBrandingManifest?.trim();
  final manifestPath = configuredPath == null || configuredPath.isEmpty
      ? defaultReleaseBrandingManifestPath
      : configuredPath;
  final manifest = File(
    _isAbsolutePath(manifestPath)
        ? manifestPath
        : _join(input.projectRoot, manifestPath),
  );

  ReleaseBrandingVerification verification;
  try {
    verification = verifyReleaseBrandingManifest(
      projectRoot: Directory(input.projectRoot),
      manifest: manifest,
      includeAndroid: input.target.includesAndroid,
      includeIos: input.target.includesIos,
      includeWeb: input.target.includesWeb,
    );
  } on Object catch (error) {
    issues.add(
      ProductionPreflightIssue(
        code: 'release_branding_invalid',
        message: 'Could not verify release branding: $error',
      ),
    );
    return;
  }

  if (verification.isValid) return;
  issues.add(
    ProductionPreflightIssue(
      code: 'release_branding_invalid',
      message:
          'Store release branding is missing, stale, or still generic. Run tool/prepare_release_branding.dart for this partner. ${verification.issues.join('; ')}',
    ),
  );
}

void _checkFlutterTenantScopedAuthStorageBinding(
  ProductionPreflightInput input,
  List<ProductionPreflightIssue> issues,
) {
  final main = File(_join(input.projectRoot, 'lib/main.dart'));
  final tokenStore = File(
    _join(input.projectRoot, 'lib/core/auth/auth_token_store.dart'),
  );
  final tenantHost = File(
    _join(input.projectRoot, 'lib/core/tenant/customer_tenant_host.dart'),
  );
  if (!main.existsSync() ||
      !tokenStore.existsSync() ||
      !tenantHost.existsSync()) {
    issues.add(
      const ProductionPreflightIssue(
        code: 'flutter_tenant_scoped_auth_storage_missing',
        message:
            'Flutter production auth storage must be scoped by the resolved tenant host.',
      ),
    );
    return;
  }

  _requireAllSnippets(
    '${main.readAsStringSync()}\n'
    '${tokenStore.readAsStringSync()}\n'
    '${tenantHost.readAsStringSync()}',
    const [
      'currentWebHost',
      'resolveCustomerTenantHost(',
      'storageScope:',
      'customerTenantStorageScope(',
      '_storageScope',
      '_restoreLegacyCredentials()',
      '_key(_accessKey)',
      '_key(_refreshKey)',
      '_key(_socialCallbackAuthStatesKey)',
      '_key(_socialCallbackRedirectStatesKey)',
      '_sessionStorageKeys(includeLegacy: true)',
    ],
    const ProductionPreflightIssue(
      code: 'flutter_tenant_scoped_auth_storage_missing',
      message:
          'Flutter production auth/session and social callback storage must resolve the tenant host, isolate secure-storage keys, preserve legacy sessions during migration, and clear only the active tenant scope.',
    ),
    issues,
  );
}

void _checkFlutterSystemChromeIdentityBinding(
  ProductionPreflightInput input,
  List<ProductionPreflightIssue> issues,
) {
  final app = File(_join(input.projectRoot, 'lib/app/customer_app.dart'));
  if (!app.existsSync()) {
    issues.add(
      const ProductionPreflightIssue(
        code: 'flutter_system_chrome_identity_missing',
        message:
            'CustomerApp must bind system status/navigation chrome to the Nuxt customer identity.',
      ),
    );
    return;
  }

  _requireAllSnippets(
    app.readAsStringSync(),
    const [
      'AnnotatedRegion<SystemUiOverlayStyle>',
      'final systemUiOverlayStyle = _systemUiOverlayStyleFor(appTheme);',
      'final statusBarColor = theme.colorScheme.primary;',
      'final navigationBarColor = theme.scaffoldBackgroundColor;',
      'ThemeData.estimateBrightnessForColor',
      'statusBarColor: statusBarColor',
      'statusBarIconBrightness:',
      'systemNavigationBarColor: navigationBarColor',
      'systemNavigationBarIconBrightness:',
      'systemNavigationBarDividerColor: theme.colorScheme.outlineVariant',
      '_contrastingBrightness(',
      'systemNavigationBarContrastEnforced: false',
    ],
    const ProductionPreflightIssue(
      code: 'flutter_system_chrome_identity_missing',
      message:
          'CustomerApp must derive native system chrome from the resolved customer theme: Nuxt-blue status chrome, runtime neutral navigation surface, and contrasting icons.',
    ),
    issues,
  );
}

void _checkFlutterSplashIdentityBinding(
  ProductionPreflightInput input,
  List<ProductionPreflightIssue> issues,
) {
  final splash = File(
    _join(input.projectRoot, 'lib/shared/widgets/app_splash.dart'),
  );
  final main = File(_join(input.projectRoot, 'lib/main.dart'));
  final pubspec = File(_join(input.projectRoot, 'pubspec.yaml'));
  final artwork = File(
    _join(input.projectRoot, 'assets/images/splash/siamblend_splash.jpg'),
  );
  if (!splash.existsSync() ||
      !main.existsSync() ||
      !pubspec.existsSync() ||
      !artwork.existsSync()) {
    issues.add(
      const ProductionPreflightIssue(
        code: 'flutter_splash_identity_missing',
        message:
            'Flutter startup must bundle the owner-approved Siamblend splash artwork and pre-cache it before runApp.',
      ),
    );
    return;
  }

  _requireAllSnippets(
    splash.readAsStringSync(),
    const [
      "const appSplashBackgroundAsset = 'assets/images/splash/siamblend_splash.jpg';",
      'precacheAppSplashBackground()',
      '_appSplashFallbackColor = Color(0xFF0B96DC)',
      'appSplashMinimumDurationProvider',
      'appSplashFadeDurationProvider',
      'mobileBootstrapProvider',
      'authSessionStartupProvider',
      '_SplashArtwork',
      'Image.asset(',
      'BoxFit.contain',
      'BoxFit.cover',
      "ValueKey('app-splash-background')",
      '_SplashLoader',
      "ValueKey('app-splash-loader')",
      'Color(0xFFE7B64C)',
    ],
    const ProductionPreflightIssue(
      code: 'flutter_splash_identity_missing',
      message:
          'Flutter splash must use the responsive owner-approved Siamblend artwork and matching safe-area gold loading treatment while preserving bootstrap/auth readiness.',
    ),
    issues,
  );
  _requireSnippet(
    main.readAsStringSync(),
    'await precacheAppSplashBackground();',
    const ProductionPreflightIssue(
      code: 'flutter_splash_identity_missing',
      message:
          'Flutter must pre-cache the Siamblend splash artwork before runApp to prevent a startup decode flash.',
    ),
    issues,
  );
  _requireSnippet(
    pubspec.readAsStringSync(),
    'assets/images/splash/',
    const ProductionPreflightIssue(
      code: 'flutter_splash_identity_missing',
      message:
          'pubspec.yaml must package the Siamblend splash artwork used by AppSplashHost.',
    ),
    issues,
  );
}

void _checkFlutterRouteRegistryBinding(
  ProductionPreflightInput input,
  List<ProductionPreflightIssue> issues,
) {
  final routes = File(_join(input.projectRoot, 'lib/app/customer_routes.dart'));
  if (!routes.existsSync()) {
    issues.add(
      const ProductionPreflightIssue(
        code: 'flutter_route_registry_missing',
        message: 'Flutter customer route registry was not found.',
      ),
    );
  } else {
    final source = routes.readAsStringSync();
    _requireAllSnippets(
      source,
      const [
        'normalizeCustomerRoutePath',
        '_customerRoutePathFromFragment',
        'currentUrl',
        'activeUrl',
        'targetUrl',
        'routeUrl',
        'returnUrl',
        'redirectUrl',
        'href',
        'uri',
      ],
      const ProductionPreflightIssue(
        code: 'flutter_route_registry_url_normalization_missing',
        message:
            'Flutter route registry must normalize full URL, hash, and query-shaped route values before sensitive-route matching.',
      ),
      issues,
    );
  }
}

void _checkFlutterMaintenanceRoutePolicyBinding(
  ProductionPreflightInput input,
  List<ProductionPreflightIssue> issues,
) {
  final bootstrap = File(
    _join(
      input.projectRoot,
      'lib/core/tenant/mobile_bootstrap_controller.dart',
    ),
  );
  if (!bootstrap.existsSync()) {
    issues.add(
      const ProductionPreflightIssue(
        code: 'flutter_maintenance_route_policy_missing',
        message:
            'Flutter mobile bootstrap maintenance route-policy parser was not found.',
      ),
    );
  } else {
    final source = bootstrap.readAsStringSync();
    _requireAllSnippets(
      source,
      const [
        'class MaintenanceConfig',
        'bool blocksRoute',
        '_maintenanceFlatConfig',
        'allowed_routes',
        'allowedRoutes',
        'blocked_route_patterns',
        'blockedRoutePatterns',
        'maintenanceAllowedRoutes',
        'maintenanceBlockedRoutePatterns',
        '_maintenancePath',
        '_normalizeScreenSecurityPolicyRoute',
        '_screenSecurityRouteValueKeys',
        'deepLink',
        'hashRoute',
        'returnUrl',
        'checkout_payment_only',
        'customer_web_only',
        'scheduled',
        'admin_only',
        'read_only',
        "site['maintenance']",
        "mobile['maintenance']",
      ],
      const ProductionPreflightIssue(
        code: 'flutter_maintenance_route_policy_missing',
        message:
            'Flutter mobile bootstrap must preserve Nuxt-style maintenance allowed_routes, blocked_route_patterns, mode aliases, and root/site/mobile config merging.',
      ),
      issues,
    );
  }

  final router = File(_join(input.projectRoot, 'lib/app/router.dart'));
  if (!router.existsSync()) {
    issues.add(
      const ProductionPreflightIssue(
        code: 'flutter_maintenance_router_binding_missing',
        message: 'Flutter router maintenance policy binding was not found.',
      ),
    );
    return;
  }

  final source = router.readAsStringSync();
  _requireAllSnippets(
    source,
    const [
      'mobileBootstrapProvider',
      'listen<AsyncValue<MobileBootstrap>>',
      '_RouterRefreshNotifier',
      'MaintenanceConfig? maintenance',
      'maintenance?.blocksRoute(path)',
    ],
    const ProductionPreflightIssue(
      code: 'flutter_maintenance_router_binding_missing',
      message:
          'Flutter router must refresh on mobile bootstrap changes and route through MaintenanceConfig.blocksRoute instead of a flat active flag.',
    ),
    issues,
  );
}

void _checkFlutterFeatureFlagRoutePolicyBinding(
  ProductionPreflightInput input,
  List<ProductionPreflightIssue> issues,
) {
  final bootstrap = File(
    _join(
      input.projectRoot,
      'lib/core/tenant/mobile_bootstrap_controller.dart',
    ),
  );
  final policy = File(
    _join(input.projectRoot, 'lib/core/tenant/mobile_runtime_policy.dart'),
  );
  final router = File(_join(input.projectRoot, 'lib/app/router.dart'));
  final profile = File(
    _join(
      input.projectRoot,
      'lib/features/profile/presentation/profile_screen.dart',
    ),
  );
  final shell = File(
    _join(input.projectRoot, 'lib/shared/widgets/app_shell.dart'),
  );

  final missingFiles = <String>[
    if (!bootstrap.existsSync())
      'lib/core/tenant/mobile_bootstrap_controller.dart',
    if (!policy.existsSync()) 'lib/core/tenant/mobile_runtime_policy.dart',
    if (!router.existsSync()) 'lib/app/router.dart',
    if (!profile.existsSync())
      'lib/features/profile/presentation/profile_screen.dart',
    if (!shell.existsSync()) 'lib/shared/widgets/app_shell.dart',
  ];
  if (missingFiles.isNotEmpty) {
    issues.add(
      ProductionPreflightIssue(
        code: 'flutter_feature_flag_route_policy_missing',
        message:
            'Flutter BO feature flag route/menu/bottom-nav policy files are missing: ${missingFiles.join(', ')}',
      ),
    );
    return;
  }

  _requireAllSnippets(
    bootstrap.readAsStringSync(),
    const [
      'class MobileFeatureFlags',
      'bool contains(String key)',
      '_featureFlagKey(key)',
      'enabled(String key, {bool fallback = false})',
    ],
    const ProductionPreflightIssue(
      code: 'flutter_feature_flag_route_policy_missing',
      message:
          'Flutter MobileFeatureFlags must distinguish missing runtime flags from explicit false BO feature/plugin settings.',
    ),
    issues,
  );

  _requireAllSnippets(
    policy.readAsStringSync(),
    const [
      'mobileCustomerRouteAllowed',
      'mobileCustomerDisabledRouteRedirect',
      '_customerFeaturePathFromQuery',
      '_customerFeaturePathFromFragment',
      '_customerFeatureRouteKeys',
      '_decodeCustomerFeatureRouteValue',
      '_featureKeysAllowed',
      'flags.contains(key)',
      'returnUrl',
      'targetUrl',
      'hashRoute',
      'wallet_topup',
      'tickets',
      'native_biometric_unlock',
      'news',
      'purchase_history',
      'reward_check',
      '/wait-result',
    ],
    const ProductionPreflightIssue(
      code: 'flutter_feature_flag_route_policy_missing',
      message:
          'Flutter runtime policy must preserve BO feature/plugin checks for customer routes and safe disabled-route redirects.',
    ),
    issues,
  );

  _requireAllSnippets(
    router.readAsStringSync(),
    const [
      'mobileCustomerDisabledRouteRedirect(',
      'MobileBootstrap? bootstrap',
      'bootstrap.valueOrNull',
    ],
    const ProductionPreflightIssue(
      code: 'flutter_feature_flag_router_binding_missing',
      message:
          'Flutter router must redirect direct entry to disabled BO feature routes through the shared runtime policy.',
    ),
    issues,
  );

  _requireAllSnippets(
    profile.readAsStringSync(),
    const [
      'mobileCustomerRouteAllowed(bootstrap, path)',
      'historyItems',
      'rewardSettingItems',
      'aboutItems',
      "routeEnabled('/profile/biometrics')",
      "routeEnabled('/reward-claims')",
    ],
    const ProductionPreflightIssue(
      code: 'flutter_feature_flag_profile_menu_binding_missing',
      message:
          'Flutter Profile menu must hide BO-disabled feature/plugin settings through the shared runtime policy.',
    ),
    issues,
  );

  _requireAllSnippets(
    shell.readAsStringSync(),
    const [
      'ConsumerWidget',
      'mobileBootstrapProvider',
      'mobileCustomerRouteAllowed(bootstrap, item.path)',
      'visibleItems',
      '_BottomNavLabel.tickets',
    ],
    const ProductionPreflightIssue(
      code: 'flutter_feature_flag_bottom_nav_binding_missing',
      message:
          'Flutter bottom navigation must hide BO-disabled feature/plugin routes through the shared runtime policy.',
    ),
    issues,
  );
}

void _checkFlutterScreenSecurityBinding(
  ProductionPreflightInput input,
  List<ProductionPreflightIssue> issues,
) {
  final service = File(
    _join(input.projectRoot, 'lib/core/security/screen_security_service.dart'),
  );
  if (!service.existsSync()) {
    issues.add(
      const ProductionPreflightIssue(
        code: 'flutter_screen_security_service_missing',
        message: 'Flutter ScreenSecurityService was not found.',
      ),
    );
  } else {
    final source = service.readAsStringSync();
    _requireAllSnippets(
      source,
      const [
        "MethodChannel('customer_flutter/screen_security')",
        'setMethodCallHandler',
        'securityEvent',
        'StreamController<ScreenSecurityEvent>.broadcast',
      ],
      const ProductionPreflightIssue(
        code: 'flutter_screen_security_event_binding_missing',
        message:
            'Flutter must listen to native screen security events from the screen security channel.',
      ),
      issues,
    );
    _requireAllSnippets(
      source,
      const [
        'screenSecurityAuditServiceProvider',
        'ScreenSecurityAuditService',
        '/customer/auth/security-events',
      ],
      const ProductionPreflightIssue(
        code: 'flutter_screen_security_audit_missing',
        message:
            'Flutter must audit native screen security events to /customer/auth/security-events.',
      ),
      issues,
    );
    _requireAllSnippets(
      source,
      const [
        '_screenSecurityPathFromFragment',
        '_screenSecurityFragmentQuery',
        '_screenSecurityQueryHasRouteKey',
        'Uri(query: queryOnly)',
        'Uri(query: query).queryParameters',
      ],
      const ProductionPreflightIssue(
        code: 'flutter_screen_security_fragment_route_normalization_missing',
        message:
            'Flutter screen security route normalization must resolve protected routes from hash-fragment query payloads before audit or session locking.',
      ),
      issues,
    );
    _requireAllSnippets(
      source,
      const [
        '_screenSecurityRouteKeys',
        '_firstNativeRouteString',
        'currentUrl',
        'routeUrl',
        'targetUrl',
        'routerPath',
        'fullPath',
        'returnUrl',
        'redirectUrl',
        'hash',
        'query',
        'href',
        'uri',
        'userInfo',
        'params',
        'routeInfo',
        'navigationInfo',
        'screenInfo',
        'captureStateInfo',
        'navigationUrl',
        'currentViewUrl',
        'rawValue',
        'screenUrl',
        '_decodeScreenSecurityRouteValue',
        'screen_capture_changed',
        'captureActive',
        'screenCaptureStatus',
        'uiscreen_captured_did_change_notification',
        'uiapplication_user_did_take_screenshot_notification',
        'media_projection_stopped',
      ],
      const ProductionPreflightIssue(
        code: 'flutter_screen_security_route_object_normalization_missing',
        message:
            'Flutter screen security route normalization must resolve encoded/hashbang route values, route objects, and currentUrl/targetUrl/href native bridge aliases before audit or session locking.',
      ),
      issues,
    );
  }

  final bootstrap = File(
    _join(
      input.projectRoot,
      'lib/core/tenant/mobile_bootstrap_controller.dart',
    ),
  );
  final app = File(_join(input.projectRoot, 'lib/app/customer_app.dart'));
  if (!bootstrap.existsSync() || !app.existsSync()) {
    issues.add(
      const ProductionPreflightIssue(
        code: 'flutter_screen_security_runtime_overlay_copy_missing',
        message:
            'Flutter screen-security runtime overlay copy parser or app binding was not found.',
      ),
    );
  } else {
    _requireAllSnippets(
      bootstrap.readAsStringSync(),
      const [
        'privacyOverlayTitle',
        'privacy_overlay_title',
        'overlay_title',
        'screen_capture_title',
        'privacyOverlayDescription',
        'privacy_overlay_description',
        'overlay_description',
        'screen_capture_description',
      ],
      const ProductionPreflightIssue(
        code: 'flutter_screen_security_runtime_overlay_copy_missing',
        message:
            'Flutter screen-security bootstrap must parse runtime privacy overlay title and description aliases.',
      ),
      issues,
    );
    _requireAllSnippets(
      bootstrap.readAsStringSync(),
      const [
        '_normalizeScreenSecurityPolicyRoute',
        '_screenSecurityPolicyPathFromQuery',
        '_screenSecurityPolicyPathFromFragment',
        '_screenSecurityRouteValueKeys',
        'currentUrl',
        'targetUrl',
        'routeUrl',
        'returnUrl',
        'redirectUrl',
        'screenUrl',
        'deepLink',
        'hashRoute',
      ],
      const ProductionPreflightIssue(
        code: 'flutter_screen_security_policy_route_normalization_missing',
        message:
            'Flutter screen-security bootstrap must normalize BO sensitive-route policy values from full URLs, hash routes, query wrappers, and native route aliases before enabling native/web guards.',
      ),
      issues,
    );
    _requireAllSnippets(
      app.readAsStringSync(),
      const [
        'privacyOverlayTitle: screenSecurity?.privacyOverlayTitle',
        'privacyOverlayDescription:',
        'screenSecurity?.privacyOverlayDescription',
      ],
      const ProductionPreflightIssue(
        code: 'flutter_screen_security_runtime_overlay_copy_missing',
        message:
            'CustomerApp must pass runtime privacy overlay copy from mobile bootstrap into SensitiveScreenGuard.',
      ),
      issues,
    );
  }

  final guard = File(
    _join(input.projectRoot, 'lib/shared/widgets/sensitive_screen_guard.dart'),
  );
  if (!guard.existsSync()) {
    issues.add(
      const ProductionPreflightIssue(
        code: 'flutter_sensitive_screen_guard_missing',
        message: 'Flutter SensitiveScreenGuard was not found.',
      ),
    );
    return;
  }

  final source = guard.readAsStringSync();
  _requireAllSnippets(
    source,
    const ['.events.listen', 'screen_capture_ended', 'lockForScreenSecurity'],
    const ProductionPreflightIssue(
      code: 'flutter_screen_security_lock_binding_missing',
      message:
          'SensitiveScreenGuard must lock the app when native screenshot or recording events are received.',
    ),
    issues,
  );
  _requireAllSnippets(
    source,
    const [
      'screenSecurityAuditServiceProvider',
      '.record(',
      'screenSecurityRoutesMatch(event.route, widget.route)',
      'normalizeScreenSecurityRoute(',
    ],
    const ProductionPreflightIssue(
      code: 'flutter_screen_security_audit_binding_missing',
      message:
          'SensitiveScreenGuard must normalize and hand matched native screen security events to the audit service.',
    ),
    issues,
  );
  _requireAllSnippets(
    source,
    const [
      'final String? privacyOverlayTitle',
      'final String? privacyOverlayDescription',
      'overlayTitle: _runtimeCopy',
      'overlayDescription: _runtimeCopy',
      '_runtimeCopy(',
    ],
    const ProductionPreflightIssue(
      code: 'flutter_screen_security_runtime_overlay_copy_missing',
      message:
          'SensitiveScreenGuard must pass runtime privacy overlay copy to the native screen-security bridge with localized fallback.',
    ),
    issues,
  );
}

void _checkFlutterWebPrivacyBinding(
  ProductionPreflightInput input,
  List<ProductionPreflightIssue> issues,
) {
  final requiredFiles = <String, List<String>>{
    'lib/app/customer_app.dart': const [
      'const webPrivacyEnabled = false;',
      'WebPrivacyGuard(',
      'enabled: webPrivacyEnabled && routeSensitive',
      'watermarkEnabled: false',
    ],
    'lib/shared/widgets/web_privacy_guard.dart': const [
      'WebPrivacyBrowserActivity',
      '..start()',
      'didChangeAppLifecycleState',
      'AppLifecycleState.hidden',
      '_browserShouldCover',
      '_lifecycleShouldCover',
      'webPrivacyModeShouldShowCover',
      'final String? privacyOverlayTitle',
      'final String? privacyOverlayDescription',
      'final title = _runtimeCopy',
      'final description = _runtimeCopy',
      'title: title',
      'description: description',
    ],
    'lib/shared/widgets/web_privacy_browser_activity.dart': const [
      "if (dart.library.html) 'web_privacy_browser_activity_web.dart'",
      "export 'web_privacy_browser_activity_stub.dart'",
    ],
    'lib/shared/widgets/web_privacy_browser_activity_web.dart': const [
      'web.document.onVisibilityChange',
      'web.EventStreamProviders.blurEvent',
      'web.EventStreamProviders.focusEvent',
      'web.EventStreamProviders.pageHideEvent',
      'web.EventStreamProviders.pageShowEvent',
      "web.EventStreamProvider<web.Event>('freeze')",
      "web.EventStreamProvider<web.Event>('resume')",
      "web.EventStreamProvider<web.Event>('beforeprint')",
      "web.EventStreamProvider<web.Event>('afterprint')",
      '_printActive',
      '_documentHasFocus',
      'web.document.hasFocus()',
      'webPrivacyBrowserShouldCover',
    ],
    'lib/shared/widgets/web_privacy_browser_activity_state.dart': const [
      'documentVisibilityState',
      'pageHidden',
      'pageFrozen',
      'printActive',
      '!windowFocused',
    ],
    'lib/shared/widgets/web_privacy_browser_activity_stub.dart': const [
      'WebPrivacyBrowserActivity',
      '_onChanged(false)',
    ],
    'lib/core/security/web_privacy_mode.dart': const [
      'normalizeWebPrivacyMode',
      "'true'",
      "'on'",
      "'enabled'",
      "'active'",
      "'screen_protection'",
      'webPrivacyModeAllowsGuard',
      'webPrivacyModeShowsWatermark',
      'webPrivacyModeShowsLifecycleCover',
      'webPrivacyModeShouldShowCover',
    ],
  };

  final missing = <String>[];
  for (final entry in requiredFiles.entries) {
    final file = File(_join(input.projectRoot, entry.key));
    if (!file.existsSync()) {
      missing.add(entry.key);
      continue;
    }

    final source = file.readAsStringSync();
    for (final snippet in entry.value) {
      if (!source.contains(snippet)) {
        missing.add('${entry.key} missing $snippet');
      }
    }
  }

  if (missing.isEmpty) return;

  issues.add(
    ProductionPreflightIssue(
      code: 'flutter_web_privacy_binding_missing',
      message:
          'Web production builds must preserve the owner-approved focus/privacy opt-out while keeping dormant runtime privacy plumbing available for a future explicit re-enable. Missing: ${missing.join(', ')}',
    ),
  );
}

void _checkFlutterBiometricBinding(
  ProductionPreflightInput input,
  List<ProductionPreflightIssue> issues,
) {
  final service = File(
    _join(input.projectRoot, 'lib/core/security/biometric_auth_service.dart'),
  );
  if (!service.existsSync()) {
    issues.add(
      const ProductionPreflightIssue(
        code: 'flutter_biometric_service_missing',
        message: 'Flutter BiometricAuthService was not found.',
      ),
    );
    return;
  }

  final source = service.readAsStringSync();
  _requireAllSnippets(
    source,
    const [
      "'customer_flutter/biometric_keys'",
      "'existingDeviceId'",
      "'deleteKeyPair'",
      "'signChallenge'",
      'BiometricChallengePayload.fromResponse',
      'biometricPinAssertionTokenFromResponse',
    ],
    const ProductionPreflightIssue(
      code: 'flutter_biometric_channel_binding_missing',
      message:
          'Flutter biometric auth must use the native biometric key channel for read-only device lookup, signing, and local key deletion.',
    ),
    issues,
  );
  _requireAllSnippets(
    source,
    const [
      'TargetPlatform.iOS',
      '_targetPlatform != TargetPlatform.iOS',
      "'localizedReason': localizedReason",
    ],
    const ProductionPreflightIssue(
      code: 'flutter_biometric_key_bound_prompt_missing',
      message:
          'Flutter biometric unlock must let the iOS protected key authenticate once and pass runtime prompt copy into the native signing operation.',
    ),
    issues,
  );
  final app = File(_join(input.projectRoot, 'lib/app/customer_app.dart'));
  final appSource = app.existsSync() ? app.readAsStringSync() : '';
  if (!source.contains('BiometricPromptCoordinator') ||
      !source.contains('_promptCoordinator.track(') ||
      !appSource.contains('biometricPromptCoordinatorProvider') ||
      !appSource.contains('.isActive')) {
    issues.add(
      const ProductionPreflightIssue(
        code: 'flutter_biometric_lifecycle_coordination_missing',
        message:
            'Flutter must suppress sensitive-route lifecycle locking only while a native biometric prompt is active.',
      ),
    );
  }
  _requireAllSnippets(
    source,
    const [
      'isDeviceSupported',
      'getAvailableBiometrics',
      'BiometricType.weak',
      '_safePostMap',
      '_safeSignChallenge',
    ],
    const ProductionPreflightIssue(
      code: 'flutter_biometric_soft_fallback_missing',
      message:
          'Flutter biometric auth must reject weak-only enrollment and fall back to PIN when challenge, verify, or native signing fails.',
    ),
    issues,
  );
  _requireAllSnippets(
    source,
    const [
      'clearLocalDeviceKey',
      "'deleteKeyPair'",
      'deviceId: deviceId',
      'rethrow',
    ],
    const ProductionPreflightIssue(
      code: 'flutter_biometric_local_key_cleanup_missing',
      message:
          'Flutter biometric registration/revoke must clean up only the matching local native key when backend registration or current-device revoke succeeds.',
    ),
    issues,
  );
  _requireAllSnippets(
    source,
    const [
      'biometricChallengeId',
      'authChallengeId',
      'requestId',
      'requestToken',
      'challengeData',
      'challengeBase64Url',
      'payloadToSign',
      'signingData',
      'serverChallenge',
      'publicKey',
      'allowCredentials',
      'excludeCredentials',
      'credentialDescriptors',
      'rpId',
      'relyingParty',
      'userVerification',
      'authenticatorSelection',
      'attestationFormats',
      'mediation',
      'hints',
      'pubKeyCredParams',
      'metadata: challengePayload.metadata',
      '_biometricChallengeMetadataFromPayload',
      '_biometricAllowCredentialsFromPayload',
      '_biometricExcludeCredentialsFromPayload',
      '_biometricCredentialDescriptorRows',
      '_biometricCredentialDescriptor',
      '_biometricChannelValue',
      'credentialPublicKey',
      'publicKeyDer',
      'publicKeyJwk',
      'rawId',
      '_biometricAlgorithmFromPayload',
      'SHA256WITHECDSA',
      '-7',
      '-257',
      'signatureBase64',
      'base64Signature',
      'nativeSignature',
      'signatureJws',
      'signatureDer',
      'credentialResponse',
      'authenticatorResponse',
      '_biometricSignatureMetadataFromPayload',
      'credential_id',
      'client_data_json',
      'authenticator_data',
      'user_handle',
      'jws',
      'proof',
      'pinAssertionToken',
      'pinAssertionJwt',
      'assertionJwt',
      'verificationToken',
    ],
    const ProductionPreflightIssue(
      code: 'flutter_biometric_alias_parsing_missing',
      message:
          'Flutter biometric auth must preserve production challenge, signature, and assertion-token alias parsing.',
    ),
    issues,
  );

  final deviceModel = File(
    _join(
      input.projectRoot,
      'lib/features/profile/data/biometric_device_models.dart',
    ),
  );
  final deviceRepository = File(
    _join(
      input.projectRoot,
      'lib/features/profile/data/biometric_device_repository.dart',
    ),
  );
  if (!deviceModel.existsSync() || !deviceRepository.existsSync()) {
    issues.add(
      const ProductionPreflightIssue(
        code: 'flutter_biometric_device_parser_alias_missing',
        message:
            'Flutter biometric device list parser/repository was not found.',
      ),
    );
  } else {
    _requireAllSnippets(
      deviceModel.readAsStringSync(),
      const [
        '_mergeBiometricDeviceFallbackWrappers',
        '_biometricDeviceFallbackWrapperKeys',
        'metadata',
        'attributes',
        'platformInfo',
        'registrationInfo',
        'lifecycle',
        'statusInfo',
      ],
      const ProductionPreflightIssue(
        code: 'flutter_biometric_device_parser_alias_missing',
        message:
            'Flutter biometric device model must preserve production metadata/attributes/platform/lifecycle wrapper parsing.',
      ),
      issues,
    );
    _requireAllSnippets(
      deviceRepository.readAsStringSync(),
      const [
        '_looksLikeBiometricDeviceRow',
        'metadata',
        'attributes',
        'platformInfo',
        'registrationInfo',
        'lifecycle',
        'statusInfo',
      ],
      const ProductionPreflightIssue(
        code: 'flutter_biometric_device_parser_alias_missing',
        message:
            'Flutter biometric device repository must detect production metadata/attributes/platform/lifecycle keyed records.',
      ),
      issues,
    );
  }

  final bootstrap = File(
    _join(
      input.projectRoot,
      'lib/core/tenant/mobile_bootstrap_controller.dart',
    ),
  );
  final runtimePolicy = File(
    _join(input.projectRoot, 'lib/core/tenant/mobile_runtime_policy.dart'),
  );
  if (!bootstrap.existsSync() || !runtimePolicy.existsSync()) {
    issues.add(
      const ProductionPreflightIssue(
        code: 'flutter_biometric_runtime_prompt_copy_missing',
        message:
            'Flutter biometric runtime prompt-copy parser or policy helper was not found.',
      ),
    );
  } else {
    _requireAllSnippets(
      bootstrap.readAsStringSync(),
      const [
        'promptReasonForPurpose',
        '_mergeBiometricPromptReasonMaps',
        'prompt_reasons',
        'purposeReasons',
        'localizedReason',
        'authenticationPromptCopy',
        'biometricSetupReason',
        'deviceRegistrationReason',
        'rewardBankUpdateReason',
        'rewardClaimReason',
        'ticketClaimReason',
        'activityClaimReason',
      ],
      const ProductionPreflightIssue(
        code: 'flutter_biometric_runtime_prompt_copy_missing',
        message:
            'Flutter mobile bootstrap must parse runtime biometric prompt-copy aliases by purpose with localized fallback.',
      ),
      issues,
    );
    _requireAllSnippets(
      runtimePolicy.readAsStringSync(),
      const [
        'mobileBiometricPromptReason',
        'promptReasonForPurpose',
        'setup = false',
      ],
      const ProductionPreflightIssue(
        code: 'flutter_biometric_runtime_prompt_copy_missing',
        message:
            'Flutter runtime policy must expose a shared biometric prompt-copy resolver.',
      ),
      issues,
    );
  }

  final promptBindings = <String, List<String>>{
    'lib/features/pin/presentation/pin_screen.dart': const [
      'mobileBiometricPromptReason(',
      "purpose: 'pin_unlock'",
    ],
    'lib/features/profile/presentation/reward_bank_screen.dart': const [
      'mobileBiometricPromptReason(',
      "purpose: 'profile_update'",
    ],
    'lib/features/profile/presentation/biometric_devices_screen.dart': const [
      'mobileBiometricPromptReason(',
      "purpose: 'biometric_setup'",
      'setup: true',
    ],
    'lib/features/tickets/presentation/tickets_screen.dart': const [
      'mobileBiometricPromptReason(',
      "purpose: 'reward_claim'",
    ],
    'lib/features/activities/presentation/activity_detail_screen.dart': const [
      'mobileBiometricPromptReason(',
      "purpose: 'activity_claim'",
    ],
  };
  final missingPromptBindings = <String>[];
  for (final entry in promptBindings.entries) {
    final file = File(_join(input.projectRoot, entry.key));
    if (!file.existsSync()) {
      missingPromptBindings.add(entry.key);
      continue;
    }
    final source = file.readAsStringSync();
    for (final snippet in entry.value) {
      if (!source.contains(snippet)) {
        missingPromptBindings.add('${entry.key} missing $snippet');
      }
    }
  }
  if (missingPromptBindings.isNotEmpty) {
    issues.add(
      ProductionPreflightIssue(
        code: 'flutter_biometric_runtime_prompt_copy_missing',
        message:
            'Flutter biometric prompt-copy runtime bindings are missing: ${missingPromptBindings.join(', ')}',
      ),
    );
  }
}

void _checkFlutterAffiliateCentralPinBinding(
  ProductionPreflightInput input,
  List<ProductionPreflightIssue> issues,
) {
  final router = File(_join(input.projectRoot, 'lib/app/router.dart'));
  final redirect = File(
    _join(input.projectRoot, 'lib/core/navigation/customer_redirect.dart'),
  );
  final affiliate = File(
    _join(
      input.projectRoot,
      'lib/features/affiliate/presentation/affiliate_screen.dart',
    ),
  );
  const affiliatePinIssue = ProductionPreflightIssue(
    code: 'flutter_affiliate_central_pin_binding_missing',
    message:
        'Affiliate must use the shared router-level PIN handoff and must not restore a page-local biometric/PIN prompt.',
  );
  if (!router.existsSync() ||
      !redirect.existsSync() ||
      !affiliate.existsSync()) {
    issues.add(affiliatePinIssue);
  } else {
    final routerSource = router.readAsStringSync();
    final redirectSource = redirect.readAsStringSync();
    final affiliateSource = affiliate.readAsStringSync();
    final missingCentralPin =
        !routerSource.contains("path: '/affiliate'") ||
        !routerSource.contains('customerRedirectPath(') ||
        !redirectSource.contains('customerPinRouteForRedirect') ||
        affiliateSource.contains('mobileBiometricPromptReason(') ||
        affiliateSource.contains("purpose: 'pin_unlock'");
    if (missingCentralPin) issues.add(affiliatePinIssue);
  }
}

void _checkFlutterRealtimeBinding(
  ProductionPreflightInput input,
  List<ProductionPreflightIssue> issues,
) {
  final protocol = File(
    _join(
      input.projectRoot,
      'lib/core/realtime/customer_realtime_protocol.dart',
    ),
  );
  if (!protocol.existsSync()) {
    issues.add(
      const ProductionPreflightIssue(
        code: 'flutter_realtime_protocol_missing',
        message: 'Flutter customer realtime protocol was not found.',
      ),
    );
  } else {
    final source = protocol.readAsStringSync();
    _requireAllSnippets(
      source,
      const [
        'normalizeRealtimeEventNameWithPayload',
        'normalizeRealtimePayload',
        '_directRealtimeEventNameKeys',
        '_providerRealtimeEventNameKeys',
        '_realtimePayloadWrapperKeys',
        '_realtimeMessageEventKeys',
        '_realtimeMessageChannelKeys',
        '_realtimeMessageDataKeys',
        '_mergeRealtimeMessageData',
        '_realtimeEventScalarText',
        '_realtimeScalarWrapperKeys',
        '_isCanonicalRealtimeEvent',
        'normalizeRealtimePayload(parseRealtimeData(data))',
        'eventClass',
        'event_class_name',
        'event_fqcn',
        'channelName',
        'subscriptionChannel',
        'broadcastAs',
        'domainEventName',
        'messageName',
        'notificationName',
        'notificationType',
        'payload_json',
        'event_data',
        'resource_data',
        'payloadData',
        'envelope',
        'notificationData',
        'messagePayload',
        'metadata',
        'context',
        'details',
        'object',
        'attributes',
        'eventEnvelope',
        'dataEnvelope',
        'recordEnvelope',
        'messageEnvelope',
        'outboxMessage',
        'payloadEnvelope',
        'channelInfo',
        'subscriptionInfo',
        "'label'",
        "'text'",
        "'rawValue'",
        'walletledgercreated',
        'wallettransactioncreated',
        'walletledgerentryupdated',
        'rewardclaimapproved',
        'activityclaimrejected',
        "'value'",
        "'code'",
        "'key'",
      ],
      const ProductionPreflightIssue(
        code: 'flutter_realtime_protocol_alias_binding_missing',
        message:
            'Flutter realtime protocol must preserve backend outbox event-class aliases, object-scalar event rows, and bridge/provider payload wrapper normalization before production release.',
      ),
      issues,
    );
    _requireAllSnippets(
      source,
      const [
        '_realtimeSocketUrlWithAppPath',
        'encodedKey',
        'queryIndex',
        "replaceFirst(RegExp('^http:'",
        "replaceFirst(RegExp('^https:'",
        r"r'/app(?:/([^/?#]+))?$'",
        '/app/\$encodedKey',
      ],
      const ProductionPreflightIssue(
        code: 'flutter_realtime_socket_url_normalization_missing',
        message:
            'Flutter realtime protocol must preserve runtime socket URL normalization for /app endpoints, proxy paths, existing app keys, and query strings.',
      ),
      issues,
    );
  }

  final requiredMonitors = <String, List<String>>{
    'lib/features/lottery/presentation/lottery_stock_realtime_monitor.dart':
        const [
          'normalizeRealtimeEventNameWithPayload',
          'normalizeRealtimePayload',
          '_realtimeScalarText',
          'salePrice',
          'unitPrice',
        ],
    'lib/features/results/presentation/result_realtime_monitor.dart': const [
      'normalizeRealtimeEventNameWithPayload',
      'normalizeRealtimePayload',
      '_resultRealtimeScalarText',
      'rewardGame',
      'currentGame',
      'selectedGameId',
    ],
    'lib/features/lottery/presentation/customer_revenue_realtime_monitor.dart':
        const [
          'normalizeRealtimeEventNameWithPayload',
          'normalizeRealtimePayload',
          'ticketIdsFromRealtimePayload',
          '_revenueRealtimeScalarText',
          'orderItems',
          'lotteryTicket',
        ],
    'lib/features/topup/presentation/topup_realtime_monitor.dart': const [
      'normalizeRealtimeEventNameWithPayload',
      'customerWalletChannel',
    ],
    'lib/features/reward_claims/presentation/claim_realtime_monitor.dart':
        const [
          'normalizeRealtimeEventNameWithPayload',
          'normalizeRealtimePayload',
          'claimIdFromRealtimePayload',
          'ticketIdFromRewardClaimRealtimePayload',
          '_claimRealtimeScalarText',
          'orderItems',
          'lotteryTicket',
          'activityAward',
        ],
  };

  final missing = <String>[];
  for (final entry in requiredMonitors.entries) {
    final file = File(_join(input.projectRoot, entry.key));
    if (!file.existsSync()) {
      missing.add(entry.key);
      continue;
    }

    final source = file.readAsStringSync();
    for (final snippet in entry.value) {
      if (!source.contains(snippet)) {
        missing.add('${entry.key} missing $snippet');
      }
    }
  }

  if (missing.isEmpty) return;

  issues.add(
    ProductionPreflightIssue(
      code: 'flutter_realtime_monitor_binding_missing',
      message:
          'Customer realtime monitors must keep using the shared payload-aware protocol for stock, result, revenue, money, and claim refreshes. Missing: ${missing.join(', ')}',
    ),
  );
}

void _checkNativeTenantHost(
  ProductionPreflightInput input,
  List<ProductionPreflightIssue> issues,
) {
  if (!input.production ||
      (!input.target.includesAndroid && !input.target.includesIos)) {
    return;
  }

  final callbackHosts = <String>{
    if (input.androidCallbackHost != null)
      _hostOnly(input.androidCallbackHost!).toLowerCase(),
    if (input.iosAssociatedDomain != null)
      _hostOnly(
        input.iosAssociatedDomain!.replaceFirst(
          RegExp(r'^applinks:', caseSensitive: false),
          '',
        ),
      ).toLowerCase(),
  }..removeWhere((host) => host.isEmpty);

  final tenantHost = _hostOnly(input.tenantHost ?? '').toLowerCase();
  if (tenantHost.isNotEmpty &&
      _looksLikeProductionHost(tenantHost, input.production) &&
      callbackHosts.isNotEmpty &&
      !callbackHosts.contains(tenantHost)) {
    issues.add(
      ProductionPreflightIssue(
        code: 'tenant_host_callback_host_mismatch',
        message:
            'TENANT_HOST must match the native callback/App Link host so Flutter does not reject production HTTPS callbacks. Expected one of ${callbackHosts.join(', ')}, got $tenantHost.',
      ),
    );
  }

  final apiUri = Uri.tryParse(input.apiBaseUrl?.trim() ?? '');
  final apiHost = apiUri?.host.trim().toLowerCase() ?? '';

  if (apiHost.isEmpty) return;

  if (callbackHosts.isEmpty || callbackHosts.contains(apiHost)) return;

  if (!_looksLikeProductionHost(tenantHost, input.production)) {
    issues.add(
      ProductionPreflightIssue(
        code: 'tenant_host_missing_for_central_api',
        message:
            'Native production builds that use a central API host must set TENANT_HOST to the public partner storefront host.',
      ),
    );
  }
}

void _checkSocialProviderValues(
  ProductionPreflightInput input,
  List<ProductionPreflightIssue> issues,
) {
  if (!input.production) return;

  final invalidProviders =
      input.socialAuthProviders
          .map((provider) => provider.trim())
          .where((provider) => provider.isNotEmpty)
          .where(
            (provider) => !_supportedSocialProviders.contains(
              _normalizeSocialProvider(provider),
            ),
          )
          .map((provider) => provider.toLowerCase())
          .toSet()
          .toList()
        ..sort();
  if (invalidProviders.isEmpty) return;

  issues.add(
    ProductionPreflightIssue(
      code: 'social_provider_invalid',
      message:
          'Unsupported social provider(s): ${invalidProviders.join(', ')}. Supported providers are line, google, apple, and facebook.',
    ),
  );
}

void _checkSocialLoginStoreCompliance(
  ProductionPreflightInput input,
  List<ProductionPreflightIssue> issues,
) {
  if (!input.production || !input.target.includesIos) return;

  final providers = _normalizedSocialProviders(input.socialAuthProviders);
  if (providers.isEmpty) return;

  final usesThirdPartyLogin =
      providers.contains('line') ||
      providers.contains('google') ||
      providers.contains('facebook');
  if (usesThirdPartyLogin && !providers.contains('apple')) {
    issues.add(
      const ProductionPreflightIssue(
        code: 'ios_sign_in_with_apple_required',
        message:
            'iOS production builds that enable LINE, Google, or Facebook login must also enable Apple ID login.',
      ),
    );
  }
}

void _checkFlutterSocialCallbackBinding(
  ProductionPreflightInput input,
  List<ProductionPreflightIssue> issues,
) {
  final authRepository = File(
    _join(input.projectRoot, 'lib/core/auth/auth_repository.dart'),
  );
  final callbackScreen = File(
    _join(
      input.projectRoot,
      'lib/features/auth/presentation/line_auth_screens.dart',
    ),
  );
  const issue = ProductionPreflightIssue(
    code: 'flutter_social_callback_wrapper_binding_missing',
    message:
        'Flutter social callback must normalize wrapper/code/state aliases in both the route screen and auth repository before submitting production OAuth callbacks.',
  );
  if (!authRepository.existsSync() || !callbackScreen.existsSync()) {
    issues.add(issue);
    return;
  }

  final authSource = authRepository.readAsStringSync();
  final callbackSource = callbackScreen.readAsStringSync();
  final authMissing = const [
    'data: normalizedQuery',
    '_socialLoginPayloadWrapperKeys',
    '_socialCallbackPayloadWrapperKeys',
    '_normalizedSocialCallbackData',
    '_authPayload',
    '_asAuthMap',
    'convert.jsonDecode',
    'readSocialCallbackContext',
    'callbackContext?.auth',
    'takeSocialCallbackContext',
    'withRedirectFallback',
    'authorizationCode',
    'callbackState',
    'providerCode',
    'providerState',
    'metadata',
    'context',
    'providerData',
  ].any((snippet) => !authSource.contains(snippet));
  final callbackMissing = const [
    '_socialCallbackWrapperKeys',
    '_normalizedSocialCallbackQuery',
    '_wrappedSocialCallbackQuery',
    '_jsonStringMap',
    'convert.jsonEncode',
    'convert.jsonDecode',
    'authorizationCode',
    'callbackState',
    'providerCode',
    'providerState',
    'metadata',
    'context',
    'providerData',
    'payload',
  ].any((snippet) => !callbackSource.contains(snippet));
  if (authMissing || callbackMissing) issues.add(issue);
}

void _checkFlutterSocialCallbackRouteBinding(
  ProductionPreflightInput input,
  List<ProductionPreflightIssue> issues,
) {
  final deepLink = File(
    _join(input.projectRoot, 'lib/core/navigation/customer_deep_link.dart'),
  );
  final router = File(_join(input.projectRoot, 'lib/app/router.dart'));
  const issue = ProductionPreflightIssue(
    code: 'flutter_social_callback_fragment_route_binding_missing',
    message:
        'Flutter social callback, link-phone, and reset routes must preserve OAuth parameters from URL fragments and hash routes before submitting production auth requests.',
  );
  if (!deepLink.existsSync() || !router.existsSync()) {
    issues.add(issue);
    return;
  }

  final deepLinkSource = deepLink.readAsStringSync();
  final routerSource = router.readAsStringSync();
  final deepLinkMissing = const [
    'customerAuthRouteParameters',
    '_routeQueryOrNull',
    '_acceptsFragmentParameters',
    '_fragmentQueryParameters',
    '_fragmentRoutePath',
    'parameters.putIfAbsent',
  ].any((snippet) => !deepLinkSource.contains(snippet));
  final routeParserBindings = RegExp(
    r'customerAuthRouteParameters\s*\(\s*state\.uri\s*\)',
  ).allMatches(routerSource).length;
  final routerMissing =
      !routerSource.contains(
        "import '../core/navigation/customer_deep_link.dart';",
      ) ||
      routeParserBindings < 5;

  if (deepLinkMissing || routerMissing) issues.add(issue);
}

void _checkFlutterAuthOtpParserBinding(
  ProductionPreflightInput input,
  List<ProductionPreflightIssue> issues,
) {
  final authRepository = File(
    _join(input.projectRoot, 'lib/core/auth/auth_repository.dart'),
  );
  if (!authRepository.existsSync()) {
    issues.add(
      const ProductionPreflightIssue(
        code: 'flutter_auth_otp_parser_binding_missing',
        message: 'Flutter auth repository OTP parser was not found.',
      ),
    );
    return;
  }

  _requireAllSnippets(
    authRepository.readAsStringSync(),
    const [
      'OtpRequestResult',
      'OtpVerifyResult',
      'otpRequestResult',
      'otpVerifyResult',
      'pinReset',
      'passwordReset',
      'mobileNumberMasked',
      'retryAfterSeconds',
      'verificationId',
      'recipient',
      'delivery',
      'maskedPhone',
      '_firstScalarString',
      '_authScalarString',
    ],
    const ProductionPreflightIssue(
      code: 'flutter_auth_otp_parser_binding_missing',
      message:
          'Flutter auth OTP parser must keep production reset/register envelopes plus phone-mask, resend-cooldown, and verification-token aliases for register, forgot password, and PIN reset.',
    ),
    issues,
  );
}

void _checkFlutterSocialProviderRuntimeColorBinding(
  ProductionPreflightInput input,
  List<ProductionPreflightIssue> issues,
) {
  final bootstrap = File(
    _join(
      input.projectRoot,
      'lib/core/tenant/mobile_bootstrap_controller.dart',
    ),
  );
  final login = File(
    _join(
      input.projectRoot,
      'lib/features/auth/presentation/login_screen.dart',
    ),
  );
  final forgotPassword = File(
    _join(
      input.projectRoot,
      'lib/features/auth/presentation/forgot_password_screen.dart',
    ),
  );
  final socialScreens = File(
    _join(
      input.projectRoot,
      'lib/features/auth/presentation/line_auth_screens.dart',
    ),
  );
  final lineNotifications = File(
    _join(
      input.projectRoot,
      'lib/features/profile/presentation/line_notifications_screen.dart',
    ),
  );
  const issue = ProductionPreflightIssue(
    code: 'flutter_social_provider_runtime_color_binding_missing',
    message:
        'Flutter social-provider UI must keep brand/button colors runtime-configured through mobile bootstrap provider aliases instead of hardcoded LINE/Google/Apple/Facebook colors.',
  );
  final files = [
    bootstrap,
    login,
    forgotPassword,
    socialScreens,
    lineNotifications,
  ];
  if (files.any((file) => !file.existsSync())) {
    issues.add(issue);
    return;
  }

  final bootstrapSource = bootstrap.readAsStringSync();
  final loginSource = login.readAsStringSync();
  final forgotSource = forgotPassword.readAsStringSync();
  final socialSource = socialScreens.readAsStringSync();
  final lineNotificationsSource = lineNotifications.readAsStringSync();

  final bootstrapMissing = const [
    'final Color? brandColor',
    'final Color? buttonBackgroundColor',
    'final Color? buttonForegroundColor',
    "json['brandColor']",
    "json['buttonBackgroundColor']",
    "json['buttonForegroundColor']",
    '_runtimeColorFrom',
  ].any((snippet) => !bootstrapSource.contains(snippet));
  final loginMissing = const [
    'provider.brandColor',
    'provider.buttonBackgroundColor',
    'provider.buttonForegroundColor',
  ].any((snippet) => !loginSource.contains(snippet));
  final forgotMissing = const [
    'provider.brandColor',
    'provider.buttonBackgroundColor',
    'provider.buttonForegroundColor',
  ].any((snippet) => !forgotSource.contains(snippet));
  final socialMissing = const [
    '_runtimeSocialProvider',
    'mobileBootstrapProvider',
    'runtimeProvider?.brandColor',
  ].any((snippet) => !socialSource.contains(snippet));
  final hardcodedProviderColor =
      const [
        '0xFF06C755',
        '0xff06c755',
        '0xFF00B900',
        '0xff00b900',
        '0xFF00C300',
        '0xff00c300',
        '0xFF4285F4',
        '0xff4285f4',
      ].any(
        (snippet) =>
            loginSource.contains(snippet) ||
            forgotSource.contains(snippet) ||
            socialSource.contains(snippet) ||
            lineNotificationsSource.contains(snippet),
      );
  if (bootstrapMissing ||
      loginMissing ||
      forgotMissing ||
      socialMissing ||
      hardcodedProviderColor) {
    issues.add(issue);
  }
}

void _checkStoreAccountReadiness(
  ProductionPreflightInput input,
  List<ProductionPreflightIssue> issues,
) {
  final requiredFiles = <String, List<String>>{
    'lib/core/tenant/mobile_bootstrap_controller.dart': const [
      "json['storeReadiness']",
      "site['storeReadiness']",
      "site['storeListing']",
      "mobile['storeReadiness']",
      "json['compliance']",
      "site['compliance']",
      'privacyContent:',
      'privacyPolicyUrl:',
      'accountDeletionUrl:',
      'supportUrl:',
      "legal['privacy_content']",
      "legalPrivacy['policyUrl']",
      "legalAccountDeletion['requestUrl']",
      "legal['links']",
      "storeReadiness['developerContact']",
      'app_store_privacy_policy',
      'store_account_deletion_url',
      'store_listing_support',
      '_runtimeLinkForAliases(',
      '_runtimeContactValueFrom(',
    ],
    'lib/app/customer_routes.dart': const [
      "path: '/privacy'",
      "path: '/profile/account-deletion'",
    ],
    'lib/app/router.dart': const [
      "path: '/privacy'",
      'PrivacyPolicyScreen',
      "path: '/profile/account-deletion'",
      'AccountDeletionScreen',
    ],
    'lib/features/profile/presentation/profile_screen.dart': const [
      "path: '/privacy'",
      "path: '/profile/account-deletion'",
    ],
    'lib/features/content/presentation/info_pages.dart': const [
      'class PrivacyPolicyScreen',
      'mobileBootstrapProvider',
      'privacyContent',
      'privacyPolicyUrl',
      'isSafeExternalLinkUri',
      'customerLinkLauncherProvider',
    ],
    'lib/features/profile/presentation/account_deletion_screen.dart': const [
      'class AccountDeletionScreen',
      'mobileBootstrapProvider',
      'accountDeletionUrl',
      'supportUrl',
      'isSafeExternalLinkUri',
      'customerLinkLauncherProvider',
      'sensitive: true',
    ],
  };

  final missing = <String>[];
  for (final entry in requiredFiles.entries) {
    final file = File(_join(input.projectRoot, entry.key));
    if (!file.existsSync()) {
      missing.add(entry.key);
      continue;
    }

    final source = file.readAsStringSync();
    for (final snippet in entry.value) {
      if (!source.contains(snippet)) {
        missing.add('${entry.key} missing $snippet');
      }
    }
  }

  if (missing.isEmpty) return;

  issues.add(
    ProductionPreflightIssue(
      code: 'store_account_readiness_missing',
      message:
          'Production builds must expose runtime-driven Privacy Policy and Account Deletion entry points. Missing: ${missing.join(', ')}',
    ),
  );
}

void _checkDeepLinkAssociationFiles(
  ProductionPreflightInput input,
  List<ProductionPreflightIssue> issues,
) {
  final configuredDir = input.linkAssociationDir?.trim() ?? '';
  if (configuredDir.isEmpty) return;
  if (!input.target.includesAndroid && !input.target.includesIos) return;

  final configured = Directory(configuredDir);
  final wellKnown =
      configured.path.endsWith('${Platform.pathSeparator}.well-known')
      ? configured
      : Directory(_join(configured.path, '.well-known'));
  if (!wellKnown.existsSync()) {
    issues.add(
      ProductionPreflightIssue(
        code: 'deep_link_association_dir_missing',
        message:
            'Deep-link association directory was not found: ${wellKnown.path}',
      ),
    );
    return;
  }

  if (input.target.includesAndroid) {
    _checkAndroidAssetLinks(input, wellKnown, issues);
  }
  if (input.target.includesIos) {
    _checkAppleAppSiteAssociation(input, wellKnown, issues);
  }
}

void _checkStoreListingMetadataInput(
  ProductionPreflightInput input,
  List<ProductionPreflightIssue> issues,
) {
  if (!input.production ||
      !input.requireStoreListingMetadata ||
      (!input.target.includesAndroid && !input.target.includesIos)) {
    return;
  }

  final privacyUrl = input.storePrivacyPolicyUrl?.trim() ?? '';
  if (privacyUrl.isEmpty) {
    issues.add(
      const ProductionPreflightIssue(
        code: 'store_privacy_policy_url_missing',
        message:
            'Store submission preflight requires a partner privacy policy HTTPS URL.',
      ),
    );
  } else if (!_looksLikeHttpsProductionUrl(privacyUrl, input.production)) {
    issues.add(
      ProductionPreflightIssue(
        code: 'store_privacy_policy_url_invalid',
        message:
            'Store privacy policy URL must be an HTTPS production URL, got $privacyUrl.',
      ),
    );
  }

  final supportUrl = input.storeSupportUrl?.trim() ?? '';
  if (supportUrl.isEmpty) {
    issues.add(
      const ProductionPreflightIssue(
        code: 'store_support_url_missing',
        message:
            'Store submission preflight requires a partner support HTTPS URL.',
      ),
    );
  } else if (!_looksLikeHttpsProductionUrl(supportUrl, input.production)) {
    issues.add(
      ProductionPreflightIssue(
        code: 'store_support_url_invalid',
        message:
            'Store support URL must be an HTTPS production URL, got $supportUrl.',
      ),
    );
  }

  final accountDeletionUrl = input.storeAccountDeletionUrl?.trim() ?? '';
  if (accountDeletionUrl.isEmpty) {
    issues.add(
      const ProductionPreflightIssue(
        code: 'store_account_deletion_url_missing',
        message:
            'Store submission preflight requires a partner account deletion HTTPS URL.',
      ),
    );
  } else if (!_looksLikeHttpsProductionUrl(
    accountDeletionUrl,
    input.production,
  )) {
    issues.add(
      ProductionPreflightIssue(
        code: 'store_account_deletion_url_invalid',
        message:
            'Store account deletion URL must be an HTTPS production URL, got $accountDeletionUrl.',
      ),
    );
  }
}

void _checkAndroidAssetLinks(
  ProductionPreflightInput input,
  Directory wellKnown,
  List<ProductionPreflightIssue> issues,
) {
  final file = File(_join(wellKnown.path, 'assetlinks.json'));
  if (!file.existsSync()) {
    issues.add(
      const ProductionPreflightIssue(
        code: 'android_assetlinks_missing',
        message:
            'Android App Links require .well-known/assetlinks.json for the production callback host.',
      ),
    );
    return;
  }

  final value = _readJsonFile(
    file,
    const ProductionPreflightIssue(
      code: 'android_assetlinks_invalid',
      message: 'assetlinks.json must be valid JSON.',
    ),
    issues,
  );
  if (value == null) return;
  if (value is! List) {
    issues.add(
      const ProductionPreflightIssue(
        code: 'android_assetlinks_invalid',
        message: 'assetlinks.json must contain a list of Android app links.',
      ),
    );
    return;
  }

  final expectedPackage = input.androidPackage?.trim() ?? '';
  final matches = value.whereType<Map>().any((entry) {
    final relation = _stringListFromJson(entry['relation']);
    final target = entry['target'];
    if (target is! Map) return false;
    final fingerprints = _stringListFromJson(
      target['sha256_cert_fingerprints'],
    );
    return relation.contains('delegate_permission/common.handle_all_urls') &&
        target['namespace']?.toString() == 'android_app' &&
        target['package_name']?.toString() == expectedPackage &&
        fingerprints.any(_looksLikeSha256Fingerprint);
  });

  if (!matches) {
    issues.add(
      ProductionPreflightIssue(
        code: 'android_assetlinks_mismatch',
        message:
            'assetlinks.json must target $expectedPackage with at least one real SHA-256 signing fingerprint.',
      ),
    );
  }
}

void _checkAppleAppSiteAssociation(
  ProductionPreflightInput input,
  Directory wellKnown,
  List<ProductionPreflightIssue> issues,
) {
  final file = File(_join(wellKnown.path, 'apple-app-site-association'));
  if (!file.existsSync()) {
    issues.add(
      const ProductionPreflightIssue(
        code: 'ios_aasa_missing',
        message:
            'iOS Universal Links require .well-known/apple-app-site-association for the production callback host.',
      ),
    );
    return;
  }

  final value = _readJsonFile(
    file,
    const ProductionPreflightIssue(
      code: 'ios_aasa_invalid',
      message: 'apple-app-site-association must be valid JSON.',
    ),
    issues,
  );
  if (value == null) return;
  if (value is! Map) {
    issues.add(
      const ProductionPreflightIssue(
        code: 'ios_aasa_invalid',
        message: 'apple-app-site-association must contain an applinks object.',
      ),
    );
    return;
  }

  final expectedAppId =
      '${input.iosTeamId?.trim() ?? ''}.${input.iosBundleId?.trim() ?? ''}';
  final applinks = value['applinks'];
  final details = applinks is Map ? applinks['details'] : null;
  final matchedPaths = <String>{};
  if (details is List) {
    for (final rawDetail in details.whereType<Map>()) {
      final appIds = _stringListFromJson(rawDetail['appIDs']);
      final legacyAppId = rawDetail['appID']?.toString().trim();
      final matchesAppId =
          appIds.contains(expectedAppId) ||
          (legacyAppId != null && legacyAppId == expectedAppId);
      if (!matchesAppId) continue;

      matchedPaths.addAll(_stringListFromJson(rawDetail['paths']));
      final components = rawDetail['components'];
      if (components is List) {
        for (final component in components.whereType<Map>()) {
          final path = component['/']?.toString().trim();
          if (path?.startsWith('/') == true) matchedPaths.add(path!);
        }
      }
    }
  }

  final missingPaths = defaultCustomerDeepLinkPaths
      .where((path) => !matchedPaths.contains(path))
      .toList();
  if (matchedPaths.isEmpty || missingPaths.isNotEmpty) {
    issues.add(
      ProductionPreflightIssue(
        code: 'ios_aasa_mismatch',
        message:
            'apple-app-site-association must target $expectedAppId and include deep-link paths: ${missingPaths.isEmpty ? defaultCustomerDeepLinkPaths.join(', ') : missingPaths.join(', ')}',
      ),
    );
  }
}

void _checkApiBaseUrl(
  ProductionPreflightInput input,
  List<ProductionPreflightIssue> issues,
) {
  final value = input.apiBaseUrl?.trim() ?? '';
  if (value.isEmpty) {
    issues.add(
      const ProductionPreflightIssue(
        code: 'api_base_url_missing',
        message: 'API_BASE_URL is required.',
      ),
    );
    return;
  }

  final isRelative = value.startsWith('/');
  final uri = Uri.tryParse(value);
  final isHttps = uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;

  if (input.production && !isHttps) {
    if (input.target.includesWeb &&
        isRelative &&
        !input.target.includesAndroid &&
        !input.target.includesIos) {
      return;
    }
    issues.add(
      ProductionPreflightIssue(
        code: 'api_base_url_not_https',
        message:
            'Production native builds require an HTTPS API_BASE_URL: $value',
      ),
    );
  }
}

void _checkDisplayName(
  ProductionPreflightInput input,
  List<ProductionPreflightIssue> issues,
) {
  final value = input.appDisplayName?.trim() ?? '';
  if (!input.production) return;

  if (value.isEmpty) {
    issues.add(
      const ProductionPreflightIssue(
        code: 'app_display_name_missing',
        message:
            'Production builds require CUSTOMER_FLUTTER_APP_LABEL, CUSTOMER_FLUTTER_APP_DISPLAY_NAME, or APP_DISPLAY_NAME.',
      ),
    );
  } else if (_isDefaultDisplayName(value)) {
    issues.add(
      ProductionPreflightIssue(
        code: 'app_display_name_not_partner_specific',
        message:
            'Production builds require a partner-specific app display name, not the default scaffold name: $value',
      ),
    );
  }
}

void _checkWebProductionMetadataInput(
  ProductionPreflightInput input,
  List<ProductionPreflightIssue> issues,
) {
  if (!input.production || !input.target.includesWeb) return;

  final appName =
      (input.webAppName?.trim().isNotEmpty == true
              ? input.webAppName
              : input.appDisplayName)
          ?.trim();
  final shortName = input.webShortName?.trim() ?? '';
  final description = input.webDescription?.trim() ?? '';

  if (appName == null || appName.isEmpty) {
    issues.add(
      const ProductionPreflightIssue(
        code: 'web_app_name_missing',
        message:
            'Web production builds require CUSTOMER_FLUTTER_WEB_APP_NAME or a partner-specific app display name.',
      ),
    );
  } else if (_isDefaultDisplayName(appName)) {
    issues.add(
      ProductionPreflightIssue(
        code: 'web_app_name_not_partner_specific',
        message:
            'Web production builds require partner-specific runtime web app metadata, not the default scaffold name: $appName',
      ),
    );
  }

  if (shortName.isNotEmpty && _isDefaultDisplayName(shortName)) {
    issues.add(
      ProductionPreflightIssue(
        code: 'web_short_name_not_partner_specific',
        message:
            'Web production builds require partner-specific runtime web short name metadata, not the default scaffold name: $shortName',
      ),
    );
  } else if (shortName.isEmpty) {
    issues.add(
      const ProductionPreflightIssue(
        code: 'web_short_name_missing',
        message:
            'Web production builds require CUSTOMER_FLUTTER_WEB_SHORT_NAME for installable PWA metadata.',
      ),
    );
  }

  if (description.isEmpty) {
    issues.add(
      const ProductionPreflightIssue(
        code: 'web_description_missing',
        message:
            'Web production builds require CUSTOMER_FLUTTER_WEB_DESCRIPTION for partner-specific PWA and search metadata.',
      ),
    );
  } else if (_isDefaultWebDescription(description)) {
    issues.add(
      ProductionPreflightIssue(
        code: 'web_description_not_partner_specific',
        message:
            'Web production builds require partner-specific runtime web description metadata, not the default scaffold description: $description',
      ),
    );
  }
}

void _checkAndroid(
  ProductionPreflightInput input,
  List<ProductionPreflightIssue> issues,
) {
  final package = input.androidPackage?.trim() ?? '';
  if (!_looksLikeApplicationId(package)) {
    issues.add(
      ProductionPreflightIssue(
        code: 'android_package_invalid',
        message:
            'CUSTOMER_FLUTTER_APPLICATION_ID is not a valid package: $package',
      ),
    );
  } else if (input.production && _isDefaultAndroidApplicationId(package)) {
    issues.add(
      ProductionPreflightIssue(
        code: 'android_package_not_partner_specific',
        message:
            'CUSTOMER_FLUTTER_APPLICATION_ID must be partner-specific for production builds: $package',
      ),
    );
  }

  final scheme = input.androidCallbackScheme?.trim() ?? '';
  if (!_looksLikeScheme(scheme)) {
    issues.add(
      ProductionPreflightIssue(
        code: 'android_callback_scheme_invalid',
        message:
            'CUSTOMER_FLUTTER_AUTH_CALLBACK_SCHEME must be a custom URL scheme.',
      ),
    );
  } else if (input.production && _isDefaultCallbackScheme(scheme)) {
    issues.add(
      ProductionPreflightIssue(
        code: 'android_callback_scheme_not_partner_specific',
        message:
            'CUSTOMER_FLUTTER_AUTH_CALLBACK_SCHEME must be partner-specific for production builds: $scheme',
      ),
    );
  }

  final host = input.androidCallbackHost?.trim() ?? '';
  if (!_looksLikeProductionHost(host, input.production)) {
    issues.add(
      ProductionPreflightIssue(
        code: 'android_callback_host_invalid',
        message:
            'CUSTOMER_FLUTTER_AUTH_CALLBACK_HOST must be a production host, not localhost.',
      ),
    );
  }

  if (input.androidRequireSigning) {
    final missing = <String>[
      if ((input.androidStoreFile?.trim() ?? '').isEmpty)
        'CUSTOMER_FLUTTER_STORE_FILE',
      if ((input.androidStorePassword?.trim() ?? '').isEmpty)
        'CUSTOMER_FLUTTER_STORE_PASSWORD',
      if ((input.androidKeyAlias?.trim() ?? '').isEmpty)
        'CUSTOMER_FLUTTER_KEY_ALIAS',
      if ((input.androidKeyPassword?.trim() ?? '').isEmpty)
        'CUSTOMER_FLUTTER_KEY_PASSWORD',
    ];
    if (missing.isNotEmpty) {
      issues.add(
        ProductionPreflightIssue(
          code: 'android_signing_missing',
          message:
              'Android release signing inputs are missing: ${missing.join(', ')}',
        ),
      );
    }

    final storeFile = input.androidStoreFile?.trim();
    if (input.checkFiles && storeFile != null && storeFile.isNotEmpty) {
      if (!File(storeFile).existsSync()) {
        issues.add(
          ProductionPreflightIssue(
            code: 'android_store_file_missing',
            message: 'Android keystore file does not exist: $storeFile',
          ),
        );
      }
    }
  }

  if (input.checkFiles) {
    _checkAndroidNativeSecurity(input, issues);
  }
}

void _checkIos(
  ProductionPreflightInput input,
  List<ProductionPreflightIssue> issues,
) {
  final teamId = input.iosTeamId?.trim() ?? '';
  if (!RegExp(r'^[A-Z0-9]{10}$').hasMatch(teamId)) {
    issues.add(
      ProductionPreflightIssue(
        code: 'ios_team_id_invalid',
        message: 'CUSTOMER_FLUTTER_IOS_TEAM_ID must be a 10-character Team ID.',
      ),
    );
  }

  final bundleId = input.iosBundleId?.trim() ?? '';
  if (!_looksLikeApplicationId(bundleId)) {
    issues.add(
      ProductionPreflightIssue(
        code: 'ios_bundle_id_invalid',
        message: 'CUSTOMER_FLUTTER_IOS_BUNDLE_ID is not valid: $bundleId',
      ),
    );
  } else if (input.production && _isDefaultIosBundleId(bundleId)) {
    issues.add(
      ProductionPreflightIssue(
        code: 'ios_bundle_id_not_partner_specific',
        message:
            'CUSTOMER_FLUTTER_IOS_BUNDLE_ID must be partner-specific for production builds: $bundleId',
      ),
    );
  }

  final scheme = input.iosUrlScheme?.trim() ?? '';
  if (!_looksLikeScheme(scheme)) {
    issues.add(
      const ProductionPreflightIssue(
        code: 'ios_url_scheme_invalid',
        message: 'CUSTOMER_FLUTTER_IOS_URL_SCHEME must be a custom URL scheme.',
      ),
    );
  } else if (input.production && _isDefaultCallbackScheme(scheme)) {
    issues.add(
      ProductionPreflightIssue(
        code: 'ios_url_scheme_not_partner_specific',
        message:
            'CUSTOMER_FLUTTER_IOS_URL_SCHEME must be partner-specific for production builds: $scheme',
      ),
    );
  }

  final associatedDomain = input.iosAssociatedDomain?.trim() ?? '';
  if (!_looksLikeAssociatedDomain(associatedDomain, input.production)) {
    issues.add(
      ProductionPreflightIssue(
        code: 'ios_associated_domain_invalid',
        message:
            'CUSTOMER_FLUTTER_IOS_ASSOCIATED_DOMAIN must be an applinks: production domain.',
      ),
    );
  }

  if (input.checkFiles) {
    _checkIosNativeSecurity(input, issues);
  }
}

void _checkAndroidNativeSecurity(
  ProductionPreflightInput input,
  List<ProductionPreflightIssue> issues,
) {
  _checkAndroidManifest(input, issues);
  _checkAndroidGradleConfig(input, issues);
  _checkAndroidLaunchIdentity(input, issues);

  final mainActivity = _findFirstFile(
    Directory(_join(input.projectRoot, 'android/app/src/main/kotlin')),
    'MainActivity.kt',
  );
  if (mainActivity == null) {
    issues.add(
      const ProductionPreflightIssue(
        code: 'android_main_activity_missing',
        message: 'Android MainActivity.kt was not found.',
      ),
    );
    return;
  }

  final source = mainActivity.readAsStringSync();
  _requireSnippet(
    source,
    'FlutterFragmentActivity',
    const ProductionPreflightIssue(
      code: 'android_biometric_fragment_activity_missing',
      message:
          'Android MainActivity must extend FlutterFragmentActivity for local_auth biometric prompts.',
    ),
    issues,
  );
  final androidStyles = [
    File(
      _join(input.projectRoot, 'android/app/src/main/res/values/styles.xml'),
    ),
    File(
      _join(
        input.projectRoot,
        'android/app/src/main/res/values-night/styles.xml',
      ),
    ),
  ];
  if (androidStyles.any(
    (file) =>
        !file.existsSync() ||
        !file.readAsStringSync().contains('Theme.AppCompat'),
  )) {
    issues.add(
      const ProductionPreflightIssue(
        code: 'android_biometric_appcompat_theme_missing',
        message:
            'Android LaunchTheme and NormalTheme must inherit from Theme.AppCompat in light and night resources for biometric compatibility.',
      ),
    );
  }
  _requireSnippet(
    source,
    'WindowManager.LayoutParams.FLAG_SECURE',
    const ProductionPreflightIssue(
      code: 'android_flag_secure_missing',
      message: 'Android MainActivity must enable FLAG_SECURE.',
    ),
    issues,
  );
  _requireOrderedSnippets(
    source,
    const ['override fun onCreate', 'window.setFlags', 'super.onCreate'],
    const ProductionPreflightIssue(
      code: 'android_startup_flag_secure_missing',
      message:
          'Android MainActivity must enable FLAG_SECURE during onCreate before the first Flutter frame.',
    ),
    issues,
  );
  _requireSnippet(
    source,
    'customer_flutter/screen_security',
    const ProductionPreflightIssue(
      code: 'android_screen_security_channel_missing',
      message: 'Android MainActivity must expose the screen security channel.',
    ),
    issues,
  );
  _requireAllSnippets(
    source,
    const ['"enable"', '"disable"', '"reportSecurityEvent"'],
    const ProductionPreflightIssue(
      code: 'android_screen_security_methods_missing',
      message:
          'Android screen security channel must support enable, disable, and reportSecurityEvent.',
    ),
    issues,
  );
  _requireAllSnippets(
    source,
    const [
      'appWideScreenSecurity = true',
      'enforceAppWideScreenSecurity()',
      '"appWideProtection" to appWideScreenSecurity',
    ],
    const ProductionPreflightIssue(
      code: 'android_app_wide_screen_security_missing',
      message:
          'Android MainActivity must keep FLAG_SECURE and recent-app preview protection active across every customer route, including disable requests during Flutter route transitions.',
    ),
    issues,
  );
  _requireAllSnippets(
    source,
    const [
      '"reportSecurityEvent"',
      '"securityEvent"',
      'invokeMethod',
      '"eventName"',
      '"currentRoute"',
      '"reasonText"',
      '"android_report_security_event"',
    ],
    const ProductionPreflightIssue(
      code: 'android_screen_security_event_callback_missing',
      message:
          'Android reportSecurityEvent must forward route-aware securityEvent payloads back to Flutter for audit and session locking.',
    ),
    issues,
  );
  _requireAllSnippets(
    source,
    const [
      'ScreenCaptureCallback',
      'registerScreenCaptureCallback',
      'unregisterScreenCaptureCallback',
      'updateScreenCaptureDetection',
      'android_screen_capture_callback',
      'requestScreenSecurityExit(',
    ],
    const ProductionPreflightIssue(
      code: 'android_screen_capture_callback_missing',
      message:
          'Android 14+ screen-security builds must register the platform screenshot callback while the protected Activity is active and route delivered detections into the forced-exit policy.',
    ),
    issues,
  );
  _requireAllSnippets(
    source,
    const [
      'addScreenRecordingCallback',
      'removeScreenRecordingCallback',
      'SCREEN_RECORDING_STATE_VISIBLE',
      'updateScreenRecordingDetection',
      'android_screen_recording_callback',
      'requestScreenSecurityExit(',
      '"screen_capture_ended"',
    ],
    const ProductionPreflightIssue(
      code: 'android_screen_recording_callback_missing',
      message:
          'Android 15+ screen-security builds must observe screen recording while the protected Activity is active, route visible capture into forced exit, and report recording end.',
    ),
    issues,
  );
  _requireAllSnippets(
    source,
    const [
      'requestScreenSecurityExit(',
      'captureTerminationScheduled',
      '"screen_security_exit_requested"',
      'screenSecurityTitleKeys',
      'Toast.makeText',
      'R.string.screen_capture_not_allowed',
      'finishAndRemoveTask()',
      'exitProcess(0)',
    ],
    const ProductionPreflightIssue(
      code: 'android_screen_capture_exit_policy_missing',
      message:
          'Android screenshot and recording callbacks must show runtime-localized blocked-copy, request a security lock, remove the task, and terminate the process.',
    ),
    issues,
  );
  final screenCaptureCopyFiles = [
    File(
      _join(input.projectRoot, 'android/app/src/main/res/values/strings.xml'),
    ),
    File(
      _join(
        input.projectRoot,
        'android/app/src/main/res/values-th/strings.xml',
      ),
    ),
  ];
  if (screenCaptureCopyFiles.any(
    (file) =>
        !file.existsSync() ||
        !file.readAsStringSync().contains('screen_capture_not_allowed'),
  )) {
    issues.add(
      const ProductionPreflightIssue(
        code: 'android_screen_capture_exit_copy_missing',
        message:
            'Android screen-capture termination must bundle English and Thai fallback copy for startup before Flutter runtime localization is available.',
      ),
    );
  }
  _requireAllSnippets(
    source,
    const [
      'override fun onStart()',
      'activityStarted = true',
      'override fun onStop()',
      'activityStarted = false',
      'updateScreenSecurityDetection()',
      'unregisterScreenCaptureCallbackIfNeeded()',
      'unregisterScreenRecordingCallbackIfNeeded()',
    ],
    const ProductionPreflightIssue(
      code: 'android_screen_security_lifecycle_missing',
      message:
          'Android screenshot and recording callbacks must follow Activity start/stop lifecycle while preserving app-wide protection and the active audit route.',
    ),
    issues,
  );
  _requireAllSnippets(
    source,
    const [
      '"getSecurityState"',
      '"windowFlagSecure"',
      '"recentAppPreviewProtected"',
    ],
    const ProductionPreflightIssue(
      code: 'android_screen_security_state_probe_missing',
      message:
          'Android screen security must expose native state for physical-device verification of FLAG_SECURE and recent-app preview protection.',
    ),
    issues,
  );
  _requireAllSnippets(
    source,
    const ['protect_recent_app_preview', 'setRecentsScreenshotEnabled'],
    const ProductionPreflightIssue(
      code: 'android_recent_app_preview_guard_missing',
      message:
          'Android screen security must honor protect_recent_app_preview and disable recent-app screenshots when supported.',
    ),
    issues,
  );
  _requireAllSnippets(
    source,
    const [
      '"enabled"',
      '"active"',
      '"allowed"',
      '"supported"',
      '"disabled"',
      '"blocked"',
      '"unsupported"',
      '"not_allowed"',
    ],
    const ProductionPreflightIssue(
      code: 'android_screen_security_bool_aliases_missing',
      message:
          'Android screen security must parse BO/runtime boolean aliases before applying FLAG_SECURE and recent-app preview policy.',
    ),
    issues,
  );
  _requireSnippet(
    source,
    'customer_flutter/biometric_keys',
    const ProductionPreflightIssue(
      code: 'android_biometric_channel_missing',
      message: 'Android MainActivity must expose the biometric key channel.',
    ),
    issues,
  );
  _requireAllSnippets(
    source,
    const [
      'AndroidKeyStore',
      'existingDeviceId',
      'deleteKeyPair',
      'deleteEntry',
      'hasExistingKeyPair',
      'remove(deviceIdKey)',
      'credentialId',
      'rawId',
      'signatureBase64',
      'signatureDer',
      'signedPayload',
      'keyAlgorithm',
      'setUserAuthenticationRequired(true)',
      'AUTH_BIOMETRIC_STRONG',
      'setInvalidatedByBiometricEnrollment(true)',
      'KeyPermanentlyInvalidatedException',
      'UnrecoverableKeyException',
      'isBiometricKeyInvalidated',
      'biometric_key_invalidated',
      'packageName',
    ],
    const ProductionPreflightIssue(
      code: 'android_biometric_keyguard_missing',
      message:
          'Android biometric keys must be package-scoped, require user authentication, and be invalidated on enrollment changes.',
    ),
    issues,
  );
  _rejectSnippet(
    source,
    'AUTH_DEVICE_CREDENTIAL',
    const ProductionPreflightIssue(
      code: 'android_biometric_device_credential_allowed',
      message:
          'Android biometric assertion keys must not allow device credential fallback; use AUTH_BIOMETRIC_STRONG only.',
    ),
    issues,
  );
}

void _checkAndroidLaunchIdentity(
  ProductionPreflightInput input,
  List<ProductionPreflightIssue> issues,
) {
  final colors = File(
    _join(input.projectRoot, 'android/app/src/main/res/values/colors.xml'),
  );
  final launch = File(
    _join(
      input.projectRoot,
      'android/app/src/main/res/drawable/launch_background.xml',
    ),
  );
  final launchV21 = File(
    _join(
      input.projectRoot,
      'android/app/src/main/res/drawable-v21/launch_background.xml',
    ),
  );
  final artwork = File(
    _join(
      input.projectRoot,
      'android/app/src/main/res/drawable-nodpi/siamblend_splash.jpg',
    ),
  );
  if (!colors.existsSync() ||
      !launch.existsSync() ||
      !launchV21.existsSync() ||
      !artwork.existsSync()) {
    issues.add(
      const ProductionPreflightIssue(
        code: 'android_launch_identity_missing',
        message:
            'Android launch resources must bundle the owner-approved Siamblend artwork.',
      ),
    );
    return;
  }

  final colorSource = colors.readAsStringSync();
  final launchSource = launch.readAsStringSync();
  final launchV21Source = launchV21.readAsStringSync();
  final missingIdentity = !colorSource.contains('customer_launch_background') ||
      !colorSource.contains('#0B96DC') ||
      !launchSource.contains('@color/customer_launch_background') ||
      !launchV21Source.contains('@color/customer_launch_background') ||
      !launchSource.contains('@drawable/siamblend_splash') ||
      !launchV21Source.contains('@drawable/siamblend_splash') ||
      !launchSource.contains('android:gravity="fill"') ||
      !launchV21Source.contains('android:gravity="fill"');
  if (missingIdentity) {
    issues.add(
      const ProductionPreflightIssue(
        code: 'android_launch_identity_missing',
        message:
            'Android launch background must render the Siamblend splash artwork over its matching #0B96DC fallback.',
      ),
    );
  }
}

void _checkAndroidManifest(
  ProductionPreflightInput input,
  List<ProductionPreflightIssue> issues,
) {
  final manifest = File(
    _join(input.projectRoot, 'android/app/src/main/AndroidManifest.xml'),
  );
  if (!manifest.existsSync()) {
    issues.add(
      const ProductionPreflightIssue(
        code: 'android_manifest_missing',
        message: 'AndroidManifest.xml was not found.',
      ),
    );
    return;
  }

  final source = manifest.readAsStringSync();
  _requireSnippet(
    source,
    'android.permission.USE_BIOMETRIC',
    const ProductionPreflightIssue(
      code: 'android_biometric_permission_missing',
      message: 'AndroidManifest.xml must declare USE_BIOMETRIC.',
    ),
    issues,
  );
  _requireSnippet(
    source,
    'android.permission.DETECT_SCREEN_CAPTURE',
    const ProductionPreflightIssue(
      code: 'android_screen_capture_permission_missing',
      message:
          'AndroidManifest.xml must declare DETECT_SCREEN_CAPTURE for Android 14+ screenshot detection on sensitive routes.',
    ),
    issues,
  );
  _requireSnippet(
    source,
    'android.permission.DETECT_SCREEN_RECORDING',
    const ProductionPreflightIssue(
      code: 'android_screen_recording_permission_missing',
      message:
          'AndroidManifest.xml must declare DETECT_SCREEN_RECORDING for Android 15+ recording detection on sensitive routes.',
    ),
    issues,
  );
  _requireAllSnippets(
    source,
    const ['android:allowBackup="false"', 'android:fullBackupContent="false"'],
    const ProductionPreflightIssue(
      code: 'android_backup_disabled_missing',
      message:
          'AndroidManifest.xml must disable app backup for production customer builds.',
    ),
    issues,
  );
  _requireSnippet(
    source,
    r'android:scheme="${authCallbackScheme}"',
    const ProductionPreflightIssue(
      code: 'android_custom_scheme_callback_missing',
      message:
          'AndroidManifest.xml must declare the runtime custom-scheme auth callback.',
    ),
    issues,
  );
  _requireAllSnippets(
    source,
    const [
      'android:autoVerify="true"',
      r'android:host="${authCallbackHost}"',
      'android:pathPrefix="/line/callback"',
      'android:pathPrefix="/social"',
      'android:pathPrefix="/reset-password"',
      'android:pathPrefix="/checkout/pending"',
    ],
    const ProductionPreflightIssue(
      code: 'android_app_links_missing',
      message:
          'AndroidManifest.xml must declare verified HTTPS app links for auth, reset, and checkout callbacks.',
    ),
    issues,
  );
  _checkAndroidReleaseManifest(input, issues);
}

void _checkAndroidReleaseManifest(
  ProductionPreflightInput input,
  List<ProductionPreflightIssue> issues,
) {
  final manifest = File(
    _join(input.projectRoot, 'android/app/src/release/AndroidManifest.xml'),
  );
  if (!manifest.existsSync()) {
    issues.add(
      const ProductionPreflightIssue(
        code: 'android_release_manifest_missing',
        message:
            'Android release manifest overlay must disable cleartext network traffic.',
      ),
    );
    return;
  }

  final source = manifest.readAsStringSync();
  _requireSnippet(
    source,
    'android:usesCleartextTraffic="false"',
    const ProductionPreflightIssue(
      code: 'android_cleartext_traffic_not_disabled',
      message:
          'Android release manifest overlay must set android:usesCleartextTraffic="false".',
    ),
    issues,
  );
}

void _checkAndroidGradleConfig(
  ProductionPreflightInput input,
  List<ProductionPreflightIssue> issues,
) {
  final buildGradle = File(
    _join(input.projectRoot, 'android/app/build.gradle.kts'),
  );
  if (!buildGradle.existsSync()) {
    issues.add(
      const ProductionPreflightIssue(
        code: 'android_gradle_config_missing',
        message: 'android/app/build.gradle.kts was not found.',
      ),
    );
    return;
  }

  final source = buildGradle.readAsStringSync();
  _requireAllSnippets(
    source,
    const [
      'CUSTOMER_FLUTTER_APPLICATION_ID',
      'CUSTOMER_FLUTTER_APP_LABEL',
      'CUSTOMER_FLUTTER_AUTH_CALLBACK_SCHEME',
      'CUSTOMER_FLUTTER_AUTH_CALLBACK_HOST',
      'manifestPlaceholders["appLabel"]',
      'manifestPlaceholders["authCallbackScheme"]',
      'manifestPlaceholders["authCallbackHost"]',
    ],
    const ProductionPreflightIssue(
      code: 'android_runtime_config_missing',
      message:
          'Android Gradle config must expose runtime app id, label, and auth callback placeholders.',
    ),
    issues,
  );
}

void _checkIosNativeSecurity(
  ProductionPreflightInput input,
  List<ProductionPreflightIssue> issues,
) {
  final infoPlist = File(_join(input.projectRoot, 'ios/Runner/Info.plist'));
  if (!infoPlist.existsSync()) {
    issues.add(
      const ProductionPreflightIssue(
        code: 'ios_info_plist_missing',
        message: 'iOS Info.plist was not found.',
      ),
    );
  } else {
    final plist = infoPlist.readAsStringSync();
    _requireSnippet(
      plist,
      'NSFaceIDUsageDescription',
      const ProductionPreflightIssue(
        code: 'ios_face_id_usage_missing',
        message: 'iOS Info.plist must include NSFaceIDUsageDescription.',
      ),
      issues,
    );
    _requireSnippet(
      plist,
      'CFBundleURLSchemes',
      const ProductionPreflightIssue(
        code: 'ios_url_scheme_plist_missing',
        message:
            'iOS Info.plist must declare URL schemes for social auth callbacks.',
      ),
      issues,
    );
    _requireSnippet(
      plist,
      r'$(APP_DISPLAY_NAME)',
      const ProductionPreflightIssue(
        code: 'ios_display_name_runtime_missing',
        message:
            'iOS Info.plist must read CFBundleDisplayName from APP_DISPLAY_NAME.',
      ),
      issues,
    );
    if (!_hasPlistStringValue(plist, 'CFBundleName', r'$(APP_DISPLAY_NAME)')) {
      issues.add(
        const ProductionPreflightIssue(
          code: 'ios_bundle_name_runtime_missing',
          message:
              'iOS Info.plist must read CFBundleName from APP_DISPLAY_NAME.',
        ),
      );
    }
    _requireSnippet(
      plist,
      r'$(CUSTOMER_FLUTTER_URL_SCHEME)',
      const ProductionPreflightIssue(
        code: 'ios_url_scheme_runtime_missing',
        message:
            'iOS Info.plist must read URL scheme from CUSTOMER_FLUTTER_URL_SCHEME.',
      ),
      issues,
    );
    _checkIosImagePickerUsageDescriptions(input, plist, issues);
  }

  final localizedFaceIdUsage = [
    File(_join(input.projectRoot, 'ios/Runner/en.lproj/InfoPlist.strings')),
    File(_join(input.projectRoot, 'ios/Runner/th.lproj/InfoPlist.strings')),
  ];
  final iosProject = File(
    _join(input.projectRoot, 'ios/Runner.xcodeproj/project.pbxproj'),
  );
  final hasLocalizedFaceIdUsage =
      localizedFaceIdUsage.every(
        (file) =>
            file.existsSync() &&
            file.readAsStringSync().contains('NSFaceIDUsageDescription'),
      ) &&
      iosProject.existsSync() &&
      iosProject.readAsStringSync().contains('InfoPlist.strings in Resources');
  if (!hasLocalizedFaceIdUsage) {
    issues.add(
      const ProductionPreflightIssue(
        code: 'ios_face_id_localization_missing',
        message:
            'iOS must bundle English and Thai NSFaceIDUsageDescription localizations for native Face ID permission prompts.',
      ),
    );
  }

  _checkIosEntitlements(input, issues);
  _checkIosXcconfig(input, issues);
  _checkIosPrivacyManifest(input, issues);
  _checkIosProjectConfig(input, issues);
  _checkIosReleaseConfigGuard(input, issues);
  _checkIosLaunchIdentity(input, issues);

  final appDelegate = File(
    _join(input.projectRoot, 'ios/Runner/AppDelegate.swift'),
  );
  if (!appDelegate.existsSync()) {
    issues.add(
      const ProductionPreflightIssue(
        code: 'ios_app_delegate_missing',
        message: 'iOS AppDelegate.swift was not found.',
      ),
    );
    return;
  }

  final source = appDelegate.readAsStringSync();
  _requireSnippet(
    source,
    'customer_flutter/screen_security',
    const ProductionPreflightIssue(
      code: 'ios_screen_security_channel_missing',
      message: 'iOS AppDelegate must expose the screen security channel.',
    ),
    issues,
  );
  _requireAllSnippets(
    source,
    const [
      'UIApplication.userDidTakeScreenshotNotification',
      'UIScreen.capturedDidChangeNotification',
      'UIScreen.main.isCaptured',
      'UIApplication.userDidTakeScreenshotNotification.rawValue',
      'UIScreen.capturedDidChangeNotification.rawValue',
      '"nativeEvent"',
      '"isCaptured"',
      '"screenCaptureActive"',
      '"currentRoute"',
      '"reasonText"',
      'showPrivacyOverlay',
      'scheduleScreenshotOverlayDismissal',
      'DispatchQueue.main.asyncAfter',
      'securityEvent',
    ],
    const ProductionPreflightIssue(
      code: 'ios_screen_capture_detection_missing',
      message:
          'iOS AppDelegate must detect screenshots, recording/mirroring, show the privacy overlay, and notify Flutter.',
    ),
    issues,
  );
  _requireAllSnippets(
    source,
    const [
      'IOSSecureCaptureProtector',
      'isSecureTextEntry = true',
      'blackBackdropView.backgroundColor = .black',
      'refreshSecureCaptureProtection',
      'secureCaptureProtector.enable(in: window)',
      'secureCaptureProtector.disable()',
    ],
    const ProductionPreflightIssue(
      code: 'ios_secure_capture_protection_missing',
      message:
          'iOS AppDelegate must protect sensitive content before capture and render a black replacement in screenshots.',
    ),
    issues,
  );
  _requireAllSnippets(
    source,
    const [
      'UIApplication.willResignActiveNotification',
      'UIApplication.didBecomeActiveNotification',
      'applicationWillHideSensitiveSnapshot',
      'applicationDidReturnFromSensitiveSnapshot',
      'showPrivacyOverlay',
    ],
    const ProductionPreflightIssue(
      code: 'ios_sensitive_snapshot_overlay_missing',
      message:
          'iOS AppDelegate must hide sensitive content before app switcher snapshots and restore safely after returning active.',
    ),
    issues,
  );
  _requireAllSnippets(
    source,
    const [
      'ios_exit_app',
      'iosExitAppEnabled',
      'screen_security_exit_requested',
      'captureTerminationScheduled',
      'exit(EXIT_SUCCESS)',
    ],
    const ProductionPreflightIssue(
      code: 'ios_exit_app_policy_missing',
      message:
          'iOS AppDelegate must honor the ios_exit_app screen-security policy by terminating after a capture event.',
    ),
    issues,
  );
  _requireAllSnippets(
    source,
    const [
      'screenSecurityRouteKeys',
      '"currentRoute"',
      '"routeName"',
      '"targetUrl"',
      'screenSecurityEventKeys',
      '"eventName"',
      '"nativeEvent"',
      'screenSecurityReasonKeys',
      '"reasonText"',
      'screenshotPolicyKeys',
      '"iosScreenshotPolicy"',
      'screenCaptureOverlayKeys',
      '"iosScreenCaptureOverlay"',
      'exitAppPolicyKeys',
      '"iosExitApp"',
      'privacyOverlayTitleKeys',
      '"privacyOverlayTitle"',
      'privacyOverlayDescriptionKeys',
      '"privacyOverlayDescription"',
      'stringArg(',
      'normalizedStringArg',
      '"enabled"',
      '"active"',
      '"allowed"',
      '"supported"',
      '"disabled"',
      '"blocked"',
      '"unsupported"',
      '"not_allowed"',
    ],
    const ProductionPreflightIssue(
      code: 'ios_screen_security_aliases_missing',
      message:
          'iOS AppDelegate must accept runtime screen-security route/event/reason/policy/copy aliases before forwarding native events.',
    ),
    issues,
  );
  _requireSnippet(
    source,
    'customer_flutter/biometric_keys',
    const ProductionPreflightIssue(
      code: 'ios_biometric_channel_missing',
      message: 'iOS AppDelegate must expose the biometric key channel.',
    ),
    issues,
  );
  _requireAllSnippets(
    source,
    const [
      'kSecAttrAccessibleWhenUnlockedThisDeviceOnly',
      'biometryCurrentSet',
      'existingDeviceId',
      'deleteKeyPair',
      'SecItemDelete',
      'hasExistingBiometricKeyPair',
      'removeObject(forKey: biometricDeviceIdKey)',
      '"credentialId"',
      '"rawId"',
      '"signatureBase64"',
      '"signatureDer"',
      '"signedPayload"',
      '"keyAlgorithm"',
      'SecKeyCreateSignature',
      'shouldInvalidateBiometricKey',
      'errSecItemNotFound',
      'biometric_key_invalidated',
      'isBiometricCancellation',
      'errSecUserCanceled',
      'LAError.Code.userCancel',
      'biometric_cancelled',
      'Bundle.main.bundleIdentifier',
    ],
    const ProductionPreflightIssue(
      code: 'ios_biometric_keyguard_missing',
      message:
          'iOS biometric keys must be bundle-scoped, device-bound, biometric-bound, and able to sign challenges.',
    ),
    issues,
  );
  _requireAllSnippets(
    source,
    const [
      'import LocalAuthentication',
      'LAContext()',
      'context.localizedReason',
      'kSecUseAuthenticationContext',
      'localizedReason: localizedReason',
    ],
    const ProductionPreflightIssue(
      code: 'ios_biometric_authentication_context_missing',
      message:
          'iOS biometric signing must authenticate the biometryCurrentSet key with an LAContext and runtime localized reason.',
    ),
    issues,
  );
}

void _checkIosLaunchIdentity(
  ProductionPreflightInput input,
  List<ProductionPreflightIssue> issues,
) {
  final storyboard = File(
    _join(input.projectRoot, 'ios/Runner/Base.lproj/LaunchScreen.storyboard'),
  );
  final contents = File(
    _join(
      input.projectRoot,
      'ios/Runner/Assets.xcassets/SplashBackground.imageset/Contents.json',
    ),
  );
  final artwork = File(
    _join(
      input.projectRoot,
      'ios/Runner/Assets.xcassets/SplashBackground.imageset/siamblend_splash.jpg',
    ),
  );
  if (!storyboard.existsSync() ||
      !contents.existsSync() ||
      !artwork.existsSync()) {
    issues.add(
      const ProductionPreflightIssue(
        code: 'ios_launch_identity_missing',
        message:
            'iOS LaunchScreen must bundle the owner-approved Siamblend artwork.',
      ),
    );
    return;
  }

  final source = storyboard.readAsStringSync();
  final contentsSource = contents.readAsStringSync();
  final hasSplashArtwork = source.contains('image="SplashBackground"') &&
      source.contains('contentMode="scaleAspectFill"') &&
      source.contains('firstAttribute="leading"') &&
      source.contains('firstAttribute="top"') &&
      source.contains('firstAttribute="trailing"') &&
      source.contains('firstAttribute="bottom"') &&
      source.contains('red="0.0431372549"') &&
      source.contains('green="0.5882352941"') &&
      source.contains('blue="0.862745098"') &&
      contentsSource.contains('"filename" : "siamblend_splash.jpg"');
  if (!hasSplashArtwork) {
    issues.add(
      const ProductionPreflightIssue(
        code: 'ios_launch_identity_missing',
        message:
            'iOS launch screen must edge-pin the aspect-fill Siamblend artwork over its matching blue fallback.',
      ),
    );
  }
}

void _checkIosImagePickerUsageDescriptions(
  ProductionPreflightInput input,
  String plist,
  List<ProductionPreflightIssue> issues,
) {
  final sources = _iosImagePickerSources(input.projectRoot);
  if (sources.contains('gallery')) {
    _requireSnippet(
      plist,
      'NSPhotoLibraryUsageDescription',
      const ProductionPreflightIssue(
        code: 'ios_photo_library_usage_missing',
        message:
            'iOS Info.plist must include NSPhotoLibraryUsageDescription when Flutter uses image_picker gallery flows.',
      ),
      issues,
    );
  }
  if (sources.contains('camera')) {
    _requireSnippet(
      plist,
      'NSCameraUsageDescription',
      const ProductionPreflightIssue(
        code: 'ios_camera_usage_missing',
        message:
            'iOS Info.plist must include NSCameraUsageDescription when Flutter uses image_picker camera flows.',
      ),
      issues,
    );
  }
}

void _checkIosPrivacyManifest(
  ProductionPreflightInput input,
  List<ProductionPreflightIssue> issues,
) {
  final manifest = File(
    _join(input.projectRoot, 'ios/Runner/PrivacyInfo.xcprivacy'),
  );
  if (!manifest.existsSync()) {
    issues.add(
      const ProductionPreflightIssue(
        code: 'ios_privacy_manifest_missing',
        message:
            'iOS Runner target must include PrivacyInfo.xcprivacy for App Store privacy manifests.',
      ),
    );
    return;
  }

  final source = manifest.readAsStringSync();
  _requireAllSnippets(
    source,
    const [
      'NSPrivacyTracking',
      '<false/>',
      'NSPrivacyTrackingDomains',
      'NSPrivacyCollectedDataTypes',
      'NSPrivacyCollectedDataTypePhoneNumber',
      'NSPrivacyCollectedDataTypeUserID',
      'NSPrivacyCollectedDataTypePurchaseHistory',
      'NSPrivacyCollectedDataTypePhotosorVideos',
      'NSPrivacyCollectedDataTypeOtherFinancialInfo',
      'NSPrivacyCollectedDataTypePurposeAppFunctionality',
      'NSPrivacyAccessedAPITypes',
      'NSPrivacyAccessedAPICategoryUserDefaults',
      'CA92.1',
    ],
    const ProductionPreflightIssue(
      code: 'ios_privacy_manifest_incomplete',
      message:
          'iOS PrivacyInfo.xcprivacy must declare no tracking, customer app-functionality data use, and the UserDefaults required-reason API used by native biometric storage.',
    ),
    issues,
  );

  final project = File(
    _join(input.projectRoot, 'ios/Runner.xcodeproj/project.pbxproj'),
  );
  if (!project.existsSync()) return;
  _requireAllSnippets(
    project.readAsStringSync(),
    const ['PrivacyInfo.xcprivacy', 'PrivacyInfo.xcprivacy in Resources'],
    const ProductionPreflightIssue(
      code: 'ios_privacy_manifest_project_binding_missing',
      message:
          'iOS Runner target must include PrivacyInfo.xcprivacy in the Resources build phase.',
    ),
    issues,
  );
}

Set<String> _iosImagePickerSources(String projectRoot) {
  final lib = Directory(_join(projectRoot, 'lib'));
  if (!lib.existsSync()) return const {};

  final sources = <String>{};
  for (final entity in lib.listSync(recursive: true, followLinks: false)) {
    if (entity is! File || _extensionOf(entity.path) != '.dart') continue;

    String source;
    try {
      source = entity.readAsStringSync();
    } on FileSystemException {
      continue;
    } on FormatException {
      continue;
    }

    if (!source.contains('image_picker') &&
        !source.contains('ImagePicker') &&
        !source.contains('ImageSource.')) {
      continue;
    }

    if (source.contains('ImageSource.camera')) sources.add('camera');
    if (source.contains('ImageSource.gallery') ||
        source.contains('ImageSource.photos') ||
        source.contains('pickImage(') ||
        source.contains('pickMultiImage(')) {
      sources.add('gallery');
    }
  }
  return sources;
}

void _checkIosEntitlements(
  ProductionPreflightInput input,
  List<ProductionPreflightIssue> issues,
) {
  final file = File(_join(input.projectRoot, 'ios/Runner/Runner.entitlements'));
  if (!file.existsSync()) {
    issues.add(
      const ProductionPreflightIssue(
        code: 'ios_entitlements_missing',
        message: 'iOS Runner.entitlements was not found.',
      ),
    );
    return;
  }

  final source = file.readAsStringSync();
  _requireAllSnippets(
    source,
    const [
      'com.apple.developer.associated-domains',
      r'$(CUSTOMER_FLUTTER_ASSOCIATED_DOMAIN)',
    ],
    const ProductionPreflightIssue(
      code: 'ios_associated_domains_entitlement_missing',
      message:
          'iOS entitlements must declare runtime-configured Associated Domains.',
    ),
    issues,
  );
}

void _checkIosXcconfig(
  ProductionPreflightInput input,
  List<ProductionPreflightIssue> issues,
) {
  final paths = const [
    'ios/Flutter/Debug.xcconfig',
    'ios/Flutter/Release.xcconfig',
  ];
  for (final path in paths) {
    final file = File(_join(input.projectRoot, path));
    if (!file.existsSync()) {
      issues.add(
        ProductionPreflightIssue(
          code: 'ios_xcconfig_missing',
          message: '$path was not found.',
        ),
      );
      continue;
    }

    final source = file.readAsStringSync();
    _requireAllSnippets(
      source,
      const [
        'APP_DISPLAY_NAME=',
        'CUSTOMER_FLUTTER_URL_SCHEME=',
        'CUSTOMER_FLUTTER_ASSOCIATED_DOMAIN=',
      ],
      ProductionPreflightIssue(
        code: 'ios_xcconfig_runtime_values_missing',
        message:
            '$path must define APP_DISPLAY_NAME, CUSTOMER_FLUTTER_URL_SCHEME, and CUSTOMER_FLUTTER_ASSOCIATED_DOMAIN.',
      ),
      issues,
    );

    if (path.endsWith('Release.xcconfig')) {
      _requireAllSnippets(
        source,
        const [
          r'APP_DISPLAY_NAME=$(CUSTOMER_FLUTTER_APP_DISPLAY_NAME)',
          r'CUSTOMER_FLUTTER_URL_SCHEME=$(CUSTOMER_FLUTTER_IOS_URL_SCHEME)',
          r'CUSTOMER_FLUTTER_ASSOCIATED_DOMAIN=$(CUSTOMER_FLUTTER_IOS_ASSOCIATED_DOMAIN)',
        ],
        const ProductionPreflightIssue(
          code: 'ios_release_xcconfig_hardcoded',
          message:
              'Release.xcconfig must read partner-specific display name, URL scheme, and Associated Domain from CI/Xcode settings.',
        ),
        issues,
      );
    }
  }
}

void _checkIosProjectConfig(
  ProductionPreflightInput input,
  List<ProductionPreflightIssue> issues,
) {
  final file = File(
    _join(input.projectRoot, 'ios/Runner.xcodeproj/project.pbxproj'),
  );
  if (!file.existsSync()) {
    issues.add(
      const ProductionPreflightIssue(
        code: 'ios_project_config_missing',
        message: 'iOS Runner.xcodeproj project.pbxproj was not found.',
      ),
    );
    return;
  }

  final source = file.readAsStringSync();
  _requireSnippet(
    source,
    'CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;',
    const ProductionPreflightIssue(
      code: 'ios_entitlements_project_config_missing',
      message: 'iOS Runner target must reference Runner/Runner.entitlements.',
    ),
    issues,
  );
  _requireAllSnippets(
    source,
    const [
      'Validate Release Config',
      'scripts/validate_release_config.sh',
      r'PRODUCT_BUNDLE_IDENTIFIER = "$(CUSTOMER_FLUTTER_IOS_BUNDLE_ID)"',
      r'DEVELOPMENT_TEAM = "$(CUSTOMER_FLUTTER_IOS_TEAM_ID)"',
    ],
    const ProductionPreflightIssue(
      code: 'ios_release_project_guard_missing',
      message:
          'iOS Runner release config must use partner-specific Team ID / bundle ID and run Validate Release Config.',
    ),
    issues,
  );
}

void _checkIosReleaseConfigGuard(
  ProductionPreflightInput input,
  List<ProductionPreflightIssue> issues,
) {
  final file = File(
    _join(input.projectRoot, 'ios/scripts/validate_release_config.sh'),
  );
  if (!file.existsSync()) {
    issues.add(
      const ProductionPreflightIssue(
        code: 'ios_release_config_guard_missing',
        message: 'iOS release config guard script was not found.',
      ),
    );
    return;
  }

  final source = file.readAsStringSync();
  _requireAllSnippets(
    source,
    const [
      'APP_DISPLAY_NAME',
      'CUSTOMER_FLUTTER_URL_SCHEME',
      'CUSTOMER_FLUTTER_ASSOCIATED_DOMAIN',
      'PRODUCT_BUNDLE_IDENTIFIER',
      'DEVELOPMENT_TEAM',
      'com.newpaotang.customerFlutter',
    ],
    const ProductionPreflightIssue(
      code: 'ios_release_config_guard_incomplete',
      message:
          'iOS release config guard must fail Release builds with missing or default partner settings.',
    ),
    issues,
  );
}

void _checkForbiddenProductionSourceReferences(
  ProductionPreflightInput input,
  List<ProductionPreflightIssue> issues,
) {
  final root = Directory(input.projectRoot);
  if (!root.existsSync()) return;

  const scanPaths = [
    'lib',
    'android/app',
    'ios/Runner',
    'ios/Flutter/Release.xcconfig',
    'web',
  ];
  const textExtensions = {
    '.dart',
    '.gradle',
    '.html',
    '.json',
    '.kt',
    '.kts',
    '.plist',
    '.swift',
    '.xml',
    '.xcconfig',
    '.entitlements',
    '.storyboard',
  };
  final forbiddenPatterns = <String, RegExp>{
    'localhost': RegExp(
      r'(?<![A-Za-z0-9_-])localhost(?![A-Za-z0-9_-])',
      caseSensitive: false,
    ),
    'loopback_ip': RegExp(r'\b(?:127\.\d{1,3}\.\d{1,3}\.\d{1,3}|0\.0\.0\.0)\b'),
    'example_domain': RegExp(
      r'\b(?:[A-Za-z0-9-]+\.)?example\.com\b',
      caseSensitive: false,
    ),
  };

  for (final scanPath in scanPaths) {
    final rootPath = _join(input.projectRoot, scanPath);
    final rootEntity = FileSystemEntity.typeSync(rootPath);
    if (rootEntity == FileSystemEntityType.notFound) continue;

    final files = rootEntity == FileSystemEntityType.file
        ? <File>[File(rootPath)]
        : Directory(
            rootPath,
          ).listSync(recursive: true, followLinks: false).whereType<File>();

    for (final entity in files) {
      final extension = _extensionOf(entity.path);
      if (!textExtensions.contains(extension)) continue;

      String source;
      try {
        source = entity.readAsStringSync();
      } on FileSystemException {
        continue;
      } on FormatException {
        continue;
      }

      for (final entry in forbiddenPatterns.entries) {
        final match = entry.value.firstMatch(source);
        if (match == null) continue;

        final line = _lineNumberForOffset(source, match.start);
        final path = _relativePath(input.projectRoot, entity.path);
        issues.add(
          ProductionPreflightIssue(
            code: 'forbidden_production_source_reference',
            message:
                'Production source contains ${entry.key} in $path:$line. Use runtime config instead of checked-in development hosts.',
          ),
        );
      }
    }
  }
}

void _checkExternalLinkLaunchPolicy(
  ProductionPreflightInput input,
  List<ProductionPreflightIssue> issues,
) {
  final lib = Directory(_join(input.projectRoot, 'lib'));
  if (!lib.existsSync()) return;

  const launcherPath = 'lib/core/navigation/customer_link_launcher.dart';
  final forbiddenPatterns = <String, RegExp>{
    'url_launcher_import': RegExp(
      "import\\s+['\"]package:url_launcher/url_launcher\\.dart['\"]",
    ),
    'launchUrl_call': RegExp(r'\blaunchUrl\s*\('),
  };

  for (final entity in lib.listSync(recursive: true, followLinks: false)) {
    if (entity is! File || _extensionOf(entity.path) != '.dart') continue;

    final path = _relativePath(input.projectRoot, entity.path);
    if (path == launcherPath) continue;

    String source;
    try {
      source = entity.readAsStringSync();
    } on FileSystemException {
      continue;
    } on FormatException {
      continue;
    }

    for (final entry in forbiddenPatterns.entries) {
      final match = entry.value.firstMatch(source);
      if (match == null) continue;

      final line = _lineNumberForOffset(source, match.start);
      issues.add(
        ProductionPreflightIssue(
          code: 'external_link_policy_bypass',
          message:
              'External link launch policy is bypassed by ${entry.key} in $path:$line. Use CustomerLinkLauncher instead.',
        ),
      );
    }
  }
}

void _checkWebRuntimeMetadata(
  ProductionPreflightInput input,
  List<ProductionPreflightIssue> issues,
) {
  final indexFile = File(_join(input.projectRoot, 'web/index.html'));
  final manifestFile = File(_join(input.projectRoot, 'web/manifest.json'));
  final sources = <String, String>{};

  if (indexFile.existsSync()) {
    sources['web/index.html'] = indexFile.readAsStringSync();
  }
  if (manifestFile.existsSync()) {
    sources['web/manifest.json'] = manifestFile.readAsStringSync();
  }

  if (sources.isEmpty) return;

  const scaffoldValues = ['customer_flutter', 'A new Flutter project.'];
  for (final entry in sources.entries) {
    for (final value in scaffoldValues) {
      if (!entry.value.contains(value)) continue;
      issues.add(
        ProductionPreflightIssue(
          code: 'web_default_scaffold_metadata',
          message:
              '${entry.key} still contains Flutter scaffold metadata "$value". Use neutral defaults and runtime metadata config.',
        ),
      );
      break;
    }
  }

  final indexSource = sources['web/index.html'] ?? '';
  _requireAllSnippets(
    indexSource,
    const [
      'customerFlutterWebConfig',
      'customerFlutterConfig',
      '__CUSTOMER_FLUTTER_WEB_CONFIG__',
      'runtimeConfigSources',
      'expandedRuntimeConfigSources',
      'addConfigSource',
      'configScalar',
      '"colors"',
      '"icons"',
      '"seo"',
      '"publicUrl"',
      '"assetUrl"',
      '"cssValue"',
      'firstConfigValue',
      'document.title',
      'meta[name="description"]',
      'meta[name="theme-color"]',
      'meta[name="msapplication-TileColor"]',
      'viewport-fit=cover',
      'apple-mobile-web-app-status-bar-style',
      'black-translucent',
      'meta[name="apple-mobile-web-app-title"]',
      'meta[property="og:title"]',
      'meta[property="og:description"]',
      'meta[property="og:url"]',
      'meta[property="og:image"]',
      'meta[name="twitter:title"]',
      'meta[name="twitter:description"]',
      'meta[name="twitter:url"]',
      'meta[name="twitter:image"]',
      '"webAppName"',
      '"web_app_name"',
      '"shortName"',
      '"short_name"',
      '"webShortName"',
      '"web_short_name"',
      '"webDescription"',
      '"web_description"',
      'normalizeThemeColor',
      '"themeColor"',
      '"theme_color"',
      '"manifestThemeColor"',
      '"manifest_theme_color"',
      '"primaryColor"',
      '"primary_color"',
      '"brandColor"',
      '"brand_color"',
      'document.documentElement.style.setProperty("--customer-theme-color"',
      '"manifestBackgroundColor"',
      '"manifest_background_color"',
      '"backgroundColor"',
      '"background_color"',
      '"faviconUrl"',
      '"favicon_url"',
      '"appleTouchIconUrl"',
      '"apple_touch_icon_url"',
      '"icon192Url"',
      '"icon_192_url"',
      '"icon512Url"',
      '"icon_512_url"',
      '"maskableIcon192Url"',
      '"maskable_icon_192_url"',
      '"maskableIcon512Url"',
      '"maskable_icon_512_url"',
      '"ogTitle"',
      '"og_title"',
      '"ogDescription"',
      '"og_description"',
      '"ogImageUrl"',
      '"og_image_url"',
      '"shareImageUrl"',
      '"share_image_url"',
      '"canonicalUrl"',
      '"canonical_url"',
      '"siteUrl"',
      '"site_url"',
      '"startUrl"',
      '"start_url"',
      '"webStartUrl"',
      '"web_start_url"',
      '"manifestId"',
      '"manifest_id"',
      '"webAppId"',
      '"web_app_id"',
      '"scope"',
      '"webScope"',
      '"web_scope"',
      '"displayMode"',
      '"display_mode"',
      '"webDisplay"',
      '"web_display"',
      'const manifestOrientation = "portrait-primary"',
      'customerRequestPortraitOrientation',
      'lockOrientation(orientation, "portrait-primary")',
      'customer-portrait-orientation-guard',
      '"lang"',
      '"defaultLocale"',
      '"default_locale"',
      '"dir"',
      '"textDirection"',
      '"text_direction"',
      'document.documentElement.setAttribute("lang"',
      'document.documentElement.setAttribute("dir"',
      'link[rel="icon"]',
      'link[rel="apple-touch-icon"]',
      'link[rel="canonical"]',
      'application/manifest+json',
    ],
    const ProductionPreflightIssue(
      code: 'web_runtime_metadata_config_missing',
      message:
          'web/index.html must support runtime partner metadata and the fixed portrait Web/PWA orientation contract.',
    ),
    issues,
  );

  final splashArtwork = File(
    _join(input.projectRoot, 'web/splash/siamblend_splash.jpg'),
  );
  if (!splashArtwork.existsSync()) {
    issues.add(
      const ProductionPreflightIssue(
        code: 'web_splash_identity_missing',
        message:
            'Web startup must package the owner-approved Siamblend splash artwork.',
      ),
    );
    return;
  }
  _requireAllSnippets(
    indexSource,
    const [
      'id="customer-bootstrap-splash"',
      'url("splash/siamblend_splash.jpg")',
      'customer-bootstrap-loader',
      'customer-bootstrap-loader-bar',
      'customer-bootstrap-loading',
      '"flutter-first-frame"',
      'splash.classList.add("is-leaving")',
      'splash.remove()',
    ],
    const ProductionPreflightIssue(
      code: 'web_splash_identity_missing',
      message:
          'Web must keep the matching Siamblend loading layer visible until Flutter renders its first frame.',
    ),
    issues,
  );
}

File? _findFirstFile(Directory root, String fileName) {
  if (!root.existsSync()) return null;
  for (final entity in root.listSync(recursive: true, followLinks: false)) {
    if (entity is File && entity.uri.pathSegments.last == fileName) {
      return entity;
    }
  }
  return null;
}

void _requireSnippet(
  String source,
  String snippet,
  ProductionPreflightIssue issue,
  List<ProductionPreflightIssue> issues,
) {
  if (!source.contains(snippet)) issues.add(issue);
}

bool _hasPlistStringValue(String source, String key, String value) {
  final pattern = RegExp(
    '<key>\\s*${RegExp.escape(key)}\\s*</key>\\s*'
    '<string>\\s*${RegExp.escape(value)}\\s*</string>',
    multiLine: true,
  );
  return pattern.hasMatch(source);
}

void _requireAllSnippets(
  String source,
  List<String> snippets,
  ProductionPreflightIssue issue,
  List<ProductionPreflightIssue> issues,
) {
  if (snippets.any((snippet) => !source.contains(snippet))) issues.add(issue);
}

void _requireOrderedSnippets(
  String source,
  List<String> snippets,
  ProductionPreflightIssue issue,
  List<ProductionPreflightIssue> issues,
) {
  var searchOffset = 0;
  for (final snippet in snippets) {
    final index = source.indexOf(snippet, searchOffset);
    if (index < 0) {
      issues.add(issue);
      return;
    }
    searchOffset = index + snippet.length;
  }
}

void _rejectSnippet(
  String source,
  String snippet,
  ProductionPreflightIssue issue,
  List<ProductionPreflightIssue> issues,
) {
  if (source.contains(snippet)) issues.add(issue);
}

Object? _readJsonFile(
  File file,
  ProductionPreflightIssue issue,
  List<ProductionPreflightIssue> issues,
) {
  try {
    return jsonDecode(file.readAsStringSync());
  } on FormatException {
    issues.add(issue);
  } on FileSystemException {
    issues.add(issue);
  }
  return null;
}

List<String> _stringListFromJson(Object? value) {
  if (value is! List) return const [];
  return value
      .map((entry) => entry?.toString().trim() ?? '')
      .where((entry) => entry.isNotEmpty)
      .toList();
}

bool _looksLikeSha256Fingerprint(String value) {
  return RegExp(r'^([0-9A-Fa-f]{2}:){31}[0-9A-Fa-f]{2}$').hasMatch(value);
}

const _supportedSocialProviders = {'line', 'google', 'apple', 'facebook'};

Set<String> _normalizedSocialProviders(Iterable<String> providers) {
  return providers
      .map(_normalizeSocialProvider)
      .where((provider) => provider.isNotEmpty)
      .where(_supportedSocialProviders.contains)
      .toSet();
}

String _normalizeSocialProvider(String provider) {
  return switch (provider.trim().toLowerCase()) {
    'gmail' || 'google_login' || 'google_oauth' || 'google_oauth2' => 'google',
    'apple_id' || 'apple_login' || 'sign_in_with_apple' => 'apple',
    'fb' ||
    'facebook_login' ||
    'facebook_oauth' ||
    'meta' ||
    'meta_login' =>
      'facebook',
    'line_login' || 'line_oa' || 'line_oauth' => 'line',
    final value => value,
  };
}

String _join(String first, String second) {
  if (first.isEmpty || first == '.') return second;
  final separator = Platform.pathSeparator;
  if (first.endsWith(separator)) return '$first$second';
  return '$first$separator$second';
}

bool _isAbsolutePath(String value) {
  return value.startsWith('/') || RegExp(r'^[A-Za-z]:[\\/]').hasMatch(value);
}

String _extensionOf(String path) {
  final name = path.split(Platform.pathSeparator).last;
  final index = name.lastIndexOf('.');
  if (index < 0) return '';
  return name.substring(index).toLowerCase();
}

int _lineNumberForOffset(String source, int offset) {
  var line = 1;
  for (var index = 0; index < offset && index < source.length; index++) {
    if (source.codeUnitAt(index) == 10) line++;
  }
  return line;
}

String _relativePath(String root, String path) {
  final rootPath = Directory(root).absolute.path;
  final filePath = File(path).absolute.path;
  final prefix = rootPath.endsWith(Platform.pathSeparator)
      ? rootPath
      : '$rootPath${Platform.pathSeparator}';
  if (filePath.startsWith(prefix)) return filePath.substring(prefix.length);
  return path;
}

bool _looksLikeApplicationId(String value) {
  return RegExp(
    r'^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z][a-zA-Z0-9_]*)+$',
  ).hasMatch(value);
}

bool _looksLikeScheme(String value) {
  if (value == 'http' || value == 'https') return false;
  return RegExp(r'^[a-z][a-z0-9+\-.]*$').hasMatch(value);
}

bool _isDefaultAndroidApplicationId(String value) {
  return value.trim().toLowerCase() == 'com.newpaotang.customer_flutter';
}

bool _isDefaultIosBundleId(String value) {
  final normalized = value.trim().toLowerCase();
  return normalized == 'com.newpaotang.customerflutter' ||
      normalized == 'com.newpaotang.customer_flutter';
}

bool _isDefaultCallbackScheme(String value) {
  return value.trim().toLowerCase() == 'newpaotang';
}

bool _isDefaultDisplayName(String value) {
  final normalized = value.trim().toLowerCase().replaceAll(
    RegExp(r'[\s_-]+'),
    '',
  );
  return normalized == 'customer' ||
      normalized == 'customerflutter' ||
      normalized == 'newpaotang';
}

bool _isDefaultWebDescription(String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized.isEmpty) return true;
  if (normalized == 'customer application.') return true;
  if (normalized == 'customer application') return true;
  if (normalized == 'a new flutter project.') return true;
  if (normalized == 'a new flutter project') return true;
  return _isDefaultDisplayName(normalized);
}

bool _looksLikeProductionHost(String value, bool production) {
  value = _hostOnly(value);
  if (value.isEmpty) return false;
  if (!production) return true;
  if (value == 'localhost' || value.endsWith('.localhost')) return false;
  if (value.startsWith('127.') || value == '0.0.0.0') return false;
  return value.contains('.');
}

bool _looksLikeHttpsProductionUrl(String value, bool production) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null || uri.scheme.toLowerCase() != 'https') return false;
  return _looksLikeProductionHost(uri.host, production);
}

String _hostOnly(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '';
  final uri = Uri.tryParse(trimmed);
  if (uri != null && uri.host.isNotEmpty) return uri.host;
  return trimmed.split('/').first.split(':').first;
}

bool _looksLikeAssociatedDomain(String value, bool production) {
  if (value.isEmpty) return false;
  if (!value.startsWith('applinks:')) return false;

  final host = value.substring('applinks:'.length).trim();
  return _looksLikeProductionHost(host, production);
}
