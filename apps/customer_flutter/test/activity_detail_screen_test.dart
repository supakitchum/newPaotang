import 'package:customer_flutter/core/auth/auth_controller.dart';
import 'package:customer_flutter/core/auth/auth_repository.dart';
import 'package:customer_flutter/core/auth/auth_token_store.dart';
import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/i18n/app_locale.dart';
import 'package:customer_flutter/core/i18n/customer_localizations.dart';
import 'package:customer_flutter/core/network/api_client.dart';
import 'package:customer_flutter/core/security/biometric_auth_service.dart';
import 'package:customer_flutter/core/theme/app_theme.dart';
import 'package:customer_flutter/features/activities/data/activity_models.dart';
import 'package:customer_flutter/features/activities/data/activity_repository.dart';
import 'package:customer_flutter/features/activities/presentation/activity_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('ActivityDetailScreen hides awards before result announcement', (
    tester,
  ) async {
    final repository = _FakeActivityRepository(resultAnnounced: false);

    await _pumpDetail(tester, repository);
    await tester.pumpAndSettle();

    expect(repository.awardsAllCount, 0);
    expect(find.text('กิจกรรมทายเลข 2 ตัว'), findsOneWidget);
    expect(find.text('พร้อมรับเงินรางวัล'), findsNothing);
    expect(find.text('รับเงิน'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ActivityDetailScreen shows claimable awards after announcement',
      (
    tester,
  ) async {
    final repository = _FakeActivityRepository(resultAnnounced: true);

    await _pumpDetail(tester, repository);
    await tester.pumpAndSettle();

    expect(repository.awardsAllCount, 1);
    expect(find.text('ผลกิจกรรม'), findsOneWidget);
    expect(find.text('พร้อมรับเงินรางวัล'), findsOneWidget);
    expect(find.text('รับเงิน'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpDetail(
  WidgetTester tester,
  _FakeActivityRepository repository,
) {
  final router = GoRouter(
    initialLocation: '/activities/lucky-board',
    routes: [
      GoRoute(
        path: '/activities/:slug',
        builder: (context, state) => ActivityDetailScreen(
          slug: state.pathParameters['slug'] ?? '',
        ),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Home')),
        ),
      ),
      GoRoute(
        path: '/tickets',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Tickets')),
        ),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Profile')),
        ),
      ),
    ],
  );

  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(
            apiBaseUrl: 'https://partner.example.test/api/v1',
            defaultLocale: 'th-TH',
          ),
        ),
        authTokenStoreProvider.overrideWithValue(AuthTokenStore()),
        authControllerProvider.overrideWith((_) => _authenticatedController()),
        activityRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp.router(
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
      ),
    ),
  );
}

class _FakeActivityRepository extends ActivityRepository {
  _FakeActivityRepository({required this.resultAnnounced})
      : super(_testApiClient(), (value) => value);

  final bool resultAnnounced;
  int awardsAllCount = 0;

  @override
  Future<ActivityItem> detail(String slug, {bool authenticated = false}) async {
    return _activityFixture(resultAnnounced: resultAnnounced);
  }

  @override
  Future<List<ActivityAwardItem>> awardsAll({
    int limit = ActivityRepository.defaultAwardPageLimit,
    int maxPages = ActivityRepository.maxAwardAutoPages,
    String? status,
  }) async {
    awardsAllCount++;
    return const [
      ActivityAwardItem(
        id: 'award_1',
        activityId: 'act_lucky',
        activityName: 'กิจกรรมทายเลข 2 ตัว',
        type: 'lucky_board',
        predictionType: 'last2',
        amount: 2000,
        status: 'claimable',
        claimId: '',
        calculatedAt: null,
      ),
    ];
  }
}

ActivityItem _activityFixture({required bool resultAnnounced}) {
  return ActivityItem(
    id: 'act_lucky',
    name: 'กิจกรรมทายเลข 2 ตัว',
    slug: 'lucky-board',
    type: 'lucky_board',
    imageUrl: '',
    conditionText: 'ทุก 10 ใบ ได้ 1 สิทธิ์',
    remainingNumbers: 97,
    hasRight: true,
    estimatedCashbackAmount: 0,
    rights: const ActivityRights(
      earnedCount: 2,
      usedCount: 1,
      remainingCount: 1,
      ticketCount: 20,
      availableTicketCount: 10,
      consumedTicketCount: 10,
      qualifyingOrderCount: 0,
      eligibilityRule: 'cumulative_tickets',
      thresholdTickets: 10,
      entryDeadlineAt: null,
      entryClosed: false,
    ),
    entries: const [
      ActivityEntry(
        id: 'entry_1',
        predictionType: 'last2',
        selectedNumber: '24',
        status: 'submitted',
        createdAt: null,
      ),
    ],
    numberBoard: const ActivityNumberBoard(
      predictionType: 'last2',
      digits: 2,
      totalCount: 100,
      reservedCount: 3,
      remainingCount: 97,
      reservedNumbers: {'01', '02', '03'},
    ),
    resultSummary: resultAnnounced
        ? const ActivityResultSummary(
            status: 'announced',
            predictionType: 'last2',
            winningNumber: '24',
            winnerCount: 1,
            awardTotal: 2000,
            customerStatus: 'won',
            customerWinningNumbers: ['24'],
            customerAwardAmount: 2000,
          )
        : null,
  );
}

AuthController _authenticatedController() {
  final tokenStore = AuthTokenStore();
  final api = _testApiClient(tokenStore);
  return AuthController(
    authRepository: AuthRepository(api: api, tokenStore: tokenStore),
    tokenStore: tokenStore,
    biometricAuth: BiometricAuthService(api),
  )
    ..isAuthenticated = true
    ..pinRequired = false;
}

ApiClient _testApiClient([AuthTokenStore? tokenStore]) {
  return ApiClient(
    const AppConfig(
      apiBaseUrl: 'https://partner.example.test/api/v1',
      defaultLocale: 'th-TH',
    ),
    tokenStore ?? AuthTokenStore(),
    localeTag: 'th-TH',
  );
}
