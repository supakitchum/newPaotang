import 'dart:io';

import 'src/production_preflight.dart';

void main(List<String> args) {
  final options = _parseArgs(args);
  if (options.flag('help')) {
    _printUsage();
    return;
  }

  final target = _targetFrom(
    options.value('target') ??
        Platform.environment['CUSTOMER_FLUTTER_PREFLIGHT_TARGET'] ??
        'all',
  );
  final input = ProductionPreflightInput(
    target: target,
    production: !options.flag('allow-dev'),
    checkFiles: options.flag('check-files'),
    androidRequireSigning:
        !options.flag('skip-android-signing') && target.includesAndroid,
    projectRoot:
        options.value('project-root') ??
        Platform.environment['CUSTOMER_FLUTTER_PROJECT_ROOT'] ??
        '.',
    apiBaseUrl:
        options.value('api-base-url') ??
        Platform.environment['API_BASE_URL'] ??
        '/api/v1',
    appDisplayName:
        options.value('app-display-name') ??
        Platform.environment['CUSTOMER_FLUTTER_APP_LABEL'] ??
        Platform.environment['CUSTOMER_FLUTTER_APP_DISPLAY_NAME'] ??
        Platform.environment['APP_DISPLAY_NAME'],
    androidPackage:
        options.value('android-package') ??
        Platform.environment['CUSTOMER_FLUTTER_APPLICATION_ID'],
    androidCallbackScheme:
        options.value('android-callback-scheme') ??
        Platform.environment['CUSTOMER_FLUTTER_AUTH_CALLBACK_SCHEME'],
    androidCallbackHost:
        options.value('android-callback-host') ??
        Platform.environment['CUSTOMER_FLUTTER_AUTH_CALLBACK_HOST'],
    androidStoreFile:
        options.value('android-store-file') ??
        Platform.environment['CUSTOMER_FLUTTER_STORE_FILE'],
    androidStorePassword:
        options.value('android-store-password') ??
        Platform.environment['CUSTOMER_FLUTTER_STORE_PASSWORD'],
    androidKeyAlias:
        options.value('android-key-alias') ??
        Platform.environment['CUSTOMER_FLUTTER_KEY_ALIAS'],
    androidKeyPassword:
        options.value('android-key-password') ??
        Platform.environment['CUSTOMER_FLUTTER_KEY_PASSWORD'],
    tenantHost:
        options.value('tenant-host') ?? Platform.environment['TENANT_HOST'],
    iosTeamId:
        options.value('ios-team-id') ??
        Platform.environment['CUSTOMER_FLUTTER_IOS_TEAM_ID'],
    iosBundleId:
        options.value('ios-bundle-id') ??
        Platform.environment['CUSTOMER_FLUTTER_IOS_BUNDLE_ID'],
    iosUrlScheme:
        options.value('ios-url-scheme') ??
        Platform.environment['CUSTOMER_FLUTTER_IOS_URL_SCHEME'] ??
        Platform.environment['CUSTOMER_FLUTTER_URL_SCHEME'],
    iosAssociatedDomain:
        options.value('ios-associated-domain') ??
        Platform.environment['CUSTOMER_FLUTTER_IOS_ASSOCIATED_DOMAIN'] ??
        Platform.environment['CUSTOMER_FLUTTER_ASSOCIATED_DOMAIN'],
    socialAuthProviders: options.values('social-provider').isEmpty
        ? _splitCsv(Platform.environment['CUSTOMER_FLUTTER_SOCIAL_PROVIDERS'])
        : options.values('social-provider').expand(_splitCsv).toList(),
    linkAssociationDir:
        options.value('link-association-dir') ??
        Platform.environment['CUSTOMER_FLUTTER_LINK_ASSOCIATION_DIR'],
    webAppName:
        options.value('web-app-name') ??
        Platform.environment['CUSTOMER_FLUTTER_WEB_APP_NAME'],
    webShortName:
        options.value('web-short-name') ??
        Platform.environment['CUSTOMER_FLUTTER_WEB_SHORT_NAME'],
    webDescription:
        options.value('web-description') ??
        Platform.environment['CUSTOMER_FLUTTER_WEB_DESCRIPTION'],
    requireStoreListingMetadata:
        options.flag('require-store-listing-metadata') ||
        _envFlag(
          Platform
              .environment['CUSTOMER_FLUTTER_REQUIRE_STORE_LISTING_METADATA'],
        ),
    storePrivacyPolicyUrl:
        options.value('store-privacy-policy-url') ??
        Platform.environment['CUSTOMER_FLUTTER_STORE_PRIVACY_POLICY_URL'],
    storeSupportUrl:
        options.value('store-support-url') ??
        Platform.environment['CUSTOMER_FLUTTER_STORE_SUPPORT_URL'],
    storeAccountDeletionUrl:
        options.value('store-account-deletion-url') ??
        Platform.environment['CUSTOMER_FLUTTER_STORE_ACCOUNT_DELETION_URL'],
    requireReleaseBranding:
        options.flag('require-release-branding') ||
        _envFlag(
          Platform.environment['CUSTOMER_FLUTTER_REQUIRE_RELEASE_BRANDING'],
        ),
    releaseBrandingManifest:
        options.value('release-branding-manifest') ??
        Platform.environment['CUSTOMER_FLUTTER_RELEASE_BRANDING_MANIFEST'],
  );

  final issues = runCustomerFlutterProductionPreflight(input);
  if (issues.isEmpty) {
    stdout.writeln('Customer Flutter production preflight passed.');
    return;
  }

  stderr.writeln('Customer Flutter production preflight failed:');
  for (final issue in issues) {
    stderr.writeln('- ${issue.code}: ${issue.message}');
  }
  exitCode = 1;
}

CustomerFlutterTarget _targetFrom(String raw) {
  final normalized = raw.trim().toLowerCase();
  for (final target in CustomerFlutterTarget.values) {
    if (target.name == normalized) return target;
  }
  throw ArgumentError.value(raw, 'target', 'must be web, android, ios, or all');
}

_Options _parseArgs(List<String> args) {
  final values = <String, List<String>>{};
  final flags = <String>{};

  for (var index = 0; index < args.length; index++) {
    final arg = args[index];
    if (!arg.startsWith('--')) continue;

    final body = arg.substring(2);
    if (body.contains('=')) {
      final parts = body.split('=');
      final key = parts.first;
      final value = parts.sublist(1).join('=');
      values.putIfAbsent(key, () => []).add(value);
      continue;
    }

    final next = index + 1 < args.length ? args[index + 1] : null;
    if (next != null && !next.startsWith('--')) {
      values.putIfAbsent(body, () => []).add(next);
      index++;
    } else {
      flags.add(body);
    }
  }

  return _Options(values, flags);
}

void _printUsage() {
  stdout.writeln('''
Validate production inputs for customer_flutter.

Usage:
  dart run tool/production_preflight.dart \\
    --target all \\
    --project-root apps/customer_flutter \\
    --api-base-url https://partner.example.com/api/v1 \\
    --app-display-name "Partner Lottery" \\
    --android-package com.partner.customer \\
    --android-callback-scheme partnerlottery \\
    --android-callback-host partner.example.com \\
    --android-store-file /secure/release.jks \\
    --android-store-password "***" \\
    --android-key-alias release \\
    --android-key-password "***" \\
    --tenant-host partner.example.com \\
    --ios-team-id ABCDE12345 \\
    --ios-bundle-id com.partner.customer \\
    --ios-url-scheme partnerlottery \\
    --ios-associated-domain applinks:partner.example.com \\
    --link-association-dir build/link-association \\
    --web-app-name "Partner Lottery" \\
    --web-short-name "Partner" \\
    --web-description "Partner digital lottery customer portal" \\
    --require-store-listing-metadata \\
    --store-privacy-policy-url https://partner.example.com/privacy \\
    --store-support-url https://partner.example.com/support \\
    --store-account-deletion-url https://partner.example.com/account-deletion \\
    --require-release-branding \\
    --release-branding-manifest release/branding.json \\
    --social-provider line \\
    --social-provider google \\
    --social-provider apple

Options:
  --target web|android|ios|all
  --project-root PATH      customer_flutter project directory for --check-files.
  --allow-dev             Allow development values such as relative API paths.
  --skip-android-signing  Do not require Android release signing inputs.
  --check-files           Verify checked-in native/web/security/release gates.
  --require-release-branding
                          Require generated partner icon hashes for store artifacts.

Environment alternatives:
  API_BASE_URL
  CUSTOMER_FLUTTER_APP_DISPLAY_NAME
  CUSTOMER_FLUTTER_APP_LABEL
  APP_DISPLAY_NAME
  CUSTOMER_FLUTTER_PROJECT_ROOT
  CUSTOMER_FLUTTER_APPLICATION_ID
  CUSTOMER_FLUTTER_AUTH_CALLBACK_SCHEME
  CUSTOMER_FLUTTER_AUTH_CALLBACK_HOST
  CUSTOMER_FLUTTER_STORE_FILE
  CUSTOMER_FLUTTER_STORE_PASSWORD
  CUSTOMER_FLUTTER_KEY_ALIAS
  CUSTOMER_FLUTTER_KEY_PASSWORD
  TENANT_HOST
  CUSTOMER_FLUTTER_IOS_TEAM_ID
  CUSTOMER_FLUTTER_IOS_BUNDLE_ID
  CUSTOMER_FLUTTER_IOS_URL_SCHEME
  CUSTOMER_FLUTTER_IOS_ASSOCIATED_DOMAIN
  CUSTOMER_FLUTTER_URL_SCHEME
  CUSTOMER_FLUTTER_ASSOCIATED_DOMAIN
  CUSTOMER_FLUTTER_SOCIAL_PROVIDERS
  CUSTOMER_FLUTTER_LINK_ASSOCIATION_DIR
  CUSTOMER_FLUTTER_WEB_APP_NAME
  CUSTOMER_FLUTTER_WEB_SHORT_NAME
  CUSTOMER_FLUTTER_WEB_DESCRIPTION
  CUSTOMER_FLUTTER_REQUIRE_STORE_LISTING_METADATA
  CUSTOMER_FLUTTER_STORE_PRIVACY_POLICY_URL
  CUSTOMER_FLUTTER_STORE_SUPPORT_URL
  CUSTOMER_FLUTTER_STORE_ACCOUNT_DELETION_URL
  CUSTOMER_FLUTTER_REQUIRE_RELEASE_BRANDING
  CUSTOMER_FLUTTER_RELEASE_BRANDING_MANIFEST
''');
}

List<String> _splitCsv(String? value) {
  if (value == null || value.trim().isEmpty) return const [];
  return value
      .split(',')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();
}

bool _envFlag(String? value) {
  final normalized = value?.trim().toLowerCase() ?? '';
  return {
    '1',
    'true',
    'yes',
    'y',
    'on',
    'enabled',
    'require',
    'required',
  }.contains(normalized);
}

class _Options {
  const _Options(this._values, this._flags);

  final Map<String, List<String>> _values;
  final Set<String> _flags;

  bool flag(String key) => _flags.contains(key);

  String? value(String key) => _values[key]?.last;

  List<String> values(String key) => _values[key] ?? const [];
}
