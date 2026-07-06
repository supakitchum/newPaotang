import 'package:customer_flutter/core/auth/auth_repository.dart';
import 'package:customer_flutter/core/auth/auth_token_store.dart';
import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/i18n/app_locale.dart';
import 'package:customer_flutter/core/i18n/customer_localizations.dart';
import 'package:customer_flutter/core/network/api_client.dart';
import 'package:customer_flutter/core/theme/app_theme.dart';
import 'package:customer_flutter/features/auth/presentation/reset_password_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('reset password submits LINE reset source and returns to login', (
    tester,
  ) async {
    final repository = _ResetPasswordRepository();
    await _pumpResetPasswordRoute(
      tester,
      repository,
      '/reset-password?token=line-token&source=line',
    );

    await tester.enterText(find.byType(TextField).at(0), 'P@ssword123');
    await tester.enterText(find.byType(TextField).at(1), 'P@ssword123');
    await _tapSubmit(tester);

    expect(repository.calls, 1);
    expect(repository.token, 'line-token');
    expect(repository.password, 'P@ssword123');
    expect(repository.passwordConfirmation, 'P@ssword123');
    expect(repository.source, 'line_login');
    expect(find.text('login route'), findsOneWidget);
  });

  testWidgets('reset password treats LINE source aliases as LINE reset', (
    tester,
  ) async {
    final repository = _ResetPasswordRepository();
    await _pumpResetPasswordRoute(
      tester,
      repository,
      '/reset-password?token=line-alias-token&source=line_login',
    );

    await tester.enterText(find.byType(TextField).at(0), 'P@ssword123');
    await tester.enterText(find.byType(TextField).at(1), 'P@ssword123');
    await _tapSubmit(tester);

    expect(repository.calls, 1);
    expect(repository.token, 'line-alias-token');
    expect(repository.source, 'line_login');
    expect(find.text('login route'), findsOneWidget);
  });

  testWidgets('reset password submits admin reset-link source by default', (
    tester,
  ) async {
    final repository = _ResetPasswordRepository();
    await _pumpResetPasswordRoute(
      tester,
      repository,
      '/reset-password?token=admin-token',
    );

    await tester.enterText(find.byType(TextField).at(0), 'P@ssword456');
    await tester.enterText(find.byType(TextField).at(1), 'P@ssword456');
    await _tapSubmit(tester);

    expect(repository.calls, 1);
    expect(repository.token, 'admin-token');
    expect(repository.source, 'admin_reset_link');
    expect(find.text('login route'), findsOneWidget);
  });

  testWidgets('reset password blocks submission when token is missing', (
    tester,
  ) async {
    final repository = _ResetPasswordRepository();
    await _pumpResetPasswordRoute(tester, repository, '/reset-password');

    expect(find.text('ลิงก์ไม่ถูกต้อง'), findsOneWidget);
    expect(
      find.text('กรุณาขอลิงก์รีเซ็ตรหัสผ่านใหม่อีกครั้ง'),
      findsOneWidget,
    );

    final submit = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'บันทึกรหัสผ่านใหม่'),
    );
    expect(submit.onPressed, isNull);
    expect(repository.calls, 0);
  });

  testWidgets('reset password shows API payload errors like Nuxt', (
    tester,
  ) async {
    final repository = _ResetPasswordRepository(
      error: _apiException('ลิงก์รีเซ็ตนี้หมดอายุแล้ว'),
    );
    await _pumpResetPasswordRoute(
      tester,
      repository,
      '/reset-password?token=expired-token',
    );

    await _submitValidResetPassword(tester);

    expect(repository.calls, 1);
    expect(find.text('ลิงก์รีเซ็ตนี้หมดอายุแล้ว'), findsOneWidget);
    expect(
      find.text('ลิงก์อาจหมดอายุ กรุณาขอลิงก์ใหม่อีกครั้ง'),
      findsNothing,
    );
  });

  testWidgets('reset password hides internal errors', (
    tester,
  ) async {
    final repository = _ResetPasswordRepository(
      error: StateError('internal reset failed'),
    );
    await _pumpResetPasswordRoute(
      tester,
      repository,
      '/reset-password?token=internal-token',
    );

    await _submitValidResetPassword(tester);

    expect(
      find.text('ลิงก์อาจหมดอายุ กรุณาขอลิงก์ใหม่อีกครั้ง'),
      findsOneWidget,
    );
    expect(find.textContaining('internal reset failed'), findsNothing);
  });
}

Future<void> _submitValidResetPassword(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField).at(0), 'P@ssword123');
  await tester.enterText(find.byType(TextField).at(1), 'P@ssword123');
  await _tapSubmit(tester);
}

Future<void> _tapSubmit(WidgetTester tester) async {
  final submit = find.widgetWithText(FilledButton, 'บันทึกรหัสผ่านใหม่');
  await tester.scrollUntilVisible(
    submit,
    120,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(submit);
  await tester.pumpAndSettle();
}

Future<void> _pumpResetPasswordRoute(
  WidgetTester tester,
  _ResetPasswordRepository repository,
  String initialLocation,
) async {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/reset-password',
        builder: (context, state) => ResetPasswordScreen(
          token: state.uri.queryParameters['token'] ?? '',
          source: state.uri.queryParameters['source'],
        ),
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
        theme: AppTheme.light(),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _ResetPasswordRepository extends AuthRepository {
  _ResetPasswordRepository({this.error})
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

  final Object? error;
  int calls = 0;
  String token = '';
  String password = '';
  String passwordConfirmation = '';
  String source = '';

  @override
  Future<void> resetPasswordWithToken({
    required String token,
    required String password,
    required String passwordConfirmation,
    String source = 'admin_reset_link',
  }) async {
    calls++;
    this.token = token;
    this.password = password;
    this.passwordConfirmation = passwordConfirmation;
    this.source = source;
    final error = this.error;
    if (error != null) throw error;
  }
}

DioException _apiException(String message) {
  final request = RequestOptions(path: '/customer/auth/password/reset');
  return DioException(
    requestOptions: request,
    response: Response<Map<String, dynamic>>(
      requestOptions: request,
      statusCode: 422,
      data: {'message': message},
    ),
  );
}
