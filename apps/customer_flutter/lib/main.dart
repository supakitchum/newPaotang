import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/customer_app.dart';
import 'core/auth/auth_token_store.dart';
import 'core/config/app_config.dart';
import 'core/navigation/web_runtime.dart';
import 'core/tenant/customer_tenant_host.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('th_TH');
  await initializeDateFormatting('en_US');
  final appConfig = AppConfig.fromEnvironment();
  final authTokenStore = AuthTokenStore(
    storageScope: resolveCustomerTenantHost(
      currentHost: currentWebHost,
      configuredTenantHost: appConfig.normalizedTenantHost,
      apiBaseUrl: appConfig.apiBaseUrl,
    ),
  );
  await authTokenStore.restore();
  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(appConfig),
        authTokenStoreProvider.overrideWithValue(authTokenStore),
      ],
      child: const CustomerApp(),
    ),
  );
}
