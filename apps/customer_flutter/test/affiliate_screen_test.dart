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

  testWidgets('affiliate commission load follows backend maintenance redirect',
      (
    tester,
  ) async {
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
  });
}

Future<void> _pumpAffiliate(
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
        builder: (_, __) => const AffiliateScreen(),
      ),
      GoRoute(
        path: '/maintenance',
        builder: (_, __) => const Scaffold(
          body: Center(child: Text('Maintenance route')),
        ),
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
}

class _AffiliateRepository extends AffiliateRepository {
  _AffiliateRepository({
    this.overviewError,
    this.commissionsError,
  }) : super(_testApiClient());

  final Object? overviewError;
  final Object? commissionsError;

  @override
  Future<AffiliateOverview> overview() async {
    final error = overviewError;
    if (error != null) throw error;
    return AffiliateOverview.fromJson(const {'is_affiliate': true});
  }

  @override
  Future<AffiliatePage<AffiliateCommission>> commissions({
    String cursor = '',
    int limit = 10,
  }) async {
    final error = commissionsError;
    if (error != null) throw error;
    return const AffiliatePage(
      items: [],
      nextCursor: '',
      hasMore: false,
    );
  }
}

DioException _maintenanceError({
  String path = '/customer/affiliate',
}) {
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
