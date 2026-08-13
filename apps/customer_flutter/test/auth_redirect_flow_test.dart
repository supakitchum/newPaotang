import 'dart:async';

import 'package:customer_flutter/app/router.dart';
import 'package:customer_flutter/core/auth/auth_controller.dart';
import 'package:customer_flutter/core/auth/auth_repository.dart';
import 'package:customer_flutter/core/auth/auth_token_store.dart';
import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/i18n/app_locale.dart';
import 'package:customer_flutter/core/i18n/customer_localizations.dart';
import 'package:customer_flutter/core/network/api_client.dart';
import 'package:customer_flutter/core/navigation/customer_back_navigation.dart';
import 'package:customer_flutter/core/security/biometric_auth_service.dart';
import 'package:customer_flutter/core/tenant/mobile_bootstrap_controller.dart';
import 'package:customer_flutter/core/tenant/mobile_runtime_policy.dart';
import 'package:customer_flutter/features/affiliate/data/affiliate_referral_repository.dart';
import 'package:customer_flutter/features/auth/presentation/login_otp_screen.dart';
import 'package:customer_flutter/features/auth/presentation/login_screen.dart';
import 'package:customer_flutter/features/auth/presentation/register_otp_screen.dart';
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
  testWidgets('login hero extends behind the top system status bar', (
    tester,
  ) async {
    final repo = _AuthRedirectRepository();
    final router = _authRouter('/login');

    await tester.pumpWidget(_testApp(router: router, repo: repo));
    await tester.pumpAndSettle();

    final safeArea = tester.widget<SafeArea>(
      find.byKey(const ValueKey('login-screen-safe-area')),
    );
    expect(safeArea.top, isFalse);
    expect(tester.getTopLeft(find.byType(Scaffold).first).dy, 0);
  });

  testWidgets('register hero extends behind the top system status bar', (
    tester,
  ) async {
    final repo = _AuthRedirectRepository();
    final router = _authRouter('/register');

    await tester.pumpWidget(_testApp(router: router, repo: repo));
    await tester.pumpAndSettle();

    final safeArea = tester.widget<SafeArea>(
      find.byKey(const ValueKey('register-screen-safe-area')),
    );
    expect(safeArea.top, isFalse);
    expect(tester.getTopLeft(find.byType(Scaffold).first).dy, 0);
  });

  test('app router is not recreated by PIN status auth refresh', () async {
    final repo = _AuthRedirectRepository();
    final tokenStore = AuthTokenStore();
    final api = ApiClient(_testConfig, tokenStore, localeTag: 'en-US');
    final controller =
        AuthController(
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

    await _switchLoginToPassword(tester);
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

  testWidgets('login keyboard done submits once and releases field focus', (
    tester,
  ) async {
    final repo = _AuthRedirectRepository();
    final router = _authRouter('/login?redirect=%2Fcheckout');

    await tester.pumpWidget(_testApp(router: router, repo: repo));
    await tester.pumpAndSettle();

    await _switchLoginToPassword(tester);
    await tester.enterText(find.byType(TextField).at(0), '0812345678');
    final passwordField = find.byType(TextField).at(1);
    await tester.enterText(passwordField, 'secret1234');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(repo.loginCalls, 1);
    expect(repo.lastLoginUsername, '0812345678');
    expect(tester.testTextInput.isVisible, isFalse);
    expect(
      FocusManager.instance.primaryFocus?.context?.widget,
      isNot(isA<EditableText>()),
    );
    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/checkout',
    );
  });

  testWidgets('login sends OTP directly after validating the phone', (
    tester,
  ) async {
    final repo = _AuthRedirectRepository();
    final router = _authRouter('/login?redirect=%2Fcheckout');

    await tester.pumpWidget(_testApp(router: router, repo: repo));
    await tester.pumpAndSettle();

    final loginFields = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    expect(
      loginFields[0].autofillHints,
      contains(AutofillHints.telephoneNumber),
    );
    expect(loginFields, hasLength(1));
    expect(loginFields[0].textInputAction, TextInputAction.done);

    await tester.enterText(find.byType(TextField).at(0), '08a12345678999');
    expect(find.byKey(const ValueKey('login-use-password')), findsNothing);
    await _tapLoginOtpSubmit(tester);
    await tester.pumpAndSettle();

    expect(repo.requestLoginOtpCalls, 1);
    expect(repo.lastLoginOtpPhone, '0812345678');
    expect(
      find.byKey(const ValueKey('login-otp-use-password')),
      findsOneWidget,
    );
    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/login/otp?redirect=%2Fcheckout',
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

    await _switchLoginToPassword(tester);
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

  testWidgets('login OTP must complete before navigating to PIN', (
    tester,
  ) async {
    final repo = _AuthRedirectRepository(
      loginOtpChallenge: const LoginOtpChallenge(
        challengeToken: 'lotp_widget',
        phoneMasked: '081xxxx678',
        resendAfterSeconds: 0,
        expiresInSeconds: 600,
      ),
      loginSession: const CustomerSession(
        accessToken: 'access-after-otp',
        refreshToken: 'refresh-after-otp',
        pinRequired: true,
        pinSetupRequired: false,
        customerId: 'cus_login_otp',
      ),
    );
    final router = _authRouter('/login?redirect=%2Fcheckout');

    await tester.pumpWidget(_testApp(router: router, repo: repo));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), '0812345678');
    await _tapLoginOtpSubmit(tester);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('login-otp-screen')), findsOneWidget);
    final otpEditable = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const ValueKey('login-otp-input')),
        matching: find.byType(EditableText),
      ),
    );
    expect(otpEditable.focusNode.hasFocus, isTrue);
    final otpField = tester.widget<TextField>(
      find.byKey(const ValueKey('login-otp-input')),
    );
    expect(otpField.autofillHints, contains(AutofillHints.oneTimeCode));
    expect(
      otpField.keyboardType,
      const TextInputType.numberWithOptions(signed: false, decimal: false),
    );
    expect(otpField.obscureText, isFalse);
    for (var index = 0; index < 6; index += 1) {
      expect(find.byKey(ValueKey('login-otp-box-$index')), findsOneWidget);
    }
    expect(repo.verifyLoginOtpCalls, 0);
    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/login/otp?redirect=%2Fcheckout',
    );

    await tester.enterText(
      find.byKey(const ValueKey('login-otp-input')),
      '123456',
    );
    await tester.pumpAndSettle();

    expect(repo.lastLoginOtp, '123456');
    expect(repo.verifyLoginOtpCalls, 1);
    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/pin?redirect=%2Fcheckout',
    );
  });

  testWidgets('OTP screen switches to password fallback with phone preserved', (
    tester,
  ) async {
    final repo = _AuthRedirectRepository();
    final router = _authRouter('/login?redirect=%2Fcheckout');

    await tester.pumpWidget(_testApp(router: router, repo: repo));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), '0812345678');
    await _tapLoginOtpSubmit(tester);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('login-otp-screen')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('login-otp-use-password')));
    await tester.pumpAndSettle();

    final fields = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    expect(fields, hasLength(2));
    expect(fields.first.controller?.text, '0812345678');
    expect(find.text('Sign in with password'), findsOneWidget);
    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/login?redirect=%2Fcheckout',
    );
  });

  testWidgets('login PIN operational errors preserve checkout redirect', (
    tester,
  ) async {
    final repo = _AuthRedirectRepository(
      loginError: const {
        'error': {
          'code': 'pin_required',
          'message': 'Please confirm your PIN.',
        },
      },
    );
    final router = _authRouter('/login?redirect=%2Fcheckout');

    await tester.pumpWidget(_testApp(router: router, repo: repo));
    await tester.pumpAndSettle();

    await _switchLoginToPassword(tester);
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

  testWidgets('login sends affiliate redirects through the global PIN screen', (
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

    await _switchLoginToPassword(tester);
    await tester.enterText(find.byType(TextField).at(0), '0812345678');
    await tester.enterText(find.byType(TextField).at(1), 'secret1234');
    await _tapLoginSubmit(tester);
    await tester.pumpAndSettle();

    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/pin?redirect=%2Faffiliate',
    );
    expect(find.text('pin-flow'), findsOneWidget);
  });

  testWidgets('login shows API error copy like Nuxt', (tester) async {
    final repo = _AuthRedirectRepository(
      loginError: _apiException(
        'เบอร์โทรศัพท์หรือรหัสผ่านไม่ถูกต้อง',
        path: '/customer/auth/login',
      ),
    );
    final router = _authRouter('/login?redirect=%2Fcheckout');

    await tester.pumpWidget(_testApp(router: router, repo: repo));
    await tester.pumpAndSettle();

    await _switchLoginToPassword(tester);
    await tester.enterText(find.byType(TextField).at(0), '0812345678');
    await tester.enterText(find.byType(TextField).at(1), 'wrong-password');
    await _tapLoginSubmit(tester);
    await tester.pumpAndSettle();

    expect(find.text('เบอร์โทรศัพท์หรือรหัสผ่านไม่ถูกต้อง'), findsOneWidget);
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

    await _switchLoginToPassword(tester);
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

  testWidgets('register opens a dedicated OTP screen with autofill semantics', (
    tester,
  ) async {
    final repo = _AuthRedirectRepository();
    final router = _authRouter('/register');

    await tester.pumpWidget(_testApp(router: router, repo: repo));
    await tester.pumpAndSettle();

    var fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(fields[0].autofillHints, contains(AutofillHints.givenName));
    expect(fields[1].autofillHints, contains(AutofillHints.familyName));
    expect(fields[2].autofillHints, contains(AutofillHints.telephoneNumber));
    expect(fields[3].autofillHints, contains(AutofillHints.newPassword));
    expect(fields[4].autofillHints, contains(AutofillHints.newPassword));

    await _fillRegisterForm(tester);
    await _tapRegisterSubmit(tester, 'Create account');
    await tester.pumpAndSettle();

    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/register/otp',
    );
    expect(find.byKey(const ValueKey('register-otp-screen')), findsOneWidget);
    expect(repo.registerCalls, 0);
    expect(find.text('Verify phone number'), findsWidgets);
    expect(find.byIcon(Icons.sms_outlined), findsOneWidget);
    expect(find.byKey(const ValueKey('register-otp-box-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('register-otp-box-5')), findsOneWidget);

    final otpField = tester.widget<TextField>(
      find.byKey(const ValueKey('register-otp-input')),
    );
    expect(otpField.autofillHints, contains(AutofillHints.oneTimeCode));
  });

  testWidgets('register OTP returns to the populated registration form', (
    tester,
  ) async {
    final repo = _AuthRedirectRepository();
    final router = _authRouter('/register?redirect=%2Fcheckout');

    await tester.pumpWidget(_testApp(router: router, repo: repo));
    await tester.pumpAndSettle();
    await _fillRegisterForm(tester);
    await _tapRegisterSubmit(tester, 'Create account');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('register-otp-change-details')));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/register?redirect=%2Fcheckout',
    );
    final fields = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    expect(fields[0].controller?.text, 'Maneerat');
    expect(fields[1].controller?.text, 'Demo');
    expect(fields[2].controller?.text, '0812345678');
  });

  testWidgets('register PIN operational errors preserve checkout redirect', (
    tester,
  ) async {
    final repo = _AuthRedirectRepository(
      requestOtpError: const {
        'error': {
          'code': 'pin_required',
          'message': 'Please confirm your PIN.',
        },
      },
    );
    final router = _authRouter('/register?redirect=%2Fcheckout');

    await tester.pumpWidget(_testApp(router: router, repo: repo));
    await tester.pumpAndSettle();

    await _fillRegisterForm(tester);
    await _tapRegisterSubmit(tester, 'Create account');
    await tester.pumpAndSettle();

    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/pin?redirect=%2Fcheckout',
    );
    expect(find.text('pin-flow'), findsOneWidget);
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
      '/register/otp?redirect=%2Fcheckout',
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
    await tester.pumpAndSettle();

    expect(repo.lastVerifiedOtp, '123456');
    expect(repo.registerCalls, 0);
    expect(
      find.text('OTP verification failed. Please request a new code.'),
      findsOneWidget,
    );
    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/register/otp?redirect=%2Fcheckout',
    );
  });

  testWidgets('register falls back for internal errors', (tester) async {
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
          builder: (context, state) =>
              const Text('checkout-flow', textDirection: TextDirection.ltr),
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

  testWidgets(
    'external PIN redirect back uses the destination fallback instead of PIN',
    (tester) async {
      final repo = _AuthRedirectRepository();
      final router = GoRouter(
        initialLocation: '/pin?redirect=%2Fnews%2Fdetail',
        routes: [
          GoRoute(path: '/pin', builder: (context, state) => const PinScreen()),
          GoRoute(
            path: '/news/detail',
            builder: (context, state) => Scaffold(
              body: Center(
                child: IconButton(
                  key: const ValueKey('news-detail-back'),
                  onPressed: () =>
                      navigateCustomerBack(context, fallbackPath: '/news'),
                  icon: const Icon(Icons.arrow_back),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/news',
            builder: (context, state) =>
                const Text('news-main', textDirection: TextDirection.ltr),
          ),
        ],
      );
      customerBackNavigationHistory.attach(router);
      addTearDown(() {
        customerBackNavigationHistory.detach(router);
        router.dispose();
      });

      await tester.pumpWidget(
        _testApp(
          router: router,
          repo: repo,
          authenticated: true,
          pinRequired: true,
        ),
      );
      await tester.pumpAndSettle();
      await _tapPinDigits(tester, '123456');
      await tester.pumpAndSettle();

      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        '/news/detail',
      );
      await tester.tap(find.byKey(const ValueKey('news-detail-back')));
      await tester.pumpAndSettle();

      expect(router.routerDelegate.currentConfiguration.uri.path, '/news');
      expect(find.text('news-main'), findsOneWidget);
      expect(find.byType(PinScreen), findsNothing);
    },
  );

  testWidgets(
    'PIN waits one second before automatically using an enabled biometric credential',
    (tester) async {
      final repo = _AuthRedirectRepository();
      final biometric = _AutoBiometricAuthService(
        assertionToken: 'assertion-auto-pin',
      );
      final router = GoRouter(
        initialLocation: '/pin?redirect=%2Fcheckout',
        routes: [
          GoRoute(path: '/pin', builder: (context, state) => const PinScreen()),
          GoRoute(
            path: '/checkout',
            builder: (context, state) =>
                const Text('checkout-flow', textDirection: TextDirection.ltr),
          ),
        ],
      );

      await tester.pumpWidget(
        _testApp(
          router: router,
          repo: repo,
          authenticated: true,
          pinRequired: true,
          biometricAuth: biometric,
          biometricEnabled: true,
          platformKey: 'ios',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PinScreen), findsOneWidget);
      expect(biometric.eligibilityChecks, 0);
      expect(biometric.assertionRequests, 0);

      await tester.pump(const Duration(milliseconds: 999));
      expect(biometric.eligibilityChecks, 0);
      expect(biometric.assertionRequests, 0);

      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();

      expect(biometric.eligibilityChecks, 1);
      expect(biometric.assertionRequests, 1);
      expect(repo.lastPinAssertionToken, 'assertion-auto-pin');
      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        '/checkout',
      );
      expect(find.text('checkout-flow'), findsOneWidget);
    },
  );

  testWidgets('PIN renders biometric unlock as an icon-only action', (
    tester,
  ) async {
    final repo = _AuthRedirectRepository();
    final biometric = _AutoBiometricAuthService(
      assertionToken: 'unused-assertion',
      canUnlock: false,
    );
    final router = GoRouter(
      initialLocation: '/pin?redirect=%2Fcheckout',
      routes: [
        GoRoute(path: '/pin', builder: (context, state) => const PinScreen()),
        GoRoute(
          path: '/checkout',
          builder: (context, state) =>
              const Text('checkout-flow', textDirection: TextDirection.ltr),
        ),
      ],
    );

    await tester.pumpWidget(
      _testApp(
        router: router,
        repo: repo,
        authenticated: true,
        pinRequired: true,
        biometricAuth: biometric,
        biometricEnabled: true,
        platformKey: 'ios',
      ),
    );
    await tester.pumpAndSettle();

    final action = find.byKey(const ValueKey('pin-biometric-button'));
    expect(action, findsOneWidget);
    expect(
      find.descendant(of: action, matching: find.byType(Text)),
      findsNothing,
    );
    expect(
      find.descendant(
        of: action,
        matching: find.byIcon(Icons.face_retouching_natural),
      ),
      findsOneWidget,
    );
    expect(tester.widget<IconButton>(action).tooltip, isNotEmpty);
  });

  testWidgets(
    'PIN does not auto-prompt when this device has no biometric credential',
    (tester) async {
      final repo = _AuthRedirectRepository();
      final biometric = _AutoBiometricAuthService(
        assertionToken: 'unused-assertion',
        canUnlock: false,
      );
      final router = GoRouter(
        initialLocation: '/pin?redirect=%2Fcheckout',
        routes: [
          GoRoute(path: '/pin', builder: (context, state) => const PinScreen()),
          GoRoute(
            path: '/checkout',
            builder: (context, state) =>
                const Text('checkout-flow', textDirection: TextDirection.ltr),
          ),
        ],
      );

      await tester.pumpWidget(
        _testApp(
          router: router,
          repo: repo,
          authenticated: true,
          pinRequired: true,
          biometricAuth: biometric,
          biometricEnabled: true,
          platformKey: 'ios',
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(biometric.eligibilityChecks, 1);

      await tester.pump(const Duration(milliseconds: 650));
      await tester.pump();
      expect(biometric.eligibilityChecks, 2);

      await tester.pump(const Duration(milliseconds: 650));
      await tester.pumpAndSettle();

      expect(biometric.eligibilityChecks, 3);
      expect(biometric.assertionRequests, 0);
      expect(repo.lastPinAssertionToken, isEmpty);
      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        '/pin?redirect=%2Fcheckout',
      );
    },
  );

  testWidgets(
    'PIN retries a transient biometric eligibility failure before prompting',
    (tester) async {
      final repo = _AuthRedirectRepository();
      final biometric = _AutoBiometricAuthService(
        assertionToken: 'assertion-after-retry',
        unavailableChecksBeforeSuccess: 1,
      );
      final router = GoRouter(
        initialLocation: '/pin?redirect=%2Fcheckout',
        routes: [
          GoRoute(path: '/pin', builder: (context, state) => const PinScreen()),
          GoRoute(
            path: '/checkout',
            builder: (context, state) =>
                const Text('checkout-flow', textDirection: TextDirection.ltr),
          ),
        ],
      );

      await tester.pumpWidget(
        _testApp(
          router: router,
          repo: repo,
          authenticated: true,
          pinRequired: true,
          biometricAuth: biometric,
          biometricEnabled: true,
          platformKey: 'ios',
        ),
      );
      await tester.pumpAndSettle();

      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(biometric.eligibilityChecks, 1);
      expect(biometric.assertionRequests, 0);
      expect(find.byType(PinScreen), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 649));
      expect(biometric.eligibilityChecks, 1);
      expect(biometric.assertionRequests, 0);

      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();

      expect(biometric.eligibilityChecks, 2);
      expect(biometric.assertionRequests, 1);
      expect(repo.lastPinAssertionToken, 'assertion-after-retry');
      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        '/checkout',
      );
    },
  );

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
          builder: (context, state) =>
              const Text('checkout-flow', textDirection: TextDirection.ltr),
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
          builder: (context, state) =>
              const Text('checkout-flow', textDirection: TextDirection.ltr),
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
    expect(find.byIcon(Icons.chevron_left), findsNothing);
    expect(find.byTooltip('ย้อนกลับ'), findsNothing);

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

  testWidgets(
    'PIN keeps Nuxt top header and bottom keypad on large viewports',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final repo = _AuthRedirectRepository();
      final router = GoRouter(
        initialLocation: '/pin?redirect=%2Fcheckout',
        routes: [
          GoRoute(path: '/pin', builder: (context, state) => const PinScreen()),
          GoRoute(
            path: '/checkout',
            builder: (context, state) =>
                const Text('checkout-flow', textDirection: TextDirection.ltr),
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

      final headerRect = tester.getRect(
        find.byKey(const ValueKey('pin-topbar')),
      );
      final titleCenter = tester.getCenter(find.text('ใส่รหัส PIN 6 หลัก'));
      final keypadRect = tester.getRect(
        find.byKey(const ValueKey('pin-keypad')),
      );
      const viewportCenterX = 512.0;

      expect(headerRect.top, lessThanOrEqualTo(12));
      expect(keypadRect.bottom, greaterThan(970));
      expect(
        headerRect.center.dx,
        moreOrLessEquals(viewportCenterX, epsilon: 0.5),
      );
      expect(titleCenter.dx, moreOrLessEquals(viewportCenterX, epsilon: 0.5));
      expect(
        keypadRect.center.dx,
        moreOrLessEquals(viewportCenterX, epsilon: 0.5),
      );
    },
  );
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
    'Accept terms of service and privacy policy',
  );
  await _scrollUntilVisible(tester, termsConsent);
  await tester.tap(termsConsent);
  await tester.pumpAndSettle();
}

Future<void> _tapLoginSubmit(WidgetTester tester) async {
  final submitButton = find.widgetWithText(FilledButton, 'Sign in');
  await _scrollUntilVisible(tester, submitButton);
  await tester.tap(submitButton);
  await tester.pump(const Duration(milliseconds: 600));
}

Future<void> _tapLoginOtpSubmit(WidgetTester tester) async {
  final submitButton = find.widgetWithText(FilledButton, 'Send OTP');
  await _scrollUntilVisible(tester, submitButton);
  await tester.tap(submitButton);
}

Future<void> _switchLoginToPassword(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const ValueKey('login-phone-input')),
    '0812345678',
  );
  await _tapLoginOtpSubmit(tester);
  await tester.pumpAndSettle();

  final switchButton = find.byKey(const ValueKey('login-otp-use-password'));
  await _scrollUntilVisible(tester, switchButton);
  await tester.tap(switchButton);
  await tester.pumpAndSettle();
}

Future<void> _enterRegisterOtp(WidgetTester tester, String otp) async {
  final otpField = find.byKey(const ValueKey('register-otp-input'));
  await tester.ensureVisible(otpField);
  await tester.enterText(otpField, otp);
  await tester.pump(const Duration(milliseconds: 600));
}

Future<void> _tapRegisterSubmit(WidgetTester tester, String label) async {
  final submitButton = find.widgetWithText(FilledButton, label);
  await _scrollUntilVisible(tester, submitButton);
  await tester.tap(submitButton);
  await tester.pump(const Duration(milliseconds: 600));
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
  BiometricAuthService? biometricAuth,
  bool biometricEnabled = false,
  String platformKey = 'web',
}) {
  final tokenStore = AuthTokenStore();
  final api = ApiClient(_testConfig, tokenStore, localeTag: 'en-US');
  final controller =
      AuthController(
          authRepository: repo,
          tokenStore: tokenStore,
          biometricAuth: biometricAuth ?? BiometricAuthService(api),
        )
        ..isAuthenticated = authenticated
        ..pinRequired = pinRequired
        ..pinSetupRequired = false;

  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(repo),
      authControllerProvider.overrideWith((_) => controller),
      customerPlatformKeyProvider.overrideWithValue(platformKey),
      affiliateReferralServiceProvider.overrideWithValue(
        _NoopAffiliateReferralService(),
      ),
      mobileBootstrapProvider.overrideWith(
        (_) async => MobileBootstrap.fromJson({
          'site': {'display_name': 'Test Shop', 'locale': 'en-US'},
          'mobile': {
            'auth_providers': [],
            'biometric': {
              'enabled': biometricEnabled,
              'platforms': {
                'ios': ['face_id'],
                'android': ['biometric_prompt'],
              },
            },
            'feature_flags': {'native_biometric_unlock': biometricEnabled},
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
        path: '/login/otp',
        builder: (context, state) => const LoginOtpScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/register/otp',
        builder: (context, state) => const RegisterOtpScreen(),
      ),
      GoRoute(
        path: '/pin',
        builder: (context, state) =>
            const Text('pin-flow', textDirection: TextDirection.ltr),
      ),
      GoRoute(
        path: '/checkout',
        builder: (context, state) =>
            const Text('checkout-flow', textDirection: TextDirection.ltr),
      ),
      GoRoute(
        path: '/affiliate',
        builder: (context, state) =>
            const Text('affiliate-flow', textDirection: TextDirection.ltr),
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
    this.loginOtpChallenge,
    this.requestOtpError,
    this.registerError,
    this.verifyOtpResult = const OtpVerifyResult(
      verificationToken: 'otp_verified_register',
    ),
    this.pinStatusCompleter,
  }) : super(
         api: ApiClient(_testConfig, AuthTokenStore(), localeTag: 'en-US'),
         tokenStore: AuthTokenStore(),
       );

  final CustomerSession loginSession;
  final Object? loginError;
  final LoginOtpChallenge? loginOtpChallenge;
  final Object? requestOtpError;
  final Object? registerError;
  final OtpVerifyResult verifyOtpResult;
  final Completer<PinStatus>? pinStatusCompleter;
  String lastLoginUsername = '';
  String lastVerifiedPin = '';
  String lastPinAssertionToken = '';
  String lastVerifiedOtp = '';
  String? lastRegisterOtpToken;
  int requestOtpCalls = 0;
  int registerCalls = 0;
  int loginCalls = 0;
  int requestLoginOtpCalls = 0;
  int verifyLoginOtpCalls = 0;
  String lastLoginOtp = '';
  String lastLoginOtpPhone = '';

  @override
  Future<CustomerSession> login({
    required String username,
    required String password,
  }) async {
    loginCalls++;
    lastLoginUsername = username;
    final error = loginError;
    if (error != null) throw error;
    final challenge = loginOtpChallenge;
    if (challenge != null) throw LoginOtpChallengeRequired(challenge);
    return loginSession;
  }

  @override
  Future<LoginOtpChallenge> requestLoginOtp({required String phone}) async {
    requestLoginOtpCalls++;
    lastLoginOtpPhone = phone;
    return loginOtpChallenge ??
        const LoginOtpChallenge(
          challengeToken: 'lotp_default',
          phoneMasked: '081xxxx678',
          resendAfterSeconds: 0,
          expiresInSeconds: 600,
        );
  }

  @override
  Future<CustomerSession> verifyLoginOtp({
    required String challengeToken,
    required String otp,
  }) async {
    verifyLoginOtpCalls++;
    lastLoginOtp = otp;
    return loginSession;
  }

  @override
  Future<OtpRequestResult> requestOtp({
    required String phone,
    required String purpose,
  }) async {
    requestOtpCalls++;
    final error = requestOtpError;
    if (error != null) throw error;
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
  Future<PinStatus> verifyPin(String pin) async {
    lastVerifiedPin = pin;
    return const PinStatus(
      hasPin: true,
      pinVerified: true,
      pinRequired: false,
      pinSetupRequired: false,
    );
  }

  @override
  Future<void> verifyPinAssertion(String pinAssertionToken) async {
    lastPinAssertionToken = pinAssertionToken;
  }
}

class _AutoBiometricAuthService extends BiometricAuthService {
  _AutoBiometricAuthService({
    required this.assertionToken,
    this.canUnlock = true,
    this.unavailableChecksBeforeSuccess = 0,
  }) : super(ApiClient(_testConfig, AuthTokenStore(), localeTag: 'en-US'));

  final String? assertionToken;
  final bool canUnlock;
  final int unavailableChecksBeforeSuccess;
  int eligibilityChecks = 0;
  int assertionRequests = 0;

  @override
  Future<bool> canUnlockCurrentDevice() async {
    eligibilityChecks++;
    return canUnlock && eligibilityChecks > unavailableChecksBeforeSuccess;
  }

  @override
  Future<String?> requestPinAssertion({
    String purpose = 'pin_unlock',
    required String localizedReason,
  }) async {
    assertionRequests++;
    return assertionToken;
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
