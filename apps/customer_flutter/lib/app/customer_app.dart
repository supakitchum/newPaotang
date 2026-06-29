import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'customer_routes.dart';
import 'router.dart';
import '../core/auth/auth_controller.dart';
import '../core/config/app_config.dart';
import '../core/i18n/app_locale.dart';
import '../core/i18n/customer_locale_controller.dart';
import '../core/i18n/customer_localizations.dart';
import '../core/i18n/customer_translation_repository.dart';
import '../core/navigation/deep_link_listener.dart';
import '../core/realtime/customer_realtime_monitor.dart';
import '../core/tenant/mobile_bootstrap_controller.dart';
import '../core/tenant/mobile_runtime_policy.dart';
import '../core/theme/app_theme.dart';
import '../features/affiliate/presentation/affiliate_referral_monitor.dart';
import '../features/lottery/presentation/lottery_stock_realtime_monitor.dart';
import '../features/lottery/presentation/sale_closure_guard.dart';
import '../features/monitoring/presentation/public_visit_monitor.dart';
import '../features/news/presentation/announcement_modal_host.dart';
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
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      ref.read(authControllerProvider).lockForAppLifecycle();
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final runtimeLocale = ref.watch(customerLocaleProvider);
    final platformKey = ref.watch(customerPlatformKeyProvider);
    final config = ref.watch(appConfigProvider);
    final bootstrap = ref.watch(mobileBootstrapProvider);
    final runtimeTranslations =
        ref.watch(customerTranslationBundleProvider).maybeWhen(
              data: (messages) => messages,
              orElse: () => const <String, String>{},
            );
    ref.listen<AsyncValue<MobileBootstrap>>(
      mobileBootstrapProvider,
      (_, next) {
        next.whenData(
          (data) => syncCustomerLocaleFromBootstrap(ref, data.locale),
        );
      },
    );
    final appTitle = bootstrap.maybeWhen(
      data: (data) => data.siteName.trim().isEmpty
          ? config.runtimeDisplayName
          : data.siteName.trim(),
      orElse: () => config.runtimeDisplayName,
    );
    final appLocale = runtimeLocale;
    Intl.defaultLocale = localeTag(appLocale).replaceAll('-', '_');
    final appTheme = bootstrap.maybeWhen(
      data: (data) => AppTheme.light(tokens: data.theme),
      orElse: AppTheme.light,
    );
    final screenSecurityEnabled = bootstrap.maybeWhen(
      data: (data) =>
          mobileNativeScreenSecurityAllowedForPlatform(data, platformKey),
      orElse: () => mobileNativeScreenSecurityFallbackForPlatform(platformKey),
    );
    final webPrivacyEnabled = bootstrap.maybeWhen(
      data: (data) =>
          mobileWebPrivacyGuardAllowedForPlatform(data, platformKey),
      orElse: () => mobileWebPrivacyGuardFallbackForPlatform(platformKey),
    );

    return MaterialApp.router(
      title: appTitle,
      debugShowCheckedModeBanner: false,
      theme: appTheme,
      locale: appLocale,
      routerConfig: router,
      builder: (context, child) {
        final appChild = child ?? const SizedBox.shrink();
        return CustomerDeepLinkListener(
          child: AppSplashHost(
            child: CustomerRealtimeMonitor(
              child: ResultRealtimeMonitor(
                child: LotteryStockRealtimeMonitor(
                  child: CustomerTopupRealtimeMonitor(
                    child: CustomerClaimRealtimeMonitor(
                      child: PublicVisitMonitor(
                        router: router,
                        child: AffiliateReferralMonitor(
                          router: router,
                          child: AppAlertHost(
                            child: AnnouncementModalHost(
                              router: router,
                              child: SaleClosureGuard(
                                router: router,
                                child: _CustomerRuntimeSecurityLayer(
                                  router: router,
                                  bootstrap: bootstrap,
                                  screenSecurityEnabled: screenSecurityEnabled,
                                  webPrivacyEnabled: webPrivacyEnabled,
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
        );
      },
      supportedLocales: const [Locale('th', 'TH'), Locale('en', 'US')],
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

class _CustomerRuntimeSecurityLayer extends StatelessWidget {
  const _CustomerRuntimeSecurityLayer({
    required this.router,
    required this.bootstrap,
    required this.screenSecurityEnabled,
    required this.webPrivacyEnabled,
    required this.child,
  });

  final GoRouter router;
  final AsyncValue<MobileBootstrap> bootstrap;
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
        final routeSensitive = isSensitiveCustomerPath(
          path,
          extraSensitiveRoutes: extraSensitiveRoutes,
        );

        return SensitiveScreenGuard(
          enabled: screenSecurityEnabled,
          route: path.isEmpty ? 'app' : path,
          child: WebPrivacyGuard(
            enabled: webPrivacyEnabled && routeSensitive,
            child: child,
          ),
        );
      },
    );
  }
}
