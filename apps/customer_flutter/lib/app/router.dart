import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_controller.dart';
import '../core/navigation/customer_back_navigation.dart';
import '../core/navigation/customer_deep_link.dart';
import '../core/navigation/customer_redirect.dart';
import '../features/activity_claims/presentation/activity_claim_detail_screen.dart';
import '../features/activity_claims/presentation/activity_claims_screen.dart';
import '../features/activities/presentation/activity_detail_screen.dart';
import '../features/activities/presentation/activities_screen.dart';
import '../features/affiliate/presentation/affiliate_screen.dart';
import '../features/auth/presentation/forgot_password_screen.dart';
import '../features/auth/presentation/line_auth_screens.dart';
import '../features/auth/presentation/login_otp_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/auth/presentation/register_otp_screen.dart';
import '../features/auth/presentation/reset_password_screen.dart';
import '../features/content/presentation/info_pages.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/lottery/presentation/lottery_screens.dart';
import '../features/news/presentation/news_detail_screen.dart';
import '../features/news/presentation/news_screen.dart';
import '../features/notifications/presentation/customer_notifications_screen.dart';
import '../features/pin/presentation/pin_screen.dart';
import '../features/profile/presentation/auto_reward_screen.dart';
import '../features/profile/presentation/account_deletion_screen.dart';
import '../features/profile/presentation/biometric_devices_screen.dart';
import '../features/profile/presentation/line_notifications_screen.dart';
import '../features/profile/presentation/language_screen.dart';
import '../features/profile/presentation/passkeys_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/profile/presentation/reward_bank_screen.dart';
import '../features/profile/presentation/social_accounts_screen.dart';
import '../features/purchase_history/presentation/purchase_history_detail_screen.dart';
import '../features/purchase_history/presentation/purchase_history_screen.dart';
import '../features/reward_claims/presentation/reward_claim_detail_screen.dart';
import '../features/reward_claims/presentation/reward_claims_screen.dart';
import '../features/results/presentation/result_detail_screen.dart';
import '../features/results/presentation/result_screen.dart';
import '../features/results/presentation/waiting_result_screen.dart';
import '../features/stores/presentation/store_screens.dart';
import '../features/support/presentation/support_screens.dart';
import '../features/system/presentation/system_pages.dart';
import '../features/tickets/presentation/tickets_screen.dart';
import '../features/topup/presentation/topup_history_screen.dart';
import '../features/topup/presentation/topup_screen.dart';
import '../features/wallet/presentation/wallet_screen.dart';
import '../shared/widgets/security_lock_screen.dart';
import 'customer_routes.dart';
import '../core/tenant/mobile_bootstrap_controller.dart';
import '../core/tenant/mobile_runtime_policy.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final routerRefresh = _RouterRefreshNotifier();
  ref
    ..listen<AuthController>(
      authControllerProvider,
      (_, __) => routerRefresh.refresh(),
    )
    ..listen<AsyncValue<MobileBootstrap>>(
      mobileBootstrapProvider,
      (_, __) => routerRefresh.refresh(),
    );

  late final GoRouter router;
  ref.onDispose(() {
    customerBackNavigationHistory.detach(router);
    router.dispose();
    routerRefresh.dispose();
  });

  router = GoRouter(
    initialLocation: '/',
    refreshListenable: routerRefresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final bootstrap = ref.read(mobileBootstrapProvider);
      final bootstrapData = bootstrap.valueOrNull;
      final maintenance = bootstrap.maybeWhen<MaintenanceConfig?>(
        data: (data) => data.maintenance,
        orElse: () => null,
      );
      if (state.uri.path == '/login/otp' &&
          !auth.isAuthenticated &&
          ref.read(loginOtpFlowProvider) == null) {
        return customerLoginRouteForRedirect(
          state.uri.queryParameters['redirect'],
        );
      }
      if (state.uri.path == '/register/otp' &&
          !auth.isAuthenticated &&
          ref.read(registerOtpFlowProvider) == null) {
        return customerRegisterRouteForRedirect(
          state.uri.queryParameters['redirect'],
        );
      }
      return customerRedirectPath(
        path: state.uri.path,
        requestedLocation: state.uri.toString(),
        isAuthenticated: auth.isAuthenticated,
        pinRequired: auth.pinRequired,
        pinSetupRequired: auth.pinSetupRequired,
        isSecurityLocked: auth.isSecurityLocked,
        maintenance: maintenance,
        bootstrap: bootstrapData,
        guestRedirectPath: state.uri.queryParameters['redirect'],
        operationalRedirectPath: auth.startupRedirectPath,
      );
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/login/otp',
        builder: (context, state) => const LoginOtpScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/register/otp',
        builder: (context, state) => const RegisterOtpScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) {
          final query = customerAuthRouteParameters(state.uri);
          return ResetPasswordScreen(
            token: query['token'] ?? '',
            source: query['source'],
          );
        },
      ),
      GoRoute(
        path: '/line/callback',
        builder: (context, state) => LineCallbackScreen(
          provider: 'line',
          query: customerAuthRouteParameters(state.uri),
        ),
      ),
      GoRoute(
        path: '/social/:provider/callback',
        builder: (context, state) => LineCallbackScreen(
          provider: state.pathParameters['provider'] ?? 'line',
          query: customerAuthRouteParameters(state.uri),
        ),
      ),
      GoRoute(
        path: '/line/link-phone',
        builder: (context, state) {
          final query = customerAuthRouteParameters(state.uri);
          return LineLinkPhoneScreen(
            provider: 'line',
            linkToken: query['token'] ?? '',
            displayName: query['name'] ?? '',
            pictureUrl: query['picture_url'] ?? '',
            redirect: query['redirect'] ?? '/',
          );
        },
      ),
      GoRoute(
        path: '/social/:provider/link-phone',
        builder: (context, state) {
          final query = customerAuthRouteParameters(state.uri);
          return LineLinkPhoneScreen(
            provider: state.pathParameters['provider'] ?? 'line',
            linkToken: query['token'] ?? '',
            displayName: query['name'] ?? '',
            pictureUrl: query['picture_url'] ?? '',
            redirect: query['redirect'] ?? '/',
          );
        },
      ),
      GoRoute(path: '/pin', builder: (context, state) => const PinScreen()),
      GoRoute(
        path: '/maintenance',
        builder: (context, state) => const MaintenanceScreen(),
      ),
      GoRoute(
        path: '/account-suspended',
        builder: (context, state) => AccountSuspendedScreen(
          reason:
              state.uri.queryParameters['reason'] ??
              state.uri.queryParameters['suspension_reason'] ??
              state.uri.queryParameters['suspensionReason'] ??
              '',
          suspendedUntil:
              state.uri.queryParameters['suspended_until'] ??
              state.uri.queryParameters['suspendedUntil'] ??
              state.uri.queryParameters['until'],
          permanent: _routeQueryBool(
            state.uri.queryParameters['permanent'] ??
                state.uri.queryParameters['is_permanent'] ??
                state.uri.queryParameters['isPermanent'],
          ),
        ),
      ),
      GoRoute(
        path: '/countdown',
        builder: (context, state) => const CountdownScreen(),
      ),
      GoRoute(path: '/buy', builder: (context, state) => const BuyScreen()),
      GoRoute(
        path: '/search',
        builder: (context, state) =>
            BuySearchScreen(query: state.uri.queryParameters),
      ),
      GoRoute(
        path: '/buy/search',
        builder: (context, state) =>
            BuySearchScreen(query: state.uri.queryParameters),
      ),
      GoRoute(
        path: '/buy/more',
        builder: (context, state) =>
            BuyMoreScreen(query: state.uri.queryParameters),
      ),
      GoRoute(path: '/cart', builder: (context, state) => const CartScreen()),
      GoRoute(
        path: '/checkout',
        builder: (context, state) => const CheckoutScreen(),
      ),
      GoRoute(
        path: '/checkout/pending',
        builder: (context, state) => CheckoutPendingPaymentScreen(
          orderId:
              state.uri.queryParameters['order_id'] ??
              state.uri.queryParameters['id'] ??
              '',
        ),
      ),
      GoRoute(
        path: '/success',
        builder: (context, state) => SuccessScreen(
          orderId:
              state.uri.queryParameters['order_id'] ??
              state.uri.queryParameters['id'],
        ),
      ),
      GoRoute(
        path: '/security-lock',
        builder: (context, state) => const SecurityLockScreen(),
      ),
      GoRoute(
        path: '/tickets',
        builder: (context, state) => const TicketsScreen(),
      ),
      GoRoute(
        path: '/tickets/search',
        builder: (context, state) =>
            TicketsSearchScreen(query: state.uri.queryParameters),
      ),
      GoRoute(
        path: '/tickets/history',
        builder: (context, state) => const TicketHistoryScreen(),
      ),
      GoRoute(
        path: '/tickets/view',
        builder: (context, state) => TicketViewScreen(
          ticketId:
              state.uri.queryParameters['id'] ??
              state.uri.queryParameters['ticket_id'] ??
              '',
          ticketNumber: state.uri.queryParameters['number'] ?? '',
          orderId: state.uri.queryParameters['order_id'] ?? '',
          gameId: state.uri.queryParameters['game_id'] ?? '',
          fromHistory: state.uri.queryParameters['from'] == 'history',
        ),
      ),
      GoRoute(
        path: '/tickets/claim/:ticketId',
        builder: (context, state) => TicketClaimScreen(
          ticketId: state.pathParameters['ticketId'] ?? '',
          fromHistory: state.uri.queryParameters['from'] == 'history',
        ),
      ),
      GoRoute(
        path: '/my-wallet',
        builder: (context, state) => const WalletScreen(),
      ),
      GoRoute(
        path: '/topup',
        builder: (context, state) => TopupScreen(
          backPath: safeTopupBackPath(state.uri.queryParameters['back']),
        ),
      ),
      GoRoute(
        path: '/topup/history',
        builder: (context, state) => const TopupHistoryScreen(),
      ),
      GoRoute(
        path: '/topup/:topupId',
        builder: (context, state) => TopupScreen(
          detailTopupId: state.pathParameters['topupId'] ?? '',
          backPath: safeTopupDetailBackPath(state.uri.queryParameters['back']),
        ),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/profile/language',
        builder: (context, state) => const LanguageScreen(),
      ),
      GoRoute(
        path: '/profile/biometrics',
        builder: (context, state) => const BiometricDevicesScreen(),
      ),
      GoRoute(
        path: '/profile/passkeys',
        builder: (context, state) => const PasskeysScreen(),
      ),
      GoRoute(
        path: '/profile/social-accounts',
        builder: (context, state) => const SocialAccountsScreen(),
      ),
      GoRoute(
        path: '/profile/account-deletion',
        builder: (context, state) => const AccountDeletionScreen(),
      ),
      GoRoute(
        path: '/profile/reward-bank',
        builder: (context, state) =>
            RewardBankScreen(redirect: state.uri.queryParameters['redirect']),
      ),
      GoRoute(
        path: '/profile/auto-reward',
        builder: (context, state) => const AutoRewardScreen(),
      ),
      GoRoute(
        path: '/profile/line-notifications',
        builder: (context, state) => const LineNotificationsScreen(),
      ),
      GoRoute(
        path: '/purchase-history',
        builder: (context, state) => const PurchaseHistoryScreen(),
      ),
      GoRoute(
        path: '/purchase-history/:orderId',
        builder: (context, state) => PurchaseHistoryDetailScreen(
          orderId: state.pathParameters['orderId'] ?? '',
        ),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const CustomerNotificationsScreen(),
      ),
      GoRoute(
        path: '/support',
        builder: (context, state) => const SupportHomeScreen(),
      ),
      GoRoute(
        path: '/support/new',
        builder: (context, state) => SupportNewTicketScreen(
          referencedTicketId: state.uri.queryParameters['reference'],
        ),
      ),
      GoRoute(
        path: '/support/tickets',
        builder: (context, state) => const SupportTicketHistoryScreen(),
      ),
      GoRoute(
        path: '/support/tickets/:ticketId',
        builder: (context, state) => SupportTicketChatScreen(
          ticketId: state.pathParameters['ticketId'] ?? '',
        ),
      ),
      GoRoute(
        path: '/reward-claims',
        builder: (context, state) => const RewardClaimsScreen(),
      ),
      GoRoute(
        path: '/reward-claims/:claimId',
        builder: (context, state) => RewardClaimDetailScreen(
          claimId: state.pathParameters['claimId'] ?? '',
        ),
      ),
      GoRoute(
        path: '/activity-claims',
        builder: (context, state) => const ActivityClaimsScreen(),
      ),
      GoRoute(
        path: '/activity-claims/:claimId',
        builder: (context, state) => ActivityClaimDetailScreen(
          claimId: state.pathParameters['claimId'] ?? '',
        ),
      ),
      GoRoute(
        path: '/result',
        builder: (context, state) => ResultScreen(routePath: state.uri.path),
      ),
      GoRoute(
        path: '/results',
        builder: (context, state) => ResultScreen(routePath: state.uri.path),
      ),
      GoRoute(
        path: '/result/full',
        builder: (context, state) => ResultDetailScreen(
          gameId:
              state.uri.queryParameters['game_id'] ??
              state.uri.queryParameters['id'],
          backPath: resultDetailBackPathFor(state.uri.path),
        ),
      ),
      GoRoute(
        path: '/results/full',
        builder: (context, state) => ResultDetailScreen(
          gameId:
              state.uri.queryParameters['game_id'] ??
              state.uri.queryParameters['id'],
          backPath: resultDetailBackPathFor(state.uri.path),
        ),
      ),
      GoRoute(
        path: '/waiting-result',
        builder: (context, state) => WaitingResultScreen(
          showSaleClosedNotice: state.uri.queryParameters['sale_closed'] == '1',
          routePath: state.uri.path,
        ),
      ),
      GoRoute(
        path: '/wait-result',
        builder: (context, state) => WaitingResultScreen(
          showSaleClosedNotice: state.uri.queryParameters['sale_closed'] == '1',
          routePath: state.uri.path,
        ),
      ),
      GoRoute(
        path: '/activities',
        builder: (context, state) => const ActivitiesScreen(),
      ),
      GoRoute(
        path: '/activities/history',
        builder: (context, state) => const ActivitiesHistoryScreen(),
      ),
      GoRoute(
        path: '/activities/:slug',
        builder: (context, state) => ActivityDetailScreen(
          slug: state.pathParameters['slug'] ?? '',
          backPath: activityDetailBackPath(
            from: state.uri.queryParameters['from'] ?? '',
            gameId: state.uri.queryParameters['game_id'] ?? '',
          ),
        ),
      ),
      GoRoute(
        path: '/affiliate',
        builder: (context, state) =>
            const AffiliateScreen(tab: AffiliateTab.overview),
      ),
      GoRoute(
        path: '/affiliate/referral',
        builder: (context, state) =>
            const AffiliateScreen(tab: AffiliateTab.referral),
      ),
      GoRoute(
        path: '/affiliate/rankings',
        builder: (context, state) =>
            const AffiliateScreen(tab: AffiliateTab.campaigns),
      ),
      GoRoute(
        path: '/affiliate/campaigns',
        builder: (context, state) =>
            const AffiliateScreen(tab: AffiliateTab.campaigns),
      ),
      GoRoute(
        path: '/affiliate/withdraw',
        builder: (context, state) => AffiliateScreen(
          tab: AffiliateTab.withdraw,
          showPayoutHistory: state.uri.queryParameters['history'] == '1',
          showPayoutSuccess: state.uri.queryParameters['created'] == '1',
        ),
      ),
      GoRoute(
        path: '/affiliate/commissions',
        builder: (context, state) =>
            const AffiliateScreen(tab: AffiliateTab.commissions),
      ),
      GoRoute(
        path: '/affiliate/payouts',
        builder: (context, state) => AffiliateScreen(
          tab: AffiliateTab.withdraw,
          showPayoutHistory: true,
          showPayoutSuccess: state.uri.queryParameters['created'] == '1',
        ),
      ),
      GoRoute(path: '/news', builder: (context, state) => const NewsScreen()),
      GoRoute(
        path: '/stores',
        builder: (context, state) => const StoresScreen(),
      ),
      GoRoute(
        path: '/stores/lotteries',
        builder: (context, state) => StoreLotteriesScreen(
          storeId: state.uri.queryParameters['store_id'] ?? '',
          storeName: state.uri.queryParameters['store_name'] ?? '',
          gameId: state.uri.queryParameters['game_id'] ?? '',
        ),
      ),
      GoRoute(
        path: '/news/:slug',
        builder: (context, state) =>
            NewsDetailScreen(slug: state.pathParameters['slug'] ?? ''),
      ),
      GoRoute(path: '/terms', builder: (context, state) => const TermsScreen()),
      GoRoute(
        path: '/privacy',
        builder: (context, state) => const PrivacyPolicyScreen(),
      ),
      GoRoute(
        path: '/term-reward',
        builder: (context, state) => const TermRewardScreen(),
      ),
      GoRoute(
        path: '/lottery-knowledge',
        builder: (context, state) => const LotteryKnowledgeScreen(),
      ),
    ],
  );
  customerBackNavigationHistory.attach(router);
  return router;
});

class _RouterRefreshNotifier extends ChangeNotifier {
  void refresh() => notifyListeners();
}

bool _isPublicPath(String path) {
  return isPublicCustomerPath(path);
}

String? customerRedirectPath({
  required String path,
  String? requestedLocation,
  required bool isAuthenticated,
  required bool pinRequired,
  bool pinSetupRequired = false,
  required bool isSecurityLocked,
  bool maintenanceActive = false,
  MaintenanceConfig? maintenance,
  MobileBootstrap? bootstrap,
  String? guestRedirectPath,
  String? operationalRedirectPath,
}) {
  final effectiveMaintenanceActive = maintenance?.active ?? maintenanceActive;
  final routeBlockedByMaintenance =
      maintenance?.blocksRoute(path) ??
      (maintenanceActive && path != '/maintenance');
  if (routeBlockedByMaintenance) {
    return '/maintenance';
  }
  if (path == '/maintenance' && !effectiveMaintenanceActive) {
    return '/';
  }
  final operationalRedirect = operationalRedirectPath?.trim() ?? '';
  if (operationalRedirect.isNotEmpty &&
      (requestedLocation ?? path) != operationalRedirect) {
    return operationalRedirect;
  }
  final disabledFeatureRedirect = mobileCustomerDisabledRouteRedirect(
    bootstrap,
    path,
  );
  if (disabledFeatureRedirect != null) {
    return disabledFeatureRedirect;
  }
  if (isSecurityLocked && path != '/security-lock') {
    return '/security-lock';
  }
  if (!isAuthenticated && !_isPublicPath(path)) {
    return customerLoginRouteForRedirect(requestedLocation ?? path);
  }
  if (isAuthenticated && _isGuestOnlyPath(path)) {
    return customerPostAuthRouteForRedirect(
      redirect: guestRedirectPath,
      pinRequired: pinRequired,
      pinSetupRequired: pinSetupRequired,
    );
  }
  if (isAuthenticated &&
      (pinRequired || pinSetupRequired) &&
      !_canBypassPin(path)) {
    final target = requestedLocation ?? path;
    final redirect = customerPostAuthRouteForRedirect(
      redirect: target,
      pinRequired: pinRequired,
      pinSetupRequired: pinSetupRequired,
    );
    if (redirect != safeCustomerRedirect(target)) return redirect;
  }
  return null;
}

bool _canBypassPin(String path) {
  return path == '/pin' ||
      path == '/security-lock' ||
      path == '/maintenance' ||
      path == '/account-suspended';
}

bool _routeQueryBool(String? value) {
  return const {
    '1',
    'true',
    'yes',
    'on',
    'permanent',
    'permanently',
  }.contains(value?.trim().toLowerCase());
}

bool _isGuestOnlyPath(String path) {
  return path == '/login' ||
      path == '/login/otp' ||
      path == '/register' ||
      path == '/register/otp' ||
      path == '/forgot-password' ||
      path == '/reset-password';
}
