import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/customer_app.dart';
import 'core/auth/auth_token_store.dart';
import 'core/config/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('th_TH');
  await initializeDateFormatting('en_US');
  final authTokenStore = AuthTokenStore();
  await authTokenStore.restore();
  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(AppConfig.fromEnvironment()),
        authTokenStoreProvider.overrideWithValue(authTokenStore),
      ],
      child: const CustomerApp(),
    ),
  );
}
