import 'package:customer_flutter/core/auth/auth_token_store.dart';
import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/i18n/app_locale.dart';
import 'package:customer_flutter/core/i18n/customer_locale_controller.dart';
import 'package:customer_flutter/core/i18n/customer_localizations.dart';
import 'package:customer_flutter/core/i18n/customer_translation_repository.dart';
import 'package:customer_flutter/core/network/api_client.dart';
import 'package:customer_flutter/core/tenant/mobile_bootstrap_controller.dart';
import 'package:customer_flutter/features/profile/data/profile_settings_repository.dart';
import 'package:customer_flutter/features/profile/presentation/language_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('language screen lists locales and persists the selection', (
    tester,
  ) async {
    final api = _LanguageApiClient();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_testConfig),
          mobileBootstrapProvider.overrideWith(
            (_) async => MobileBootstrap.fromJson(
              const {},
              defaultLocale: 'th-TH',
              defaultSiteName: 'Test',
            ),
          ),
          profileSettingsRepositoryProvider.overrideWithValue(
            ProfileSettingsRepository(api),
          ),
          customerSupportedLocaleOptionsProvider.overrideWithValue(
            _runtimeLocaleOptions,
          ),
        ],
        child: const _LocaleHarness(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ไทย'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('profile_language_en-US')));
    await tester.pumpAndSettle();

    expect(api.savedLocale, 'en-US');
    expect(find.text('Display language'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
  });

  testWidgets('failed save restores locale and override state', (tester) async {
    final api = _LanguageApiClient(fail: true);
    late ProviderContainer container;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container = ProviderContainer(
          overrides: [
            appConfigProvider.overrideWithValue(_testConfig),
            mobileBootstrapProvider.overrideWith(
              (_) async => MobileBootstrap.fromJson(
                const {},
                defaultLocale: 'th-TH',
                defaultSiteName: 'Test',
              ),
            ),
            profileSettingsRepositoryProvider.overrideWithValue(
              ProfileSettingsRepository(api),
            ),
            customerSupportedLocaleOptionsProvider.overrideWithValue(
              _runtimeLocaleOptions,
            ),
          ],
        ),
        child: const _LocaleHarness(),
      ),
    );
    addTearDown(container.dispose);
    await tester.pumpAndSettle();

    expect(container.read(customerLocaleOverriddenProvider), isFalse);

    await tester.tap(find.byKey(const ValueKey('profile_language_en-US')));
    await tester.pumpAndSettle();

    expect(localeTag(container.read(customerLocaleProvider)), 'th-TH');
    expect(container.read(customerLocaleOverriddenProvider), isFalse);
    expect(find.textContaining('บันทึกลงบัญชีไม่สำเร็จ'), findsOneWidget);
  });

  testWidgets('failed save shows backend API copy after restoring locale', (
    tester,
  ) async {
    final api = _LanguageApiClient(
      error: _apiException(
        'ภาษานี้ยังไม่เปิดใช้งานสำหรับบัญชีของคุณ',
        path: '/customer/profile',
      ),
    );
    late ProviderContainer container;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container = ProviderContainer(
          overrides: [
            appConfigProvider.overrideWithValue(_testConfig),
            mobileBootstrapProvider.overrideWith(
              (_) async => MobileBootstrap.fromJson(
                const {},
                defaultLocale: 'th-TH',
                defaultSiteName: 'Test',
              ),
            ),
            profileSettingsRepositoryProvider.overrideWithValue(
              ProfileSettingsRepository(api),
            ),
            customerSupportedLocaleOptionsProvider.overrideWithValue(
              _runtimeLocaleOptions,
            ),
          ],
        ),
        child: const _LocaleHarness(),
      ),
    );
    addTearDown(container.dispose);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('profile_language_en-US')));
    await tester.pumpAndSettle();

    expect(localeTag(container.read(customerLocaleProvider)), 'th-TH');
    expect(container.read(customerLocaleOverriddenProvider), isFalse);
    expect(
      find.text('ภาษานี้ยังไม่เปิดใช้งานสำหรับบัญชีของคุณ'),
      findsOneWidget,
    );
    expect(find.textContaining('บันทึกลงบัญชีไม่สำเร็จ'), findsNothing);
  });

  testWidgets('language screen renders and saves a runtime third locale', (
    tester,
  ) async {
    final api = _LanguageApiClient();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_testConfig),
          mobileBootstrapProvider.overrideWith(
            (_) async => MobileBootstrap.fromJson(
              const {},
              defaultLocale: 'th-TH',
              defaultSiteName: 'Test',
            ),
          ),
          profileSettingsRepositoryProvider.overrideWithValue(
            ProfileSettingsRepository(api),
          ),
          customerSupportedLocaleOptionsProvider.overrideWithValue(
            _runtimeLocaleOptions,
          ),
        ],
        child: const _LocaleHarness(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('日本語'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('profile_language_ja-JP')));
    await tester.pumpAndSettle();

    expect(api.savedLocale, 'ja-JP');
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
  });

  testWidgets('language save follows backend maintenance redirect', (
    tester,
  ) async {
    final api = _LanguageApiClient(
      error: _apiException(
        'ร้านค้าปิดปรับปรุงชั่วคราว',
        path: '/customer/profile',
        code: 'maintenance_active',
        statusCode: 503,
      ),
    );
    final router = GoRouter(
      initialLocation: '/profile/language',
      routes: [
        GoRoute(
          path: '/profile/language',
          builder: (_, __) => const LanguageScreen(),
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
          appConfigProvider.overrideWithValue(_testConfig),
          mobileBootstrapProvider.overrideWith(
            (_) async => MobileBootstrap.fromJson(
              const {},
              defaultLocale: 'th-TH',
              defaultSiteName: 'Test',
            ),
          ),
          profileSettingsRepositoryProvider.overrideWithValue(
            ProfileSettingsRepository(api),
          ),
          customerSupportedLocaleOptionsProvider.overrideWithValue(
            _runtimeLocaleOptions,
          ),
        ],
        child: _LocaleRouterHarness(router: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('profile_language_en-US')));
    await tester.pumpAndSettle();

    expect(find.text('Maintenance route'), findsOneWidget);
  });
}

const _testConfig = AppConfig(
  apiBaseUrl: 'https://partner.example.test/api/v1',
  defaultLocale: 'th-TH',
);

const _runtimeLocaleOptions = <CustomerLocaleOption>[
  CustomerLocaleOption(
    locale: Locale('th', 'TH'),
    name: 'Thai',
    nativeName: 'ไทย',
    isDefault: true,
    sortOrder: 10,
  ),
  CustomerLocaleOption(
    locale: Locale('en', 'US'),
    name: 'English',
    nativeName: 'English',
    sortOrder: 20,
  ),
  CustomerLocaleOption(
    locale: Locale('ja', 'JP'),
    name: 'Japanese',
    nativeName: '日本語',
    sortOrder: 30,
  ),
];

class _LocaleHarness extends ConsumerWidget {
  const _LocaleHarness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(customerLocaleProvider);
    final localeOptions = ref.watch(customerSupportedLocaleOptionsProvider);
    return MaterialApp(
      locale: locale,
      supportedLocales: customerAppSupportedLocales(
        localeOptions,
        activeLocale: locale,
      ),
      localizationsDelegates: const [
        CustomerLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const LanguageScreen(),
    );
  }
}

class _LocaleRouterHarness extends ConsumerWidget {
  const _LocaleRouterHarness({required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(customerLocaleProvider);
    final localeOptions = ref.watch(customerSupportedLocaleOptionsProvider);
    return MaterialApp.router(
      routerConfig: router,
      locale: locale,
      supportedLocales: customerAppSupportedLocales(
        localeOptions,
        activeLocale: locale,
      ),
      localizationsDelegates: const [
        CustomerLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}

class _LanguageApiClient extends ApiClient {
  _LanguageApiClient({this.fail = false, this.error})
      : super(
          const AppConfig(
            apiBaseUrl: 'https://partner.example.test/api/v1',
            defaultLocale: 'th-TH',
          ),
          AuthTokenStore(),
          localeTag: 'th-TH',
        );

  final bool fail;
  final Object? error;
  String savedLocale = '';

  @override
  Future<Response<T>> patchWithHeaders<T>(
    String path, {
    Object? data,
    bool auth = true,
    Map<String, String> headers = const {},
  }) async {
    final requestError = error;
    if (requestError != null) throw requestError;
    if (fail) throw StateError('save failed');
    final payload = Map<String, dynamic>.from(data as Map);
    savedLocale = payload['preferred_locale'] as String;
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: {
        'data': {
          'id': 'cus_1',
          'member_no': 'CUS001234',
          'name': 'Demo Customer',
          'phone': '0812345678',
          'preferred_locale': savedLocale,
          'reward_payout_bank_account': <String, dynamic>{},
          'auto_reward_claim': <String, dynamic>{},
        },
      } as T,
    );
  }
}

DioException _apiException(
  String message, {
  required String path,
  String code = '',
  int statusCode = 422,
}) {
  final request = RequestOptions(path: path);
  return DioException(
    requestOptions: request,
    response: Response<Map<String, dynamic>>(
      requestOptions: request,
      statusCode: statusCode,
      data: {
        if (code.isNotEmpty) 'code': code,
        'message': message,
      },
    ),
  );
}
