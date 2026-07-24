import 'package:customer_flutter/core/auth/auth_token_store.dart';
import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/i18n/app_locale.dart';
import 'package:customer_flutter/core/i18n/customer_localizations.dart';
import 'package:customer_flutter/core/network/api_client.dart';
import 'package:customer_flutter/core/tenant/mobile_bootstrap_controller.dart';
import 'package:customer_flutter/features/support/data/support_models.dart';
import 'package:customer_flutter/features/support/data/support_repository.dart';
import 'package:customer_flutter/features/support/presentation/support_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  testWidgets('Help Center shows active ticket, FAQ, and no bottom nav', (
    tester,
  ) async {
    final repository = _SupportScreenRepository(
      bootstrapValue: _bootstrap(activeTicket: _ticket()),
      faqsValue: const [
        SupportFaq(
          id: 'faq_1',
          categoryId: 'cat_order',
          question: 'How do I check my order?',
          answer: 'Open My Tickets to review it.',
        ),
      ],
    );

    await _pumpSupportApp(tester, repository, initialLocation: '/support');

    expect(find.text('Active ticket'), findsOneWidget);
    expect(find.text('Payment was not completed'), findsOneWidget);
    expect(find.text('How do I check my order?'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(BottomNavigationBar), findsNothing);
  });

  testWidgets('new-ticket FAQ failure offers retry without losing category', (
    tester,
  ) async {
    final repository = _SupportScreenRepository(
      bootstrapValue: _bootstrap(),
      faqsValue: const [
        SupportFaq(
          id: 'faq_retry',
          categoryId: 'cat_order',
          question: 'Retry loaded this answer',
          answer: 'The selected category was preserved.',
        ),
      ],
      faqFailuresBeforeSuccess: 1,
    );

    await _pumpSupportApp(tester, repository, initialLocation: '/support/new');
    await tester.tap(find.text('Order issue'));
    await tester.pumpAndSettle();

    expect(find.text('Unable to load data. Please try again.'), findsOneWidget);
    expect(find.text('I still need an agent'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Retry loaded this answer'), findsOneWidget);
    expect(repository.faqCalls, 2);
  });

  testWidgets('closed ticket remains read-only and shows closure summary', (
    tester,
  ) async {
    final closed = _ticket(
      status: 'closed',
      closedAt: DateTime(2026, 7, 23, 11, 30),
      closedByName: 'Agent One',
    );
    final repository = _SupportScreenRepository(
      bootstrapValue: _bootstrap(),
      ticketValue: closed,
      messagesValue: [
        SupportMessage(
          id: 'msg_1',
          sequence: 1,
          senderType: 'customer',
          senderName: 'Customer',
          body: 'Please review my payment.',
          attachments: const [],
          createdAt: DateTime(2026, 7, 23, 10),
          readByCounterpart: true,
        ),
      ],
    );

    await _pumpSupportApp(
      tester,
      repository,
      initialLocation: '/support/tickets/stk_1',
    );

    expect(find.text('Payment was not completed'), findsWidgets);
    expect(find.text('Closed by Agent One'), findsWidgets);
    expect(find.text('Rate the service'), findsOneWidget);
    expect(find.text('Type a message'), findsNothing);
    expect(find.byIcon(Icons.send_rounded), findsNothing);
  });

  testWidgets('agent-side close opens the rating sheet on refresh', (
    tester,
  ) async {
    final repository = _SupportScreenRepository(
      bootstrapValue: _bootstrap(),
      ticketValue: _ticket(),
      ticketAfterFirstFetch: _ticket(
        status: 'closed',
        closedAt: DateTime(2026, 7, 23, 11, 30),
        closedByName: 'Agent One',
      ),
    );

    await _pumpSupportApp(
      tester,
      repository,
      initialLocation: '/support/tickets/stk_1',
    );
    expect(find.text('How was your support experience?'), findsNothing);

    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();

    expect(find.text('How was your support experience?'), findsOneWidget);
  });

  testWidgets('ticket history adapts between desktop and narrow layouts', (
    tester,
  ) async {
    final repository = _SupportScreenRepository(
      bootstrapValue: _bootstrap(),
      ticketsValue: [
        _ticket(),
        _ticket(
          id: 'stk_2',
          publicNo: 'SUP-000002',
          subject: 'A second support request with a longer subject',
        ),
      ],
    );
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.binding.setSurfaceSize(const Size(1100, 800));
    await _pumpSupportApp(
      tester,
      repository,
      initialLocation: '/support/tickets',
    );

    final firstWide = tester.getTopLeft(find.text('SUP-000001')).dx;
    final secondWide = tester.getTopLeft(find.text('SUP-000002')).dx;
    expect(secondWide, greaterThan(firstWide + 100));
    expect(tester.takeException(), isNull);

    await tester.binding.setSurfaceSize(const Size(320, 700));
    await tester.pumpAndSettle();

    final firstNarrow = tester.getTopLeft(find.text('SUP-000001')).dx;
    final secondNarrow = tester.getTopLeft(find.text('SUP-000002')).dx;
    expect(secondNarrow, closeTo(firstNarrow, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('pressing Enter sends a customer support message', (
    tester,
  ) async {
    final repository = _SupportScreenRepository(
      bootstrapValue: _bootstrap(),
      ticketValue: _ticket(status: 'assigned'),
    );

    await _pumpSupportApp(
      tester,
      repository,
      initialLocation: '/support/tickets/stk_1',
    );

    final composer = find.byKey(const ValueKey('support-chat-composer'));
    await tester.tap(composer);
    await tester.enterText(composer, 'Hello support');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(repository.sendMessageCalls, 1);
    expect(repository.lastSentBody, 'Hello support');
    expect(tester.widget<TextField>(composer).controller!.text, isEmpty);
  });

  testWidgets('queued ticket stays readable but hides the chat composer', (
    tester,
  ) async {
    final repository = _SupportScreenRepository(
      bootstrapValue: _bootstrap(),
      ticketValue: _ticket(),
      messagesValue: [
        SupportMessage(
          id: 'msg_initial',
          sequence: 1,
          senderType: 'customer',
          senderName: 'Customer',
          body: 'Please review my payment.',
          attachments: const [],
          createdAt: DateTime(2026, 7, 23, 10),
          readByCounterpart: false,
        ),
      ],
    );

    await _pumpSupportApp(
      tester,
      repository,
      initialLocation: '/support/tickets/stk_1',
    );

    expect(find.text('Please review my payment.'), findsOneWidget);
    expect(find.text('Your request is in the queue'), findsOneWidget);
    expect(find.byKey(const ValueKey('support-chat-composer')), findsNothing);
    expect(find.byIcon(Icons.send_rounded), findsNothing);
    expect(repository.sendMessageCalls, 0);
  });
}

Future<void> _pumpSupportApp(
  WidgetTester tester,
  SupportRepository repository, {
  required String initialLocation,
}) async {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(path: '/support', builder: (_, __) => const SupportHomeScreen()),
      GoRoute(
        path: '/support/new',
        builder: (_, __) => const SupportNewTicketScreen(),
      ),
      GoRoute(
        path: '/support/tickets',
        builder: (_, __) => const SupportTicketHistoryScreen(),
      ),
      GoRoute(
        path: '/support/tickets/:ticketId',
        builder: (_, state) => SupportTicketChatScreen(
          ticketId: state.pathParameters['ticketId']!,
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
        supportRepositoryProvider.overrideWithValue(repository),
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

SupportBootstrap _bootstrap({SupportTicket? activeTicket}) {
  return SupportBootstrap(
    enabled: true,
    categories: const [
      SupportCategory(
        id: 'cat_order',
        code: 'order',
        name: 'Order issue',
        iconKey: 'receipt',
      ),
    ],
    activeTicket: activeTicket,
    historyCount: 2,
    unreadCount: activeTicket?.unreadCount ?? 0,
    limits: const SupportLimits.defaults(),
  );
}

SupportTicket _ticket({
  String id = 'stk_1',
  String publicNo = 'SUP-000001',
  String subject = 'Payment was not completed',
  String status = 'queued',
  DateTime? closedAt,
  String closedByName = '',
}) {
  return SupportTicket(
    id: id,
    publicNo: publicNo,
    categoryId: 'cat_order',
    categoryName: 'Order issue',
    subject: subject,
    status: status,
    chatAvailable: status != 'queued' && status != 'closed',
    lastMessage: 'Please review my payment.',
    unreadCount: 1,
    queuePosition: status == 'queued' ? 2 : null,
    openedAt: DateTime(2026, 7, 23, 10),
    updatedAt: DateTime(2026, 7, 23, 10),
    closedAt: closedAt,
    closedByName: closedByName,
    agent: status == 'queued'
        ? null
        : const SupportAgent(id: 'agent_1', name: 'Agent One'),
    rating: null,
  );
}

class _SupportScreenRepository extends SupportRepository {
  _SupportScreenRepository({
    required this.bootstrapValue,
    this.faqsValue = const [],
    this.ticketValue,
    this.ticketAfterFirstFetch,
    this.messagesValue = const [],
    this.ticketsValue = const [],
    this.faqFailuresBeforeSuccess = 0,
  }) : super(_testApiClient(), localeResolver: () => 'en-US');

  final SupportBootstrap bootstrapValue;
  final List<SupportFaq> faqsValue;
  final SupportTicket? ticketValue;
  final SupportTicket? ticketAfterFirstFetch;
  final List<SupportMessage> messagesValue;
  final List<SupportTicket> ticketsValue;
  final int faqFailuresBeforeSuccess;
  int faqCalls = 0;
  int ticketCalls = 0;
  int sendMessageCalls = 0;
  String lastSentBody = '';

  @override
  Future<SupportBootstrap> bootstrap() async => bootstrapValue;

  @override
  Future<List<SupportFaq>> faqs({
    String query = '',
    String categoryId = '',
  }) async {
    faqCalls++;
    if (faqCalls <= faqFailuresBeforeSuccess) {
      throw StateError('FAQ unavailable');
    }
    return faqsValue;
  }

  @override
  Future<SupportTicketPage> tickets({
    required bool closed,
    String? cursor,
  }) async {
    return SupportTicketPage(items: ticketsValue, nextCursor: null);
  }

  @override
  Future<SupportTicket> ticket(String id) async {
    ticketCalls++;
    if (ticketCalls > 1 && ticketAfterFirstFetch != null) {
      return ticketAfterFirstFetch!;
    }
    return ticketValue ?? _ticket();
  }

  @override
  Future<SupportMessagePage> messages(
    String ticketId, {
    int? beforeSequence,
  }) async {
    return SupportMessagePage(items: messagesValue, nextBeforeSequence: null);
  }

  @override
  Future<SupportMessage> sendMessage(
    String ticketId, {
    required String body,
    List<XFile> attachments = const [],
    String? idempotencyKey,
    void Function(int, int)? onSendProgress,
  }) async {
    sendMessageCalls++;
    lastSentBody = body;
    return SupportMessage(
      id: 'msg_sent',
      sequence: messagesValue.length + 1,
      senderType: 'customer',
      senderName: 'Customer',
      body: body,
      attachments: const [],
      createdAt: DateTime(2026, 7, 23, 12),
      readByCounterpart: false,
    );
  }

  @override
  Future<void> markRead(String ticketId, int sequence) async {}

  @override
  Future<SupportRealtimeBinding?> realtimeBinding(String ticketId) async {
    return null;
  }
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
