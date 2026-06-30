import 'package:customer_flutter/core/auth/auth_controller.dart';
import 'package:customer_flutter/core/auth/auth_repository.dart';
import 'package:customer_flutter/core/auth/auth_token_store.dart';
import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/i18n/app_locale.dart';
import 'package:customer_flutter/core/i18n/customer_localizations.dart';
import 'package:customer_flutter/core/network/api_client.dart';
import 'package:customer_flutter/core/security/biometric_auth_service.dart';
import 'package:customer_flutter/core/tenant/mobile_bootstrap_controller.dart';
import 'package:customer_flutter/features/affiliate/data/affiliate_referral_repository.dart';
import 'package:customer_flutter/features/auth/presentation/login_screen.dart';
import 'package:customer_flutter/features/auth/presentation/register_screen.dart';
import 'package:customer_flutter/features/monitoring/data/public_visit_id_store.dart';
import 'package:customer_flutter/features/pin/presentation/pin_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('login preserves checkout redirect after password auth', (
    tester,
  ) async {
    final repo = _AuthRedirectRepository(
      loginSession: const CustomerSession(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
        pinRequired: false,
        pinSetupRequired: false,
        customerId: 'cus_login',
      ),
    );
    final router = _authRouter('/login?redirect=%2Fcheckout');

    await tester.pumpWidget(_testApp(router: router, repo: repo));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), '0812345678');
    await tester.enterText(find.byType(TextField).at(1), 'secret1234');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(repo.lastLoginUsername, '0812345678');
    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/checkout',
    );
    expect(find.text('checkout-flow'), findsOneWidget);
  });

  testWidgets('login sends PIN-required sessions to PIN with redirect', (
    tester,
  ) async {
    final repo = _AuthRedirectRepository(
      loginSession: const CustomerSession(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
        pinRequired: true,
        pinSetupRequired: false,
        customerId: 'cus_pin',
      ),
    );
    final router = _authRouter('/login?redirect=%2Fcheckout');

    await tester.pumpWidget(_testApp(router: router, repo: repo));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), '0812345678');
    await tester.enterText(find.byType(TextField).at(1), 'secret1234');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/pin?redirect=%2Fcheckout',
    );
    expect(find.text('pin-flow'), findsOneWidget);
  });

  testWidgets('register login link preserves checkout redirect', (
    tester,
  ) async {
    final repo = _AuthRedirectRepository();
    final router = _authRouter('/register?redirect=%2Fcheckout');

    await tester.pumpWidget(_testApp(router: router, repo: repo));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Already have an account? Sign in'));
    await tester.tap(find.text('Already have an account? Sign in'));
    await tester.pumpAndSettle();

    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/login?redirect=%2Fcheckout',
    );
  });

  testWidgets('PIN verification returns to the saved checkout redirect', (
    tester,
  ) async {
    final repo = _AuthRedirectRepository();
    final router = GoRouter(
      initialLocation: '/pin?redirect=%2Fcheckout',
      routes: [
        GoRoute(path: '/pin', builder: (context, state) => const PinScreen()),
        GoRoute(
          path: '/checkout',
          builder: (context, state) => const Text(
            'checkout-flow',
            textDirection: TextDirection.ltr,
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      _testApp(
        router: router,
        repo: repo,
        authenticated: true,
        pinRequired: true,
      ),
    );
    await tester.pumpAndSettle();

    for (final digit in '123456'.split('')) {
      await tester.tap(find.text(digit));
      await tester.pumpAndSettle();
    }

    expect(repo.lastVerifiedPin, '123456');
    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/checkout',
    );
    expect(find.text('checkout-flow'), findsOneWidget);
  });
}

Widget _testApp({
  required GoRouter router,
  required _AuthRedirectRepository repo,
  bool authenticated = false,
  bool pinRequired = false,
}) {
  final tokenStore = AuthTokenStore();
  final api = ApiClient(_testConfig, tokenStore, localeTag: 'en-US');
  final controller = AuthController(
    authRepository: repo,
    tokenStore: tokenStore,
    biometricAuth: BiometricAuthService(api),
  )
    ..isAuthenticated = authenticated
    ..pinRequired = pinRequired
    ..pinSetupRequired = false;

  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(repo),
      authControllerProvider.overrideWith((_) => controller),
      affiliateReferralServiceProvider.overrideWithValue(
        _NoopAffiliateReferralService(),
      ),
      mobileBootstrapProvider.overrideWith(
        (_) async => MobileBootstrap.fromJson(const {
          'site': {'display_name': 'Test Shop', 'locale': 'en-US'},
          'mobile': {
            'auth_providers': [],
            'feature_flags': {'native_biometric_unlock': false},
          },
        }),
      ),
    ],
    child: MaterialApp.router(
      locale: const Locale('en', 'US'),
      supportedLocales: supportedCustomerLocales,
      localizationsDelegates: const [
        CustomerLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    ),
  );
}

GoRouter _authRouter(String initialLocation) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/pin',
        builder: (context, state) => const Text(
          'pin-flow',
          textDirection: TextDirection.ltr,
        ),
      ),
      GoRoute(
        path: '/checkout',
        builder: (context, state) => const Text(
          'checkout-flow',
          textDirection: TextDirection.ltr,
        ),
      ),
    ],
  );
}

const _testConfig = AppConfig(
  apiBaseUrl: 'https://partner.example.com/api/v1',
  defaultLocale: 'en-US',
);

class _AuthRedirectRepository extends AuthRepository {
  _AuthRedirectRepository({
    this.loginSession = const CustomerSession(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      pinRequired: false,
      pinSetupRequired: false,
      customerId: 'cus_default',
    ),
  }) : super(
          api: ApiClient(_testConfig, AuthTokenStore(), localeTag: 'en-US'),
          tokenStore: AuthTokenStore(),
        );

  final CustomerSession loginSession;
  String lastLoginUsername = '';
  String lastVerifiedPin = '';

  @override
  Future<CustomerSession> login({
    required String username,
    required String password,
  }) async {
    lastLoginUsername = username;
    return loginSession;
  }

  @override
  Future<PinStatus> pinStatus() async {
    return const PinStatus(
      hasPin: true,
      pinVerified: false,
      pinRequired: true,
      pinSetupRequired: false,
    );
  }

  @override
  Future<void> verifyPin(String pin) async {
    lastVerifiedPin = pin;
  }
}

class _NoopAffiliateReferralService extends AffiliateReferralService {
  _NoopAffiliateReferralService()
      : super(
          config: _testConfig,
          repository: AffiliateReferralRepository(
            ApiClient(_testConfig, AuthTokenStore(), localeTag: 'en-US'),
          ),
          store: AffiliateReferralStore(),
          visitIdStore: PublicVisitIdStore(idFactory: (_) => 'visitor'),
        );

  @override
  Future<void> applyStored({bool registered = false}) async {}
}
