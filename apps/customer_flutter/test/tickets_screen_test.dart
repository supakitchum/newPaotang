import 'dart:async';

import 'package:customer_flutter/core/auth/auth_token_store.dart';
import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/i18n/app_locale.dart';
import 'package:customer_flutter/core/i18n/customer_localizations.dart';
import 'package:customer_flutter/core/network/api_client.dart';
import 'package:customer_flutter/core/security/biometric_auth_service.dart';
import 'package:customer_flutter/core/tenant/mobile_bootstrap_controller.dart';
import 'package:customer_flutter/core/tenant/mobile_runtime_policy.dart';
import 'package:customer_flutter/core/theme/app_theme.dart';
import 'package:customer_flutter/features/profile/data/profile_settings_models.dart';
import 'package:customer_flutter/features/profile/data/profile_settings_repository.dart';
import 'package:customer_flutter/features/results/data/result_models.dart';
import 'package:customer_flutter/features/tickets/data/ticket_models.dart';
import 'package:customer_flutter/features/tickets/data/ticket_repository.dart';
import 'package:customer_flutter/features/tickets/presentation/tickets_screen.dart';
import 'package:customer_flutter/shared/widgets/customer_gradient_button.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Finder _ticketTile(String id, String number, {bool history = false}) =>
    find.byKey(
      ValueKey('ticket-tile-${history ? 'history' : 'current'}-$id-$number'),
    );

void main() {
  testWidgets('current tickets show search summary and winning banner', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _TicketCurrentRepository([
      _ticket(
        'current_1',
        '740000',
        count: 2,
        prizeAmount: 2000,
        claimable: true,
        rewardStatus: const TicketRewardStatus(
          status: 'winning',
          claimStatus: '',
          claimable: true,
          prizeType: 'back3',
          prizeNumber: '000',
          prizeAmount: 2000,
          prizes: [],
          rewardClaimId: null,
          payoutMethod: '',
          adminNote: '',
        ),
      ),
      _ticket('current_2', '880000'),
      _ticket('current_3', '123456'),
    ]);

    await _pumpCurrent(tester, repository);
    await tester.pumpAndSettle();

    expect(repository.currentAllCalls, 1);
    expect(find.text('งวดปัจจุบัน'), findsWidgets);
    expect(find.text('งวดย้อนหลัง'), findsOneWidget);
    expect(
      find.text('สลากที่ซื้อแล้วและรายการที่รอขึ้นเงินจะแสดงแยกตามสถานะ'),
      findsNothing,
    );
    expect(find.text('สลากฯ งวดวันที่'), findsOneWidget);
    expect(find.text('ทั้งหมด 4 ใบ'), findsOneWidget);
    expect(find.text('ยินดีด้วย!'), findsOneWidget);
    expect(find.text('คุณถูกรางวัล 2 ใบ'), findsOneWidget);
    expect(find.text('L6'), findsNWidgets(3));
    expect(find.text('80\nบาท'), findsNWidgets(3));
    expect(find.text('สลากดิจิทัล'), findsNWidgets(3));
    expect(find.text('งวดที่'), findsNothing);
    expect(find.text('ชุดที่'), findsNothing);
    expect(_ticketTile('current_1', '740000'), findsOneWidget);
    expect(_ticketTile('current_2', '880000'), findsOneWidget);
    expect(_ticketTile('current_3', '123456'), findsOneWidget);
    expect(find.text('ขึ้นรางวัล'), findsOneWidget);
    expect(find.text('รับเงินรางวัล 2,000 บาท'), findsOneWidget);
    expect(
      find.text(
        'เมนู ‘สลากฯ ของฉัน’ เป็นการบันทึกเลขสลากฯ หากถูกรางวัล ระบบจะแจ้งผลรางวัลในหน้านี้',
      ),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'ค้นหาเลขสลาก'), findsNothing);
    expect(find.byType(Card), findsNothing);

    final searchAction = find.byKey(const ValueKey('tickets-search-action'));
    expect(tester.getSize(searchAction), const Size.square(42));
    expect(tester.getTopLeft(searchAction).dy, 62);
    expect(
      tester.widget<IconButton>(searchAction).icon,
      isA<Icon>()
          .having((icon) => icon.icon, 'icon', Icons.search)
          .having((icon) => icon.size, 'size', 24),
    );

    final router = GoRouter.of(tester.element(find.byType(TicketsScreen)));
    await tester.tap(searchAction);
    await tester.pumpAndSettle();
    expect(router.canPop(), isTrue);
    expect(find.byType(TicketsSearchScreen), findsOneWidget);
    expect(
      find.byKey(const ValueKey('ticket-search-digit-inputs')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('ticket-search-clear')), findsOneWidget);
    final digitInputs = find.descendant(
      of: find.byKey(const ValueKey('ticket-search-digit-inputs')),
      matching: find.byType(TextField),
    );
    expect(digitInputs, findsNWidgets(6));
    for (var index = 0; index < 6; index++) {
      await tester.enterText(digitInputs.at(index), '740000'[index]);
    }
    await tester.tap(find.byKey(const ValueKey('ticket-search-submit')));
    await tester.pumpAndSettle();

    expect(find.text('ผลการค้นหาเลข'), findsOneWidget);
    expect(_ticketTile('current_1', '740000'), findsOneWidget);
    expect(_ticketTile('current_2', '880000'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('ticket-search-clear')));
    await tester.pumpAndSettle();

    expect(
      find.text('คุณสามารถกรอกเลขสลากฯ\nที่ต้องการค้นหาอย่างน้อย 1 หลัก'),
      findsOneWidget,
    );
    expect(_ticketTile('current_2', '880000'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('current tickets use current game instead of stale ticket draw', (
    tester,
  ) async {
    final repository = _TicketCurrentRepository([
      _ticket(
        'stale_ticket',
        '111111',
        gameId: 'game_previous',
        gameName: 'งวด 1 พ.ค. 2569',
        drawAt: '2026-05-01T16:00:00+07:00',
      ),
    ]);

    await _pumpCurrent(
      tester,
      repository,
      currentGame: const CurrentGame(
        id: 'game_current',
        name: 'งวด 1 พ.ค. 2569',
        status: 'closed',
        drawAt: '2026-07-16T16:00:00+07:00',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('16 ก.ค. 2569'), findsOneWidget);
    expect(find.text('1 พ.ค. 2569'), findsNothing);
    expect(find.text('ทั้งหมด 0 ใบ'), findsOneWidget);
    expect(_ticketTile('stale_ticket', '111111'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('history tab switches in place without navigating route', (
    tester,
  ) async {
    final repository = _TicketCurrentWithHistoryRepository(
      currentTickets: [_ticket('current_inline', '111111')],
      historyTickets: [_ticket('history_inline', '990000')],
    );

    await _pumpCurrent(tester, repository);
    await tester.pumpAndSettle();

    final router = GoRouter.of(tester.element(find.byType(TicketsScreen)));

    expect(router.routerDelegate.currentConfiguration.uri.path, '/tickets');
    expect(repository.currentAllCalls, 1);
    expect(repository.historyCalls, 0);
    expect(_ticketTile('current_inline', '111111'), findsOneWidget);

    await tester.tap(find.text('งวดย้อนหลัง'));
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.uri.path, '/tickets');
    expect(repository.historyCalls, 1);
    expect(find.text('Ticket history'), findsNothing);
    expect(
      _ticketTile('history_inline', '990000', history: true),
      findsOneWidget,
    );
    expect(_ticketTile('current_inline', '111111'), findsNothing);

    await tester.tap(find.text('งวดปัจจุบัน'));
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.uri.path, '/tickets');
    expect(_ticketTile('current_inline', '111111'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('short current ticket list stays top-aligned in content sheet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(399, 849);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _TicketCurrentRepository([
      _ticket('current_short_1', '146008'),
      _ticket('current_short_2', '921594'),
    ]);

    await _pumpCurrent(tester, repository);
    await tester.pumpAndSettle();

    final sheet = tester.getRect(
      find.byKey(const ValueKey('ticket-content-sheet')),
    );
    final summary = tester.getRect(find.text('สลากฯ งวดวันที่'));

    expect(summary.top - sheet.top, closeTo(18, 1));
    expect(find.text('ทั้งหมด 2 ใบ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tickets keep the blue header fixed while ticket rows scroll', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(399, 849);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _TicketCurrentRepository([
      for (var index = 0; index < 8; index++)
        _ticket('current_fixed_$index', '14600$index'),
    ]);

    await _pumpCurrent(tester, repository);
    await tester.pumpAndSettle();

    final headerFinder = find.byKey(const ValueKey('ticket-fixed-header'));
    final sheetFinder = find.byKey(const ValueKey('ticket-content-sheet'));
    final initialHeaderRect = tester.getRect(headerFinder);
    final initialSheetTop = tester.getTopLeft(sheetFinder).dy;

    await tester.drag(
      find.byKey(const ValueKey('ticket-content-scroll')),
      const Offset(0, -260),
    );
    await tester.pumpAndSettle();

    expect(tester.getRect(headerFinder), initialHeaderRect);
    expect(
      find.descendant(of: headerFinder, matching: find.text('สลากฯ ของฉัน')),
      findsOneWidget,
    );
    expect(tester.getTopLeft(sheetFinder).dy, lessThan(initialSheetTop));
    expect(tester.takeException(), isNull);
  });

  testWidgets('current ticket stub keeps Nuxt layout at narrow width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _TicketCurrentRepository([
      _ticket('current_narrow', '123456'),
    ]);

    await _pumpCurrent(tester, repository);
    await tester.pumpAndSettle();

    expect(_ticketTile('current_narrow', '123456'), findsOneWidget);
    expect(find.text('งวดที่'), findsNothing);
    expect(find.text('ชุดที่'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('current ticket stub opens claim flow directly like Nuxt', (
    tester,
  ) async {
    final repository = _TicketCurrentRepository([
      _ticket(
        'current_claimable',
        '740000',
        prizeAmount: 2000,
        claimable: true,
        rewardStatus: const TicketRewardStatus(
          status: 'winning',
          claimStatus: '',
          claimable: true,
          prizeType: 'back2',
          prizeNumber: '00',
          prizeAmount: 2000,
          prizes: [],
          rewardClaimId: null,
          payoutMethod: '',
          adminNote: '',
        ),
      ),
    ]);

    await _pumpCurrent(tester, repository);
    await tester.pumpAndSettle();

    expect(find.text('ขึ้นรางวัล'), findsOneWidget);
    expect(find.text('Ticket detail'), findsNothing);

    tester
        .widget<InkWell>(
          find.ancestor(
            of: find.text('ขึ้นรางวัล'),
            matching: find.byType(InkWell),
          ),
        )
        .onTap!();
    await tester.pumpAndSettle();

    expect(
      find.text('Ticket claim: current_claimable from current'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('current ticket row opens image overlay directly like Nuxt', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _TicketCurrentRepository([
      _ticket('current_preview', '740000', imageStatus: 'pending_assets'),
    ]);

    await _pumpCurrent(tester, repository);
    await tester.pumpAndSettle();

    expect(find.text('Ticket detail'), findsNothing);

    await tester.tap(_ticketTile('current_preview', '740000'));
    await tester.pumpAndSettle();

    expect(find.text('Customer'), findsOneWidget);
    expect(tester.getSize(find.byType(Dialog)).width, greaterThan(350));
    expect(
      find.text('สลากดิจิทัลนี้จัดเก็บใน Customer สำหรับ L6'),
      findsOneWidget,
    );
    expect(find.text('Ticket detail'), findsNothing);

    await tester.tap(find.byTooltip('ปิดรูปสลากฯ'));
    await tester.pumpAndSettle();

    expect(find.text('Customer'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('current ticket stub opens existing reward claim directly', (
    tester,
  ) async {
    final repository = _TicketCurrentRepository([
      _ticket(
        'current_claimed',
        '880000',
        prizeAmount: 2000,
        rewardClaimId: 'claim_current_existing',
        rewardStatus: const TicketRewardStatus(
          status: 'submitted',
          claimStatus: 'submitted',
          claimable: false,
          prizeType: 'back2',
          prizeNumber: '00',
          prizeAmount: 2000,
          prizes: [],
          rewardClaimId: 'claim_current_existing',
          payoutMethod: 'wallet_credit',
          adminNote: '',
        ),
      ),
    ]);

    await _pumpCurrent(tester, repository);
    await tester.pumpAndSettle();

    expect(find.text('ดูรางวัล'), findsOneWidget);

    tester
        .widget<InkWell>(
          find.ancestor(
            of: find.text('ดูรางวัล'),
            matching: find.byType(InkWell),
          ),
        )
        .onTap!();
    await tester.pumpAndSettle();

    expect(
      find.text('Reward claim detail: claim_current_existing'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('current tickets API error uses server copy like Nuxt', (
    tester,
  ) async {
    final repository = _FailingTicketCurrentRepository(
      _apiException('/customer/tickets', 'ไม่สามารถโหลดสลากงวดนี้ได้'),
    );

    await _pumpCurrent(tester, repository);
    await tester.pumpAndSettle();

    expect(repository.currentAllCalls, 1);
    expect(find.text('ไม่สามารถโหลดสลากงวดนี้ได้'), findsOneWidget);
    expect(find.text('ยังไม่มีสลากในงวดนี้'), findsNothing);
    expect(find.text('โหลดสลากฯ ไม่สำเร็จ'), findsNothing);
  });

  testWidgets('current tickets internal error falls back to localized copy', (
    tester,
  ) async {
    final repository = _FailingTicketCurrentRepository(
      StateError('internal ticket load failed'),
    );

    await _pumpCurrent(tester, repository);
    await tester.pumpAndSettle();

    expect(find.text('โหลดสลากฯ ไม่สำเร็จ'), findsOneWidget);
    expect(find.textContaining('internal ticket load failed'), findsNothing);
  });

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
    expect(find.text('สลากงวดย้อนหลัง'), findsNothing);
    expect(
      find.text('แสดงเฉพาะงวดที่ออกผลแล้วและมีงวดใหม่กว่าแล้ว'),
      findsNothing,
    );
    expect(_ticketTile('history_0', '740000', history: true), findsOneWidget);
    expect(_ticketTile('history_2', '880000', history: true), findsNothing);

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -1800));
    await tester.pumpAndSettle();

    expect(repository.historyCalls, 2);
    expect(repository.cursors, [null, 'cursor_2']);
    expect(_ticketTile('history_2', '880000', history: true), findsOneWidget);
    expect(find.text('โหลดเพิ่มเติม'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ticket history groups rows by draw and auto-loads like Nuxt', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _TicketHistoryStaticRepository(
      [
        _ticket(
          'history_may_1',
          '740000',
          gameId: 'game_may',
          gameName: 'งวด 16 พ.ค. 2569',
          drawAt: '2026-05-16T17:00:00+07:00',
        ),
        _ticket(
          'history_may_2',
          '740001',
          gameId: 'game_may',
          gameName: 'งวด 16 พ.ค. 2569',
          drawAt: '2026-05-16T17:00:00+07:00',
        ),
        _ticket(
          'history_june_1',
          '880000',
          gameId: 'game_june',
          gameName: 'งวด 1 มิ.ย. 2569',
          drawAt: '2026-06-01T17:00:00+07:00',
        ),
      ],
      hasMore: true,
      nextCursor: 'cursor_2',
    );

    await _pumpHistory(tester, repository);
    await tester.pumpAndSettle();

    expect(repository.historyCalls, 1);
    expect(
      find.byKey(const ValueKey('ticket-history-group-game_may')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('ticket-history-group-game_june')),
      findsOneWidget,
    );
    expect(find.text('งวดวันที่'), findsNWidgets(2));
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('ticket-history-group-date-game_may')),
          )
          .data,
      contains('16 พ.ค.'),
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('ticket-history-group-date-game_june')),
          )
          .data,
      contains('1 มิ.ย.'),
    );
    expect(find.text('โหลดเพิ่มเติม'), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
    expect(find.byIcon(Icons.expand_more), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ticket history API error uses server copy like Nuxt', (
    tester,
  ) async {
    final repository = _FailingTicketHistoryRepository(
      _apiException(
        '/customer/tickets/history',
        'ไม่สามารถโหลดสลากย้อนหลังได้',
      ),
    );

    await _pumpHistory(tester, repository);
    await tester.pumpAndSettle();

    expect(find.text('ไม่สามารถโหลดสลากย้อนหลังได้'), findsOneWidget);
    expect(find.text('โหลดประวัติสลากไม่สำเร็จ'), findsNothing);
    expect(find.text('ยังไม่มีสลากย้อนหลัง'), findsNothing);
  });

  testWidgets('ticket history load more API error uses server copy like Nuxt', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 620);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _TicketHistoryRepository(
      loadMoreError: _apiException(
        '/customer/tickets/history',
        'โหลดหน้าถัดไปจากระบบไม่สำเร็จ',
      ),
    );

    await _pumpHistory(tester, repository);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -1800));
    await tester.pumpAndSettle();

    expect(repository.historyCalls, 2);
    expect(find.text('โหลดหน้าถัดไปจากระบบไม่สำเร็จ'), findsOneWidget);
    expect(find.text('โหลดรายการเพิ่มเติมไม่สำเร็จ'), findsNothing);
  });

  testWidgets('ticket history filters winning tickets like Nuxt', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _TicketHistoryFilterRepository([
      _ticket(
        'history_win',
        '740000',
        count: 2,
        prizeAmount: 2000,
        rewardStatus: const TicketRewardStatus(
          status: 'winning',
          claimStatus: '',
          claimable: true,
          prizeType: 'back3',
          prizeNumber: '000',
          prizeAmount: 2000,
          prizes: [],
          rewardClaimId: null,
          payoutMethod: '',
          adminNote: '',
        ),
      ),
      _ticket('history_lost', '880000'),
    ]);

    await _pumpHistory(tester, repository);
    await tester.pumpAndSettle();

    expect(find.text('รายการสลากฯ'), findsOneWidget);
    expect(find.text('ดูสลากฯ ที่ถูกรางวัล'), findsOneWidget);
    expect(find.text('ยินดีด้วย คุณมีสลากฯ ถูกรางวัล 2 ใบ'), findsOneWidget);
    expect(find.text('2 รายการ'), findsOneWidget);
    expect(_ticketTile('history_win', '740000', history: true), findsOneWidget);
    expect(
      _ticketTile('history_lost', '880000', history: true),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(TextButton, 'ดูสลากฯ ที่ถูกรางวัล'));
    await tester.pumpAndSettle();

    expect(find.text('ดูสลากฯ ทั้งหมด'), findsOneWidget);
    expect(_ticketTile('history_win', '740000', history: true), findsOneWidget);
    expect(_ticketTile('history_lost', '880000', history: true), findsNothing);
    expect(repository.historyCalls, 1);
    expect(tester.takeException(), isNull);

    await tester.tap(find.widgetWithText(TextButton, 'ดูสลากฯ ทั้งหมด'));
    await tester.pumpAndSettle();

    expect(
      _ticketTile('history_lost', '880000', history: true),
      findsOneWidget,
    );
  });

  testWidgets(
    'ticket view resolves current ticket from Nuxt query parameters',
    (tester) async {
      final repository = _TicketViewRepository(
        currentTickets: [
          _ticket(
            'current_1',
            '740000',
            gameId: 'game_current',
            orderId: 'order_1',
          ),
          _ticket(
            'current_2',
            '880000',
            gameId: 'game_current',
            orderId: 'order_2',
          ),
        ],
      );

      await _pumpTicketView(
        tester,
        repository,
        '/tickets/view?number=740000&order_id=order_1&game_id=game_current',
      );
      await tester.pumpAndSettle();

      expect(repository.currentAllCalls, 1);
      expect(repository.detailCalls, 0);
      expect(find.text('740000', skipOffstage: false), findsWidgets);
      expect(find.text('880000', skipOffstage: false), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('ticket view resolves history ticket with game id query', (
    tester,
  ) async {
    final repository = _TicketViewRepository(
      historyTickets: [
        _ticket(
          'history_1',
          '880000',
          gameId: 'game_previous',
          orderId: 'order_8',
        ),
      ],
    );

    await _pumpTicketView(
      tester,
      repository,
      '/tickets/view?from=history&number=880000&game_id=game_previous',
    );
    await tester.pumpAndSettle();

    expect(repository.historyCalls, 1);
    expect(repository.historyGameIds, ['game_previous']);
    expect(repository.detailCalls, 0);
    expect(find.text('880000', skipOffstage: false), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ticket view opens Nuxt-style generated image preview', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _TicketViewRepository(
      currentTickets: [
        _ticket(
          'current_1',
          '740000',
          gameId: 'game_current',
          orderId: 'order_1',
          imageStatus: 'pending_assets',
        ),
      ],
    );

    await _pumpTicketView(
      tester,
      repository,
      '/tickets/view?number=740000&order_id=order_1&game_id=game_current',
    );
    await tester.pumpAndSettle();

    _expectTicketDetailImagePreview();

    expect(
      find.text('รูปสลากกำลังเตรียมพร้อม', skipOffstage: false),
      findsOneWidget,
    );
    expect(find.text('ขายแล้ว', skipOffstage: false), findsWidgets);

    _expectTicketDetailImagePreview();

    tester
        .widget<InkWell>(
          find.descendant(
            of: find.byTooltip('ดูรูปสลากฯ', skipOffstage: false),
            matching: find.byType(InkWell, skipOffstage: false),
            skipOffstage: false,
          ),
        )
        .onTap!();
    await tester.pumpAndSettle();

    expect(find.text('GLO'), findsWidgets);
    expect(find.text('L6'), findsWidgets);
    expect(find.text('แบบดิจิทัล'), findsWidgets);
    expect(find.text('Customer'), findsOneWidget);
    expect(tester.getSize(find.byType(Dialog)).width, greaterThan(350));
    expect(
      find.text('สลากดิจิทัลนี้จัดเก็บใน Customer สำหรับ L6'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('ปิดรูปสลากฯ'));
    await tester.pumpAndSettle();

    expect(find.text('Customer'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ticket view shows backend image error while failed', (
    tester,
  ) async {
    final repository = _TicketViewRepository(
      currentTickets: [
        _ticket(
          'current_failed_image',
          '740000',
          gameId: 'game_current',
          orderId: 'order_1',
          imageUrl: 'https://cdn.example.test/tickets/740000.png',
          imageStatus: 'failed',
          imageError: 'ภาพสลากยังไม่พร้อมจากระบบ',
        ),
      ],
    );

    await _pumpTicketView(
      tester,
      repository,
      '/tickets/view?number=740000&order_id=order_1&game_id=game_current',
    );
    await tester.pumpAndSettle();

    expect(
      find.text('ภาพสลากยังไม่พร้อมจากระบบ', skipOffstage: false),
      findsOneWidget,
    );
    expect(find.byType(Image), findsNothing);

    tester
        .widget<InkWell>(
          find.descendant(
            of: find.byTooltip('ดูรูปสลากฯ', skipOffstage: false),
            matching: find.byType(InkWell, skipOffstage: false),
            skipOffstage: false,
          ),
        )
        .onTap!();
    await tester.pumpAndSettle();

    expect(
      find.text('ภาพสลากยังไม่พร้อมจากระบบ', skipOffstage: false),
      findsNWidgets(2),
    );
    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ticket claim loading uses Nuxt reward loading copy', (
    tester,
  ) async {
    final detailCompleter = Completer<CustomerTicket>();
    final repository = _PendingTicketClaimRepository(detailCompleter.future);

    await _pumpTicketClaim(
      tester,
      repository,
      initialLocation: '/tickets/claim/ticket_loading',
    );
    await tester.pump();

    expect(find.text('กำลังโหลดข้อมูลรางวัล...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(Card), findsNothing);

    detailCompleter.complete(_ticket('ticket_loading', '123456'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('ticket claim load API error uses server copy like Nuxt', (
    tester,
  ) async {
    final repository = _TicketClaimRepository(
      ticket: _ticket('ticket_error', '123456'),
      status: const TicketRewardStatus(
        status: 'non_winning',
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
      detailError: _apiException(
        '/customer/tickets/ticket_error',
        'โหลดข้อมูลขึ้นเงินจากระบบไม่สำเร็จ',
      ),
    );

    await _pumpTicketClaim(
      tester,
      repository,
      initialLocation: '/tickets/claim/ticket_error',
    );
    await tester.pumpAndSettle();

    expect(find.text('โหลดข้อมูลขึ้นเงินจากระบบไม่สำเร็จ'), findsOneWidget);
    expect(find.text('โหลดข้อมูลขึ้นเงินไม่สำเร็จ'), findsNothing);
  });

  testWidgets('ticket claim shows unavailable reward status message', (
    tester,
  ) async {
    final repository = _TicketClaimRepository(
      ticket: _ticket('ticket_lost', '123456'),
      status: const TicketRewardStatus(
        status: 'non_winning',
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
    );

    await _pumpTicketClaim(tester, repository);
    await tester.pumpAndSettle();

    expect(find.text('สลากใบนี้ไม่ถูกรางวัลในงวดนี้'), findsOneWidget);
    expect(find.text('123456'), findsOneWidget);

    final nextButton = tester.widget<CustomerGradientButton>(
      find.widgetWithText(CustomerGradientButton, 'ถัดไป'),
    );

    expect(nextButton.onPressed, isNull);
    expect(find.text('ยืนยัน'), findsNothing);
    expect(repository.createRewardClaimCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ticket claim with existing reward claim opens claim detail', (
    tester,
  ) async {
    final repository = _TicketClaimRepository(
      ticket: _ticket('ticket_claimed', '123456'),
      status: const TicketRewardStatus(
        status: 'winning',
        claimStatus: 'submitted',
        claimable: false,
        prizeType: 'back3',
        prizeNumber: '456',
        prizeAmount: 2000,
        prizes: [],
        rewardClaimId: 'claim_existing',
        payoutMethod: 'wallet_credit',
        adminNote: '',
      ),
    );

    await _pumpTicketClaim(
      tester,
      repository,
      initialLocation: '/tickets/claim/ticket_claimed',
    );
    await tester.pumpAndSettle();

    expect(find.text('มีรายการขึ้นเงินแล้ว'), findsOneWidget);
    expect(
      find.text('ติดตามสถานะรายการนี้ได้จากหน้ารายละเอียด'),
      findsOneWidget,
    );
    expect(find.text('ถัดไป'), findsNothing);
    expect(repository.createRewardClaimCalls, 0);

    await tester.tap(find.text('ดูรายการขึ้นเงิน'));
    await tester.pumpAndSettle();

    expect(find.text('Reward claim detail: claim_existing'), findsOneWidget);
    expect(repository.createRewardClaimCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ticket claim confirm shows waived tax and fee rows', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _TicketClaimRepository(
      ticket: _ticket('ticket_win', '654321'),
      status: const TicketRewardStatus(
        status: 'winning',
        claimStatus: '',
        claimable: true,
        prizeType: 'back3',
        prizeNumber: '321',
        prizeAmount: 2000,
        prizes: [],
        rewardClaimId: null,
        payoutMethod: '',
        adminNote: '',
      ),
    );

    await _pumpTicketClaim(
      tester,
      repository,
      initialLocation: '/tickets/claim/ticket_win',
    );
    await tester.pumpAndSettle();

    final nextButton = tester.widget<CustomerGradientButton>(
      find.widgetWithText(CustomerGradientButton, 'ถัดไป'),
    );
    nextButton.onPressed!();
    await tester.pumpAndSettle();

    expect(find.text('ค่าภาษีถอนเงิน (0.5%)'), findsOneWidget);
    expect(find.text('10 บาท'), findsOneWidget);
    expect(find.text('ลดให้ 10 บาท'), findsOneWidget);
    expect(find.text('ค่าธรรมเนียม (1%)'), findsOneWidget);
    expect(find.text('20 บาท'), findsOneWidget);
    expect(find.text('ลดให้ 20 บาท'), findsOneWidget);
    expect(find.text('0 บาท'), findsNWidgets(2));
    expect(find.text('ยอดเงินที่ได้รับ'), findsOneWidget);
    expect(repository.createRewardClaimCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ticket claim bank payout matches Nuxt labels and payload', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _TicketClaimRepository(
      ticket: _ticket('ticket_bank', '112233'),
      status: const TicketRewardStatus(
        status: 'winning',
        claimStatus: '',
        claimable: true,
        prizeType: 'back3',
        prizeNumber: '233',
        prizeAmount: 3000,
        prizes: [],
        rewardClaimId: null,
        payoutMethod: '',
        adminNote: '',
      ),
    );

    await _pumpTicketClaim(
      tester,
      repository,
      initialLocation: '/tickets/claim/ticket_bank',
      profileRepository: _TicketClaimProfileRepository(
        bankAccount: const RewardBankAccount(
          bankName: 'ธนาคารกสิกรไทย',
          accountName: 'ผู้ใช้งาน',
          accountNumber: '1234567890',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('บัญชีกสิกรไทย x 7890'), findsOneWidget);
    tester
        .widget<InkWell>(
          find.ancestor(
            of: find.text('บัญชีกสิกรไทย x 7890'),
            matching: find.byType(InkWell),
          ),
        )
        .onTap!();
    await tester.pumpAndSettle();

    tester
        .widget<CustomerGradientButton>(
          find.widgetWithText(CustomerGradientButton, 'ถัดไป'),
        )
        .onPressed!();
    await tester.pumpAndSettle();

    expect(find.text('ธนาคารกสิกรไทย'), findsOneWidget);
    expect(find.text('หมายเลขบัญชี x xxx7890'), findsOneWidget);

    tester
        .widget<CustomerGradientButton>(
          find.widgetWithText(CustomerGradientButton, 'ยืนยัน'),
        )
        .onPressed!();
    await tester.pumpAndSettle();

    for (final digit in ['1', '2', '3', '4', '5', '6']) {
      await tester.tap(find.widgetWithText(TextButton, digit));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(repository.createRewardClaimCalls, 1);
    expect(repository.createdPayoutMethods, ['bank_transfer']);
    expect(repository.createdBankAccounts.single, {
      'bank_name': 'ธนาคารกสิกรไทย',
      'account_name': 'ผู้ใช้งาน',
      'account_number': '1234567890',
    });
    expect(find.text('กำลังดำเนินการโอนเงินรางวัล'), findsOneWidget);
    expect(find.text('ธนาคารกสิกรไทย'), findsOneWidget);
    expect(find.text('หมายเลขบัญชี x xxx7890'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ticket claim wallet payout uses runtime wallet suffix', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _TicketClaimRepository(
      ticket: _ticket('ticket_wallet', '445566'),
      status: const TicketRewardStatus(
        status: 'winning',
        claimStatus: '',
        claimable: true,
        prizeType: 'back3',
        prizeNumber: '566',
        prizeAmount: 4000,
        prizes: [],
        rewardClaimId: null,
        payoutMethod: '',
        adminNote: '',
      ),
    );

    await _pumpTicketClaim(
      tester,
      repository,
      initialLocation: '/tickets/claim/ticket_wallet',
      profileRepository: _TicketClaimProfileRepository(
        walletId: 'wallet_987654321',
        walletName: 'Runtime Blue Wallet',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Runtime Blue Wallet x 321'), findsOneWidget);

    tester
        .widget<CustomerGradientButton>(
          find.widgetWithText(CustomerGradientButton, 'ถัดไป'),
        )
        .onPressed!();
    await tester.pumpAndSettle();

    expect(find.text('Runtime Blue Wallet x 321'), findsOneWidget);

    tester
        .widget<CustomerGradientButton>(
          find.widgetWithText(CustomerGradientButton, 'ยืนยัน'),
        )
        .onPressed!();
    await tester.pumpAndSettle();

    for (final digit in ['1', '2', '3', '4', '5', '6']) {
      await tester.tap(find.widgetWithText(TextButton, digit));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(repository.createRewardClaimCalls, 1);
    expect(repository.createdPayoutMethods, ['wallet_credit']);
    expect(find.text('Runtime Blue Wallet x 321'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ticket claim submits PIN and transitions to processing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _TicketClaimRepository(
      ticket: _ticket('ticket_pin', '456789'),
      status: const TicketRewardStatus(
        status: 'winning',
        claimStatus: '',
        claimable: true,
        prizeType: 'back3',
        prizeNumber: '789',
        prizeAmount: 1000,
        prizes: [],
        rewardClaimId: null,
        payoutMethod: '',
        adminNote: '',
      ),
    );

    await _pumpTicketClaim(
      tester,
      repository,
      initialLocation: '/tickets/claim/ticket_pin',
    );
    await tester.pumpAndSettle();

    tester
        .widget<CustomerGradientButton>(
          find.widgetWithText(CustomerGradientButton, 'ถัดไป'),
        )
        .onPressed!();
    await tester.pumpAndSettle();

    tester
        .widget<CustomerGradientButton>(
          find.widgetWithText(CustomerGradientButton, 'ยืนยัน'),
        )
        .onPressed!();
    await tester.pumpAndSettle();

    for (final digit in ['1', '2', '3', '4', '5', '6']) {
      await tester.tap(find.widgetWithText(TextButton, digit));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(repository.createRewardClaimCalls, 1);
    expect(find.text('กำลังดำเนินการโอนเงินรางวัล'), findsOneWidget);
    expect(find.text('L6'), findsOneWidget);
    expect(find.text('สลากกินแบ่งรัฐบาล'), findsWidgets);
    expect(find.text('วิธีขึ้นเงินรางวัล'), findsOneWidget);
    expect(find.text('ขึ้นเงินรางวัลด้วยตนเอง'), findsOneWidget);
    expect(find.text('สลากฯ งวดวันที่'), findsOneWidget);
    expect(find.text('456789'), findsOneWidget);
    expect(find.text('งวดที่'), findsOneWidget);
    expect(find.text('16'), findsOneWidget);
    expect(find.text('ชุดที่'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
    expect(find.text('รางวัลเลขท้าย 3 ตัว 1,000 บาท'), findsOneWidget);
    expect(find.text('ยอดเงินที่ได้รับ'), findsOneWidget);
    expect(find.text('วันที่ทำรายการ'), findsOneWidget);
    expect(find.text('5 บาท'), findsOneWidget);
    expect(find.text('ลดให้ 5 บาท'), findsOneWidget);
    expect(find.text('10 บาท'), findsOneWidget);
    expect(find.text('ลดให้ 10 บาท'), findsOneWidget);
    expect(find.text('0 บาท'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('ticket claim submit API error uses server copy like Nuxt', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _TicketClaimRepository(
      ticket: _ticket('ticket_submit_error', '456789'),
      status: const TicketRewardStatus(
        status: 'winning',
        claimStatus: '',
        claimable: true,
        prizeType: 'back3',
        prizeNumber: '789',
        prizeAmount: 1000,
        prizes: [],
        rewardClaimId: null,
        payoutMethod: '',
        adminNote: '',
      ),
      createError: _apiException(
        '/customer/reward-claims',
        'ไม่สามารถส่งรายการขึ้นเงินจากระบบได้',
      ),
    );

    await _pumpTicketClaim(
      tester,
      repository,
      initialLocation: '/tickets/claim/ticket_submit_error',
    );
    await tester.pumpAndSettle();

    tester
        .widget<CustomerGradientButton>(
          find.widgetWithText(CustomerGradientButton, 'ถัดไป'),
        )
        .onPressed!();
    await tester.pumpAndSettle();

    tester
        .widget<CustomerGradientButton>(
          find.widgetWithText(CustomerGradientButton, 'ยืนยัน'),
        )
        .onPressed!();
    await tester.pumpAndSettle();

    for (final digit in ['1', '2', '3', '4', '5', '6']) {
      await tester.tap(find.widgetWithText(TextButton, digit));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(repository.createRewardClaimCalls, 1);
    expect(find.text('ไม่สามารถส่งรายการขึ้นเงินจากระบบได้'), findsOneWidget);
    expect(find.text('ส่งรายการไม่สำเร็จ กรุณาลองใหม่'), findsNothing);
    expect(find.text('กำลังดำเนินการโอนเงินรางวัล'), findsNothing);
  });

  testWidgets('ticket claim conflict reloads existing claim like Nuxt', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _TicketClaimRepository(
      ticket: _ticket('ticket_conflict', '456789'),
      status: const TicketRewardStatus(
        status: 'winning',
        claimStatus: '',
        claimable: true,
        prizeType: 'back3',
        prizeNumber: '789',
        prizeAmount: 1000,
        prizes: [],
        rewardClaimId: null,
        payoutMethod: '',
        adminNote: '',
      ),
      createError: _apiException(
        '/customer/reward-claims',
        'รายการนี้อาจถูกส่งขึ้นเงินไว้แล้ว',
        statusCode: 409,
        code: 'resource_conflict',
      ),
      statusAfterCreateError: const TicketRewardStatus(
        status: 'winning',
        claimStatus: 'submitted',
        claimable: false,
        prizeType: 'back3',
        prizeNumber: '789',
        prizeAmount: 1000,
        prizes: [],
        rewardClaimId: 'claim_after_conflict',
        payoutMethod: 'wallet_credit',
        adminNote: '',
      ),
    );

    await _pumpTicketClaim(
      tester,
      repository,
      initialLocation: '/tickets/claim/ticket_conflict',
    );
    await tester.pumpAndSettle();

    tester
        .widget<CustomerGradientButton>(
          find.widgetWithText(CustomerGradientButton, 'ถัดไป'),
        )
        .onPressed!();
    await tester.pumpAndSettle();

    tester
        .widget<CustomerGradientButton>(
          find.widgetWithText(CustomerGradientButton, 'ยืนยัน'),
        )
        .onPressed!();
    await tester.pumpAndSettle();

    for (final digit in ['1', '2', '3', '4', '5', '6']) {
      await tester.tap(find.widgetWithText(TextButton, digit));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(repository.createRewardClaimCalls, 1);
    expect(find.text('ใส่รหัส PIN 6 หลัก'), findsNothing);
    expect(
      find.text('รายการนี้ถูกดำเนินการแล้ว กรุณารีเฟรชสถานะ'),
      findsOneWidget,
    );
    expect(find.text('มีรายการขึ้นเงินแล้ว'), findsOneWidget);
    expect(
      find.text('ติดตามสถานะรายการนี้ได้จากหน้ารายละเอียด'),
      findsOneWidget,
    );

    await tester.tap(find.text('ดูรายการขึ้นเงิน'));
    await tester.pumpAndSettle();

    expect(
      find.text('Reward claim detail: claim_after_conflict'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('ticket claim submits biometric assertion token', (tester) async {
    tester.view.physicalSize = const Size(390, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _TicketClaimRepository(
      ticket: _ticket('ticket_biometric', '456780'),
      status: const TicketRewardStatus(
        status: 'winning',
        claimStatus: '',
        claimable: true,
        prizeType: 'back3',
        prizeNumber: '780',
        prizeAmount: 1000,
        prizes: [],
        rewardClaimId: null,
        payoutMethod: '',
        adminNote: '',
      ),
    );
    final biometric = _FakeBiometricAuthService('assertion_reward_1');

    await _pumpTicketClaim(
      tester,
      repository,
      initialLocation: '/tickets/claim/ticket_biometric',
      platformKey: 'ios',
      biometricEnabled: true,
      biometricAuth: biometric,
    );
    await tester.pumpAndSettle();

    tester
        .widget<CustomerGradientButton>(
          find.widgetWithText(CustomerGradientButton, 'ถัดไป'),
        )
        .onPressed!();
    await tester.pumpAndSettle();

    tester
        .widget<CustomerGradientButton>(
          find.widgetWithText(CustomerGradientButton, 'ยืนยัน'),
        )
        .onPressed!();
    await tester.pumpAndSettle();

    expect(find.text('ใช้ Face ID / Biometric'), findsOneWidget);

    await tester.tap(find.text('ใช้ Face ID / Biometric'));
    await tester.pumpAndSettle();

    expect(biometric.calls, 1);
    expect(biometric.purposes, ['reward_claim']);
    expect(repository.createRewardClaimCalls, 1);
    expect(repository.createdTicketIds, ['ticket_biometric']);
    expect(repository.createdPayoutMethods, ['wallet_credit']);
    expect(repository.createdPins, ['']);
    expect(repository.createdAssertionTokens, ['assertion_reward_1']);
    expect(find.text('กำลังดำเนินการโอนเงินรางวัล'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpCurrent(
  WidgetTester tester,
  _TicketCurrentRepository repository, {
  CurrentGame? currentGame,
}) {
  final router = GoRouter(
    initialLocation: '/tickets',
    routes: [
      GoRoute(
        path: '/tickets',
        builder: (context, state) => const TicketsScreen(),
      ),
      GoRoute(
        path: '/tickets/search',
        builder: (context, state) =>
            TicketsSearchScreen(query: state.uri.queryParameters),
      ),
      GoRoute(
        path: '/tickets/history',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Ticket history'))),
      ),
      GoRoute(
        path: '/tickets/view',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Ticket detail'))),
      ),
      GoRoute(
        path: '/tickets/claim/:ticketId',
        builder: (context, state) => Scaffold(
          body: Center(
            child: Text(
              'Ticket claim: ${state.pathParameters['ticketId']} '
              'from ${state.uri.queryParameters['from']}',
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/reward-claims/:claimId',
        builder: (context, state) => Scaffold(
          body: Center(
            child: Text(
              'Reward claim detail: ${state.pathParameters['claimId']}',
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/buy',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Buy'))),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Home'))),
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
        mobileBootstrapProvider.overrideWith(
          (_) async => _ticketMobileBootstrap(),
        ),
        ticketRepositoryProvider.overrideWithValue(repository),
        currentTicketsProvider.overrideWith((_) => repository.currentAll()),
        currentTicketGameProvider.overrideWith(
          (_) async => currentGame ?? _currentTicketGame(),
        ),
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

Future<void> _pumpHistory(WidgetTester tester, TicketRepository repository) {
  final router = GoRouter(
    initialLocation: '/tickets/history',
    routes: [
      GoRoute(
        path: '/tickets/history',
        builder: (context, state) => const TicketHistoryScreen(),
      ),
      GoRoute(
        path: '/tickets',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Current tickets'))),
      ),
      GoRoute(
        path: '/tickets/view',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Ticket detail'))),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Home'))),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Profile'))),
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
        mobileBootstrapProvider.overrideWith(
          (_) async => _ticketMobileBootstrap(),
        ),
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

Future<void> _pumpTicketView(
  WidgetTester tester,
  _TicketViewRepository repository,
  String initialLocation,
) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/tickets/view',
        builder: (context, state) => TicketViewScreen(
          ticketId:
              state.uri.queryParameters['id'] ??
              state.uri.queryParameters['ticket_id'] ??
              '',
          ticketNumber: state.uri.queryParameters['number'] ?? '',
          orderId: state.uri.queryParameters['order_id'] ?? '',
          gameId: state.uri.queryParameters['game_id'] ?? '',
          fromHistory: state.uri.queryParameters['from'] == 'history',
        ),
      ),
      GoRoute(
        path: '/tickets',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Current tickets'))),
      ),
      GoRoute(
        path: '/tickets/history',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Ticket history'))),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Home'))),
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
        ticketRepositoryProvider.overrideWithValue(repository),
        mobileBootstrapProvider.overrideWith(
          (_) async => MobileBootstrap.fromJson(const {
            'site': {'display_name': 'Customer', 'locale': 'th-TH'},
            'mobile': {
              'lottery_product_label': 'L6',
              'ticket_image_watermark': 'GLO',
            },
          }),
        ),
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

void _expectTicketDetailImagePreview() {
  final preview = find.byTooltip('ดูรูปสลากฯ', skipOffstage: false);
  expect(preview, findsOneWidget);
}

Future<void> _pumpTicketClaim(
  WidgetTester tester,
  TicketRepository repository, {
  String initialLocation = '/tickets/claim/ticket_lost',
  String? platformKey,
  bool biometricEnabled = false,
  BiometricAuthService? biometricAuth,
  ProfileSettingsRepository? profileRepository,
}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/tickets/claim/:ticketId',
        builder: (context, state) => TicketClaimScreen(
          ticketId: state.pathParameters['ticketId'] ?? '',
          fromHistory: state.uri.queryParameters['from'] == 'history',
        ),
      ),
      GoRoute(
        path: '/tickets',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Current tickets'))),
      ),
      GoRoute(
        path: '/profile/reward-bank',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Reward bank'))),
      ),
      GoRoute(
        path: '/reward-claims/:claimId',
        builder: (context, state) => Scaffold(
          body: Center(
            child: Text(
              'Reward claim detail: ${state.pathParameters['claimId']}',
            ),
          ),
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
        mobileBootstrapProvider.overrideWith(
          (_) async =>
              _ticketMobileBootstrap(biometricEnabled: biometricEnabled),
        ),
        ticketRepositoryProvider.overrideWithValue(repository),
        profileSettingsRepositoryProvider.overrideWithValue(
          profileRepository ?? _TicketClaimProfileRepository(),
        ),
        if (platformKey != null)
          customerPlatformKeyProvider.overrideWithValue(platformKey),
        if (biometricAuth != null)
          biometricAuthServiceProvider.overrideWithValue(biometricAuth),
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

MobileBootstrap _ticketMobileBootstrap({bool biometricEnabled = false}) {
  final json = <String, dynamic>{
    'site': {'display_name': 'Customer', 'locale': 'th-TH'},
    'mobile': {'lottery_product_label': 'L6'},
  };
  if (biometricEnabled) {
    json['biometric'] = {
      'enabled': true,
      'platforms': {
        'ios': ['face_id'],
      },
    };
    json['feature_flags'] = {'native_biometric_unlock': true};
  }
  return MobileBootstrap.fromJson(json);
}

class _TicketCurrentRepository extends TicketRepository {
  _TicketCurrentRepository(this._tickets) : super(_testApiClient());

  final List<CustomerTicket> _tickets;
  int currentAllCalls = 0;

  @override
  Future<List<CustomerTicket>> currentAll({
    int limit = TicketRepository.defaultPageLimit,
    int maxPages = TicketRepository.maxAutoPages,
  }) async {
    currentAllCalls++;
    return _tickets;
  }
}

class _TicketCurrentWithHistoryRepository extends _TicketCurrentRepository {
  _TicketCurrentWithHistoryRepository({
    required List<CustomerTicket> currentTickets,
    required List<CustomerTicket> historyTickets,
  }) : _historyTickets = historyTickets,
       super(currentTickets);

  final List<CustomerTicket> _historyTickets;
  int historyCalls = 0;

  @override
  Future<TicketPage> history({
    int limit = 20,
    String? cursor,
    String? gameId,
  }) async {
    historyCalls++;
    return TicketPage(
      items: _historyTickets,
      nextCursor: null,
      hasMore: false,
      total: _historyTickets.length,
    );
  }
}

class _FailingTicketCurrentRepository extends _TicketCurrentRepository {
  _FailingTicketCurrentRepository(this.error) : super(const []);

  final Object error;

  @override
  Future<List<CustomerTicket>> currentAll({
    int limit = TicketRepository.defaultPageLimit,
    int maxPages = TicketRepository.maxAutoPages,
  }) async {
    currentAllCalls++;
    throw error;
  }
}

class _TicketHistoryRepository extends TicketRepository {
  _TicketHistoryRepository({this.loadMoreError}) : super(_testApiClient());

  final Object? loadMoreError;

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
      final error = loadMoreError;
      if (error != null) throw error;
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

class _TicketHistoryStaticRepository extends TicketRepository {
  _TicketHistoryStaticRepository(
    this._tickets, {
    this.hasMore = false,
    this.nextCursor,
  }) : super(_testApiClient());

  final List<CustomerTicket> _tickets;
  final bool hasMore;
  final String? nextCursor;
  int historyCalls = 0;

  @override
  Future<TicketPage> history({
    int limit = 20,
    String? cursor,
    String? gameId,
  }) async {
    historyCalls++;

    if (cursor != null && cursor.isNotEmpty) {
      return const TicketPage(
        items: [],
        nextCursor: null,
        hasMore: false,
        total: 0,
      );
    }

    return TicketPage(
      items: _tickets,
      nextCursor: nextCursor,
      hasMore: hasMore,
      total: _tickets.length,
    );
  }
}

class _FailingTicketHistoryRepository extends TicketRepository {
  _FailingTicketHistoryRepository(this.error) : super(_testApiClient());

  final Object error;

  @override
  Future<TicketPage> history({
    int limit = 20,
    String? cursor,
    String? gameId,
  }) async {
    throw error;
  }
}

class _TicketHistoryFilterRepository extends TicketRepository {
  _TicketHistoryFilterRepository(this._tickets) : super(_testApiClient());

  final List<CustomerTicket> _tickets;
  int historyCalls = 0;

  @override
  Future<TicketPage> history({
    int limit = 20,
    String? cursor,
    String? gameId,
  }) async {
    historyCalls++;
    return TicketPage(
      items: _tickets,
      nextCursor: null,
      hasMore: false,
      total: _tickets.length,
    );
  }
}

class _TicketViewRepository extends TicketRepository {
  _TicketViewRepository({
    this.currentTickets = const [],
    this.historyTickets = const [],
  }) : super(_testApiClient());

  final List<CustomerTicket> currentTickets;
  final List<CustomerTicket> historyTickets;
  int currentAllCalls = 0;
  int historyCalls = 0;
  int detailCalls = 0;
  final historyGameIds = <String?>[];

  @override
  Future<List<CustomerTicket>> currentAll({
    int limit = TicketRepository.defaultPageLimit,
    int maxPages = TicketRepository.maxAutoPages,
  }) async {
    currentAllCalls++;
    return currentTickets;
  }

  @override
  Future<TicketPage> history({
    int limit = 20,
    String? cursor,
    String? gameId,
  }) async {
    historyCalls++;
    historyGameIds.add(gameId);
    return TicketPage(
      items: historyTickets,
      nextCursor: null,
      hasMore: false,
      total: historyTickets.length,
    );
  }

  @override
  Future<CustomerTicket> detail(String id) async {
    detailCalls++;
    return [
      ...currentTickets,
      ...historyTickets,
    ].firstWhere((ticket) => ticket.id == id);
  }
}

class _PendingTicketClaimRepository extends TicketRepository {
  _PendingTicketClaimRepository(this._detailFuture) : super(_testApiClient());

  final Future<CustomerTicket> _detailFuture;

  @override
  Future<CustomerTicket> detail(String id) => _detailFuture;

  @override
  Future<TicketRewardStatus> rewardStatus(String id) async {
    return const TicketRewardStatus(
      status: 'non_winning',
      claimStatus: '',
      claimable: false,
      prizeType: '',
      prizeNumber: '',
      prizeAmount: 0,
      prizes: [],
      rewardClaimId: null,
      payoutMethod: '',
      adminNote: '',
    );
  }
}

class _TicketClaimRepository extends TicketRepository {
  _TicketClaimRepository({
    required this.ticket,
    required this.status,
    this.detailError,
    this.createError,
    this.statusAfterCreateError,
  }) : super(_testApiClient());

  final CustomerTicket ticket;
  TicketRewardStatus status;
  final Object? detailError;
  final Object? createError;
  final TicketRewardStatus? statusAfterCreateError;
  int createRewardClaimCalls = 0;
  final createdTicketIds = <String>[];
  final createdPayoutMethods = <String>[];
  final createdPins = <String>[];
  final createdAssertionTokens = <String>[];
  final createdBankAccounts = <Map<String, dynamic>?>[];

  @override
  Future<CustomerTicket> detail(String id) async {
    final error = detailError;
    if (error != null) throw error;
    return ticket;
  }

  @override
  Future<TicketRewardStatus> rewardStatus(String id) async => status;

  @override
  Future<RewardClaimSubmission> createRewardClaim({
    required String ticketId,
    required String payoutMethod,
    String pin = '',
    String pinAssertionToken = '',
    Map<String, dynamic>? bankAccount,
  }) async {
    createRewardClaimCalls++;
    createdTicketIds.add(ticketId);
    createdPayoutMethods.add(payoutMethod);
    createdPins.add(pin);
    createdAssertionTokens.add(pinAssertionToken);
    createdBankAccounts.add(bankAccount);
    final error = createError;
    if (error != null) {
      final nextStatus = statusAfterCreateError;
      if (nextStatus != null) status = nextStatus;
      throw error;
    }
    return const RewardClaimSubmission(
      id: 'claim_1',
      status: 'submitted',
      createdAt: '2026-06-29T10:00:00+07:00',
    );
  }
}

class _TicketClaimProfileRepository extends ProfileSettingsRepository {
  _TicketClaimProfileRepository({
    this.bankAccount,
    this.walletId = '',
    this.walletName = '',
  }) : super(_testApiClient());

  final RewardBankAccount? bankAccount;
  final String walletId;
  final String walletName;

  @override
  Future<CustomerProfileSettings> load() async {
    return CustomerProfileSettings(
      id: 'customer_1',
      name: 'ผู้ใช้งาน',
      customerNo: 'C001',
      phone: '0800000000',
      bankAccount:
          bankAccount ??
          const RewardBankAccount(
            bankName: '',
            accountName: '',
            accountNumber: '',
          ),
      autoReward: AutoRewardSetting(enabled: false, payoutMethod: '', type: ''),
      walletId: walletId,
      walletName: walletName,
    );
  }
}

class _FakeBiometricAuthService extends BiometricAuthService {
  _FakeBiometricAuthService(this.assertionToken) : super(_testApiClient());

  final String assertionToken;
  int calls = 0;
  final purposes = <String>[];

  @override
  Future<String?> requestPinAssertion({
    String purpose = 'pin_unlock',
    required String localizedReason,
  }) async {
    calls++;
    purposes.add(purpose);
    return assertionToken;
  }
}

DioException _apiException(
  String path,
  String message, {
  int statusCode = 422,
  String code = '',
}) {
  final requestOptions = RequestOptions(path: path);
  return DioException(
    requestOptions: requestOptions,
    response: Response<Map<String, dynamic>>(
      requestOptions: requestOptions,
      statusCode: statusCode,
      data: {'message': message, if (code.isNotEmpty) 'code': code},
    ),
  );
}

CustomerTicket _ticket(
  String id,
  String number, {
  String gameId = 'game_previous',
  String orderId = '',
  int count = 1,
  double prizeAmount = 0,
  bool claimable = false,
  String rewardClaimId = '',
  String imageUrl = '',
  String imageThumbUrl = '',
  String previewImageUrl = '',
  String imageStatus = '',
  String imageError = '',
  String drawNumber = '16',
  String setNumber = '42',
  String gameName = 'งวด 16 พ.ค. 2569',
  Object? drawAt,
  TicketRewardStatus rewardStatus = const TicketRewardStatus(
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
}) {
  return CustomerTicket(
    id: id,
    orderId: orderId,
    gameId: gameId,
    gameName: gameName,
    drawAt: drawAt ?? '2026-05-16T17:00:00+07:00',
    drawNumber: drawNumber,
    setNumber: setNumber,
    number: number,
    status: 'paid',
    rewardStatus: rewardStatus,
    count: count,
    prizes: const [],
    prizeAmount: prizeAmount,
    claimable: claimable,
    rewardClaimId: rewardClaimId,
    imageUrl: imageUrl,
    imageThumbUrl: imageThumbUrl,
    previewImageUrl: previewImageUrl,
    imageStatus: imageStatus,
    imageError: imageError,
  );
}

CurrentGame _currentTicketGame() {
  return const CurrentGame(
    id: 'game_previous',
    name: 'งวด 16 พ.ค. 2569',
    status: 'open',
    drawAt: '2026-05-16T17:00:00+07:00',
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
