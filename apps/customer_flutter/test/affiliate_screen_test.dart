import 'package:customer_flutter/core/auth/auth_token_store.dart';
import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/i18n/app_locale.dart';
import 'package:customer_flutter/core/i18n/customer_localizations.dart';
import 'package:customer_flutter/core/network/api_client.dart';
import 'package:customer_flutter/core/tenant/mobile_bootstrap_controller.dart';
import 'package:customer_flutter/features/affiliate/data/affiliate_models.dart';
import 'package:customer_flutter/features/affiliate/data/affiliate_repository.dart';
import 'package:customer_flutter/features/affiliate/presentation/affiliate_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('affiliate overview follows backend maintenance redirect', (
    tester,
  ) async {
    await _pumpAffiliate(
      tester,
      repository: _AffiliateRepository(overviewError: _maintenanceError()),
    );

    expect(find.text('Maintenance route'), findsOneWidget);
  });

  testWidgets(
    'affiliate commission load follows backend maintenance redirect',
    (tester) async {
      await _pumpAffiliate(
        tester,
        repository: _AffiliateRepository(
          commissionsError: _maintenanceError(
            path: '/customer/affiliate/commissions',
          ),
        ),
      );

      await tester.tap(find.text('Commissions'));
      await tester.pumpAndSettle();

      expect(find.text('Maintenance route'), findsOneWidget);
    },
  );

  testWidgets(
    'affiliate registration shows API-backed benefits without hero copy',
    (tester) async {
      await _pumpAffiliate(
        tester,
        repository: _AffiliateRepository(
          overviewValue: AffiliateOverview.fromJson(const {
            'is_affiliate': false,
            'payout_policy': {
              'minimum_payout_amount': {'amount': 45000, 'currency': 'THB'},
            },
          }),
        ),
      );

      expect(find.text('Affiliate benefits'), findsOneWidget);
      expect(
        find.text('Withdraw earnings once your balance reaches 450.00 THB.'),
        findsOneWidget,
      );
      expect(find.text('Refer others and earn sales rewards.'), findsNothing);
      expect(find.text('Affiliate'), findsOneWidget);
      expect(find.text('Store name'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'affiliate navigation opens dedicated pages without customer nav',
    (tester) async {
      final router = await _pumpAffiliate(
        tester,
        repository: _AffiliateRepository(
          overviewValue: AffiliateOverview.fromJson(const {
            'is_affiliate': true,
            'affiliate': {
              'referral_code': 'AFF123',
              'referral_url': 'https://partner.example.test/?ref=AFF123',
            },
          }),
        ),
      );

      expect(
        find.byKey(const ValueKey('affiliate-navigation-bar')),
        findsOneWidget,
      );
      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Your store name'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('affiliate-referral-qr')),
        findsOneWidget,
      );
      expect(find.text('Payout account'), findsNothing);
      expect(find.text('Home'), findsNothing);
      expect(find.text('My Tickets'), findsNothing);
      expect(find.text('More'), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Withdraw'));
      await tester.pumpAndSettle();

      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        '/affiliate/withdraw',
      );
      expect(find.text('Request withdrawal'), findsWidgets);
      expect(find.text('Payout account'), findsOneWidget);
      expect(find.text('Your store name'), findsNothing);
      expect(find.text('Referral link'), findsNothing);
      expect(find.byKey(const ValueKey('affiliate-referral-qr')), findsNothing);
      final withdrawException = tester.takeException();
      expect(
        withdrawException,
        isNull,
        reason: withdrawException is FlutterError
            ? withdrawException.toStringDeep()
            : withdrawException?.toString(),
      );

      await tester.tap(find.text('Commissions'));
      await tester.pumpAndSettle();

      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        '/affiliate/commissions',
      );
      expect(find.text('Latest commissions'), findsWidgets);
      expect(find.text('Your store name'), findsNothing);
      expect(find.text('Referral link'), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();

      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        '/affiliate/payouts',
      );
      expect(find.text('Withdrawal history'), findsWidgets);
      expect(find.text('Your store name'), findsNothing);
      expect(find.text('Referral link'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<GoRouter> _pumpAffiliate(
  WidgetTester tester, {
  required AffiliateRepository repository,
}) async {
  tester.view.physicalSize = const Size(900, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final router = GoRouter(
    initialLocation: '/affiliate',
    routes: [
      GoRoute(
        path: '/affiliate',
        builder: (_, __) => const AffiliateScreen(tab: AffiliateTab.overview),
      ),
      GoRoute(
        path: '/affiliate/withdraw',
        builder: (_, __) => const AffiliateScreen(tab: AffiliateTab.withdraw),
      ),
      GoRoute(
        path: '/affiliate/commissions',
        builder: (_, __) =>
            const AffiliateScreen(tab: AffiliateTab.commissions),
      ),
      GoRoute(
        path: '/affiliate/payouts',
        builder: (_, state) => AffiliateScreen(
          tab: AffiliateTab.payouts,
          showPayoutSuccess: state.uri.queryParameters['created'] == '1',
        ),
      ),
      GoRoute(
        path: '/maintenance',
        builder: (_, __) =>
            const Scaffold(body: Center(child: Text('Maintenance route'))),
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
        affiliateRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp.router(
        locale: const Locale('en', 'US'),
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
  return router;
}

class _AffiliateRepository extends AffiliateRepository {
  _AffiliateRepository({
    this.overviewValue,
    this.overviewError,
    this.commissionsError,
  }) : super(_testApiClient());

  final AffiliateOverview? overviewValue;
  final Object? overviewError;
  final Object? commissionsError;

  @override
  Future<AffiliateOverview> overview() async {
    final error = overviewError;
    if (error != null) throw error;
    return overviewValue ??
        AffiliateOverview.fromJson(const {'is_affiliate': true});
  }

  @override
  Future<AffiliatePage<AffiliateCommission>> commissions({
    String cursor = '',
    int limit = 10,
  }) async {
    final error = commissionsError;
    if (error != null) throw error;
    return const AffiliatePage(items: [], nextCursor: '', hasMore: false);
  }

  @override
  Future<AffiliatePage<AffiliatePayout>> payouts({
    String cursor = '',
    int limit = 10,
  }) async {
    return const AffiliatePage(items: [], nextCursor: '', hasMore: false);
  }
}

DioException _maintenanceError({String path = '/customer/affiliate'}) {
  final request = RequestOptions(path: path);
  return DioException(
    requestOptions: request,
    response: Response<Map<String, dynamic>>(
      requestOptions: request,
      statusCode: 503,
      data: const {
        'code': 'maintenance_active',
        'message': 'Store is temporarily unavailable.',
      },
    ),
  );
}

ApiClient _testApiClient() {
  return ApiClient(
    const AppConfig(
      apiBaseUrl: 'https://partner.example.test/api/v1',
      defaultLocale: 'en-US',
    ),
    AuthTokenStore(),
    localeTag: 'en-US',
  );
}
