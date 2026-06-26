import 'package:customer_flutter/app/customer_app.dart';
import 'package:customer_flutter/app/router.dart';
import 'package:customer_flutter/core/auth/auth_controller.dart';
import 'package:customer_flutter/core/auth/auth_repository.dart';
import 'package:customer_flutter/core/auth/auth_token_store.dart';
import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/i18n/customer_localizations.dart';
import 'package:customer_flutter/core/network/api_client.dart';
import 'package:customer_flutter/core/security/biometric_auth_service.dart';
import 'package:customer_flutter/core/tenant/mobile_bootstrap_controller.dart';
import 'package:customer_flutter/core/tenant/mobile_runtime_policy.dart';
import 'package:customer_flutter/features/monitoring/presentation/public_visit_monitor.dart';
import 'package:customer_flutter/features/news/data/news_models.dart';
import 'package:customer_flutter/features/news/data/news_repository.dart';
import 'package:customer_flutter/features/pin/presentation/pin_screen.dart';
import 'package:customer_flutter/shared/widgets/app_shell.dart';
import 'package:customer_flutter/shared/widgets/sensitive_screen_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('CustomerApp enables root screen security for every route',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(
              apiBaseUrl: 'https://partner.example.com/api/v1',
              defaultLocale: 'th-TH',
            ),
          ),
          authTokenStoreProvider.overrideWithValue(AuthTokenStore()),
          newsRepositoryProvider.overrideWithValue(_NoopNewsRepository()),
          publicVisitMonitorEnabledProvider.overrideWithValue(false),
          customerPlatformKeyProvider.overrideWithValue('android'),
          mobileBootstrapProvider.overrideWith(
            (_) async => MobileBootstrap.fromJson(
              {
                'site': {
                  'display_name': 'Test Shop',
                  'locale': 'th-TH',
                },
              },
            ),
          ),
          appRouterProvider.overrideWithValue(
            GoRouter(
              routes: [
                GoRoute(
                  path: '/',
                  builder: (context, state) => const Text('Root route'),
                ),
              ],
            ),
          ),
        ],
        child: const CustomerApp(),
      ),
    );

    await tester.pump();

    expect(find.byType(SensitiveScreenGuard), findsOneWidget);
    expect(
      tester
          .widget<SensitiveScreenGuard>(find.byType(SensitiveScreenGuard))
          .enabled,
      isTrue,
    );
    expect(find.text('Root route'), findsOneWidget);
  });

  testWidgets('CustomerApp disables native screen security on web platform',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(
              apiBaseUrl: 'https://partner.example.com/api/v1',
              defaultLocale: 'th-TH',
            ),
          ),
          authTokenStoreProvider.overrideWithValue(AuthTokenStore()),
          newsRepositoryProvider.overrideWithValue(_NoopNewsRepository()),
          publicVisitMonitorEnabledProvider.overrideWithValue(false),
          customerPlatformKeyProvider.overrideWithValue('web'),
          mobileBootstrapProvider.overrideWith(
            (_) async => MobileBootstrap.fromJson(
              {
                'site': {
                  'display_name': 'Test Shop',
                  'locale': 'th-TH',
                },
                'mobile': {
                  'screen_security': {
                    'android': {'flag_secure': true},
                    'ios': {'screen_capture_overlay': true},
                  },
                  'feature_flags': {'screen_security_native': true},
                },
              },
            ),
          ),
          appRouterProvider.overrideWithValue(
            GoRouter(
              routes: [
                GoRoute(
                  path: '/',
                  builder: (context, state) => const Text('Root route'),
                ),
              ],
            ),
          ),
        ],
        child: const CustomerApp(),
      ),
    );

    await tester.pump();

    final guard = tester.widget<SensitiveScreenGuard>(
      find.byType(SensitiveScreenGuard),
    );
    expect(guard.enabled, isFalse);
    expect(find.text('Root route'), findsOneWidget);
  });

  testWidgets('CustomerApp honors bootstrap screen security feature flag',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(
              apiBaseUrl: 'https://partner.example.com/api/v1',
              defaultLocale: 'th-TH',
            ),
          ),
          authTokenStoreProvider.overrideWithValue(AuthTokenStore()),
          newsRepositoryProvider.overrideWithValue(_NoopNewsRepository()),
          publicVisitMonitorEnabledProvider.overrideWithValue(false),
          mobileBootstrapProvider.overrideWith(
            (_) async => MobileBootstrap.fromJson(
              {
                'site': {
                  'display_name': 'Test Shop',
                  'locale': 'th-TH',
                },
                'mobile': {
                  'feature_flags': {'screen_security_native': false},
                },
              },
            ),
          ),
          appRouterProvider.overrideWithValue(
            GoRouter(
              routes: [
                GoRoute(
                  path: '/',
                  builder: (context, state) => const Text('Root route'),
                ),
              ],
            ),
          ),
        ],
        child: const CustomerApp(),
      ),
    );

    await tester.pump();

    final guard = tester.widget<SensitiveScreenGuard>(
      find.byType(SensitiveScreenGuard),
    );
    expect(guard.enabled, isFalse);
    expect(find.text('Root route'), findsOneWidget);
  });

  testWidgets('PinScreen hides biometric unlock when tenant policy disables it',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith((_) => _testAuthController()),
          mobileBootstrapProvider.overrideWith(
            (_) async => MobileBootstrap.fromJson(
              {
                'mobile': {
                  'feature_flags': {'native_biometric_unlock': false},
                },
              },
            ),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('en', 'US'),
          supportedLocales: [Locale('th', 'TH'), Locale('en', 'US')],
          localizationsDelegates: [
            CustomerLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          home: PinScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Use Face ID / Biometric'), findsNothing);
    expect(find.text('Forgot PIN?'), findsOneWidget);
  });

  testWidgets('PinScreen hides native biometric unlock on web platform',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith((_) => _testAuthController()),
          customerPlatformKeyProvider.overrideWithValue('web'),
          mobileBootstrapProvider.overrideWith(
            (_) async => MobileBootstrap.fromJson(
              {
                'mobile': {
                  'biometric': {
                    'enabled': true,
                    'platforms': {
                      'ios': ['face_id'],
                      'android': ['biometric_prompt'],
                    },
                  },
                  'feature_flags': {'native_biometric_unlock': true},
                },
              },
            ),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('en', 'US'),
          supportedLocales: [Locale('th', 'TH'), Locale('en', 'US')],
          localizationsDelegates: [
            CustomerLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          home: PinScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Use Face ID / Biometric'), findsNothing);
    expect(find.text('Forgot PIN?'), findsOneWidget);
  });

  testWidgets('PinScreen switches to setup mode when customer has no PIN',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            (_) => _testAuthController(pinSetupRequired: true),
          ),
          mobileBootstrapProvider.overrideWith(
            (_) async => MobileBootstrap.fromJson(
              {
                'mobile': {
                  'biometric': {
                    'enabled': true,
                    'platforms': {
                      'ios': ['face_id'],
                      'android': ['biometric_prompt'],
                    },
                  },
                  'feature_flags': {'native_biometric_unlock': true},
                },
              },
            ),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('en', 'US'),
          supportedLocales: [Locale('th', 'TH'), Locale('en', 'US')],
          localizationsDelegates: [
            CustomerLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          home: PinScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Set 6-digit PIN'), findsOneWidget);
    expect(find.text('Use Face ID / Biometric'), findsNothing);
    expect(find.text('Forgot PIN?'), findsNothing);
  });

  testWidgets('AppShell leaves capture protection to the root guard',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AppShell(
          title: 'Secure',
          currentPath: '/tickets',
          sensitive: true,
          child: Text('Secure content'),
        ),
      ),
    );

    expect(find.byType(SensitiveScreenGuard), findsNothing);
    expect(find.text('Secure content'), findsOneWidget);
  });

  testWidgets('public AppShell pages are still renderable under root policy',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AppShell(
          title: 'Public',
          currentPath: '/news',
          child: Text('Public content'),
        ),
      ),
    );

    expect(find.byType(SensitiveScreenGuard), findsNothing);
    expect(find.text('Public content'), findsOneWidget);
  });
}

class _NoopNewsRepository extends NewsRepository {
  _NoopNewsRepository()
      : super(
          ApiClient(
            const AppConfig(
              apiBaseUrl: 'https://partner.example.com/api/v1',
              defaultLocale: 'th-TH',
            ),
            AuthTokenStore(),
            localeTag: 'th-TH',
          ),
          (value) => value,
        );

  @override
  Future<NewsItem?> modal() async => null;
}

AuthController _testAuthController({bool pinSetupRequired = false}) {
  final tokenStore = AuthTokenStore();
  final api = ApiClient(
    const AppConfig(
      apiBaseUrl: 'https://partner.example.com/api/v1',
      defaultLocale: 'en-US',
    ),
    tokenStore,
    localeTag: 'en-US',
  );

  return AuthController(
    authRepository: AuthRepository(api: api, tokenStore: tokenStore),
    tokenStore: tokenStore,
    biometricAuth: BiometricAuthService(api),
  )
    ..pinRequired = true
    ..pinSetupRequired = pinSetupRequired;
}
