import 'dart:async';

import 'package:customer_flutter/core/auth/auth_token_store.dart';
import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/i18n/app_locale.dart';
import 'package:customer_flutter/core/i18n/customer_localizations.dart';
import 'package:customer_flutter/core/network/api_client.dart';
import 'package:customer_flutter/core/tenant/mobile_bootstrap_controller.dart';
import 'package:customer_flutter/core/theme/app_theme.dart';
import 'package:customer_flutter/core/utils/formatters.dart';
import 'package:customer_flutter/features/reward_claims/data/reward_claim_models.dart';
import 'package:customer_flutter/features/reward_claims/data/reward_claim_repository.dart';
import 'package:customer_flutter/features/reward_claims/presentation/claim_realtime_monitor.dart';
import 'package:customer_flutter/features/reward_claims/presentation/reward_claim_detail_screen.dart';
import 'package:customer_flutter/features/reward_claims/presentation/reward_claims_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('reward claims list renders Nuxt payout rows and loads more', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _RewardClaimListRepository();

    await _pumpRewardClaims(tester, [
      rewardClaimRepositoryProvider.overrideWithValue(repository),
    ]);
    await tester.pumpAndSettle();

    expect(repository.listCalls, 1);
    expect(find.text('ประวัติขึ้นเงินรางวัลสลากดิจิทัล'), findsOneWidget);
    expect(find.text('เงินรางวัลสลากฯ'), findsOneWidget);
    expect(find.text('3,940 บาท'), findsOneWidget);
    expect(find.text('โอนเงินสำเร็จ'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('โอนเงินสำเร็จ')).style?.color,
      const Color(0xFF28A81E),
    );
    expect(find.text('รางวัลเลขท้าย 2 ตัว'), findsOneWidget);
    expect(find.text('รางวัลเลขหน้า 3 ตัว'), findsOneWidget);
    expect(find.text('รับผ่านบัญชีกรุงไทย'), findsOneWidget);
    expect(
      find.text(formatLocalizedDateTime('2026-05-16T10:30:00+07:00', 'th-TH')),
      findsOneWidget,
    );
    expect(find.textContaining('RWD-0001 •'), findsNothing);
    expect(find.byType(Card), findsNothing);
    final loadMoreButton = find.widgetWithText(OutlinedButton, 'โหลดเพิ่มเติม');
    expect(loadMoreButton, findsOneWidget);
    expect(
      find.descendant(
        of: loadMoreButton,
        matching: find.byIcon(Icons.expand_more),
      ),
      findsNothing,
    );
    expect(
      tester.widget<Icon>(find.byIcon(Icons.chevron_right)).color,
      const Color(0xFF3B9CFF),
    );

    await tester.tap(find.text('โหลดเพิ่มเติม'));
    await tester.pumpAndSettle();

    expect(repository.listCalls, 2);
    expect(repository.cursors, [null, 'cursor_2']);
    expect(find.text('ยกเลิกรายการ'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('ยกเลิกรายการ')).style?.color,
      const Color(0xFFED2C25),
    );
    expect(find.text('รับเข้า Primary wallet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reward claims list stays Nuxt-dense on compact mobile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpRewardClaims(tester, [
      rewardClaimRepositoryProvider.overrideWithValue(
        _RewardClaimListRepository(),
      ),
    ]);
    await tester.pumpAndSettle();

    expect(find.text('ประวัติขึ้นเงินรางวัลสลากดิจิทัล'), findsOneWidget);
    expect(find.text('เงินรางวัลสลากฯ'), findsOneWidget);
    expect(find.text('3,940 บาท'), findsOneWidget);
    expect(find.text('โอนเงินสำเร็จ'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    expect(find.byType(Card), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reward claims list back action returns to profile like Nuxt', (
    tester,
  ) async {
    await _pumpRewardClaims(tester, [
      rewardClaimRepositoryProvider.overrideWithValue(
        _RewardClaimListRepository(),
      ),
    ]);
    await tester.pumpAndSettle();

    final backButton = find.byTooltip('ย้อนกลับ');
    expect(backButton, findsOneWidget);

    await tester.tap(backButton);
    await tester.pumpAndSettle();

    expect(find.text('Profile route'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reward claims loading and error states use Nuxt copy', (
    tester,
  ) async {
    final completer = Completer<RewardClaimPage>();
    final pendingRepository = _RewardClaimPendingRepository(completer.future);

    await _pumpRewardClaims(tester, [
      rewardClaimRepositoryProvider.overrideWithValue(pendingRepository),
    ]);
    await tester.pump();

    expect(find.text('กำลังโหลดประวัติขึ้นเงิน...'), findsOneWidget);
    expect(find.byType(Card), findsNothing);

    completer.complete(
      const RewardClaimPage(items: [], nextCursor: null, hasMore: false),
    );
    await tester.pumpAndSettle();

    expect(find.text('ยังไม่มีประวัติขึ้นเงิน'), findsOneWidget);
    expect(find.text('ดูสลากฯ ที่ถูกรางวัล'), findsOneWidget);

    await tester.tap(find.text('ดูสลากฯ ที่ถูกรางวัล'));
    await tester.pumpAndSettle();

    expect(find.text('Ticket history route'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    final failingRepository = _RewardClaimFailingRepository();
    await _pumpRewardClaims(tester, [
      rewardClaimRepositoryProvider.overrideWithValue(failingRepository),
    ]);
    await tester.pumpAndSettle();

    expect(find.text('โหลดประวัติขึ้นเงินไม่สำเร็จ'), findsOneWidget);
    expect(find.text('ลองใหม่'), findsOneWidget);
    expect(find.byType(Card), findsNothing);
    expect(failingRepository.listCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reward claims API errors use server copy like Nuxt', (
    tester,
  ) async {
    await _pumpRewardClaims(tester, [
      rewardClaimRepositoryProvider.overrideWithValue(
        _RewardClaimApiMessageRepository('ระบบขึ้นเงินปิดปรับปรุง'),
      ),
    ]);
    await tester.pumpAndSettle();

    expect(find.text('ระบบขึ้นเงินปิดปรับปรุง'), findsOneWidget);
    expect(find.text('โหลดประวัติขึ้นเงินไม่สำเร็จ'), findsNothing);
    expect(find.text('ลองใหม่'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    await _pumpRewardClaimDetailProvider(
      tester,
      claimId: 'claim_api_error',
      detail: () async => throw _apiException('ไม่พบรายการขึ้นเงินนี้'),
    );
    await tester.pumpAndSettle();

    expect(find.text('ไม่พบรายการขึ้นเงินนี้'), findsOneWidget);
    expect(find.text('โหลดรายการขึ้นเงินไม่สำเร็จ'), findsNothing);
    expect(find.text('ลองใหม่'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reward claims list refreshes on realtime tick', (
    tester,
  ) async {
    final repository = _RewardClaimRealtimeRepository();
    final container = ProviderContainer(
      overrides: _rewardClaimsOverrides([
        rewardClaimRepositoryProvider.overrideWithValue(repository),
      ]),
    );
    addTearDown(container.dispose);

    await _pumpRewardClaims(tester, const [], container: container);
    await tester.pumpAndSettle();

    expect(repository.listCalls, 1);
    expect(find.text('รอดำเนินการโอนเงิน'), findsOneWidget);
    expect(find.text('โอนเงินสำเร็จ'), findsNothing);

    container.read(rewardClaimRealtimeTickProvider.notifier).state++;
    await tester.pump();
    await tester.pumpAndSettle();

    expect(repository.listCalls, 2);
    expect(find.text('โอนเงินสำเร็จ'), findsOneWidget);
    expect(find.text('รอดำเนินการโอนเงิน'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reward claim detail renders receipt payout, tax, and fee rows', (
    tester,
  ) async {
    await _pumpRewardClaimDetail(
      tester,
      _claim(
        id: 'claim_1',
        reference: 'RWD-0001',
        status: 'approved',
        payoutMethod: 'bank_transfer',
        bankName: 'ธนาคารกรุงไทย',
        bankAccountNumber: '006123456789',
        paidAt: '2026-05-16T11:00:00+07:00',
        adminNote: 'ตรวจสอบเอกสารแล้ว',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('รายละเอียดการขึ้นเงินรางวัล'), findsOneWidget);
    expect(find.text('GLO'), findsOneWidget);
    expect(find.text('สลากกินแบ่งรัฐบาล'), findsOneWidget);
    expect(find.text('ผู้รับเงิน'), findsOneWidget);
    expect(find.text('วิรัตน์ ดวงดี'), findsOneWidget);
    expect(find.text('ช่องทางขึ้นเงินรางวัล'), findsOneWidget);
    expect(find.textContaining('ธนาคารกรุงไทย'), findsWidgets);
    expect(find.textContaining('x xxx6789'), findsOneWidget);
    expect(find.text('วิธีขึ้นเงินรางวัล'), findsOneWidget);
    expect(find.text('ขึ้นเงินรางวัลด้วยตนเอง'), findsOneWidget);
    expect(find.text('โอนเงินสำเร็จ'), findsWidgets);
    expect(
      find.text('โอนเงินรางวัลเข้าบัญชีผู้รับเงินเรียบร้อยแล้ว'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Text>(
            find.text('โอนเงินรางวัลเข้าบัญชีผู้รับเงินเรียบร้อยแล้ว'),
          )
          .style
          ?.color,
      const Color(0xFF28A81E),
    );
    expect(find.text('สลากฯ งวดวันที่'), findsOneWidget);
    expect(find.text('740000'), findsOneWidget);
    expect(find.textContaining('รางวัลเลขท้าย 2 ตัว'), findsOneWidget);
    expect(find.text('ค่าภาษีถอนเงิน (0.5%)'), findsOneWidget);
    expect(find.text('20 บาท'), findsOneWidget);
    expect(find.text('ลดให้ 20 บาท'), findsOneWidget);
    expect(find.text('ค่าธรรมเนียม (1%)'), findsOneWidget);
    expect(find.text('39 บาท'), findsOneWidget);
    expect(find.text('ลดให้ 39 บาท'), findsOneWidget);
    expect(find.text('0 บาท'), findsNWidgets(2));
    expect(find.text('ยอดเงินที่ได้รับ'), findsOneWidget);
    expect(find.text('ตรวจสอบเอกสารแล้ว'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('ตรวจสอบเอกสารแล้ว')).style?.color,
      const Color(0xFF475569),
    );
    expect(find.byType(Card), findsNothing);

    await tester.tap(find.byTooltip('ย้อนกลับ'));
    await tester.pumpAndSettle();

    expect(find.text('Reward claim history'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reward claim detail loading and error match Nuxt states', (
    tester,
  ) async {
    final completer = Completer<RewardClaimItem>();
    await _pumpRewardClaimDetailProvider(
      tester,
      claimId: 'claim_pending',
      detail: () => completer.future,
    );
    await tester.pump();

    expect(find.text('กำลังโหลดรายการขึ้นเงิน...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(Card), findsNothing);

    completer.complete(
      _claim(
        id: 'claim_pending',
        reference: 'RWD-PENDING',
        status: 'submitted',
        payoutMethod: 'wallet_credit',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('รายละเอียดการขึ้นเงินรางวัล'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    await _pumpRewardClaimDetailProvider(
      tester,
      claimId: 'claim_failed',
      detail: () async => throw StateError('reward claim detail failed'),
    );
    await tester.pumpAndSettle();

    expect(find.text('โหลดรายการขึ้นเงินไม่สำเร็จ'), findsOneWidget);
    expect(find.text('ลองใหม่'), findsOneWidget);
    expect(find.byType(Card), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reward claim detail uses Nuxt game-name draw date fallback', (
    tester,
  ) async {
    await _pumpRewardClaimDetail(
      tester,
      _claim(
        id: 'claim_game_name',
        reference: 'RWD-GAME-NAME',
        status: 'submitted',
        payoutMethod: 'wallet_credit',
        gameName: 'งวดวันที่ 16 พฤษภาคม 2569',
        drawAt: null,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('สลากฯ งวดวันที่'), findsOneWidget);
    expect(find.text('16 พ.ค. 2569'), findsOneWidget);
    expect(find.text('รอดำเนินการโอนเงิน'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reward claim detail uses legacy top-level customer name', (
    tester,
  ) async {
    await _pumpRewardClaimDetail(
      tester,
      RewardClaimItem.fromJson({
        'id': 'claim_legacy_name',
        'reference': 'RWD-LEGACY-NAME',
        'status': 'submitted',
        'payout_method': 'wallet_credit',
        'prize_amount': {'amount': 200000, 'currency': 'THB'},
        'customer_display_name': 'ลูกค้า Legacy',
        'ticket': {
          'full_number': '123456',
          'game': {'name': 'งวด 16 พ.ค. 2569'},
        },
        'prizes': [
          {
            'prize_type': 'back2',
            'amount': {'amount': 200000, 'currency': 'THB'},
          },
        ],
        'submitted_at': '2026-05-16T10:30:00+07:00',
      }),
    );
    await tester.pumpAndSettle();

    expect(find.text('ผู้รับเงิน'), findsOneWidget);
    expect(find.text('ลูกค้า Legacy'), findsOneWidget);
    expect(find.text('ผู้ใช้งาน'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reward claim detail refreshes on realtime tick', (
    tester,
  ) async {
    var detailCalls = 0;
    FutureOr<RewardClaimItem> detail() {
      detailCalls++;
      if (detailCalls == 1) {
        return _claim(
          id: 'claim_realtime',
          reference: 'RWD-REALTIME',
          status: 'submitted',
          payoutMethod: 'wallet_credit',
        );
      }
      return _claim(
        id: 'claim_realtime',
        reference: 'RWD-REALTIME',
        status: 'paid',
        payoutMethod: 'wallet_credit',
        paidAt: '2026-05-16T11:00:00+07:00',
        adminNote: 'โอนสำเร็จจาก realtime',
      );
    }

    final container = ProviderContainer(
      overrides: _rewardClaimsOverrides([
        rewardClaimDetailProvider('claim_realtime').overrideWith(
          (_) => detail(),
        ),
      ]),
    );
    addTearDown(container.dispose);

    await _pumpRewardClaimDetailProvider(
      tester,
      claimId: 'claim_realtime',
      detail: detail,
      container: container,
    );
    await tester.pumpAndSettle();

    expect(detailCalls, 1);
    expect(find.text('รอดำเนินการโอนเงิน'), findsOneWidget);
    expect(find.text('โอนสำเร็จจาก realtime'), findsNothing);

    container.read(rewardClaimRealtimeTickProvider.notifier).state++;
    await tester.pump();
    await tester.pumpAndSettle();

    expect(detailCalls, 2);
    expect(find.text('โอนเงินสำเร็จ'), findsWidgets);
    expect(find.text('โอนสำเร็จจาก realtime'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reward claim detail remains readable on compact mobile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpRewardClaimDetail(
      tester,
      _claim(
        id: 'claim_compact',
        reference: 'RWD-COMPACT',
        status: 'approved',
        payoutMethod: 'bank_transfer',
        bankName: 'ธนาคารกรุงไทย',
        bankAccountNumber: '006123456789',
        paidAt: '2026-05-16T11:00:00+07:00',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('รายละเอียดการขึ้นเงินรางวัล'), findsOneWidget);
    expect(find.text('ช่องทางขึ้นเงินรางวัล'), findsOneWidget);
    expect(find.textContaining('x xxx6789'), findsOneWidget);
    expect(find.text('ยอดเงินที่ได้รับ'), findsOneWidget);
    expect(find.byType(Card), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpRewardClaims(
  WidgetTester tester,
  List<Override> overrides, {
  ProviderContainer? container,
}) {
  final router = GoRouter(
    initialLocation: '/reward-claims',
    routes: [
      GoRoute(
        path: '/reward-claims',
        builder: (context, state) => const RewardClaimsScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Profile route')),
        ),
      ),
      GoRoute(
        path: '/tickets/history',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Ticket history route')),
        ),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Home route')),
        ),
      ),
      GoRoute(
        path: '/tickets',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Tickets route')),
        ),
      ),
    ],
  );

  final child = MaterialApp.router(
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
  );

  if (container != null) {
    return tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: child,
      ),
    );
  }

  return tester.pumpWidget(
    ProviderScope(
      overrides: _rewardClaimsOverrides(overrides),
      child: child,
    ),
  );
}

Future<void> _pumpRewardClaimDetail(
  WidgetTester tester,
  RewardClaimItem claim,
) {
  return _pumpRewardClaimDetailProvider(
    tester,
    claimId: claim.id,
    detail: () => claim,
  );
}

Future<void> _pumpRewardClaimDetailProvider(
  WidgetTester tester, {
  required String claimId,
  required FutureOr<RewardClaimItem> Function() detail,
  ProviderContainer? container,
}) {
  final router = GoRouter(
    initialLocation: '/reward-claims/$claimId',
    routes: [
      GoRoute(
        path: '/reward-claims/:claimId',
        builder: (context, state) => RewardClaimDetailScreen(
          claimId: state.pathParameters['claimId'] ?? '',
        ),
      ),
      GoRoute(
        path: '/reward-claims',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Reward claim history')),
        ),
      ),
    ],
  );

  final child = MaterialApp.router(
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
  );

  if (container != null) {
    return tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: child,
      ),
    );
  }

  return tester.pumpWidget(
    ProviderScope(
      overrides: _rewardClaimsOverrides([
        rewardClaimDetailProvider(claimId).overrideWith((_) => detail()),
      ]),
      child: child,
    ),
  );
}

List<Override> _rewardClaimsOverrides(List<Override> overrides) {
  return [
    claimRealtimeEnabledProvider.overrideWithValue(false),
    mobileBootstrapProvider.overrideWith((_) async => _bootstrap()),
    ...overrides,
  ];
}

MobileBootstrap _bootstrap() {
  return MobileBootstrap.fromJson(
    const {
      'tenant_id': 'tenant_reward_claims_test',
      'site': {
        'display_name': 'Partner Lottery',
        'locale': 'th-TH',
      },
      'mobile': {'ticket_image_watermark': 'GLO'},
    },
    defaultLocale: 'th-TH',
    defaultSiteName: 'Partner Lottery',
  );
}

RewardClaimItem _claim({
  required String id,
  required String reference,
  required String status,
  required String payoutMethod,
  String bankName = '',
  String bankAccountNumber = '',
  String walletName = 'Primary wallet',
  String payoutLedgerId = '',
  String? paidAt,
  String adminNote = '',
  String gameName = 'งวด 16 พ.ค. 2569',
  Object? drawAt = '2026-05-16T17:00:00+07:00',
}) {
  return RewardClaimItem.fromJson({
    'id': id,
    'reference': reference,
    'status': status,
    'payout_method': payoutMethod,
    'payout_ledger_id': payoutLedgerId,
    'prize_amount': {'amount': 394000, 'currency': 'THB'},
    'customer': {'name': 'วิรัตน์ ดวงดี'},
    'ticket': {
      'full_number': '740000',
      'game': {
        'name': gameName,
        'draw_at': drawAt,
      },
    },
    'prizes': [
      {
        'prize_type': 'back2',
        'amount': {'amount': 200000, 'currency': 'THB'},
      },
      {
        'prize_type': 'front3',
        'amount': {'amount': 194000, 'currency': 'THB'},
      },
    ],
    'bank_name': bankName,
    'bank_account_number': bankAccountNumber,
    'wallet_name': walletName,
    'submitted_at': '2026-05-16T10:30:00+07:00',
    'paid_at': paidAt,
    'admin_note': adminNote,
  });
}

class _RewardClaimListRepository extends RewardClaimRepository {
  _RewardClaimListRepository() : super(_testApiClient());

  int listCalls = 0;
  final cursors = <String?>[];

  @override
  Future<RewardClaimPage> list({int limit = 20, String? cursor}) async {
    listCalls++;
    cursors.add(cursor);

    if (cursor == 'cursor_2') {
      return RewardClaimPage(
        items: [
          _claim(
            id: 'claim_2',
            reference: 'RWD-0002',
            status: 'cancelled',
            payoutMethod: 'wallet_credit',
          ),
        ],
        nextCursor: null,
        hasMore: false,
      );
    }

    return RewardClaimPage(
      items: [
        _claim(
          id: 'claim_1',
          reference: 'RWD-0001',
          status: 'approved',
          payoutMethod: 'bank_transfer',
          bankName: 'ธนาคารกรุงไทย',
          bankAccountNumber: '006123456789',
          payoutLedgerId: 'ledger_1',
        ),
      ],
      nextCursor: 'cursor_2',
      hasMore: true,
    );
  }
}

class _RewardClaimRealtimeRepository extends RewardClaimRepository {
  _RewardClaimRealtimeRepository() : super(_testApiClient());

  int listCalls = 0;

  @override
  Future<RewardClaimPage> list({int limit = 20, String? cursor}) async {
    listCalls++;
    if (listCalls == 1) {
      return RewardClaimPage(
        items: [
          _claim(
            id: 'claim_realtime',
            reference: 'RWD-REALTIME',
            status: 'submitted',
            payoutMethod: 'wallet_credit',
          ),
        ],
        nextCursor: null,
        hasMore: false,
      );
    }

    return RewardClaimPage(
      items: [
        _claim(
          id: 'claim_realtime',
          reference: 'RWD-REALTIME',
          status: 'paid',
          payoutMethod: 'wallet_credit',
          paidAt: '2026-05-16T11:00:00+07:00',
        ),
      ],
      nextCursor: null,
      hasMore: false,
    );
  }
}

class _RewardClaimPendingRepository extends RewardClaimRepository {
  _RewardClaimPendingRepository(this._page) : super(_testApiClient());

  final Future<RewardClaimPage> _page;
  int listCalls = 0;

  @override
  Future<RewardClaimPage> list({int limit = 20, String? cursor}) {
    listCalls++;
    return _page;
  }
}

class _RewardClaimFailingRepository extends RewardClaimRepository {
  _RewardClaimFailingRepository() : super(_testApiClient());

  int listCalls = 0;

  @override
  Future<RewardClaimPage> list({int limit = 20, String? cursor}) async {
    listCalls++;
    throw StateError('reward claim history failed');
  }
}

class _RewardClaimApiMessageRepository extends RewardClaimRepository {
  _RewardClaimApiMessageRepository(this.message) : super(_testApiClient());

  final String message;

  @override
  Future<RewardClaimPage> list({int limit = 20, String? cursor}) async {
    throw _apiException(message);
  }
}

DioException _apiException(String message) {
  final requestOptions = RequestOptions(path: '/customer/reward-claims');
  return DioException(
    requestOptions: requestOptions,
    response: Response<Map<String, dynamic>>(
      requestOptions: requestOptions,
      statusCode: 503,
      data: {'message': message},
    ),
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
