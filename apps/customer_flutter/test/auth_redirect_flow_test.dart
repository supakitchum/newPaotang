import 'dart:async';

import 'package:customer_flutter/app/router.dart';
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
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  test('app router is not recreated by PIN status auth refresh', () async {
    final repo = _AuthRedirectRepository();
    final tokenStore = AuthTokenStore();
    final api = ApiClient(_testConfig, tokenStore, localeTag: 'en-US');
    final controller = AuthController(
      authRepository: repo,
      tokenStore: tokenStore,
      biometricAuth: BiometricAuthService(api),
    )
      ..isAuthenticated = true
      ..pinRequired = true;
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(repo),
        authControllerProvider.overrideWith((_) => controller),
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
    );
    addTearDown(container.dispose);

    final router = container.read(appRouterProvider);
    await controller.syncPinStatus();

    expect(container.read(appRouterProvider), same(router));
  });

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
    await _tapLoginSubmit(tester);
    await tester.pumpAndSettle();

    expect(repo.lastLoginUsername, '0812345678');
    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/checkout',
    );
    expect(find.text('checkout-flow'), findsOneWidget);
  });

  testWidgets('login phone input keeps Nuxt numeric 10-digit behavior', (
    tester,
  ) async {
    final repo = _AuthRedirectRepository();
    final router = _authRouter('/login?redirect=%2Fcheckout');

    await tester.pumpWidget(_testApp(router: router, repo: repo));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), '08a12345678999');
    await tester.enterText(find.byType(TextField).at(1), 'secret1234');
    await _tapLoginSubmit(tester);
    await tester.pumpAndSettle();

    expect(repo.lastLoginUsername, '0812345678');
    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/checkout',
    );
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
    await _tapLoginSubmit(tester);
    await tester.pumpAndSettle();

    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/pin?redirect=%2Fcheckout',
    );
    expect(find.text('pin-flow'), findsOneWidget);
  });

  testWidgets('login resumes inline PIN routes without global PIN redirect', (
    tester,
  ) async {
    final repo = _AuthRedirectRepository(
      loginSession: const CustomerSession(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
        pinRequired: true,
        pinSetupRequired: false,
        customerId: 'cus_affiliate',
      ),
    );
    final router = _authRouter('/login?redirect=%2Faffiliate');

    await tester.pumpWidget(_testApp(router: router, repo: repo));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), '0812345678');
    await tester.enterText(find.byType(TextField).at(1), 'secret1234');
    await _tapLoginSubmit(tester);
    await tester.pumpAndSettle();

    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/affiliate',
    );
    expect(find.text('affiliate-flow'), findsOneWidget);
  });

  testWidgets('login shows API error copy like Nuxt', (
    tester,
  ) async {
    final repo = _AuthRedirectRepository(
      loginError: _apiException(
        'เบอร์โทรศัพท์หรือรหัสผ่านไม่ถูกต้อง',
        path: '/customer/auth/login',
      ),
    );
    final router = _authRouter('/login?redirect=%2Fcheckout');

    await tester.pumpWidget(_testApp(router: router, repo: repo));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), '0812345678');
    await tester.enterText(find.byType(TextField).at(1), 'wrong-password');
    await _tapLoginSubmit(tester);
    await tester.pumpAndSettle();

    expect(
      find.text('เบอร์โทรศัพท์หรือรหัสผ่านไม่ถูกต้อง'),
      findsOneWidget,
    );
    expect(find.text('Could not sign in'), findsNothing);
    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/login?redirect=%2Fcheckout',
    );
  });

  testWidgets('login hides internal errors behind localized fallback', (
    tester,
  ) async {
    final repo = _AuthRedirectRepository(
      loginError: StateError('internal login failed'),
    );
    final router = _authRouter('/login?redirect=%2Fcheckout');

    await tester.pumpWidget(_testApp(router: router, repo: repo));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), '0812345678');
    await tester.enterText(find.byType(TextField).at(1), 'secret1234');
    await _tapLoginSubmit(tester);
    await tester.pumpAndSettle();

    expect(find.text('Could not sign in'), findsOneWidget);
    expect(find.textContaining('internal login failed'), findsNothing);
  });

  testWidgets('register login link preserves checkout redirect', (
    tester,
  ) async {
    final repo = _AuthRedirectRepository();
    final router = _authRouter('/register?redirect=%2Fcheckout');

    await tester.pumpWidget(_testApp(router: router, repo: repo));
    await tester.pumpAndSettle();

    final signInLink = find.widgetWithText(TextButton, 'Sign in');
    await _scrollUntilVisible(tester, signInLink);
    await tester.tap(signInLink);
    await tester.pumpAndSettle();

    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/login?redirect=%2Fcheckout',
    );
  });

  testWidgets('register shows API error copy after OTP like Nuxt', (
    tester,
  ) async {
    final repo = _AuthRedirectRepository(
      registerError: _apiException('เบอร์โทรศัพท์นี้ถูกใช้งานแล้ว'),
    );
    final router = _authRouter('/register?redirect=%2Fcheckout');

    await tester.pumpWidget(_testApp(router: router, repo: repo));
    await tester.pumpAndSettle();

    await _fillRegisterForm(tester);
    await _tapRegisterSubmit(tester, 'Create account');
    await tester.pumpAndSettle();

    expect(repo.requestOtpCalls, 1);
    expect(find.textContaining('OTP'), findsWidgets);

    await _enterRegisterOtp(tester, '123456');
    await _tapRegisterSubmit(tester, 'Verify and create account');
    await tester.pumpAndSettle();

    expect(repo.lastVerifiedOtp, '123456');
    expect(find.text('เบอร์โทรศัพท์นี้ถูกใช้งานแล้ว'), findsOneWidget);
    expect(
      find.text(
        'Could not create account. Please check your details and try again.',
      ),
      findsNothing,
    );
    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/register?redirect=%2Fcheckout',
    );
  });

  testWidgets('register stops when OTP verification returns no token', (
    tester,
  ) async {
    final repo = _AuthRedirectRepository(
      verifyOtpResult: const OtpVerifyResult(verificationToken: ''),
    );
    final router = _authRouter('/register?redirect=%2Fcheckout');

    await tester.pumpWidget(_testApp(router: router, repo: repo));
    await tester.pumpAndSettle();

    await _fillRegisterForm(tester);
    await _tapRegisterSubmit(tester, 'Create account');
    await tester.pumpAndSettle();
    await _enterRegisterOtp(tester, '123456');
    await _tapRegisterSubmit(tester, 'Verify and create account');
    await tester.pumpAndSettle();

    expect(repo.lastVerifiedOtp, '123456');
    expect(repo.registerCalls, 0);
    expect(
      find.text('OTP verification failed. Please request a new code.'),
      findsOneWidget,
    );
    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/register?redirect=%2Fcheckout',
    );
  });

  testWidgets('register falls back for internal errors', (
    tester,
  ) async {
    final repo = _AuthRedirectRepository(
      registerError: StateError('internal register failed'),
    );
    final router = _authRouter('/register?redirect=%2Fcheckout');

    await tester.pumpWidget(_testApp(router: router, repo: repo));
    await tester.pumpAndSettle();

    await _fillRegisterForm(tester);
    await _tapRegisterSubmit(tester, 'Create account');
    await tester.pumpAndSettle();
    await _enterRegisterOtp(tester, '123456');
    await _tapRegisterSubmit(tester, 'Verify and create account');
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Could not create account. Please check your details and try again.',
      ),
      findsOneWidget,
    );
    expect(find.text('internal register failed'), findsNothing);
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

  testWidgets('PIN status refresh keeps digits entered while it is pending', (
    tester,
  ) async {
    final pinStatusCompleter = Completer<PinStatus>();
    final repo = _AuthRedirectRepository(
      pinStatusCompleter: pinStatusCompleter,
    );
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
    await tester.pump();

    await _tapPinDigits(tester, '123');
    pinStatusCompleter.complete(
      const PinStatus(
        hasPin: true,
        pinVerified: false,
        pinRequired: true,
        pinSetupRequired: false,
      ),
    );
    await tester.pump();
    await tester.pump();
    await _tapPinDigits(tester, '456');
    await tester.pumpAndSettle();

    expect(repo.lastVerifiedPin, '123456');
    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/checkout',
    );
    expect(find.text('checkout-flow'), findsOneWidget);
  });

  testWidgets('PIN keypad mirrors Nuxt layout and keeps entered dots visible', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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
        locale: const Locale('th', 'TH'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Test Shop'), findsOneWidget);
    expect(find.text('ใส่รหัส PIN 6 หลัก'), findsOneWidget);
    expect(find.text('เพื่อทำรายการต่อ'), findsOneWidget);
    expect(find.text('ลืม PIN?'), findsOneWidget);
    expect(find.byType(Card), findsNothing);

    await _tapPinDigits(tester, '123');
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('pin-dot-0-active')), findsOneWidget);
    expect(find.byKey(const ValueKey('pin-dot-1-active')), findsOneWidget);
    expect(find.byKey(const ValueKey('pin-dot-2-active')), findsOneWidget);
    expect(find.byKey(const ValueKey('pin-dot-3-empty')), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.digit4);
    await tester.pump();
    expect(find.byKey(const ValueKey('pin-dot-3-active')), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit5);
    await tester.pump();
    expect(find.byKey(const ValueKey('pin-dot-4-active')), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit6);
    await tester.pumpAndSettle();

    expect(repo.lastVerifiedPin, '123456');
    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/checkout',
    );
    expect(find.text('checkout-flow'), findsOneWidget);
  });
}

Future<void> _tapPinDigits(WidgetTester tester, String pin) async {
  for (final digit in pin.split('')) {
    await tester.tap(find.text(digit));
    await tester.pump();
  }
}

Future<void> _fillRegisterForm(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField).at(0), 'Maneerat');
  await tester.enterText(find.byType(TextField).at(1), 'Demo');
  await tester.enterText(find.byType(TextField).at(2), '0812345678');
  await tester.enterText(find.byType(TextField).at(3), 'secret1234');
  await tester.enterText(find.byType(TextField).at(4), 'secret1234');
  final termsConsent = find.bySemanticsLabel(
    'Accept terms and conditions',
  );
  await _scrollUntilVisible(tester, termsConsent);
  await tester.tap(termsConsent);
  await tester.pumpAndSettle();
}

Future<void> _tapLoginSubmit(WidgetTester tester) async {
  final submitButton = find.widgetWithText(FilledButton, 'Sign in');
  await _scrollUntilVisible(tester, submitButton);
  await tester.tap(submitButton);
}

Future<void> _enterRegisterOtp(WidgetTester tester, String otp) async {
  final otpField = find.byType(TextField).at(5);
  await tester.ensureVisible(otpField);
  await tester.enterText(otpField, otp);
}

Future<void> _tapRegisterSubmit(WidgetTester tester, String label) async {
  final submitButton = find.widgetWithText(FilledButton, label);
  await _scrollUntilVisible(tester, submitButton);
  await tester.tap(submitButton);
}

Future<void> _scrollUntilVisible(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    96,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

Widget _testApp({
  required GoRouter router,
  required _AuthRedirectRepository repo,
  bool authenticated = false,
  bool pinRequired = false,
  Locale locale = const Locale('en', 'US'),
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
      locale: locale,
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
      GoRoute(
        path: '/affiliate',
        builder: (context, state) => const Text(
          'affiliate-flow',
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
    this.loginError,
    this.registerError,
    this.verifyOtpResult =
        const OtpVerifyResult(verificationToken: 'otp_verified_register'),
    this.pinStatusCompleter,
  }) : super(
          api: ApiClient(_testConfig, AuthTokenStore(), localeTag: 'en-US'),
          tokenStore: AuthTokenStore(),
        );

  final CustomerSession loginSession;
  final Object? loginError;
  final Object? registerError;
  final OtpVerifyResult verifyOtpResult;
  final Completer<PinStatus>? pinStatusCompleter;
  String lastLoginUsername = '';
  String lastVerifiedPin = '';
  String lastVerifiedOtp = '';
  String? lastRegisterOtpToken;
  int requestOtpCalls = 0;
  int registerCalls = 0;

  @override
  Future<CustomerSession> login({
    required String username,
    required String password,
  }) async {
    lastLoginUsername = username;
    final error = loginError;
    if (error != null) throw error;
    return loginSession;
  }

  @override
  Future<OtpRequestResult> requestOtp({
    required String phone,
    required String purpose,
  }) async {
    requestOtpCalls++;
    return const OtpRequestResult(
      phoneMasked: '081xxx5678',
      resendAfterSeconds: 0,
    );
  }

  @override
  Future<OtpVerifyResult> verifyOtp({
    required String phone,
    required String purpose,
    required String otp,
  }) async {
    lastVerifiedOtp = otp;
    return verifyOtpResult;
  }

  @override
  Future<CustomerSession> register({
    required String firstName,
    required String lastName,
    required String phone,
    required String password,
    required String passwordConfirmation,
    String? otpVerificationToken,
  }) async {
    registerCalls++;
    lastRegisterOtpToken = otpVerificationToken;
    final error = registerError;
    if (error != null) throw error;
    return loginSession;
  }

  @override
  Future<PinStatus> pinStatus() async {
    final completer = pinStatusCompleter;
    if (completer != null) return completer.future;
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

DioException _apiException(
  String message, {
  String path = '/customer/auth/register',
}) {
  final requestOptions = RequestOptions(path: path);
  return DioException(
    requestOptions: requestOptions,
    response: Response<Map<String, dynamic>>(
      requestOptions: requestOptions,
      statusCode: 422,
      data: {'message': message},
    ),
  );
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
