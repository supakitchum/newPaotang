import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/src/production_preflight.dart';

void main() {
  test('production preflight accepts complete native release inputs', () {
    final issues = runCustomerFlutterProductionPreflight(
      const ProductionPreflightInput(
        target: CustomerFlutterTarget.all,
        production: true,
        checkFiles: false,
        androidRequireSigning: true,
        apiBaseUrl: 'https://partner.example.com/api/v1',
        appDisplayName: 'Partner Lottery',
        androidPackage: 'com.partner.customer',
        androidCallbackScheme: 'partnerlottery',
        androidCallbackHost: 'partner.example.com',
        androidStoreFile: '/secure/release.jks',
        androidStorePassword: 'secret',
        androidKeyAlias: 'release',
        androidKeyPassword: 'secret',
        iosTeamId: 'ABCDE12345',
        iosBundleId: 'com.partner.customer',
        iosUrlScheme: 'partnerlottery',
        iosAssociatedDomain: 'applinks:partner.example.com',
        webShortName: 'Partner',
        webDescription: 'Partner digital lottery customer portal.',
      ),
    );

    expect(issues, isEmpty);
  });

  test('store release branding gate rejects a missing hash manifest', () {
    final root = Directory.systemTemp.createTempSync(
      'customer_flutter_release_branding_preflight_',
    );
    try {
      final issues = runCustomerFlutterProductionPreflight(
        ProductionPreflightInput(
          target: CustomerFlutterTarget.web,
          production: true,
          checkFiles: false,
          androidRequireSigning: false,
          projectRoot: root.path,
          apiBaseUrl: '/api/v1',
          appDisplayName: 'Partner Lottery',
          webShortName: 'Partner',
          webDescription: 'Partner digital lottery customer portal.',
          requireReleaseBranding: true,
        ),
      );

      expect(
        issues.map((issue) => issue.code),
        contains('release_branding_invalid'),
      );
    } finally {
      root.deleteSync(recursive: true);
    }
  });

  test('production preflight rejects default display names', () {
    final issues = runCustomerFlutterProductionPreflight(
      const ProductionPreflightInput(
        target: CustomerFlutterTarget.all,
        production: true,
        checkFiles: false,
        androidRequireSigning: false,
        apiBaseUrl: 'https://partner.example.com/api/v1',
        appDisplayName: 'Customer Flutter',
        androidPackage: 'com.partner.customer',
        androidCallbackScheme: 'partnerlottery',
        androidCallbackHost: 'partner.example.com',
        iosTeamId: 'ABCDE12345',
        iosBundleId: 'com.partner.customer',
        iosUrlScheme: 'partnerlottery',
        iosAssociatedDomain: 'applinks:partner.example.com',
      ),
    );

    expect(
      issues.map((issue) => issue.code),
      contains('app_display_name_not_partner_specific'),
    );
  });

  test('production preflight requires runtime customer theme binding', () {
    final root = Directory.systemTemp.createTempSync(
      'customer_flutter_identity_preflight_',
    );
    try {
      _writeFile(
        root,
        'lib/core/theme/app_theme.dart',
        File('lib/core/theme/app_theme.dart').readAsStringSync(),
      );
      final appSource = File(
        'lib/app/customer_app.dart',
      ).readAsStringSync().replaceFirst('useRuntimeBrandColors: true', '');
      _writeFile(root, 'lib/app/customer_app.dart', appSource);

      final issues = runCustomerFlutterProductionPreflight(
        ProductionPreflightInput(
          target: CustomerFlutterTarget.web,
          production: true,
          checkFiles: true,
          androidRequireSigning: false,
          projectRoot: root.path,
          apiBaseUrl: '/api/v1',
          appDisplayName: 'Partner Lottery',
          webAppName: 'Partner Lottery',
          webShortName: 'Partner',
          webDescription: 'Partner digital lottery customer portal.',
        ),
      );

      expect(
        issues.map((issue) => issue.code),
        contains('flutter_runtime_theme_binding_missing'),
      );
    } finally {
      root.deleteSync(recursive: true);
    }
  });

  test('store submission preflight can require listing metadata URLs', () {
    final missingIssues = runCustomerFlutterProductionPreflight(
      const ProductionPreflightInput(
        target: CustomerFlutterTarget.all,
        production: true,
        checkFiles: false,
        androidRequireSigning: false,
        apiBaseUrl: 'https://partner.example.com/api/v1',
        appDisplayName: 'Partner Lottery',
        androidPackage: 'com.partner.customer',
        androidCallbackScheme: 'partnerlottery',
        androidCallbackHost: 'partner.example.com',
        iosTeamId: 'ABCDE12345',
        iosBundleId: 'com.partner.customer',
        iosUrlScheme: 'partnerlottery',
        iosAssociatedDomain: 'applinks:partner.example.com',
        requireStoreListingMetadata: true,
      ),
    );

    expect(
      missingIssues.map((issue) => issue.code),
      containsAll({
        'store_privacy_policy_url_missing',
        'store_support_url_missing',
        'store_account_deletion_url_missing',
      }),
    );

    final invalidIssues = runCustomerFlutterProductionPreflight(
      const ProductionPreflightInput(
        target: CustomerFlutterTarget.ios,
        production: true,
        checkFiles: false,
        androidRequireSigning: false,
        apiBaseUrl: 'https://partner.example.com/api/v1',
        appDisplayName: 'Partner Lottery',
        iosTeamId: 'ABCDE12345',
        iosBundleId: 'com.partner.customer',
        iosUrlScheme: 'partnerlottery',
        iosAssociatedDomain: 'applinks:partner.example.com',
        requireStoreListingMetadata: true,
        storePrivacyPolicyUrl: '/privacy',
        storeSupportUrl: 'http://localhost/support',
        storeAccountDeletionUrl: 'https://localhost/delete-account',
      ),
    );

    expect(
      invalidIssues.map((issue) => issue.code),
      containsAll({
        'store_privacy_policy_url_invalid',
        'store_support_url_invalid',
        'store_account_deletion_url_invalid',
      }),
    );

    final validIssues = runCustomerFlutterProductionPreflight(
      const ProductionPreflightInput(
        target: CustomerFlutterTarget.all,
        production: true,
        checkFiles: false,
        androidRequireSigning: false,
        apiBaseUrl: 'https://partner.example.com/api/v1',
        appDisplayName: 'Partner Lottery',
        androidPackage: 'com.partner.customer',
        androidCallbackScheme: 'partnerlottery',
        androidCallbackHost: 'partner.example.com',
        iosTeamId: 'ABCDE12345',
        iosBundleId: 'com.partner.customer',
        iosUrlScheme: 'partnerlottery',
        iosAssociatedDomain: 'applinks:partner.example.com',
        requireStoreListingMetadata: true,
        storePrivacyPolicyUrl: 'https://partner.example.com/privacy',
        storeSupportUrl: 'https://partner.example.com/support',
        storeAccountDeletionUrl: 'https://partner.example.com/account-deletion',
        webShortName: 'Partner',
        webDescription: 'Partner digital lottery customer portal.',
      ),
    );

    expect(
      validIssues.map((issue) => issue.code),
      isNot(
        contains(
          anyOf(
            'store_privacy_policy_url_missing',
            'store_privacy_policy_url_invalid',
            'store_support_url_missing',
            'store_support_url_invalid',
            'store_account_deletion_url_missing',
            'store_account_deletion_url_invalid',
          ),
        ),
      ),
    );
  });

  test('production preflight validates checked-in native security files', () {
    final issues = runCustomerFlutterProductionPreflight(
      const ProductionPreflightInput(
        target: CustomerFlutterTarget.all,
        production: true,
        checkFiles: true,
        androidRequireSigning: false,
        apiBaseUrl: 'https://partner.example.com/api/v1',
        appDisplayName: 'Partner Lottery',
        androidPackage: 'com.partner.customer',
        androidCallbackScheme: 'partnerlottery',
        androidCallbackHost: 'partner.example.com',
        iosTeamId: 'ABCDE12345',
        iosBundleId: 'com.partner.customer',
        iosUrlScheme: 'partnerlottery',
        iosAssociatedDomain: 'applinks:partner.example.com',
        socialAuthProviders: ['line', 'google', 'apple'],
        webShortName: 'Partner',
        webDescription: 'Partner digital lottery customer portal.',
      ),
    );

    expect(issues, isEmpty);
  });

  test('production preflight validates deep-link association artifacts', () {
    final root = Directory.systemTemp.createTempSync('customer_flutter_links_');
    try {
      _writeFile(
        root,
        '.well-known/assetlinks.json',
        jsonEncode([
          {
            'relation': ['delegate_permission/common.handle_all_urls'],
            'target': {
              'namespace': 'android_app',
              'package_name': 'com.partner.customer',
              'sha256_cert_fingerprints': [_realSha256Fingerprint()],
            },
          },
        ]),
      );
      _writeFile(
        root,
        '.well-known/apple-app-site-association',
        jsonEncode({
          'applinks': {
            'apps': <String>[],
            'details': [
              {
                'appIDs': ['ABCDE12345.com.partner.customer'],
                'paths': [
                  '/line/callback',
                  '/social/*',
                  '/reset-password',
                  '/checkout/pending',
                ],
              },
            ],
          },
        }),
      );

      final issues = runCustomerFlutterProductionPreflight(
        ProductionPreflightInput(
          target: CustomerFlutterTarget.all,
          production: true,
          checkFiles: true,
          androidRequireSigning: false,
          apiBaseUrl: 'https://partner.example.com/api/v1',
          appDisplayName: 'Partner Lottery',
          androidPackage: 'com.partner.customer',
          androidCallbackScheme: 'partnerlottery',
          androidCallbackHost: 'partner.example.com',
          iosTeamId: 'ABCDE12345',
          iosBundleId: 'com.partner.customer',
          iosUrlScheme: 'partnerlottery',
          iosAssociatedDomain: 'applinks:partner.example.com',
          socialAuthProviders: const ['line', 'google', 'apple'],
          linkAssociationDir: root.path,
          webShortName: 'Partner',
          webDescription: 'Partner digital lottery customer portal.',
        ),
      );

      expect(issues, isEmpty);
    } finally {
      root.deleteSync(recursive: true);
    }
  });

  test('production preflight rejects missing deep-link association files', () {
    final root = Directory.systemTemp.createTempSync(
      'customer_flutter_links_missing_',
    );
    try {
      Directory('${root.path}/.well-known').createSync(recursive: true);

      final issues = runCustomerFlutterProductionPreflight(
        ProductionPreflightInput(
          target: CustomerFlutterTarget.all,
          production: true,
          checkFiles: true,
          androidRequireSigning: false,
          apiBaseUrl: 'https://partner.example.com/api/v1',
          appDisplayName: 'Partner Lottery',
          androidPackage: 'com.partner.customer',
          androidCallbackScheme: 'partnerlottery',
          androidCallbackHost: 'partner.example.com',
          iosTeamId: 'ABCDE12345',
          iosBundleId: 'com.partner.customer',
          iosUrlScheme: 'partnerlottery',
          iosAssociatedDomain: 'applinks:partner.example.com',
          socialAuthProviders: const ['line', 'google', 'apple'],
          linkAssociationDir: root.path,
        ),
      );

      expect(
        issues.map((issue) => issue.code),
        containsAll({'android_assetlinks_missing', 'ios_aasa_missing'}),
      );
    } finally {
      root.deleteSync(recursive: true);
    }
  });

  test(
    'production preflight requires privacy and account deletion surfaces',
    () {
      final root = Directory.systemTemp.createTempSync('customer_preflight_');
      try {
        final issues = runCustomerFlutterProductionPreflight(
          ProductionPreflightInput(
            target: CustomerFlutterTarget.web,
            production: true,
            checkFiles: true,
            androidRequireSigning: false,
            projectRoot: root.path,
            apiBaseUrl: '/api/v1',
            appDisplayName: 'Partner Lottery',
            socialAuthProviders: const ['line'],
          ),
        );

        expect(
          issues.map((issue) => issue.code),
          contains('store_account_readiness_missing'),
        );
      } finally {
        root.deleteSync(recursive: true);
      }
    },
  );

  test(
    'production preflight requires store account surfaces without social login',
    () {
      final root = Directory.systemTemp.createTempSync(
        'customer_preflight_store_required_',
      );
      try {
        final issues = runCustomerFlutterProductionPreflight(
          ProductionPreflightInput(
            target: CustomerFlutterTarget.web,
            production: true,
            checkFiles: true,
            androidRequireSigning: false,
            projectRoot: root.path,
            apiBaseUrl: '/api/v1',
            appDisplayName: 'Partner Lottery',
            webShortName: 'Partner',
            webDescription: 'Partner digital lottery customer portal.',
          ),
        );

        expect(
          issues.map((issue) => issue.code),
          contains('store_account_readiness_missing'),
        );
      } finally {
        root.deleteSync(recursive: true);
      }
    },
  );

  test('production preflight requires runtime legal config binding', () {
    final root = Directory.systemTemp.createTempSync(
      'customer_preflight_legal_runtime_',
    );
    try {
      _writeFile(root, 'lib/app/customer_routes.dart', '''
const routes = [
  (path: '/privacy'),
  (path: '/profile/account-deletion'),
];
''');
      _writeFile(root, 'lib/app/router.dart', '''
final routes = [
  GoRoute(path: '/privacy', builder: PrivacyPolicyScreen.new),
  GoRoute(path: '/profile/account-deletion', builder: AccountDeletionScreen.new),
];
''');
      _writeFile(
        root,
        'lib/features/profile/presentation/profile_screen.dart',
        '''
final menu = [
  _ProfileMenuItem(path: '/privacy'),
  _ProfileMenuItem(path: '/profile/account-deletion'),
];
''',
      );

      final issues = runCustomerFlutterProductionPreflight(
        ProductionPreflightInput(
          target: CustomerFlutterTarget.web,
          production: true,
          checkFiles: true,
          androidRequireSigning: false,
          projectRoot: root.path,
          apiBaseUrl: '/api/v1',
          appDisplayName: 'Partner Lottery',
          webShortName: 'Partner',
          webDescription: 'Partner digital lottery customer portal.',
        ),
      );

      final issue = issues.singleWhere(
        (issue) => issue.code == 'store_account_readiness_missing',
      );
      expect(
        issue.message,
        contains('lib/core/tenant/mobile_bootstrap_controller.dart'),
      );
      expect(
        issue.message,
        contains('lib/features/content/presentation/info_pages.dart'),
      );
      expect(
        issue.message,
        contains(
          'lib/features/profile/presentation/account_deletion_screen.dart',
        ),
      );
    } finally {
      root.deleteSync(recursive: true);
    }
  });

  test(
    'ios release guard script rejects missing or default release settings',
    () async {
      final script = 'ios/scripts/validate_release_config.sh';

      final debug = await Process.run(
        'sh',
        [script],
        environment: {'CONFIGURATION': 'Debug'},
      );
      expect(debug.exitCode, 0);

      final bad = await Process.run(
        'sh',
        [script],
        environment: {
          'CONFIGURATION': 'Release',
          'APP_DISPLAY_NAME': 'NewPaotang',
          'CUSTOMER_FLUTTER_URL_SCHEME': 'newpaotang',
          'CUSTOMER_FLUTTER_ASSOCIATED_DOMAIN': 'applinks:localhost',
          'PRODUCT_BUNDLE_IDENTIFIER': 'com.newpaotang.customerFlutter',
          'DEVELOPMENT_TEAM': 'ABCDE12345',
        },
      );
      expect(bad.exitCode, isNot(0));
      expect(bad.stderr.toString(), contains('APP_DISPLAY_NAME'));
      expect(bad.stderr.toString(), contains('CUSTOMER_FLUTTER_URL_SCHEME'));
      expect(bad.stderr.toString(), contains('production domain'));
      expect(bad.stderr.toString(), contains('partner-specific'));

      final good = await Process.run(
        'sh',
        [script],
        environment: {
          'CONFIGURATION': 'Release',
          'APP_DISPLAY_NAME': 'Partner Lottery',
          'CUSTOMER_FLUTTER_URL_SCHEME': 'partnerlottery',
          'CUSTOMER_FLUTTER_ASSOCIATED_DOMAIN': 'applinks:partner.example.com',
          'PRODUCT_BUNDLE_IDENTIFIER': 'com.partner.customer',
          'DEVELOPMENT_TEAM': 'ABCDE12345',
        },
      );
      expect(good.exitCode, 0);
    },
  );

  test('production preflight rejects missing native security hooks', () {
    final root = Directory.systemTemp.createTempSync(
      'customer_flutter_preflight_',
    );
    try {
      _writeFile(
        root,
        'android/app/src/main/kotlin/com/example/MainActivity.kt',
        'class MainActivity',
      );
      _writeFile(root, 'ios/Runner/Info.plist', '<plist><dict></dict></plist>');
      _writeFile(root, 'ios/Runner/AppDelegate.swift', 'class AppDelegate');

      final issues = runCustomerFlutterProductionPreflight(
        ProductionPreflightInput(
          target: CustomerFlutterTarget.all,
          production: true,
          checkFiles: true,
          androidRequireSigning: false,
          projectRoot: root.path,
          apiBaseUrl: 'https://partner.example.com/api/v1',
          appDisplayName: 'Partner Lottery',
          androidPackage: 'com.partner.customer',
          androidCallbackScheme: 'partnerlottery',
          androidCallbackHost: 'partner.example.com',
          iosTeamId: 'ABCDE12345',
          iosBundleId: 'com.partner.customer',
          iosUrlScheme: 'partnerlottery',
          iosAssociatedDomain: 'applinks:partner.example.com',
        ),
      );

      expect(
        issues.map((issue) => issue.code),
        containsAll({
          'android_manifest_missing',
          'android_gradle_config_missing',
          'android_flag_secure_missing',
          'android_startup_flag_secure_missing',
          'android_screen_security_channel_missing',
          'android_recent_app_preview_guard_missing',
          'android_biometric_channel_missing',
          'flutter_screen_security_service_missing',
          'flutter_sensitive_screen_guard_missing',
          'flutter_biometric_service_missing',
          'ios_face_id_usage_missing',
          'ios_face_id_localization_missing',
          'ios_privacy_manifest_missing',
          'ios_xcconfig_missing',
          'ios_release_config_guard_missing',
          'ios_screen_capture_detection_missing',
          'ios_sensitive_snapshot_overlay_missing',
          'ios_exit_app_policy_missing',
          'ios_screen_security_aliases_missing',
          'ios_biometric_channel_missing',
        }),
      );
    } finally {
      root.deleteSync(recursive: true);
    }
  });

  test('production preflight rejects missing Flutter biometric safeguards', () {
    final root = Directory.systemTemp.createTempSync(
      'customer_flutter_preflight_flutter_biometric_',
    );
    try {
      _writeFile(root, 'lib/core/security/biometric_auth_service.dart', '''
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class BiometricAuthService {
  static const _keyChannel = MethodChannel('customer_flutter/biometric_keys');
  final _localAuth = LocalAuthentication();

  Future<bool> canUseBiometric() {
    return _localAuth.canCheckBiometrics;
  }

  Future<String?> requestPinAssertion() async {
    final deviceId = await _keyChannel.invokeMethod<String>('deviceId');
    if (deviceId == null) return null;
    final signature = await _keyChannel.invokeMethod<String>('signChallenge');
    return signature;
  }
}
''');

      final issues = runCustomerFlutterProductionPreflight(
        ProductionPreflightInput(
          target: CustomerFlutterTarget.ios,
          production: true,
          checkFiles: true,
          androidRequireSigning: false,
          projectRoot: root.path,
          apiBaseUrl: 'https://partner.example.com/api/v1',
          appDisplayName: 'Partner Lottery',
          iosTeamId: 'ABCDE12345',
          iosBundleId: 'com.partner.customer',
          iosUrlScheme: 'partnerlottery',
          iosAssociatedDomain: 'applinks:partner.example.com',
        ),
      );

      expect(
        issues.map((issue) => issue.code),
        containsAll({
          'flutter_biometric_channel_binding_missing',
          'flutter_biometric_key_bound_prompt_missing',
          'flutter_biometric_lifecycle_coordination_missing',
          'flutter_biometric_soft_fallback_missing',
          'flutter_biometric_local_key_cleanup_missing',
          'flutter_biometric_alias_parsing_missing',
          'flutter_biometric_device_parser_alias_missing',
          'flutter_biometric_runtime_prompt_copy_missing',
        }),
      );
    } finally {
      root.deleteSync(recursive: true);
    }
  });

  test(
    'production preflight rejects missing Flutter social callback wrapper parsing',
    () {
      final root = Directory.systemTemp.createTempSync(
        'customer_flutter_preflight_social_callback_',
      );
      try {
        _writeFile(root, 'lib/core/auth/auth_repository.dart', '''
class AuthRepository {
  Future<void> socialCallback({
    required Map<String, dynamic> query,
  }) async {
    final normalizedQuery = Map<String, dynamic>.from(query);
    await Future<void>.value(normalizedQuery);
  }
}
''');
        _writeFile(
          root,
          'lib/features/auth/presentation/line_auth_screens.dart',
          '''
Map<String, String> normalizedSocialCallbackQuery(
  Map<String, String> query,
) {
  return Map<String, String>.from(query);
}
''',
        );

        final issues = runCustomerFlutterProductionPreflight(
          ProductionPreflightInput(
            target: CustomerFlutterTarget.web,
            production: true,
            checkFiles: true,
            androidRequireSigning: false,
            projectRoot: root.path,
            apiBaseUrl: 'https://partner.example.com/api/v1',
            appDisplayName: 'Partner Lottery',
            webShortName: 'Partner',
            webDescription: 'Partner digital lottery customer portal.',
          ),
        );

        expect(
          issues.map((issue) => issue.code),
          contains('flutter_social_callback_wrapper_binding_missing'),
        );
      } finally {
        root.deleteSync(recursive: true);
      }
    },
  );

  test(
    'production preflight rejects missing social callback fragment route binding',
    () {
      final root = Directory.systemTemp.createTempSync(
        'customer_flutter_preflight_social_fragment_',
      );
      try {
        _writeFile(root, 'lib/core/navigation/customer_deep_link.dart', '''
Map<String, String> customerAuthRouteParameters(Uri uri) {
  return uri.queryParameters;
}
''');
        _writeFile(root, 'lib/app/router.dart', '''
Map<String, String> callbackParameters(Uri uri) {
  return uri.queryParameters;
}
''');

        final issues = runCustomerFlutterProductionPreflight(
          ProductionPreflightInput(
            target: CustomerFlutterTarget.web,
            production: true,
            checkFiles: true,
            androidRequireSigning: false,
            projectRoot: root.path,
            apiBaseUrl: 'https://partner.example.com/api/v1',
            appDisplayName: 'Partner Lottery',
            webShortName: 'Partner',
            webDescription: 'Partner digital lottery customer portal.',
          ),
        );

        expect(
          issues.map((issue) => issue.code),
          contains('flutter_social_callback_fragment_route_binding_missing'),
        );
      } finally {
        root.deleteSync(recursive: true);
      }
    },
  );

  test('production preflight requires auth OTP reset/register aliases', () {
    final root = Directory.systemTemp.createTempSync(
      'customer_flutter_preflight_auth_otp_',
    );
    try {
      _writeFile(root, 'lib/core/auth/auth_repository.dart', '''
class OtpRequestResult {}
class OtpVerifyResult {}
''');

      final issues = runCustomerFlutterProductionPreflight(
        ProductionPreflightInput(
          target: CustomerFlutterTarget.web,
          production: true,
          checkFiles: true,
          androidRequireSigning: false,
          projectRoot: root.path,
          apiBaseUrl: 'https://partner.example.com/api/v1',
          appDisplayName: 'Partner Lottery',
          webShortName: 'Partner',
          webDescription: 'Partner digital lottery customer portal.',
        ),
      );

      expect(
        issues.map((issue) => issue.code),
        contains('flutter_auth_otp_parser_binding_missing'),
      );
    } finally {
      root.deleteSync(recursive: true);
    }
  });

  test('production preflight requires tenant-scoped auth storage wiring', () {
    final root = Directory.systemTemp.createTempSync(
      'customer_flutter_preflight_tenant_auth_storage_',
    );
    try {
      _writeFile(
        root,
        'lib/main.dart',
        'final authTokenStore = AuthTokenStore();',
      );
      _writeFile(root, 'lib/core/auth/auth_token_store.dart', '''
class AuthTokenStore {
  final accessKey = 'customer_access_token';
}
''');
      _writeFile(
        root,
        'lib/core/tenant/customer_tenant_host.dart',
        'String normalizeCustomerTenantHost(String value) => value;',
      );

      final issues = runCustomerFlutterProductionPreflight(
        ProductionPreflightInput(
          target: CustomerFlutterTarget.web,
          production: true,
          checkFiles: true,
          androidRequireSigning: false,
          projectRoot: root.path,
          apiBaseUrl: 'https://partner.example.com/api/v1',
          appDisplayName: 'Partner Lottery',
          webShortName: 'Partner',
          webDescription: 'Partner digital lottery customer portal.',
        ),
      );

      expect(
        issues.map((issue) => issue.code),
        contains('flutter_tenant_scoped_auth_storage_missing'),
      );
    } finally {
      root.deleteSync(recursive: true);
    }
  });

  test(
    'production preflight requires runtime social provider color binding',
    () {
      final root = Directory.systemTemp.createTempSync(
        'customer_flutter_preflight_social_colors_',
      );
      try {
        _writeFile(root, 'lib/core/tenant/mobile_bootstrap_controller.dart', '''
class SocialAuthProvider {
  const SocialAuthProvider({required this.provider});
  final String provider;
}
''');
        _writeFile(root, 'lib/features/auth/presentation/login_screen.dart', '''
const lineGreen = Color(0xFF06C755);
''');
        _writeFile(
          root,
          'lib/features/auth/presentation/forgot_password_screen.dart',
          '''
final buttonColor = Color(0xFF00C300);
''',
        );
        _writeFile(
          root,
          'lib/features/auth/presentation/line_auth_screens.dart',
          '''
Color providerColor(String provider) => const Color(0xFF4285F4);
''',
        );
        _writeFile(
          root,
          'lib/features/profile/presentation/line_notifications_screen.dart',
          '''
final accent = Color(0xFF06C755);
''',
        );

        final issues = runCustomerFlutterProductionPreflight(
          ProductionPreflightInput(
            target: CustomerFlutterTarget.web,
            production: true,
            checkFiles: true,
            androidRequireSigning: false,
            projectRoot: root.path,
            apiBaseUrl: 'https://partner.example.com/api/v1',
            appDisplayName: 'Partner Lottery',
            webShortName: 'Partner',
            webDescription: 'Partner digital lottery customer portal.',
          ),
        );

        expect(
          issues.map((issue) => issue.code),
          contains('flutter_social_provider_runtime_color_binding_missing'),
        );
      } finally {
        root.deleteSync(recursive: true);
      }
    },
  );

  test('production preflight requires realtime bridge/outbox aliases', () {
    final root = Directory.systemTemp.createTempSync(
      'customer_flutter_preflight_realtime_',
    );
    try {
      _writeFile(root, 'lib/core/realtime/customer_realtime_protocol.dart', '''
Map<String, dynamic> normalizeRealtimePayload(Map<String, dynamic> payload) {
  return payload;
}

String normalizeRealtimeEventNameWithPayload({
  required String eventName,
  required Map<String, dynamic> payload,
}) {
  return eventName;
}

const _realtimePayloadWrapperKeys = ['data', 'payload'];
''');
      _writeFile(
        root,
        'lib/features/topup/presentation/topup_realtime_monitor.dart',
        '''
bool shouldRefreshTopupsFromRealtimeEvent(event) {
  return event.name == 'topup.updated';
}
''',
      );

      final issues = runCustomerFlutterProductionPreflight(
        ProductionPreflightInput(
          target: CustomerFlutterTarget.web,
          production: true,
          checkFiles: true,
          androidRequireSigning: false,
          projectRoot: root.path,
          apiBaseUrl: 'https://partner.example.com/api/v1',
          appDisplayName: 'Partner Lottery',
          webShortName: 'Partner',
          webDescription: 'Partner digital lottery customer portal.',
        ),
      );

      expect(
        issues.map((issue) => issue.code),
        containsAll({
          'flutter_realtime_protocol_alias_binding_missing',
          'flutter_realtime_monitor_binding_missing',
        }),
      );
    } finally {
      root.deleteSync(recursive: true);
    }
  });

  test(
    'production preflight requires realtime object-scalar event aliases',
    () {
      final root = Directory.systemTemp.createTempSync(
        'customer_flutter_preflight_realtime_scalar_',
      );
      try {
        _writeFile(
          root,
          'lib/core/realtime/customer_realtime_protocol.dart',
          '''
Map<String, dynamic> normalizeRealtimePayload(Map<String, dynamic> payload) {
  return payload;
}

String normalizeRealtimeEventNameWithPayload({
  required String eventName,
  required Map<String, dynamic> payload,
}) {
  return eventName;
}

const _directRealtimeEventNameKeys = [
  'event_type',
  'eventName',
  'eventClass',
  'event_class_name',
  'event_fqcn',
];
const _providerRealtimeEventNameKeys = [
  'event',
  'action',
  'className',
  'notificationType',
];
const _realtimePayloadWrapperKeys = [
  'data',
  'payload',
  'payload_json',
  'event_data',
  'resource_data',
  'metadata',
  'context',
  'details',
  'object',
  'attributes',
];
const _isCanonicalRealtimeEvent = true;
''',
        );

        final issues = runCustomerFlutterProductionPreflight(
          ProductionPreflightInput(
            target: CustomerFlutterTarget.web,
            production: true,
            checkFiles: true,
            androidRequireSigning: false,
            projectRoot: root.path,
            apiBaseUrl: 'https://partner.example.com/api/v1',
            appDisplayName: 'Partner Lottery',
            webShortName: 'Partner',
            webDescription: 'Partner digital lottery customer portal.',
          ),
        );

        expect(
          issues.map((issue) => issue.code),
          contains('flutter_realtime_protocol_alias_binding_missing'),
        );
      } finally {
        root.deleteSync(recursive: true);
      }
    },
  );

  test('production preflight requires realtime socket URL normalization', () {
    final root = Directory.systemTemp.createTempSync(
      'customer_flutter_preflight_realtime_socket_',
    );
    try {
      _writeFile(root, 'lib/core/realtime/customer_realtime_protocol.dart', r'''
Uri buildRealtimeSocketUri({
  required String baseUrl,
  required String key,
}) {
  final encodedKey = Uri.encodeComponent(key);
  return Uri.parse('$baseUrl/app/$encodedKey');
}

Map<String, dynamic> normalizeRealtimePayload(Map<String, dynamic> payload) {
  return payload;
}

String normalizeRealtimeEventNameWithPayload({
  required String eventName,
  required Map<String, dynamic> payload,
}) {
  return eventName;
}

const _directRealtimeEventNameKeys = [
  'event_type',
  'eventName',
  'eventClass',
  'event_class_name',
  'event_fqcn',
];
const _providerRealtimeEventNameKeys = [
  'event',
  'action',
  'className',
  'notificationType',
];
const _realtimePayloadWrapperKeys = [
  'data',
  'payload',
  'payload_json',
  'event_data',
  'resource_data',
  'metadata',
  'context',
  'details',
  'object',
  'attributes',
];
String _realtimeEventScalarText(Object? value) => '';
const _realtimeScalarWrapperKeys = ['value', 'code', 'key'];
bool _isCanonicalRealtimeEvent(String eventName) => false;
''');

      final issues = runCustomerFlutterProductionPreflight(
        ProductionPreflightInput(
          target: CustomerFlutterTarget.web,
          production: true,
          checkFiles: true,
          androidRequireSigning: false,
          projectRoot: root.path,
          apiBaseUrl: 'https://partner.example.com/api/v1',
          appDisplayName: 'Partner Lottery',
          webShortName: 'Partner',
          webDescription: 'Partner digital lottery customer portal.',
        ),
      );

      expect(
        issues.map((issue) => issue.code),
        contains('flutter_realtime_socket_url_normalization_missing'),
      );
    } finally {
      root.deleteSync(recursive: true);
    }
  });

  test(
    'production preflight rejects Android security reports without callback',
    () {
      final root = Directory.systemTemp.createTempSync(
        'customer_flutter_preflight_android_security_',
      );
      try {
        _writeFile(root, 'android/app/src/main/AndroidManifest.xml', r'''
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
  <uses-permission android:name="android.permission.USE_BIOMETRIC"/>
  <application android:label="${appLabel}">
    <activity android:name=".MainActivity" android:exported="true">
      <intent-filter>
        <data android:scheme="${authCallbackScheme}"/>
      </intent-filter>
      <intent-filter android:autoVerify="true">
        <data android:scheme="https" android:host="${authCallbackHost}" android:pathPrefix="/line/callback"/>
        <data android:scheme="https" android:host="${authCallbackHost}" android:pathPrefix="/social"/>
        <data android:scheme="https" android:host="${authCallbackHost}" android:pathPrefix="/reset-password"/>
        <data android:scheme="https" android:host="${authCallbackHost}" android:pathPrefix="/checkout/pending"/>
      </intent-filter>
    </activity>
  </application>
</manifest>
''');
        _writeFile(root, 'android/app/build.gradle.kts', '''
val appId = providers.gradleProperty("CUSTOMER_FLUTTER_APPLICATION_ID")
val appLabel = providers.gradleProperty("CUSTOMER_FLUTTER_APP_LABEL")
val scheme = providers.gradleProperty("CUSTOMER_FLUTTER_AUTH_CALLBACK_SCHEME")
val host = providers.gradleProperty("CUSTOMER_FLUTTER_AUTH_CALLBACK_HOST")
android {
  defaultConfig {
    applicationId = appId.get()
    manifestPlaceholders["appLabel"] = appLabel.get()
    manifestPlaceholders["authCallbackScheme"] = scheme.get()
    manifestPlaceholders["authCallbackHost"] = host.get()
  }
}
''');
        _writeFile(
          root,
          'android/app/src/main/kotlin/com/example/MainActivity.kt',
          '''
class MainActivity {
  val flag = "WindowManager.LayoutParams.FLAG_SECURE"
  fun marker() = "override fun onCreate"
  fun startup() = "window.setFlags"
  val screen = "customer_flutter/screen_security"
  val enable = "enable"
  val disable = "disable"
  val report = "reportSecurityEvent"
  val recentsPolicy = "protect_recent_app_preview"
  val recentsApi = "setRecentsScreenshotEnabled"
  val biometric = "customer_flutter/biometric_keys"
  val store = "AndroidKeyStore"
  val existingId = "existingDeviceId"
  val deleteMethod = "deleteKeyPair"
  val deleteStoreKey = "deleteEntry"
  val keyExists = "hasExistingKeyPair"
  val staleDeviceCleanup = "remove(deviceIdKey)"
  val keyAliases = "credentialId rawId keyAlgorithm"
  val signaturePayload = "signatureBase64 signatureDer signedPayload"
  val auth = "setUserAuthenticationRequired(true)"
  val strongAuth = "AUTH_BIOMETRIC_STRONG"
  val invalidated = "setInvalidatedByBiometricEnrollment(true)"
  val runtimeNamespace = "packageName"
  val boolAliases = "enabled active allowed supported disabled blocked unsupported not_allowed"
}
''',
        );

        final issues = runCustomerFlutterProductionPreflight(
          ProductionPreflightInput(
            target: CustomerFlutterTarget.android,
            production: true,
            checkFiles: true,
            androidRequireSigning: false,
            projectRoot: root.path,
            apiBaseUrl: 'https://partner.example.com/api/v1',
            appDisplayName: 'Partner Lottery',
            androidPackage: 'com.partner.customer',
            androidCallbackScheme: 'partnerlottery',
            androidCallbackHost: 'partner.example.com',
          ),
        );

        expect(
          issues.map((issue) => issue.code),
          contains('android_screen_security_event_callback_missing'),
        );
      } finally {
        root.deleteSync(recursive: true);
      }
    },
  );

  test('production preflight rejects missing Flutter security audit hooks', () {
    final root = Directory.systemTemp.createTempSync(
      'customer_flutter_preflight_audit_',
    );
    try {
      _writeFile(root, 'lib/core/security/screen_security_service.dart', '''
import 'dart:async';
import 'package:flutter/services.dart';

class ScreenSecurityEvent {
  const ScreenSecurityEvent({required this.event});
  final String event;
}

class ScreenSecurityService {
  ScreenSecurityService() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'securityEvent') {}
    });
  }

  final _channel = const MethodChannel('customer_flutter/screen_security');
  final _events = StreamController<ScreenSecurityEvent>.broadcast();
  Stream<ScreenSecurityEvent> get events => _events.stream;
}
''');
      _writeFile(root, 'lib/shared/widgets/sensitive_screen_guard.dart', '''
class SensitiveScreenGuard {
  void bind(ScreenSecurityService service, AuthController auth) {
    service.events.listen((event) {
      if (event.event == 'screen_capture_ended') return;
      auth.lockForScreenSecurity();
    });
  }
}
''');

      final issues = runCustomerFlutterProductionPreflight(
        ProductionPreflightInput(
          target: CustomerFlutterTarget.android,
          production: true,
          checkFiles: true,
          androidRequireSigning: false,
          projectRoot: root.path,
          apiBaseUrl: 'https://partner.example.com/api/v1',
          appDisplayName: 'Partner Lottery',
          androidPackage: 'com.partner.customer',
          androidCallbackScheme: 'partnerlottery',
          androidCallbackHost: 'partner.example.com',
        ),
      );

      expect(
        issues.map((issue) => issue.code),
        containsAll({
          'flutter_screen_security_audit_missing',
          'flutter_screen_security_audit_binding_missing',
          'flutter_screen_security_runtime_overlay_copy_missing',
        }),
      );
    } finally {
      root.deleteSync(recursive: true);
    }
  });

  test(
    'production preflight requires normalized screen-security audit routes',
    () {
      final root = Directory.systemTemp.createTempSync(
        'customer_flutter_preflight_audit_route_',
      );
      try {
        _writeFile(root, 'lib/core/security/screen_security_service.dart', '''
import 'dart:async';
import 'package:flutter/services.dart';

final screenSecurityAuditServiceProvider = Object();

abstract class ScreenSecurityAuditService {}

class ScreenSecurityEvent {
  const ScreenSecurityEvent({required this.event, required this.route});
  final String event;
  final String route;
}

class ApiScreenSecurityAuditService extends ScreenSecurityAuditService {
  final endpoint = '/customer/auth/security-events';
}

class ScreenSecurityService {
  ScreenSecurityService() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'securityEvent') {}
    });
  }

  final _channel = const MethodChannel('customer_flutter/screen_security');
  final _events = StreamController<ScreenSecurityEvent>.broadcast();
  Stream<ScreenSecurityEvent> get events => _events.stream;
}
''');
        _writeFile(root, 'lib/shared/widgets/sensitive_screen_guard.dart', '''
class SensitiveScreenGuard {
  void bind(ScreenSecurityService service, AuthController auth) {
    service.events.listen((event) {
      if (event.event == 'screen_capture_ended') return;
      screenSecurityAuditServiceProvider.record(event: event, route: event.route);
      auth.lockForScreenSecurity();
    });
  }
}
''');

        final issues = runCustomerFlutterProductionPreflight(
          ProductionPreflightInput(
            target: CustomerFlutterTarget.android,
            production: true,
            checkFiles: true,
            androidRequireSigning: false,
            projectRoot: root.path,
            apiBaseUrl: 'https://partner.example.com/api/v1',
            appDisplayName: 'Partner Lottery',
            androidPackage: 'com.partner.customer',
            androidCallbackScheme: 'partnerlottery',
            androidCallbackHost: 'partner.example.com',
          ),
        );

        expect(
          issues.map((issue) => issue.code),
          containsAll({
            'flutter_route_registry_missing',
            'flutter_screen_security_audit_binding_missing',
            'flutter_screen_security_fragment_route_normalization_missing',
            'flutter_screen_security_route_object_normalization_missing',
          }),
        );
      } finally {
        root.deleteSync(recursive: true);
      }
    },
  );

  test(
    'production preflight rejects missing Android runtime manifest config',
    () {
      final root = Directory.systemTemp.createTempSync(
        'customer_flutter_preflight_android_',
      );
      try {
        _writeFile(root, 'android/app/src/main/AndroidManifest.xml', '''
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
  <uses-permission android:name="android.permission.INTERNET"/>
  <application android:label="Hardcoded">
    <activity android:name=".MainActivity"/>
  </application>
</manifest>
''');
        _writeFile(
          root,
          'android/app/build.gradle.kts',
          'android { defaultConfig { applicationId = "com.example.app" } }',
        );
        _writeFile(
          root,
          'android/app/src/main/kotlin/com/example/MainActivity.kt',
          '''
class MainActivity {
  val flag = "WindowManager.LayoutParams.FLAG_SECURE"
  fun marker() = "override fun onCreate"
  fun startup() = "window.setFlags"
  val screen = "customer_flutter/screen_security"
  val enable = "enable"
  val disable = "disable"
  val report = "reportSecurityEvent"
  val recentsPolicy = "protect_recent_app_preview"
  val recentsApi = "setRecentsScreenshotEnabled"
  val biometric = "customer_flutter/biometric_keys"
  val store = "AndroidKeyStore"
  val existingId = "existingDeviceId"
  val deleteMethod = "deleteKeyPair"
  val deleteStoreKey = "deleteEntry"
  val keyExists = "hasExistingKeyPair"
  val staleDeviceCleanup = "remove(deviceIdKey)"
  val keyAliases = "credentialId rawId keyAlgorithm"
  val signaturePayload = "signatureBase64 signatureDer signedPayload"
  val auth = "setUserAuthenticationRequired(true)"
  val strongAuth = "AUTH_BIOMETRIC_STRONG"
  val invalidated = "setInvalidatedByBiometricEnrollment(true)"
  val runtimeNamespace = "packageName"
  val boolAliases = "enabled active allowed supported disabled blocked unsupported not_allowed"
}
''',
        );

        final issues = runCustomerFlutterProductionPreflight(
          ProductionPreflightInput(
            target: CustomerFlutterTarget.android,
            production: true,
            checkFiles: true,
            androidRequireSigning: false,
            projectRoot: root.path,
            apiBaseUrl: 'https://partner.example.com/api/v1',
            appDisplayName: 'Partner Lottery',
            androidPackage: 'com.partner.customer',
            androidCallbackScheme: 'partnerlottery',
            androidCallbackHost: 'partner.example.com',
          ),
        );

        expect(
          issues.map((issue) => issue.code),
          containsAll({
            'android_biometric_permission_missing',
            'android_screen_capture_permission_missing',
            'android_custom_scheme_callback_missing',
            'android_app_links_missing',
            'android_runtime_config_missing',
            'android_biometric_fragment_activity_missing',
            'android_biometric_appcompat_theme_missing',
          }),
        );
      } finally {
        root.deleteSync(recursive: true);
      }
    },
  );

  test('production preflight rejects missing native push release wiring', () {
    final root = Directory.systemTemp.createTempSync(
      'customer_flutter_preflight_native_push_',
    );
    try {
      final issues = runCustomerFlutterProductionPreflight(
        ProductionPreflightInput(
          target: CustomerFlutterTarget.all,
          production: true,
          checkFiles: true,
          androidRequireSigning: false,
          projectRoot: root.path,
          apiBaseUrl: 'https://partner.example.com/api/v1',
          appDisplayName: 'Partner Lottery',
          androidPackage: 'com.partner.customer',
          androidCallbackScheme: 'partnerlottery',
          androidCallbackHost: 'partner.example.com',
          iosTeamId: 'ABCDE12345',
          iosBundleId: 'com.partner.customer',
          iosUrlScheme: 'partnerlottery',
          iosAssociatedDomain: 'applinks:partner.example.com',
        ),
      );

      expect(
        issues.map((issue) => issue.code),
        containsAll({
          'flutter_native_push_binding_missing',
          'android_native_push_config_missing',
          'ios_native_push_config_missing',
        }),
      );
    } finally {
      root.deleteSync(recursive: true);
    }
  });

  test('production preflight rejects Android backup-enabled manifests', () {
    final root = Directory.systemTemp.createTempSync(
      'customer_flutter_preflight_android_backup_',
    );
    try {
      _writeFile(root, 'android/app/src/main/AndroidManifest.xml', r'''
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
  <uses-permission android:name="android.permission.USE_BIOMETRIC"/>
  <application android:label="${appLabel}">
    <activity android:name=".MainActivity" android:exported="true">
      <intent-filter>
        <data android:scheme="${authCallbackScheme}"/>
      </intent-filter>
      <intent-filter android:autoVerify="true">
        <data android:scheme="https" android:host="${authCallbackHost}" android:pathPrefix="/line/callback"/>
        <data android:scheme="https" android:host="${authCallbackHost}" android:pathPrefix="/social"/>
        <data android:scheme="https" android:host="${authCallbackHost}" android:pathPrefix="/reset-password"/>
        <data android:scheme="https" android:host="${authCallbackHost}" android:pathPrefix="/checkout/pending"/>
      </intent-filter>
    </activity>
  </application>
</manifest>
''');
      _writeFile(root, 'android/app/build.gradle.kts', '''
val appId = providers.gradleProperty("CUSTOMER_FLUTTER_APPLICATION_ID")
val appLabel = providers.gradleProperty("CUSTOMER_FLUTTER_APP_LABEL")
val scheme = providers.gradleProperty("CUSTOMER_FLUTTER_AUTH_CALLBACK_SCHEME")
val host = providers.gradleProperty("CUSTOMER_FLUTTER_AUTH_CALLBACK_HOST")
android {
  defaultConfig {
    applicationId = appId.get()
    manifestPlaceholders["appLabel"] = appLabel.get()
    manifestPlaceholders["authCallbackScheme"] = scheme.get()
    manifestPlaceholders["authCallbackHost"] = host.get()
  }
}
''');
      _writeFile(
        root,
        'android/app/src/main/kotlin/com/example/MainActivity.kt',
        '''
class MainActivity {
  val flag = "WindowManager.LayoutParams.FLAG_SECURE"
  fun marker() = "override fun onCreate"
  fun startup() = "window.setFlags"
  val screen = "customer_flutter/screen_security"
  val enable = "enable"
  val disable = "disable"
  val report = "reportSecurityEvent"
  val event = "securityEvent"
  val callback = "invokeMethod"
  val eventName = "eventName"
  val currentRoute = "currentRoute"
  val reasonText = "reasonText"
  val androidSource = "android_report_security_event"
  val recentsPolicy = "protect_recent_app_preview"
  val recentsApi = "setRecentsScreenshotEnabled"
  val biometric = "customer_flutter/biometric_keys"
  val store = "AndroidKeyStore"
  val existingId = "existingDeviceId"
  val deleteMethod = "deleteKeyPair"
  val deleteStoreKey = "deleteEntry"
  val keyExists = "hasExistingKeyPair"
  val staleDeviceCleanup = "remove(deviceIdKey)"
  val keyAliases = "credentialId rawId keyAlgorithm"
  val signaturePayload = "signatureBase64 signatureDer signedPayload"
  val auth = "setUserAuthenticationRequired(true)"
  val strongAuth = "AUTH_BIOMETRIC_STRONG"
  val invalidated = "setInvalidatedByBiometricEnrollment(true)"
  val runtimeNamespace = "packageName"
  val boolAliases = "enabled active allowed supported disabled blocked unsupported not_allowed"
}
''',
      );

      final issues = runCustomerFlutterProductionPreflight(
        ProductionPreflightInput(
          target: CustomerFlutterTarget.android,
          production: true,
          checkFiles: true,
          androidRequireSigning: false,
          projectRoot: root.path,
          apiBaseUrl: 'https://partner.example.com/api/v1',
          appDisplayName: 'Partner Lottery',
          androidPackage: 'com.partner.customer',
          androidCallbackScheme: 'partnerlottery',
          androidCallbackHost: 'partner.example.com',
        ),
      );

      expect(
        issues.map((issue) => issue.code),
        contains('android_backup_disabled_missing'),
      );
    } finally {
      root.deleteSync(recursive: true);
    }
  });

  test('production preflight rejects Android release cleartext traffic', () {
    final root = Directory.systemTemp.createTempSync(
      'customer_flutter_preflight_android_cleartext_',
    );
    try {
      _writeFile(root, 'android/app/src/main/AndroidManifest.xml', r'''
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
  <uses-permission android:name="android.permission.USE_BIOMETRIC"/>
  <application
      android:label="${appLabel}"
      android:allowBackup="false"
      android:fullBackupContent="false">
    <activity android:name=".MainActivity" android:exported="true">
      <intent-filter>
        <data android:scheme="${authCallbackScheme}"/>
      </intent-filter>
      <intent-filter android:autoVerify="true">
        <data android:scheme="https" android:host="${authCallbackHost}" android:pathPrefix="/line/callback"/>
        <data android:scheme="https" android:host="${authCallbackHost}" android:pathPrefix="/social"/>
        <data android:scheme="https" android:host="${authCallbackHost}" android:pathPrefix="/reset-password"/>
        <data android:scheme="https" android:host="${authCallbackHost}" android:pathPrefix="/checkout/pending"/>
      </intent-filter>
    </activity>
  </application>
</manifest>
''');
      _writeFile(root, 'android/app/src/release/AndroidManifest.xml', r'''
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
  <application android:usesCleartextTraffic="true"/>
</manifest>
''');

      final issues = runCustomerFlutterProductionPreflight(
        ProductionPreflightInput(
          target: CustomerFlutterTarget.android,
          production: true,
          checkFiles: true,
          androidRequireSigning: false,
          projectRoot: root.path,
          apiBaseUrl: 'https://partner.example.com/api/v1',
          appDisplayName: 'Partner Lottery',
          androidPackage: 'com.partner.customer',
          androidCallbackScheme: 'partnerlottery',
          androidCallbackHost: 'partner.example.com',
        ),
      );

      expect(
        issues.map((issue) => issue.code),
        contains('android_cleartext_traffic_not_disabled'),
      );
    } finally {
      root.deleteSync(recursive: true);
    }
  });

  test(
    'production preflight rejects Android biometric credential fallback',
    () {
      final root = Directory.systemTemp.createTempSync(
        'customer_flutter_preflight_android_biometric_',
      );
      try {
        _writeFile(root, 'android/app/src/main/AndroidManifest.xml', r'''
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
  <uses-permission android:name="android.permission.USE_BIOMETRIC"/>
  <application android:label="${appLabel}">
    <activity android:name=".MainActivity" android:exported="true">
      <intent-filter>
        <data android:scheme="${authCallbackScheme}"/>
      </intent-filter>
      <intent-filter android:autoVerify="true">
        <data android:scheme="https" android:host="${authCallbackHost}" android:pathPrefix="/line/callback"/>
        <data android:scheme="https" android:host="${authCallbackHost}" android:pathPrefix="/social"/>
        <data android:scheme="https" android:host="${authCallbackHost}" android:pathPrefix="/reset-password"/>
        <data android:scheme="https" android:host="${authCallbackHost}" android:pathPrefix="/checkout/pending"/>
      </intent-filter>
    </activity>
  </application>
</manifest>
''');
        _writeFile(root, 'android/app/build.gradle.kts', '''
val appId = providers.gradleProperty("CUSTOMER_FLUTTER_APPLICATION_ID")
val appLabel = providers.gradleProperty("CUSTOMER_FLUTTER_APP_LABEL")
val scheme = providers.gradleProperty("CUSTOMER_FLUTTER_AUTH_CALLBACK_SCHEME")
val host = providers.gradleProperty("CUSTOMER_FLUTTER_AUTH_CALLBACK_HOST")
android {
  defaultConfig {
    applicationId = appId.get()
    manifestPlaceholders["appLabel"] = appLabel.get()
    manifestPlaceholders["authCallbackScheme"] = scheme.get()
    manifestPlaceholders["authCallbackHost"] = host.get()
  }
}
''');
        _writeFile(
          root,
          'android/app/src/main/kotlin/com/example/MainActivity.kt',
          '''
class MainActivity {
  val flag = "WindowManager.LayoutParams.FLAG_SECURE"
  fun marker() = "override fun onCreate"
  fun startup() = "window.setFlags"
  val screen = "customer_flutter/screen_security"
  val enable = "enable"
  val disable = "disable"
  val report = "reportSecurityEvent"
  val event = "securityEvent"
  val callback = "invokeMethod"
  val eventName = "eventName"
  val currentRoute = "currentRoute"
  val reasonText = "reasonText"
  val androidSource = "android_report_security_event"
  val recentsPolicy = "protect_recent_app_preview"
  val recentsApi = "setRecentsScreenshotEnabled"
  val biometric = "customer_flutter/biometric_keys"
  val store = "AndroidKeyStore"
  val existingId = "existingDeviceId"
  val deleteMethod = "deleteKeyPair"
  val deleteStoreKey = "deleteEntry"
  val keyExists = "hasExistingKeyPair"
  val staleDeviceCleanup = "remove(deviceIdKey)"
  val keyAliases = "credentialId rawId keyAlgorithm"
  val signaturePayload = "signatureBase64 signatureDer signedPayload"
  val auth = "setUserAuthenticationRequired(true)"
  val strongAuth = "AUTH_BIOMETRIC_STRONG"
  val unsafeCredentialFallback = "AUTH_DEVICE_CREDENTIAL"
  val invalidated = "setInvalidatedByBiometricEnrollment(true)"
  val runtimeNamespace = "packageName"
  val boolAliases = "enabled active allowed supported disabled blocked unsupported not_allowed"
}
''',
        );

        final issues = runCustomerFlutterProductionPreflight(
          ProductionPreflightInput(
            target: CustomerFlutterTarget.android,
            production: true,
            checkFiles: true,
            androidRequireSigning: false,
            projectRoot: root.path,
            apiBaseUrl: 'https://partner.example.com/api/v1',
            appDisplayName: 'Partner Lottery',
            androidPackage: 'com.partner.customer',
            androidCallbackScheme: 'partnerlottery',
            androidCallbackHost: 'partner.example.com',
          ),
        );

        expect(
          issues.map((issue) => issue.code),
          contains('android_biometric_device_credential_allowed'),
        );
      } finally {
        root.deleteSync(recursive: true);
      }
    },
  );

  test('production preflight rejects missing iOS runtime config', () {
    final root = Directory.systemTemp.createTempSync(
      'customer_flutter_preflight_ios_',
    );
    try {
      _writeFile(root, 'ios/Runner/Info.plist', '''
<plist>
  <dict>
    <key>CFBundleDisplayName</key>
    <string>Hardcoded</string>
    <key>CFBundleURLTypes</key>
    <array>
      <dict>
        <key>CFBundleURLSchemes</key>
        <array><string>hardcoded</string></array>
      </dict>
    </array>
    <key>NSFaceIDUsageDescription</key>
    <string>Use Face ID</string>
  </dict>
</plist>
''');
      _writeFile(root, 'ios/Flutter/Debug.xcconfig', 'APP_DISPLAY_NAME=Demo');
      _writeFile(root, 'ios/Flutter/Release.xcconfig', '''
APP_DISPLAY_NAME=Demo
CUSTOMER_FLUTTER_URL_SCHEME=demo
CUSTOMER_FLUTTER_ASSOCIATED_DOMAIN=applinks:demo.test
''');
      _writeFile(root, 'ios/Runner/AppDelegate.swift', '''
class AppDelegate {
  let screen = "customer_flutter/screen_security"
  let screenshot = "UIApplication.userDidTakeScreenshotNotification"
  let screenshotRaw = "UIApplication.userDidTakeScreenshotNotification.rawValue"
  let captureChanged = "UIScreen.capturedDidChangeNotification"
  let captureChangedRaw = "UIScreen.capturedDidChangeNotification.rawValue"
  let captured = "UIScreen.main.isCaptured"
  let willResign = "UIApplication.willResignActiveNotification"
  let didBecome = "UIApplication.didBecomeActiveNotification"
  let hideSnapshot = "applicationWillHideSensitiveSnapshot"
  let restoreSnapshot = "applicationDidReturnFromSensitiveSnapshot"
  let overlay = "showPrivacyOverlay"
  let exitPolicy = "ios_exit_app iosExitAppEnabled"
  let exitEvent = "screen_security_exit_requested"
  let event = "securityEvent"
  let eventPayload = "nativeEvent isCaptured screenCaptureActive currentRoute reasonText"
  let aliasRoutes = "screenSecurityRouteKeys routeName targetUrl"
  let aliasEvents = "screenSecurityEventKeys eventName nativeEvent"
  let aliasReasons = "screenSecurityReasonKeys reasonText"
  let aliasPolicies = "screenshotPolicyKeys iosScreenshotPolicy screenCaptureOverlayKeys iosScreenCaptureOverlay exitAppPolicyKeys iosExitApp"
  let aliasCopy = "privacyOverlayTitleKeys privacyOverlayTitle privacyOverlayDescriptionKeys privacyOverlayDescription"
  let aliasHelpers = "stringArg( normalizedStringArg"
  let boolAliases = "enabled active allowed supported disabled blocked unsupported not_allowed"
  let biometric = "customer_flutter/biometric_keys"
  let accessible = "kSecAttrAccessibleWhenUnlockedThisDeviceOnly"
  let currentSet = "biometryCurrentSet"
  let existingId = "existingDeviceId"
  let deleteMethod = "deleteKeyPair"
  let deleteStoreKey = "SecItemDelete"
  let keyExists = "hasExistingBiometricKeyPair"
  let staleDeviceCleanup = "removeObject(forKey: biometricDeviceIdKey)"
  let credentialAlias = "credentialId"
  let rawAlias = "rawId"
  let keyAlgorithmAlias = "keyAlgorithm"
  let signatureBase64Alias = "signatureBase64"
  let signatureDerAlias = "signatureDer"
  let signedPayloadAlias = "signedPayload"
  let sign = "SecKeyCreateSignature"
  let runtimeNamespace = "Bundle.main.bundleIdentifier"
}
''');

      final issues = runCustomerFlutterProductionPreflight(
        ProductionPreflightInput(
          target: CustomerFlutterTarget.ios,
          production: true,
          checkFiles: true,
          androidRequireSigning: false,
          projectRoot: root.path,
          apiBaseUrl: 'https://partner.example.com/api/v1',
          appDisplayName: 'Partner Lottery',
          iosTeamId: 'ABCDE12345',
          iosBundleId: 'com.partner.customer',
          iosUrlScheme: 'partnerlottery',
          iosAssociatedDomain: 'applinks:partner.example.com',
        ),
      );

      expect(
        issues.map((issue) => issue.code),
        containsAll({
          'ios_display_name_runtime_missing',
          'ios_bundle_name_runtime_missing',
          'ios_url_scheme_runtime_missing',
          'ios_xcconfig_runtime_values_missing',
          'ios_release_xcconfig_hardcoded',
          'ios_entitlements_missing',
          'ios_project_config_missing',
          'ios_biometric_authentication_context_missing',
        }),
      );
    } finally {
      root.deleteSync(recursive: true);
    }
  });

  test('production preflight requires iOS media usage descriptions', () {
    final root = Directory.systemTemp.createTempSync(
      'customer_flutter_preflight_ios_media_',
    );
    try {
      _writeValidIosSecurityFixture(root);
      _writeFile(root, 'lib/features/topup/presentation/topup_screen.dart', '''
import 'package:image_picker/image_picker.dart';

Future<void> pickSlip() async {
  await ImagePicker().pickImage(source: ImageSource.gallery);
  await ImagePicker().pickImage(source: ImageSource.camera);
}
''');

      final issues = runCustomerFlutterProductionPreflight(
        ProductionPreflightInput(
          target: CustomerFlutterTarget.ios,
          production: true,
          checkFiles: true,
          androidRequireSigning: false,
          projectRoot: root.path,
          apiBaseUrl: 'https://partner.example.com/api/v1',
          appDisplayName: 'Partner Lottery',
          iosTeamId: 'ABCDE12345',
          iosBundleId: 'com.partner.customer',
          iosUrlScheme: 'partnerlottery',
          iosAssociatedDomain: 'applinks:partner.example.com',
        ),
      );

      expect(
        issues.map((issue) => issue.code),
        containsAll({
          'ios_photo_library_usage_missing',
          'ios_camera_usage_missing',
        }),
      );
    } finally {
      root.deleteSync(recursive: true);
    }
  });

  test('production preflight rejects checked-in development hosts', () {
    final root = Directory.systemTemp.createTempSync(
      'customer_flutter_preflight_source_',
    );
    try {
      _writeFile(root, 'lib/core/config/dev_leak.dart', '''
const badApi = 'http://localhost:8000/api/v1';
const badCdn = 'https://assets.example.com/file.webp';
''');

      final issues = runCustomerFlutterProductionPreflight(
        ProductionPreflightInput(
          target: CustomerFlutterTarget.web,
          production: true,
          checkFiles: true,
          androidRequireSigning: false,
          projectRoot: root.path,
          apiBaseUrl: 'https://partner.example.com/api/v1',
          appDisplayName: 'Partner Lottery',
        ),
      );

      final matchingIssues = issues
          .where(
            (issue) => issue.code == 'forbidden_production_source_reference',
          )
          .toList();
      expect(matchingIssues, hasLength(2));
      expect(
        matchingIssues.map((issue) => issue.message).join('\n'),
        contains('lib/core/config/dev_leak.dart'),
      );
    } finally {
      root.deleteSync(recursive: true);
    }
  });

  test('production preflight ignores development hosts in tests', () {
    final root = Directory.systemTemp.createTempSync(
      'customer_flutter_preflight_test_source_',
    );
    try {
      _writeFile(
        root,
        'test/example_test.dart',
        "const fixture = 'http://localhost:8000';",
      );

      final issues = runCustomerFlutterProductionPreflight(
        ProductionPreflightInput(
          target: CustomerFlutterTarget.web,
          production: true,
          checkFiles: true,
          androidRequireSigning: false,
          projectRoot: root.path,
          apiBaseUrl: 'https://partner.example.com/api/v1',
          appDisplayName: 'Partner Lottery',
        ),
      );

      expect(
        issues.map((issue) => issue.code),
        isNot(contains('forbidden_production_source_reference')),
      );
    } finally {
      root.deleteSync(recursive: true);
    }
  });

  test('production preflight rejects direct external link launch bypasses', () {
    final root = Directory.systemTemp.createTempSync(
      'customer_flutter_preflight_external_link_',
    );
    try {
      _writeFile(root, 'lib/features/system/direct_launcher.dart', '''
import 'package:url_launcher/url_launcher.dart';

Future<void> open(Uri uri) async {
  await launchUrl(uri);
}
''');
      _writeFile(root, 'lib/core/navigation/customer_link_launcher.dart', '''
import 'package:url_launcher/url_launcher.dart';

Future<void> open(Uri uri) async {
  await launchUrl(uri);
}
''');

      final issues = runCustomerFlutterProductionPreflight(
        ProductionPreflightInput(
          target: CustomerFlutterTarget.web,
          production: true,
          checkFiles: true,
          androidRequireSigning: false,
          projectRoot: root.path,
          apiBaseUrl: 'https://partner.example.com/api/v1',
          appDisplayName: 'Partner Lottery',
        ),
      );

      final matchingIssues = issues
          .where((issue) => issue.code == 'external_link_policy_bypass')
          .toList();
      expect(matchingIssues, hasLength(2));
      expect(
        matchingIssues.map((issue) => issue.message).join('\n'),
        contains('lib/features/system/direct_launcher.dart'),
      );
      expect(
        matchingIssues.map((issue) => issue.message).join('\n'),
        isNot(contains('lib/core/navigation/customer_link_launcher.dart')),
      );
    } finally {
      root.deleteSync(recursive: true);
    }
  });

  test(
    'production preflight scans release xcconfig but ignores debug defaults',
    () {
      final root = Directory.systemTemp.createTempSync(
        'customer_flutter_preflight_xcconfig_',
      );
      try {
        _writeFile(
          root,
          'ios/Flutter/Debug.xcconfig',
          'CUSTOMER_FLUTTER_ASSOCIATED_DOMAIN=applinks:localhost',
        );
        _writeFile(
          root,
          'ios/Flutter/Release.xcconfig',
          'CUSTOMER_FLUTTER_ASSOCIATED_DOMAIN=applinks:localhost',
        );

        final issues = runCustomerFlutterProductionPreflight(
          ProductionPreflightInput(
            target: CustomerFlutterTarget.ios,
            production: true,
            checkFiles: true,
            androidRequireSigning: false,
            projectRoot: root.path,
            apiBaseUrl: 'https://partner.example.com/api/v1',
            appDisplayName: 'Partner Lottery',
            iosTeamId: 'ABCDE12345',
            iosBundleId: 'com.partner.customer',
            iosUrlScheme: 'partnerlottery',
            iosAssociatedDomain: 'applinks:partner.example.com',
          ),
        );

        final forbidden = issues.where(
          (issue) => issue.code == 'forbidden_production_source_reference',
        );
        expect(forbidden, hasLength(1));
        expect(
          forbidden.single.message,
          contains('ios/Flutter/Release.xcconfig'),
        );
      } finally {
        root.deleteSync(recursive: true);
      }
    },
  );

  test(
    'production preflight rejects hardcoded iOS release branding settings',
    () {
      final root = Directory.systemTemp.createTempSync(
        'customer_flutter_preflight_ios_release_hardcode_',
      );
      try {
        _writeValidIosSecurityFixture(root);
        _writeFile(root, 'ios/Flutter/Debug.xcconfig', '''
APP_DISPLAY_NAME=NewPaotang
CUSTOMER_FLUTTER_URL_SCHEME=newpaotang
CUSTOMER_FLUTTER_ASSOCIATED_DOMAIN=applinks:localhost
''');
        _writeFile(root, 'ios/Flutter/Release.xcconfig', '''
APP_DISPLAY_NAME=NewPaotang
CUSTOMER_FLUTTER_URL_SCHEME=newpaotang
CUSTOMER_FLUTTER_ASSOCIATED_DOMAIN=applinks:partner.example.com
''');

        final issues = runCustomerFlutterProductionPreflight(
          ProductionPreflightInput(
            target: CustomerFlutterTarget.ios,
            production: true,
            checkFiles: true,
            androidRequireSigning: false,
            projectRoot: root.path,
            apiBaseUrl: 'https://partner.example.com/api/v1',
            appDisplayName: 'Partner Lottery',
            iosTeamId: 'ABCDE12345',
            iosBundleId: 'com.partner.customer',
            iosUrlScheme: 'partnerlottery',
            iosAssociatedDomain: 'applinks:partner.example.com',
          ),
        );

        expect(
          issues.map((issue) => issue.code),
          contains('ios_release_xcconfig_hardcoded'),
        );
      } finally {
        root.deleteSync(recursive: true);
      }
    },
  );

  test('web production preflight allows same-origin API path', () {
    final issues = runCustomerFlutterProductionPreflight(
      const ProductionPreflightInput(
        target: CustomerFlutterTarget.web,
        production: true,
        checkFiles: false,
        androidRequireSigning: false,
        apiBaseUrl: '/api/v1',
        appDisplayName: 'Partner Lottery',
        webShortName: 'Partner',
        webDescription: 'Partner digital lottery customer portal.',
      ),
    );

    expect(issues, isEmpty);
  });

  test('web production preflight rejects missing runtime metadata', () {
    final issues = runCustomerFlutterProductionPreflight(
      const ProductionPreflightInput(
        target: CustomerFlutterTarget.web,
        production: true,
        checkFiles: false,
        androidRequireSigning: false,
        apiBaseUrl: '/api/v1',
        appDisplayName: 'Partner Lottery',
      ),
    );

    expect(
      issues.map((issue) => issue.code),
      containsAll({'web_short_name_missing', 'web_description_missing'}),
    );
  });

  test('web production preflight rejects generic runtime metadata', () {
    final issues = runCustomerFlutterProductionPreflight(
      const ProductionPreflightInput(
        target: CustomerFlutterTarget.web,
        production: true,
        checkFiles: false,
        androidRequireSigning: false,
        apiBaseUrl: '/api/v1',
        appDisplayName: 'Partner Lottery',
        webAppName: 'Customer',
        webShortName: 'Customer',
        webDescription: 'Customer application.',
      ),
    );

    expect(
      issues.map((issue) => issue.code),
      containsAll({
        'web_app_name_not_partner_specific',
        'web_short_name_not_partner_specific',
        'web_description_not_partner_specific',
      }),
    );
  });

  test('web production preflight rejects default scaffold metadata', () {
    final root = Directory.systemTemp.createTempSync(
      'customer_flutter_preflight_web_metadata_',
    );
    try {
      _writeFile(root, 'web/index.html', '''
<html>
  <head>
    <meta name="description" content="A new Flutter project.">
    <meta name="apple-mobile-web-app-title" content="customer_flutter">
    <title>customer_flutter</title>
    <link rel="manifest" href="manifest.json">
  </head>
  <body></body>
</html>
''');
      _writeFile(root, 'web/manifest.json', '''
{
  "name": "customer_flutter",
  "short_name": "customer_flutter",
  "description": "A new Flutter project."
}
''');

      final issues = runCustomerFlutterProductionPreflight(
        ProductionPreflightInput(
          target: CustomerFlutterTarget.web,
          production: true,
          checkFiles: true,
          androidRequireSigning: false,
          projectRoot: root.path,
          apiBaseUrl: '/api/v1',
          appDisplayName: 'Partner Lottery',
        ),
      );

      expect(
        issues.map((issue) => issue.code),
        containsAll({
          'web_default_scaffold_metadata',
          'web_runtime_metadata_config_missing',
        }),
      );
    } finally {
      root.deleteSync(recursive: true);
    }
  });

  test(
    'web production preflight rejects missing runtime icon/theme config',
    () {
      final root = Directory.systemTemp.createTempSync(
        'customer_flutter_preflight_web_icons_',
      );
      try {
        _writeFile(root, 'web/index.html', '''
<html>
  <head>
    <meta name="description" content="Customer application.">
    <meta name="apple-mobile-web-app-title" content="Customer">
    <link rel="icon" href="favicon.png">
    <link rel="apple-touch-icon" href="icons/Icon-192.png">
    <link rel="manifest" href="manifest.json">
  </head>
  <body>
    <script>
      const runtimeConfig = window.customerFlutterWebConfig || {};
      document.title = runtimeConfig.appName || "Customer";
      document.querySelector('meta[name="description"]')
        .setAttribute("content", runtimeConfig.description || "Customer application.");
      document.querySelector('meta[name="apple-mobile-web-app-title"]')
        .setAttribute("content", runtimeConfig.shortName || "Customer");
      const manifest = {
        name: runtimeConfig.appName || "Customer",
        short_name: runtimeConfig.shortName || "Customer",
      };
      new Blob([JSON.stringify(manifest)], {
        type: "application/manifest+json"
      });
    </script>
  </body>
</html>
''');

        final issues = runCustomerFlutterProductionPreflight(
          ProductionPreflightInput(
            target: CustomerFlutterTarget.web,
            production: true,
            checkFiles: true,
            androidRequireSigning: false,
            projectRoot: root.path,
            apiBaseUrl: '/api/v1',
            appDisplayName: 'Partner Lottery',
            webShortName: 'Partner',
            webDescription: 'Partner digital lottery customer portal.',
          ),
        );

        expect(
          issues.map((issue) => issue.code),
          contains('web_runtime_metadata_config_missing'),
        );
      } finally {
        root.deleteSync(recursive: true);
      }
    },
  );

  test('web production preflight rejects missing runtime social metadata', () {
    final root = Directory.systemTemp.createTempSync(
      'customer_flutter_preflight_web_social_',
    );
    try {
      _writeFile(root, 'web/index.html', '''
<html>
  <head>
    <meta name="description" content="Customer application.">
    <meta name="theme-color" content="#087FF0">
    <meta name="msapplication-TileColor" content="#087FF0">
    <meta name="apple-mobile-web-app-title" content="Customer">
    <link rel="icon" href="favicon.png">
    <link rel="apple-touch-icon" href="icons/Icon-192.png">
    <link rel="manifest" href="manifest.json">
  </head>
  <body>
    <script>
      const runtimeConfig = window.customerFlutterWebConfig || {};
      const appName = runtimeConfig.appName || "Customer";
      const shortName = runtimeConfig.shortName || appName;
      const description = runtimeConfig.description || "Customer application.";
      const themeColor = runtimeConfig.themeColor || "#087FF0";
      const icon192Url = runtimeConfig.icon192Url || "icons/Icon-192.png";
      const icon512Url = runtimeConfig.icon512Url || "icons/Icon-512.png";
      const maskableIcon192Url = runtimeConfig.maskableIcon192Url || "icons/Icon-maskable-192.png";
      const maskableIcon512Url = runtimeConfig.maskableIcon512Url || "icons/Icon-maskable-512.png";
      const faviconUrl = runtimeConfig.faviconUrl || icon192Url;
      const appleTouchIconUrl = runtimeConfig.appleTouchIconUrl || icon192Url;
      document.title = appName;
      document.querySelector('meta[name="description"]').setAttribute("content", description);
      document.querySelector('meta[name="theme-color"]').setAttribute("content", themeColor);
      document.querySelector('meta[name="msapplication-TileColor"]').setAttribute("content", themeColor);
      document.querySelector('meta[name="apple-mobile-web-app-title"]').setAttribute("content", shortName);
      document.querySelector('link[rel="icon"]').setAttribute("href", faviconUrl);
      document.querySelector('link[rel="apple-touch-icon"]').setAttribute("href", appleTouchIconUrl);
      const manifest = {
        name: appName,
        short_name: shortName,
        description: description,
        theme_color: runtimeConfig.themeColor,
        icons: [
          { src: icon192Url },
          { src: icon512Url },
          { src: maskableIcon192Url },
          { src: maskableIcon512Url }
        ]
      };
      new Blob([JSON.stringify(manifest)], {
        type: "application/manifest+json"
      });
    </script>
  </body>
</html>
''');

      final issues = runCustomerFlutterProductionPreflight(
        ProductionPreflightInput(
          target: CustomerFlutterTarget.web,
          production: true,
          checkFiles: true,
          androidRequireSigning: false,
          projectRoot: root.path,
          apiBaseUrl: '/api/v1',
          appDisplayName: 'Partner Lottery',
          webShortName: 'Partner',
          webDescription: 'Partner digital lottery customer portal.',
        ),
      );

      expect(
        issues.map((issue) => issue.code),
        contains('web_runtime_metadata_config_missing'),
      );
    } finally {
      root.deleteSync(recursive: true);
    }
  });

  test('web production preflight rejects missing canonical web identity', () {
    final root = Directory.systemTemp.createTempSync(
      'customer_flutter_preflight_web_canonical_',
    );
    try {
      _writeFile(root, 'web/index.html', '''
<html>
  <head>
    <meta name="description" content="Customer application.">
    <meta name="theme-color" content="#087FF0">
    <meta name="msapplication-TileColor" content="#087FF0">
    <meta name="apple-mobile-web-app-title" content="Customer">
    <meta property="og:title" content="Customer">
    <meta property="og:description" content="Customer application.">
    <meta property="og:image" content="icons/Icon-512.png">
    <meta name="twitter:title" content="Customer">
    <meta name="twitter:description" content="Customer application.">
    <meta name="twitter:image" content="icons/Icon-512.png">
    <link rel="icon" href="favicon.png">
    <link rel="apple-touch-icon" href="icons/Icon-192.png">
    <link rel="manifest" href="manifest.json">
  </head>
  <body>
    <script>
      const runtimeConfig = window.customerFlutterWebConfig || {};
      const appName = runtimeConfig.appName || "Customer";
      const shortName = runtimeConfig.shortName || appName;
      const description = runtimeConfig.description || "Customer application.";
      const themeColor = runtimeConfig.themeColor || "#087FF0";
      const icon192Url = runtimeConfig.icon192Url || "icons/Icon-192.png";
      const icon512Url = runtimeConfig.icon512Url || "icons/Icon-512.png";
      const maskableIcon192Url = runtimeConfig.maskableIcon192Url || "icons/Icon-maskable-192.png";
      const maskableIcon512Url = runtimeConfig.maskableIcon512Url || "icons/Icon-maskable-512.png";
      const faviconUrl = runtimeConfig.faviconUrl || icon192Url;
      const appleTouchIconUrl = runtimeConfig.appleTouchIconUrl || icon192Url;
      const socialTitle = runtimeConfig.socialTitle || runtimeConfig.ogTitle || appName;
      const socialDescription = runtimeConfig.socialDescription || runtimeConfig.ogDescription || description;
      const shareImageUrl = runtimeConfig.shareImageUrl || runtimeConfig.ogImageUrl || icon512Url;
      document.title = appName;
      document.querySelector('meta[name="description"]').setAttribute("content", description);
      document.querySelector('meta[name="theme-color"]').setAttribute("content", themeColor);
      document.querySelector('meta[name="msapplication-TileColor"]').setAttribute("content", themeColor);
      document.querySelector('meta[name="apple-mobile-web-app-title"]').setAttribute("content", shortName);
      document.querySelector('meta[property="og:title"]').setAttribute("content", socialTitle);
      document.querySelector('meta[property="og:description"]').setAttribute("content", socialDescription);
      document.querySelector('meta[property="og:image"]').setAttribute("content", shareImageUrl);
      document.querySelector('meta[name="twitter:title"]').setAttribute("content", socialTitle);
      document.querySelector('meta[name="twitter:description"]').setAttribute("content", socialDescription);
      document.querySelector('meta[name="twitter:image"]').setAttribute("content", shareImageUrl);
      document.querySelector('link[rel="icon"]').setAttribute("href", faviconUrl);
      document.querySelector('link[rel="apple-touch-icon"]').setAttribute("href", appleTouchIconUrl);
      const manifest = {
        name: appName,
        short_name: shortName,
        start_url: runtimeConfig.startUrl || ".",
        description: description,
        theme_color: runtimeConfig.themeColor,
        icons: [
          { src: icon192Url },
          { src: icon512Url },
          { src: maskableIcon192Url },
          { src: maskableIcon512Url }
        ]
      };
      new Blob([JSON.stringify(manifest)], {
        type: "application/manifest+json"
      });
    </script>
  </body>
</html>
''');

      final issues = runCustomerFlutterProductionPreflight(
        ProductionPreflightInput(
          target: CustomerFlutterTarget.web,
          production: true,
          checkFiles: true,
          androidRequireSigning: false,
          projectRoot: root.path,
          apiBaseUrl: '/api/v1',
          appDisplayName: 'Partner Lottery',
          webShortName: 'Partner',
          webDescription: 'Partner digital lottery customer portal.',
        ),
      );

      expect(
        issues.map((issue) => issue.code),
        contains('web_runtime_metadata_config_missing'),
      );
    } finally {
      root.deleteSync(recursive: true);
    }
  });

  test('web production preflight accepts runtime manifest aliases', () {
    final root = Directory.systemTemp.createTempSync(
      'customer_flutter_preflight_web_manifest_aliases_',
    );
    try {
      _writeFile(root, 'web/index.html', r'''
<html>
  <head>
    <meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover">
    <meta name="description" content="Customer application.">
    <meta name="theme-color" content="#087FF0">
    <meta name="msapplication-TileColor" content="#087FF0">
    <meta property="og:title" content="Customer">
    <meta property="og:description" content="Customer application.">
    <meta property="og:url" content=".">
    <meta property="og:image" content="icons/Icon-512.png">
    <meta name="twitter:title" content="Customer">
    <meta name="twitter:description" content="Customer application.">
    <meta name="twitter:url" content=".">
    <meta name="twitter:image" content="icons/Icon-512.png">
    <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
    <meta name="apple-mobile-web-app-title" content="Customer">
    <link rel="icon" href="favicon.png">
    <link rel="apple-touch-icon" href="icons/Icon-192.png">
    <link rel="canonical" href=".">
    <link rel="manifest" href="manifest.json">
  </head>
  <body>
    <script>
      const runtimeConfigSources = [
        window.customerFlutterWebConfig,
        window.customerFlutterConfig,
        window.__CUSTOMER_FLUTTER_WEB_CONFIG__,
      ];
      const expandedRuntimeConfigSources = [];
      function addConfigSource(source, depth) {
        if (!source || depth > 3) return;
        expandedRuntimeConfigSources.push(source);
        for (const key of ["web", "pwa", "manifest", "colors", "icons", "seo"]) {
          if (source[key]) addConfigSource(source[key], depth + 1);
        }
      }
      for (const source of runtimeConfigSources) addConfigSource(source, 0);
      const runtimeConfig = expandedRuntimeConfigSources[0] || {};
      function configScalar(value) {
        if (typeof value === "string" && value.trim()) return value.trim();
        if (value && typeof value === "object") {
          for (const key of ["value", "hex", "cssValue", "publicUrl", "assetUrl"]) {
            if (value[key]) return value[key];
          }
        }
        return "";
      }
      function firstConfigValue(keys, fallback) {
        for (const key of keys) {
          const value = configScalar(runtimeConfig[key]);
          if (value) return value;
        }
        return fallback;
      }
      const appName = firstConfigValue(["appName", "webAppName", "web_app_name"], "Customer");
      const shortName = firstConfigValue(["shortName", "short_name", "webShortName", "web_short_name"], appName);
      const description = firstConfigValue(["description", "webDescription", "web_description"], "Customer application.");
      function normalizeThemeColor(value) {
        const normalized = configScalar(value);
        return /^#[0-9a-fA-F]{6}$/.test(normalized)
          ? normalized.toUpperCase()
          : "#087FF0";
      }
      const themeColor = normalizeThemeColor(firstConfigValue([
        "themeColor", "theme_color", "manifestThemeColor",
        "manifest_theme_color", "primaryColor", "primary_color",
        "primary", "brandColor", "brand_color"
      ], "#087FF0"));
      const backgroundColor = firstConfigValue(["manifestBackgroundColor", "manifest_background_color", "backgroundColor", "background_color"], "#FFFFFF");
      const faviconUrl = firstConfigValue(["faviconUrl", "favicon_url"], "favicon.png");
      const appleTouchIconUrl = firstConfigValue(["appleTouchIconUrl", "apple_touch_icon_url"], "icons/Icon-192.png");
      const icon192Url = firstConfigValue(["icon192Url", "icon_192_url"], "icons/Icon-192.png");
      const icon512Url = firstConfigValue(["icon512Url", "icon_512_url"], "icons/Icon-512.png");
      const maskableIcon192Url = firstConfigValue(["maskableIcon192Url", "maskable_icon_192_url"], "icons/Icon-maskable-192.png");
      const maskableIcon512Url = firstConfigValue(["maskableIcon512Url", "maskable_icon_512_url"], "icons/Icon-maskable-512.png");
      const socialTitle = firstConfigValue(["ogTitle", "og_title"], appName);
      const socialDescription = firstConfigValue(["ogDescription", "og_description"], description);
      const shareImageUrl = firstConfigValue(["shareImageUrl", "share_image_url", "ogImageUrl", "og_image_url"], icon512Url);
      const startUrl = firstConfigValue(["startUrl", "start_url", "webStartUrl", "web_start_url"], ".");
      const canonicalUrl = firstConfigValue(["canonicalUrl", "canonical_url", "siteUrl", "site_url"], startUrl);
      const manifestId = firstConfigValue(["manifestId", "manifest_id", "webAppId", "web_app_id"], canonicalUrl);
      const manifestScope = firstConfigValue(["scope", "webScope", "web_scope"], startUrl);
      const manifestDisplay = firstConfigValue(["displayMode", "display_mode", "webDisplay", "web_display"], "standalone");
      const manifestOrientation = firstConfigValue(["orientation", "webOrientation", "web_orientation"], "portrait-primary");
      const htmlLang = firstConfigValue(["lang", "defaultLocale", "default_locale"], "");
      const htmlDir = firstConfigValue(["dir", "textDirection", "text_direction"], "");
      document.title = appName;
      if (htmlLang) document.documentElement.setAttribute("lang", htmlLang);
      if (htmlDir) document.documentElement.setAttribute("dir", htmlDir);
      document.documentElement.style.setProperty("--customer-theme-color", themeColor);
      document.querySelector('meta[name="description"]').setAttribute("content", description);
      document.querySelector('meta[name="theme-color"]').setAttribute("content", themeColor);
      document.querySelector('meta[name="msapplication-TileColor"]').setAttribute("content", themeColor);
      document.querySelector('meta[name="apple-mobile-web-app-title"]').setAttribute("content", shortName);
      document.querySelector('meta[property="og:title"]').setAttribute("content", socialTitle);
      document.querySelector('meta[property="og:description"]').setAttribute("content", socialDescription);
      document.querySelector('meta[property="og:url"]').setAttribute("content", canonicalUrl);
      document.querySelector('meta[property="og:image"]').setAttribute("content", shareImageUrl);
      document.querySelector('meta[name="twitter:title"]').setAttribute("content", socialTitle);
      document.querySelector('meta[name="twitter:description"]').setAttribute("content", socialDescription);
      document.querySelector('meta[name="twitter:url"]').setAttribute("content", canonicalUrl);
      document.querySelector('meta[name="twitter:image"]').setAttribute("content", shareImageUrl);
      document.querySelector('link[rel="icon"]').setAttribute("href", faviconUrl);
      document.querySelector('link[rel="apple-touch-icon"]').setAttribute("href", appleTouchIconUrl);
      document.querySelector('link[rel="canonical"]').setAttribute("href", canonicalUrl);
      const manifest = {
        id: manifestId,
        name: appName,
        short_name: shortName,
        start_url: startUrl,
        scope: manifestScope,
        display: manifestDisplay,
        background_color: backgroundColor,
        theme_color: themeColor,
        description: description,
        orientation: manifestOrientation,
        icons: [
          { src: icon192Url },
          { src: icon512Url },
          { src: maskableIcon192Url },
          { src: maskableIcon512Url }
        ]
      };
      new Blob([JSON.stringify(manifest)], {
        type: "application/manifest+json"
      });
    </script>
  </body>
</html>
''');

      final issues = runCustomerFlutterProductionPreflight(
        ProductionPreflightInput(
          target: CustomerFlutterTarget.web,
          production: true,
          checkFiles: true,
          androidRequireSigning: false,
          projectRoot: root.path,
          apiBaseUrl: '/api/v1',
          appDisplayName: 'Partner Lottery',
          webAppName: 'Partner Lottery',
          webShortName: 'Partner',
          webDescription: 'Partner digital lottery customer portal.',
        ),
      );

      expect(
        issues.map((issue) => issue.code),
        isNot(contains('web_runtime_metadata_config_missing')),
      );
    } finally {
      root.deleteSync(recursive: true);
    }
  });

  test('web runtime system chrome follows runtime theme aliases', () {
    final indexSource = File('web/index.html').readAsStringSync();
    final manifestSource = File('web/manifest.json').readAsStringSync();

    expect(indexSource, contains('content="#087FF0"'));
    expect(
      indexSource,
      contains('const themeColor = normalizeThemeColor(firstConfigValue(['),
    );
    expect(indexSource, contains('"primaryColor",'));
    expect(indexSource, contains('"manifestThemeColor",'));
    expect(indexSource, contains('viewport-fit=cover'));
    expect(indexSource, contains('content="black-translucent"'));
    expect(
      indexSource,
      contains(
        'document.documentElement.style.setProperty("--customer-theme-color", themeColor)',
      ),
    );
    expect(indexSource, contains('"#FFFFFF"'));
    expect(manifestSource, contains('"theme_color": "#087FF0"'));
    expect(manifestSource, contains('"background_color": "#FFFFFF"'));
  });

  test('web production preflight rejects stale deployment cache binding', () {
    final root = Directory.systemTemp.createTempSync(
      'customer_flutter_preflight_web_freshness_',
    );
    try {
      _writeFile(root, 'web/flutter_bootstrap.js', '''
{{flutter_js}}
{{flutter_build_config}}
_flutter.loader.load({
  serviceWorkerSettings: { serviceWorkerVersion: "old" }
});
''');
      _writeFile(root, 'docker/nginx.conf', '''
location ~* \\.js\$ {
  add_header Cache-Control "public, max-age=2592000";
}
''');

      final issues = runCustomerFlutterProductionPreflight(
        ProductionPreflightInput(
          target: CustomerFlutterTarget.web,
          production: true,
          checkFiles: true,
          androidRequireSigning: false,
          projectRoot: root.path,
          apiBaseUrl: '/api/v1',
          appDisplayName: 'Partner Lottery',
          webAppName: 'Partner Lottery',
          webShortName: 'Partner',
          webDescription: 'Partner digital lottery customer portal.',
        ),
      );

      expect(
        issues.map((issue) => issue.code),
        contains('flutter_web_deployment_freshness_missing'),
      );
    } finally {
      root.deleteSync(recursive: true);
    }
  });

  test('web production preflight rejects missing runtime locale metadata', () {
    final root = Directory.systemTemp.createTempSync(
      'customer_flutter_preflight_web_locale_',
    );
    try {
      final indexSource = File('web/index.html')
          .readAsStringSync()
          .replaceAll(
            'document.documentElement.setAttribute("lang", htmlLang);',
            '',
          )
          .replaceAll(
            'document.documentElement.setAttribute("dir", htmlDir);',
            '',
          );
      _writeFile(root, 'web/index.html', indexSource);

      final issues = runCustomerFlutterProductionPreflight(
        ProductionPreflightInput(
          target: CustomerFlutterTarget.web,
          production: true,
          checkFiles: true,
          androidRequireSigning: false,
          projectRoot: root.path,
          apiBaseUrl: '/api/v1',
          appDisplayName: 'Partner Lottery',
          webAppName: 'Partner Lottery',
          webShortName: 'Partner',
          webDescription: 'Partner digital lottery customer portal.',
        ),
      );

      expect(
        issues.map((issue) => issue.code),
        contains('web_runtime_metadata_config_missing'),
      );
    } finally {
      root.deleteSync(recursive: true);
    }
  });

  test(
    'web production preflight rejects missing privacy lifecycle binding',
    () {
      final root = Directory.systemTemp.createTempSync(
        'customer_flutter_preflight_web_privacy_',
      );
      try {
        _writeFile(
          root,
          'web/index.html',
          File('web/index.html').readAsStringSync(),
        );

        final issues = runCustomerFlutterProductionPreflight(
          ProductionPreflightInput(
            target: CustomerFlutterTarget.web,
            production: true,
            checkFiles: true,
            androidRequireSigning: false,
            projectRoot: root.path,
            apiBaseUrl: '/api/v1',
            appDisplayName: 'Partner Lottery',
            webAppName: 'Partner Lottery',
            webShortName: 'Partner',
            webDescription: 'Partner digital lottery customer portal.',
          ),
        );

        expect(
          issues.map((issue) => issue.code),
          contains('flutter_web_privacy_binding_missing'),
        );
      } finally {
        root.deleteSync(recursive: true);
      }
    },
  );

  test('web production preflight rejects re-enabled focus privacy cover', () {
    final root = Directory.systemTemp.createTempSync(
      'customer_flutter_preflight_web_privacy_opt_out_',
    );
    try {
      const paths = [
        'lib/app/customer_app.dart',
        'lib/shared/widgets/web_privacy_guard.dart',
        'lib/shared/widgets/web_privacy_browser_activity.dart',
        'lib/shared/widgets/web_privacy_browser_activity_web.dart',
        'lib/shared/widgets/web_privacy_browser_activity_state.dart',
        'lib/shared/widgets/web_privacy_browser_activity_stub.dart',
        'lib/core/security/web_privacy_mode.dart',
        'web/index.html',
      ];
      for (final path in paths) {
        var source = File(path).readAsStringSync();
        if (path == 'lib/app/customer_app.dart') {
          source = source.replaceFirst(
            'const webPrivacyEnabled = false;',
            'const webPrivacyEnabled = true;',
          );
        }
        _writeFile(root, path, source);
      }

      final issues = runCustomerFlutterProductionPreflight(
        ProductionPreflightInput(
          target: CustomerFlutterTarget.web,
          production: true,
          checkFiles: true,
          androidRequireSigning: false,
          projectRoot: root.path,
          apiBaseUrl: '/api/v1',
          appDisplayName: 'Partner Lottery',
          webAppName: 'Partner Lottery',
          webShortName: 'Partner',
          webDescription: 'Partner digital lottery customer portal.',
        ),
      );

      expect(
        issues.map((issue) => issue.code),
        contains('flutter_web_privacy_binding_missing'),
      );
    } finally {
      root.deleteSync(recursive: true);
    }
  });

  test('production preflight rejects page-local Affiliate biometric PIN', () {
    final root = Directory.systemTemp.createTempSync(
      'customer_flutter_preflight_affiliate_pin_',
    );
    try {
      _writeFile(root, 'lib/app/router.dart', '''
void buildRouter() {
  const path = '/affiliate';
  customerRedirectPath(path: path);
}
''');
      _writeFile(root, 'lib/core/navigation/customer_redirect.dart', '''
String customerPinRouteForRedirect(String path) => '/pin?redirect=\$path';
''');
      _writeFile(
        root,
        'lib/features/affiliate/presentation/affiliate_screen.dart',
        '''
String affiliatePrompt() {
  mobileBiometricPromptReason(purpose: 'pin_unlock');
  return 'affiliate';
}
''',
      );

      final issues = runCustomerFlutterProductionPreflight(
        ProductionPreflightInput(
          target: CustomerFlutterTarget.android,
          production: true,
          checkFiles: true,
          androidRequireSigning: false,
          projectRoot: root.path,
          apiBaseUrl: 'https://partner.example.com/api/v1',
          appDisplayName: 'Partner Lottery',
          androidPackage: 'com.partner.customer',
          androidCallbackScheme: 'partnerlottery',
          androidCallbackHost: 'partner.example.com',
        ),
      );

      expect(
        issues.map((issue) => issue.code),
        contains('flutter_affiliate_central_pin_binding_missing'),
      );
    } finally {
      root.deleteSync(recursive: true);
    }
  });

  test(
    'web production preflight requires route registry URL normalization',
    () {
      final root = Directory.systemTemp.createTempSync(
        'customer_flutter_preflight_web_route_registry_',
      );
      try {
        _writeFile(
          root,
          'web/index.html',
          File('web/index.html').readAsStringSync(),
        );
        _writeFile(root, 'lib/app/customer_routes.dart', '''
bool isSensitiveCustomerPath(String path) {
  return path == '/my-wallet';
}
''');

        final issues = runCustomerFlutterProductionPreflight(
          ProductionPreflightInput(
            target: CustomerFlutterTarget.web,
            production: true,
            checkFiles: true,
            androidRequireSigning: false,
            projectRoot: root.path,
            apiBaseUrl: '/api/v1',
            appDisplayName: 'Partner Lottery',
            webAppName: 'Partner Lottery',
            webShortName: 'Partner',
            webDescription: 'Partner digital lottery customer portal.',
          ),
        );

        expect(
          issues.map((issue) => issue.code),
          contains('flutter_route_registry_url_normalization_missing'),
        );
      } finally {
        root.deleteSync(recursive: true);
      }
    },
  );

  test('production preflight requires maintenance route-policy binding', () {
    final root = Directory.systemTemp.createTempSync(
      'customer_flutter_preflight_maintenance_',
    );
    try {
      _writeFile(
        root,
        'web/index.html',
        File('web/index.html').readAsStringSync(),
      );
      _writeFile(root, 'lib/core/tenant/mobile_bootstrap_controller.dart', '''
class MobileBootstrap {
  final maintenance = MaintenanceConfig(active: true);
}

class MaintenanceConfig {
  const MaintenanceConfig({required this.active});
  final bool active;
}
''');
      _writeFile(root, 'lib/app/router.dart', '''
String? customerRedirectPath({
  required String path,
  required bool maintenanceActive,
}) {
  if (maintenanceActive && path != '/maintenance') return '/maintenance';
  return null;
}
''');

      final issues = runCustomerFlutterProductionPreflight(
        ProductionPreflightInput(
          target: CustomerFlutterTarget.web,
          production: true,
          checkFiles: true,
          androidRequireSigning: false,
          projectRoot: root.path,
          apiBaseUrl: '/api/v1',
          appDisplayName: 'Partner Lottery',
          webAppName: 'Partner Lottery',
          webShortName: 'Partner',
          webDescription: 'Partner digital lottery customer portal.',
        ),
      );

      expect(
        issues.map((issue) => issue.code),
        containsAll({
          'flutter_maintenance_route_policy_missing',
          'flutter_maintenance_router_binding_missing',
        }),
      );
    } finally {
      root.deleteSync(recursive: true);
    }
  });

  test('production preflight requires feature-flag route and menu binding', () {
    final root = Directory.systemTemp.createTempSync(
      'customer_flutter_preflight_feature_flags_',
    );
    try {
      _writeFile(
        root,
        'web/index.html',
        File('web/index.html').readAsStringSync(),
      );
      _writeFile(root, 'lib/core/tenant/mobile_bootstrap_controller.dart', '''
class MobileFeatureFlags {
  const MobileFeatureFlags(this.values);
  final Map<String, bool> values;
  bool enabled(String key, {bool fallback = false}) => values[key] ?? fallback;
}
''');
      _writeFile(root, 'lib/core/tenant/mobile_runtime_policy.dart', '''
bool mobileBiometricAllowedForPlatform(bootstrap, platform) => true;
bool mobileNativeScreenSecurityAllowedForPlatform(bootstrap, platform) => true;
''');
      _writeFile(root, 'lib/app/router.dart', '''
String? customerRedirectPath({required String path}) => null;
''');
      _writeFile(
        root,
        'lib/features/profile/presentation/profile_screen.dart',
        '''
class ProfileScreen {
  final items = const ['/my-wallet', '/tickets', '/profile/biometrics'];
}
''',
      );
      _writeFile(root, 'lib/shared/widgets/app_shell.dart', '''
class AppShell {
  static const items = ['/', '/tickets', '/profile'];
}
''');

      final issues = runCustomerFlutterProductionPreflight(
        ProductionPreflightInput(
          target: CustomerFlutterTarget.web,
          production: true,
          checkFiles: true,
          androidRequireSigning: false,
          projectRoot: root.path,
          apiBaseUrl: '/api/v1',
          appDisplayName: 'Partner Lottery',
          webAppName: 'Partner Lottery',
          webShortName: 'Partner',
          webDescription: 'Partner digital lottery customer portal.',
        ),
      );

      expect(
        issues.map((issue) => issue.code),
        containsAll({
          'flutter_feature_flag_route_policy_missing',
          'flutter_feature_flag_router_binding_missing',
          'flutter_feature_flag_profile_menu_binding_missing',
          'flutter_feature_flag_bottom_nav_binding_missing',
        }),
      );
    } finally {
      root.deleteSync(recursive: true);
    }
  });

  test('native production preflight rejects relative API URL', () {
    final issues = runCustomerFlutterProductionPreflight(
      const ProductionPreflightInput(
        target: CustomerFlutterTarget.android,
        production: true,
        checkFiles: false,
        androidRequireSigning: false,
        apiBaseUrl: '/api/v1',
        appDisplayName: 'Partner Lottery',
        androidPackage: 'com.partner.customer',
        androidCallbackScheme: 'partnerlottery',
        androidCallbackHost: 'partner.example.com',
      ),
    );

    expect(
      issues.map((issue) => issue.code),
      contains('api_base_url_not_https'),
    );
  });

  test('native production preflight requires tenant host for central API', () {
    final issues = runCustomerFlutterProductionPreflight(
      const ProductionPreflightInput(
        target: CustomerFlutterTarget.android,
        production: true,
        checkFiles: false,
        androidRequireSigning: false,
        apiBaseUrl: 'https://api.newpaotang.example.com/api/v1',
        appDisplayName: 'Partner Lottery',
        androidPackage: 'com.partner.customer',
        androidCallbackScheme: 'partnerlottery',
        androidCallbackHost: 'partner.example.com',
      ),
    );

    expect(
      issues.map((issue) => issue.code),
      contains('tenant_host_missing_for_central_api'),
    );
  });

  test('native production preflight accepts tenant host for central API', () {
    final issues = runCustomerFlutterProductionPreflight(
      const ProductionPreflightInput(
        target: CustomerFlutterTarget.android,
        production: true,
        checkFiles: false,
        androidRequireSigning: false,
        apiBaseUrl: 'https://api.newpaotang.example.com/api/v1',
        appDisplayName: 'Partner Lottery',
        androidPackage: 'com.partner.customer',
        androidCallbackScheme: 'partnerlottery',
        androidCallbackHost: 'partner.example.com',
        tenantHost: 'partner.example.com',
      ),
    );

    expect(
      issues.map((issue) => issue.code),
      isNot(contains('tenant_host_missing_for_central_api')),
    );
  });

  test('native production preflight rejects tenant callback host mismatch', () {
    final issues = runCustomerFlutterProductionPreflight(
      const ProductionPreflightInput(
        target: CustomerFlutterTarget.all,
        production: true,
        checkFiles: false,
        androidRequireSigning: false,
        apiBaseUrl: 'https://api.newpaotang.example.com/api/v1',
        appDisplayName: 'Partner Lottery',
        androidPackage: 'com.partner.customer',
        androidCallbackScheme: 'partnerlottery',
        androidCallbackHost: 'partner.example.com',
        iosTeamId: 'ABCDE12345',
        iosBundleId: 'com.partner.customer',
        iosUrlScheme: 'partnerlottery',
        iosAssociatedDomain: 'applinks:partner.example.com',
        tenantHost: 'other-partner.example.com',
        webShortName: 'Partner',
        webDescription: 'Partner digital lottery customer portal.',
      ),
    );

    expect(
      issues.map((issue) => issue.code),
      contains('tenant_host_callback_host_mismatch'),
    );
  });

  test('android production preflight rejects localhost callback host', () {
    final issues = runCustomerFlutterProductionPreflight(
      const ProductionPreflightInput(
        target: CustomerFlutterTarget.android,
        production: true,
        checkFiles: false,
        androidRequireSigning: false,
        apiBaseUrl: 'https://partner.example.com/api/v1',
        appDisplayName: 'Partner Lottery',
        androidPackage: 'com.partner.customer',
        androidCallbackScheme: 'partnerlottery',
        androidCallbackHost: 'localhost',
      ),
    );

    expect(
      issues.map((issue) => issue.code),
      contains('android_callback_host_invalid'),
    );
  });

  test('android production preflight rejects default project identifiers', () {
    final issues = runCustomerFlutterProductionPreflight(
      const ProductionPreflightInput(
        target: CustomerFlutterTarget.android,
        production: true,
        checkFiles: false,
        androidRequireSigning: false,
        apiBaseUrl: 'https://partner.example.com/api/v1',
        appDisplayName: 'Partner Lottery',
        androidPackage: 'com.newpaotang.customer_flutter',
        androidCallbackScheme: 'newpaotang',
        androidCallbackHost: 'partner.example.com',
      ),
    );

    expect(
      issues.map((issue) => issue.code),
      containsAll({
        'android_package_not_partner_specific',
        'android_callback_scheme_not_partner_specific',
      }),
    );
  });

  test('android production preflight requires signing inputs when enabled', () {
    final issues = runCustomerFlutterProductionPreflight(
      const ProductionPreflightInput(
        target: CustomerFlutterTarget.android,
        production: true,
        checkFiles: false,
        androidRequireSigning: true,
        apiBaseUrl: 'https://partner.example.com/api/v1',
        appDisplayName: 'Partner Lottery',
        androidPackage: 'com.partner.customer',
        androidCallbackScheme: 'partnerlottery',
        androidCallbackHost: 'partner.example.com',
      ),
    );

    expect(
      issues.map((issue) => issue.code),
      contains('android_signing_missing'),
    );
  });

  test(
    'android release build requires explicit signing or local smoke opt-in',
    () {
      final source = File('android/app/build.gradle.kts').readAsStringSync();

      expect(source, contains('CUSTOMER_FLUTTER_ALLOW_DEBUG_RELEASE_SIGNING'));
      expect(source, contains('Release signing inputs are required'));
      expect(source, contains('allowDebugReleaseSigning'));
      expect(source, contains('releaseTaskRequested'));
      expect(source, contains('hasReleaseSigning -> signingConfigs'));
      expect(source, contains('allowDebugReleaseSigning -> signingConfigs'));
      expect(source, contains('!releaseTaskRequested -> signingConfigs'));
    },
  );

  test('android release build always requires partner runtime config', () {
    final source = File('android/app/build.gradle.kts').readAsStringSync();

    expect(source, contains('Partner release config is required'));
    expect(source, contains('requireReleaseValue'));
    expect(source, contains('requirePartnerReleaseValue'));
    expect(source, contains('must be partner-specific'));
    expect(source, contains('isDefaultAndroidApplicationId'));
    expect(source, contains('isDefaultAppLabel'));
    expect(source, contains('isDefaultCallbackScheme'));
    expect(source, contains('isDevelopmentCallbackHost'));
    expect(
      source,
      contains('CUSTOMER_FLUTTER_ALLOW_DEBUG_RELEASE_SIGNING only'),
    );
    expect(source, contains('partner runtime'));
    expect(source, contains('identifiers are still required'));
    expect(
      source,
      isNot(contains('!releaseTaskRequested || allowDebugReleaseSigning ||')),
    );
    expect(source, contains('CUSTOMER_FLUTTER_APPLICATION_ID'));
    expect(source, contains('CUSTOMER_FLUTTER_APP_LABEL'));
    expect(source, contains('CUSTOMER_FLUTTER_AUTH_CALLBACK_SCHEME'));
    expect(source, contains('CUSTOMER_FLUTTER_AUTH_CALLBACK_HOST'));
  });

  test('ios production preflight validates team id and bundle id', () {
    final issues = runCustomerFlutterProductionPreflight(
      const ProductionPreflightInput(
        target: CustomerFlutterTarget.ios,
        production: true,
        checkFiles: false,
        androidRequireSigning: false,
        apiBaseUrl: 'https://partner.example.com/api/v1',
        appDisplayName: 'Partner Lottery',
        iosTeamId: 'bad',
        iosBundleId: 'customer',
        iosUrlScheme: 'https',
        iosAssociatedDomain: 'http://localhost',
      ),
    );

    expect(issues.map((issue) => issue.code), contains('ios_team_id_invalid'));
    expect(
      issues.map((issue) => issue.code),
      contains('ios_bundle_id_invalid'),
    );
    expect(
      issues.map((issue) => issue.code),
      contains('ios_url_scheme_invalid'),
    );
    expect(
      issues.map((issue) => issue.code),
      contains('ios_associated_domain_invalid'),
    );
  });

  test('ios production preflight rejects default project identifiers', () {
    final issues = runCustomerFlutterProductionPreflight(
      const ProductionPreflightInput(
        target: CustomerFlutterTarget.ios,
        production: true,
        checkFiles: false,
        androidRequireSigning: false,
        apiBaseUrl: 'https://partner.example.com/api/v1',
        appDisplayName: 'Partner Lottery',
        iosTeamId: 'ABCDE12345',
        iosBundleId: 'com.newpaotang.customerFlutter',
        iosUrlScheme: 'newpaotang',
        iosAssociatedDomain: 'applinks:partner.example.com',
      ),
    );

    expect(
      issues.map((issue) => issue.code),
      containsAll({
        'ios_bundle_id_not_partner_specific',
        'ios_url_scheme_not_partner_specific',
      }),
    );
  });

  test('ios production preflight requires Apple login with LINE or Google', () {
    final issues = runCustomerFlutterProductionPreflight(
      const ProductionPreflightInput(
        target: CustomerFlutterTarget.ios,
        production: true,
        checkFiles: false,
        androidRequireSigning: false,
        apiBaseUrl: 'https://partner.example.com/api/v1',
        appDisplayName: 'Partner Lottery',
        iosTeamId: 'ABCDE12345',
        iosBundleId: 'com.partner.customer',
        iosUrlScheme: 'partnerlottery',
        iosAssociatedDomain: 'applinks:partner.example.com',
        socialAuthProviders: ['line_oauth', 'google_oauth2'],
      ),
    );

    expect(
      issues.map((issue) => issue.code),
      contains('ios_sign_in_with_apple_required'),
    );
  });

  test('production preflight rejects unsupported social providers', () {
    final issues = runCustomerFlutterProductionPreflight(
      const ProductionPreflightInput(
        target: CustomerFlutterTarget.android,
        production: true,
        checkFiles: false,
        androidRequireSigning: false,
        apiBaseUrl: 'https://partner.example.com/api/v1',
        appDisplayName: 'Partner Lottery',
        androidPackage: 'com.partner.customer',
        androidCallbackScheme: 'partnerlottery',
        androidCallbackHost: 'partner.example.com',
        socialAuthProviders: ['line', 'gogle', 'apple-id'],
      ),
    );

    expect(
      issues.map((issue) => issue.code),
      contains('social_provider_invalid'),
    );
    expect(
      issues
          .singleWhere((issue) => issue.code == 'social_provider_invalid')
          .message,
      contains('apple-id, gogle'),
    );
  });

  test('ios production preflight accepts Apple login with other providers', () {
    final issues = runCustomerFlutterProductionPreflight(
      const ProductionPreflightInput(
        target: CustomerFlutterTarget.ios,
        production: true,
        checkFiles: false,
        androidRequireSigning: false,
        apiBaseUrl: 'https://partner.example.com/api/v1',
        appDisplayName: 'Partner Lottery',
        iosTeamId: 'ABCDE12345',
        iosBundleId: 'com.partner.customer',
        iosUrlScheme: 'partnerlottery',
        iosAssociatedDomain: 'applinks:partner.example.com',
        socialAuthProviders: ['LINE', 'google_oauth2', 'apple_login', 'google'],
      ),
    );

    expect(
      issues.map((issue) => issue.code),
      isNot(contains('ios_sign_in_with_apple_required')),
    );
    expect(
      issues.map((issue) => issue.code),
      isNot(contains('social_provider_invalid')),
    );
  });
}

void _writeFile(Directory root, String relativePath, String contents) {
  final file = File('${root.path}${Platform.pathSeparator}$relativePath');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(contents);
}

String _realSha256Fingerprint() {
  return List<String>.filled(32, 'AA').join(':');
}

void _writeValidIosSecurityFixture(Directory root) {
  _writeFile(root, 'ios/Runner/Info.plist', r'''
<plist>
  <dict>
    <key>CFBundleDisplayName</key>
    <string>$(APP_DISPLAY_NAME)</string>
    <key>CFBundleName</key>
    <string>$(APP_DISPLAY_NAME)</string>
    <key>CFBundleURLTypes</key>
    <array>
      <dict>
        <key>CFBundleURLSchemes</key>
        <array><string>$(CUSTOMER_FLUTTER_URL_SCHEME)</string></array>
      </dict>
    </array>
    <key>NSFaceIDUsageDescription</key>
    <string>Use Face ID</string>
  </dict>
</plist>
''');
  _writeFile(root, 'ios/Runner/Runner.entitlements', r'''
<plist>
  <dict>
    <key>com.apple.developer.associated-domains</key>
    <array><string>$(CUSTOMER_FLUTTER_ASSOCIATED_DOMAIN)</string></array>
  </dict>
</plist>
''');
  _writeFile(root, 'ios/Runner/AppDelegate.swift', '''
class AppDelegate {
  let screen = "customer_flutter/screen_security"
  let screenshot = "UIApplication.userDidTakeScreenshotNotification"
  let screenshotRaw = "UIApplication.userDidTakeScreenshotNotification.rawValue"
  let captureChanged = "UIScreen.capturedDidChangeNotification"
  let captureChangedRaw = "UIScreen.capturedDidChangeNotification.rawValue"
  let captured = "UIScreen.main.isCaptured"
  let willResign = "UIApplication.willResignActiveNotification"
  let didBecome = "UIApplication.didBecomeActiveNotification"
  let hideSnapshot = "applicationWillHideSensitiveSnapshot"
  let restoreSnapshot = "applicationDidReturnFromSensitiveSnapshot"
  let overlay = "showPrivacyOverlay"
  let exitPolicy = "ios_exit_app iosExitAppEnabled"
  let exitEvent = "screen_security_exit_requested"
  let event = "securityEvent"
  let eventPayload = "nativeEvent isCaptured screenCaptureActive currentRoute reasonText"
  let aliasRoutes = "screenSecurityRouteKeys routeName targetUrl"
  let aliasEvents = "screenSecurityEventKeys eventName nativeEvent"
  let aliasReasons = "screenSecurityReasonKeys reasonText"
  let aliasPolicies = "screenshotPolicyKeys iosScreenshotPolicy screenCaptureOverlayKeys iosScreenCaptureOverlay exitAppPolicyKeys iosExitApp"
  let aliasCopy = "privacyOverlayTitleKeys privacyOverlayTitle privacyOverlayDescriptionKeys privacyOverlayDescription"
  let aliasHelpers = "stringArg( normalizedStringArg"
  let boolAliases = "enabled active allowed supported disabled blocked unsupported not_allowed"
  let biometric = "customer_flutter/biometric_keys"
  let accessible = "kSecAttrAccessibleWhenUnlockedThisDeviceOnly"
  let currentSet = "biometryCurrentSet"
  let existingId = "existingDeviceId"
  let deleteMethod = "deleteKeyPair"
  let deleteStoreKey = "SecItemDelete"
  let keyExists = "hasExistingBiometricKeyPair"
  let staleDeviceCleanup = "removeObject(forKey: biometricDeviceIdKey)"
  let credentialAlias = "credentialId"
  let rawAlias = "rawId"
  let keyAlgorithmAlias = "keyAlgorithm"
  let signatureBase64Alias = "signatureBase64"
  let signatureDerAlias = "signatureDer"
  let signedPayloadAlias = "signedPayload"
  let sign = "SecKeyCreateSignature"
  let runtimeNamespace = "Bundle.main.bundleIdentifier"
}
''');
  _writeFile(root, 'ios/Runner.xcodeproj/project.pbxproj', r'''
CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;
Validate Release Config
scripts/validate_release_config.sh
PRODUCT_BUNDLE_IDENTIFIER = "$(CUSTOMER_FLUTTER_IOS_BUNDLE_ID)";
DEVELOPMENT_TEAM = "$(CUSTOMER_FLUTTER_IOS_TEAM_ID)";
''');
  _writeFile(root, 'ios/scripts/validate_release_config.sh', '''
require_value "APP_DISPLAY_NAME"
require_value "CUSTOMER_FLUTTER_URL_SCHEME"
require_value "CUSTOMER_FLUTTER_ASSOCIATED_DOMAIN"
require_value "PRODUCT_BUNDLE_IDENTIFIER"
require_value "DEVELOPMENT_TEAM"
com.newpaotang.customerFlutter
''');
}
