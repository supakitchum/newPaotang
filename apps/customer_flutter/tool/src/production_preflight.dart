import 'dart:io';

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
  _checkSocialProviderValues(input, issues);
  _checkSocialLoginStoreCompliance(input, issues);
  if (input.production && input.checkFiles) {
    _checkStoreAccountReadiness(input, issues);
    _checkForbiddenProductionSourceReferences(input, issues);
    _checkExternalLinkLaunchPolicy(input, issues);
    if (input.target.includesWeb) _checkWebRuntimeMetadata(input, issues);
  }
  if (input.checkFiles &&
      (input.target.includesAndroid || input.target.includesIos)) {
    _checkFlutterScreenSecurityBinding(input, issues);
  }
  if (input.target.includesAndroid) _checkAndroid(input, issues);
  if (input.target.includesIos) _checkIos(input, issues);

  return issues;
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
    const [
      '.events.listen',
      'screen_capture_ended',
      'lockForScreenSecurity',
    ],
    const ProductionPreflightIssue(
      code: 'flutter_screen_security_lock_binding_missing',
      message:
          'SensitiveScreenGuard must lock the app when native screenshot or recording events are received.',
    ),
    issues,
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

  final apiUri = Uri.tryParse(input.apiBaseUrl?.trim() ?? '');
  final apiHost = apiUri?.host.trim().toLowerCase() ?? '';

  if (apiHost.isEmpty) return;

  final callbackHosts = <String>{
    if (input.androidCallbackHost != null)
      _hostOnly(input.androidCallbackHost!).toLowerCase(),
    if (input.iosAssociatedDomain != null)
      _hostOnly(
        input.iosAssociatedDomain!
            .replaceFirst(RegExp(r'^applinks:', caseSensitive: false), ''),
      ).toLowerCase(),
  }..removeWhere((host) => host.isEmpty);

  if (callbackHosts.isEmpty || callbackHosts.contains(apiHost)) return;

  final tenantHost = _hostOnly(input.tenantHost ?? '');
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

  const supportedProviders = {'line', 'google', 'apple'};
  final invalidProviders = input.socialAuthProviders
      .map((provider) => provider.trim().toLowerCase())
      .where((provider) => provider.isNotEmpty)
      .where((provider) => !supportedProviders.contains(provider))
      .toSet()
      .toList()
    ..sort();
  if (invalidProviders.isEmpty) return;

  issues.add(
    ProductionPreflightIssue(
      code: 'social_provider_invalid',
      message:
          'Unsupported social provider(s): ${invalidProviders.join(', ')}. Supported providers are line, google, and apple.',
    ),
  );
}

void _checkSocialLoginStoreCompliance(
  ProductionPreflightInput input,
  List<ProductionPreflightIssue> issues,
) {
  if (!input.production || !input.target.includesIos) return;

  final providers = input.socialAuthProviders
      .map((provider) => provider.trim().toLowerCase())
      .where((provider) => provider.isNotEmpty)
      .toSet();
  if (providers.isEmpty) return;

  final usesThirdPartyLogin =
      providers.contains('line') || providers.contains('google');
  if (usesThirdPartyLogin && !providers.contains('apple')) {
    issues.add(
      const ProductionPreflightIssue(
        code: 'ios_sign_in_with_apple_required',
        message:
            'iOS production builds that enable LINE or Google login must also enable Apple ID login.',
      ),
    );
  }
}

void _checkStoreAccountReadiness(
  ProductionPreflightInput input,
  List<ProductionPreflightIssue> issues,
) {
  final providers = input.socialAuthProviders
      .map((provider) => provider.trim().toLowerCase())
      .where((provider) => provider.isNotEmpty)
      .toSet();
  if (providers.isEmpty) return;

  final requiredFiles = <String, List<String>>{
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
          'Production builds with social login must expose Privacy Policy and Account Deletion entry points. Missing: ${missing.join(', ')}',
    ),
  );
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
  if (input.production && value.isEmpty) {
    issues.add(
      const ProductionPreflightIssue(
        code: 'app_display_name_missing',
        message:
            'Production builds require CUSTOMER_FLUTTER_APP_DISPLAY_NAME or APP_DISPLAY_NAME.',
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
    'WindowManager.LayoutParams.FLAG_SECURE',
    const ProductionPreflightIssue(
      code: 'android_flag_secure_missing',
      message: 'Android MainActivity must enable FLAG_SECURE.',
    ),
    issues,
  );
  _requireAllSnippets(
    source,
    const ['override fun onCreate', 'window.setFlags'],
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
      'setUserAuthenticationRequired(true)',
      'setInvalidatedByBiometricEnrollment(true)',
      'packageName',
    ],
    const ProductionPreflightIssue(
      code: 'android_biometric_keyguard_missing',
      message:
          'Android biometric keys must be package-scoped, require user authentication, and be invalidated on enrollment changes.',
    ),
    issues,
  );
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
    ],
    const ProductionPreflightIssue(
      code: 'android_app_links_missing',
      message:
          'AndroidManifest.xml must declare verified HTTPS app links for auth and reset callbacks.',
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
  }

  _checkIosEntitlements(input, issues);
  _checkIosXcconfig(input, issues);
  _checkIosProjectConfig(input, issues);
  _checkIosReleaseConfigGuard(input, issues);

  final appDelegate =
      File(_join(input.projectRoot, 'ios/Runner/AppDelegate.swift'));
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
      'showPrivacyOverlay',
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
      'SecKeyCreateSignature',
      'Bundle.main.bundleIdentifier',
    ],
    const ProductionPreflightIssue(
      code: 'ios_biometric_keyguard_missing',
      message:
          'iOS biometric keys must be bundle-scoped, device-bound, biometric-bound, and able to sign challenges.',
    ),
    issues,
  );
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
    'loopback_ip': RegExp(
      r'\b(?:127\.\d{1,3}\.\d{1,3}\.\d{1,3}|0\.0\.0\.0)\b',
    ),
    'example_domain':
        RegExp(r'\b(?:[A-Za-z0-9-]+\.)?example\.com\b', caseSensitive: false),
  };

  for (final scanPath in scanPaths) {
    final rootPath = _join(input.projectRoot, scanPath);
    final rootEntity = FileSystemEntity.typeSync(rootPath);
    if (rootEntity == FileSystemEntityType.notFound) continue;

    final files = rootEntity == FileSystemEntityType.file
        ? <File>[File(rootPath)]
        : Directory(rootPath)
            .listSync(recursive: true, followLinks: false)
            .whereType<File>();

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

  const scaffoldValues = [
    'customer_flutter',
    'A new Flutter project.',
  ];
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
      'document.title',
      'meta[name="description"]',
      'meta[name="apple-mobile-web-app-title"]',
      'application/manifest+json',
    ],
    const ProductionPreflightIssue(
      code: 'web_runtime_metadata_config_missing',
      message:
          'web/index.html must support runtime partner metadata for title, description, PWA title, and manifest values.',
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

void _requireAllSnippets(
  String source,
  List<String> snippets,
  ProductionPreflightIssue issue,
  List<ProductionPreflightIssue> issues,
) {
  if (snippets.any((snippet) => !source.contains(snippet))) issues.add(issue);
}

String _join(String first, String second) {
  if (first.isEmpty || first == '.') return second;
  final separator = Platform.pathSeparator;
  if (first.endsWith(separator)) return '$first$second';
  return '$first$separator$second';
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
  return RegExp(r'^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z][a-zA-Z0-9_]*)+$')
      .hasMatch(value);
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

bool _looksLikeProductionHost(String value, bool production) {
  value = _hostOnly(value);
  if (value.isEmpty) return false;
  if (!production) return true;
  if (value == 'localhost' || value.endsWith('.localhost')) return false;
  if (value.startsWith('127.') || value == '0.0.0.0') return false;
  return value.contains('.');
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
