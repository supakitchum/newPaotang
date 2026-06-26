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
      ),
    );

    expect(issues, isEmpty);
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
          'android_screen_security_channel_missing',
          'android_biometric_channel_missing',
          'ios_face_id_usage_missing',
          'ios_xcconfig_missing',
          'ios_screen_capture_detection_missing',
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
        socialAuthProviders: ['line', 'google', 'apple'],
      ),
    );

    expect(
      issues.map((issue) => issue.code),
      isNot(contains('ios_sign_in_with_apple_required')),
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
    'CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;',
  );
}
