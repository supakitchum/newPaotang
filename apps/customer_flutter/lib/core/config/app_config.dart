import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../i18n/app_locale.dart';

final appConfigProvider = Provider<AppConfig>(
  (_) => throw StateError('AppConfig is not initialized.'),
);

class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    required this.defaultLocale,
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
      tenantHost: String.fromEnvironment('TENANT_HOST'),
    );
  }

  final String apiBaseUrl;
  final String defaultLocale;
  final String tenantHost;

  String get defaultLocaleTag => localeTag(parseCustomerLocale(defaultLocale));
  String get normalizedTenantHost => _normalizeTenantHost(tenantHost);

  static String _normalizeTenantHost(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.host.isNotEmpty) return uri.host;
    return trimmed.split('/').first.split(':').first;
  }
}
