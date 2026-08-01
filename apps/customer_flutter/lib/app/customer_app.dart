import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'customer_routes.dart';
import 'router.dart';
import '../core/auth/auth_controller.dart';
import '../core/auth/customer_session_replacement_monitor.dart';
import '../core/config/app_config.dart';
import '../core/i18n/app_locale.dart';
import '../core/i18n/customer_locale_controller.dart';
import '../core/i18n/customer_localizations.dart';
import '../core/i18n/customer_translation_repository.dart';
import '../core/navigation/deep_link_listener.dart';
import '../core/navigation/web_runtime.dart' as web_runtime;
import '../core/notifications/customer_push_lifecycle_monitor.dart';
import '../core/realtime/customer_realtime_monitor.dart';
import '../core/security/biometric_auth_service.dart';
import '../core/tenant/mobile_bootstrap_controller.dart';
import '../core/tenant/mobile_runtime_policy.dart';
import '../core/theme/app_theme.dart';
import '../features/affiliate/presentation/affiliate_referral_monitor.dart';
import '../features/lottery/presentation/customer_revenue_realtime_monitor.dart';
import '../features/lottery/presentation/lottery_stock_realtime_monitor.dart';
import '../features/lottery/presentation/sale_closure_guard.dart';
import '../features/monitoring/presentation/public_visit_monitor.dart';
import '../features/news/presentation/announcement_modal_host.dart';
import '../features/notifications/presentation/customer_notification_realtime_monitor.dart';
import '../features/results/presentation/result_realtime_monitor.dart';
import '../features/reward_claims/presentation/claim_realtime_monitor.dart';
import '../features/topup/presentation/topup_realtime_monitor.dart';
import '../shared/widgets/app_alert.dart';
import '../shared/widgets/app_splash.dart';
import '../shared/widgets/sensitive_screen_guard.dart';
import '../shared/widgets/web_privacy_guard.dart';

class CustomerApp extends ConsumerStatefulWidget {
  const CustomerApp({super.key});

  @override
  ConsumerState<CustomerApp> createState() => _CustomerAppState();
}

class _CustomerAppState extends ConsumerState<CustomerApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final platformKey = ref.read(customerPlatformKeyProvider);
    if (platformKey.trim().toLowerCase() == 'web') return;
    if (ref.read(biometricPromptCoordinatorProvider).isActive) return;
    if (_shouldLockForLifecycleState(state) && _currentRouteIsSensitive()) {
      ref.read(authControllerProvider).lockForAppLifecycle();
    }
  }

  bool _shouldLockForLifecycleState(AppLifecycleState state) {
    return state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached;
  }

  bool _currentRouteIsSensitive() {
    final router = ref.read(appRouterProvider);
    final path = router.routeInformationProvider.value.uri.path;
    final extraSensitiveRoutes = ref
        .read(mobileBootstrapProvider)
        .maybeWhen(
          data: (data) => data.screenSecurity.sensitiveRoutes,
          orElse: () => const <String>[],
        );
    return isSensitiveCustomerPath(
      path,
      extraSensitiveRoutes: extraSensitiveRoutes,
    );
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final runtimeLocale = ref.watch(customerLocaleProvider);
    final platformKey = ref.watch(customerPlatformKeyProvider);
    final config = ref.watch(appConfigProvider);
    final bootstrap = ref.watch(mobileBootstrapProvider);
    final translationBundle =
        ref.watch(customerTranslationBundleProvider).valueOrNull ??
        const CustomerTranslationBundle();
    final runtimeTranslations = translationBundle.messages;
    final runtimeLocaleOptions = ref.watch(
      customerSupportedLocaleOptionsProvider,
    );
    ref.listen<AsyncValue<MobileBootstrap>>(mobileBootstrapProvider, (_, next) {
      next.whenData(
        (data) => syncCustomerLocaleFromBootstrap(ref, data.locale),
      );
    });
    ref.listen<AuthController>(
      authControllerProvider,
      (_, next) => syncCustomerLocaleFromProfile(ref, next.preferredLocale),
    );
    final appTitle = bootstrap.maybeWhen(
      data: (data) => data.siteName.trim().isEmpty
          ? config.runtimeDisplayName
          : data.siteName.trim(),
      orElse: () => config.runtimeDisplayName,
    );
    final appLocale = runtimeLocale;
    final appSupportedLocales = customerAppSupportedLocales(
      runtimeLocaleOptions,
      activeLocale: appLocale,
    );
    Intl.defaultLocale = localeTag(appLocale).replaceAll('-', '_');
    final appTheme = bootstrap.maybeWhen(
      data: (data) =>
          AppTheme.light(tokens: data.theme, useRuntimeBrandColors: true),
      orElse: AppTheme.light,
    );
    final pwaIconUrl = bootstrap.maybeWhen(
      data: (data) {
        final faviconUrl = data.brand.faviconUrl.trim();
        return faviconUrl.isNotEmpty ? faviconUrl : data.brand.logoUrl.trim();
      },
      orElse: () => '',
    );
    web_runtime.syncWebSystemChromeColor(
      appTheme.colorScheme.primary.toARGB32(),
    );
    web_runtime.syncWebPwaIdentity(appName: appTitle, iconUrl: pwaIconUrl);
    final screenSecurityEnabled = bootstrap.maybeWhen(
      data: (data) =>
          mobileNativeScreenSecurityAllowedForPlatform(data, platformKey),
      orElse: () => mobileNativeScreenSecurityFallbackForPlatform(platformKey),
    );
    const webPrivacyEnabled = false;

    return MaterialApp.router(
      title: appTitle,
      debugShowCheckedModeBanner: false,
      theme: appTheme,
      locale: appLocale,
      routerConfig: router,
      builder: (context, child) {
        final appChild = child ?? const SizedBox.shrink();
        return ListenableBuilder(
          listenable: router.routeInformationProvider,
          builder: (context, _) {
            final path = normalizeCustomerRoutePath(
              router.routeInformationProvider.value.uri.path,
            );
            final statusBarBackgroundColor = _statusBarBackgroundColorFor(
              appTheme,
              path,
            );
            final systemUiOverlayStyle = _systemUiOverlayStyleFor(
              appTheme,
              statusBarBackgroundColor: statusBarBackgroundColor,
            );

            return AnnotatedRegion<SystemUiOverlayStyle>(
              key: const ValueKey('customer-system-ui-overlay'),
              value: systemUiOverlayStyle,
              child: CustomerDeepLinkListener(
                child: AppSplashHost(
                  child: CustomerRealtimeMonitor(
                    child: CustomerPushLifecycleMonitor(
                      router: router,
                      child: CustomerNotificationRealtimeMonitor(
                        child: ResultRealtimeMonitor(
                          child: LotteryStockRealtimeMonitor(
                            child: CustomerRevenueRealtimeMonitor(
                              child: CustomerTopupRealtimeMonitor(
                                child: CustomerClaimRealtimeMonitor(
                                  child: PublicVisitMonitor(
                                    router: router,
                                    child: AffiliateReferralMonitor(
                                      router: router,
                                      child: AppAlertHost(
                                        child: CustomerSessionReplacementMonitor(
                                          child: AnnouncementModalHost(
                                            router: router,
                                            child: SaleClosureGuard(
                                              router: router,
                                              child:
                                                  _CustomerRuntimeSecurityLayer(
                                                    router: router,
                                                    bootstrap: bootstrap,
                                                    platformKey: platformKey,
                                                    screenSecurityEnabled:
                                                        screenSecurityEnabled,
                                                    webPrivacyEnabled:
                                                        webPrivacyEnabled,
                                                    child: appChild,
                                                  ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
      supportedLocales: appSupportedLocales,
      localizationsDelegates: [
        RuntimeCustomerLocalizationsDelegate(runtimeTranslations),
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      localeResolutionCallback: (deviceLocale, supportedLocales) {
        return resolveCustomerLocale(deviceLocale, supportedLocales);
      },
    );
  }
}

Color _statusBarBackgroundColorFor(ThemeData theme, String path) {
  return switch (path) {
    '/pin' || '/security-lock' => theme.colorScheme.surface,
    _ => theme.colorScheme.primary,
  };
}

SystemUiOverlayStyle _systemUiOverlayStyleFor(
  ThemeData theme, {
  Color? statusBarBackgroundColor,
}) {
  final resolvedStatusBarBackgroundColor =
      statusBarBackgroundColor ?? theme.colorScheme.primary;
  final navigationBarColor = theme.scaffoldBackgroundColor;
  final statusBarBackgroundBrightness = ThemeData.estimateBrightnessForColor(
    resolvedStatusBarBackgroundColor,
  );
  final navigationBarBackgroundBrightness =
      ThemeData.estimateBrightnessForColor(navigationBarColor);

  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: _contrastingBrightness(
      statusBarBackgroundBrightness,
    ),
    statusBarBrightness: statusBarBackgroundBrightness,
    systemNavigationBarColor: navigationBarColor,
    systemNavigationBarIconBrightness: _contrastingBrightness(
      navigationBarBackgroundBrightness,
    ),
    systemNavigationBarDividerColor: theme.colorScheme.outlineVariant,
    systemNavigationBarContrastEnforced: false,
  );
}

Brightness _contrastingBrightness(Brightness backgroundBrightness) {
  return backgroundBrightness == Brightness.dark
      ? Brightness.light
      : Brightness.dark;
}

class _CustomerRuntimeSecurityLayer extends StatelessWidget {
  const _CustomerRuntimeSecurityLayer({
    required this.router,
    required this.bootstrap,
    required this.platformKey,
    required this.screenSecurityEnabled,
    required this.webPrivacyEnabled,
    required this.child,
  });

  final GoRouter router;
  final AsyncValue<MobileBootstrap> bootstrap;
  final String platformKey;
  final bool screenSecurityEnabled;
  final bool webPrivacyEnabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: router.routeInformationProvider,
      builder: (context, _) {
        final path = router.routeInformationProvider.value.uri.path;
        final extraSensitiveRoutes = bootstrap.maybeWhen(
          data: (data) => data.screenSecurity.sensitiveRoutes,
          orElse: () => const <String>[],
        );
        final screenSecurity = bootstrap.maybeWhen(
          data: (data) => data.screenSecurity,
          orElse: () => null,
        );
        final routeSensitive = isSensitiveCustomerPath(
          path,
          extraSensitiveRoutes: extraSensitiveRoutes,
        );
        final normalizedPlatformKey = platformKey.trim().toLowerCase();
        final protectEntireAndroidApp = normalizedPlatformKey == 'android';
        final protectEntireIosApp = normalizedPlatformKey == 'ios';

        return SensitiveScreenGuard(
          enabled:
              protectEntireAndroidApp ||
              (screenSecurityEnabled &&
                  (protectEntireIosApp || routeSensitive)),
          route: path.isEmpty ? 'app' : path,
          androidFlagSecure: protectEntireAndroidApp
              ? true
              : screenSecurity?.androidFlagSecure,
          androidProtectRecentAppPreview: protectEntireAndroidApp
              ? true
              : screenSecurity?.androidProtectRecentAppPreview,
          iosScreenshotPolicy: screenSecurity?.iosScreenshotPolicy,
          iosScreenCaptureOverlay: screenSecurity?.iosScreenCaptureOverlay,
          iosExitApp: screenSecurity?.iosExitApp,
          privacyOverlayTitle: screenSecurity?.privacyOverlayTitle,
          privacyOverlayDescription: screenSecurity?.privacyOverlayDescription,
          lockOnCapture: screenSecurity == null
              ? true
              : mobileNativeScreenSecurityLocksOnCapture(
                  screenSecurity,
                  platformKey,
                ),
          child: WebPrivacyGuard(
            enabled: webPrivacyEnabled && routeSensitive,
            mode: screenSecurity?.webSensitiveScreenMode ?? 'limited',
            watermarkEnabled: false,
            privacyOverlayTitle: screenSecurity?.privacyOverlayTitle,
            privacyOverlayDescription:
                screenSecurity?.privacyOverlayDescription,
            child: child,
          ),
        );
      },
    );
  }
}
