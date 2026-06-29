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
      ),
    );

    expect(issues, isEmpty);
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
      ),
    );

    expect(issues, isEmpty);
  });

  test('production preflight requires privacy and account deletion surfaces',
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
  });

  test('ios release guard script rejects missing or default release settings',
      () async {
    final script = 'ios/scripts/validate_release_config.sh';

    final debug = await Process.run(
      'sh',
      [
        script,
      ],
      environment: {
        'CONFIGURATION': 'Debug',
      },
    );
    expect(debug.exitCode, 0);

    final bad = await Process.run(
      'sh',
      [
        script,
      ],
      environment: {
        'CONFIGURATION': 'Release',
        'APP_DISPLAY_NAME': 'Partner Lottery',
        'CUSTOMER_FLUTTER_URL_SCHEME': 'partnerlottery',
        'CUSTOMER_FLUTTER_ASSOCIATED_DOMAIN': 'applinks:localhost',
        'PRODUCT_BUNDLE_IDENTIFIER': 'com.newpaotang.customerFlutter',
        'DEVELOPMENT_TEAM': 'ABCDE12345',
      },
    );
    expect(bad.exitCode, isNot(0));
    expect(bad.stderr.toString(), contains('production domain'));
    expect(bad.stderr.toString(), contains('partner-specific'));

    final good = await Process.run(
      'sh',
      [
        script,
      ],
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
  });

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
      _writeFile(
        root,
        'ios/Runner/Info.plist',
        '<plist><dict></dict></plist>',
      );
      _writeFile(
        root,
        'ios/Runner/AppDelegate.swift',
        'class AppDelegate',
      );

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
          'android_biometric_channel_missing',
          'flutter_screen_security_service_missing',
          'flutter_sensitive_screen_guard_missing',
          'ios_face_id_usage_missing',
          'ios_xcconfig_missing',
          'ios_release_config_guard_missing',
          'ios_screen_capture_detection_missing',
          'ios_sensitive_snapshot_overlay_missing',
          'ios_biometric_channel_missing',
        }),
      );
    } finally {
      root.deleteSync(recursive: true);
    }
  });

  test('production preflight rejects missing Android runtime manifest config',
      () {
    final root = Directory.systemTemp.createTempSync(
      'customer_flutter_preflight_android_',
    );
    try {
      _writeFile(
        root,
        'android/app/src/main/AndroidManifest.xml',
        '''
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
  <uses-permission android:name="android.permission.INTERNET"/>
  <application android:label="Hardcoded">
    <activity android:name=".MainActivity"/>
  </application>
</manifest>
''',
      );
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
  val biometric = "customer_flutter/biometric_keys"
  val store = "AndroidKeyStore"
  val auth = "setUserAuthenticationRequired(true)"
  val invalidated = "setInvalidatedByBiometricEnrollment(true)"
  val runtimeNamespace = "packageName"
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
          'android_custom_scheme_callback_missing',
          'android_app_links_missing',
          'android_runtime_config_missing',
        }),
      );
    } finally {
      root.deleteSync(recursive: true);
    }
  });

  test('production preflight rejects missing iOS runtime config', () {
    final root = Directory.systemTemp.createTempSync(
      'customer_flutter_preflight_ios_',
    );
    try {
      _writeFile(
        root,
        'ios/Runner/Info.plist',
        '''
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
''',
      );
      _writeFile(root, 'ios/Flutter/Debug.xcconfig', 'APP_DISPLAY_NAME=Demo');
      _writeFile(
        root,
        'ios/Flutter/Release.xcconfig',
        '''
APP_DISPLAY_NAME=Demo
CUSTOMER_FLUTTER_URL_SCHEME=demo
CUSTOMER_FLUTTER_ASSOCIATED_DOMAIN=applinks:demo.test
''',
      );
      _writeFile(
        root,
        'ios/Runner/AppDelegate.swift',
        '''
class AppDelegate {
  let screen = "customer_flutter/screen_security"
  let screenshot = "UIApplication.userDidTakeScreenshotNotification"
  let captureChanged = "UIScreen.capturedDidChangeNotification"
  let captured = "UIScreen.main.isCaptured"
  let willResign = "UIApplication.willResignActiveNotification"
  let didBecome = "UIApplication.didBecomeActiveNotification"
  let hideSnapshot = "applicationWillHideSensitiveSnapshot"
  let restoreSnapshot = "applicationDidReturnFromSensitiveSnapshot"
  let overlay = "showPrivacyOverlay"
  let event = "securityEvent"
  let biometric = "customer_flutter/biometric_keys"
  let accessible = "kSecAttrAccessibleWhenUnlockedThisDeviceOnly"
  let currentSet = "biometryCurrentSet"
  let sign = "SecKeyCreateSignature"
  let runtimeNamespace = "Bundle.main.bundleIdentifier"
}
''',
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

      expect(
        issues.map((issue) => issue.code),
        containsAll({
          'ios_display_name_runtime_missing',
          'ios_url_scheme_runtime_missing',
          'ios_xcconfig_runtime_values_missing',
          'ios_release_xcconfig_hardcoded',
          'ios_entitlements_missing',
          'ios_project_config_missing',
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
      _writeFile(
        root,
        'lib/core/config/dev_leak.dart',
        '''
const badApi = 'http://localhost:8000/api/v1';
const badCdn = 'https://assets.example.com/file.webp';
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
      _writeFile(
        root,
        'lib/features/system/direct_launcher.dart',
        '''
import 'package:url_launcher/url_launcher.dart';

Future<void> open(Uri uri) async {
  await launchUrl(uri);
}
''',
      );
      _writeFile(
        root,
        'lib/core/navigation/customer_link_launcher.dart',
        '''
import 'package:url_launcher/url_launcher.dart';

Future<void> open(Uri uri) async {
  await launchUrl(uri);
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

  test('production preflight scans release xcconfig but ignores debug defaults',
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
  });

  test('production preflight rejects hardcoded iOS release branding settings',
      () {
    final root = Directory.systemTemp.createTempSync(
      'customer_flutter_preflight_ios_release_hardcode_',
    );
    try {
      _writeValidIosSecurityFixture(root);
      _writeFile(
        root,
        'ios/Flutter/Debug.xcconfig',
        '''
APP_DISPLAY_NAME=NewPaotang
CUSTOMER_FLUTTER_URL_SCHEME=newpaotang
CUSTOMER_FLUTTER_ASSOCIATED_DOMAIN=applinks:localhost
''',
      );
      _writeFile(
        root,
        'ios/Flutter/Release.xcconfig',
        '''
APP_DISPLAY_NAME=NewPaotang
CUSTOMER_FLUTTER_URL_SCHEME=newpaotang
CUSTOMER_FLUTTER_ASSOCIATED_DOMAIN=applinks:partner.example.com
''',
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

      expect(
        issues.map((issue) => issue.code),
        contains('ios_release_xcconfig_hardcoded'),
      );
    } finally {
      root.deleteSync(recursive: true);
    }
  });

  test('web production preflight allows same-origin API path', () {
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

    expect(issues, isEmpty);
  });

  test('web production preflight rejects default scaffold metadata', () {
    final root = Directory.systemTemp.createTempSync(
      'customer_flutter_preflight_web_metadata_',
    );
    try {
      _writeFile(
        root,
        'web/index.html',
        '''
<html>
  <head>
    <meta name="description" content="A new Flutter project.">
    <meta name="apple-mobile-web-app-title" content="customer_flutter">
    <title>customer_flutter</title>
    <link rel="manifest" href="manifest.json">
  </head>
  <body></body>
</html>
''',
      );
      _writeFile(
        root,
        'web/manifest.json',
        '''
{
  "name": "customer_flutter",
  "short_name": "customer_flutter",
  "description": "A new Flutter project."
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

  test('android release build requires explicit signing or local smoke opt-in',
      () {
    final source = File('android/app/build.gradle.kts').readAsStringSync();

    expect(
      source,
      contains('CUSTOMER_FLUTTER_ALLOW_DEBUG_RELEASE_SIGNING'),
    );
    expect(source, contains('Release signing inputs are required'));
    expect(source, contains('allowDebugReleaseSigning'));
    expect(source, contains('releaseTaskRequested'));
    expect(source, contains('hasReleaseSigning -> signingConfigs'));
    expect(source, contains('allowDebugReleaseSigning -> signingConfigs'));
    expect(source, contains('!releaseTaskRequested -> signingConfigs'));
  });

  test('android release build requires partner runtime config unless smoke',
      () {
    final source = File('android/app/build.gradle.kts').readAsStringSync();

    expect(source, contains('Partner release config is required'));
    expect(source, contains('requireReleaseValue'));
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

    expect(
      issues.map((issue) => issue.code),
      contains('ios_team_id_invalid'),
    );
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
        socialAuthProviders: ['line', 'google'],
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
        socialAuthProviders: ['LINE', 'google', 'apple', 'google'],
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

void _writeValidIosSecurityFixture(Directory root) {
  _writeFile(
    root,
    'ios/Runner/Info.plist',
    r'''
<plist>
  <dict>
    <key>CFBundleDisplayName</key>
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
''',
  );
  _writeFile(
    root,
    'ios/Runner/Runner.entitlements',
    r'''
<plist>
  <dict>
    <key>com.apple.developer.associated-domains</key>
    <array><string>$(CUSTOMER_FLUTTER_ASSOCIATED_DOMAIN)</string></array>
  </dict>
</plist>
''',
  );
  _writeFile(
    root,
    'ios/Runner/AppDelegate.swift',
    '''
class AppDelegate {
  let screen = "customer_flutter/screen_security"
  let screenshot = "UIApplication.userDidTakeScreenshotNotification"
  let captureChanged = "UIScreen.capturedDidChangeNotification"
  let captured = "UIScreen.main.isCaptured"
  let willResign = "UIApplication.willResignActiveNotification"
  let didBecome = "UIApplication.didBecomeActiveNotification"
  let hideSnapshot = "applicationWillHideSensitiveSnapshot"
  let restoreSnapshot = "applicationDidReturnFromSensitiveSnapshot"
  let overlay = "showPrivacyOverlay"
  let event = "securityEvent"
  let biometric = "customer_flutter/biometric_keys"
  let accessible = "kSecAttrAccessibleWhenUnlockedThisDeviceOnly"
  let currentSet = "biometryCurrentSet"
  let sign = "SecKeyCreateSignature"
  let runtimeNamespace = "Bundle.main.bundleIdentifier"
}
''',
  );
  _writeFile(
    root,
    'ios/Runner.xcodeproj/project.pbxproj',
    r'''
CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;
Validate Release Config
scripts/validate_release_config.sh
PRODUCT_BUNDLE_IDENTIFIER = "$(CUSTOMER_FLUTTER_IOS_BUNDLE_ID)";
DEVELOPMENT_TEAM = "$(CUSTOMER_FLUTTER_IOS_TEAM_ID)";
''',
  );
  _writeFile(
    root,
    'ios/scripts/validate_release_config.sh',
    '''
require_value "APP_DISPLAY_NAME"
require_value "CUSTOMER_FLUTTER_URL_SCHEME"
require_value "CUSTOMER_FLUTTER_ASSOCIATED_DOMAIN"
require_value "PRODUCT_BUNDLE_IDENTIFIER"
require_value "DEVELOPMENT_TEAM"
com.newpaotang.customerFlutter
''',
  );
}
