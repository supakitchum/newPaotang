import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_controller.dart';
import '../core/navigation/customer_redirect.dart';
import '../features/activity_claims/presentation/activity_claim_detail_screen.dart';
import '../features/activity_claims/presentation/activity_claims_screen.dart';
import '../features/activities/presentation/activity_detail_screen.dart';
import '../features/activities/presentation/activities_screen.dart';
import '../features/affiliate/presentation/affiliate_screen.dart';
import '../features/auth/presentation/forgot_password_screen.dart';
import '../features/auth/presentation/line_auth_screens.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/auth/presentation/reset_password_screen.dart';
import '../features/content/presentation/info_pages.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/lottery/presentation/lottery_screens.dart';
import '../features/news/presentation/news_detail_screen.dart';
import '../features/news/presentation/news_screen.dart';
import '../features/pin/presentation/pin_screen.dart';
import '../features/profile/presentation/auto_reward_screen.dart';
import '../features/profile/presentation/account_deletion_screen.dart';
import '../features/profile/presentation/biometric_devices_screen.dart';
import '../features/profile/presentation/line_notifications_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/profile/presentation/reward_bank_screen.dart';
import '../features/purchase_history/presentation/purchase_history_detail_screen.dart';
import '../features/purchase_history/presentation/purchase_history_screen.dart';
import '../features/reward_claims/presentation/reward_claim_detail_screen.dart';
import '../features/reward_claims/presentation/reward_claims_screen.dart';
import '../features/results/presentation/result_detail_screen.dart';
import '../features/results/presentation/result_screen.dart';
import '../features/results/presentation/waiting_result_screen.dart';
import '../features/stores/presentation/store_screens.dart';
import '../features/system/presentation/system_pages.dart';
import '../features/tickets/presentation/tickets_screen.dart';
import '../features/topup/presentation/topup_history_screen.dart';
import '../features/topup/presentation/topup_screen.dart';
import '../features/wallet/presentation/wallet_screen.dart';
import '../shared/widgets/security_lock_screen.dart';
import 'customer_routes.dart';
import '../core/tenant/mobile_bootstrap_controller.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authControllerProvider);
  final bootstrap = ref.watch(mobileBootstrapProvider);
  final maintenanceActive = bootstrap.maybeWhen(
    data: (data) => data.maintenance.active,
    orElse: () => false,
  );

  return GoRouter(
    initialLocation: '/',
    refreshListenable: auth,
    redirect: (context, state) {
      return customerRedirectPath(
        path: state.uri.path,
        requestedLocation: state.uri.toString(),
        isAuthenticated: auth.isAuthenticated,
        pinRequired: auth.pinRequired,
        isSecurityLocked: auth.isSecurityLocked,
        maintenanceActive: maintenanceActive,
        guestRedirectPath: state.uri.queryParameters['redirect'],
      );
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) => ResetPasswordScreen(
          token: state.uri.queryParameters['token'] ?? '',
          source: state.uri.queryParameters['source'],
        ),
      ),
      GoRoute(
        path: '/line/callback',
        builder: (context, state) => LineCallbackScreen(
          provider: 'line',
          query: state.uri.queryParameters,
        ),
      ),
      GoRoute(
        path: '/social/:provider/callback',
        builder: (context, state) => LineCallbackScreen(
          provider: state.pathParameters['provider'] ?? 'line',
          query: state.uri.queryParameters,
        ),
      ),
      GoRoute(
        path: '/line/link-phone',
        builder: (context, state) => LineLinkPhoneScreen(
          provider: 'line',
          linkToken: state.uri.queryParameters['token'] ?? '',
          displayName: state.uri.queryParameters['name'] ?? '',
          pictureUrl: state.uri.queryParameters['picture_url'] ?? '',
          redirect: state.uri.queryParameters['redirect'] ?? '/',
        ),
      ),
      GoRoute(
        path: '/social/:provider/link-phone',
        builder: (context, state) => LineLinkPhoneScreen(
          provider: state.pathParameters['provider'] ?? 'line',
          linkToken: state.uri.queryParameters['token'] ?? '',
          displayName: state.uri.queryParameters['name'] ?? '',
          pictureUrl: state.uri.queryParameters['picture_url'] ?? '',
          redirect: state.uri.queryParameters['redirect'] ?? '/',
        ),
      ),
      GoRoute(path: '/pin', builder: (context, state) => const PinScreen()),
      GoRoute(
        path: '/maintenance',
        builder: (context, state) => const MaintenanceScreen(),
      ),
      GoRoute(
        path: '/account-suspended',
        builder: (context, state) => AccountSuspendedScreen(
          reason: state.uri.queryParameters['reason'] ?? '',
          suspendedUntil: state.uri.queryParameters['suspended_until'],
          permanent: state.uri.queryParameters['permanent'] == '1' ||
              state.uri.queryParameters['is_permanent'] == '1',
        ),
      ),
      GoRoute(
        path: '/countdown',
        builder: (context, state) => const CountdownScreen(),
      ),
      GoRoute(path: '/buy', builder: (context, state) => const BuyScreen()),
      GoRoute(
        path: '/search',
        builder: (context, state) => BuySearchScreen(
          query: state.uri.queryParameters,
        ),
      ),
      GoRoute(
        path: '/buy/search',
        builder: (context, state) => BuySearchScreen(
          query: state.uri.queryParameters,
        ),
      ),
      GoRoute(
        path: '/buy/more',
        builder: (context, state) => BuyMoreScreen(
          query: state.uri.queryParameters,
        ),
      ),
      GoRoute(path: '/cart', builder: (context, state) => const CartScreen()),
      GoRoute(
        path: '/checkout',
        builder: (context, state) => const CheckoutScreen(),
      ),
      GoRoute(
        path: '/checkout/pending',
        builder: (context, state) => CheckoutPendingPaymentScreen(
          orderId: state.uri.queryParameters['order_id'] ??
              state.uri.queryParameters['id'] ??
              '',
        ),
      ),
      GoRoute(
        path: '/success',
        builder: (context, state) => SuccessScreen(
          orderId: state.uri.queryParameters['order_id'] ??
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
        path: '/tickets/history',
        builder: (context, state) => const TicketHistoryScreen(),
      ),
      GoRoute(
        path: '/tickets/view',
        builder: (context, state) => TicketViewScreen(
          ticketId: state.uri.queryParameters['id'] ??
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
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/profile/biometrics',
        builder: (context, state) => const BiometricDevicesScreen(),
      ),
      GoRoute(
        path: '/profile/account-deletion',
        builder: (context, state) => const AccountDeletionScreen(),
      ),
      GoRoute(
        path: '/profile/reward-bank',
        builder: (context, state) => RewardBankScreen(
          redirect: state.uri.queryParameters['redirect'],
        ),
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
        builder: (context, state) => const ResultScreen(),
      ),
      GoRoute(
        path: '/results',
        builder: (context, state) => const ResultScreen(),
      ),
      GoRoute(
        path: '/result/full',
        builder: (context, state) => ResultDetailScreen(
          gameId: state.uri.queryParameters['game_id'] ??
              state.uri.queryParameters['id'],
        ),
      ),
      GoRoute(
        path: '/results/full',
        builder: (context, state) => ResultDetailScreen(
          gameId: state.uri.queryParameters['game_id'] ??
              state.uri.queryParameters['id'],
        ),
      ),
      GoRoute(
        path: '/waiting-result',
        builder: (context, state) => WaitingResultScreen(
          showSaleClosedNotice: state.uri.queryParameters['sale_closed'] == '1',
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
        builder: (context, state) => const AffiliateScreen(),
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
        builder: (context, state) => NewsDetailScreen(
          slug: state.pathParameters['slug'] ?? '',
        ),
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
});

bool _isPublicPath(String path) {
  return isPublicCustomerPath(path);
}

String? customerRedirectPath({
  required String path,
  String? requestedLocation,
  required bool isAuthenticated,
  required bool pinRequired,
  required bool isSecurityLocked,
  bool maintenanceActive = false,
  String? guestRedirectPath,
}) {
  if (maintenanceActive) {
    return path == '/maintenance' ? null : '/maintenance';
  }
  if (path == '/maintenance') {
    return '/';
  }
  if (isSecurityLocked && path != '/security-lock') {
    return '/security-lock';
  }
  if (!isAuthenticated && !_isPublicPath(path)) {
    return customerLoginRouteForRedirect(requestedLocation ?? path);
  }
  if (isAuthenticated && _isGuestOnlyPath(path)) {
    return pinRequired
        ? customerPinRouteForRedirect(guestRedirectPath)
        : safeCustomerRedirect(guestRedirectPath);
  }
  if (isAuthenticated && pinRequired && !_canBypassPin(path)) {
    return customerPinRouteForRedirect(requestedLocation ?? path);
  }
  return null;
}

bool _canBypassPin(String path) {
  return path == '/pin' ||
      path == '/security-lock' ||
      path == '/maintenance' ||
      path == '/account-suspended';
}

bool _isGuestOnlyPath(String path) {
  return path == '/login' ||
      path == '/register' ||
      path == '/forgot-password' ||
      path == '/reset-password';
}
