import 'dart:async';

import 'package:customer_flutter/app/customer_app.dart';
import 'package:customer_flutter/app/router.dart';
import 'package:customer_flutter/core/auth/auth_controller.dart';
import 'package:customer_flutter/core/auth/auth_repository.dart';
import 'package:customer_flutter/core/auth/auth_token_store.dart';
import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/i18n/customer_localizations.dart';
import 'package:customer_flutter/core/network/api_client.dart';
import 'package:customer_flutter/core/security/biometric_auth_service.dart';
import 'package:customer_flutter/core/security/screen_security_service.dart';
import 'package:customer_flutter/core/tenant/mobile_bootstrap_controller.dart';
import 'package:customer_flutter/core/tenant/mobile_runtime_policy.dart';
import 'package:customer_flutter/features/monitoring/presentation/public_visit_monitor.dart';
import 'package:customer_flutter/features/news/data/news_models.dart';
import 'package:customer_flutter/features/news/data/news_repository.dart';
import 'package:customer_flutter/features/results/data/result_models.dart';
import 'package:customer_flutter/features/results/data/result_repository.dart';
import 'package:customer_flutter/features/pin/presentation/pin_screen.dart';
import 'package:customer_flutter/shared/widgets/app_shell.dart';
import 'package:customer_flutter/shared/widgets/sensitive_screen_guard.dart';
import 'package:customer_flutter/shared/widgets/web_privacy_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ScreenSecurityService sends localized overlay copy to native',
      (tester) async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('customer_flutter/screen_security'),
      (call) async {
        calls.add(call);
        return null;
      },
    );
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('customer_flutter/screen_security'),
        null,
      );
    });

    final service = ScreenSecurityService();
    await service.enable(
      route: '/tickets',
      overlayTitle: 'Screen capture is not allowed',
      overlayDescription: 'Sensitive information is hidden.',
    );

    expect(calls, hasLength(1));
    expect(calls.single.method, 'enable');
    expect(calls.single.arguments, {
      'route': '/tickets',
      'overlay_title': 'Screen capture is not allowed',
      'overlay_description': 'Sensitive information is hidden.',
    });
  });

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
          resultRepositoryProvider.overrideWithValue(_NoopResultRepository()),
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

  testWidgets('SensitiveScreenGuard locks session on native capture events',
      (tester) async {
    final authController = _testAuthController()..pinRequired = false;
    final screenSecurity = _FakeScreenSecurityService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith((_) => authController),
          screenSecurityServiceProvider.overrideWithValue(screenSecurity),
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
          home: SensitiveScreenGuard(
            route: '/tickets',
            child: Text('Ticket detail'),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(screenSecurity.enabledRoute, '/tickets');
    expect(authController.pinRequired, isFalse);

    screenSecurity.emit(
      const ScreenSecurityEvent(
        event: 'screenshot_detected',
        route: '/tickets',
        reason: 'screenshot',
      ),
    );
    await tester.pump();

    expect(authController.pinRequired, isTrue);
    expect(authController.isSecurityLocked, isTrue);
  });

  testWidgets(
      'CustomerApp disables native screen security and leaves public web routes uncovered',
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
          resultRepositoryProvider.overrideWithValue(_NoopResultRepository()),
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
    final webGuard = tester.widget<WebPrivacyGuard>(
      find.byType(WebPrivacyGuard),
    );
    expect(webGuard.enabled, isFalse);
    expect(find.text('Root route'), findsOneWidget);
  });

  testWidgets('CustomerApp enables web privacy guard on sensitive web routes',
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
          resultRepositoryProvider.overrideWithValue(_NoopResultRepository()),
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
                    'web': {'watermark_enabled': true},
                  },
                },
              },
            ),
          ),
          appRouterProvider.overrideWithValue(
            GoRouter(
              initialLocation: '/my-wallet',
              routes: [
                GoRoute(
                  path: '/my-wallet',
                  builder: (context, state) => const Text('Wallet route'),
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
    final webGuard = tester.widget<WebPrivacyGuard>(
      find.byType(WebPrivacyGuard),
    );
    expect(webGuard.enabled, isTrue);
    expect(find.text('Wallet route'), findsOneWidget);
  });

  testWidgets('CustomerApp can disable web privacy guard by tenant policy',
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
          resultRepositoryProvider.overrideWithValue(_NoopResultRepository()),
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
                    'web': {
                      'sensitive_screen_mode': 'off',
                      'watermark_enabled': false,
                    },
                  },
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

    final webGuard = tester.widget<WebPrivacyGuard>(
      find.byType(WebPrivacyGuard),
    );
    expect(webGuard.enabled, isFalse);
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
          resultRepositoryProvider.overrideWithValue(_NoopResultRepository()),
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

  @override
  Future<List<NewsItem>> list({int limit = NewsRepository.defaultPageLimit}) {
    return Future.value(const []);
  }

  @override
  Future<List<NewsItem>> listAll({
    int limit = NewsRepository.defaultPageLimit,
    int maxPages = NewsRepository.maxAutoPages,
  }) {
    return Future.value(const []);
  }
}

class _NoopResultRepository extends ResultRepository {
  _NoopResultRepository()
      : super(
          ApiClient(
            const AppConfig(
              apiBaseUrl: 'https://partner.example.com/api/v1',
              defaultLocale: 'th-TH',
            ),
            AuthTokenStore(),
            localeTag: 'th-TH',
          ),
        );

  @override
  Future<CurrentGame?> currentGame() async => null;

  @override
  Future<RewardResultGame?> latest({String? gameId, bool live = true}) async {
    return null;
  }

  @override
  Future<RewardResultBundle> current({String? gameId}) async {
    return const RewardResultBundle(
      currentGame: null,
      selectedResult: null,
      history: [],
    );
  }
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

class _FakeScreenSecurityService extends ScreenSecurityService {
  final StreamController<ScreenSecurityEvent> _controller =
      StreamController<ScreenSecurityEvent>.broadcast();
  String enabledRoute = '';
  bool disabled = false;

  @override
  Stream<ScreenSecurityEvent> get events => _controller.stream;

  @override
  Future<void> enable({
    required String route,
    String? overlayTitle,
    String? overlayDescription,
  }) async {
    enabledRoute = route;
    disabled = false;
  }

  @override
  Future<void> disable() async {
    disabled = true;
  }

  void emit(ScreenSecurityEvent event) => _controller.add(event);
}
