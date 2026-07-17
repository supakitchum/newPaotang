import 'package:customer_flutter/core/auth/auth_repository.dart';
import 'package:customer_flutter/core/auth/auth_token_store.dart';
import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/i18n/app_locale.dart';
import 'package:customer_flutter/core/i18n/customer_localizations.dart';
import 'package:customer_flutter/core/network/api_client.dart';
import 'package:customer_flutter/core/tenant/mobile_bootstrap_controller.dart';
import 'package:customer_flutter/features/auth/presentation/forgot_password_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('forgot password shows LINE reset when tenant enables LINE login',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mobileBootstrapProvider.overrideWith(
            (_) async => MobileBootstrap.fromJson({
              'mobile': {
                'auth_providers': [
                  {'provider': 'line', 'label': 'LINE', 'enabled': true},
                ],
              },
            }),
          ),
        ],
        child: const _ForgotPasswordTestApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Reset with LINE'), findsWidgets);
    expect(find.textContaining('If you have connected LINE'), findsOneWidget);
  });

  testWidgets(
      'forgot password shows LINE reset for runtime LINE provider aliases',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mobileBootstrapProvider.overrideWith(
            (_) async => MobileBootstrap.fromJson({
              'mobile': {
                'auth_providers': [
                  {'provider': 'line_login', 'label': 'LINE', 'enabled': true},
                ],
              },
            }),
          ),
        ],
        child: const _ForgotPasswordTestApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Reset with LINE'), findsWidgets);
    expect(find.textContaining('If you have connected LINE'), findsOneWidget);
  });

  testWidgets(
      'forgot password hides LINE reset when tenant disables LINE login',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mobileBootstrapProvider.overrideWith(
            (_) async => MobileBootstrap.fromJson({
              'mobile': {
                'auth_providers': [
                  {'provider': 'line', 'label': 'LINE', 'enabled': false},
                ],
              },
            }),
          ),
        ],
        child: const _ForgotPasswordTestApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Reset with LINE'), findsNothing);
  });

  testWidgets('forgot password shows friendly copy when SMS OTP is unavailable',
      (tester) async {
    await _pumpForgotPassword(tester, repository: _ForgotPasswordRepository());

    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '0801234567');
    await tester.tap(find.widgetWithText(FilledButton, 'ส่งรหัส OTP'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.text(
        'ร้านค้ายังไม่ได้เปิดบริการ OTP สำหรับรีเซ็ตรหัสผ่าน กรุณาใช้ LINE หรือช่องทางติดต่อร้านค้า',
      ),
      findsOneWidget,
    );
    expect(find.text('SMS OTP provider is not configured.'), findsNothing);
  });

  testWidgets('forgot password shows API payload errors like Nuxt',
      (tester) async {
    await _pumpForgotPassword(
      tester,
      repository: _ForgotPasswordRepository(
        requestOtpError: _apiException('ไม่พบเบอร์โทรศัพท์นี้ในระบบ'),
      ),
    );

    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '0801234567');
    await tester.tap(find.widgetWithText(FilledButton, 'ส่งรหัส OTP'));
    await tester.pumpAndSettle();

    expect(find.text('ไม่พบเบอร์โทรศัพท์นี้ในระบบ'), findsOneWidget);
    expect(
      find.text('ดำเนินการไม่สำเร็จ กรุณาตรวจสอบข้อมูลแล้วลองใหม่'),
      findsNothing,
    );
  });

  testWidgets('forgot password defaults OTP resend cooldown like Nuxt',
      (tester) async {
    await _pumpForgotPassword(
      tester,
      repository: _ForgotPasswordRepository(requestOtpSucceeds: true),
    );

    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '0801234567');
    await tester.tap(find.widgetWithText(FilledButton, 'ส่งรหัส OTP'));
    await tester.pump();

    expect(find.text('ส่งใหม่ได้ใน 60 วินาที'), findsOneWidget);
  });

  testWidgets('forgot password completes OTP reset and returns to login', (
    tester,
  ) async {
    final repository = _ForgotPasswordRepository(requestOtpSucceeds: true);
    final router = GoRouter(
      initialLocation: '/forgot-password',
      routes: [
        GoRoute(
          path: '/forgot-password',
          builder: (context, state) => const ForgotPasswordScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const Scaffold(
            body: Text('login route'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(repository),
          mobileBootstrapProvider.overrideWith(
            (_) async => MobileBootstrap.fromJson(const {}),
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

    expect(
      tester.widget<TextField>(find.byType(TextField)).autofillHints,
      contains(AutofillHints.telephoneNumber),
    );
    await tester.enterText(find.byType(TextFormField), '0801234567');
    await tester.tap(find.widgetWithText(FilledButton, 'ส่งรหัส OTP'));
    await tester.pump();

    expect(find.textContaining('080xxx4567'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).autofillHints,
      contains(AutofillHints.oneTimeCode),
    );
    await tester.enterText(find.byType(TextFormField), '123456');
    await tester.tap(find.widgetWithText(FilledButton, 'ยืนยัน OTP'));
    await tester.pump();

    final passwordFields =
        tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(
      passwordFields[0].autofillHints,
      contains(AutofillHints.newPassword),
    );
    expect(
      passwordFields[1].autofillHints,
      contains(AutofillHints.newPassword),
    );
    await tester.enterText(find.byType(TextFormField).at(0), 'P@ssword123');
    await tester.enterText(find.byType(TextFormField).at(1), 'P@ssword123');
    final saveButton = find.widgetWithText(FilledButton, 'บันทึกรหัสผ่านใหม่');
    await tester.scrollUntilVisible(
      saveButton,
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(
      find.byType(Scrollable).first,
      const Offset(0, -140),
    );
    await tester.pumpAndSettle();
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(repository.verifyOtpCalls, 1);
    expect(repository.resetPasswordCalls, 1);
    expect(repository.lastOtpVerificationToken, 'otp-verification-token');
    expect(find.text('login route'), findsOneWidget);
  });

  testWidgets('forgot password hides internal errors', (tester) async {
    await _pumpForgotPassword(
      tester,
      repository: _ForgotPasswordRepository(
        requestOtpError: StateError('internal forgot password failed'),
      ),
    );

    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '0801234567');
    await tester.tap(find.widgetWithText(FilledButton, 'ส่งรหัส OTP'));
    await tester.pumpAndSettle();

    expect(
      find.text('ดำเนินการไม่สำเร็จ กรุณาตรวจสอบข้อมูลแล้วลองใหม่'),
      findsOneWidget,
    );
    expect(
      find.textContaining('internal forgot password failed'),
      findsNothing,
    );
  });

  testWidgets('forgot password LINE reset shows API payload errors like Nuxt',
      (tester) async {
    await _pumpForgotPassword(
      tester,
      repository: _ForgotPasswordRepository(
        socialUrlError: _apiException('บัญชียังไม่ได้เชื่อมต่อ LINE'),
      ),
      lineEnabled: true,
    );

    await tester.pumpAndSettle();
    await _tapLineResetButton(tester);
    await tester.pumpAndSettle();

    expect(find.text('บัญชียังไม่ได้เชื่อมต่อ LINE'), findsOneWidget);
    expect(
      find.text(
        'รีเซ็ตด้วย LINE ไม่สำเร็จ บัญชีนี้อาจยังไม่ได้เชื่อมต่อ LINE หรือร้านค้ายังไม่ได้ตั้งค่า LINE',
      ),
      findsNothing,
    );
  });

  testWidgets('forgot password LINE reset sends Nuxt return path',
      (tester) async {
    final repository = _ForgotPasswordRepository(
      requestOtpError: _smsOtpProviderError(),
      socialLoginUrlValue: 'https://access.line.me/oauth2/v2.1/authorize',
    );

    await _pumpForgotPassword(
      tester,
      repository: repository,
      lineEnabled: true,
    );

    await tester.pumpAndSettle();
    await _tapLineResetButton(tester);
    await tester.pumpAndSettle();

    expect(repository.lastSocialPurpose, 'password_reset');
    expect(repository.lastSocialRedirect, '/forgot-password');
  });

  testWidgets('forgot password LINE reset hides internal errors', (
    tester,
  ) async {
    await _pumpForgotPassword(
      tester,
      repository: _ForgotPasswordRepository(
        socialUrlError: StateError('internal line reset failed'),
      ),
      lineEnabled: true,
    );

    await tester.pumpAndSettle();
    await _tapLineResetButton(tester);
    await tester.pumpAndSettle();

    expect(
      find.text(
        'รีเซ็ตด้วย LINE ไม่สำเร็จ บัญชีนี้อาจยังไม่ได้เชื่อมต่อ LINE หรือร้านค้ายังไม่ได้ตั้งค่า LINE',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('internal line reset failed'), findsNothing);
  });
}

Future<void> _tapLineResetButton(WidgetTester tester) async {
  final lineResetButton = find.widgetWithText(FilledButton, 'รีเซ็ตด้วย LINE');
  await tester.scrollUntilVisible(
    lineResetButton,
    96,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(lineResetButton);
}

Future<void> _pumpForgotPassword(
  WidgetTester tester, {
  required _ForgotPasswordRepository repository,
  bool lineEnabled = false,
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(repository),
        mobileBootstrapProvider.overrideWith(
          (_) async => MobileBootstrap.fromJson({
            'mobile': {
              'auth_providers': [
                {'provider': 'line', 'label': 'LINE', 'enabled': lineEnabled},
              ],
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
        home: const ForgotPasswordScreen(),
      ),
    ),
  );
}

class _ForgotPasswordTestApp extends StatelessWidget {
  const _ForgotPasswordTestApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      locale: Locale('en', 'US'),
      supportedLocales: [Locale('th', 'TH'), Locale('en', 'US')],
      localizationsDelegates: [
        CustomerLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      home: ForgotPasswordScreen(),
    );
  }
}

class _ForgotPasswordRepository extends AuthRepository {
  _ForgotPasswordRepository({
    Object? requestOtpError,
    bool requestOtpSucceeds = false,
    this.socialUrlError,
    this.socialLoginUrlValue = 'https://line.example.com/oauth',
  })  : requestOtpError = requestOtpSucceeds
            ? null
            : requestOtpError ?? _smsOtpProviderError(),
        super(
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

  final Object? requestOtpError;
  final Object? socialUrlError;
  final String socialLoginUrlValue;
  String? lastSocialPurpose;
  String? lastSocialRedirect;
  int verifyOtpCalls = 0;
  int resetPasswordCalls = 0;
  String? lastOtpVerificationToken;

  @override
  Future<OtpRequestResult> requestOtp({
    required String phone,
    required String purpose,
  }) async {
    final error = requestOtpError;
    if (error != null) throw error;
    return const OtpRequestResult(
      phoneMasked: '080xxx4567',
      resendAfterSeconds: 0,
    );
  }

  @override
  Future<String> socialLoginUrl(
    String provider, {
    String purpose = 'login',
    String? redirect,
    bool callbackUsesAuth = false,
  }) {
    lastSocialPurpose = purpose;
    lastSocialRedirect = redirect;
    final error = socialUrlError;
    if (error != null) throw error;
    return Future.value(socialLoginUrlValue);
  }

  @override
  Future<OtpVerifyResult> verifyOtp({
    required String phone,
    required String purpose,
    required String otp,
  }) async {
    verifyOtpCalls++;
    return const OtpVerifyResult(
      verificationToken: 'otp-verification-token',
    );
  }

  @override
  Future<void> resetPasswordWithOtp({
    required String phone,
    required String otpVerificationToken,
    required String password,
    required String passwordConfirmation,
  }) async {
    resetPasswordCalls++;
    lastOtpVerificationToken = otpVerificationToken;
  }
}

DioException _apiException(String message) {
  final request = RequestOptions(path: '/customer/auth/otp/request');
  return DioException(
    requestOptions: request,
    response: Response<Map<String, dynamic>>(
      requestOptions: request,
      statusCode: 422,
      data: {'message': message},
    ),
  );
}

DioException _smsOtpProviderError() {
  final request = RequestOptions(path: '/customer/auth/otp/request');
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
