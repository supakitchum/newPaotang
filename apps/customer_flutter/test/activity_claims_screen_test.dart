import 'dart:async';

import 'package:customer_flutter/core/auth/auth_token_store.dart';
import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/i18n/app_locale.dart';
import 'package:customer_flutter/core/i18n/customer_localizations.dart';
import 'package:customer_flutter/core/network/api_client.dart';
import 'package:customer_flutter/core/theme/app_theme.dart';
import 'package:customer_flutter/core/utils/formatters.dart';
import 'package:customer_flutter/features/activity_claims/data/activity_claim_models.dart';
import 'package:customer_flutter/features/activity_claims/data/activity_claim_repository.dart';
import 'package:customer_flutter/features/activity_claims/presentation/activity_claim_detail_screen.dart';
import 'package:customer_flutter/features/activity_claims/presentation/activity_claims_screen.dart';
import 'package:customer_flutter/features/reward_claims/presentation/claim_realtime_monitor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('activity claims list exposes Nuxt-style back to profile', (
    tester,
  ) async {
    final repository = _ActivityClaimListRepository();

    await _pumpActivityClaimsRoute(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('ย้อนกลับ'));
    await tester.pumpAndSettle();

    expect(find.text('Profile route'), findsOneWidget);
  });

  testWidgets('activity claims list uses Nuxt loading copy', (
    tester,
  ) async {
    await _pumpActivityClaims(tester, [
      activityClaimRepositoryProvider.overrideWithValue(
        _PendingActivityClaimRepository(),
      ),
    ]);
    await tester.pump();

    expect(find.text('กำลังโหลดประวัติขึ้นเงินกิจกรรม...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('activity claims list renders payout rows and loads more', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _ActivityClaimListRepository();

    await _pumpActivityClaims(tester, [
      activityClaimRepositoryProvider.overrideWithValue(repository),
    ]);
    await tester.pumpAndSettle();

    expect(repository.listCalls, 1);
    expect(find.text('เงินรางวัลกิจกรรม'), findsOneWidget);
    expect(find.text('1,500.00 บาท'), findsOneWidget);
    expect(find.text('โอนเงินสำเร็จ'), findsOneWidget);
    expect(find.text('เงินคืนกิจกรรม'), findsOneWidget);
    expect(find.text('ลุ้นโชคงวดนี้'), findsWidgets);
    expect(find.text('รับผ่านบัญชีกสิกรไทย'), findsOneWidget);
    expect(
      find.text(
        formatLocalizedDateTime('2026-06-26T10:30:00+07:00', 'th-TH'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('โหลดเพิ่มเติม'));
    await tester.pumpAndSettle();

    expect(repository.listCalls, 2);
    expect(repository.cursors, [null, 'cursor_2']);
    expect(find.text('ยกเลิกรายการ'), findsOneWidget);
    expect(find.text('รับเข้า Primary wallet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('activity claims list refreshes on realtime tick', (
    tester,
  ) async {
    final repository = _ActivityClaimRealtimeRepository();
    final container = ProviderContainer(
      overrides: [
        activityClaimRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    await _pumpActivityClaimsWithContainer(tester, container);
    await tester.pumpAndSettle();

    expect(repository.listCalls, 1);
    expect(find.text('รอดำเนินการโอนเงิน'), findsOneWidget);
    expect(find.text('โอนเงินสำเร็จ'), findsNothing);

    container.read(activityClaimRealtimeTickProvider.notifier).state++;
    await tester.pump();
    await tester.pumpAndSettle();

    expect(repository.listCalls, 2);
    expect(find.text('รอดำเนินการโอนเงิน'), findsNothing);
    expect(find.text('โอนเงินสำเร็จ'), findsOneWidget);
    expect(find.text('ACT-REALTIME'), findsNothing);
    expect(find.text('รับเข้า Primary wallet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('activity claim detail renders Nuxt-style receipt rows', (
    tester,
  ) async {
    await _pumpActivityClaimDetail(
      tester,
      _claim(
        id: 'activity_claim_1',
        reference: 'ACT-0001',
        status: 'approved',
        payoutMethod: 'bank_transfer',
        payoutLedgerId: 'ledger_activity_1',
        bankName: 'ธนาคารกสิกรไทย',
        bankAccountNumber: '1234567890',
        paidAt: '2026-06-26T11:00:00+07:00',
        customerNote: 'ขอรับเข้าบัญชีนี้',
        adminNote: 'ตรวจสอบเรียบร้อย',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('รายละเอียดขึ้นเงินรางวัลกิจกรรม'), findsOneWidget);
    expect(find.byType(Card), findsNothing);
    expect(find.text('รางวัลกิจกรรม'), findsWidgets);
    expect(find.text('ยอดเงินที่ได้รับ'), findsOneWidget);
    expect(find.text('ผู้รับเงิน'), findsOneWidget);
    expect(find.text('มานะ ใจดี'), findsOneWidget);
    expect(find.text('ช่องทางขึ้นเงินรางวัล'), findsOneWidget);
    expect(find.textContaining('ธนาคารกสิกรไทย'), findsWidgets);
    expect(find.textContaining('x xxx7890'), findsOneWidget);
    expect(find.text('วิธีขึ้นเงินรางวัล'), findsOneWidget);
    expect(find.text('โอนเข้าบัญชีธนาคาร'), findsOneWidget);
    expect(find.text('โอนเงินสำเร็จ'), findsWidgets);
    expect(find.text('โอนเงินรางวัลกิจกรรมเรียบร้อยแล้ว'), findsOneWidget);
    expect(find.text('กิจกรรม'), findsWidgets);
    expect(find.text('ลุ้นโชคงวดนี้'), findsWidgets);
    expect(find.text('เงินคืนกิจกรรม'), findsOneWidget);
    expect(find.text('ACT-0001'), findsOneWidget);
    expect(find.text('ยอดรางวัลกิจกรรม'), findsOneWidget);
    expect(find.text('หมายเหตุของลูกค้า'), findsOneWidget);
    expect(find.text('ขอรับเข้าบัญชีนี้'), findsOneWidget);
    expect(find.text('หมายเหตุจากผู้ตรวจสอบ'), findsOneWidget);
    expect(find.text('ตรวจสอบเรียบร้อย'), findsOneWidget);

    await tester.tap(find.byTooltip('ย้อนกลับ'));
    await tester.pumpAndSettle();

    expect(find.text('Activity claim history'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('activity claim detail uses Nuxt loading copy', (
    tester,
  ) async {
    const claimId = 'activity_claim_loading';
    final container = ProviderContainer(
      overrides: [
        activityClaimDetailProvider(claimId).overrideWith((_) {
          return Completer<ActivityClaimItem>().future;
        }),
      ],
    );
    addTearDown(container.dispose);

    await _pumpActivityClaimDetailWithContainer(tester, container, claimId);
    await tester.pump();

    expect(find.text('กำลังโหลดรายการขึ้นเงินกิจกรรม...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(Card), findsNothing);
  });

  testWidgets('activity claim detail uses Nuxt error copy', (
    tester,
  ) async {
    const claimId = 'activity_claim_error';
    final container = ProviderContainer(
      overrides: [
        activityClaimDetailProvider(claimId).overrideWith((_) async {
          throw Exception('not found');
        }),
      ],
    );
    addTearDown(container.dispose);

    await _pumpActivityClaimDetailWithContainer(tester, container, claimId);
    await tester.pumpAndSettle();

    expect(find.text('โหลดรายการขึ้นเงินกิจกรรมไม่สำเร็จ'), findsOneWidget);
    expect(find.byType(Card), findsNothing);
  });

  testWidgets('activity claim detail refreshes on realtime tick', (
    tester,
  ) async {
    var loads = 0;
    const claimId = 'activity_claim_realtime';
    final container = ProviderContainer(
      overrides: [
        activityClaimDetailProvider(claimId).overrideWith((_) async {
          loads++;
          return _claim(
            id: claimId,
            reference: 'ACT-REALTIME',
            status: loads == 1 ? 'submitted' : 'approved',
            payoutMethod: 'wallet_credit',
            payoutLedgerId: loads == 1 ? '' : 'ledger_activity_realtime',
            paidAt: loads == 1 ? null : '2026-06-26T12:00:00+07:00',
            adminNote: loads == 1 ? '' : 'โอนสำเร็จจาก realtime',
          );
        }),
      ],
    );
    addTearDown(container.dispose);

    await _pumpActivityClaimDetailWithContainer(
      tester,
      container,
      claimId,
    );
    await tester.pumpAndSettle();

    expect(loads, 1);
    expect(find.text('รอดำเนินการโอนเงิน'), findsWidgets);
    expect(find.text('โอนสำเร็จจาก realtime'), findsNothing);

    container.read(activityClaimRealtimeTickProvider.notifier).state++;
    await tester.pump();
    await tester.pumpAndSettle();

    expect(loads, 2);
    expect(find.text('โอนเงินสำเร็จ'), findsWidgets);
    expect(find.text('โอนสำเร็จจาก realtime'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpActivityClaimsRoute(
  WidgetTester tester,
  ActivityClaimRepository repository,
) {
  final router = GoRouter(
    initialLocation: '/activity-claims',
    routes: [
      GoRoute(
        path: '/activity-claims',
        builder: (context, state) => const ActivityClaimsScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Profile route')),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);

  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        activityClaimRepositoryProvider.overrideWithValue(repository),
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

Future<void> _pumpActivityClaims(
  WidgetTester tester,
  List<Override> overrides,
) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        locale: fallbackCustomerLocale,
        supportedLocales: supportedCustomerLocales,
        localizationsDelegates: const [
          CustomerLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.light(),
        home: const ActivityClaimsScreen(),
      ),
    ),
  );
}

Future<void> _pumpActivityClaimsWithContainer(
  WidgetTester tester,
  ProviderContainer container,
) {
  return tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: fallbackCustomerLocale,
        supportedLocales: supportedCustomerLocales,
        localizationsDelegates: const [
          CustomerLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.light(),
        home: const ActivityClaimsScreen(),
      ),
    ),
  );
}

Future<void> _pumpActivityClaimDetail(
  WidgetTester tester,
  ActivityClaimItem claim,
) {
  final router = GoRouter(
    initialLocation: '/activity-claims/${claim.id}',
    routes: [
      GoRoute(
        path: '/activity-claims/:claimId',
        builder: (context, state) => ActivityClaimDetailScreen(
          claimId: state.pathParameters['claimId'] ?? '',
        ),
      ),
      GoRoute(
        path: '/activity-claims',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Activity claim history')),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);

  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        activityClaimDetailProvider(claim.id).overrideWith((_) async => claim),
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

Future<void> _pumpActivityClaimDetailWithContainer(
  WidgetTester tester,
  ProviderContainer container,
  String claimId,
) {
  final router = GoRouter(
    initialLocation: '/activity-claims/$claimId',
    routes: [
      GoRoute(
        path: '/activity-claims/:claimId',
        builder: (context, state) => ActivityClaimDetailScreen(
          claimId: state.pathParameters['claimId'] ?? '',
        ),
      ),
    ],
  );
  addTearDown(router.dispose);

  return tester.pumpWidget(
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
}

class _PendingActivityClaimRepository extends ActivityClaimRepository {
  _PendingActivityClaimRepository() : super(_testApiClient());

  final completer = Completer<ActivityClaimPage>();

  @override
  Future<ActivityClaimPage> list({int limit = 20, String? cursor}) {
    return completer.future;
  }
}

ActivityClaimItem _claim({
  required String id,
  required String reference,
  required String status,
  required String payoutMethod,
  String payoutLedgerId = '',
  String bankName = '',
  String bankAccountNumber = '',
  String walletName = 'Primary wallet',
  String? paidAt,
  String customerNote = '',
  String adminNote = '',
}) {
  return ActivityClaimItem.fromJson({
    'id': id,
    'reference': reference,
    'status': status,
    'payout_method': payoutMethod,
    'payout_ledger_id': payoutLedgerId,
    'claim_amount': {'amount': 150000, 'currency': 'THB'},
    'customer': {'name': 'มานะ ใจดี'},
    'activity_name': 'ลุ้นโชคงวดนี้',
    'award': {
      'type': 'cashback',
      'activity_name': 'ลุ้นโชคงวดนี้',
      'amount': {'amount': 150000, 'currency': 'THB'},
    },
    'bank_name': bankName,
    'bank_account_number': bankAccountNumber,
    'wallet_name': walletName,
    'submitted_at': '2026-06-26T10:30:00+07:00',
    'paid_at': paidAt,
    'customer_note': customerNote,
    'admin_note': adminNote,
  });
}

class _ActivityClaimListRepository extends ActivityClaimRepository {
  _ActivityClaimListRepository() : super(_testApiClient());

  int listCalls = 0;
  final cursors = <String?>[];

  @override
  Future<ActivityClaimPage> list({int limit = 20, String? cursor}) async {
    listCalls++;
    cursors.add(cursor);

    if (cursor == 'cursor_2') {
      return ActivityClaimPage(
        items: [
          _claim(
            id: 'activity_claim_2',
            reference: 'ACT-0002',
            status: 'cancelled',
            payoutMethod: 'wallet_credit',
          ),
        ],
        nextCursor: null,
        hasMore: false,
      );
    }

    return ActivityClaimPage(
      items: [
        _claim(
          id: 'activity_claim_1',
          reference: 'ACT-0001',
          status: 'approved',
          payoutMethod: 'bank_transfer',
          payoutLedgerId: 'ledger_activity_1',
          bankName: 'ธนาคารกสิกรไทย',
          bankAccountNumber: '1234567890',
        ),
      ],
      nextCursor: 'cursor_2',
      hasMore: true,
    );
  }
}

class _ActivityClaimRealtimeRepository extends ActivityClaimRepository {
  _ActivityClaimRealtimeRepository() : super(_testApiClient());

  int listCalls = 0;

  @override
  Future<ActivityClaimPage> list({int limit = 20, String? cursor}) async {
    listCalls++;
    return ActivityClaimPage(
      items: [
        _claim(
          id: 'activity_claim_realtime',
          reference: 'ACT-REALTIME',
          status: listCalls == 1 ? 'submitted' : 'approved',
          payoutMethod: 'wallet_credit',
          payoutLedgerId: listCalls == 1 ? '' : 'ledger_activity_realtime_list',
          paidAt: listCalls == 1 ? null : '2026-06-26T12:00:00+07:00',
        ),
      ],
      nextCursor: null,
      hasMore: false,
    );
  }
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
