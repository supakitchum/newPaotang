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
    expect(
      customerErrorMessage(StateError('internal cart failed'), 'fallback'),
      'fallback',
    );
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
    expect(
      router.routeInformationProvider.value.uri.queryParameters['redirect'],
      '/protected',
    );
  });

  testWidgets('PIN-required errors preserve the current protected return path',
      (
    tester,
  ) async {
    final handled = Completer<bool>();
    final router = GoRouter(
      initialLocation: '/protected?tab=payouts',
      routes: [
        GoRoute(
          path: '/protected',
          builder: (_, __) => _OperationalErrorHarness(
            error: {
              'error': {
                'code': 'pin_required',
                'message': 'Please confirm your PIN.',
              },
            },
            handled: handled,
          ),
        ),
        GoRoute(
          path: '/pin',
          builder: (_, __) => const Scaffold(body: Text('PIN page')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.tap(find.text('Handle error'));
    expect(await handled.future, isTrue);
    await tester.pump(const Duration(milliseconds: 100));

    expect(router.routeInformationProvider.value.uri.path, '/pin');
    expect(
      router.routeInformationProvider.value.uri.queryParameters['redirect'],
      '/protected?tab=payouts',
    );
  });

  testWidgets('auth entry errors honor an explicit protected return path', (
    tester,
  ) async {
    final handled = Completer<bool>();
    final router = GoRouter(
      initialLocation: '/login?redirect=%2Fcheckout',
      routes: [
        GoRoute(
          path: '/login',
          builder: (_, __) => _OperationalErrorHarness(
            error: const {
              'error': {
                'code': 'pin_required',
                'message': 'Please confirm your PIN.',
              },
            },
            handled: handled,
            returnPathOverride: '/checkout?step=payment',
          ),
        ),
        GoRoute(
          path: '/pin',
          builder: (_, __) => const Scaffold(body: Text('PIN page')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.tap(find.text('Handle error'));
    expect(await handled.future, isTrue);
    await tester.pump(const Duration(milliseconds: 100));

    expect(router.routeInformationProvider.value.uri.path, '/pin');
    expect(
      router.routeInformationProvider.value.uri.queryParameters['redirect'],
      '/checkout?step=payment',
    );
  });

  testWidgets('suspended customer errors clear the session before redirecting',
      (
    tester,
  ) async {
    final controller = _testAuthController()
      ..isAuthenticated = true
      ..pinRequired = true;
    final handled = Completer<bool>();
    final router = GoRouter(
      initialLocation: '/protected',
      routes: [
        GoRoute(
          path: '/protected',
          builder: (_, __) => _OperationalErrorHarness(
            error: {
              'error': {
                'code': 'customer_suspended',
                'details': {
                  'accountSuspension': {
                    'suspensionReason': 'Risk review',
                    'isPermanent': true,
                  },
                },
              },
            },
            handled: handled,
          ),
        ),
        GoRoute(
          path: '/account-suspended',
          builder: (_, __) => const Scaffold(
            body: Text('Account suspended page'),
          ),
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
    expect(
      router.routeInformationProvider.value.uri.path,
      '/account-suspended',
    );
    expect(
      router.routeInformationProvider.value.uri.queryParameters['reason'],
      'Risk review',
    );
    expect(
      router.routeInformationProvider.value.uri.queryParameters['permanent'],
      '1',
    );
  });
}

class _OperationalErrorHarness extends ConsumerWidget {
  const _OperationalErrorHarness({
    required this.error,
    required this.handled,
    this.returnPathOverride,
  });

  final Object error;
  final Completer<bool> handled;
  final String? returnPathOverride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: TextButton(
        onPressed: () async {
          final result = await handleCustomerOperationalError(
            ref: ref,
            context: context,
            error: error,
            returnPathOverride: returnPathOverride,
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
