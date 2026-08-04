import 'package:customer_flutter/core/auth/auth_token_store.dart';
import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/i18n/app_locale.dart';
import 'package:customer_flutter/core/i18n/customer_localizations.dart';
import 'package:customer_flutter/core/network/api_client.dart';
import 'package:customer_flutter/core/tenant/mobile_bootstrap_controller.dart';
import 'package:customer_flutter/features/affiliate/data/affiliate_models.dart';
import 'package:customer_flutter/features/affiliate/data/affiliate_repository.dart';
import 'package:customer_flutter/features/affiliate/presentation/affiliate_referral_share_service.dart';
import 'package:customer_flutter/features/affiliate/presentation/affiliate_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets(
    'every affiliate page uses close and navbar replaces route history',
    (tester) async {
      final router = await _pumpAffiliate(
        tester,
        repository: _AffiliateRepository(),
      );

      expect(find.text('Home'), findsOneWidget);
      expect(find.byKey(const ValueKey('affiliate-close')), findsOneWidget);
      expect(find.byTooltip('Back'), findsNothing);

      await tester.tap(find.text('Ranking'));
      await tester.pumpAndSettle();
      expect(find.text('Affiliate rankings'), findsOneWidget);

      await tester.tap(find.text('Referral'));
      await tester.pumpAndSettle();
      expect(find.text('Referral link'), findsWidgets);
      expect(find.byTooltip('Back'), findsNothing);
      expect(find.byKey(const ValueKey('affiliate-close')), findsOneWidget);

      await tester.tap(find.text('Commissions'));
      await tester.pumpAndSettle();
      expect(find.text('Latest commissions'), findsWidgets);
      expect(find.byTooltip('Back'), findsNothing);
      expect(find.byKey(const ValueKey('affiliate-close')), findsOneWidget);

      await tester.tap(find.text('Withdraw'));
      await tester.pumpAndSettle();
      expect(find.text('Request withdrawal'), findsWidgets);
      expect(find.byTooltip('Back'), findsNothing);
      expect(find.byKey(const ValueKey('affiliate-close')), findsOneWidget);

      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      expect(router.routerDelegate.currentConfiguration.uri.path, '/affiliate');

      await tester.tap(find.byKey(const ValueKey('affiliate-close')));
      await tester.pumpAndSettle();
      expect(router.routerDelegate.currentConfiguration.uri.path, '/profile');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('direct affiliate child page closes to profile', (tester) async {
    final router = await _pumpAffiliate(
      tester,
      initialLocation: '/affiliate/referral',
      repository: _AffiliateRepository(),
    );

    expect(find.byTooltip('Back'), findsNothing);
    expect(find.byKey(const ValueKey('affiliate-close')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('affiliate-close')));
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.uri.path, '/profile');
    expect(tester.takeException(), isNull);
  });

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
      tester.view.viewPadding = const FakeViewPadding(bottom: 34);
      addTearDown(tester.view.resetViewPadding);
      final shareService = _RecordingAffiliateReferralShareService();
      await _pumpAffiliate(
        tester,
        shareService: shareService,
        repository: _AffiliateRepository(
          overviewValue: AffiliateOverview.fromJson(const {
            'is_affiliate': true,
            'affiliate': {
              'referral_code': 'AFF123',
              'referral_url': 'https://partner.example.test/?ref=AFF123',
            },
            'tier': {
              'code': 'bronze',
              'name': 'Bronze',
              'rank': 1,
              'commission_per_ticket': {'amount': 100, 'currency': 'THB'},
              'minimum_payout': {'amount': 30000, 'currency': 'THB'},
            },
            'store_name': {
              'status': 'approved',
              'approved_name': 'Approved Store',
              'can_request_change': false,
            },
            'campaigns': [
              {
                'id': 'atc_1',
                'name': 'July tier campaign',
                'campaign_type': 'fixed_threshold',
                'status': 'active',
                'starts_at': '2026-07-01T00:00:00+07:00',
                'ends_at': '2026-07-31T23:59:59+07:00',
                'can_reduce_tier': true,
                'rules': [
                  {
                    'minimum_ticket_count': 0,
                    'target_tier': {'code': 'bronze', 'name': 'Bronze'},
                  },
                  {
                    'minimum_ticket_count': 200,
                    'target_tier': {'code': 'silver', 'name': 'Silver'},
                  },
                  {
                    'minimum_ticket_count': 300,
                    'target_tier': {'code': 'gold', 'name': 'Gold'},
                  },
                ],
                'my_progress': {
                  'ticket_count': 205,
                  'rank': 4,
                  'projected_tier': {'code': 'silver', 'name': 'Silver'},
                },
                'leaderboard': [
                  {
                    'affiliate_code': 'AFF999',
                    'affiliate_name': 'Lucky Agent',
                    'ticket_count': 330,
                    'rank': 1,
                    'is_current_affiliate': false,
                  },
                  {
                    'affiliate_code': 'AFF222',
                    'affiliate_name': 'Silver Star',
                    'ticket_count': 270,
                    'rank': 2,
                    'is_current_affiliate': false,
                  },
                  {
                    'affiliate_code': 'AFF333',
                    'affiliate_name': 'Happy Seller',
                    'ticket_count': 220,
                    'rank': 3,
                    'is_current_affiliate': false,
                  },
                  {
                    'affiliate_code': 'AFF123',
                    'affiliate_name': 'Approved Store',
                    'ticket_count': 205,
                    'rank': 4,
                    'is_current_affiliate': true,
                  },
                ],
              },
            ],
          }),
        ),
      );

      expect(
        find.byKey(const ValueKey('affiliate-navigation-bar')),
        findsOneWidget,
      );
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Ranking'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('affiliate-member-card')),
        findsOneWidget,
      );
      final memberCard = tester.widget<Container>(
        find.byKey(const ValueKey('affiliate-member-card')),
      );
      final memberCardGradient =
          (memberCard.decoration! as BoxDecoration).gradient! as LinearGradient;
      expect(memberCardGradient.colors, const [
        Color(0xFFA85D33),
        Color(0xFF60301F),
      ]);
      expect(
        find.byKey(const ValueKey('affiliate-tier-badge-bronze')),
        findsOneWidget,
      );
      expect(find.text('AFFILIATE MEMBER'), findsOneWidget);
      expect(find.text('Approved Store'), findsOneWidget);
      expect(find.text('Bronze member'), findsOneWidget);
      expect(find.text('Commission per ticket'), findsOneWidget);
      expect(find.text('1.00 THB'), findsOneWidget);
      expect(find.text('July tier campaign'), findsNothing);
      expect(find.text('95 tickets to Gold'), findsNothing);
      expect(find.text('205 tickets sold'), findsNothing);
      expect(
        find.byKey(const ValueKey('affiliate-campaign-progress-atc_1')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('affiliate-referral-qr')), findsNothing);
      expect(find.text('Referral link'), findsNothing);
      expect(find.text('Payout account'), findsNothing);
      expect(find.byKey(const Key('customer_bottom_nav')), findsNothing);
      expect(find.text('My Tickets'), findsNothing);
      expect(find.text('More'), findsNothing);
      final navigationRect = tester.getRect(
        find.byKey(const ValueKey('affiliate-navigation-bar')),
      );
      expect(navigationRect.height, 82);
      expect(navigationRect.bottom, 1400);
      final navigationLabels = [
        'Home',
        'Ranking',
        'Referral',
        'Commissions',
        'Withdraw',
      ];
      for (var index = 1; index < navigationLabels.length; index++) {
        expect(
          tester.getCenter(find.text(navigationLabels[index - 1])).dx,
          lessThan(tester.getCenter(find.text(navigationLabels[index])).dx),
        );
      }
      final referralCircleRect = tester.getRect(
        find.byKey(const ValueKey('affiliate-referral-navigation-circle')),
      );
      expect(
        referralCircleRect.center.dx,
        closeTo(navigationRect.center.dx, 1),
      );
      expect(referralCircleRect.top, lessThan(navigationRect.top));
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Ranking'));
      await tester.pumpAndSettle();

      expect(find.text('Affiliate rankings'), findsOneWidget);
      expect(find.text('Fixed sales target'), findsOneWidget);
      expect(find.text('Active tier campaign'), findsOneWidget);
      expect(find.text('Top 3 affiliates'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('affiliate-ranking-podium-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('affiliate-ranking-podium-2')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('affiliate-ranking-podium-3')),
        findsOneWidget,
      );
      expect(find.text('Lucky Agent'), findsWidgets);
      expect(find.text('Silver Star'), findsWidgets);
      expect(find.text('Happy Seller'), findsWidgets);
      expect(find.text('Gold rankings'), findsOneWidget);
      expect(find.text('Silver rankings'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('affiliate-campaign-leaderboard-table')),
        findsWidgets,
      );
      expect(find.text('Approved Store (You)'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Referral'));
      await tester.pumpAndSettle();

      expect(find.text('Referral link'), findsWidgets);
      expect(find.text('Referral link'), findsWidgets);
      expect(
        find.byKey(const ValueKey('affiliate-referral-qr')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('affiliate-referral-share-action')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('affiliate-referral-share-action')),
      );
      await tester.pump();
      expect(shareService.calls, hasLength(1));
      expect(shareService.calls.single.subject, 'Referral link');
      expect(
        shareService.calls.single.text,
        contains('https://partner.example.test/?ref=AFF123'),
      );
      expect(shareService.calls.single.sharePositionOrigin, isNotNull);
      expect(find.byKey(const ValueKey('affiliate-member-card')), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Commissions'));
      await tester.pumpAndSettle();

      expect(find.text('Latest commissions'), findsWidgets);
      expect(find.byKey(const ValueKey('affiliate-member-card')), findsNothing);
      expect(find.text('Referral link'), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Withdraw'));
      await tester.pumpAndSettle();

      expect(find.text('Request withdrawal'), findsWidgets);
      expect(find.text('Payout account'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('affiliate-withdraw-segmented-control')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('affiliate-member-card')), findsNothing);
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

      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();

      expect(find.text('Withdrawal history'), findsWidgets);
      expect(
        find.byKey(const ValueKey('affiliate-withdraw-history-content')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('affiliate-member-card')), findsNothing);
      expect(find.text('Referral link'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('ranking campaign stays readable on a narrow viewport', (
    tester,
  ) async {
    await _pumpAffiliate(
      tester,
      viewport: const Size(320, 1000),
      repository: _AffiliateRepository(
        overviewValue: AffiliateOverview.fromJson(const {
          'is_affiliate': true,
          'affiliate': {'referral_code': 'AFF321'},
          'tier': {
            'code': 'gold',
            'name': 'Gold',
            'rank': 3,
            'commission_per_ticket': {'amount': 200, 'currency': 'THB'},
            'minimum_payout': {'amount': 20000, 'currency': 'THB'},
          },
          'store_name': {'status': 'approved', 'approved_name': 'Narrow Store'},
          'campaigns': [
            {
              'id': 'atc_rank',
              'name': 'Diamond challenge',
              'campaign_type': 'ranking',
              'status': 'active',
              'rules': [
                {
                  'rank_from': 1,
                  'rank_to': 10,
                  'target_tier': {'code': 'diamond', 'name': 'Diamond'},
                },
              ],
              'my_progress': {
                'ticket_count': 88,
                'rank': 7,
                'projected_tier': {'code': 'diamond', 'name': 'Diamond'},
              },
              'leaderboard': [
                {
                  'affiliate_code': 'AFF001',
                  'affiliate_name': 'First Store',
                  'ticket_count': 150,
                  'rank': 1,
                  'is_current_affiliate': false,
                },
                {
                  'affiliate_code': 'AFF002',
                  'affiliate_name': 'Second Store',
                  'ticket_count': 120,
                  'rank': 2,
                  'is_current_affiliate': false,
                },
                {
                  'affiliate_code': 'AFF003',
                  'affiliate_name': 'Third Store',
                  'ticket_count': 100,
                  'rank': 3,
                  'is_current_affiliate': false,
                },
                {
                  'affiliate_code': 'AFF321',
                  'affiliate_name': 'Narrow Store',
                  'ticket_count': 88,
                  'rank': 7,
                  'is_current_affiliate': true,
                },
              ],
            },
          ],
        }),
      ),
    );

    expect(find.text('Leaderboard'), findsNothing);
    expect(find.text('Narrow Store (You)'), findsNothing);

    await tester.tap(find.text('Ranking'));
    await tester.pumpAndSettle();

    expect(find.text('Active tier campaign'), findsOneWidget);
    expect(find.text('#7'), findsOneWidget);
    expect(find.text('Top 3 affiliates'), findsOneWidget);
    expect(find.text('Diamond rankings'), findsOneWidget);
    expect(find.text('Narrow Store (You)'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('affiliate-campaign-leaderboard-table')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('affiliate-campaign-progress-atc_rank')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('ranking falls back to the latest completed campaign', (
    tester,
  ) async {
    await _pumpAffiliate(
      tester,
      repository: _AffiliateRepository(
        overviewValue: AffiliateOverview.fromJson(const {
          'is_affiliate': true,
          'affiliate': {'referral_code': 'AFF777'},
          'tier': {'code': 'silver', 'name': 'Silver', 'rank': 2},
          'campaigns': [
            {
              'id': 'atc_old',
              'name': 'Older campaign result',
              'campaign_type': 'ranking',
              'status': 'completed',
              'starts_at': '2026-05-01T00:00:00+07:00',
              'ends_at': '2026-05-31T23:59:59+07:00',
              'leaderboard': [],
            },
            {
              'id': 'atc_latest',
              'name': 'June winner campaign',
              'campaign_type': 'ranking',
              'status': 'completed',
              'starts_at': '2026-06-01T00:00:00+07:00',
              'ends_at': '2026-06-30T23:59:59+07:00',
              'rules': [
                {
                  'rank_from': 1,
                  'rank_to': 1,
                  'target_tier': {
                    'code': 'diamond',
                    'name': 'Diamond',
                    'rank': 5,
                  },
                },
              ],
              'leaderboard': [
                {
                  'affiliate_code': 'AFF001',
                  'affiliate_name': 'Latest Winner',
                  'ticket_count': 510,
                  'rank': 1,
                  'is_current_affiliate': false,
                },
              ],
            },
          ],
        }),
      ),
    );

    await tester.tap(find.text('Ranking'));
    await tester.pumpAndSettle();

    expect(find.text('Latest campaign result'), findsOneWidget);
    expect(find.text('June winner campaign'), findsOneWidget);
    expect(find.text('Older campaign result'), findsNothing);
    expect(find.text('Latest Winner'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

Future<GoRouter> _pumpAffiliate(
  WidgetTester tester, {
  required AffiliateRepository repository,
  AffiliateReferralShareService? shareService,
  Size viewport = const Size(900, 1400),
  String initialLocation = '/affiliate',
}) async {
  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/profile',
        builder: (_, __) =>
            const Scaffold(body: Center(child: Text('Profile route'))),
      ),
      GoRoute(
        path: '/affiliate',
        builder: (_, __) => const AffiliateScreen(tab: AffiliateTab.overview),
      ),
      GoRoute(
        path: '/affiliate/referral',
        builder: (_, __) => const AffiliateScreen(tab: AffiliateTab.referral),
      ),
      GoRoute(
        path: '/affiliate/rankings',
        builder: (_, __) => const AffiliateScreen(tab: AffiliateTab.campaigns),
      ),
      GoRoute(
        path: '/affiliate/campaigns',
        builder: (_, __) => const AffiliateScreen(tab: AffiliateTab.campaigns),
      ),
      GoRoute(
        path: '/affiliate/withdraw',
        builder: (_, state) => AffiliateScreen(
          tab: AffiliateTab.withdraw,
          showPayoutHistory: state.uri.queryParameters['history'] == '1',
          showPayoutSuccess: state.uri.queryParameters['created'] == '1',
        ),
      ),
      GoRoute(
        path: '/affiliate/commissions',
        builder: (_, __) =>
            const AffiliateScreen(tab: AffiliateTab.commissions),
      ),
      GoRoute(
        path: '/affiliate/payouts',
        builder: (_, state) => AffiliateScreen(
          tab: AffiliateTab.withdraw,
          showPayoutHistory: true,
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
        if (shareService != null)
          affiliateReferralShareServiceProvider.overrideWithValue(shareService),
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

class _RecordingAffiliateReferralShareService
    implements AffiliateReferralShareService {
  final calls = <_AffiliateShareCall>[];

  @override
  Future<void> share({
    required String text,
    required String subject,
    Rect? sharePositionOrigin,
  }) async {
    calls.add(
      _AffiliateShareCall(
        text: text,
        subject: subject,
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }
}

class _AffiliateShareCall {
  const _AffiliateShareCall({
    required this.text,
    required this.subject,
    required this.sharePositionOrigin,
  });

  final String text;
  final String subject;
  final Rect? sharePositionOrigin;
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
