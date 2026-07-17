import 'package:customer_flutter/core/auth/auth_controller.dart';
import 'package:customer_flutter/core/auth/auth_repository.dart';
import 'package:customer_flutter/core/auth/auth_token_store.dart';
import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/i18n/app_locale.dart';
import 'package:customer_flutter/core/i18n/customer_localizations.dart';
import 'package:customer_flutter/core/network/api_client.dart';
import 'package:customer_flutter/core/security/biometric_auth_service.dart';
import 'package:customer_flutter/core/tenant/mobile_bootstrap_controller.dart';
import 'package:customer_flutter/features/pin/presentation/pin_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('PIN reset shows friendly copy when SMS OTP is unavailable', (
    tester,
  ) async {
    final repo = _PinResetRepository(otpError: _smsOtpProviderError());
    final tokenStore = AuthTokenStore();
    final api = ApiClient(
      const AppConfig(
        apiBaseUrl: 'https://partner.example.com/api/v1',
        defaultLocale: 'th-TH',
      ),
      tokenStore,
      localeTag: 'th-TH',
    );
    final controller = AuthController(
      authRepository: repo,
      tokenStore: tokenStore,
      biometricAuth: BiometricAuthService(api),
    )
      ..isAuthenticated = true
      ..pinRequired = true
      ..pinSetupRequired = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(repo),
          authControllerProvider.overrideWith((_) => controller),
          mobileBootstrapProvider.overrideWith(
            (_) async => MobileBootstrap.fromJson(const {
              'mobile': {
                'feature_flags': {'native_biometric_unlock': false},
              },
            }),
          ),
        ],
        child: MaterialApp(
          locale: fallbackCustomerLocale,
          supportedLocales: supportedCustomerLocales,
          localizationsDelegates: const [
            CustomerLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const PinScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('ลืม PIN?'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.text(
        'ร้านค้ายังไม่ได้เปิดบริการ OTP สำหรับรีเซ็ต PIN กรุณาติดต่อร้านค้าเพื่อยืนยันตัวตน',
      ),
      findsOneWidget,
    );
    expect(find.text('SMS OTP provider is not configured.'), findsNothing);
  });

  testWidgets('PIN reset shows API payload errors like Nuxt', (tester) async {
    final repo = _PinResetRepository(
      otpError: _apiException('ส่ง OTP เกินจำนวนครั้งที่กำหนด'),
    );

    await _pumpPinScreen(tester, repo);
    await tester.tap(find.text('ลืม PIN?'));
    await tester.pumpAndSettle();

    expect(find.text('ส่ง OTP เกินจำนวนครั้งที่กำหนด'), findsOneWidget);
    expect(find.text('ส่ง OTP ไม่สำเร็จ กรุณาลองใหม่'), findsNothing);
  });

  testWidgets('PIN reset hides internal errors', (tester) async {
    final repo = _PinResetRepository(
      otpError: StateError('internal pin reset failed'),
    );

    await _pumpPinScreen(tester, repo);
    await tester.tap(find.text('ลืม PIN?'));
    await tester.pumpAndSettle();

    expect(find.text('ส่ง OTP ไม่สำเร็จ กรุณาลองใหม่'), findsOneWidget);
    expect(find.textContaining('internal pin reset failed'), findsNothing);
  });

  testWidgets('PIN reset uses keypad after OTP verification', (tester) async {
    final repo = _PinResetRepository();
    final tokenStore = AuthTokenStore();
    final api = ApiClient(
      const AppConfig(
        apiBaseUrl: 'https://partner.example.com/api/v1',
        defaultLocale: 'th-TH',
      ),
      tokenStore,
      localeTag: 'th-TH',
    );
    final controller = AuthController(
      authRepository: repo,
      tokenStore: tokenStore,
      biometricAuth: BiometricAuthService(api),
    )
      ..isAuthenticated = true
      ..pinRequired = true
      ..pinSetupRequired = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(repo),
          authControllerProvider.overrideWith((_) => controller),
          mobileBootstrapProvider.overrideWith(
            (_) async => MobileBootstrap.fromJson(const {
              'mobile': {
                'feature_flags': {'native_biometric_unlock': false},
              },
            }),
          ),
        ],
        child: MaterialApp(
          locale: fallbackCustomerLocale,
          supportedLocales: supportedCustomerLocales,
          localizationsDelegates: const [
            CustomerLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const PinScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('pin-reset-back')),
      findsNothing,
    );
    await tester.tap(find.text('ลืม PIN?'));
    await tester.pumpAndSettle();

    expect(repo.requestedOtp, isTrue);
    expect(find.byType(DraggableScrollableSheet), findsNothing);
    expect(find.byKey(const ValueKey('pin-reset-screen')), findsOneWidget);
    expect(find.byKey(const ValueKey('pin-reset-back')), findsOneWidget);
    expect(find.text('รีเซ็ต PIN'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('pin-reset-otp-input')),
      '123456',
    );
    await _tapPinResetSubmit(tester, 'ยืนยัน OTP');
    await tester.pumpAndSettle();

    expect(repo.verifiedOtp, '123456');
    expect(find.text('ตั้ง PIN ใหม่'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(
      find.byKey(const ValueKey('pin-reset-keypad-screen')),
      findsOneWidget,
    );

    await _tapResetPin(tester, '654321');
    expect(find.text('ยืนยัน PIN ใหม่'), findsWidgets);

    await _tapResetPin(tester, '654321');
    await tester.pumpAndSettle();

    expect(repo.confirmedOtpToken, 'verified-token');
    expect(repo.confirmedPin, '654321');
    expect(repo.confirmedPinConfirmation, '654321');
    expect(
      find.byKey(const ValueKey('pin-reset-keypad-screen')),
      findsNothing,
    );
  });

  testWidgets('PIN reset returns to the saved redirect after success', (
    tester,
  ) async {
    final repo = _PinResetRepository();
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

    await _pumpPinRouter(tester, repo, router);
    await tester.tap(find.text('ลืม PIN?'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('pin-reset-otp-input')),
      '123456',
    );
    await _tapPinResetSubmit(tester, 'ยืนยัน OTP');
    await tester.pumpAndSettle();

    await _tapResetPin(tester, '654321');
    await _tapResetPin(tester, '654321');
    await tester.pumpAndSettle();

    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/checkout',
    );
    expect(find.text('checkout-flow'), findsOneWidget);
  });
}

Future<void> _pumpPinScreen(
  WidgetTester tester,
  _PinResetRepository repo,
) async {
  final tokenStore = AuthTokenStore();
  final api = ApiClient(
    const AppConfig(
      apiBaseUrl: 'https://partner.example.com/api/v1',
      defaultLocale: 'th-TH',
    ),
    tokenStore,
    localeTag: 'th-TH',
  );
  final controller = AuthController(
    authRepository: repo,
    tokenStore: tokenStore,
    biometricAuth: BiometricAuthService(api),
  )
    ..isAuthenticated = true
    ..pinRequired = true
    ..pinSetupRequired = false;

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(repo),
        authControllerProvider.overrideWith((_) => controller),
        mobileBootstrapProvider.overrideWith(
          (_) async => MobileBootstrap.fromJson(const {
            'mobile': {
              'feature_flags': {'native_biometric_unlock': false},
            },
          }),
        ),
      ],
      child: MaterialApp(
        locale: fallbackCustomerLocale,
        supportedLocales: supportedCustomerLocales,
        localizationsDelegates: const [
          CustomerLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const PinScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapPinResetSubmit(WidgetTester tester, String label) async {
  await tester.pump();
  final button = find.byKey(const ValueKey('pin-reset-primary-action'));
  expect(find.text(label), findsOneWidget);
  expect(button, findsOneWidget);
  await tester.ensureVisible(button);
  await tester.tap(button);
}

Future<void> _pumpPinRouter(
  WidgetTester tester,
  _PinResetRepository repo,
  GoRouter router,
) async {
  final tokenStore = AuthTokenStore();
  final api = ApiClient(
    const AppConfig(
      apiBaseUrl: 'https://partner.example.com/api/v1',
      defaultLocale: 'th-TH',
    ),
    tokenStore,
    localeTag: 'th-TH',
  );
  final controller = AuthController(
    authRepository: repo,
    tokenStore: tokenStore,
    biometricAuth: BiometricAuthService(api),
  )
    ..isAuthenticated = true
    ..pinRequired = true
    ..pinSetupRequired = false;

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(repo),
        authControllerProvider.overrideWith((_) => controller),
        mobileBootstrapProvider.overrideWith(
          (_) async => MobileBootstrap.fromJson(const {
            'mobile': {
              'feature_flags': {'native_biometric_unlock': false},
            },
          }),
        ),
      ],
      child: MaterialApp.router(
        locale: fallbackCustomerLocale,
        supportedLocales: supportedCustomerLocales,
        localizationsDelegates: const [
          CustomerLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapResetPin(WidgetTester tester, String pin) async {
  for (final digit in pin.split('')) {
    final button = find.descendant(
      of: find.byKey(const ValueKey('pin-reset-keypad')),
      matching: find.text(digit),
    );
    await tester.tap(button.last);
    await tester.pumpAndSettle();
  }
}

class _PinResetRepository extends AuthRepository {
  _PinResetRepository({this.otpError})
      : super(
          api: ApiClient(
            const AppConfig(
              apiBaseUrl: 'https://partner.example.com/api/v1',
              defaultLocale: 'th-TH',
            ),
            AuthTokenStore(),
            localeTag: 'th-TH',
          ),
          tokenStore: AuthTokenStore(),
        );

  bool requestedOtp = false;
  String verifiedOtp = '';
  String confirmedOtpToken = '';
  String confirmedPin = '';
  String confirmedPinConfirmation = '';
  final Object? otpError;

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
  Future<OtpRequestResult> requestPinResetOtp() async {
    final error = otpError;
    if (error != null) throw error;
    requestedOtp = true;
    return const OtpRequestResult(
      phoneMasked: '08x-xxx-1234',
      resendAfterSeconds: 0,
    );
  }

  @override
  Future<OtpVerifyResult> verifyPinResetOtp({required String otp}) async {
    verifiedOtp = otp;
    return const OtpVerifyResult(verificationToken: 'verified-token');
  }

  @override
  Future<void> confirmPinResetWithOtp({
    required String otpVerificationToken,
    required String pin,
    required String pinConfirmation,
  }) async {
    confirmedOtpToken = otpVerificationToken;
    confirmedPin = pin;
    confirmedPinConfirmation = pinConfirmation;
  }
}

DioException _smsOtpProviderError() {
  final request = RequestOptions(path: '/customer/auth/pin/reset/request-otp');
  return DioException(
    requestOptions: request,
    response: Response<Map<String, dynamic>>(
      requestOptions: request,
      statusCode: 422,
      data: const {
        'error': {
          'code': 'sms_otp_provider_not_configured',
          'message': 'SMS OTP provider is not configured.',
          'details': {'provider_required': true},
        },
      },
    ),
  );
}

DioException _apiException(String message) {
  final request = RequestOptions(path: '/customer/auth/pin/reset/request-otp');
  return DioException(
    requestOptions: request,
    response: Response<Map<String, dynamic>>(
      requestOptions: request,
      statusCode: 422,
      data: {'message': message},
    ),
  );
}
