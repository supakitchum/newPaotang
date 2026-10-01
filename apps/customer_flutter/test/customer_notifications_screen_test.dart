import 'dart:async';

import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/auth/auth_token_store.dart';
import 'package:customer_flutter/core/i18n/app_locale.dart';
import 'package:customer_flutter/core/i18n/customer_localizations.dart';
import 'package:customer_flutter/core/network/api_client.dart';
import 'package:customer_flutter/core/tenant/mobile_bootstrap_controller.dart';
import 'package:customer_flutter/core/theme/app_theme.dart';
import 'package:customer_flutter/features/notifications/data/customer_notification_models.dart';
import 'package:customer_flutter/features/notifications/data/customer_notification_repository.dart';
import 'package:customer_flutter/features/notifications/presentation/customer_notification_realtime_monitor.dart';
import 'package:customer_flutter/features/notifications/presentation/customer_notifications_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('opening inbox from the bell marks all before loading rows', (
    tester,
  ) async {
    final calls = <String>[];
    final repository = _InboxRepository(
      listResponses: [
        () async {
          calls.add('list');
          return _page([
            _item(
              'read-on-open',
              'อ่านจากกระดิ่งแล้ว',
              isRead: true,
              readAt: DateTime(2026, 8, 13, 14),
            ),
          ], unreadCount: 0);
        },
      ],
      markAllReadHandler: () async {
        calls.add('mark-all');
        return 0;
      },
    );

    await _pumpInbox(tester, repository, markAllOnOpen: true);
    await tester.pumpAndSettle();

    expect(calls, ['mark-all', 'list']);
    expect(repository.markAllReadCalls, 1);
    expect(find.text('อ่านจากกระดิ่งแล้ว'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(
            find.byKey(const ValueKey('customer-notification-read-all')),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('realtime refresh is replayed after the initial request', (
    tester,
  ) async {
    final initial = Completer<CustomerNotificationPage>();
    final repository = _InboxRepository(
      listResponses: [
        () => initial.future,
        () async => _page([_item('new', 'รายการล่าสุด')]),
      ],
    );
    final harness = await _pumpInbox(tester, repository);

    expect(repository.listCalls, 1);
    harness.container
        .read(customerNotificationRealtimeTickProvider.notifier)
        .state++;
    await tester.pump();

    initial.complete(_page([_item('old', 'รายการเดิม')]));
    await tester.pumpAndSettle();

    expect(repository.listCalls, 2);
    expect(find.text('รายการล่าสุด'), findsOneWidget);
    expect(find.text('รายการเดิม'), findsNothing);
  });

  testWidgets('read rollback does not overwrite a newer realtime list', (
    tester,
  ) async {
    final markRead = Completer<CustomerNotificationItem>();
    final repository = _InboxRepository(
      listResponses: [
        () async => _page([_item('old', 'รายการเดิม')]),
        () async => _page([
          _item('new', 'รายการใหม่'),
          _item(
            'old',
            'รายการเดิม',
            isRead: true,
            readAt: DateTime(2026, 7, 21, 12),
          ),
        ]),
      ],
      markReadHandler: (_) => markRead.future,
    );
    final harness = await _pumpInbox(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.text('รายการเดิม'));
    await tester.pump();
    harness.container
        .read(customerNotificationRealtimeTickProvider.notifier)
        .state++;
    await tester.pumpAndSettle();

    markRead.completeError(StateError('offline'));
    await tester.pumpAndSettle();

    expect(find.text('รายการใหม่'), findsOneWidget);
    expect(find.text('รายการเดิม'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mark-read response wins over a stale realtime refresh', (
    tester,
  ) async {
    final markRead = Completer<CustomerNotificationItem>();
    final repository = _InboxRepository(
      listResponses: [
        () async => _page([_item('old', 'รายการเดิม')]),
        () async => _page([_item('old', 'รายการเดิม')]),
      ],
      markReadHandler: (_) => markRead.future,
    );
    final harness = await _pumpInbox(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.text('รายการเดิม'));
    await tester.pump();
    harness.container
        .read(customerNotificationRealtimeTickProvider.notifier)
        .state++;
    await tester.pumpAndSettle();

    markRead.complete(
      _item(
        'old',
        'รายการเดิม',
        isRead: true,
        readAt: DateTime(2026, 7, 21, 13),
      ),
    );
    await tester.pumpAndSettle();

    final tile = find.byKey(const ValueKey('customer-notification-old'));
    final material = find.descendant(of: tile, matching: find.byType(Material));
    expect(tester.widget<Material>(material.first).color, Colors.white);
    expect(
      tester
          .widget<TextButton>(
            find.byKey(const ValueKey('customer-notification-read-all')),
          )
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('read-all uses authoritative unread count beyond loaded rows', (
    tester,
  ) async {
    final repository = _InboxRepository(
      listResponses: [
        () async => _page([
          _item('visible-read', 'รายการที่อ่านแล้ว', isRead: true),
        ], unreadCount: 4),
        () async => _page([
          _item('visible-read', 'รายการที่อ่านแล้ว', isRead: true),
        ], unreadCount: 0),
      ],
    );
    await _pumpInbox(tester, repository);
    await tester.pumpAndSettle();

    final button = find.byKey(const ValueKey('customer-notification-read-all'));
    expect(tester.widget<TextButton>(button).onPressed, isNotNull);

    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(repository.markAllReadCalls, 1);
    expect(tester.widget<TextButton>(button).onPressed, isNull);
  });

  testWidgets('read-all failure restores authoritative unread count', (
    tester,
  ) async {
    final repository = _InboxRepository(
      listResponses: [
        () async => _page([
          _item('visible-read', 'รายการที่อ่านแล้ว', isRead: true),
        ], unreadCount: 4),
      ],
      markAllReadHandler: () async => throw StateError('offline'),
    );
    await _pumpInbox(tester, repository);
    await tester.pumpAndSettle();

    final button = find.byKey(const ValueKey('customer-notification-read-all'));
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(repository.markAllReadCalls, 1);
    expect(tester.widget<TextButton>(button).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('read-all rollback preserves notifications received meanwhile', (
    tester,
  ) async {
    final markAll = Completer<int>();
    final repository = _InboxRepository(
      listResponses: [
        () async => _page([_item('old', 'รายการเดิม')]),
        () async =>
            _page([_item('new', 'รายการใหม่'), _item('old', 'รายการเดิม')]),
      ],
      markAllReadHandler: () => markAll.future,
    );
    final harness = await _pumpInbox(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('customer-notification-read-all')),
    );
    await tester.pump();
    harness.container
        .read(customerNotificationRealtimeTickProvider.notifier)
        .state++;
    await tester.pumpAndSettle();

    markAll.completeError(StateError('offline'));
    await tester.pumpAndSettle();

    expect(find.text('รายการใหม่'), findsOneWidget);
    expect(find.text('รายการเดิม'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<_InboxHarness> _pumpInbox(
  WidgetTester tester,
  CustomerNotificationRepository repository, {
  bool markAllOnOpen = false,
}) async {
  final router = GoRouter(
    initialLocation: '/notifications',
    routes: [
      GoRoute(
        path: '/notifications',
        builder: (_, __) =>
            CustomerNotificationsScreen(markAllOnOpen: markAllOnOpen),
      ),
      GoRoute(
        path: '/',
        builder: (_, __) => const Scaffold(body: Text('Home')),
      ),
    ],
  );
  final container = ProviderContainer(
    overrides: [
      customerNotificationRepositoryProvider.overrideWithValue(repository),
      mobileBootstrapProvider.overrideWith((_) async => _bootstrap()),
    ],
  );
  addTearDown(router.dispose);
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
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
  await tester.pump();
  return _InboxHarness(container);
}

class _InboxHarness {
  const _InboxHarness(this.container);

  final ProviderContainer container;
}

class _InboxRepository extends CustomerNotificationRepository {
  _InboxRepository({
    required this.listResponses,
    this.markReadHandler,
    this.markAllReadHandler,
  }) : super(
         ApiClient(
           const AppConfig(
             apiBaseUrl: 'https://partner.example.test/api/v1',
             defaultLocale: 'th-TH',
           ),
           AuthTokenStore(),
           localeTag: 'th-TH',
         ),
       );

  final List<Future<CustomerNotificationPage> Function()> listResponses;
  final Future<CustomerNotificationItem> Function(String id)? markReadHandler;
  final Future<int> Function()? markAllReadHandler;
  int listCalls = 0;
  int markAllReadCalls = 0;

  @override
  Future<CustomerNotificationPage> list({
    int limit = 20,
    String cursor = '',
    String status = 'all',
    String category = '',
  }) {
    final response = listResponses[listCalls];
    listCalls++;
    return response();
  }

  @override
  Future<CustomerNotificationItem> markRead(String notificationId) {
    return markReadHandler?.call(notificationId) ??
        Future.value(_item(notificationId, notificationId, isRead: true));
  }

  @override
  Future<int> markAllRead() {
    markAllReadCalls++;
    return markAllReadHandler?.call() ?? Future.value(0);
  }
}

CustomerNotificationPage _page(
  List<CustomerNotificationItem> items, {
  int? unreadCount,
}) {
  return CustomerNotificationPage(
    items: items,
    nextCursor: '',
    hasMore: false,
    unreadCount: unreadCount ?? items.where((item) => !item.isRead).length,
  );
}

CustomerNotificationItem _item(
  String id,
  String title, {
  bool isRead = false,
  DateTime? readAt,
}) {
  return CustomerNotificationItem(
    id: id,
    category: 'account',
    eventKey: 'account.updated',
    title: title,
    body: 'รายละเอียด',
    iconKey: 'account',
    action: const CustomerNotificationAction(key: 'none'),
    isRead: isRead,
    readAt: readAt,
    createdAt: DateTime(2026, 7, 21, 12),
  );
}

MobileBootstrap _bootstrap() {
  return MobileBootstrap.fromJson(
    const {
      'tenant_id': 'tenant_notification_test',
      'site': {'display_name': 'Partner Lottery', 'locale': 'th-TH'},
    },
    defaultLocale: 'th-TH',
    defaultSiteName: 'Partner Lottery',
  );
}
