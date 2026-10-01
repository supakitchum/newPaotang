// Isolated visual QA entry point. All customer and purchase data are fixtures.
import 'package:customer_flutter/core/auth/auth_controller.dart';
import 'package:customer_flutter/core/auth/auth_repository.dart';
import 'package:customer_flutter/core/auth/auth_token_store.dart';
import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/i18n/app_locale.dart';
import 'package:customer_flutter/core/i18n/customer_localizations.dart';
import 'package:customer_flutter/core/network/api_client.dart';
import 'package:customer_flutter/core/security/biometric_auth_service.dart';
import 'package:customer_flutter/core/tenant/mobile_bootstrap_controller.dart';
import 'package:customer_flutter/core/theme/app_theme.dart';
import 'package:customer_flutter/features/auth/presentation/line_auth_screens.dart';
import 'package:customer_flutter/features/affiliate/data/affiliate_referral_repository.dart';
import 'package:customer_flutter/features/monitoring/data/public_visit_id_store.dart';
import 'package:customer_flutter/features/lottery/data/lottery_models.dart';
import 'package:customer_flutter/features/lottery/data/lottery_repository.dart';
import 'package:customer_flutter/features/lottery/presentation/lottery_screens.dart';
import 'package:customer_flutter/features/purchase_history/data/purchase_history_models.dart';
import 'package:customer_flutter/features/purchase_history/data/purchase_history_repository.dart';
import 'package:customer_flutter/features/results/data/result_models.dart';
import 'package:customer_flutter/features/results/data/result_repository.dart';
import 'package:customer_flutter/features/system/presentation/system_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

const _config = AppConfig(
  apiBaseUrl: 'http://127.0.0.1:18081/fixture-api',
  defaultLocale: 'th-TH',
);

void main() {
  final tokens = AuthTokenStore(storageScope: 'customer-ui-fixture');
  final api = ApiClient(_config, tokens, localeTag: 'th-TH');
  final authRepository = _FixtureAuthRepository(api, tokens);
  final auth = AuthController(
    authRepository: authRepository,
    tokenStore: tokens,
    biometricAuth: BiometricAuthService(api),
  )..isAuthenticated = true;
  final order = PurchaseHistoryOrder.fromJson({
    'id': 'preview_order',
    'reference': 'SB-20261001-0001',
    'payment_method': 'wallet',
    'total': {'amount': 24000, 'currency': 'THB'},
    'ticket_count': 3,
    'game': {
      'name': 'งวดวันที่ 1 ต.ค. 2569',
      'draw_at': '2026-10-01T16:00:00+07:00',
    },
    'wallet': {'name': 'Primary wallet'},
    'store': {'name': 'Siamblend'},
    'paid_at': '2026-10-01T09:00:00+07:00',
  });
  final page = Uri.base.queryParameters['page'] ?? 'success';
  final router = GoRouter(
    initialLocation: '/$page',
    routes: [
      GoRoute(
        path: '/success',
        builder: (_, __) => const SuccessScreen(orderId: 'preview_order'),
      ),
      GoRoute(path: '/buy', builder: (_, __) => const BuyScreen()),
      GoRoute(
        path: '/buy/search',
        builder: (_, __) => const BuySearchScreen(query: {}),
      ),
      GoRoute(
        path: '/social',
        builder: (_, __) => const LineLinkPhoneScreen(
          provider: 'google',
          linkToken: 'preview-link',
          displayName: 'Siamblend Member',
          pictureUrl: '',
          redirect: '/tickets',
        ),
      ),
      GoRoute(
        path: '/tickets',
        builder: (_, __) =>
            const Scaffold(body: Center(child: Text('สลากฯ ของฉัน'))),
      ),
    ],
  );
  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(_config),
        apiClientProvider.overrideWithValue(api),
        authTokenStoreProvider.overrideWithValue(tokens),
        authRepositoryProvider.overrideWithValue(authRepository),
        authControllerProvider.overrideWith((_) => auth),
        affiliateReferralServiceProvider.overrideWithValue(
          _FixtureReferralService(api),
        ),
        mobileBootstrapProvider.overrideWith(
          (_) async => MobileBootstrap.fromJson({
            'site': {'display_name': 'Siamblend'},
            'featureFlags': {'customer_support': false},
          }),
        ),
        purchaseHistoryDetailProvider(
          'preview_order',
        ).overrideWith((_) async => order),
        resultRepositoryProvider.overrideWithValue(
          _FixtureResultRepository(api),
        ),
        lotteryRepositoryProvider.overrideWithValue(
          _FixtureLotteryRepository(api),
        ),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        locale: fallbackCustomerLocale,
        supportedLocales: supportedCustomerLocales,
        localizationsDelegates: const [
          CustomerLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.light(),
        routerConfig: router,
        builder: (context, child) {
          final safe = Uri.base.queryParameters['safe'] == '1';
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: safe
                  ? const EdgeInsets.only(top: 47, bottom: 34)
                  : EdgeInsets.zero,
            ),
            child: child!,
          );
        },
      ),
    ),
  );
}

class _FixtureAuthRepository extends AuthRepository {
  _FixtureAuthRepository(ApiClient api, AuthTokenStore tokens)
    : super(api: api, tokenStore: tokens);

  @override
  Future<OtpRequestResult> requestOtp({
    required String phone,
    required String purpose,
  }) async {
    return const OtpRequestResult(
      phoneMasked: '08xxxxx678',
      resendAfterSeconds: 60,
    );
  }

  @override
  Future<OtpVerifyResult> verifyOtp({
    required String phone,
    required String purpose,
    required String otp,
  }) async {
    return const OtpVerifyResult(verificationToken: 'preview-verified');
  }

  @override
  Future<CustomerSession?> socialLinkExistingPhone({
    required String provider,
    required String linkToken,
    required String phone,
    required String otpVerificationToken,
    String? redirect,
  }) async {
    if (Uri.base.queryParameters['existing'] == '1') {
      return const CustomerSession(
        accessToken: 'fixture-session',
        refreshToken: 'fixture-refresh',
        customerId: 'fixture-member',
        pinRequired: false,
        pinSetupRequired: false,
      );
    }
    return null;
  }
}

class _FixtureReferralService extends AffiliateReferralService {
  _FixtureReferralService(ApiClient api)
    : super(
        config: _config,
        repository: AffiliateReferralRepository(api),
        store: AffiliateReferralStore(),
        visitIdStore: PublicVisitIdStore(),
      );

  @override
  Future<void> applyStored({bool registered = false}) async {}
}

class _FixtureResultRepository extends ResultRepository {
  _FixtureResultRepository(super.api);

  @override
  Future<CurrentGame?> currentGame() async => const CurrentGame(
    id: 'preview_game',
    name: 'งวดวันที่ 1 ต.ค. 2569',
    status: 'open',
    drawAt: '2026-10-01T16:00:00+07:00',
  );
}

class _FixtureLotteryRepository extends LotteryRepository {
  _FixtureLotteryRepository(super.api);

  @override
  Future<LotteryStockPage> search({
    required String gameId,
    List<String> digits = const [],
    String number = '',
    String storeId = '',
    String cursor = '',
    String randomSeed = '',
    int limit = 20,
  }) async {
    return LotteryStockPage(
      gameId: gameId,
      items: const [],
      nextCursor: '',
      hasMore: false,
      sellerName: 'Siamblend',
    );
  }

  @override
  Future<LotteryCart> cart() async {
    final now = DateTime.now();
    return LotteryCart(
      reservations: [
        LotteryReservation(
          id: 'preview_reservation',
          gameId: 'preview_game',
          status: 'active',
          expiresAt: now.add(const Duration(minutes: 12)).toIso8601String(),
          expiresInSeconds: 720,
          serverTime: now.toIso8601String(),
          items: const [],
          total: 240,
        ),
      ],
      total: 240,
      itemCount: 3,
      serverTime: now.toIso8601String(),
      warnings: const [],
    );
  }
}
