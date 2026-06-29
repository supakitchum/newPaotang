import 'package:customer_flutter/core/auth/auth_token_store.dart';
import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/i18n/app_locale.dart';
import 'package:customer_flutter/core/i18n/customer_localizations.dart';
import 'package:customer_flutter/core/network/api_client.dart';
import 'package:customer_flutter/core/theme/app_theme.dart';
import 'package:customer_flutter/features/tickets/data/ticket_models.dart';
import 'package:customer_flutter/features/tickets/data/ticket_repository.dart';
import 'package:customer_flutter/features/tickets/presentation/tickets_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('ticket history auto-loads more tickets near the bottom', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 620);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _TicketHistoryRepository();

    await _pumpHistory(tester, repository);
    await tester.pumpAndSettle();

    expect(repository.historyCalls, 1);
    expect(find.text('740000'), findsOneWidget);
    expect(find.text('880000'), findsNothing);

    await tester.drag(find.byType(ListView), const Offset(0, -1800));
    await tester.pumpAndSettle();

    expect(repository.historyCalls, 2);
    expect(repository.cursors, [null, 'cursor_2']);
    expect(find.text('880000'), findsOneWidget);
    expect(find.text('โหลดเพิ่มเติม'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpHistory(
  WidgetTester tester,
  _TicketHistoryRepository repository,
) {
  final router = GoRouter(
    initialLocation: '/tickets/history',
    routes: [
      GoRoute(
        path: '/tickets/history',
        builder: (context, state) => const TicketHistoryScreen(),
      ),
      GoRoute(
        path: '/tickets',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Current tickets')),
        ),
      ),
      GoRoute(
        path: '/tickets/view',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Ticket detail')),
        ),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Home')),
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
        ticketRepositoryProvider.overrideWithValue(repository),
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

class _TicketHistoryRepository extends TicketRepository {
  _TicketHistoryRepository() : super(_testApiClient());

  int historyCalls = 0;
  final cursors = <String?>[];

  @override
  Future<TicketPage> history({
    int limit = 20,
    String? cursor,
    String? gameId,
  }) async {
    historyCalls++;
    cursors.add(cursor);

    if (cursor == 'cursor_2') {
      return TicketPage(
        items: [_ticket('history_2', '880000')],
        nextCursor: null,
        hasMore: false,
        total: 9,
      );
    }

    return TicketPage(
      items: [
        for (var index = 0; index < 8; index++)
          _ticket('history_$index', '74000$index'),
      ],
      nextCursor: 'cursor_2',
      hasMore: true,
      total: 9,
    );
  }
}

CustomerTicket _ticket(String id, String number) {
  return CustomerTicket(
    id: id,
    gameId: 'game_previous',
    gameName: 'งวด 16 พ.ค. 2569',
    drawAt: '2026-05-16T17:00:00+07:00',
    number: number,
    status: 'paid',
    rewardStatus: const TicketRewardStatus(
      status: 'lost',
      claimStatus: '',
      claimable: false,
      prizeType: '',
      prizeNumber: '',
      prizeAmount: 0,
      prizes: [],
      rewardClaimId: null,
      payoutMethod: '',
      adminNote: '',
    ),
    count: 1,
    prizes: const [],
    prizeAmount: 0,
    claimable: false,
    rewardClaimId: '',
    imageUrl: '',
    imageThumbUrl: '',
    previewImageUrl: '',
    imageStatus: '',
    imageError: '',
  );
}

ApiClient _testApiClient() {
  return ApiClient(
    const AppConfig(
      apiBaseUrl: 'https://partner.example.test/api/v1',
      defaultLocale: 'th-TH',
    ),
    AuthTokenStore(),
    localeTag: 'th-TH',
  );
}
