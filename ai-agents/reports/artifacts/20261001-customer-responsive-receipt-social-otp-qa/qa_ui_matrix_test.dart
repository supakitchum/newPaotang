import 'dart:io';
import 'dart:ui' as ui;

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
import 'package:customer_flutter/features/affiliate/data/affiliate_referral_repository.dart';
import 'package:customer_flutter/features/auth/presentation/line_auth_screens.dart';
import 'package:customer_flutter/features/lottery/data/lottery_models.dart';
import 'package:customer_flutter/features/lottery/data/lottery_repository.dart';
import 'package:customer_flutter/features/lottery/presentation/lottery_screens.dart';
import 'package:customer_flutter/features/monitoring/data/public_visit_id_store.dart';
import 'package:customer_flutter/features/results/data/result_models.dart';
import 'package:customer_flutter/features/results/data/result_repository.dart';
import 'package:customer_flutter/features/stores/data/store_models.dart';
import 'package:customer_flutter/features/stores/data/store_repository.dart';
import 'package:customer_flutter/features/stores/presentation/store_screens.dart';
import 'package:customer_flutter/features/wallet/data/wallet_models.dart';
import 'package:customer_flutter/features/wallet/data/wallet_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _config = AppConfig(apiBaseUrl: 'https://qa-fixture.test/api/v1', defaultLocale: 'th-TH');
ApiClient _api() => ApiClient(_config, AuthTokenStore(), localeTag: 'th-TH');

void main() {
  WidgetController.hitTestWarningShouldBeFatal = true;
  for (final page in ['buy', 'search', 'more', 'stores', 'cart', 'checkout']) {
    for (final inset in [0.0, 34.0]) {
      testWidgets('QA $page dock inset $inset', (tester) async {
        final root = GlobalKey();
        await _prepare(tester, const Size(390, 844), inset);
        final router = GoRouter(initialLocation: '/$page', routes: [
          GoRoute(path: '/buy', builder: (_, __) => const BuyScreen()),
          GoRoute(path: '/search', builder: (_, __) => const BuySearchScreen(query: {'number': '273707'})),
          GoRoute(path: '/more', builder: (_, __) => const BuyMoreScreen(query: {'number': '273707'})),
          GoRoute(path: '/stores', builder: (_, __) => const StoresScreen()),
          GoRoute(path: '/cart', builder: (_, __) => const CartScreen()),
          GoRoute(path: '/checkout', builder: (_, __) => const CheckoutScreen()),
          GoRoute(path: '/pin', builder: (_, __) => const Scaffold(body: Text('QA PIN gate'))),
        ]);
        addTearDown(router.dispose);
        final tokens = AuthTokenStore();
        final repository = _Auth(existing: false);
        final auth = AuthController(authRepository: repository, tokenStore: tokens, biometricAuth: BiometricAuthService(_api()))..isAuthenticated = true;
        await tester.pumpWidget(_app(root, router, [
          authTokenStoreProvider.overrideWithValue(tokens),
          authControllerProvider.overrideWith((_) => auth),
          authRepositoryProvider.overrideWithValue(repository),
          resultRepositoryProvider.overrideWithValue(_Results()),
          lotteryRepositoryProvider.overrideWithValue(_Lottery()),
          storeRepositoryProvider.overrideWithValue(_Stores()),
          walletRepositoryProvider.overrideWithValue(_Wallet()),
        ]));
        await tester.pumpAndSettle();
        final dock = find.byKey(ValueKey(page == 'cart' ? 'cart-payment-dock' : page == 'checkout' ? 'checkout-payment-dock' : 'cart-selection-dock'));
        expect(dock, findsOneWidget);
        final rect = tester.getRect(dock);
        expect(rect.bottom, closeTo(844, 1));
        expect(rect.left, 0);
        expect(rect.right, 390);
        final button = find.descendant(of: dock, matching: find.byType(FilledButton)).first;
        expect(tester.getRect(button).bottom, lessThanOrEqualTo(844 - inset));
        await _capture(tester, root, 'dock-$page-inset${inset.toInt()}');
        if (page == 'search') {
          await tester.tap(find.byType(TextField).first);
          tester.view.viewInsets = const FakeViewPadding(bottom: 260);
          await tester.pumpAndSettle();
          expect(tester.getRect(button).bottom, lessThanOrEqualTo(584));
          await _capture(tester, root, 'dock-search-inset${inset.toInt()}-keyboard');
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
  for (final size in [const Size(320, 568), const Size(390, 844), const Size(768, 1024)]) {
    for (final existing in [false, true]) {
      testWidgets('QA social ${size.width} existing=$existing', (tester) async {
        final root = GlobalKey();
        await _prepare(tester, size, 34);
        final repository = _Auth(existing: existing);
        final router = GoRouter(initialLocation: '/social', routes: [
          GoRoute(path: '/social', builder: (_, __) => const LineLinkPhoneScreen(provider: 'google', linkToken: 'qa-link', displayName: 'QA Member', redirect: '/tickets')),
          GoRoute(path: '/pin', builder: (_, __) => const Scaffold(body: Text('QA PIN gate'))),
          GoRoute(path: '/tickets', builder: (_, __) => const Scaffold(body: Text('QA Tickets'))),
        ]);
        addTearDown(router.dispose);
        final tokens = AuthTokenStore();
        final auth = AuthController(authRepository: repository, tokenStore: tokens, biometricAuth: BiometricAuthService(_api()));
        await tester.pumpWidget(_app(root, router, [
          authTokenStoreProvider.overrideWithValue(tokens),
          authControllerProvider.overrideWith((_) => auth),
          authRepositoryProvider.overrideWithValue(repository),
        ]));
        await tester.pumpAndSettle();
        final name = 'social-${size.width.toInt()}x${size.height.toInt()}-${existing ? 'existing' : 'new'}';
        await _capture(tester, root, '$name-phone');
        await tester.enterText(find.byType(TextField), '0812345678');
        tester.view.viewInsets = const FakeViewPadding(bottom: 260);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byType(FilledButton));
        await tester.pumpAndSettle();
        expect(tester.getRect(find.byType(FilledButton)).bottom, lessThanOrEqualTo(size.height - 260));
        await _capture(tester, root, '$name-keyboard');
        await tester.tap(find.byType(FilledButton));
        await tester.pumpAndSettle();
        expect(repository.requestPurpose, 'register');
        await tester.enterText(find.byType(TextField), '123456');
        await tester.pumpAndSettle();
        expect(repository.probes, 1);
        if (existing) {
          expect(find.text('QA PIN gate'), findsOneWidget);
          expect(repository.registrations, 0);
        } else {
          expect(find.byType(TextField), findsNWidgets(4));
          expect(find.byType(CheckboxListTile), findsOneWidget);
          tester.view.viewInsets = FakeViewPadding.zero;
          await tester.pumpAndSettle();
          await _capture(tester, root, '$name-member-top');
          await tester.ensureVisible(find.byType(FilledButton));
          await tester.pumpAndSettle();
          await tester.tap(find.byType(FilledButton));
          await tester.pumpAndSettle();
          expect(repository.registrations, 0);
          for (final entry in ['QA', 'Member', 'qa-secret1234', 'qa-secret1234'].asMap().entries) {
            await tester.ensureVisible(find.byType(TextField).at(entry.key));
            await tester.pumpAndSettle();
            await tester.enterText(find.byType(TextField).at(entry.key), entry.value);
            await tester.pumpAndSettle();
          }
          await tester.ensureVisible(find.byType(FilledButton));
          await tester.pumpAndSettle();
          await tester.tap(find.byType(FilledButton));
          await tester.pumpAndSettle();
          expect(repository.registrations, 0);
          await tester.ensureVisible(find.byType(CheckboxListTile));
          await tester.pumpAndSettle();
          await tester.tap(find.byType(CheckboxListTile));
          await tester.ensureVisible(find.byType(FilledButton));
          await tester.pumpAndSettle();
          await _capture(tester, root, '$name-member-bottom');
          await tester.tap(find.byType(FilledButton));
          await tester.pumpAndSettle();
          expect(repository.registrations, 1);
          expect(find.text('QA PIN gate'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}

Future<void> _prepare(WidgetTester tester, Size size, double inset) async {
  await tester.runAsync(() => (FontLoader('Kanit')
    ..addFont(rootBundle.load('assets/fonts/kanit/Kanit-Regular.ttf'))
    ..addFont(rootBundle.load('assets/fonts/kanit/Kanit-Bold.ttf'))).load());
  await tester.runAsync(() => (FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load());
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.view.padding = FakeViewPadding(top: 47, bottom: inset);
  addTearDown(tester.view.reset);
}

Widget _app(GlobalKey root, GoRouter router, List<Override> overrides) => RepaintBoundary(key: root, child: ProviderScope(
  overrides: [
    appConfigProvider.overrideWithValue(_config),
    mobileBootstrapProvider.overrideWith((_) async => MobileBootstrap.fromJson({})),
    affiliateReferralServiceProvider.overrideWithValue(_Referrals()),
    ...overrides,
  ],
  child: MaterialApp.router(debugShowCheckedModeBanner: false, locale: fallbackCustomerLocale,
    supportedLocales: supportedCustomerLocales,
    localizationsDelegates: const [CustomerLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
    theme: AppTheme.light(), routerConfig: router),
));

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('/evidence/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

class _Results extends ResultRepository {
  _Results() : super(_api());
  @override
  Future<CurrentGame?> currentGame() async => const CurrentGame(id: 'qa-game', name: 'QA draw', status: 'open', drawAt: '2026-10-01T17:00:00+07:00');
}
class _Stores extends StoreRepository {
  _Stores() : super(_api());
  @override
  Future<StorePage> list({String q = '', String cursor = '', int limit = 30}) async => const StorePage(items: [StoreItem(id: 'qa-store', name: 'QA Store', code: 'QA')], nextCursor: '', hasMore: false);
}
class _Lottery extends LotteryRepository {
  _Lottery() : super(_api());
  @override
  Future<LotteryStockPage> search({required String gameId, List<String> digits = const [], String number = '', String storeId = '', String cursor = '', String randomSeed = '', int limit = 20}) async => LotteryStockPage(gameId: gameId, items: const [_stock], nextCursor: '', hasMore: false, sellerName: 'QA Store');
  @override
  Future<LotteryCart> cart() async {
    final now = DateTime.now();
    return LotteryCart(reservations: [LotteryReservation(id: 'qa-reservation', gameId: 'qa-game', status: 'active', expiresAt: now.add(const Duration(minutes: 12)).toIso8601String(), expiresInSeconds: 720, serverTime: now.toIso8601String(), items: const [_stock], total: 80)], total: 80, itemCount: 1, serverTime: now.toIso8601String(), warnings: const []);
  }
}
const _stock = LotteryStockItem(id: 'qa-stock', token: 'qa-fixture-token', localStockItemId: 'qa-stock', stockRef: 'qa-ref', number: '273707', sellerName: 'QA Store', storeName: 'QA Store', price: 80, remainingCount: 1, status: 'available', reservationId: 'qa-reservation', reservationExpiresAt: null, serverTime: null, imageUrl: '', thumbUrl: '', raw: {});
class _Wallet extends WalletRepository {
  _Wallet() : super(_api());
  @override
  Future<WalletSummary> summary() async => const WalletSummary(wallets: [CustomerWallet(id: 'qa-wallet', name: 'QA Wallet', type: '1', balance: 240)], ledger: []);
}
class _Auth extends AuthRepository {
  _Auth({required this.existing}) : super(api: _api(), tokenStore: AuthTokenStore());
  final bool existing;
  int probes = 0;
  int registrations = 0;
  String requestPurpose = '';
  @override
  Future<OtpRequestResult> requestOtp({required String phone, required String purpose}) async {
    requestPurpose = purpose;
    return const OtpRequestResult(phoneMasked: '08xxxxx678', resendAfterSeconds: 60);
  }
  @override
  Future<OtpVerifyResult> verifyOtp({required String phone, required String purpose, required String otp}) async => const OtpVerifyResult(verificationToken: 'qa-verified');
  @override
  Future<CustomerSession?> socialLinkExistingPhone({required String provider, required String linkToken, required String phone, required String otpVerificationToken, String? redirect}) async {
    probes++;
    return existing ? const CustomerSession(accessToken: 'qa-session', refreshToken: 'qa-refresh', customerId: 'qa-member', pinRequired: true, pinSetupRequired: false) : null;
  }
  @override
  Future<CustomerSession> socialLinkPhone({required String provider, required String linkToken, required String phone, required String firstName, required String lastName, required String password, required String passwordConfirmation, required String otpVerificationToken, required bool acceptedTerms, String? redirect}) async {
    registrations++;
    return const CustomerSession(accessToken: 'qa-session', refreshToken: 'qa-refresh', customerId: 'qa-member', pinRequired: true, pinSetupRequired: true);
  }
}
class _Referrals extends AffiliateReferralService {
  _Referrals() : super(config: _config, repository: AffiliateReferralRepository(_api()), store: AffiliateReferralStore(), visitIdStore: PublicVisitIdStore());
  @override
  Future<void> applyStored({bool registered = false}) async {}
}
