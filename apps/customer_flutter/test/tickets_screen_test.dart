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
import 'package:customer_flutter/features/tickets/data/ticket_models.dart';
import 'package:customer_flutter/features/tickets/data/ticket_repository.dart';
import 'package:customer_flutter/features/tickets/presentation/tickets_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

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
    expect(find.text('740000'), findsWidgets);
    expect(find.text('880000'), findsOneWidget);
    expect(
      find.text(
        'เมนู ‘สลากฯ ของฉัน’ เป็นการบันทึกเลขสลากฯ หากถูกรางวัล ระบบจะแจ้งผลรางวัลในหน้านี้',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('ค้นหาเลขสลาก'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('ticket-search-input')),
      '740000',
    );
    await tester.tap(find.byKey(const ValueKey('ticket-search-submit')));
    await tester.pumpAndSettle();

    expect(find.text('ผลการค้นหา "740000"'), findsOneWidget);
    expect(find.text('740000'), findsWidgets);
    expect(find.text('880000'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('ticket-search-clear')));
    await tester.pumpAndSettle();

    expect(find.text('880000'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('current tickets API error uses server copy like Nuxt', (
    tester,
  ) async {
    final repository = _FailingTicketCurrentRepository(
      _apiException(
        '/customer/tickets',
        'ไม่สามารถโหลดสลากงวดนี้ได้',
      ),
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
    await tester.drag(find.byType(ListView), const Offset(0, -1800));
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
    expect(find.text('คุณถูกรางวัล 2 ใบ'), findsOneWidget);
    expect(find.text('740000'), findsOneWidget);
    expect(find.text('880000'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'ดูสลากฯ ที่ถูกรางวัล'));
    await tester.pumpAndSettle();

    expect(find.text('ดูสลากฯ ทั้งหมด'), findsOneWidget);
    expect(find.text('740000'), findsOneWidget);
    expect(find.text('880000'), findsNothing);
    expect(repository.historyCalls, 1);
    expect(tester.takeException(), isNull);

    await tester.tap(find.widgetWithText(TextButton, 'ดูสลากฯ ทั้งหมด'));
    await tester.pumpAndSettle();

    expect(find.text('880000'), findsOneWidget);
  });

  testWidgets('ticket view resolves current ticket from Nuxt query parameters',
      (
    tester,
  ) async {
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
    expect(find.text('740000'), findsOneWidget);
    expect(find.text('880000'), findsNothing);
    expect(tester.takeException(), isNull);
  });

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
    expect(find.text('880000'), findsOneWidget);
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

    expect(find.text('รูปสลากกำลังเตรียมพร้อม'), findsOneWidget);
    expect(find.text('ขายแล้ว'), findsWidgets);

    await tester.tap(find.byTooltip('ดูรูปสลากฯ'));
    await tester.pumpAndSettle();

    expect(find.text('GLO'), findsWidgets);
    expect(find.text('L6'), findsWidgets);
    expect(find.text('แบบดิจิทัล'), findsWidgets);
    expect(find.text('Customer'), findsOneWidget);
    expect(
      find.text('สลากดิจิทัลนี้จัดเก็บใน Customer สำหรับ สลากกินแบ่งรัฐบาล'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('ปิดรูปสลากฯ'));
    await tester.pumpAndSettle();

    expect(find.text('Customer'), findsNothing);
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

    final nextButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'ถัดไป'),
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

    await tester.tap(find.text('มีรายการขึ้นเงินแล้ว'));
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

    final nextButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'ถัดไป'),
    );
    nextButton.onPressed!();
    await tester.pumpAndSettle();

    expect(find.text('ค่าภาษีถอนเงิน (0.5%)'), findsOneWidget);
    expect(find.text('ลดให้ 10.00 บาท'), findsOneWidget);
    expect(find.text('ค่าธรรมเนียม (1%)'), findsOneWidget);
    expect(find.text('ลดให้ 20.00 บาท'), findsOneWidget);
    expect(find.text('ยอดเงินที่ได้รับ'), findsOneWidget);
    expect(repository.createRewardClaimCalls, 0);
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
        .widget<FilledButton>(find.widgetWithText(FilledButton, 'ถัดไป'))
        .onPressed!();
    await tester.pumpAndSettle();

    tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, 'ยืนยัน'))
        .onPressed!();
    await tester.pumpAndSettle();

    for (final digit in ['1', '2', '3', '4', '5', '6']) {
      await tester.tap(find.widgetWithText(FilledButton, digit));
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
    expect(find.text('รางวัลเลขท้าย 3 ตัว 1,000.00 บาท'), findsOneWidget);
    expect(find.text('ยอดเงินที่ได้รับ'), findsOneWidget);
    expect(find.text('วันที่ทำรายการ'), findsOneWidget);
    expect(find.text('ลดให้ 5.00 บาท'), findsOneWidget);
    expect(find.text('ลดให้ 10.00 บาท'), findsOneWidget);
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
        .widget<FilledButton>(find.widgetWithText(FilledButton, 'ถัดไป'))
        .onPressed!();
    await tester.pumpAndSettle();

    tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, 'ยืนยัน'))
        .onPressed!();
    await tester.pumpAndSettle();

    for (final digit in ['1', '2', '3', '4', '5', '6']) {
      await tester.tap(find.widgetWithText(FilledButton, digit));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(repository.createRewardClaimCalls, 1);
    expect(find.text('ไม่สามารถส่งรายการขึ้นเงินจากระบบได้'), findsOneWidget);
    expect(find.text('ส่งรายการไม่สำเร็จ กรุณาลองใหม่'), findsNothing);
    expect(find.text('กำลังดำเนินการโอนเงินรางวัล'), findsNothing);
  });

  testWidgets('ticket claim submits biometric assertion token', (
    tester,
  ) async {
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
        .widget<FilledButton>(find.widgetWithText(FilledButton, 'ถัดไป'))
        .onPressed!();
    await tester.pumpAndSettle();

    tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, 'ยืนยัน'))
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
  _TicketCurrentRepository repository,
) {
  final router = GoRouter(
    initialLocation: '/tickets',
    routes: [
      GoRoute(
        path: '/tickets',
        builder: (context, state) => const TicketsScreen(),
      ),
      GoRoute(
        path: '/tickets/history',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Ticket history')),
        ),
      ),
      GoRoute(
        path: '/tickets/view',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Ticket detail')),
        ),
      ),
      GoRoute(
        path: '/buy',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Buy')),
        ),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Home')),
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

Future<void> _pumpHistory(
  WidgetTester tester,
  TicketRepository repository,
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
        appConfigProvider.overrideWithValue(
          const AppConfig(
            apiBaseUrl: 'https://partner.example.test/api/v1',
            defaultLocale: 'th-TH',
          ),
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
          ticketId: state.uri.queryParameters['id'] ??
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
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Current tickets')),
        ),
      ),
      GoRoute(
        path: '/tickets/history',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Ticket history')),
        ),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Home')),
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

Future<void> _pumpTicketClaim(
  WidgetTester tester,
  TicketRepository repository, {
  String initialLocation = '/tickets/claim/ticket_lost',
  String? platformKey,
  bool biometricEnabled = false,
  BiometricAuthService? biometricAuth,
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
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Current tickets')),
        ),
      ),
      GoRoute(
        path: '/profile/reward-bank',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Reward bank')),
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
          (_) async => _ticketMobileBootstrap(
            biometricEnabled: biometricEnabled,
          ),
        ),
        ticketRepositoryProvider.overrideWithValue(repository),
        profileSettingsRepositoryProvider.overrideWithValue(
          _TicketClaimProfileRepository(),
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
    return [...currentTickets, ...historyTickets].firstWhere(
      (ticket) => ticket.id == id,
    );
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
  }) : super(_testApiClient());

  final CustomerTicket ticket;
  final TicketRewardStatus status;
  final Object? detailError;
  final Object? createError;
  int createRewardClaimCalls = 0;
  final createdTicketIds = <String>[];
  final createdPayoutMethods = <String>[];
  final createdPins = <String>[];
  final createdAssertionTokens = <String>[];

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
    final error = createError;
    if (error != null) throw error;
    return const RewardClaimSubmission(
      id: 'claim_1',
      status: 'submitted',
      createdAt: '2026-06-29T10:00:00+07:00',
    );
  }
}

class _TicketClaimProfileRepository extends ProfileSettingsRepository {
  _TicketClaimProfileRepository() : super(_testApiClient());

  @override
  Future<CustomerProfileSettings> load() async {
    return const CustomerProfileSettings(
      id: 'customer_1',
      name: 'ผู้ใช้งาน',
      customerNo: 'C001',
      phone: '0800000000',
      bankAccount: RewardBankAccount(
        bankName: '',
        accountName: '',
        accountNumber: '',
      ),
      autoReward: AutoRewardSetting(
        enabled: false,
        payoutMethod: '',
        type: '',
      ),
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

DioException _apiException(String path, String message) {
  final requestOptions = RequestOptions(path: path);
  return DioException(
    requestOptions: requestOptions,
    response: Response<Map<String, dynamic>>(
      requestOptions: requestOptions,
      statusCode: 422,
      data: {'message': message},
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
    gameName: 'งวด 16 พ.ค. 2569',
    drawAt: '2026-05-16T17:00:00+07:00',
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
