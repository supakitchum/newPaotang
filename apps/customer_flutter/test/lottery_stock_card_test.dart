import 'dart:async';

import 'package:customer_flutter/core/auth/auth_controller.dart';
import 'package:customer_flutter/core/auth/auth_repository.dart';
import 'package:customer_flutter/core/auth/auth_token_store.dart';
import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/i18n/app_locale.dart';
import 'package:customer_flutter/core/i18n/customer_localizations.dart';
import 'package:customer_flutter/core/network/api_client.dart';
import 'package:customer_flutter/core/security/biometric_auth_service.dart';
import 'package:customer_flutter/core/tenant/mobile_bootstrap_controller.dart';
import 'package:customer_flutter/core/theme/app_theme.dart';
import 'package:customer_flutter/features/lottery/data/lottery_models.dart';
import 'package:customer_flutter/features/lottery/data/lottery_repository.dart';
import 'package:customer_flutter/features/lottery/presentation/lottery_screens.dart';
import 'package:customer_flutter/features/lottery/presentation/lottery_stock_realtime_monitor.dart';
import 'package:customer_flutter/features/results/data/result_models.dart';
import 'package:customer_flutter/features/results/data/result_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('search page restores digit filters into six Nuxt-style boxes', (
    tester,
  ) async {
    final lottery = _FakeLotteryRepository();
    final router = _lotteryRouter(
      initialLocation: '/buy/search?d1=2&d3=3&d5=7&store_id=store_1',
    );

    await _pumpLotteryApp(tester, router: router, lottery: lottery);
    await tester.pumpAndSettle();

    expect(find.text('ซื้อสลากดิจิทัล'), findsOneWidget);
    expect(find.text('ค้นหาเลขสลากฯในร้านค้า'), findsOneWidget);
    expect(find.text('สลากฯ ทั้งหมด'), findsNothing);
    expect(find.text('ร้านค้า'), findsNothing);
    expect(find.textContaining('งวดวันที่'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'ล้างค่า'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'ล้างค่า'), findsNothing);
    final searchButton = find.widgetWithText(FilledButton, 'ค้นหาเลข');
    expect(searchButton, findsOneWidget);
    expect(
      find.descendant(of: searchButton, matching: find.byIcon(Icons.search)),
      findsNothing,
    );
    expect(find.text('ผลการค้นหาเลข'), findsOneWidget);
    expect(
      find.text('กดดูเลขนี้เพิ่มเติมเพื่อค้นหาเลขเดียวกันอีกครั้ง'),
      findsNothing,
    );
    expect(find.byType(TextField), findsNWidgets(6));
    expect(
      tester.widget<TextField>(find.byType(TextField).at(0)).controller?.text,
      '2',
    );
    expect(
      tester.widget<TextField>(find.byType(TextField).at(1)).controller?.text,
      '',
    );
    expect(
      tester.widget<TextField>(find.byType(TextField).at(2)).controller?.text,
      '3',
    );
    expect(
      tester.widget<TextField>(find.byType(TextField).at(4)).controller?.text,
      '7',
    );
    expect(lottery.lastDigits, ['2', '', '3', '', '7', '']);
    expect(lottery.lastStoreId, 'store_1');
    expect(find.text('ทั้งหมด'), findsOneWidget);
    expect(find.text('ลดราคา'), findsOneWidget);
    expect(find.text('ร้านค้าผู้พิการ'), findsOneWidget);
    expect(find.text('ร้านค้าหน่วยงาน'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('lottery-stock-brand-row')),
      findsWidgets,
    );
    expect(
      find.byKey(const ValueKey('lottery-stock-seller-row')),
      findsNothing,
    );
    expect(find.text('สลากกินแบ่งรัฐบาล'), findsWidgets);
    expect(find.text('L6'), findsWidgets);
    expect(find.text('ร้านทดสอบ'), findsNothing);
    final moreButton = find.widgetWithText(TextButton, 'ดูเลขนี้เพิ่ม');
    expect(moreButton, findsOneWidget);
    expect(
      find.descendant(of: moreButton, matching: find.byIcon(Icons.open_in_new)),
      findsNothing,
    );
    final stockRow = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('lottery-stock-row-local-stock-1')),
    );
    final stockDecoration = stockRow.decoration as BoxDecoration;
    expect(stockDecoration.borderRadius, isNull);
    final stockBorder = stockDecoration.border as Border;
    expect(stockBorder.top.style, BorderStyle.none);
    expect(stockBorder.left.style, BorderStyle.none);
    expect(stockBorder.right.style, BorderStyle.none);
    expect(stockBorder.bottom.style, BorderStyle.solid);
  });

  testWidgets('search clear resets filters and hides results like Nuxt', (
    tester,
  ) async {
    final lottery = _FakeLotteryRepository();
    final router = _lotteryRouter(
      initialLocation: '/buy/search?d1=2&d3=3&store_id=store_1',
    );

    await _pumpLotteryApp(tester, router: router, lottery: lottery);
    await tester.pumpAndSettle();

    expect(lottery.searchCount, 1);
    expect(find.text('เลือก'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'ล้างค่า'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNWidgets(6));
    for (var index = 0; index < 6; index++) {
      expect(
        tester
            .widget<TextField>(find.byType(TextField).at(index))
            .controller
            ?.text,
        '',
      );
    }
    expect(find.text('เลือก'), findsNothing);
    expect(lottery.searchCount, 1);

    await tester.tap(find.widgetWithText(FilledButton, 'ค้นหาเลข'));
    await tester.pumpAndSettle();

    expect(lottery.searchCount, 2);
    expect(lottery.lastDigits, ['', '', '', '', '', '']);
    expect(lottery.lastStoreId, 'store_1');
    expect(find.text('เลือก'), findsOneWidget);
  });

  testWidgets('search load failure shows API payload copy safely', (
    tester,
  ) async {
    final router = _lotteryRouter(initialLocation: '/buy/search?number=273707');

    await _pumpLotteryApp(
      tester,
      router: router,
      lottery: _FailingSearchLotteryRepository(
        _apiException('ยังไม่สามารถค้นหาเลขได้ กรุณาลองใหม่'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ยังไม่สามารถค้นหาเลขได้ กรุณาลองใหม่'), findsOneWidget);
    expect(find.textContaining('internal search failure'), findsNothing);
  });

  testWidgets('search load failure hides internal errors', (tester) async {
    final router = _lotteryRouter(initialLocation: '/buy/search?number=273707');

    await _pumpLotteryApp(
      tester,
      router: router,
      lottery: _FailingSearchLotteryRepository(
        StateError('internal search failure'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('โหลดเลขสลากไม่สำเร็จ'), findsWidgets);
    expect(find.textContaining('internal search failure'), findsNothing);
  });

  testWidgets('search load follows backend maintenance redirect', (
    tester,
  ) async {
    final router = _lotteryRouter(
      initialLocation: '/buy/search?number=273707',
    );

    await _pumpLotteryApp(
      tester,
      router: router,
      lottery: _FailingSearchLotteryRepository(
        _maintenanceApiException(),
      ),
    );
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/maintenance');
    expect(find.text('Maintenance route'), findsOneWidget);
  });

  testWidgets('buy search hides ticket image frame like Nuxt show-image false',
      (
    tester,
  ) async {
    final router = _lotteryRouter(initialLocation: '/buy/search?number=273707');

    await _pumpLotteryApp(
      tester,
      router: router,
      lottery: _FakeLotteryRepository(),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('lottery-stock-ticket-image-frame')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('lottery-stock-ticket-image')),
      findsNothing,
    );

    await _pumpLotteryApp(
      tester,
      router: _lotteryRouter(initialLocation: '/buy/search?number=273707'),
      lottery: _PendingImageLotteryRepository(),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('lottery-stock-ticket-image-frame')),
      findsNothing,
    );
    expect(find.text('รูปสลากกำลังเตรียมพร้อม'), findsNothing);

    await _pumpLotteryApp(
      tester,
      router: _lotteryRouter(initialLocation: '/buy/search?number=273707'),
      lottery: _FailedImageLotteryRepository(),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('lottery-stock-ticket-image-frame')),
      findsNothing,
    );
    expect(find.text('ภาพสลากยังไม่พร้อมจากระบบ'), findsNothing);
  });

  testWidgets('stock card toggles select and remove from the live cart state', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final lottery = _FakeLotteryRepository();
    final router = _lotteryRouter(
      initialLocation: '/buy/search?number=273707',
    );

    await _pumpLotteryApp(tester, router: router, lottery: lottery);

    await tester.pumpAndSettle();

    expect(lottery.searchCount, 1);
    expect(find.text('ค้นหาเลขเด็ด'), findsOneWidget);
    expect(find.textContaining('งวดวันที่'), findsOneWidget);
    expect(find.text('ผลการค้นหาเลข'), findsOneWidget);
    expect(
      find.text('กดดูเลขนี้เพิ่มเติมเพื่อค้นหาเลขเดียวกันอีกครั้ง'),
      findsNothing,
    );
    final selectButton = find.widgetWithText(OutlinedButton, 'เลือก');
    expect(selectButton, findsOneWidget);
    expect(
      find.descendant(
        of: selectButton,
        matching: find.byIcon(Icons.add_shopping_cart_outlined),
      ),
      findsNothing,
    );
    expect(find.text('เอาออก'), findsNothing);

    await tester.tap(selectButton);
    await tester.pumpAndSettle();

    expect(lottery.reserveCount, 1);
    expect(find.text('เพิ่มสลากลงตะกร้าแล้ว'), findsOneWidget);
    expect(find.text('เลือก'), findsNothing);
    expect(find.text('เอาออก'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    final removeButton = find.widgetWithText(FilledButton, 'เอาออก');
    expect(
      find.descendant(
        of: removeButton,
        matching: find.byIcon(Icons.remove_shopping_cart_outlined),
      ),
      findsNothing,
    );
    await tester.ensureVisible(removeButton);
    await tester.tap(removeButton);
    await tester.pumpAndSettle();

    expect(lottery.releaseCount, 1);
    expect(find.text('เลือก'), findsOneWidget);
    expect(find.text('เอาออก'), findsNothing);
  });

  testWidgets('stock card stays selected after backend materializes stock id', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final lottery = _MaterializedReservationLotteryRepository();
    final router = _lotteryRouter(
      initialLocation: '/buy/search?number=273707',
    );

    await _pumpLotteryApp(tester, router: router, lottery: lottery);
    await tester.pumpAndSettle();

    final selectButton = find.widgetWithText(OutlinedButton, 'เลือก');
    expect(selectButton, findsOneWidget);

    await tester.tap(selectButton);
    await tester.pumpAndSettle();

    expect(lottery.reserveCount, 1);
    expect(lottery.lastReservedItemId, 'vstock:tenant_1:game_1:273707:1');
    expect(find.text('เพิ่มสลากลงตะกร้าแล้ว'), findsOneWidget);
    expect(find.text('เลือก'), findsNothing);
    expect(find.text('เอาออก'), findsOneWidget);
  });

  testWidgets('stock row tap does not reserve; select pill is the only action',
      (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final lottery = _FakeLotteryRepository();
    final router = _lotteryRouter(
      initialLocation: '/buy/search?number=273707',
    );

    await _pumpLotteryApp(tester, router: router, lottery: lottery);
    await tester.pumpAndSettle();

    final stockRow = find.byKey(
      const ValueKey('lottery-stock-row-local-stock-1'),
    );
    expect(stockRow, findsOneWidget);

    await tester.tap(stockRow);
    await tester.pumpAndSettle();

    expect(lottery.reserveCount, 0);
    expect(find.text('เพิ่มสลากลงตะกร้าแล้ว'), findsNothing);
    expect(find.text('เอาออก'), findsNothing);

    await tester.tap(find.widgetWithText(OutlinedButton, 'เลือก'));
    await tester.pumpAndSettle();

    expect(lottery.reserveCount, 1);
    expect(find.text('เพิ่มสลากลงตะกร้าแล้ว'), findsOneWidget);
    expect(find.text('เอาออก'), findsOneWidget);
  });

  testWidgets('guest stock selection keeps Nuxt-style login redirect', (
    tester,
  ) async {
    final lottery = _GuestBrowseLotteryRepository();
    final tokenStore = AuthTokenStore();
    final router = _lotteryRouter(
      initialLocation: '/buy/search?number=273707',
    );

    await _pumpLotteryApp(
      tester,
      router: router,
      lottery: lottery,
      tokenStore: tokenStore,
      authController: _unauthenticatedController(tokenStore),
    );
    await tester.pumpAndSettle();

    expect(lottery.cartCount, 0);
    expect(find.text('เลือก'), findsOneWidget);

    final selectButton = find.widgetWithText(OutlinedButton, 'เลือก');
    await tester.ensureVisible(selectButton);
    await tester.pumpAndSettle();
    await tester.tap(selectButton);
    await tester.pumpAndSettle();

    expect(lottery.cartCount, 0);
    expect(lottery.reserveCount, 0);
    expect(find.text('Login route /buy/search?number=273707'), findsOneWidget);
    expect(find.text('เพิ่มสลากลงตะกร้าแล้ว'), findsNothing);
  });

  testWidgets('stock selection still reserves when restored token exists', (
    tester,
  ) async {
    final lottery = _FakeLotteryRepository();
    final tokenStore = _MemoryAuthTokenStore();
    await tokenStore.save(
      accessToken: 'restored-access-token',
      refreshToken: 'restored-refresh-token',
      customerId: 'customer_1',
    );
    final router = _lotteryRouter(
      initialLocation: '/buy/search?number=273707',
    );

    await _pumpLotteryApp(
      tester,
      router: router,
      lottery: lottery,
      tokenStore: tokenStore,
      authController: _unauthenticatedController(tokenStore),
    );
    await tester.pumpAndSettle();

    final selectButton = find.widgetWithText(OutlinedButton, 'เลือก');
    await tester.ensureVisible(selectButton);
    await tester.pumpAndSettle();
    await tester.tap(selectButton);
    await tester.pumpAndSettle();

    expect(lottery.reserveCount, 1);
    expect(find.text('Login route /buy/search?number=273707'), findsNothing);
    expect(find.text('เพิ่มสลากลงตะกร้าแล้ว'), findsOneWidget);
  });

  testWidgets('stock list shows selected-cart dock after reservation', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final lottery = _FakeLotteryRepository();
    final router = _lotteryRouter(
      initialLocation: '/buy/search?number=273707',
    );

    await _pumpLotteryApp(tester, router: router, lottery: lottery);
    await tester.pumpAndSettle();

    expect(find.text('จำนวนที่เลือก'), findsNothing);

    final selectButton = find.widgetWithText(OutlinedButton, 'เลือก');
    await tester.ensureVisible(selectButton);
    await tester.pumpAndSettle();
    await tester.tap(selectButton);
    await tester.pumpAndSettle();

    final selectionDock = find.byKey(const ValueKey('cart-selection-dock'));
    expect(selectionDock, findsOneWidget);
    expect(
      find.ancestor(of: selectionDock, matching: find.byType(ListView)),
      findsNothing,
    );
    final selectionDockDecoration =
        tester.widget<DecoratedBox>(selectionDock).decoration as BoxDecoration;
    expect(
      selectionDockDecoration.borderRadius,
      const BorderRadius.vertical(top: Radius.circular(12)),
    );
    expect(find.text('จำนวนที่เลือก'), findsOneWidget);
    expect(find.text('คุณมีสลากฯ ที่เลือกไว้'), findsNothing);
    expect(find.text('1 ใบ'), findsOneWidget);
    expect(
      find.descendant(
        of: selectionDock,
        matching: find.textContaining('กรุณาชำระเงินภายใน'),
      ),
      findsOneWidget,
    );

    final reviewButton = find.widgetWithText(FilledButton, 'ตรวจสอบสลากฯ');
    expect(tester.getSize(reviewButton).height, 58);
    expect(
      find.descendant(
        of: reviewButton,
        matching: find.byIcon(Icons.shopping_cart_checkout),
      ),
      findsNothing,
    );
    expect(
      find.descendant(of: reviewButton, matching: find.textContaining('นาที')),
      findsNothing,
    );
    final dockBottom = tester.getBottomLeft(selectionDock).dy;
    await tester.drag(find.byType(ListView), const Offset(0, -260));
    await tester.pumpAndSettle();
    expect(tester.getBottomLeft(selectionDock).dy, closeTo(dockBottom, 1));
    await tester.tap(reviewButton);
    await tester.pumpAndSettle();

    expect(find.text('Cart route'), findsOneWidget);
  });

  testWidgets('stock list disables new reservations when sales are closed', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final lottery = _ClosedLotteryRepository();
    final router = _lotteryRouter(
      initialLocation: '/buy/search?number=273707',
    );

    await _pumpLotteryApp(tester, router: router, lottery: lottery);
    await tester.pumpAndSettle();

    expect(find.text('ขณะนี้ไม่สามารถซื้อสลากได้'), findsOneWidget);
    expect(find.text('ปิดรับซื้อ'), findsOneWidget);
    expect(find.byKey(const ValueKey('cart-selection-dock')), findsNothing);

    final closedButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'ปิดรับซื้อ'),
    );
    expect(closedButton.onPressed, isNull);
    expect(
      tester.getSize(find.widgetWithText(OutlinedButton, 'ปิดรับซื้อ')).height,
      40,
    );
    expect(
      tester.getTopLeft(find.text('ขณะนี้ไม่สามารถซื้อสลากได้')).dy,
      lessThan(
        tester
            .getTopLeft(
              find.byKey(const ValueKey('lottery-stock-row-local-stock-1')),
            )
            .dy,
      ),
    );
    expect(lottery.reserveCount, 0);
    expect(find.text('เลือก'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stock list handles unavailable reservation races like Nuxt', (
    tester,
  ) async {
    final lottery = _UnavailableReservationLotteryRepository();
    final router = _lotteryRouter(
      initialLocation: '/buy/search?number=273707',
    );

    await _pumpLotteryApp(tester, router: router, lottery: lottery);
    await tester.pumpAndSettle();

    expect(find.text('เลือก'), findsOneWidget);

    final selectButton = find.widgetWithText(OutlinedButton, 'เลือก');
    await tester.ensureVisible(selectButton);
    await tester.pumpAndSettle();
    await tester.tap(selectButton);
    await tester.pumpAndSettle();

    expect(lottery.reserveCount, 1);
    expect(lottery.cartCount, 2);
    expect(find.text('สลากใบนี้ถูกซื้อแล้ว'), findsOneWidget);
    expect(
      find.text('ขออภัย สลากที่ท่านเลือกมีคนซื้อแล้ว กรุณาเลือกสลากใบอื่น'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'รับทราบ'));
    await tester.pumpAndSettle();

    expect(find.text('เลือก'), findsNothing);
    expect(find.text('ไม่พบเลขสลาก'), findsOneWidget);
  });

  testWidgets('search page refreshes stock on realtime tick', (
    tester,
  ) async {
    final lottery = _FakeLotteryRepository();
    final router = _lotteryRouter(
      initialLocation: '/buy/search?number=273707',
    );

    await _pumpLotteryApp(tester, router: router, lottery: lottery);
    await tester.pumpAndSettle();

    expect(lottery.searchCount, 1);
    expect(find.text('เลือก'), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(BuySearchScreen)),
      listen: false,
    );
    container.read(lotteryStockRealtimeTickProvider.notifier).state++;
    await tester.pump();
    await tester.pumpAndSettle();

    expect(lottery.searchCount, 2);
    expect(lottery.lastCursor, isEmpty);
    expect(find.text('เลือก'), findsOneWidget);
  });

  testWidgets('stock price realtime patch shows Nuxt-style trend', (
    tester,
  ) async {
    final lottery = _FakeLotteryRepository();
    final router = _lotteryRouter(initialLocation: '/buy/search?number=273707');

    await _pumpLotteryApp(tester, router: router, lottery: lottery);
    await tester.pumpAndSettle();

    expect(find.text('80.00 บาท'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('lottery-stock-price-trend-up')),
      findsNothing,
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byType(BuySearchScreen)),
      listen: false,
    );
    container.read(lotteryStockPricePatchProvider.notifier).state =
        const LotteryStockPricePatch(
      price: 90,
      gameId: 'game_1',
      flashKey: 9001,
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('90.00 บาท'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('lottery-stock-price-trend-up')),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 2));

    expect(find.text('90.00 บาท'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('lottery-stock-price-trend-up')),
      findsNothing,
    );
  });

  testWidgets('stock availability realtime patch disables sold rows like Nuxt',
      (
    tester,
  ) async {
    final lottery = _FakeLotteryRepository();
    final router = _lotteryRouter(initialLocation: '/buy/search?number=273707');

    await _pumpLotteryApp(tester, router: router, lottery: lottery);
    await tester.pumpAndSettle();

    expect(find.text('เลือก'), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(BuySearchScreen)),
      listen: false,
    );
    container.read(lotteryStockAvailabilityPatchProvider.notifier).state =
        const LotteryStockAvailabilityPatch(
      number: '273707',
      remainingCount: 0,
      status: 'sold_out',
      gameId: 'game_1',
      flashKey: 2701,
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('เลือก'), findsNothing);
    final soldOutButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'ขายหมดแล้ว'),
    );
    expect(soldOutButton.onPressed, isNull);
    expect(lottery.reserveCount, 0);
  });

  testWidgets('stock list loads the next page when it is near the bottom', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final lottery = _PaginatedLotteryRepository();
    final router = _lotteryRouter(initialLocation: '/buy/search?d1=2');

    await _pumpLotteryApp(tester, router: router, lottery: lottery);
    await tester.pumpAndSettle();

    expect(lottery.searchCount, 1);

    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pumpAndSettle();

    expect(lottery.searchCount, 2);
    expect(lottery.lastCursor, 'cursor_1');
    expect(lottery.randomSeeds, hasLength(2));
    expect(lottery.randomSeeds.first, isNotEmpty);
    expect(lottery.randomSeeds.last, lottery.randomSeeds.first);
    expect(find.text('เลือก'), findsNWidgets(2));
  });

  testWidgets('stock list omits Flutter load-more CTA', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final lottery = _PaginatedLotteryRepository();
    final router = _lotteryRouter(initialLocation: '/buy/search?d1=2');

    await _pumpLotteryApp(tester, router: router, lottery: lottery);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(OutlinedButton, 'โหลดเพิ่มเติม'), findsNothing);
  });

  testWidgets('stock list renders Nuxt-style skeletons while initially loading',
      (
    tester,
  ) async {
    final lottery = _DelayedInitialLotteryRepository();
    final router = _lotteryRouter(initialLocation: '/buy/search?number=273707');

    await _pumpLotteryApp(tester, router: router, lottery: lottery);
    await tester.pump();
    await tester.pump();

    final loadingSearchButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'กำลังค้นหา'),
    );
    expect(loadingSearchButton.onPressed, isNull);
    final loadingClearButton = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'ล้างค่า'),
    );
    expect(loadingClearButton.onPressed, isNull);
    expect(find.widgetWithText(OutlinedButton, 'แสดงเลขใหม่'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'กำลังโหลด'), findsNothing);
    expect(_lotteryStockSkeletons(), findsNWidgets(5));
    expect(find.byType(CircularProgressIndicator), findsNothing);

    lottery.completeSearch();
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'ค้นหาเลข'), findsOneWidget);
    expect(_lotteryStockSkeletons(), findsNothing);
    expect(find.text('เลือก'), findsOneWidget);
  });

  testWidgets('stock list appends Nuxt-style skeletons while loading more', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final lottery = _DelayedNextPageLotteryRepository();
    final router = _lotteryRouter(initialLocation: '/buy/search?d1=2');

    await _pumpLotteryApp(tester, router: router, lottery: lottery);
    await tester.pumpAndSettle();

    expect(lottery.searchCount, 1);

    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pump();
    await tester.pump();

    expect(lottery.searchCount, 2);
    expect(lottery.lastCursor, 'cursor_1');
    expect(find.text('เลือก'), findsOneWidget);
    expect(_lotteryStockSkeletons(), findsNWidgets(5));

    lottery.completeNextPage();
    await tester.pumpAndSettle();

    expect(_lotteryStockSkeletons(), findsNothing);
    expect(find.text('เลือก'), findsNWidgets(2));
  });

  testWidgets('buy browse list deduplicates repeated random numbers like Nuxt',
      (
    tester,
  ) async {
    final lottery = _DuplicateBrowseLotteryRepository();
    final router = GoRouter(
      initialLocation: '/buy',
      routes: [
        GoRoute(
          path: '/buy',
          builder: (context, state) => const BuyScreen(),
        ),
        GoRoute(
          path: '/cart',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('Cart route'))),
        ),
      ],
    );

    await _pumpLotteryApp(tester, router: router, lottery: lottery);
    await tester.pumpAndSettle();

    expect(lottery.searchCount, 1);
    expect(find.text('ทั้งหมด'), findsOneWidget);
    expect(find.text('ลดราคา'), findsOneWidget);
    expect(find.text('ร้านค้าผู้พิการ'), findsOneWidget);
    expect(find.text('ร้านค้าหน่วยงาน'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('lottery-stock-ticket-image-frame')),
      findsNothing,
    );
    expect(find.text('เลือก'), findsNWidgets(2));
  });

  testWidgets('buy browse refresh enters Nuxt-style cooldown', (
    tester,
  ) async {
    final lottery = _FakeLotteryRepository();
    final router = GoRouter(
      initialLocation: '/buy',
      routes: [
        GoRoute(
          path: '/buy',
          builder: (context, state) => const BuyScreen(),
        ),
        GoRoute(
          path: '/cart',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('Cart route'))),
        ),
      ],
    );

    await _pumpLotteryApp(tester, router: router, lottery: lottery);
    await tester.pumpAndSettle();

    expect(lottery.searchCount, 1);
    final initialSeed = lottery.lastRandomSeed;
    expect(initialSeed, isNotEmpty);

    final refreshButton = find.widgetWithText(OutlinedButton, 'แสดงเลขใหม่');
    await tester.tap(refreshButton);
    await tester.pump();
    await tester.pump();

    expect(lottery.searchCount, 2);
    expect(lottery.lastRandomSeed, isNot(initialSeed));
    expect(find.widgetWithText(OutlinedButton, 'รอ 10 วิ'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'รอ 10 วิ'),
          )
          .onPressed,
      isNull,
    );

    await tester.pump(const Duration(seconds: 1));
    expect(find.widgetWithText(OutlinedButton, 'รอ 9 วิ'), findsOneWidget);
    expect(lottery.searchCount, 2);

    await tester.pump(const Duration(seconds: 9));
    expect(find.widgetWithText(OutlinedButton, 'แสดงเลขใหม่'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'แสดงเลขใหม่'),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('exact search still preserves duplicate full-number rows', (
    tester,
  ) async {
    final lottery = _DuplicateBrowseLotteryRepository();
    final router = _lotteryRouter(initialLocation: '/buy/search?number=123123');

    await _pumpLotteryApp(tester, router: router, lottery: lottery);
    await tester.pumpAndSettle();

    expect(lottery.searchCount, 1);
    expect(find.text('เลือก'), findsNWidgets(3));

    await tester.tap(find.widgetWithText(OutlinedButton, 'แสดงเลขใหม่'));
    await tester.pump();
    await tester.pump();

    expect(lottery.searchCount, 2);
    expect(find.textContaining('รอ '), findsNothing);
    expect(find.widgetWithText(OutlinedButton, 'แสดงเลขใหม่'), findsOneWidget);
  });

  testWidgets('more page close action restores the stacked search page', (
    tester,
  ) async {
    final lottery = _FakeLotteryRepository();
    final router = _lotteryRouter(
      initialLocation: '/buy/search?d1=2&d3=3&store_id=store_1',
    );

    await _pumpLotteryApp(tester, router: router, lottery: lottery);
    await tester.pumpAndSettle();

    router.push(
      Uri(
        path: '/buy/more',
        queryParameters: const {
          'number': '273707',
          'store_id': 'store_1',
          'back': '/buy/search?d1=2&d3=3&store_id=store_1',
        },
      ).toString(),
    );
    await tester.pumpAndSettle();

    expect(find.byType(BuyMoreScreen), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'ย้อนกลับ'), findsNothing);
    expect(find.text('ทั้งหมด'), findsNothing);
    expect(find.text('ลดราคา'), findsNothing);
    expect(find.text('ร้านค้าผู้พิการ'), findsNothing);
    expect(find.text('ร้านค้าหน่วยงาน'), findsNothing);
    expect(lottery.lastRandomSeed, isEmpty);

    await tester.tap(find.byTooltip('ย้อนกลับ'));
    await tester.pumpAndSettle();

    expect(find.byType(BuySearchScreen), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).at(0)).controller?.text,
      '2',
    );
    expect(
      tester.widget<TextField>(find.byType(TextField).at(2)).controller?.text,
      '3',
    );
    expect(lottery.lastStoreId, 'store_1');
  });

  testWidgets('more page matches Nuxt compact number-list layout on mobile', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final lottery = _FakeLotteryRepository();
    final router = _lotteryRouter(
      initialLocation:
          '/buy/more?number=273707&store_id=store_1&back=/buy/search?d1=2',
    );

    await _pumpLotteryApp(tester, router: router, lottery: lottery);
    await tester.pumpAndSettle();

    expect(find.byType(BuyMoreScreen), findsOneWidget);
    expect(find.text('รายการสลากฯ'), findsOneWidget);
    expect(find.text('สลากฯ เลข'), findsOneWidget);
    expect(find.text('2 7 3 7 0 7'), findsOneWidget);
    expect(find.text('เลขนี้เพิ่มเติม'), findsNothing);
    expect(find.text('แสดงเลขใหม่'), findsNothing);
    expect(find.byIcon(Icons.refresh), findsNothing);
    expect(find.text('ทั้งหมด'), findsNothing);
    expect(find.text('ลดราคา'), findsNothing);
    expect(find.text('ร้านค้าผู้พิการ'), findsNothing);
    expect(find.text('ร้านค้าหน่วยงาน'), findsNothing);
    expect(find.widgetWithText(TextButton, 'ดูเลขนี้เพิ่ม'), findsNothing);
    expect(
      find.byKey(const ValueKey('lottery-stock-ticket-image-frame')),
      findsNothing,
    );
    expect(lottery.searchCount, 1);
    expect(lottery.lastStoreId, 'store_1');
    expect(lottery.lastRandomSeed, isEmpty);
    expect(find.byKey(const ValueKey('cart-selection-dock')), findsNothing);

    final moreSelectButton = find.widgetWithText(OutlinedButton, 'เลือก').first;
    await tester.ensureVisible(moreSelectButton);
    await tester.pumpAndSettle();
    await tester.tap(moreSelectButton);
    await tester.pumpAndSettle();

    final moreDock = find.byKey(const ValueKey('cart-selection-dock'));
    expect(moreDock, findsOneWidget);
    expect(
      find.ancestor(of: moreDock, matching: find.byType(ListView)),
      findsNothing,
    );
    expect(
      find.descendant(
        of: moreDock,
        matching: find.textContaining('กรุณาชำระเงินภายใน'),
      ),
      findsOneWidget,
    );
    final moreDockBottom = tester.getBottomLeft(moreDock).dy;
    await tester.drag(find.byType(ListView), const Offset(0, -260));
    await tester.pumpAndSettle();
    expect(tester.getBottomLeft(moreDock).dy, closeTo(moreDockBottom, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('more page auto-loads same-number pages without random seed', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final lottery = _PaginatedLotteryRepository();
    final router = _lotteryRouter(
      initialLocation:
          '/buy/more?number=273707&store_id=store_1&back=/buy/search?d1=2',
    );

    await _pumpLotteryApp(tester, router: router, lottery: lottery);
    await tester.pumpAndSettle();

    expect(lottery.searchCount, 1);
    expect(lottery.lastCursor, isEmpty);
    expect(lottery.lastStoreId, 'store_1');
    expect(lottery.lastRandomSeed, isEmpty);

    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pumpAndSettle();

    expect(lottery.searchCount, 2);
    expect(lottery.lastCursor, 'cursor_1');
    expect(lottery.lastStoreId, 'store_1');
    expect(lottery.randomSeeds, ['', '']);
    expect(find.text('เลือก'), findsNWidgets(2));
    expect(find.text('แสดงเลขใหม่'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('more page close action falls back from unsafe back path', (
    tester,
  ) async {
    final lottery = _FakeLotteryRepository();
    final unsafeBack = Uri.encodeComponent('https://evil.test/buy');
    final router = _lotteryRouter(
      initialLocation: '/buy/more?number=273707&back=$unsafeBack',
    );

    await _pumpLotteryApp(tester, router: router, lottery: lottery);
    await tester.pumpAndSettle();

    expect(find.byType(BuyMoreScreen), findsOneWidget);

    await tester.tap(find.byTooltip('ย้อนกลับ'));
    await tester.pumpAndSettle();

    expect(find.text('Buy route'), findsOneWidget);
  });
}

GoRouter _lotteryRouter({required String initialLocation}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/buy/search',
        builder: (context, state) => BuySearchScreen(
          query: state.uri.queryParameters,
        ),
      ),
      GoRoute(
        path: '/buy/more',
        builder: (context, state) => BuyMoreScreen(
          query: state.uri.queryParameters,
        ),
      ),
      GoRoute(
        path: '/buy',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Buy route'))),
      ),
      GoRoute(
        path: '/cart',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Cart route'))),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => Scaffold(
          body: Center(
            child: Text(
              'Login route ${state.uri.queryParameters['redirect'] ?? ''}',
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/maintenance',
        builder: (context, state) =>
            const Scaffold(body: Text('Maintenance route')),
      ),
    ],
  );
}

Future<void> _pumpLotteryApp(
  WidgetTester tester, {
  required GoRouter router,
  required LotteryRepository lottery,
  AuthTokenStore? tokenStore,
  AuthController? authController,
}) {
  final effectiveTokenStore = tokenStore ?? AuthTokenStore();
  final effectiveAuthController =
      authController ?? _authenticatedController(effectiveTokenStore);
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(_testConfig),
        authTokenStoreProvider.overrideWithValue(effectiveTokenStore),
        authControllerProvider.overrideWith((_) => effectiveAuthController),
        resultRepositoryProvider.overrideWithValue(_FakeResultRepository()),
        lotteryRepositoryProvider.overrideWithValue(lottery),
        mobileBootstrapProvider.overrideWith((_) async => _mobileBootstrap()),
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

const _testConfig = AppConfig(
  apiBaseUrl: 'https://partner.example.com/api/v1',
  defaultLocale: 'th-TH',
);

MobileBootstrap _mobileBootstrap() {
  return MobileBootstrap.fromJson(const {
    'mobile': {'lottery_product_label': 'L6'},
  });
}

AuthController _authenticatedController(AuthTokenStore tokenStore) {
  final api = _testApiClient(tokenStore);
  return AuthController(
    authRepository: AuthRepository(api: api, tokenStore: tokenStore),
    tokenStore: tokenStore,
    biometricAuth: BiometricAuthService(api),
  )
    ..isAuthenticated = true
    ..pinRequired = false;
}

AuthController _unauthenticatedController(AuthTokenStore tokenStore) {
  final api = _testApiClient(tokenStore);
  return AuthController(
    authRepository: AuthRepository(api: api, tokenStore: tokenStore),
    tokenStore: tokenStore,
    biometricAuth: BiometricAuthService(api),
  )
    ..isAuthenticated = false
    ..pinRequired = false;
}

class _MemoryAuthTokenStore extends AuthTokenStore {
  String? _access;
  String? _refresh;
  String? _customer;

  @override
  String? get accessToken => _access;

  @override
  String? get refreshToken => _refresh;

  @override
  String? get customerId => _customer;

  @override
  bool get hasAccessToken => (_access ?? '').isNotEmpty;

  @override
  Future<void> restore() async {}

  @override
  Future<void> save({
    required String accessToken,
    required String refreshToken,
    String? customerId,
  }) async {
    _access = accessToken;
    _refresh = refreshToken;
    _customer = customerId;
  }

  @override
  Future<void> clear() async {
    _access = null;
    _refresh = null;
    _customer = null;
  }
}

Finder _lotteryStockSkeletons() {
  return find.byWidgetPredicate((widget) {
    final key = widget.key;
    return key is ValueKey<String> &&
        key.value.startsWith('lottery-stock-skeleton-');
  });
}

class _FakeResultRepository extends ResultRepository {
  _FakeResultRepository() : super(_testApiClient());

  @override
  Future<CurrentGame?> currentGame() async {
    return const CurrentGame(
      id: 'game_1',
      name: 'งวดทดสอบ',
      status: 'open',
      drawAt: '2026-07-01T17:00:00+07:00',
    );
  }
}

class _FakeLotteryRepository extends LotteryRepository {
  _FakeLotteryRepository() : super(_testApiClient());

  bool _reserved = false;
  int searchCount = 0;
  int cartCount = 0;
  int reserveCount = 0;
  int releaseCount = 0;
  List<String> lastDigits = const [];
  List<String> randomSeeds = const [];
  String lastStoreId = '';
  String lastCursor = '';
  String lastRandomSeed = '';

  @override
  Future<LotteryStockPage> search({
    required String gameId,
    List<String> digits = const [],
    String number = '',
    String storeId = '',
    String cursor = '',
    String randomSeed = '',
    int limit = 20,
  }) async {
    searchCount++;
    lastDigits = List<String>.from(digits);
    lastStoreId = storeId;
    lastCursor = cursor;
    lastRandomSeed = randomSeed;
    randomSeeds = [...randomSeeds, randomSeed];
    return LotteryStockPage(
      gameId: gameId,
      items: [_stockItem()],
      nextCursor: '',
      hasMore: false,
      sellerName: 'ร้านทดสอบ',
    );
  }

  @override
  Future<LotteryReservation> reserve({
    required String gameId,
    required LotteryStockItem item,
  }) async {
    reserveCount++;
    _reserved = true;
    return LotteryReservation(
      id: 'reservation_1',
      gameId: gameId,
      status: 'active',
      expiresAt: '2026-06-29T12:30:00+07:00',
      expiresInSeconds: 900,
      serverTime: '2026-06-29T12:15:00+07:00',
      items: [_stockItem(reservationId: 'reservation_1')],
      total: 80,
    );
  }

  @override
  Future<LotteryCart> cart() async {
    cartCount++;
    return _reserved ? _reservedCart() : LotteryCart.empty();
  }

  @override
  Future<LotteryCart> releaseReservation(String reservationId) async {
    releaseCount++;
    _reserved = false;
    return LotteryCart.empty();
  }

  LotteryCart _reservedCart() {
    return LotteryCart(
      reservations: [
        LotteryReservation(
          id: 'reservation_1',
          gameId: 'game_1',
          status: 'active',
          expiresAt: '2026-06-29T12:30:00+07:00',
          expiresInSeconds: 900,
          serverTime: '2026-06-29T12:15:00+07:00',
          items: [_stockItem(reservationId: 'reservation_1')],
          total: 80,
        ),
      ],
      total: 80,
      itemCount: 1,
      serverTime: '2026-06-29T12:15:00+07:00',
      warnings: const [],
    );
  }

  LotteryStockItem _stockItem({
    String id = '',
    String token = '',
    String reservationId = '',
    String number = '273707',
    String localStockItemId = 'local-stock-1',
    String stockRef = 'vstock-ref-1',
    String imageUrl = 'data:image/gif;base64,R0lGODlhAQABAAAAACwAAAAAAQABAAA=',
    String thumbUrl = '',
    String imageStatus = 'ready',
    String imageError = '',
  }) {
    return LotteryStockItem(
      id: id.isEmpty ? 'vstock:game_1:$number:1' : id,
      token: token.isEmpty ? 'stock-token-$number' : token,
      localStockItemId: localStockItemId,
      stockRef: stockRef,
      number: number,
      sellerName: 'ร้านทดสอบ',
      storeName: 'ร้านทดสอบ',
      price: 80,
      remainingCount: 1,
      status: 'available',
      reservationId: reservationId,
      reservationExpiresAt: null,
      serverTime: null,
      imageUrl: imageUrl,
      thumbUrl: thumbUrl,
      imageStatus: imageStatus,
      imageError: imageError,
      raw: const {},
    );
  }
}

class _PendingImageLotteryRepository extends _FakeLotteryRepository {
  @override
  Future<LotteryStockPage> search({
    required String gameId,
    List<String> digits = const [],
    String number = '',
    String storeId = '',
    String cursor = '',
    String randomSeed = '',
    int limit = 20,
  }) async {
    searchCount++;
    lastDigits = List<String>.from(digits);
    lastStoreId = storeId;
    lastCursor = cursor;
    lastRandomSeed = randomSeed;
    randomSeeds = [...randomSeeds, randomSeed];
    return LotteryStockPage(
      gameId: gameId,
      items: [_stockItem(imageUrl: '', imageStatus: 'pending_assets')],
      nextCursor: '',
      hasMore: false,
      sellerName: 'ร้านทดสอบ',
    );
  }
}

class _FailedImageLotteryRepository extends _FakeLotteryRepository {
  @override
  Future<LotteryStockPage> search({
    required String gameId,
    List<String> digits = const [],
    String number = '',
    String storeId = '',
    String cursor = '',
    String randomSeed = '',
    int limit = 20,
  }) async {
    searchCount++;
    lastDigits = List<String>.from(digits);
    lastStoreId = storeId;
    lastCursor = cursor;
    lastRandomSeed = randomSeed;
    randomSeeds = [...randomSeeds, randomSeed];
    return LotteryStockPage(
      gameId: gameId,
      items: [
        _stockItem(
          imageStatus: 'failed',
          imageError: 'ภาพสลากยังไม่พร้อมจากระบบ',
        ),
      ],
      nextCursor: '',
      hasMore: false,
      sellerName: 'ร้านทดสอบ',
    );
  }
}

class _MaterializedReservationLotteryRepository extends _FakeLotteryRepository {
  String lastReservedItemId = '';

  @override
  Future<LotteryStockPage> search({
    required String gameId,
    List<String> digits = const [],
    String number = '',
    String storeId = '',
    String cursor = '',
    String randomSeed = '',
    int limit = 20,
  }) async {
    searchCount++;
    lastDigits = List<String>.from(digits);
    lastStoreId = storeId;
    lastCursor = cursor;
    lastRandomSeed = randomSeed;
    randomSeeds = [...randomSeeds, randomSeed];
    const virtualRef = 'vstock:tenant_1:game_1:273707:1';
    return LotteryStockPage(
      gameId: gameId,
      items: [
        _stockItem(
          id: virtualRef,
          token: virtualRef,
          localStockItemId: virtualRef,
          stockRef: virtualRef,
        ),
      ],
      nextCursor: '',
      hasMore: false,
      sellerName: 'ร้านทดสอบ',
    );
  }

  @override
  Future<LotteryReservation> reserve({
    required String gameId,
    required LotteryStockItem item,
  }) async {
    reserveCount++;
    _reserved = true;
    lastReservedItemId = item.reserveStockItemId;
    const virtualRef = 'vstock:tenant_1:game_1:273707:1';
    return LotteryReservation(
      id: 'reservation_1',
      gameId: gameId,
      status: 'active',
      expiresAt: '2026-06-29T12:30:00+07:00',
      expiresInSeconds: 900,
      serverTime: '2026-06-29T12:15:00+07:00',
      items: [
        _stockItem(
          id: 'local_stock_1',
          token: 'local_stock_1',
          localStockItemId: 'local_stock_1',
          stockRef: virtualRef,
          reservationId: 'reservation_1',
        ),
      ],
      total: 80,
    );
  }
}

class _UnavailableReservationLotteryRepository extends _FakeLotteryRepository {
  @override
  Future<LotteryReservation> reserve({
    required String gameId,
    required LotteryStockItem item,
  }) async {
    reserveCount++;
    throw DioException(
      requestOptions: RequestOptions(path: '/customer/reservations'),
      response: Response(
        requestOptions: RequestOptions(path: '/customer/reservations'),
        statusCode: 409,
        data: const {
          'error': {
            'code': 'reservation_unavailable',
            'message': 'The requested stock is no longer available.',
          },
        },
      ),
    );
  }
}

class _GuestBrowseLotteryRepository extends _FakeLotteryRepository {
  @override
  Future<LotteryCart> cart() async {
    cartCount++;
    throw StateError('Guest stock browse should not load customer cart.');
  }
}

class _FailingSearchLotteryRepository extends _FakeLotteryRepository {
  _FailingSearchLotteryRepository(this.error);

  final Object error;

  @override
  Future<LotteryStockPage> search({
    required String gameId,
    List<String> digits = const [],
    String number = '',
    String storeId = '',
    String cursor = '',
    String randomSeed = '',
    int limit = 20,
  }) async {
    searchCount++;
    lastDigits = List<String>.from(digits);
    lastStoreId = storeId;
    lastCursor = cursor;
    lastRandomSeed = randomSeed;
    randomSeeds = [...randomSeeds, randomSeed];
    throw error;
  }
}

class _PaginatedLotteryRepository extends _FakeLotteryRepository {
  @override
  Future<LotteryStockPage> search({
    required String gameId,
    List<String> digits = const [],
    String number = '',
    String storeId = '',
    String cursor = '',
    String randomSeed = '',
    int limit = 20,
  }) async {
    searchCount++;
    lastDigits = List<String>.from(digits);
    lastStoreId = storeId;
    lastCursor = cursor;
    lastRandomSeed = randomSeed;
    randomSeeds = [...randomSeeds, randomSeed];
    if (cursor.isEmpty) {
      return LotteryStockPage(
        gameId: gameId,
        items: [_stockItem()],
        nextCursor: 'cursor_1',
        hasMore: true,
        sellerName: 'ร้านทดสอบ',
      );
    }
    return LotteryStockPage(
      gameId: gameId,
      items: [
        _stockItem(number: '999999', localStockItemId: 'local-stock-2'),
      ],
      nextCursor: '',
      hasMore: false,
      sellerName: 'ร้านทดสอบ',
    );
  }
}

class _DelayedInitialLotteryRepository extends _FakeLotteryRepository {
  final _searchCompleter = Completer<LotteryStockPage>();

  void completeSearch() {
    if (_searchCompleter.isCompleted) return;
    _searchCompleter.complete(
      LotteryStockPage(
        gameId: 'game_1',
        items: [_stockItem()],
        nextCursor: '',
        hasMore: false,
        sellerName: 'ร้านทดสอบ',
      ),
    );
  }

  @override
  Future<LotteryStockPage> search({
    required String gameId,
    List<String> digits = const [],
    String number = '',
    String storeId = '',
    String cursor = '',
    String randomSeed = '',
    int limit = 20,
  }) {
    searchCount++;
    lastDigits = List<String>.from(digits);
    lastStoreId = storeId;
    lastCursor = cursor;
    lastRandomSeed = randomSeed;
    randomSeeds = [...randomSeeds, randomSeed];
    return _searchCompleter.future;
  }
}

class _DelayedNextPageLotteryRepository extends _FakeLotteryRepository {
  final _nextPageCompleter = Completer<LotteryStockPage>();

  void completeNextPage() {
    if (_nextPageCompleter.isCompleted) return;
    _nextPageCompleter.complete(
      LotteryStockPage(
        gameId: 'game_1',
        items: [
          _stockItem(number: '999999', localStockItemId: 'local-stock-2'),
        ],
        nextCursor: '',
        hasMore: false,
        sellerName: 'ร้านทดสอบ',
      ),
    );
  }

  @override
  Future<LotteryStockPage> search({
    required String gameId,
    List<String> digits = const [],
    String number = '',
    String storeId = '',
    String cursor = '',
    String randomSeed = '',
    int limit = 20,
  }) {
    searchCount++;
    lastDigits = List<String>.from(digits);
    lastStoreId = storeId;
    lastCursor = cursor;
    lastRandomSeed = randomSeed;
    randomSeeds = [...randomSeeds, randomSeed];
    if (cursor.isEmpty) {
      return Future.value(
        LotteryStockPage(
          gameId: gameId,
          items: [_stockItem()],
          nextCursor: 'cursor_1',
          hasMore: true,
          sellerName: 'ร้านทดสอบ',
        ),
      );
    }
    return _nextPageCompleter.future;
  }
}

class _DuplicateBrowseLotteryRepository extends _FakeLotteryRepository {
  @override
  Future<LotteryStockPage> search({
    required String gameId,
    List<String> digits = const [],
    String number = '',
    String storeId = '',
    String cursor = '',
    String randomSeed = '',
    int limit = 20,
  }) async {
    searchCount++;
    lastDigits = List<String>.from(digits);
    lastStoreId = storeId;
    lastCursor = cursor;
    lastRandomSeed = randomSeed;
    randomSeeds = [...randomSeeds, randomSeed];
    return LotteryStockPage(
      gameId: gameId,
      items: [
        _stockItem(number: '123123', localStockItemId: 'local-stock-1'),
        _stockItem(number: '123123', localStockItemId: 'local-stock-2'),
        _stockItem(number: '456456', localStockItemId: 'local-stock-3'),
      ],
      nextCursor: '',
      hasMore: false,
      sellerName: 'ร้านทดสอบ',
    );
  }
}

class _ClosedLotteryRepository extends _FakeLotteryRepository {
  @override
  Future<LotteryStockPage> search({
    required String gameId,
    List<String> digits = const [],
    String number = '',
    String storeId = '',
    String cursor = '',
    String randomSeed = '',
    int limit = 20,
  }) async {
    final page = await super.search(
      gameId: gameId,
      digits: digits,
      number: number,
      storeId: storeId,
      cursor: cursor,
      randomSeed: randomSeed,
      limit: limit,
    );
    return LotteryStockPage(
      gameId: page.gameId,
      items: page.items,
      nextCursor: page.nextCursor,
      hasMore: page.hasMore,
      sellerName: page.sellerName,
      canReserve: false,
    );
  }
}

DioException _apiException(String message) {
  final request = RequestOptions(path: '/public/stock/search');
  return DioException(
    requestOptions: request,
    response: Response<Map<String, dynamic>>(
      requestOptions: request,
      statusCode: 422,
      data: {'message': message},
    ),
  );
}

DioException _maintenanceApiException() {
  final request = RequestOptions(path: '/public/stock/search');
  return DioException(
    requestOptions: request,
    response: Response<Map<String, dynamic>>(
      requestOptions: request,
      statusCode: 503,
      data: const {
        'error': {
          'code': 'maintenance_active',
          'message': 'ระบบอยู่ระหว่างปิดปรับปรุง',
        },
      },
    ),
  );
}

ApiClient _testApiClient([AuthTokenStore? tokenStore]) {
  return ApiClient(
    _testConfig,
    tokenStore ?? AuthTokenStore(),
    localeTag: 'th-TH',
  );
}
