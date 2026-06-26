import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'router.dart';
import '../core/auth/auth_controller.dart';
import '../core/i18n/app_locale.dart';
import '../core/i18n/customer_locale_controller.dart';
import '../core/i18n/customer_localizations.dart';
import '../core/navigation/deep_link_listener.dart';
import '../core/realtime/customer_realtime_monitor.dart';
import '../core/tenant/mobile_bootstrap_controller.dart';
import '../core/tenant/mobile_runtime_policy.dart';
import '../core/theme/app_theme.dart';
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
    final bootstrap = ref.watch(mobileBootstrapProvider);
    ref.listen<AsyncValue<MobileBootstrap>>(
      mobileBootstrapProvider,
      (_, next) {
        next.whenData(
          (data) => syncCustomerLocaleFromBootstrap(ref, data.locale),
        );
      },
    );
    final appTitle = bootstrap.maybeWhen(
      data: (data) =>
          data.siteName.trim().isEmpty ? 'Customer App' : data.siteName.trim(),
      orElse: () => 'Customer App',
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
                        child: AppAlertHost(
                          child: AnnouncementModalHost(
                            router: router,
                            child: SaleClosureGuard(
                              router: router,
                              child: SensitiveScreenGuard(
                                enabled: screenSecurityEnabled,
                                route: 'app',
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
        );
      },
      supportedLocales: const [Locale('th', 'TH'), Locale('en', 'US')],
      localizationsDelegates: const [
        CustomerLocalizations.delegate,
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
