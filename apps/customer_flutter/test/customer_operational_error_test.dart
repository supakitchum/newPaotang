import 'dart:async';

import 'package:customer_flutter/core/auth/auth_controller.dart';
import 'package:customer_flutter/core/auth/auth_repository.dart';
import 'package:customer_flutter/core/auth/auth_token_store.dart';
import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/network/api_client.dart';
import 'package:customer_flutter/core/security/biometric_auth_service.dart';
import 'package:customer_flutter/shared/utils/customer_operational_error.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  test('customerErrorMessage returns API message or fallback', () {
    expect(
      customerErrorMessage(
        {
          'error': {'message': 'Provider not configured.'},
        },
        'fallback',
      ),
      'Provider not configured.',
    );
    expect(customerErrorMessage({'ok': false}, 'fallback'), 'fallback');
  });

  testWidgets('expired session operational errors logout and redirect to login',
      (tester) async {
    final controller = _testAuthController()
      ..isAuthenticated = true
      ..pinRequired = true;
    final request = RequestOptions(path: '/customer/topups');
    final error = DioException(
      requestOptions: request,
      response: Response<Map<String, dynamic>>(
        requestOptions: request,
        statusCode: 401,
        data: {'message': 'Unauthenticated.'},
      ),
    );
    final handled = Completer<bool>();
    final router = GoRouter(
      initialLocation: '/protected',
      routes: [
        GoRoute(
          path: '/protected',
          builder: (_, __) => _OperationalErrorHarness(
            error: error,
            handled: handled,
          ),
        ),
        GoRoute(
          path: '/login',
          builder: (_, __) => const Scaffold(body: Text('Login page')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authControllerProvider.overrideWith((_) => controller)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.tap(find.text('Handle error'));
    expect(await handled.future, isTrue);
    await tester.pump(const Duration(milliseconds: 100));

    expect(controller.isAuthenticated, isFalse);
    expect(controller.pinRequired, isFalse);
    expect(router.routeInformationProvider.value.uri.path, '/login');
  });
}

class _OperationalErrorHarness extends ConsumerWidget {
  const _OperationalErrorHarness({
    required this.error,
    required this.handled,
  });

  final Object error;
  final Completer<bool> handled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: TextButton(
        onPressed: () async {
          final result = await handleCustomerOperationalError(
            ref: ref,
            context: context,
            error: error,
          );
          if (!handled.isCompleted) handled.complete(result);
        },
        child: const Text('Handle error'),
      ),
    );
  }
}

AuthController _testAuthController() {
  final tokenStore = AuthTokenStore();
  final api = ApiClient(
    const AppConfig(
      apiBaseUrl: 'https://partner.example.com/api/v1',
      defaultLocale: 'th-TH',
    ),
    tokenStore,
    localeTag: 'th-TH',
  );
  return AuthController(
    authRepository: _NoopLogoutRepository(api: api, tokenStore: tokenStore),
    tokenStore: tokenStore,
    biometricAuth: BiometricAuthService(api),
  );
}

class _NoopLogoutRepository extends AuthRepository {
  _NoopLogoutRepository({
    required super.api,
    required super.tokenStore,
  });

  @override
  Future<void> logout() async {}
}
