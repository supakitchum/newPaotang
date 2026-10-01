import 'package:customer_flutter/app/customer_app.dart';
import 'package:customer_flutter/app/router.dart';
import 'package:customer_flutter/core/auth/auth_token_store.dart';
import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/network/api_client.dart';
import 'package:customer_flutter/core/realtime/customer_realtime_monitor.dart';
import 'package:customer_flutter/core/tenant/mobile_bootstrap_controller.dart';
import 'package:customer_flutter/core/tenant/mobile_runtime_policy.dart';
import 'package:customer_flutter/features/affiliate/presentation/affiliate_referral_monitor.dart';
import 'package:customer_flutter/features/lottery/presentation/customer_revenue_realtime_monitor.dart';
import 'package:customer_flutter/features/lottery/presentation/lottery_stock_realtime_monitor.dart';
import 'package:customer_flutter/features/monitoring/presentation/public_visit_monitor.dart';
import 'package:customer_flutter/features/news/data/news_models.dart';
import 'package:customer_flutter/features/news/data/news_repository.dart';
import 'package:customer_flutter/features/results/presentation/result_realtime_monitor.dart';
import 'package:customer_flutter/features/reward_claims/presentation/claim_realtime_monitor.dart';
import 'package:customer_flutter/features/topup/presentation/topup_realtime_monitor.dart';
import 'package:customer_flutter/shared/widgets/app_splash.dart';
import 'package:customer_flutter/shared/widgets/sensitive_screen_guard.dart';
import 'package:customer_flutter/shared/widgets/web_privacy_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Future<void> runCustomerAppSmokeHarness(
  WidgetTester tester, {
  String? platformKey,
  Map<String, dynamic>? bootstrapPayload,
  Color? expectedPrimaryColor,
  Color? expectedScaffoldBackgroundColor,
  String? expectedFontFamily,
}) async {
  final effectivePlatformKey = platformKey ?? currentCustomerPlatformKey();
  final protectsEntireNativeApp =
      effectivePlatformKey == 'android' || effectivePlatformKey == 'ios';
  final expectsNativeSecurity = mobileNativeScreenSecurityFallbackForPlatform(
    effectivePlatformKey,
  );
  const expectsWebPrivacy = false;
  final router = _smokeRouter();

  await tester.pumpWidget(
    ProviderScope(
      overrides: _smokeOverrides(
        router,
        effectivePlatformKey,
        bootstrapPayload: bootstrapPayload,
      ),
      child: const CustomerApp(),
    ),
  );

  await tester.pumpAndSettle();

  expect(find.text('Smoke home'), findsOneWidget);
  final homeContext = tester.element(find.text('Smoke home'));
  final homeTheme = Theme.of(homeContext);
  if (expectedPrimaryColor != null) {
    expect(homeTheme.colorScheme.primary, expectedPrimaryColor);
  }
  if (expectedScaffoldBackgroundColor != null) {
    expect(homeTheme.scaffoldBackgroundColor, expectedScaffoldBackgroundColor);
  }
  if (expectedFontFamily != null) {
    expect(homeTheme.textTheme.bodyMedium?.fontFamily, expectedFontFamily);
  }
  final systemUiOverlay = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
    find.byKey(const ValueKey('customer-system-ui-overlay')),
  );
  expect(systemUiOverlay.value.statusBarColor, Colors.transparent);
  expect(
    systemUiOverlay.value.systemNavigationBarColor,
    homeTheme.scaffoldBackgroundColor,
  );
  expect(
    systemUiOverlay.value.systemNavigationBarDividerColor,
    homeTheme.colorScheme.outlineVariant,
  );
  expect(
    systemUiOverlay.value.statusBarIconBrightness,
    ThemeData.estimateBrightnessForColor(homeTheme.colorScheme.primary) ==
            Brightness.dark
        ? Brightness.light
        : Brightness.dark,
  );
  expect(
    systemUiOverlay.value.systemNavigationBarIconBrightness,
    ThemeData.estimateBrightnessForColor(homeTheme.scaffoldBackgroundColor) ==
            Brightness.dark
        ? Brightness.light
        : Brightness.dark,
  );
  expect(
    find.byKey(const ValueKey('customer-status-bar-background')),
    findsNothing,
  );
  expect(
    tester.widget<WebPrivacyGuard>(find.byType(WebPrivacyGuard)).enabled,
    isFalse,
  );
  final homeSecurityGuard = tester.widget<SensitiveScreenGuard>(
    find.byType(SensitiveScreenGuard),
  );
  expect(homeSecurityGuard.enabled, protectsEntireNativeApp);
  if (effectivePlatformKey == 'android') {
    expect(homeSecurityGuard.androidFlagSecure, isTrue);
    expect(homeSecurityGuard.androidProtectRecentAppPreview, isTrue);
  }

  router.go('/privacy');
  await tester.pumpAndSettle();

  expect(find.text('Smoke privacy'), findsOneWidget);
  expect(
    tester.widget<WebPrivacyGuard>(find.byType(WebPrivacyGuard)).enabled,
    isFalse,
  );

  router.go('/my-wallet');
  await tester.pumpAndSettle();

  expect(find.text('Smoke wallet'), findsOneWidget);
  expect(
    tester.widget<WebPrivacyGuard>(find.byType(WebPrivacyGuard)).enabled,
    expectsWebPrivacy,
  );
  expect(
    tester
        .widget<SensitiveScreenGuard>(find.byType(SensitiveScreenGuard))
        .enabled,
    expectsNativeSecurity,
  );

  router.go('/profile/account-deletion');
  await tester.pumpAndSettle();

  expect(find.text('Smoke account deletion'), findsOneWidget);
  expect(
    tester.widget<WebPrivacyGuard>(find.byType(WebPrivacyGuard)).enabled,
    expectsWebPrivacy,
  );
  expect(
    tester
        .widget<SensitiveScreenGuard>(find.byType(SensitiveScreenGuard))
        .enabled,
    expectsNativeSecurity,
  );
}

GoRouter _smokeRouter() {
  return GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Smoke home'))),
      ),
      GoRoute(
        path: '/my-wallet',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Smoke wallet'))),
      ),
      GoRoute(
        path: '/privacy',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Smoke privacy'))),
      ),
      GoRoute(
        path: '/profile/account-deletion',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Smoke account deletion'))),
      ),
    ],
  );
}

List<Override> _smokeOverrides(
  GoRouter router,
  String platformKey, {
  Map<String, dynamic>? bootstrapPayload,
}) {
  return [
    appConfigProvider.overrideWithValue(
      const AppConfig(
        apiBaseUrl: 'https://partner.example.com/api/v1',
        defaultLocale: 'en-US',
        appDisplayName: 'Partner Lottery',
      ),
    ),
    authTokenStoreProvider.overrideWithValue(AuthTokenStore()),
    appRouterProvider.overrideWithValue(router),
    appSplashMinimumDurationProvider.overrideWithValue(Duration.zero),
    appSplashFadeDurationProvider.overrideWithValue(Duration.zero),
    customerPlatformKeyProvider.overrideWithValue(platformKey),
    customerRealtimeEnabledProvider.overrideWithValue(false),
    resultRealtimeEnabledProvider.overrideWithValue(false),
    lotteryStockRealtimeEnabledProvider.overrideWithValue(false),
    customerRevenueRealtimeEnabledProvider.overrideWithValue(false),
    topupRealtimeEnabledProvider.overrideWithValue(false),
    claimRealtimeEnabledProvider.overrideWithValue(false),
    affiliateReferralMonitorEnabledProvider.overrideWithValue(false),
    publicVisitMonitorEnabledProvider.overrideWithValue(false),
    newsRepositoryProvider.overrideWithValue(_NoopNewsRepository()),
    mobileBootstrapProvider.overrideWith(
      (_) async => MobileBootstrap.fromJson(
        bootstrapPayload ??
            const {
              'tenant_id': 'tenant_smoke',
              'site': {'display_name': 'Partner Lottery', 'locale': 'en-US'},
              'mobile': {
                'auth_providers': [
                  {'provider': 'line', 'enabled': true},
                  {'provider': 'google', 'enabled': true},
                  {'provider': 'apple', 'enabled': true},
                ],
                'screen_security': {
                  'android': {
                    'flag_secure': true,
                    'protect_recent_app_preview': true,
                  },
                  'ios': {
                    'screenshot_policy': 'lock_and_blank',
                    'screen_capture_overlay': true,
                  },
                  'web': {
                    'sensitive_screen_mode': 'limited',
                    'watermark_enabled': true,
                  },
                },
              },
            },
        defaultLocale: 'en-US',
        defaultSiteName: 'Partner Lottery',
      ),
    ),
  ];
}

class _NoopNewsRepository extends NewsRepository {
  _NoopNewsRepository()
    : super(
        ApiClient(
          const AppConfig(
            apiBaseUrl: 'https://partner.example.com/api/v1',
            defaultLocale: 'en-US',
          ),
          AuthTokenStore(),
          localeTag: 'en-US',
        ),
        (value) => value,
      );

  @override
  Future<NewsItem?> modal() async => null;

  @override
  Future<List<NewsItem>> list({int limit = NewsRepository.defaultPageLimit}) {
    return Future.value(const []);
  }

  @override
  Future<List<NewsItem>> listAll({
    int limit = NewsRepository.defaultPageLimit,
    int maxPages = NewsRepository.maxAutoPages,
  }) {
    return Future.value(const []);
  }
}
