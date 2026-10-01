import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../i18n/app_locale.dart';
import '../tenant/customer_tenant_host.dart';

final appConfigProvider = Provider<AppConfig>(
  (_) => throw StateError('AppConfig is not initialized.'),
);

class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    required this.defaultLocale,
    this.appDisplayName = 'Customer',
    this.tenantHost = '',
  });

  factory AppConfig.fromEnvironment() {
    return const AppConfig(
      apiBaseUrl: String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: '/api/v1',
      ),
      defaultLocale: String.fromEnvironment(
        'APP_LOCALE',
        defaultValue: 'th-TH',
      ),
      appDisplayName: _customerFlutterAppDisplayName == ''
          ? _appDisplayName
          : _customerFlutterAppDisplayName,
      tenantHost: String.fromEnvironment('TENANT_HOST'),
    );
  }

  static const _customerFlutterAppDisplayName = String.fromEnvironment(
    'CUSTOMER_FLUTTER_APP_DISPLAY_NAME',
  );
  static const _appDisplayName = String.fromEnvironment(
    'APP_DISPLAY_NAME',
    defaultValue: 'Customer',
  );

  final String apiBaseUrl;
  final String defaultLocale;
  final String appDisplayName;
  final String tenantHost;

  String get defaultLocaleTag => localeTag(parseCustomerLocale(defaultLocale));
  String get runtimeDisplayName => appDisplayName.trim().isEmpty
      ? _appDisplayName.trim().isEmpty
          ? 'Customer'
          : _appDisplayName.trim()
      : appDisplayName.trim();
  String get normalizedTenantHost => normalizeCustomerTenantHost(tenantHost);
}
