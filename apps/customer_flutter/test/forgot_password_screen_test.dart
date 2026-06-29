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
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            _ForgotPasswordRepository(),
          ),
          mobileBootstrapProvider.overrideWith(
            (_) async => MobileBootstrap.fromJson(const {
              'auth_providers': [],
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
  _ForgotPasswordRepository()
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

  @override
  Future<OtpRequestResult> requestOtp({
    required String phone,
    required String purpose,
  }) async {
    throw _smsOtpProviderError();
  }
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
