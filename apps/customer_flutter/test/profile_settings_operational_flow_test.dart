import 'package:customer_flutter/core/auth/auth_token_store.dart';
import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/i18n/app_locale.dart';
import 'package:customer_flutter/core/i18n/customer_localizations.dart';
import 'package:customer_flutter/core/network/api_client.dart';
import 'package:customer_flutter/core/tenant/mobile_bootstrap_controller.dart';
import 'package:customer_flutter/core/tenant/mobile_runtime_policy.dart';
import 'package:customer_flutter/features/profile/data/profile_settings_models.dart';
import 'package:customer_flutter/features/profile/data/profile_settings_repository.dart';
import 'package:customer_flutter/features/profile/presentation/auto_reward_screen.dart';
import 'package:customer_flutter/features/profile/presentation/reward_bank_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  for (final route in const [
    '/profile/reward-bank',
    '/profile/auto-reward',
  ]) {
    testWidgets('$route load follows backend maintenance redirect', (
      tester,
    ) async {
      final router = GoRouter(
        initialLocation: route,
        routes: [
          GoRoute(
            path: '/profile/reward-bank',
            builder: (_, __) => const RewardBankScreen(),
          ),
          GoRoute(
            path: '/profile/auto-reward',
            builder: (_, __) => const AutoRewardScreen(),
          ),
          GoRoute(
            path: '/maintenance',
            builder: (_, __) => const Scaffold(
              body: Center(child: Text('Maintenance route')),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mobileBootstrapProvider.overrideWith(
              (_) async => MobileBootstrap.fromJson(const {}),
            ),
            customerPlatformKeyProvider.overrideWithValue('web'),
            customerProfileSettingsProvider.overrideWith(
              (_) async => throw _maintenanceError(),
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

      expect(find.text('Maintenance route'), findsOneWidget);
    });
  }

  testWidgets('auto reward PIN-required save returns through centralized PIN', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/profile/auto-reward',
      routes: [
        GoRoute(
          path: '/profile/auto-reward',
          builder: (_, __) => const AutoRewardScreen(),
        ),
        GoRoute(
          path: '/pin',
          builder: (_, __) => const Scaffold(
            body: Center(child: Text('PIN route')),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mobileBootstrapProvider.overrideWith(
            (_) async => MobileBootstrap.fromJson(const {}),
          ),
          customerProfileSettingsProvider.overrideWith(
            (_) async => _autoRewardProfile,
          ),
          profileSettingsRepositoryProvider.overrideWithValue(
            _ProfileSettingsRepository(saveError: _pinRequiredError()),
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

    await tester.tap(find.text('ถัดไป'));
    await tester.pumpAndSettle();

    expect(find.text('PIN route'), findsOneWidget);
    expect(
      router.routeInformationProvider.value.uri.queryParameters['redirect'],
      '/profile/auto-reward',
    );
  });
}

DioException _maintenanceError() {
  final request = RequestOptions(path: '/customer/profile');
  return DioException(
    requestOptions: request,
    response: Response<Map<String, dynamic>>(
      requestOptions: request,
      statusCode: 503,
      data: const {
        'code': 'maintenance_active',
        'message': 'ร้านค้าปิดปรับปรุงชั่วคราว',
      },
    ),
  );
}

DioException _pinRequiredError() {
  final request = RequestOptions(path: '/customer/profile');
  return DioException(
    requestOptions: request,
    response: Response<Map<String, dynamic>>(
      requestOptions: request,
      statusCode: 403,
      data: const {
        'code': 'pin_required',
        'message': 'กรุณายืนยัน PIN',
      },
    ),
  );
}

class _ProfileSettingsRepository extends ProfileSettingsRepository {
  _ProfileSettingsRepository({required this.saveError})
      : super(_testApiClient());

  final Object saveError;

  @override
  Future<CustomerProfileSettings> saveAutoReward({
    required bool enabled,
    required String payoutMethod,
    String pin = '',
    String pinAssertionToken = '',
  }) async {
    throw saveError;
  }
}

ApiClient _testApiClient() {
  return ApiClient(
    const AppConfig(
      apiBaseUrl: 'https://partner.example.test/api/v1',
      defaultLocale: 'th-TH',
    ),
    AuthTokenStore(),
    localeTag: 'th-TH',
  );
}

const _autoRewardProfile = CustomerProfileSettings(
  id: 'customer_1',
  name: 'ลูกค้าทดสอบ',
  customerNo: 'CUST001',
  phone: '0812345678',
  bankAccount: RewardBankAccount(
    bankName: '',
    accountName: '',
    accountNumber: '',
  ),
  autoReward: AutoRewardSetting(
    enabled: true,
    payoutMethod: 'wallet_credit',
    type: 'wallet',
  ),
  walletId: 'wallet_1',
);
