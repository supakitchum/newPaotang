import 'dart:async';

import 'package:customer_flutter/core/auth/auth_token_store.dart';
import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/i18n/app_locale.dart';
import 'package:customer_flutter/core/i18n/customer_localizations.dart';
import 'package:customer_flutter/core/navigation/customer_link_launcher.dart';
import 'package:customer_flutter/core/network/api_client.dart';
import 'package:customer_flutter/core/payment/checkout_payment_config.dart';
import 'package:customer_flutter/core/tenant/mobile_bootstrap_controller.dart';
import 'package:customer_flutter/core/theme/app_theme.dart';
import 'package:customer_flutter/features/affiliate/data/affiliate_referral_repository.dart';
import 'package:customer_flutter/features/lottery/data/lottery_models.dart';
import 'package:customer_flutter/features/lottery/data/lottery_repository.dart';
import 'package:customer_flutter/features/lottery/presentation/checkout_payment_method_provider.dart';
import 'package:customer_flutter/features/lottery/presentation/lottery_screens.dart';
import 'package:customer_flutter/features/lottery/presentation/lottery_stock_realtime_monitor.dart';
import 'package:customer_flutter/features/monitoring/data/public_visit_id_store.dart';
import 'package:customer_flutter/features/purchase_history/data/purchase_history_models.dart';
import 'package:customer_flutter/features/purchase_history/data/purchase_history_repository.dart';
import 'package:customer_flutter/features/results/data/result_models.dart';
import 'package:customer_flutter/features/results/data/result_repository.dart';
import 'package:customer_flutter/features/system/presentation/system_pages.dart';
import 'package:customer_flutter/features/wallet/data/wallet_models.dart';
import 'package:customer_flutter/features/wallet/data/wallet_repository.dart';
import 'package:customer_flutter/shared/widgets/customer_loading_indicator.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('checkout loading state uses Nuxt preparing copy', (
    tester,
  ) async {
    final cartCompleter = Completer<LotteryCart>();
    final router = GoRouter(
      initialLocation: '/checkout',
      routes: [
        GoRoute(
          path: '/checkout',
          builder: (context, state) => const CheckoutScreen(),
        ),
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('Home')),
        ),
        GoRoute(
          path: '/tickets',
          builder: (context, state) => const Scaffold(body: Text('Tickets')),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const Scaffold(body: Text('Profile')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mobileBootstrapProvider.overrideWith((_) async => _mobileBootstrap()),
          lotteryRepositoryProvider.overrideWithValue(
            _PendingCartLotteryRepository(cartCompleter.future),
          ),
          walletRepositoryProvider.overrideWithValue(
            _WalletRepository(balance: 240),
          ),
          affiliateReferralServiceProvider.overrideWithValue(
            _NoopAffiliateReferralService(),
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

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('ยืนยันการชำระเงิน'), findsOneWidget);
    expect(find.byType(CustomerLoadingMark), findsOneWidget);
    expect(find.text('กำลังเตรียมรายการชำระเงิน...'), findsWidgets);
    expect(tester.takeException(), isNull);

    cartCompleter.complete(await _CheckoutLotteryRepository().cart());
  });

  testWidgets('cart loading state uses Nuxt review copy', (
    tester,
  ) async {
    final cartCompleter = Completer<LotteryCart>();
    final router = GoRouter(
      initialLocation: '/cart',
      routes: [
        GoRoute(
          path: '/cart',
          builder: (context, state) => const CartScreen(),
        ),
        GoRoute(
          path: '/buy',
          builder: (context, state) => const Scaffold(body: Text('Buy')),
        ),
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('Home')),
        ),
        GoRoute(
          path: '/tickets',
          builder: (context, state) => const Scaffold(body: Text('Tickets')),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const Scaffold(body: Text('Profile')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          lotteryRepositoryProvider.overrideWithValue(
            _PendingCartLotteryRepository(cartCompleter.future),
          ),
          resultRepositoryProvider.overrideWithValue(_CartResultRepository()),
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

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(CustomerLoadingMark), findsOneWidget);
    expect(find.text('กำลังโหลดรายการสลากในตะกร้า...'), findsOneWidget);
    expect(tester.takeException(), isNull);

    cartCompleter.complete(await _CheckoutLotteryRepository().cart());
  });

  testWidgets('cart load failure shows API payload copy safely', (
    tester,
  ) async {
    await _pumpCartTest(
      tester,
      lottery: _FailingCartLotteryRepository(
        _apiException('ตะกร้าหมดอายุแล้ว กรุณาเลือกสลากใหม่'),
      ),
    );

    expect(
      find.text('ตะกร้าหมดอายุแล้ว กรุณาเลือกสลากใหม่'),
      findsOneWidget,
    );
    expect(find.text('กรุณาลองใหม่อีกครั้ง'), findsNothing);
  });

  testWidgets('cart load failure hides internal errors', (tester) async {
    await _pumpCartTest(
      tester,
      lottery: _FailingCartLotteryRepository(
        StateError('internal cart refresh failure'),
      ),
    );

    expect(find.text('โหลดตะกร้าไม่สำเร็จ'), findsOneWidget);
    expect(find.textContaining('internal cart refresh failure'), findsNothing);
  });

  testWidgets('checkout load failure shows API payload copy safely', (
    tester,
  ) async {
    await _pumpCheckoutPaymentTest(
      tester,
      lottery: _FailingCartLotteryRepository(
        _apiException('ไม่พบรายการชำระเงิน กรุณาเลือกสลากใหม่'),
      ),
    );

    expect(
      find.text('ไม่พบรายการชำระเงิน กรุณาเลือกสลากใหม่'),
      findsWidgets,
    );
    expect(find.text('กรุณาลองใหม่อีกครั้ง'), findsNothing);
  });

  testWidgets('checkout load failure hides internal errors', (tester) async {
    await _pumpCheckoutPaymentTest(
      tester,
      lottery: _FailingCartLotteryRepository(
        StateError('internal checkout cart failure'),
      ),
    );

    expect(find.text('โหลดข้อมูลไม่สำเร็จ'), findsOneWidget);
    expect(
      find.textContaining('internal checkout cart failure'),
      findsNothing,
    );
  });

  testWidgets('checkout wallet load failure shows API payload copy safely', (
    tester,
  ) async {
    await _pumpCheckoutPaymentTest(
      tester,
      lottery: _CheckoutLotteryRepository(),
      walletRepository: _FailingWalletRepository(
        _apiException('ไม่สามารถโหลดกระเป๋าเงินสำหรับรายการนี้ได้'),
      ),
    );

    expect(
      find.text('ไม่สามารถโหลดกระเป๋าเงินสำหรับรายการนี้ได้'),
      findsOneWidget,
    );
    expect(find.text('โหลดกระเป๋าเงินไม่สำเร็จ'), findsNothing);
  });

  testWidgets('checkout shows the selected wallet payment method card', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final lottery = _CheckoutLotteryRepository();
    final router = GoRouter(
      initialLocation: '/checkout',
      routes: [
        GoRoute(
          path: '/checkout',
          builder: (context, state) => const CheckoutScreen(),
        ),
        GoRoute(
          path: '/topup',
          builder: (context, state) => Scaffold(
            body: Text('topup:${state.uri.queryParameters['back']}'),
          ),
        ),
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('Home')),
        ),
        GoRoute(
          path: '/tickets',
          builder: (context, state) => const Scaffold(body: Text('Tickets')),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const Scaffold(body: Text('Profile')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mobileBootstrapProvider.overrideWith((_) async => _mobileBootstrap()),
          lotteryRepositoryProvider.overrideWithValue(lottery),
          walletRepositoryProvider.overrideWithValue(
            _WalletRepository(balance: 240),
          ),
          affiliateReferralServiceProvider.overrideWithValue(
            _NoopAffiliateReferralService(),
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

    await tester.pumpAndSettle();

    expect(find.text('ช่องทางชำระเงิน'), findsOneWidget);
    final paymentSectionHeader = find.byKey(
      const ValueKey('checkout-payment-method-section-header'),
    );
    expect(paymentSectionHeader, findsOneWidget);
    final paymentSectionHeaderBox =
        tester.widget<ColoredBox>(paymentSectionHeader);
    final paymentSectionHeaderTheme =
        Theme.of(tester.element(paymentSectionHeader));
    expect(
      paymentSectionHeaderBox.color,
      paymentSectionHeaderTheme.colorScheme.surfaceContainerHighest.withValues(
        alpha: 0.48,
      ),
    );
    final summaryCard = find.byKey(const ValueKey('checkout-summary-card'));
    expect(summaryCard, findsOneWidget);
    final summaryDecoration =
        tester.widget<DecoratedBox>(summaryCard).decoration as BoxDecoration;
    expect(summaryDecoration.borderRadius, BorderRadius.circular(12));
    expect(find.text('สลากกินแบ่งรัฐบาล'), findsOneWidget);
    expect(find.text('จำนวนสลากฯ'), findsOneWidget);
    expect(find.text('ยอดชำระทั้งหมด'), findsOneWidget);
    final summaryTotalRow = find.byKey(
      const ValueKey('checkout-summary-total-row'),
    );
    expect(summaryTotalRow, findsOneWidget);
    final summaryTotalAmount = tester.widget<Text>(
      find.byKey(const ValueKey('checkout-summary-total-amount')),
    );
    final summaryTotalUnit = tester.widget<Text>(
      find.byKey(const ValueKey('checkout-summary-total-unit')),
    );
    expect(summaryTotalAmount.data, '80');
    expect(summaryTotalUnit.data, 'บาท');
    expect(
      find.descendant(of: summaryTotalRow, matching: find.text('80 บาท')),
      findsNothing,
    );
    expect(find.text('273707'), findsNothing);
    expect(find.text('G Wallet'), findsOneWidget);
    expect(
      find.text(
        'คุณสามารถยืนยันชำระเงินเพื่อใช้บัญชีที่ผูกไว้ชำระเงินค่าสลากได้อัตโนมัติ',
      ),
      findsOneWidget,
    );
    expect(find.widgetWithText(OutlinedButton, 'เติมเงิน'), findsOneWidget);
    final walletOption = find.byKey(
      const ValueKey('checkout-payment-method-option-wallet'),
    );
    expect(walletOption, findsOneWidget);
    final walletOptionDecoration =
        tester.widget<DecoratedBox>(walletOption).decoration as BoxDecoration;
    expect(walletOptionDecoration.borderRadius, BorderRadius.circular(12));
    final walletNote = tester.widget<Container>(
      find.descendant(
        of: walletOption,
        matching: find.byKey(
          const ValueKey('checkout-payment-method-note-wallet'),
        ),
      ),
    );
    final walletNoteDecoration = walletNote.decoration as BoxDecoration;
    expect(
      walletNoteDecoration.color,
      AppTheme.appCheckoutWalletNoteFill,
    );
    expect(
      find.descendant(
        of: walletOption,
        matching: find.byIcon(Icons.check_circle),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: walletOption,
        matching: find.byIcon(Icons.radio_button_checked),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: walletOption,
        matching: find.byIcon(Icons.account_balance_wallet_outlined),
      ),
      findsNothing,
    );
    final walletMark = tester.widget<Text>(
      find.byKey(const ValueKey('checkout-wallet-method-mark')),
    );
    expect(walletMark.data, 'G');

    final paymentDock = find.byKey(const ValueKey('checkout-payment-dock'));
    expect(paymentDock, findsOneWidget);
    final checkoutDockDecoration =
        tester.widget<DecoratedBox>(paymentDock).decoration as BoxDecoration;
    expect(
      checkoutDockDecoration.borderRadius,
      const BorderRadius.vertical(top: Radius.circular(16)),
    );
    expect(find.byKey(const Key('customer_bottom_nav')), findsNothing);
    final dockBottom = tester.getBottomLeft(paymentDock).dy;
    expect(dockBottom, greaterThan(640));
    expect(
      find.descendant(
        of: paymentDock,
        matching: find.textContaining('กรุณาชำระเงินภายใน'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: paymentDock,
        matching: find.widgetWithText(FilledButton, 'ยืนยันชำระเงิน'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: paymentDock,
        matching: find.byIcon(Icons.check_circle_outline),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);

    final topupButton = find.widgetWithText(OutlinedButton, 'เติมเงิน');
    await _tapVisibleAboveDock(tester, topupButton);

    expect(lottery.checkoutReservationIds, isEmpty);
    expect(find.text('topup:/checkout'), findsOneWidget);
  });

  testWidgets('checkout keeps payment surface visible while wallet loads', (
    tester,
  ) async {
    final walletCompleter = Completer<WalletSummary>();
    final lottery = _CheckoutLotteryRepository();
    final router = GoRouter(
      initialLocation: '/checkout',
      routes: [
        GoRoute(
          path: '/checkout',
          builder: (context, state) => const CheckoutScreen(),
        ),
        GoRoute(
          path: '/topup',
          builder: (context, state) => const Scaffold(body: Text('Topup')),
        ),
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('Home')),
        ),
        GoRoute(
          path: '/tickets',
          builder: (context, state) => const Scaffold(body: Text('Tickets')),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const Scaffold(body: Text('Profile')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mobileBootstrapProvider.overrideWith((_) async => _mobileBootstrap()),
          lotteryRepositoryProvider.overrideWithValue(lottery),
          walletRepositoryProvider.overrideWithValue(
            _PendingWalletRepository(walletCompleter.future),
          ),
          affiliateReferralServiceProvider.overrideWithValue(
            _NoopAffiliateReferralService(),
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

    await tester.pump();
    await tester.pump();

    expect(find.text('กำลังเตรียมรายการชำระเงิน...'), findsNothing);
    expect(find.text('ช่องทางชำระเงิน'), findsOneWidget);
    expect(find.text('สลากกินแบ่งรัฐบาล'), findsOneWidget);
    expect(find.text('กำลังโหลดกระเป๋าเงิน...'), findsWidgets);
    expect(find.byKey(const ValueKey('checkout-payment-dock')), findsOneWidget);
    final loadingConfirm = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'กำลังโหลดกระเป๋าเงิน...'),
    );
    expect(loadingConfirm.onPressed, isNull);

    walletCompleter.complete(
      const WalletSummary(
        wallets: [
          CustomerWallet(
            id: 'wallet_1',
            name: 'G Wallet',
            type: '1',
            balance: 240,
          ),
        ],
        ledger: [],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('กำลังโหลดกระเป๋าเงิน...'), findsNothing);
    expect(find.text('240.00 บาท'), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, 'ยืนยันชำระเงิน'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'checkout wallet card handles long runtime wallet names on mobile',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final lottery = _CheckoutLotteryRepository();
    final router = GoRouter(
      initialLocation: '/checkout',
      routes: [
        GoRoute(
          path: '/checkout',
          builder: (context, state) => const CheckoutScreen(),
        ),
        GoRoute(
          path: '/topup',
          builder: (context, state) => Scaffold(
            body: Text('topup:${state.uri.queryParameters['back']}'),
          ),
        ),
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('Home')),
        ),
        GoRoute(
          path: '/tickets',
          builder: (context, state) => const Scaffold(body: Text('Tickets')),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const Scaffold(body: Text('Profile')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mobileBootstrapProvider.overrideWith((_) async => _mobileBootstrap()),
          lotteryRepositoryProvider.overrideWithValue(lottery),
          walletRepositoryProvider.overrideWithValue(
            _WalletRepository(
              balance: 240,
              walletName:
                  'G Wallet บัญชีหลักสำหรับชำระเงินค่าสลากประจำครอบครัว',
            ),
          ),
          affiliateReferralServiceProvider.overrideWithValue(
            _NoopAffiliateReferralService(),
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

    await tester.pumpAndSettle();

    expect(
      find.text('G Wallet บัญชีหลักสำหรับชำระเงินค่าสลากประจำครอบครัว'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('checkout-payment-dock')), findsOneWidget);
    expect(find.byKey(const Key('customer_bottom_nav')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('checkout uses wallet payment method and nested order id', (
    tester,
  ) async {
    final lottery = _CheckoutLotteryRepository();
    final affiliate = _NoopAffiliateReferralService();
    final router = GoRouter(
      initialLocation: '/checkout',
      routes: [
        GoRoute(
          path: '/checkout',
          builder: (context, state) => const CheckoutScreen(),
        ),
        GoRoute(
          path: '/checkout/pending',
          builder: (context, state) => CheckoutPendingPaymentScreen(
            orderId: state.uri.queryParameters['order_id'] ?? '',
          ),
        ),
        GoRoute(
          path: '/success',
          builder: (context, state) => Scaffold(
            body: Center(
              child: Text('success:${state.uri.queryParameters['order_id']}'),
            ),
          ),
        ),
        GoRoute(
          path: '/topup',
          builder: (context, state) => const Scaffold(body: Text('Topup')),
        ),
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('Home')),
        ),
        GoRoute(
          path: '/tickets',
          builder: (context, state) => const Scaffold(body: Text('Tickets')),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const Scaffold(body: Text('Profile')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mobileBootstrapProvider.overrideWith((_) async => _mobileBootstrap()),
          lotteryRepositoryProvider.overrideWithValue(lottery),
          walletRepositoryProvider.overrideWithValue(
            _WalletRepository(balance: 240),
          ),
          affiliateReferralServiceProvider.overrideWithValue(affiliate),
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

    await tester.pumpAndSettle();
    expect(find.text('ยืนยันชำระเงิน'), findsOneWidget);

    await _submitCheckoutPayment(tester);

    expect(affiliate.applied, isTrue);
    expect(lottery.checkoutReservationIds, ['res_1']);
    expect(lottery.checkoutPaymentMethod, checkoutPaymentMethodWallet);
    expect(find.text('success:ord_nested'), findsOneWidget);
  });

  testWidgets('checkout accepts legacy Nuxt cart order payloads', (
    tester,
  ) async {
    final lottery = _LegacyCartOrderLotteryRepository();
    final router = await _pumpCheckoutPaymentTest(
      tester,
      lottery: lottery,
    );

    expect(find.text('ยืนยันการชำระเงิน'), findsOneWidget);
    expect(find.text('จำนวนสลากฯ'), findsOneWidget);
    expect(find.text('2 ใบ'), findsOneWidget);
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('checkout-summary-total-amount')),
          )
          .data,
      '160',
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('checkout-summary-total-unit')),
          )
          .data,
      'บาท',
    );

    await _submitCheckoutPayment(tester);

    expect(lottery.checkoutReservationIds, ['res_legacy_1', 'res_legacy_2']);
    expect(lottery.checkoutPaymentMethod, checkoutPaymentMethodWallet);
    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/success?order_id=ord_nested',
    );
  });

  testWidgets('checkout shows API error copy on payment failure like Nuxt', (
    tester,
  ) async {
    final lottery = _CheckoutLotteryRepository(
      checkoutError: _apiException('รายการชำระเงินหมดอายุแล้ว'),
    );
    final router = await _pumpCheckoutPaymentTest(
      tester,
      lottery: lottery,
    );

    await _submitCheckoutPayment(tester);

    expect(lottery.checkoutReservationIds, ['res_1']);
    expect(find.text('รายการชำระเงินหมดอายุแล้ว'), findsOneWidget);
    expect(find.text('ชำระเงินไม่สำเร็จ'), findsNothing);
    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/checkout',
    );
  });

  testWidgets('checkout falls back for internal payment errors', (
    tester,
  ) async {
    final lottery = _CheckoutLotteryRepository(
      checkoutError: StateError('internal checkout failure'),
    );
    final router = await _pumpCheckoutPaymentTest(
      tester,
      lottery: lottery,
    );

    await _submitCheckoutPayment(tester);

    expect(lottery.checkoutReservationIds, ['res_1']);
    expect(find.text('ชำระเงินไม่สำเร็จ'), findsOneWidget);
    expect(find.textContaining('internal checkout failure'), findsNothing);
    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/checkout',
    );
  });

  testWidgets(
      'checkout success keeps Nuxt-style receipt fallback on load error', (
    tester,
  ) async {
    final lottery = _CheckoutLotteryRepository();
    final router = GoRouter(
      initialLocation: '/checkout',
      routes: [
        GoRoute(
          path: '/checkout',
          builder: (context, state) => const CheckoutScreen(),
        ),
        GoRoute(
          path: '/success',
          builder: (context, state) => SuccessScreen(
            orderId: state.uri.queryParameters['order_id'],
          ),
        ),
        GoRoute(
          path: '/topup',
          builder: (context, state) => const Scaffold(body: Text('Topup')),
        ),
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('Home')),
        ),
        GoRoute(
          path: '/tickets',
          builder: (context, state) => const Scaffold(body: Text('Tickets')),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const Scaffold(body: Text('Profile')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mobileBootstrapProvider.overrideWith((_) async => _mobileBootstrap()),
          lotteryRepositoryProvider.overrideWithValue(lottery),
          walletRepositoryProvider.overrideWithValue(
            _WalletRepository(balance: 240),
          ),
          affiliateReferralServiceProvider.overrideWithValue(
            _NoopAffiliateReferralService(),
          ),
          purchaseHistoryDetailProvider('ord_nested').overrideWith(
            (_) async => throw StateError('receipt unavailable'),
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

    await tester.pumpAndSettle();

    await _submitCheckoutPayment(tester);

    expect(lottery.checkoutReservationIds, ['res_1']);
    expect(find.text('ซื้อสลากหกหลักแบบดิจิทัลสำเร็จ'), findsOneWidget);
    expect(find.text('จำนวนสลากฯ'), findsOneWidget);
    expect(find.text('1 ใบ'), findsOneWidget);
    expect(find.text('ยอดชำระทั้งหมด'), findsOneWidget);
    expect(find.text('80.00'), findsOneWidget);
    expect(find.text('บาท'), findsWidgets);
    expect(find.textContaining('ORDER-NESTED'), findsOneWidget);
    expect(find.text('โหลดข้อมูลการชำระเงินไม่สำเร็จ'), findsNothing);
  });

  testWidgets('checkout external payment is selectable without wallet balance',
      (
    tester,
  ) async {
    final lottery = _CheckoutLotteryRepository(
      redirectUrl: 'https://pay.example.test/session/ord_nested',
    );
    final launcher = _RecordingLinkLauncher();
    final router = GoRouter(
      initialLocation: '/checkout',
      routes: [
        GoRoute(
          path: '/checkout',
          builder: (context, state) => const CheckoutScreen(),
        ),
        GoRoute(
          path: '/checkout/pending',
          builder: (context, state) => CheckoutPendingPaymentScreen(
            orderId: state.uri.queryParameters['order_id'] ?? '',
          ),
        ),
        GoRoute(
          path: '/success',
          builder: (context, state) => Scaffold(
            body: Center(
              child: Text('success:${state.uri.queryParameters['order_id']}'),
            ),
          ),
        ),
        GoRoute(
          path: '/topup',
          builder: (context, state) => const Scaffold(body: Text('Topup')),
        ),
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('Home')),
        ),
        GoRoute(
          path: '/tickets',
          builder: (context, state) => const Scaffold(body: Text('Tickets')),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const Scaffold(body: Text('Profile')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mobileBootstrapProvider.overrideWith((_) async => _mobileBootstrap()),
          lotteryRepositoryProvider.overrideWithValue(lottery),
          walletRepositoryProvider
              .overrideWithValue(_WalletRepository(balance: 20)),
          affiliateReferralServiceProvider.overrideWithValue(
            _NoopAffiliateReferralService(),
          ),
          customerLinkLauncherProvider.overrideWithValue(launcher),
          purchaseHistoryDetailProvider('ord_nested').overrideWith(
            (_) async => PurchaseHistoryOrder.fromJson({
              'id': 'ord_nested',
              'reference': 'PAY-ORDER-NESTED',
              'status': 'pending_payment',
              'payment_status': 'pending_payment',
              'payment_method': checkoutPaymentMethodExternalPayment,
              'total': {'amount': 8000, 'currency': 'THB'},
              'ticket_count': 1,
              'redirect_url': 'https://pay.example.test/session/ord_nested',
            }),
          ),
          checkoutPaymentMethodProvider.overrideWithValue(
            checkoutPaymentMethodWallet,
          ),
          checkoutPaymentMethodsProvider.overrideWithValue(const [
            checkoutPaymentMethodWallet,
            checkoutPaymentMethodExternalPayment,
          ]),
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

    await tester.pumpAndSettle();

    expect(find.text('ยอดเงินไม่เพียงพอ'), findsWidgets);
    expect(find.text('ชำระผ่านผู้ให้บริการภายนอก'), findsOneWidget);

    final externalOption = find.text('ชำระผ่านผู้ให้บริการภายนอก');
    await _tapVisibleAboveDock(tester, externalOption);

    expect(find.text('ยืนยันชำระเงิน'), findsOneWidget);

    await _submitCheckoutPayment(tester);

    expect(lottery.checkoutPaymentMethod, checkoutPaymentMethodExternalPayment);
    expect(
      launcher.openedUri,
      Uri.parse('https://pay.example.test/session/ord_nested'),
    );
    expect(find.text('รอชำระเงิน'), findsWidgets);
    expect(find.text('PAY-ORDER-NESTED'), findsOneWidget);
    expect(find.text('เปิดหน้าชำระเงิน'), findsOneWidget);
    expect(find.byKey(const Key('customer_bottom_nav')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('checkout external payment can submit while wallet is loading', (
    tester,
  ) async {
    final walletCompleter = Completer<WalletSummary>();
    final lottery = _CheckoutLotteryRepository(
      redirectUrl: 'https://pay.example.test/session/ord_nested',
    );
    final launcher = _RecordingLinkLauncher();
    final router = GoRouter(
      initialLocation: '/checkout',
      routes: [
        GoRoute(
          path: '/checkout',
          builder: (context, state) => const CheckoutScreen(),
        ),
        GoRoute(
          path: '/checkout/pending',
          builder: (context, state) => Scaffold(
            body: Text('pending:${state.uri.queryParameters['order_id']}'),
          ),
        ),
        GoRoute(
          path: '/topup',
          builder: (context, state) => const Scaffold(body: Text('Topup')),
        ),
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('Home')),
        ),
        GoRoute(
          path: '/tickets',
          builder: (context, state) => const Scaffold(body: Text('Tickets')),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const Scaffold(body: Text('Profile')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mobileBootstrapProvider.overrideWith((_) async => _mobileBootstrap()),
          lotteryRepositoryProvider.overrideWithValue(lottery),
          walletRepositoryProvider.overrideWithValue(
            _PendingWalletRepository(walletCompleter.future),
          ),
          affiliateReferralServiceProvider.overrideWithValue(
            _NoopAffiliateReferralService(),
          ),
          customerLinkLauncherProvider.overrideWithValue(launcher),
          checkoutPaymentMethodProvider.overrideWithValue(
            checkoutPaymentMethodWallet,
          ),
          checkoutPaymentMethodsProvider.overrideWithValue(const [
            checkoutPaymentMethodWallet,
            checkoutPaymentMethodExternalPayment,
          ]),
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

    await tester.pump();
    await tester.pump();

    expect(find.text('กำลังโหลดกระเป๋าเงิน...'), findsWidgets);
    expect(find.text('ชำระผ่านผู้ให้บริการภายนอก'), findsOneWidget);

    final externalOption = find.text('ชำระผ่านผู้ให้บริการภายนอก');
    await _tapVisibleAboveDock(tester, externalOption);

    expect(find.text('กำลังโหลดกระเป๋าเงิน...'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'ยืนยันชำระเงิน'), findsOneWidget);

    await _submitCheckoutPayment(tester);

    expect(lottery.checkoutPaymentMethod, checkoutPaymentMethodExternalPayment);
    expect(
      launcher.openedUri,
      Uri.parse('https://pay.example.test/session/ord_nested'),
    );
    expect(find.text('pending:ord_nested'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'checkout external payment continues to pending if link open fails', (
    tester,
  ) async {
    final lottery = _CheckoutLotteryRepository(
      redirectUrl: 'https://pay.example.test/session/ord_nested',
    );
    final launcher = _RecordingLinkLauncher(openError: Exception('blocked'));
    final router = GoRouter(
      initialLocation: '/checkout',
      routes: [
        GoRoute(
          path: '/checkout',
          builder: (context, state) => const CheckoutScreen(),
        ),
        GoRoute(
          path: '/checkout/pending',
          builder: (context, state) => Scaffold(
            body: Text('pending:${state.uri.queryParameters['order_id']}'),
          ),
        ),
        GoRoute(
          path: '/topup',
          builder: (context, state) => const Scaffold(body: Text('Topup')),
        ),
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('Home')),
        ),
        GoRoute(
          path: '/tickets',
          builder: (context, state) => const Scaffold(body: Text('Tickets')),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const Scaffold(body: Text('Profile')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mobileBootstrapProvider.overrideWith((_) async => _mobileBootstrap()),
          lotteryRepositoryProvider.overrideWithValue(lottery),
          walletRepositoryProvider.overrideWithValue(
            _WalletRepository(balance: 20),
          ),
          affiliateReferralServiceProvider.overrideWithValue(
            _NoopAffiliateReferralService(),
          ),
          customerLinkLauncherProvider.overrideWithValue(launcher),
          checkoutPaymentMethodProvider.overrideWithValue(
            checkoutPaymentMethodWallet,
          ),
          checkoutPaymentMethodsProvider.overrideWithValue(const [
            checkoutPaymentMethodWallet,
            checkoutPaymentMethodExternalPayment,
          ]),
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

    await tester.pumpAndSettle();

    final externalOption = find.text('ชำระผ่านผู้ให้บริการภายนอก');
    await _tapVisibleAboveDock(tester, externalOption);

    await _submitCheckoutPayment(tester);

    expect(lottery.checkoutPaymentMethod, checkoutPaymentMethodExternalPayment);
    expect(
      launcher.openedUri,
      Uri.parse('https://pay.example.test/session/ord_nested'),
    );
    expect(find.text('pending:ord_nested'), findsOneWidget);
    expect(find.text('ชำระเงินไม่สำเร็จ'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('checkout external-only config skips wallet summary load', (
    tester,
  ) async {
    final lottery = _CheckoutLotteryRepository(
      redirectUrl: 'https://pay.example.test/session/ord_nested',
    );
    final wallet = _CountingWalletRepository();
    final launcher = _RecordingLinkLauncher();
    final router = GoRouter(
      initialLocation: '/checkout',
      routes: [
        GoRoute(
          path: '/checkout',
          builder: (context, state) => const CheckoutScreen(),
        ),
        GoRoute(
          path: '/checkout/pending',
          builder: (context, state) => Scaffold(
            body: Text('pending:${state.uri.queryParameters['order_id']}'),
          ),
        ),
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('Home')),
        ),
        GoRoute(
          path: '/tickets',
          builder: (context, state) => const Scaffold(body: Text('Tickets')),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const Scaffold(body: Text('Profile')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mobileBootstrapProvider.overrideWith((_) async => _mobileBootstrap()),
          lotteryRepositoryProvider.overrideWithValue(lottery),
          walletRepositoryProvider.overrideWithValue(wallet),
          affiliateReferralServiceProvider.overrideWithValue(
            _NoopAffiliateReferralService(),
          ),
          customerLinkLauncherProvider.overrideWithValue(launcher),
          checkoutPaymentMethodProvider.overrideWithValue(
            checkoutPaymentMethodExternalPayment,
          ),
          checkoutPaymentMethodsProvider.overrideWithValue(const [
            checkoutPaymentMethodExternalPayment,
          ]),
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

    await tester.pumpAndSettle();

    expect(wallet.summaryCalls, 0);
    expect(find.text('G Wallet'), findsNothing);
    expect(find.text('เติมเงิน'), findsNothing);
    expect(find.text('ชำระผ่านผู้ให้บริการภายนอก'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'ยืนยันชำระเงิน'), findsOneWidget);

    await _submitCheckoutPayment(tester);

    expect(wallet.summaryCalls, 0);
    expect(lottery.checkoutPaymentMethod, checkoutPaymentMethodExternalPayment);
    expect(
      launcher.openedUri,
      Uri.parse('https://pay.example.test/session/ord_nested'),
    );
    expect(find.text('pending:ord_nested'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('checkout pending loading uses focused payment surface', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final orderCompleter = Completer<PurchaseHistoryOrder>();
    final router = GoRouter(
      initialLocation: '/checkout/pending?order_id=ord_pending',
      routes: [
        GoRoute(
          path: '/checkout/pending',
          builder: (context, state) => CheckoutPendingPaymentScreen(
            orderId: state.uri.queryParameters['order_id'] ?? '',
          ),
        ),
        GoRoute(
          path: '/checkout',
          builder: (context, state) => const CheckoutScreen(),
        ),
        GoRoute(
          path: '/buy',
          builder: (context, state) => const Scaffold(body: Text('Buy')),
        ),
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('Home')),
        ),
        GoRoute(
          path: '/tickets',
          builder: (context, state) => const Scaffold(body: Text('Tickets')),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const Scaffold(body: Text('Profile')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          purchaseHistoryDetailProvider('ord_pending').overrideWith(
            (_) => orderCompleter.future,
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

    await tester.pump();

    expect(find.byType(CheckoutPendingPaymentScreen), findsOneWidget);
    expect(find.text('กำลังตรวจสอบสถานะการชำระเงิน...'), findsOneWidget);
    expect(find.byType(CustomerLoadingMark), findsOneWidget);
    expect(find.byKey(const Key('customer_bottom_nav')), findsNothing);
    expect(tester.takeException(), isNull);

    orderCompleter.complete(
      PurchaseHistoryOrder.fromJson({
        'id': 'ord_pending',
        'reference': 'PAY-ORDER-PENDING',
        'status': 'pending_payment',
        'payment_status': 'pending_payment',
        'payment_method': checkoutPaymentMethodExternalPayment,
        'total': {'amount': 8000, 'currency': 'THB'},
        'ticket_count': 1,
        'redirect_url': 'https://pay.example.test/session/ord_pending',
      }),
    );
  });

  testWidgets('checkout pending without order id returns to buy', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/checkout/pending',
      routes: [
        GoRoute(
          path: '/checkout/pending',
          builder: (context, state) => CheckoutPendingPaymentScreen(
            orderId: state.uri.queryParameters['order_id'] ?? '',
          ),
        ),
        GoRoute(
          path: '/checkout',
          builder: (context, state) => const CheckoutScreen(),
        ),
        GoRoute(
          path: '/buy',
          builder: (context, state) => const Scaffold(body: Text('Buy route')),
        ),
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('Home')),
        ),
        GoRoute(
          path: '/tickets',
          builder: (context, state) => const Scaffold(body: Text('Tickets')),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const Scaffold(body: Text('Profile')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
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

    await tester.pumpAndSettle();

    expect(find.byType(CheckoutPendingPaymentScreen), findsOneWidget);
    expect(find.text('ไม่พบรายการรอชำระ'), findsOneWidget);
    expect(
      find.text('กรุณากลับไปหน้าชำระเงินหรือเลือกสลากใหม่อีกครั้ง'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('customer_bottom_nav')), findsNothing);

    await tester.tap(find.widgetWithText(OutlinedButton, 'กลับไปเลือกสลาก'));
    await tester.pumpAndSettle();

    expect(find.text('Buy route'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('checkout pending load error shows API payload and retries', (
    tester,
  ) async {
    var loads = 0;
    final router = GoRouter(
      initialLocation: '/checkout/pending?order_id=ord_retry',
      routes: [
        GoRoute(
          path: '/checkout/pending',
          builder: (context, state) => CheckoutPendingPaymentScreen(
            orderId: state.uri.queryParameters['order_id'] ?? '',
          ),
        ),
        GoRoute(
          path: '/checkout',
          builder: (context, state) => const CheckoutScreen(),
        ),
        GoRoute(
          path: '/buy',
          builder: (context, state) => const Scaffold(body: Text('Buy')),
        ),
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('Home')),
        ),
        GoRoute(
          path: '/tickets',
          builder: (context, state) => const Scaffold(body: Text('Tickets')),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const Scaffold(body: Text('Profile')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          purchaseHistoryDetailProvider('ord_retry').overrideWith((_) async {
            loads++;
            if (loads == 1) {
              throw _apiException(
                'ไม่สามารถตรวจสอบสถานะการชำระเงินได้',
                path: '/customer/orders/ord_retry',
              );
            }
            return PurchaseHistoryOrder.fromJson({
              'id': 'ord_retry',
              'reference': 'PAY-ORDER-RETRY',
              'status': 'pending_payment',
              'payment_status': 'pending_payment',
              'payment_method': checkoutPaymentMethodExternalPayment,
              'total': {'amount': 8000, 'currency': 'THB'},
              'ticket_count': 1,
              'redirect_url': 'https://pay.example.test/session/ord_retry',
            });
          }),
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

    await tester.pumpAndSettle();

    expect(loads, 1);
    expect(find.text('โหลดข้อมูลไม่สำเร็จ'), findsOneWidget);
    expect(
      find.text('ไม่สามารถตรวจสอบสถานะการชำระเงินได้'),
      findsOneWidget,
    );
    expect(find.text('กรุณาลองใหม่อีกครั้ง'), findsNothing);
    expect(find.byKey(const Key('customer_bottom_nav')), findsNothing);

    await tester.tap(find.widgetWithText(OutlinedButton, 'ลองใหม่'));
    await tester.pumpAndSettle();

    expect(loads, 2);
    expect(find.text('PAY-ORDER-RETRY'), findsOneWidget);
    expect(find.text('รอชำระ'), findsOneWidget);
    expect(find.text('เปิดหน้าชำระเงิน'), findsOneWidget);
    expect(find.byIcon(Icons.open_in_new), findsNothing);
    expect(find.byIcon(Icons.refresh), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('checkout pending paid order continues to success receipt', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/checkout/pending?order_id=ord_paid',
      routes: [
        GoRoute(
          path: '/checkout/pending',
          builder: (context, state) => CheckoutPendingPaymentScreen(
            orderId: state.uri.queryParameters['order_id'] ?? '',
          ),
        ),
        GoRoute(
          path: '/success',
          builder: (context, state) => Scaffold(
            body: Text('success:${state.uri.queryParameters['order_id']}'),
          ),
        ),
        GoRoute(
          path: '/checkout',
          builder: (context, state) => const CheckoutScreen(),
        ),
        GoRoute(
          path: '/buy',
          builder: (context, state) => const Scaffold(body: Text('Buy')),
        ),
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('Home')),
        ),
        GoRoute(
          path: '/tickets',
          builder: (context, state) => const Scaffold(body: Text('Tickets')),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const Scaffold(body: Text('Profile')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          purchaseHistoryDetailProvider('ord_paid').overrideWith(
            (_) async => PurchaseHistoryOrder.fromJson({
              'id': 'ord_paid',
              'reference': 'PAY-ORDER-PAID',
              'status': 'paid',
              'payment_status': 'paid',
              'payment_method': checkoutPaymentMethodExternalPayment,
              'total': {'amount': 8000, 'currency': 'THB'},
              'ticket_count': 1,
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

    await tester.pumpAndSettle();

    expect(find.text('success:ord_paid'), findsOneWidget);
    expect(find.byType(CheckoutPendingPaymentScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('checkout pending failed order stays on payment surface', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/checkout/pending?order_id=ord_failed',
      routes: [
        GoRoute(
          path: '/checkout/pending',
          builder: (context, state) => CheckoutPendingPaymentScreen(
            orderId: state.uri.queryParameters['order_id'] ?? '',
          ),
        ),
        GoRoute(
          path: '/success',
          builder: (context, state) => Scaffold(
            body: Text('success:${state.uri.queryParameters['order_id']}'),
          ),
        ),
        GoRoute(
          path: '/checkout',
          builder: (context, state) => const CheckoutScreen(),
        ),
        GoRoute(
          path: '/buy',
          builder: (context, state) => const Scaffold(body: Text('Buy')),
        ),
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('Home')),
        ),
        GoRoute(
          path: '/tickets',
          builder: (context, state) => const Scaffold(body: Text('Tickets')),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const Scaffold(body: Text('Profile')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          purchaseHistoryDetailProvider('ord_failed').overrideWith(
            (_) async => PurchaseHistoryOrder.fromJson({
              'id': 'ord_failed',
              'reference': 'PAY-ORDER-FAILED',
              'status': 'failed',
              'payment_status': 'failed',
              'payment_method': checkoutPaymentMethodExternalPayment,
              'total': {'amount': 8000, 'currency': 'THB'},
              'ticket_count': 1,
              'redirect_url': 'https://pay.example.test/session/ord_failed',
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

    await tester.pumpAndSettle();

    expect(find.byType(CheckoutPendingPaymentScreen), findsOneWidget);
    expect(find.text('success:ord_failed'), findsNothing);
    expect(find.text('PAY-ORDER-FAILED'), findsOneWidget);
    expect(find.text('ชำระไม่สำเร็จ'), findsOneWidget);
    expect(find.text('เปิดหน้าชำระเงิน'), findsOneWidget);
    expect(find.text('ดูใบเสร็จ'), findsNothing);
    expect(find.byIcon(Icons.open_in_new), findsNothing);
    expect(find.byIcon(Icons.refresh), findsNothing);
    expect(find.byKey(const Key('customer_bottom_nav')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('checkout pending expired order stays off success receipt', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/checkout/pending?order_id=ord_expired',
      routes: [
        GoRoute(
          path: '/checkout/pending',
          builder: (context, state) => CheckoutPendingPaymentScreen(
            orderId: state.uri.queryParameters['order_id'] ?? '',
          ),
        ),
        GoRoute(
          path: '/success',
          builder: (context, state) => Scaffold(
            body: Text('success:${state.uri.queryParameters['order_id']}'),
          ),
        ),
        GoRoute(
          path: '/checkout',
          builder: (context, state) => const CheckoutScreen(),
        ),
        GoRoute(
          path: '/buy',
          builder: (context, state) => const Scaffold(body: Text('Buy')),
        ),
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('Home')),
        ),
        GoRoute(
          path: '/tickets',
          builder: (context, state) => const Scaffold(body: Text('Tickets')),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const Scaffold(body: Text('Profile')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          purchaseHistoryDetailProvider('ord_expired').overrideWith(
            (_) async => PurchaseHistoryOrder.fromJson({
              'id': 'ord_expired',
              'reference': 'PAY-ORDER-EXPIRED',
              'status': 'expired',
              'payment_status': 'expired',
              'payment_method': checkoutPaymentMethodExternalPayment,
              'total': {'amount': 8000, 'currency': 'THB'},
              'ticket_count': 1,
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

    await tester.pumpAndSettle();

    expect(find.byType(CheckoutPendingPaymentScreen), findsOneWidget);
    expect(find.text('success:ord_expired'), findsNothing);
    expect(find.text('PAY-ORDER-EXPIRED'), findsOneWidget);
    expect(find.text('หมดอายุ'), findsOneWidget);
    expect(find.text('เปิดหน้าชำระเงิน'), findsNothing);
    expect(find.text('ดูใบเสร็จ'), findsNothing);
    expect(find.text('ตรวจสอบสถานะอีกครั้ง'), findsOneWidget);
    expect(find.byIcon(Icons.refresh), findsNothing);
    expect(find.byKey(const Key('customer_bottom_nav')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'checkout keeps external payment available when wallet load fails', (
    tester,
  ) async {
    final lottery = _CheckoutLotteryRepository(
      redirectUrl: 'https://pay.example.test/session/ord_nested',
    );
    final launcher = _RecordingLinkLauncher();
    final router = GoRouter(
      initialLocation: '/checkout',
      routes: [
        GoRoute(
          path: '/checkout',
          builder: (context, state) => const CheckoutScreen(),
        ),
        GoRoute(
          path: '/checkout/pending',
          builder: (context, state) => Scaffold(
            body: Text('pending:${state.uri.queryParameters['order_id']}'),
          ),
        ),
        GoRoute(
          path: '/topup',
          builder: (context, state) => const Scaffold(body: Text('Topup')),
        ),
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('Home')),
        ),
        GoRoute(
          path: '/tickets',
          builder: (context, state) => const Scaffold(body: Text('Tickets')),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const Scaffold(body: Text('Profile')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mobileBootstrapProvider.overrideWith((_) async => _mobileBootstrap()),
          lotteryRepositoryProvider.overrideWithValue(lottery),
          walletRepositoryProvider
              .overrideWithValue(_FailingWalletRepository()),
          affiliateReferralServiceProvider.overrideWithValue(
            _NoopAffiliateReferralService(),
          ),
          customerLinkLauncherProvider.overrideWithValue(launcher),
          checkoutPaymentMethodProvider.overrideWithValue(
            checkoutPaymentMethodWallet,
          ),
          checkoutPaymentMethodsProvider.overrideWithValue(const [
            checkoutPaymentMethodWallet,
            checkoutPaymentMethodExternalPayment,
          ]),
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

    await tester.pumpAndSettle();

    expect(find.text('โหลดกระเป๋าเงินไม่สำเร็จ'), findsOneWidget);
    expect(find.text('ชำระผ่านผู้ให้บริการภายนอก'), findsOneWidget);

    final externalOption = find.text('ชำระผ่านผู้ให้บริการภายนอก');
    await _tapVisibleAboveDock(tester, externalOption);

    await _submitCheckoutPayment(tester);

    expect(lottery.checkoutPaymentMethod, checkoutPaymentMethodExternalPayment);
    expect(
      launcher.openedUri,
      Uri.parse('https://pay.example.test/session/ord_nested'),
    );
    expect(find.text('pending:ord_nested'), findsOneWidget);
  });

  testWidgets('checkout keeps confirm disabled when wallet is insufficient', (
    tester,
  ) async {
    final lottery = _CheckoutLotteryRepository();
    final router = GoRouter(
      initialLocation: '/checkout',
      routes: [
        GoRoute(
          path: '/checkout',
          builder: (context, state) => const CheckoutScreen(),
        ),
        GoRoute(
          path: '/topup',
          builder: (context, state) => Scaffold(
            body: Text('topup:${state.uri.queryParameters['back']}'),
          ),
        ),
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('Home')),
        ),
        GoRoute(
          path: '/tickets',
          builder: (context, state) => const Scaffold(body: Text('Tickets')),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const Scaffold(body: Text('Profile')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mobileBootstrapProvider.overrideWith((_) async => _mobileBootstrap()),
          lotteryRepositoryProvider.overrideWithValue(lottery),
          walletRepositoryProvider
              .overrideWithValue(_WalletRepository(balance: 20)),
          affiliateReferralServiceProvider.overrideWithValue(
            _NoopAffiliateReferralService(),
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

    await tester.pumpAndSettle();
    expect(find.text('ยอดเงินไม่เพียงพอ'), findsWidgets);

    final confirm = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'ยอดเงินไม่เพียงพอ'),
    );
    expect(confirm.onPressed, isNull);

    final topupButton = find.widgetWithText(OutlinedButton, 'เติมเงิน');
    await _tapVisibleAboveDock(tester, topupButton);

    expect(lottery.checkoutReservationIds, isEmpty);
    expect(find.text('topup:/checkout'), findsOneWidget);
  });

  testWidgets('checkout direct entry exposes back action to cart', (
    tester,
  ) async {
    final lottery = _CheckoutLotteryRepository();
    final router = GoRouter(
      initialLocation: '/checkout',
      routes: [
        GoRoute(
          path: '/checkout',
          builder: (context, state) => const CheckoutScreen(),
        ),
        GoRoute(
          path: '/cart',
          builder: (context, state) => const Scaffold(body: Text('Cart route')),
        ),
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('Home')),
        ),
        GoRoute(
          path: '/tickets',
          builder: (context, state) => const Scaffold(body: Text('Tickets')),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const Scaffold(body: Text('Profile')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mobileBootstrapProvider.overrideWith((_) async => _mobileBootstrap()),
          lotteryRepositoryProvider.overrideWithValue(lottery),
          walletRepositoryProvider.overrideWithValue(
            _WalletRepository(balance: 240),
          ),
          affiliateReferralServiceProvider.overrideWithValue(
            _NoopAffiliateReferralService(),
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

    await tester.pumpAndSettle();

    final backButton = find.byTooltip('ย้อนกลับ');
    expect(backButton, findsOneWidget);

    await tester.tap(backButton);
    await tester.pumpAndSettle();

    expect(find.text('Cart route'), findsOneWidget);
  });

  testWidgets('checkout releases expired reservations and returns to buy', (
    tester,
  ) async {
    final lottery = _CheckoutLotteryRepository(expired: true);
    final router = GoRouter(
      initialLocation: '/checkout',
      routes: [
        GoRoute(
          path: '/checkout',
          builder: (context, state) => const CheckoutScreen(),
        ),
        GoRoute(
          path: '/buy',
          builder: (context, state) => const Scaffold(body: Text('Buy')),
        ),
        GoRoute(
          path: '/topup',
          builder: (context, state) => const Scaffold(body: Text('Topup')),
        ),
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('Home')),
        ),
        GoRoute(
          path: '/tickets',
          builder: (context, state) => const Scaffold(body: Text('Tickets')),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const Scaffold(body: Text('Profile')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mobileBootstrapProvider.overrideWith((_) async => _mobileBootstrap()),
          lotteryRepositoryProvider.overrideWithValue(lottery),
          walletRepositoryProvider.overrideWithValue(
            _WalletRepository(balance: 240),
          ),
          affiliateReferralServiceProvider.overrideWithValue(
            _NoopAffiliateReferralService(),
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

    await tester.pumpAndSettle();

    expect(lottery.releasedReservationIds, ['res_1']);
    expect(lottery.checkoutReservationIds, isEmpty);
    expect(find.text('Buy'), findsOneWidget);
  });

  testWidgets('checkout refreshes reserved cart on stock realtime tick', (
    tester,
  ) async {
    final lottery = _CheckoutLotteryRepository();
    final router = GoRouter(
      initialLocation: '/checkout',
      routes: [
        GoRoute(
          path: '/checkout',
          builder: (context, state) => const CheckoutScreen(),
        ),
        GoRoute(
          path: '/topup',
          builder: (context, state) => const Scaffold(body: Text('Topup')),
        ),
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('Home')),
        ),
        GoRoute(
          path: '/tickets',
          builder: (context, state) => const Scaffold(body: Text('Tickets')),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const Scaffold(body: Text('Profile')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mobileBootstrapProvider.overrideWith((_) async => _mobileBootstrap()),
          lotteryRepositoryProvider.overrideWithValue(lottery),
          walletRepositoryProvider.overrideWithValue(
            _WalletRepository(balance: 240),
          ),
          affiliateReferralServiceProvider.overrideWithValue(
            _NoopAffiliateReferralService(),
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

    await tester.pumpAndSettle();

    expect(lottery.cartCount, 1);
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('checkout-summary-total-amount')),
          )
          .data,
      '80',
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('checkout-summary-total-unit')),
          )
          .data,
      'บาท',
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byType(CheckoutScreen)),
      listen: false,
    );
    container.read(lotteryStockRealtimeTickProvider.notifier).state++;
    await tester.pump();
    await tester.pumpAndSettle();

    expect(lottery.cartCount, 2);
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('checkout-summary-total-amount')),
          )
          .data,
      '80',
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('checkout-summary-total-unit')),
          )
          .data,
      'บาท',
    );
  });

  testWidgets('cart shows payment dock with countdown and routes to checkout', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final lottery = _CheckoutLotteryRepository();
    final router = GoRouter(
      initialLocation: '/cart',
      routes: [
        GoRoute(
          path: '/cart',
          builder: (context, state) => const CartScreen(),
        ),
        GoRoute(
          path: '/checkout',
          builder: (context, state) => const Scaffold(body: Text('Checkout')),
        ),
        GoRoute(
          path: '/buy',
          builder: (context, state) => const Scaffold(body: Text('Buy')),
        ),
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('Home')),
        ),
        GoRoute(
          path: '/tickets',
          builder: (context, state) => const Scaffold(body: Text('Tickets')),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const Scaffold(body: Text('Profile')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mobileBootstrapProvider.overrideWith((_) async => _mobileBootstrap()),
          lotteryRepositoryProvider.overrideWithValue(lottery),
          resultRepositoryProvider.overrideWithValue(_CartResultRepository()),
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

    await tester.pumpAndSettle();

    expect(find.text('ตรวจสอบรายการสลากฯ'), findsOneWidget);
    expect(find.text('สลากฯ 1 ใบ'), findsOneWidget);
    expect(find.text('รายการที่จองไว้'), findsNothing);
    expect(find.text('1 ใบ • 80.00 บาท'), findsNothing);
    expect(
      find.byKey(const ValueKey('cart-ticket-product-row')),
      findsOneWidget,
    );
    final cartTicketRow = find.byKey(
      const ValueKey('cart-ticket-row-game_1:273707'),
    );
    expect(cartTicketRow, findsOneWidget);
    expect(
      find.ancestor(of: cartTicketRow, matching: find.byType(Card)),
      findsNothing,
    );
    final cartRowDecoration =
        tester.widget<DecoratedBox>(cartTicketRow).decoration as BoxDecoration;
    expect(cartRowDecoration.borderRadius, isNull);
    final cartRowBorder = cartRowDecoration.border as Border;
    expect(cartRowBorder.top.style, BorderStyle.none);
    expect(cartRowBorder.left.style, BorderStyle.none);
    expect(cartRowBorder.right.style, BorderStyle.none);
    expect(cartRowBorder.bottom.style, BorderStyle.solid);
    expect(find.text('สลากกินแบ่งรัฐบาล'), findsOneWidget);
    expect(
      find.descendant(of: cartTicketRow, matching: find.text('L6')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: cartTicketRow,
        matching: find.byIcon(Icons.confirmation_number_outlined),
      ),
      findsNothing,
    );
    final removePill = tester.widget<DecoratedBox>(
      find.descendant(
        of: cartTicketRow,
        matching: find.byKey(const ValueKey('cart-ticket-remove-pill')),
      ),
    );
    expect((removePill.decoration as BoxDecoration).gradient, isNotNull);
    expect(
      find.descendant(
        of: cartTicketRow,
        matching: find.byIcon(Icons.delete_outline),
      ),
      findsNothing,
    );
    expect(find.textContaining('งวดวันที่'), findsOneWidget);
    expect(find.text('ยอดชำระทั้งหมด'), findsOneWidget);
    expect(find.text('80.00 บาท'), findsWidgets);
    expect(find.textContaining('กรุณาชำระเงินภายใน'), findsOneWidget);
    expect(find.textContaining('สูงสุด 20 ใบ'), findsOneWidget);
    expect(
      find.widgetWithText(OutlinedButton, 'เลือกสลากฯ เพิ่ม'),
      findsNothing,
    );
    final addMoreButton = find.widgetWithText(FilledButton, 'เลือกสลากฯ เพิ่ม');
    expect(addMoreButton, findsOneWidget);
    expect(
      find.descendant(of: addMoreButton, matching: find.byIcon(Icons.add)),
      findsOneWidget,
    );
    final paymentDock = find.byKey(const ValueKey('cart-payment-dock'));
    expect(paymentDock, findsOneWidget);
    final cartDockDecoration =
        tester.widget<DecoratedBox>(paymentDock).decoration as BoxDecoration;
    expect(
      cartDockDecoration.borderRadius,
      const BorderRadius.vertical(top: Radius.circular(16)),
    );
    final dockAmount = tester.widget<Text>(
      find.descendant(
        of: paymentDock,
        matching: find.byKey(const ValueKey('cart-payment-dock-amount')),
      ),
    );
    final dockUnit = tester.widget<Text>(
      find.descendant(
        of: paymentDock,
        matching: find.byKey(const ValueKey('cart-payment-dock-unit')),
      ),
    );
    expect(dockAmount.data, '80.00');
    expect(dockUnit.data, 'บาท');
    expect(
      find.descendant(of: paymentDock, matching: find.text('80.00 บาท')),
      findsNothing,
    );
    expect(
      find.descendant(
        of: paymentDock,
        matching: find.byIcon(Icons.timer_outlined),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: paymentDock,
        matching: find.byIcon(Icons.payment),
      ),
      findsNothing,
    );
    final dockCountdown = find.descendant(
      of: paymentDock,
      matching: find.textContaining('กรุณาชำระเงินภายใน'),
    );
    expect(dockCountdown, findsOneWidget);
    expect(
      tester.getCenter(dockCountdown).dx,
      closeTo(tester.getCenter(paymentDock).dx, 2),
    );
    expect(find.byKey(const Key('customer_bottom_nav')), findsNothing);
    final dockBottom = tester.getBottomLeft(paymentDock).dy;
    expect(dockBottom, closeTo(640, 1));
    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    scrollable.position.jumpTo(
      (scrollable.position.pixels + 260)
          .clamp(
            scrollable.position.minScrollExtent,
            scrollable.position.maxScrollExtent,
          )
          .toDouble(),
    );
    await tester.pumpAndSettle();
    expect(tester.getBottomLeft(paymentDock).dy, closeTo(dockBottom, 1));
    expect(tester.takeException(), isNull);

    final checkoutButton = find.widgetWithText(FilledButton, 'ชำระเงิน');
    await tester.tap(checkoutButton);
    await tester.pumpAndSettle();

    expect(find.text('Checkout'), findsOneWidget);
  });

  testWidgets('cart refreshes reserved tickets on stock realtime tick', (
    tester,
  ) async {
    final lottery = _CheckoutLotteryRepository();
    final router = GoRouter(
      initialLocation: '/cart',
      routes: [
        GoRoute(
          path: '/cart',
          builder: (context, state) => const CartScreen(),
        ),
        GoRoute(
          path: '/checkout',
          builder: (context, state) => const Scaffold(body: Text('Checkout')),
        ),
        GoRoute(
          path: '/buy',
          builder: (context, state) => const Scaffold(body: Text('Buy')),
        ),
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('Home')),
        ),
        GoRoute(
          path: '/tickets',
          builder: (context, state) => const Scaffold(body: Text('Tickets')),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const Scaffold(body: Text('Profile')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          lotteryRepositoryProvider.overrideWithValue(lottery),
          resultRepositoryProvider.overrideWithValue(_CartResultRepository()),
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

    await tester.pumpAndSettle();

    expect(lottery.cartCount, 1);
    expect(find.text('สลากฯ 1 ใบ'), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(CartScreen)),
      listen: false,
    );
    container.read(lotteryStockRealtimeTickProvider.notifier).state++;
    await tester.pump();
    await tester.pumpAndSettle();

    expect(lottery.cartCount, 2);
    expect(find.text('สลากฯ 1 ใบ'), findsOneWidget);
  });

  testWidgets('cart add-more action returns to buy like Nuxt', (
    tester,
  ) async {
    final lottery = _CheckoutLotteryRepository();
    final router = GoRouter(
      initialLocation: '/cart',
      routes: [
        GoRoute(
          path: '/cart',
          builder: (context, state) => const CartScreen(),
        ),
        GoRoute(
          path: '/buy',
          builder: (context, state) => const Scaffold(body: Text('Buy route')),
        ),
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('Home')),
        ),
        GoRoute(
          path: '/tickets',
          builder: (context, state) => const Scaffold(body: Text('Tickets')),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const Scaffold(body: Text('Profile')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [lotteryRepositoryProvider.overrideWithValue(lottery)],
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

    await tester.pumpAndSettle();

    final addMoreButton = find.widgetWithText(FilledButton, 'เลือกสลากฯ เพิ่ม');
    await _tapVisibleAboveDock(tester, addMoreButton);

    expect(find.text('Buy route'), findsOneWidget);
  });

  testWidgets('cart remove confirmation uses Nuxt-style grouped copy', (
    tester,
  ) async {
    final lottery = _GroupedCartLotteryRepository();
    final router = GoRouter(
      initialLocation: '/cart',
      routes: [
        GoRoute(
          path: '/cart',
          builder: (context, state) => const CartScreen(),
        ),
        GoRoute(
          path: '/buy',
          builder: (context, state) => const Scaffold(body: Text('Buy route')),
        ),
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('Home')),
        ),
        GoRoute(
          path: '/tickets',
          builder: (context, state) => const Scaffold(body: Text('Tickets')),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const Scaffold(body: Text('Profile')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          lotteryRepositoryProvider.overrideWithValue(lottery),
          resultRepositoryProvider.overrideWithValue(_CartResultRepository()),
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

    await tester.pumpAndSettle();

    expect(find.text('จำนวน 2 ใบ'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('cart-ticket-summary-row')),
      findsOneWidget,
    );
    expect(find.text('160.00 บาท'), findsWidgets);
    expect(find.text('80.00 บาท'), findsNothing);

    final cartTicketRow = find.byKey(
      const ValueKey('cart-ticket-row-game_1:273707'),
    );
    expect(cartTicketRow, findsOneWidget);
    final removePill = tester.widget<DecoratedBox>(
      find.descendant(
        of: cartTicketRow,
        matching: find.byKey(const ValueKey('cart-ticket-remove-pill')),
      ),
    );
    expect((removePill.decoration as BoxDecoration).gradient, isNotNull);
    final removeButton = find.widgetWithText(FilledButton, 'เอาออก');
    expect(
      find.byKey(const ValueKey('cart-ticket-remove-action')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: removeButton, matching: find.byIcon(Icons.close)),
      findsNothing,
    );
    await _tapVisibleAboveDock(tester, removeButton);

    expect(
      find.byKey(const ValueKey('cart-remove-confirmation-dialog')),
      findsOneWidget,
    );
    expect(find.byType(AlertDialog), findsNothing);
    expect(
      find.text('คุณต้องการลบสลากฯ\n273707 จำนวน 2 ใบ หรือไม่'),
      findsOneWidget,
    );
    expect(
      find.text('เมื่อยืนยัน สลากฯ ชุดนี้\nจะถูกลบออกจากรายการซื้อ'),
      findsOneWidget,
    );
    expect(find.widgetWithText(OutlinedButton, 'ยกเลิก'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'ลบ'));
    await tester.pumpAndSettle();

    expect(lottery.releasedReservationIds, ['res_1', 'res_2']);
  });

  testWidgets('cart remove confirmation stays within compact mobile viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpCartTest(
      tester,
      lottery: _GroupedCartLotteryRepository(),
    );

    final removeButton = find.widgetWithText(FilledButton, 'เอาออก');
    await _tapVisibleAboveDock(tester, removeButton);

    final dialog = find.byKey(
      const ValueKey('cart-remove-confirmation-dialog'),
    );
    expect(dialog, findsOneWidget);
    final dialogRect = tester.getRect(dialog);
    expect(dialogRect.left, greaterThanOrEqualTo(0));
    expect(dialogRect.right, lessThanOrEqualTo(320));

    final cancelButton = find.widgetWithText(OutlinedButton, 'ยกเลิก');
    final confirmButton = find.widgetWithText(FilledButton, 'ลบ');
    expect(cancelButton, findsOneWidget);
    expect(confirmButton, findsOneWidget);
    expect(tester.getRect(cancelButton).left, greaterThanOrEqualTo(0));
    expect(tester.getRect(confirmButton).right, lessThanOrEqualTo(320));
    expect(tester.takeException(), isNull);
  });

  testWidgets('cart remove confirmation keeps Nuxt-style removing state', (
    tester,
  ) async {
    final lottery = _DelayedReleaseLotteryRepository();
    final router = GoRouter(
      initialLocation: '/cart',
      routes: [
        GoRoute(
          path: '/cart',
          builder: (context, state) => const CartScreen(),
        ),
        GoRoute(
          path: '/buy',
          builder: (context, state) => const Scaffold(body: Text('Buy route')),
        ),
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('Home')),
        ),
        GoRoute(
          path: '/tickets',
          builder: (context, state) => const Scaffold(body: Text('Tickets')),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const Scaffold(body: Text('Profile')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          lotteryRepositoryProvider.overrideWithValue(lottery),
          resultRepositoryProvider.overrideWithValue(_CartResultRepository()),
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

    await tester.pumpAndSettle();

    final removeButton = find.widgetWithText(FilledButton, 'เอาออก');
    await _tapVisibleAboveDock(tester, removeButton);

    expect(find.widgetWithText(FilledButton, 'ลบ'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'ลบ'));
    await tester.pump();

    expect(lottery.releasedReservationIds, ['res_1']);
    final removingButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'กำลังลบ'),
    );
    expect(removingButton.onPressed, isNull);
    final cancelButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'ยกเลิก'),
    );
    expect(cancelButton.onPressed, isNull);

    lottery.completeRelease();
    await tester.pumpAndSettle();

    expect(find.text('กำลังลบ'), findsNothing);
    expect(find.text('ตะกร้าว่าง'), findsOneWidget);
  });

  testWidgets('cart remove confirmation stays open after release failure', (
    tester,
  ) async {
    final lottery = _FailingReleaseLotteryRepository();
    final router = GoRouter(
      initialLocation: '/cart',
      routes: [
        GoRoute(
          path: '/cart',
          builder: (context, state) => const CartScreen(),
        ),
        GoRoute(
          path: '/buy',
          builder: (context, state) => const Scaffold(body: Text('Buy route')),
        ),
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('Home')),
        ),
        GoRoute(
          path: '/tickets',
          builder: (context, state) => const Scaffold(body: Text('Tickets')),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const Scaffold(body: Text('Profile')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          lotteryRepositoryProvider.overrideWithValue(lottery),
          resultRepositoryProvider.overrideWithValue(_CartResultRepository()),
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

    await tester.pumpAndSettle();

    final removeButton = find.widgetWithText(FilledButton, 'เอาออก');
    await _tapVisibleAboveDock(tester, removeButton);

    await tester.tap(find.widgetWithText(FilledButton, 'ลบ'));
    await tester.pumpAndSettle();

    expect(lottery.releasedReservationIds, ['res_1']);
    expect(find.text('คุณต้องการลบสลากฯ\n273707 หรือไม่'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'ลบ'), findsOneWidget);
    expect(find.text('กำลังลบ'), findsNothing);
    expect(find.text('กรุณาลองใหม่อีกครั้ง'), findsOneWidget);
  });

  testWidgets('cart direct entry exposes back action to buy', (
    tester,
  ) async {
    final lottery = _CheckoutLotteryRepository();
    final router = GoRouter(
      initialLocation: '/cart',
      routes: [
        GoRoute(
          path: '/cart',
          builder: (context, state) => const CartScreen(),
        ),
        GoRoute(
          path: '/buy',
          builder: (context, state) => const Scaffold(body: Text('Buy route')),
        ),
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('Home')),
        ),
        GoRoute(
          path: '/tickets',
          builder: (context, state) => const Scaffold(body: Text('Tickets')),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const Scaffold(body: Text('Profile')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [lotteryRepositoryProvider.overrideWithValue(lottery)],
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

    await tester.pumpAndSettle();

    final backButton = find.byTooltip('ย้อนกลับ');
    expect(backButton, findsOneWidget);

    await tester.tap(backButton);
    await tester.pumpAndSettle();

    expect(find.text('Buy route'), findsOneWidget);
  });

  testWidgets('cart releases expired reservations and returns to buy', (
    tester,
  ) async {
    final lottery = _CheckoutLotteryRepository(expired: true);
    final router = GoRouter(
      initialLocation: '/cart',
      routes: [
        GoRoute(
          path: '/cart',
          builder: (context, state) => const CartScreen(),
        ),
        GoRoute(
          path: '/buy',
          builder: (context, state) => const Scaffold(body: Text('Buy')),
        ),
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('Home')),
        ),
        GoRoute(
          path: '/tickets',
          builder: (context, state) => const Scaffold(body: Text('Tickets')),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const Scaffold(body: Text('Profile')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [lotteryRepositoryProvider.overrideWithValue(lottery)],
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

    await tester.pumpAndSettle();

    expect(lottery.releasedReservationIds, ['res_1']);
    expect(lottery.checkoutReservationIds, isEmpty);
    expect(find.text('Buy'), findsOneWidget);
  });
}

Future<void> _pumpCartTest(
  WidgetTester tester, {
  required _CheckoutLotteryRepository lottery,
}) async {
  final router = GoRouter(
    initialLocation: '/cart',
    routes: [
      GoRoute(
        path: '/cart',
        builder: (context, state) => const CartScreen(),
      ),
      GoRoute(
        path: '/buy',
        builder: (context, state) => const Scaffold(body: Text('Buy')),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(body: Text('Home')),
      ),
      GoRoute(
        path: '/tickets',
        builder: (context, state) => const Scaffold(body: Text('Tickets')),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const Scaffold(body: Text('Profile')),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mobileBootstrapProvider.overrideWith((_) async => _mobileBootstrap()),
        lotteryRepositoryProvider.overrideWithValue(lottery),
        resultRepositoryProvider.overrideWithValue(_CartResultRepository()),
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
  await tester.pumpAndSettle();
}

Future<GoRouter> _pumpCheckoutPaymentTest(
  WidgetTester tester, {
  required _CheckoutLotteryRepository lottery,
  WalletRepository? walletRepository,
  AffiliateReferralService? affiliateReferralService,
}) async {
  final router = GoRouter(
    initialLocation: '/checkout',
    routes: [
      GoRoute(
        path: '/checkout',
        builder: (context, state) => const CheckoutScreen(),
      ),
      GoRoute(
        path: '/success',
        builder: (context, state) => Scaffold(
          body: Center(
            child: Text('success:${state.uri.queryParameters['order_id']}'),
          ),
        ),
      ),
      GoRoute(
        path: '/topup',
        builder: (context, state) => const Scaffold(body: Text('Topup')),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(body: Text('Home')),
      ),
      GoRoute(
        path: '/tickets',
        builder: (context, state) => const Scaffold(body: Text('Tickets')),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const Scaffold(body: Text('Profile')),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mobileBootstrapProvider.overrideWith((_) async => _mobileBootstrap()),
        lotteryRepositoryProvider.overrideWithValue(lottery),
        walletRepositoryProvider.overrideWithValue(
          walletRepository ?? _WalletRepository(balance: 240),
        ),
        affiliateReferralServiceProvider.overrideWithValue(
          affiliateReferralService ?? _NoopAffiliateReferralService(),
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
  await tester.pumpAndSettle();
  return router;
}

Future<void> _tapVisibleAboveDock(WidgetTester tester, Finder finder) async {
  await Scrollable.ensureVisible(
    tester.element(finder),
    alignment: 0.12,
    duration: Duration.zero,
  );
  await tester.pumpAndSettle();
  for (var attempt = 0; attempt < 8; attempt += 1) {
    final dockTop = _fixedPaymentDockTop(tester);
    if (dockTop == null) break;
    final targetRect = tester.getRect(finder);
    if (targetRect.center.dy <= dockTop - 44) break;
    final scrollable = Scrollable.of(tester.element(finder));
    final position = scrollable.position;
    final distance =
        (targetRect.center.dy - dockTop + 96).clamp(60.0, 280.0).toDouble();
    final nextOffset = (position.pixels + distance)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    if ((nextOffset - position.pixels).abs() < 0.5) break;
    position.jumpTo(nextOffset);
    await tester.pumpAndSettle();
  }
  for (var attempt = 0; attempt < 4; attempt += 1) {
    final scrollable = Scrollable.of(tester.element(finder));
    final renderObject = scrollable.context.findRenderObject();
    if (renderObject is! RenderBox) break;
    final scrollableTop = renderObject.localToGlobal(Offset.zero).dy;
    final targetRect = tester.getRect(finder);
    final minTargetCenter = scrollableTop + 48;
    if (targetRect.center.dy >= minTargetCenter) break;
    final position = scrollable.position;
    final nextOffset =
        (position.pixels - (minTargetCenter - targetRect.center.dy + 32))
            .clamp(position.minScrollExtent, position.maxScrollExtent)
            .toDouble();
    if ((nextOffset - position.pixels).abs() < 0.5) break;
    position.jumpTo(nextOffset);
    await tester.pumpAndSettle();
  }
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

double? _fixedPaymentDockTop(WidgetTester tester) {
  const keys = [
    ValueKey('checkout-payment-dock'),
    ValueKey('cart-payment-dock'),
  ];
  for (final key in keys) {
    final dock = find.byKey(key);
    if (dock.evaluate().isNotEmpty) {
      return tester.getTopLeft(dock).dy;
    }
  }
  return null;
}

Future<void> _submitCheckoutPayment(WidgetTester tester) async {
  final confirmButton = find.widgetWithText(FilledButton, 'ยืนยันชำระเงิน');
  await Scrollable.ensureVisible(
    tester.element(confirmButton),
    alignment: 0.82,
    duration: Duration.zero,
  );
  await tester.pumpAndSettle();
  await tester.tap(confirmButton);
  await tester.pumpAndSettle();
}

DioException _apiException(
  String message, {
  String path = '/customer/checkout',
}) {
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

class _PendingCartLotteryRepository extends LotteryRepository {
  _PendingCartLotteryRepository(this.cartFuture) : super(_testApiClient());

  final Future<LotteryCart> cartFuture;

  @override
  Future<LotteryCart> cart() => cartFuture;
}

class _CheckoutLotteryRepository extends LotteryRepository {
  _CheckoutLotteryRepository({
    this.expired = false,
    this.redirectUrl = '',
    this.checkoutError,
  }) : super(_testApiClient());

  final bool expired;
  final String redirectUrl;
  final Object? checkoutError;

  List<String> checkoutReservationIds = const [];
  String checkoutPaymentMethod = '';
  List<String> releasedReservationIds = const [];
  int cartCount = 0;
  bool _released = false;

  @override
  Future<LotteryCart> cart() async {
    cartCount++;
    if (_released) return LotteryCart.empty();
    final now = DateTime.now();
    return LotteryCart(
      reservations: [
        LotteryReservation(
          id: 'res_1',
          gameId: 'game_1',
          status: 'active',
          expiresAt: now
              .add(
                expired
                    ? const Duration(seconds: -2)
                    : const Duration(minutes: 12),
              )
              .toIso8601String(),
          expiresInSeconds: expired ? 0 : 720,
          serverTime: now.toIso8601String(),
          items: [
            LotteryStockItem(
              id: 'vstock:game_1:273707:1',
              token: 'stock-token',
              localStockItemId: 'local-stock-1',
              stockRef: 'vstock-ref-1',
              number: '273707',
              sellerName: 'ร้านทดสอบ',
              storeName: 'ร้านทดสอบ',
              price: 80,
              remainingCount: 1,
              status: 'available',
              reservationId: 'res_1',
              reservationExpiresAt: null,
              serverTime: null,
              imageUrl: '',
              thumbUrl: '',
              raw: const {},
            ),
          ],
          total: 80,
        ),
      ],
      total: 80,
      itemCount: 1,
      serverTime: DateTime.now().toIso8601String(),
      warnings: const [],
    );
  }

  @override
  Future<LotteryCheckoutOrder> checkout(
    List<String> reservationIds, {
    String paymentMethod = checkoutPaymentMethodWallet,
  }) async {
    checkoutReservationIds = List<String>.from(reservationIds);
    checkoutPaymentMethod = paymentMethod;
    final error = checkoutError;
    if (error != null) throw error;
    return LotteryCheckoutOrder.fromJson({
      'result': {
        'order': {
          'id': 'ord_nested',
          'reference': 'ORDER-NESTED',
          'status': paymentMethod == checkoutPaymentMethodExternalPayment
              ? 'pending_payment'
              : 'paid',
          'payment_status':
              paymentMethod == checkoutPaymentMethodExternalPayment
                  ? 'pending_payment'
                  : 'paid',
          'payment_method': paymentMethod,
          if (redirectUrl.isNotEmpty) 'redirect_url': redirectUrl,
          'total': {'amount': 8000, 'currency': 'THB'},
          'ticket_count': 1,
        },
      },
    });
  }

  @override
  Future<LotteryCart> releaseReservation(String reservationId) async {
    releasedReservationIds = [...releasedReservationIds, reservationId];
    _released = true;
    return LotteryCart.empty();
  }
}

class _FailingCartLotteryRepository extends _CheckoutLotteryRepository {
  _FailingCartLotteryRepository(this.error);

  final Object error;

  @override
  Future<LotteryCart> cart() async {
    throw error;
  }
}

class _LegacyCartOrderLotteryRepository extends _CheckoutLotteryRepository {
  @override
  Future<LotteryCart> cart() async {
    cartCount++;
    return LotteryCart.fromJson({
      'result': {
        'cart_order': {
          'exp':
              DateTime.now().add(const Duration(minutes: 12)).toIso8601String(),
          'created_at': DateTime.now().toIso8601String(),
          'lotteries': [
            {
              'reservation_id': 'res_legacy_1',
              'game_id': 'game_1',
              'local_stock_item_id': 'legacy_stock_1',
              'number': '273707',
              'store_name': 'ร้าน legacy',
              'price': {'amount': 8000, 'currency': 'THB'},
            },
            {
              'reservation_id': 'res_legacy_2',
              'game_id': 'game_1',
              'local_stock_item_id': 'legacy_stock_2',
              'number': '445566',
              'store_name': 'ร้าน legacy',
              'price': {'amount': 8000, 'currency': 'THB'},
            },
          ],
        },
      },
    });
  }
}

class _GroupedCartLotteryRepository extends _CheckoutLotteryRepository {
  @override
  Future<LotteryCart> cart() async {
    if (_released) return LotteryCart.empty();
    final now = DateTime.now();
    return LotteryCart(
      reservations: [
        _reservation(
          id: 'res_1',
          localStockItemId: 'local-stock-1',
          now: now,
        ),
        _reservation(
          id: 'res_2',
          localStockItemId: 'local-stock-2',
          now: now,
        ),
      ],
      total: 160,
      itemCount: 2,
      serverTime: now.toIso8601String(),
      warnings: const [],
    );
  }

  LotteryReservation _reservation({
    required String id,
    required String localStockItemId,
    required DateTime now,
  }) {
    return LotteryReservation(
      id: id,
      gameId: 'game_1',
      status: 'active',
      expiresAt: now.add(const Duration(minutes: 12)).toIso8601String(),
      expiresInSeconds: 720,
      serverTime: now.toIso8601String(),
      items: [
        LotteryStockItem(
          id: 'vstock:game_1:273707:$localStockItemId',
          token: 'stock-token-$localStockItemId',
          localStockItemId: localStockItemId,
          stockRef: 'vstock-ref-$localStockItemId',
          number: '273707',
          sellerName: 'ร้านทดสอบ',
          storeName: 'ร้านทดสอบ',
          price: 80,
          remainingCount: 1,
          status: 'available',
          reservationId: id,
          reservationExpiresAt: null,
          serverTime: null,
          imageUrl: '',
          thumbUrl: '',
          raw: const {},
        ),
      ],
      total: 80,
    );
  }
}

class _DelayedReleaseLotteryRepository extends _CheckoutLotteryRepository {
  final _releaseCompleter = Completer<LotteryCart>();

  void completeRelease() {
    if (_releaseCompleter.isCompleted) return;
    _released = true;
    _releaseCompleter.complete(LotteryCart.empty());
  }

  @override
  Future<LotteryCart> releaseReservation(String reservationId) {
    releasedReservationIds = [...releasedReservationIds, reservationId];
    return _releaseCompleter.future;
  }
}

class _FailingReleaseLotteryRepository extends _CheckoutLotteryRepository {
  @override
  Future<LotteryCart> releaseReservation(String reservationId) async {
    releasedReservationIds = [...releasedReservationIds, reservationId];
    throw DioException(
      requestOptions: RequestOptions(
        path: '/customer/reservations/$reservationId/release',
      ),
    );
  }
}

class _CartResultRepository extends ResultRepository {
  _CartResultRepository() : super(_testApiClient());

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

class _RecordingLinkLauncher extends CustomerLinkLauncher {
  _RecordingLinkLauncher({this.openError});

  final Object? openError;
  Uri? openedUri;

  @override
  Future<bool> openExternal(
    Uri uri, {
    bool preferSameWindowInLine = false,
  }) async {
    openedUri = uri;
    final error = openError;
    if (error != null) throw error;
    return true;
  }
}

class _WalletRepository extends WalletRepository {
  _WalletRepository({required this.balance, this.walletName = 'G Wallet'})
      : super(_testApiClient());

  final double balance;
  final String walletName;

  @override
  Future<WalletSummary> summary() async {
    return WalletSummary(
      wallets: [
        CustomerWallet(
          id: 'wallet_1',
          name: walletName,
          type: '1',
          balance: balance,
        ),
      ],
      ledger: const [],
    );
  }
}

class _PendingWalletRepository extends WalletRepository {
  _PendingWalletRepository(this.summaryFuture) : super(_testApiClient());

  final Future<WalletSummary> summaryFuture;

  @override
  Future<WalletSummary> summary() => summaryFuture;
}

class _CountingWalletRepository extends WalletRepository {
  _CountingWalletRepository() : super(_testApiClient());

  int summaryCalls = 0;

  @override
  Future<WalletSummary> summary() async {
    summaryCalls++;
    return const WalletSummary(wallets: [], ledger: []);
  }
}

class _FailingWalletRepository extends WalletRepository {
  _FailingWalletRepository([this.error]) : super(_testApiClient());

  final Object? error;

  @override
  Future<WalletSummary> summary() async {
    throw error ?? StateError('wallet unavailable');
  }
}

class _NoopAffiliateReferralService extends AffiliateReferralService {
  _NoopAffiliateReferralService()
      : super(
          config: const AppConfig(
            apiBaseUrl: 'https://partner.example.test/api/v1',
            defaultLocale: 'th-TH',
          ),
          repository: AffiliateReferralRepository(_testApiClient()),
          store: AffiliateReferralStore(),
          visitIdStore: PublicVisitIdStore(idFactory: (_) => 'visitor'),
        );

  bool applied = false;

  @override
  Future<void> applyStored({bool registered = false}) async {
    applied = true;
  }
}

MobileBootstrap _mobileBootstrap() {
  return MobileBootstrap.fromJson(const {
    'tenant_id': 'tenant_test',
    'site': {
      'display_name': 'ร้านทดสอบ',
      'locale': 'th-TH',
    },
    'brand': {'logo_url': ''},
    'mobile': {'lottery_product_label': 'L6'},
  });
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
