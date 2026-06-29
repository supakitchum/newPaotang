import 'package:customer_flutter/core/auth/auth_repository.dart';
import 'package:customer_flutter/core/auth/auth_token_store.dart';
import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/i18n/app_locale.dart';
import 'package:customer_flutter/core/i18n/customer_localizations.dart';
import 'package:customer_flutter/core/network/api_client.dart';
import 'package:customer_flutter/core/tenant/mobile_bootstrap_controller.dart';
import 'package:customer_flutter/features/affiliate/data/affiliate_referral_repository.dart';
import 'package:customer_flutter/features/auth/presentation/line_auth_screens.dart';
import 'package:customer_flutter/features/auth/presentation/login_screen.dart';
import 'package:customer_flutter/features/monitoring/data/public_visit_id_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets(
      'login renders every enabled store-compliant social provider from runtime config',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mobileBootstrapProvider.overrideWith(
            (_) async => MobileBootstrap.fromJson({
              'mobile': {
                'auth_providers': [
                  {'provider': 'line_login', 'enabled': true},
                  {'provider': 'google_oauth', 'enabled': true},
                  {'provider': 'apple_id', 'enabled': true},
                  {'provider': 'discord', 'enabled': true},
                  {'provider': 'gmail', 'enabled': false},
                ],
              },
            }),
          ),
        ],
        child: const _LoginTestApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Continue with LINE'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue with Apple ID'), findsOneWidget);
    expect(find.text('Continue with discord'), findsNothing);
  });

  testWidgets(
      'generic social callback routes unlinked Google users to phone link',
      (tester) async {
    final repository = _SocialAuthRepository(
      callbackResult: const SocialCallbackResult(
        provider: 'google',
        code: 0,
        lineLinkRequired: true,
        linkToken: 'google-link-token',
        displayName: 'Ada Google',
        pictureUrl: '',
        passwordResetReady: false,
        passwordResetToken: '',
        orderId: '',
        message: '',
      ),
    );

    final router = _router(initialLocation: '/social/google/callback?code=abc');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_testConfig),
          authRepositoryProvider.overrideWithValue(repository),
          affiliateReferralServiceProvider.overrideWithValue(
            _NoopAffiliateReferralService(),
          ),
        ],
        child: _TestApp(router: router),
      ),
    );

    await _pumpCallbackWork(tester);

    expect(repository.lastCallbackProvider, 'google');
    expect(repository.lastCallbackQuery?['code'], 'abc');
    expect(
      find.text('link:google:google-link-token:Ada Google'),
      findsOneWidget,
    );
  });

  testWidgets(
      'generic social callback applies Apple session and enters PIN flow',
      (tester) async {
    final repository = _SocialAuthRepository(
      callbackResult: const SocialCallbackResult(
        provider: 'apple',
        code: 0,
        lineLinkRequired: false,
        linkToken: '',
        displayName: '',
        pictureUrl: '',
        passwordResetReady: false,
        passwordResetToken: '',
        orderId: '',
        message: '',
        session: CustomerSession(
          accessToken: 'access-token',
          refreshToken: 'refresh-token',
          pinRequired: true,
          pinSetupRequired: false,
          customerId: 'cus_apple',
        ),
      ),
    );
    final affiliate = _NoopAffiliateReferralService();

    final router = _router(initialLocation: '/social/apple/callback?code=abc');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_testConfig),
          authRepositoryProvider.overrideWithValue(repository),
          affiliateReferralServiceProvider.overrideWithValue(affiliate),
        ],
        child: _TestApp(router: router),
      ),
    );

    await _pumpCallbackWork(tester);

    expect(repository.lastCallbackProvider, 'apple');
    expect(affiliate.applied, isTrue);
    expect(router.routerDelegate.currentConfiguration.uri.path, '/pin');
    expect(find.text('pin-flow'), findsOneWidget);
  });

  testWidgets('generic social link-phone submits Google provider and signs in',
      (tester) async {
    final repository = _SocialAuthRepository(
      callbackResult: const SocialCallbackResult(
        provider: 'google',
        code: 0,
        lineLinkRequired: false,
        linkToken: '',
        displayName: '',
        pictureUrl: '',
        passwordResetReady: false,
        passwordResetToken: '',
        orderId: '',
        message: '',
      ),
      linkSession: const CustomerSession(
        accessToken: 'linked-access-token',
        refreshToken: 'linked-refresh-token',
        pinRequired: true,
        pinSetupRequired: false,
        customerId: 'cus_google_linked',
      ),
    );
    final affiliate = _NoopAffiliateReferralService();

    final router = _router(
      initialLocation:
          '/social/google/link-phone?token=google-link-token&name=Ada%20Google',
      useRealLinkPhoneScreen: true,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_testConfig),
          authRepositoryProvider.overrideWithValue(repository),
          affiliateReferralServiceProvider.overrideWithValue(affiliate),
        ],
        child: _TestApp(router: router),
      ),
    );

    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), '0812345678');
    await tester.enterText(find.byType(TextField).at(1), 'secret1234');
    await tester.enterText(find.byType(TextField).at(2), 'secret1234');
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.pump();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(repository.lastLinkProvider, 'google');
    expect(repository.lastLinkToken, 'google-link-token');
    expect(repository.lastLinkPhone, '0812345678');
    expect(repository.lastLinkPassword, 'secret1234');
    expect(affiliate.applied, isTrue);
    expect(router.routerDelegate.currentConfiguration.uri.path, '/pin');
    expect(find.text('pin-flow'), findsOneWidget);
  });

  testWidgets('social link-phone keeps content usable on narrow mobile screens',
      (tester) async {
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _SocialAuthRepository(
      callbackResult: const SocialCallbackResult(
        provider: 'line',
        code: 0,
        lineLinkRequired: false,
        linkToken: '',
        displayName: '',
        pictureUrl: '',
        passwordResetReady: false,
        passwordResetToken: '',
        orderId: '',
        message: '',
      ),
    );
    final router = _router(
      initialLocation: Uri(
        path: '/social/line/link-phone',
        queryParameters: {
          'token': 'line-link-token',
          'name': 'สมาชิกชื่อยาวมากสำหรับทดสอบการตัดคำในหน้าผูกบัญชีไลน์',
        },
      ).toString(),
      useRealLinkPhoneScreen: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_testConfig),
          authRepositoryProvider.overrideWithValue(repository),
          affiliateReferralServiceProvider.overrideWithValue(
            _NoopAffiliateReferralService(),
          ),
        ],
        child: _TestApp(router: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('LINE account'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(3));
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.byType(FilledButton), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _LoginTestApp extends StatelessWidget {
  const _LoginTestApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      locale: Locale('en', 'US'),
      supportedLocales: supportedCustomerLocales,
      localizationsDelegates: [
        CustomerLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: LoginScreen(),
    );
  }
}

Future<void> _pumpCallbackWork(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(seconds: 1));
}

GoRouter _router({
  required String initialLocation,
  bool useRealLinkPhoneScreen = false,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/social/:provider/callback',
        builder: (context, state) => LineCallbackScreen(
          provider: state.pathParameters['provider'] ?? 'line',
          query: state.uri.queryParameters,
        ),
      ),
      GoRoute(
        path: '/social/:provider/link-phone',
        builder: (context, state) => useRealLinkPhoneScreen
            ? LineLinkPhoneScreen(
                provider: state.pathParameters['provider'] ?? 'line',
                linkToken: state.uri.queryParameters['token'] ?? '',
                displayName: state.uri.queryParameters['name'] ?? '',
                pictureUrl: state.uri.queryParameters['picture_url'] ?? '',
                redirect: state.uri.queryParameters['redirect'] ?? '/',
              )
            : Text(
                [
                  'link',
                  state.pathParameters['provider'] ?? '',
                  state.uri.queryParameters['token'] ?? '',
                  state.uri.queryParameters['name'] ?? '',
                ].join(':'),
                textDirection: TextDirection.ltr,
              ),
      ),
      GoRoute(
        path: '/pin',
        builder: (context, state) => const Text(
          'pin-flow',
          textDirection: TextDirection.ltr,
        ),
      ),
    ],
  );
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      locale: const Locale('en', 'US'),
      supportedLocales: supportedCustomerLocales,
      localizationsDelegates: const [
        CustomerLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}

const _testConfig = AppConfig(
  apiBaseUrl: 'https://partner.example.com/api/v1',
  defaultLocale: 'en-US',
);

class _SocialAuthRepository extends AuthRepository {
  _SocialAuthRepository({
    required this.callbackResult,
    this.linkSession = const CustomerSession(
      accessToken: 'linked-access',
      refreshToken: 'linked-refresh',
      pinRequired: false,
      pinSetupRequired: false,
      customerId: 'cus_linked',
    ),
  }) : super(
          api: ApiClient(
            const AppConfig(
              apiBaseUrl: 'https://partner.example.com/api/v1',
              defaultLocale: 'en-US',
            ),
            AuthTokenStore(),
            localeTag: 'en-US',
          ),
          tokenStore: AuthTokenStore(),
        );

  final SocialCallbackResult callbackResult;
  final CustomerSession linkSession;
  String? lastCallbackProvider;
  Map<String, dynamic>? lastCallbackQuery;
  String? lastLinkProvider;
  String? lastLinkToken;
  String? lastLinkPhone;
  String? lastLinkPassword;
  String? lastLinkPasswordConfirmation;

  @override
  Future<SocialCallbackResult> socialCallback({
    required String provider,
    required Map<String, dynamic> query,
  }) async {
    lastCallbackProvider = provider;
    lastCallbackQuery = query;
    return callbackResult;
  }

  @override
  Future<CustomerSession> socialLinkPhone({
    required String provider,
    required String linkToken,
    required String phone,
    required String password,
    required String passwordConfirmation,
  }) async {
    lastLinkProvider = provider;
    lastLinkToken = linkToken;
    lastLinkPhone = phone;
    lastLinkPassword = password;
    lastLinkPasswordConfirmation = passwordConfirmation;
    return linkSession;
  }
}

class _NoopAffiliateReferralService extends AffiliateReferralService {
  _NoopAffiliateReferralService()
      : super(
          config: const AppConfig(
            apiBaseUrl: 'https://partner.example.com/api/v1',
            defaultLocale: 'en-US',
          ),
          repository: AffiliateReferralRepository(
            ApiClient(
              const AppConfig(
                apiBaseUrl: 'https://partner.example.com/api/v1',
                defaultLocale: 'en-US',
              ),
              AuthTokenStore(),
              localeTag: 'en-US',
            ),
          ),
          store: AffiliateReferralStore(),
          visitIdStore: PublicVisitIdStore(idFactory: (_) => 'visitor'),
        );

  bool applied = false;

  @override
  Future<void> applyStored({bool registered = false}) async {
    applied = true;
  }
}
