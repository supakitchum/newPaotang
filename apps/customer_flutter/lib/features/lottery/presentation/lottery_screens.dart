import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/auth_token_store.dart';
import '../../../core/i18n/customer_localizations.dart';
import '../../../core/i18n/app_locale.dart';
import '../../../core/navigation/customer_back_navigation.dart';
import '../../../core/navigation/customer_link_launcher.dart';
import '../../../core/navigation/customer_redirect.dart';
import '../../../core/payment/checkout_payment_config.dart';
import '../../../core/tenant/mobile_bootstrap_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/api_errors.dart';
import '../../../core/utils/asset_url.dart';
import '../../../core/utils/formatters.dart';
import '../../../features/affiliate/data/affiliate_referral_repository.dart';
import '../../../features/purchase_history/data/purchase_history_models.dart';
import '../../../features/purchase_history/data/purchase_history_repository.dart';
import '../../../features/results/data/result_models.dart';
import '../../../features/results/data/result_repository.dart';
import '../../../features/system/presentation/success_receipt_state.dart';
import '../../../features/wallet/data/wallet_models.dart';
import '../../../features/wallet/data/wallet_repository.dart';
import '../../../shared/utils/customer_operational_error.dart';
import '../../../shared/widgets/customer_gradient_button.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/customer_page_body.dart';
import '../../../shared/widgets/customer_loading_indicator.dart';
import '../../../shared/widgets/flexible_image.dart';
import '../../../shared/widgets/pin_confirmation_step.dart';
import '../data/customer_revenue_cache.dart';
import '../data/lottery_models.dart';
import '../data/lottery_repository.dart';
import 'checkout_payment_method_provider.dart';
import 'lottery_digit_input_row.dart';
import 'lottery_navigation.dart';
import 'lottery_stock_realtime_monitor.dart';
import 'lottery_stock_skeleton.dart';
import 'lottery_store_segment_tabs.dart';

class BuyScreen extends ConsumerStatefulWidget {
  const BuyScreen({super.key});

  @override
  ConsumerState<BuyScreen> createState() => _BuyScreenState();
}

class _BuyScreenState extends ConsumerState<BuyScreen> {
  final _digits = List.generate(6, (_) => TextEditingController());
  late final Future<CurrentGame?> _currentGameFuture;
  LotteryCart _cart = LotteryCart.empty();

  @override
  void initState() {
    super.initState();
    _currentGameFuture = _loadCurrentGame();
  }

  @override
  void dispose() {
    for (final controller in _digits) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppShell(
      title: l10n.lotteryBuyTitle,
      currentPath: '/buy',
      backPath: '/',
      showBottomNavigation: false,
      heroMinHeight: 258,
      heroContent: const LotteryStoreSegmentTabs(activePath: '/buy'),
      child: _LotteryDockedPage(
        dock: _cart.reservationIds.isEmpty
            ? null
            : _CartSelectionDock(
                cart: _cart,
                onReview: _cartSelectionReviewEnabled(_cart)
                    ? () => context.push('/cart')
                    : null,
              ),
        children: [
          Column(
            key: const ValueKey('buy-search-entry-section'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.lotterySearchHeroTitle,
                style: _lotterySectionTitleTextStyle(context),
              ),
              const SizedBox(height: 4),
              FutureBuilder<CurrentGame?>(
                future: _currentGameFuture,
                builder: (context, snapshot) {
                  final drawDate = _lotteryDrawDateLabel(l10n, snapshot.data);
                  return Text(
                    drawDate.isEmpty
                        ? l10n.countdownCurrentDrawFallback
                        : drawDate,
                    style: _lotteryDrawDateTextStyle(context),
                  );
                },
              ),
              const SizedBox(height: 20),
              LotteryDigitInputRow(
                controllers: _digits,
                readOnly: true,
                onTap: _goSearch,
                style: _lotteryDigitBoxesStyle(context),
              ),
            ],
          ),
          const Divider(height: 34),
          _LotteryStockList(
            title: l10n.lotteryStockTitle,
            showTicketImages: false,
            onCartChanged: _syncCart,
          ),
        ],
      ),
    );
  }

  void _goSearch() {
    context.push('/buy/search');
  }

  Future<CurrentGame?> _loadCurrentGame() async {
    try {
      return await ref.read(resultRepositoryProvider).currentGame();
    } catch (error) {
      if (mounted) {
        await handleCustomerOperationalError(
          ref: ref,
          context: context,
          error: error,
        );
      }
      return null;
    }
  }

  void _syncCart(LotteryCart cart) {
    if (_sameCartSummary(_cart, cart)) return;
    setState(() => _cart = cart);
  }
}

class BuySearchScreen extends ConsumerStatefulWidget {
  const BuySearchScreen({super.key, required this.query});

  final Map<String, String> query;

  @override
  ConsumerState<BuySearchScreen> createState() => _BuySearchScreenState();
}

List<String> _queryDigits(Map<String, String> query) {
  final number = (query['number'] ?? '').replaceAll(RegExp(r'\D'), '');
  if (number.isNotEmpty) {
    return List.generate(
      6,
      (index) => index < number.length ? number[index] : '',
      growable: false,
    );
  }
  return List.generate(6, (index) {
    final value = (query['d${index + 1}'] ?? '').replaceAll(RegExp(r'\D'), '');
    return value.isEmpty ? '' : value.substring(0, 1);
  }, growable: false);
}

bool _queryHasLotterySearchInput(Map<String, String> query) {
  if ((query['number'] ?? '').replaceAll(RegExp(r'\D'), '').isNotEmpty) {
    return true;
  }
  for (var index = 0; index < 6; index++) {
    if ((query['d${index + 1}'] ?? '')
        .replaceAll(RegExp(r'\D'), '')
        .isNotEmpty) {
      return true;
    }
  }
  return false;
}

class _BuySearchScreenState extends ConsumerState<BuySearchScreen> {
  late final List<TextEditingController> _digits;
  late final Future<CurrentGame?> _currentGameFuture;
  late bool _showResults;
  LotteryCart _cart = LotteryCart.empty();
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _digits = List.generate(6, (_) => TextEditingController());
    _currentGameFuture = _loadCurrentGame();
    _showResults = _queryHasLotterySearchInput(widget.query);
    _syncDigitsFromQuery();
  }

  @override
  void didUpdateWidget(covariant BuySearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query.toString() != widget.query.toString()) {
      _syncDigitsFromQuery();
      _showResults = _queryHasLotterySearchInput(widget.query);
    }
  }

  @override
  void dispose() {
    for (final controller in _digits) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final digits = List.generate(6, (index) => widget.query['d${index + 1}']);
    final exactSearch = isExactLotterySearch(
      number: widget.query['number'] ?? '',
      digits: digits.map((value) => value ?? '').toList(),
    );
    final returnPath = lotterySearchPath(
      number: widget.query['number'] ?? '',
      digits: digits.map((value) => value ?? '').toList(),
      storeId: widget.query['store_id'] ?? '',
      storeName: widget.query['store_name'] ?? '',
    );
    final storeId = (widget.query['store_id'] ?? '').trim();
    final backPath = storeId.isEmpty
        ? '/buy'
        : lotteryStorePath(
            storeId: storeId,
            storeName: widget.query['store_name'] ?? '',
          );
    final searchCardTitle = (widget.query['store_id'] ?? '').trim().isEmpty
        ? l10n.lotterySearchCardTitle
        : l10n.lotterySearchStoreCardTitle;
    return AppShell(
      title: l10n.lotterySearchPageTitle,
      currentPath: '/buy',
      backPath: backPath,
      showBottomNavigation: false,
      heroMinHeight: customerReferenceCompactHeroHeight,
      heroSheetOverlap: 0,
      heroContent: const SizedBox.shrink(),
      child: _LotteryDockedPage(
        dock: _cart.reservationIds.isEmpty
            ? null
            : _CartSelectionDock(
                cart: _cart,
                onReview: _cartSelectionReviewEnabled(_cart)
                    ? () => context.push('/cart')
                    : null,
              ),
        children: [
          Column(
            key: const ValueKey('buy-search-form-section'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      searchCardTitle,
                      style: _lotterySectionTitleTextStyle(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: _searching ? null : _clearDigits,
                    style: _lotteryTextLinkButtonStyle(context),
                    child: Text(l10n.lotteryClearButton),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              FutureBuilder<CurrentGame?>(
                future: _currentGameFuture,
                builder: (context, snapshot) {
                  final drawDate = _lotteryDrawDateLabel(l10n, snapshot.data);
                  return Text(
                    drawDate.isEmpty
                        ? l10n.countdownCurrentDrawFallback
                        : drawDate,
                    style: _lotteryDrawDateTextStyle(context),
                  );
                },
              ),
              const SizedBox(height: 20),
              LotteryDigitInputRow(
                controllers: _digits,
                onSubmitted: _submitDigits,
                style: _lotteryDigitBoxesStyle(context),
              ),
              const SizedBox(height: 22),
              _LotterySearchActions(
                onSearch: _submitDigits,
                searching: _searching,
              ),
              if (!_showResults) ...[
                const SizedBox(height: 31),
                _LotterySearchInitialHint(
                  message: l10n.lotterySearchInitialHint,
                ),
              ],
            ],
          ),
          if (_showResults) ...[
            const Divider(height: 34),
            _LotteryStockList(
              title: l10n.lotterySearchResultsTitle,
              number: widget.query['number'] ?? '',
              digits: digits.map((value) => value ?? '').toList(),
              storeId: widget.query['store_id'] ?? '',
              returnPath: returnPath,
              showMoreLink: !exactSearch,
              showTicketImages: false,
              onCartChanged: _syncCart,
              onResetLoadingChanged: _setSearchLoading,
            ),
          ],
        ],
      ),
    );
  }

  void _submitDigits() {
    if (_searching) return;
    setState(() => _showResults = true);
    context.go(
      lotterySearchPath(
        digits: _digits.map((controller) => controller.text).toList(),
        storeId: widget.query['store_id'] ?? '',
        storeName: widget.query['store_name'] ?? '',
      ),
    );
  }

  void _clearDigits() {
    if (_searching) return;
    for (final controller in _digits) {
      controller.clear();
    }
    setState(() => _showResults = false);
    context.go(
      lotterySearchPath(
        storeId: widget.query['store_id'] ?? '',
        storeName: widget.query['store_name'] ?? '',
      ),
    );
  }

  Future<CurrentGame?> _loadCurrentGame() async {
    try {
      return await ref.read(resultRepositoryProvider).currentGame();
    } catch (error) {
      if (mounted) {
        await handleCustomerOperationalError(
          ref: ref,
          context: context,
          error: error,
        );
      }
      return null;
    }
  }

  void _syncDigitsFromQuery() {
    final values = _queryDigits(widget.query);
    for (var index = 0; index < _digits.length; index++) {
      final next = values[index];
      if (_digits[index].text != next) {
        _digits[index].text = next;
      }
    }
  }

  void _setSearchLoading(bool value) {
    if (!mounted || _searching == value) return;
    setState(() => _searching = value);
  }

  void _syncCart(LotteryCart cart) {
    if (_sameCartSummary(_cart, cart)) return;
    setState(() => _cart = cart);
  }
}

class BuyMoreScreen extends ConsumerStatefulWidget {
  const BuyMoreScreen({super.key, required this.query});

  final Map<String, String> query;

  @override
  ConsumerState<BuyMoreScreen> createState() => _BuyMoreScreenState();
}

class _BuyMoreScreenState extends ConsumerState<BuyMoreScreen> {
  LotteryCart _cart = LotteryCart.empty();

  @override
  Widget build(BuildContext context) {
    final number = widget.query['number'] ?? '';
    final backPath = safeLotteryBackPath(
      widget.query['back'] ?? '',
      fallback: '/buy',
    );
    final l10n = context.l10n;
    return AppShell(
      title: '',
      currentPath: '/buy',
      showBottomNavigation: false,
      automaticallyImplyBack: false,
      heroMinHeight: 142,
      heroSheetOverlap: 24,
      heroContent: const SizedBox.shrink(),
      child: _LotteryDockedPage(
        dock: _cart.reservationIds.isEmpty
            ? null
            : _CartSelectionDock(
                cart: _cart,
                onReview: _cartSelectionReviewEnabled(_cart)
                    ? () => context.push('/cart')
                    : null,
              ),
        children: [
          _LotteryMoreSummaryHeader(
            number: number,
            onClose: () => _goBack(context, backPath),
          ),
          const SizedBox(height: 14),
          _LotteryStockList(
            title: l10n.lotteryMoreListTitle,
            number: number,
            storeId: widget.query['store_id'] ?? '',
            returnPath: backPath,
            showTitle: false,
            showMoreLink: false,
            showFilterPills: false,
            showRefreshAction: false,
            showTicketImages: false,
            useRandomSeed: false,
            onCartChanged: _syncCart,
          ),
        ],
      ),
    );
  }

  void _goBack(BuildContext context, String backPath) {
    navigateCustomerBack(context, fallbackPath: backPath);
  }

  void _syncCart(LotteryCart cart) {
    if (_sameCartSummary(_cart, cart)) return;
    setState(() => _cart = cart);
  }
}

class _LotteryMoreSummaryHeader extends StatelessWidget {
  const _LotteryMoreSummaryHeader({
    required this.number,
    required this.onClose,
  });

  final String number;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final displayNumber = _spacedLotteryNumber(number);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                l10n.lotteryMoreSheetTitle,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: colorScheme.onSurface,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
            ),
            const SizedBox(width: 12),
            _LotteryMoreCloseButton(
              tooltip: l10n.commonBack,
              color: colorScheme.onSurface,
              onClose: onClose,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              l10n.lotteryMoreNumberPrefix,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.w400,
                height: 1.25,
              ),
            ),
            Text(
              displayNumber.isEmpty ? l10n.lotteryMoreFallback : displayNumber,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colorScheme.primary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                height: 1.25,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LotteryMoreCloseButton extends StatelessWidget {
  const _LotteryMoreCloseButton({
    required this.tooltip,
    required this.color,
    required this.onClose,
  });

  final String tooltip;
  final Color color;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onClose,
            child: SizedBox.square(
              dimension: 44,
              child: Center(child: Icon(Icons.close, color: color, size: 34)),
            ),
          ),
        ),
      ),
    );
  }
}

String _spacedLotteryNumber(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  return digits.split('').join(' ');
}

class CartTicketGroup {
  const CartTicketGroup({
    required this.key,
    required this.number,
    required this.items,
    required this.reservationIds,
    required this.total,
    required this.deadlineReservation,
  });

  final String key;
  final String number;
  final List<LotteryStockItem> items;
  final List<String> reservationIds;
  final double total;
  final LotteryReservation? deadlineReservation;

  int get count => items.length;

  LotteryStockItem? get primaryItem => items.isEmpty ? null : items.first;

  String get storeSummary {
    final stores = <String>[];
    for (final item in items) {
      final store = item.storeName.trim();
      if (store.isNotEmpty && !stores.contains(store)) {
        stores.add(store);
      }
    }
    return stores.join(', ');
  }
}

List<CartTicketGroup> groupCartReservationsByNumber(
  List<LotteryReservation> reservations,
) {
  final groups = <String, _MutableCartTicketGroup>{};
  for (final reservation in reservations) {
    if (reservation.status != 'active') continue;
    for (final item in reservation.items) {
      final key = '${reservation.gameId}:${item.number}';
      final group = groups.putIfAbsent(
        key,
        () => _MutableCartTicketGroup(key: key, number: item.number),
      );
      group.items.add(item);
      group.reservations.add(reservation);
      if (reservation.id.isNotEmpty &&
          !group.reservationIds.contains(reservation.id)) {
        group.reservationIds.add(reservation.id);
      }
    }
  }
  return groups.values
      .map((group) => group.toCartTicketGroup())
      .toList(growable: false);
}

class _MutableCartTicketGroup {
  _MutableCartTicketGroup({required this.key, required this.number});

  final String key;
  final String number;
  final List<LotteryStockItem> items = [];
  final List<LotteryReservation> reservations = [];
  final List<String> reservationIds = [];

  CartTicketGroup toCartTicketGroup() {
    return CartTicketGroup(
      key: key,
      number: number,
      items: List.unmodifiable(items),
      reservationIds: List.unmodifiable(reservationIds),
      total: items.fold<double>(0, (sum, item) => sum + item.price),
      deadlineReservation: earliestActiveReservation(reservations),
    );
  }
}

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  LotteryCart _cart = LotteryCart.empty();
  CurrentGame? _currentGame;
  Timer? _deadlineTimer;
  bool _loading = true;
  bool _busy = false;
  bool _releasingExpiredCart = false;
  String _error = '';
  String _noticeMessage = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _deadlineTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(lotteryStockRealtimeTickProvider, (previous, next) {
      if (previous == null || previous == next || _busy) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_loading && !_busy) {
          _load();
        }
      });
    });
    ref.listen<int>(cartRealtimeTickProvider, (previous, next) {
      if (previous == null || previous == next || _busy) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_loading && !_busy) {
          _load();
        }
      });
    });

    final l10n = context.l10n;
    final productMarker = ref
        .watch(mobileBootstrapProvider)
        .maybeWhen(
          data: (bootstrap) => bootstrap.lotteryProductLabel.trim(),
          orElse: () => '',
        );
    final groupedTickets = groupCartReservationsByNumber(_cart.reservations);
    final paymentDeadline = earliestActiveReservation(_cart.reservations);
    final drawDateLabel = _lotteryDrawDateLabel(l10n, _currentGame);
    final paymentExpired =
        paymentDeadline != null && reservationDeadlineExpired(paymentDeadline);
    final canCheckout =
        _cart.reservationIds.isNotEmpty && !paymentExpired && !_busy;
    return AppShell(
      title: l10n.cartTitle,
      currentPath: '/buy',
      backPath: '/buy',
      sensitive: true,
      showBottomNavigation: false,
      heroMinHeight: 205,
      heroSheetOverlap: 0,
      heroContent: _CartHeaderSummary(
        count: _cart.itemCount,
        drawDateLabel: drawDateLabel,
        empty: _cart.isEmpty,
        onHero: true,
      ),
      child: _CartReviewDockedPage(
        physics: const AlwaysScrollableScrollPhysics(),
        dockLeading:
            (!_loading &&
                _error.isEmpty &&
                !(_cart.isEmpty || groupedTickets.isEmpty))
            ? _CartAddMoreButton(onAddMore: () => context.go('/buy'))
            : null,
        dock:
            (!_loading &&
                _error.isEmpty &&
                !(_cart.isEmpty || groupedTickets.isEmpty))
            ? _CartPaymentDock(
                total: _cart.total,
                deadline: paymentDeadline,
                canCheckout: canCheckout,
                onCheckout: () => context.push('/checkout'),
              )
            : null,
        children: [
          if (_loading)
            _CheckoutSheetInset(
              child: _LoadingMessageCard(message: l10n.cartLoading),
            )
          else if (_error.isNotEmpty)
            _CheckoutSheetInset(
              child: _MessageCard(
                icon: Icons.error_outline,
                title: l10n.cartLoadFailedTitle,
                message: _error,
                actionLabel: l10n.commonRetry,
                onAction: _load,
              ),
            )
          else if (_cart.isEmpty || groupedTickets.isEmpty) ...[
            _CartEmptySheetState(
              title: l10n.cartEmptyTitle,
              message: l10n.cartEmptyMessage,
            ),
            _CartPurchaseLimitNotice(onAddMore: () => context.go('/buy')),
          ] else ...[
            if (_noticeMessage.isNotEmpty) ...[
              _InlineNoticeCard(message: _noticeMessage),
              const SizedBox(height: 12),
            ],
            for (final group in groupedTickets)
              _CartTicketGroupCard(
                group: group,
                productMarker: productMarker,
                busy: _busy,
                onRelease: () => _releaseGroup(group),
              ),
            const SizedBox(height: 24),
            const _CartPurchaseLimitMessage(),
          ],
        ],
      ),
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
      _noticeMessage = '';
    });
    try {
      final cart = await ref.read(lotteryRepositoryProvider).cart();
      CurrentGame? currentGame;
      try {
        currentGame = await ref.read(resultRepositoryProvider).currentGame();
      } catch (error) {
        if (mounted &&
            await handleCustomerOperationalError(
              ref: ref,
              context: context,
              error: error,
            )) {
          return;
        }
        currentGame = null;
      }
      if (!mounted) return;
      setState(() {
        _cart = cart;
        if (currentGame != null) {
          _currentGame = currentGame;
        }
      });
    } catch (error) {
      if (!mounted) return;
      if (await handleCustomerOperationalError(
        ref: ref,
        context: context,
        error: error,
      )) {
        return;
      }
      setState(
        () => _error = _errorMessage(error, context.l10n.cartGenericRetry),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        _syncExpiredCartWatcher();
      }
    }
  }

  Future<void> _releaseGroup(CartTicketGroup group) async {
    if (group.reservationIds.isEmpty || _busy) return;
    await showDialog<void>(
      context: context,
      barrierColor: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.65),
      barrierDismissible: false,
      builder: (context) {
        var removing = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final l10n = context.l10n;
            return _CartRemoveConfirmationDialog(
              title: l10n.cartRemoveGroupTitle(group.number, group.count),
              message: l10n.cartRemoveGroupMessage(group.count),
              removing: removing,
              onCancel: () => Navigator.of(context).pop(),
              onConfirm: () => _confirmReleaseGroup(
                group,
                dialogContext: context,
                setDialogState: setDialogState,
                setRemoving: (value) => removing = value,
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmReleaseGroup(
    CartTicketGroup group, {
    required BuildContext dialogContext,
    required StateSetter setDialogState,
    required ValueChanged<bool> setRemoving,
  }) async {
    if (!mounted) return;
    setDialogState(() => setRemoving(true));
    setState(() => _busy = true);
    try {
      var cart = _cart;
      for (final reservationId in group.reservationIds) {
        cart = await ref
            .read(lotteryRepositoryProvider)
            .releaseReservation(reservationId);
      }
      if (!mounted) return;
      setState(() {
        _cart = cart;
        _noticeMessage = '';
      });
      ref.read(cartRealtimeTickProvider.notifier).state++;
      if (dialogContext.mounted) {
        Navigator.of(dialogContext).pop();
      }
    } catch (error) {
      if (!mounted) return;
      final operationalRedirect = ApiErrorInfo.fromObject(
        error,
      ).operationalRedirectPath;
      if (operationalRedirect != null && dialogContext.mounted) {
        Navigator.of(dialogContext).pop();
      }
      if (await handleCustomerOperationalError(
        ref: ref,
        context: context,
        error: error,
      )) {
        return;
      }
      setState(
        () => _noticeMessage = _errorMessage(
          error,
          context.l10n.cartGenericRetry,
        ),
      );
      if (dialogContext.mounted) {
        setDialogState(() => setRemoving(false));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _syncExpiredCartWatcher();
      }
    }
  }

  void _syncExpiredCartWatcher() {
    _deadlineTimer?.cancel();
    if (_loading ||
        _busy ||
        _releasingExpiredCart ||
        _cart.reservationIds.isEmpty) {
      return;
    }

    final deadline = earliestActiveReservation(_cart.reservations);
    if (deadline == null) return;
    if (reservationDeadlineExpired(deadline)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _releaseExpiredCartReservations();
      });
      return;
    }

    _deadlineTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _loading || _busy || _releasingExpiredCart) return;
      final latestDeadline = earliestActiveReservation(_cart.reservations);
      if (latestDeadline == null) {
        _deadlineTimer?.cancel();
        _deadlineTimer = null;
        return;
      }
      if (reservationDeadlineExpired(latestDeadline)) {
        _releaseExpiredCartReservations();
      }
    });
  }

  Future<void> _releaseExpiredCartReservations() async {
    if (_releasingExpiredCart) return;
    final reservationIds = _cart.reservationIds;
    if (reservationIds.isEmpty) return;

    _releasingExpiredCart = true;
    _deadlineTimer?.cancel();
    _deadlineTimer = null;
    if (mounted) setState(() => _busy = true);

    try {
      for (final reservationId in reservationIds) {
        await ref
            .read(lotteryRepositoryProvider)
            .releaseReservation(reservationId);
      }
    } catch (error) {
      if (mounted &&
          await handleCustomerOperationalError(
            ref: ref,
            context: context,
            error: error,
          )) {
        if (mounted) {
          setState(() {
            _busy = false;
            _releasingExpiredCart = false;
          });
        }
        return;
      }
      // Nuxt clears the local cart after timeout even when release refreshes fail.
    }

    if (!mounted) return;
    setState(() {
      _cart = LotteryCart.empty();
      _busy = false;
      _releasingExpiredCart = false;
    });
    ref.read(cartRealtimeTickProvider.notifier).state++;
    context.go('/buy');
  }
}

String _lotteryDrawDateLabel(CustomerLocalizations l10n, CurrentGame? game) {
  final drawDate = parseDateTime(game?.drawAt);
  if (drawDate == null) return '';
  return l10n.cartDrawDate(
    formatLocalizedShortDate(drawDate, localeTag(l10n.locale)),
  );
}

String _paymentAmountWithoutUnit(CustomerLocalizations l10n, num value) {
  final formatted = l10n.formatBaht(value);
  final unit = l10n.commonBahtSuffix.trim();
  if (unit.isEmpty) return formatted;
  return formatted
      .replaceFirst(RegExp(r'\s*' + RegExp.escape(unit) + r'$'), '')
      .trim();
}

String _checkoutAmountWithoutUnit(CustomerLocalizations l10n, num value) {
  final amount = _paymentAmountWithoutUnit(l10n, value);
  final numericValue = value.toDouble();
  if (!numericValue.isFinite ||
      (numericValue - numericValue.roundToDouble()).abs() > 0.000001) {
    return amount;
  }
  return amount.replaceFirst(RegExp(r'[\.,]00$'), '');
}

class _CartHeaderSummary extends StatelessWidget {
  const _CartHeaderSummary({
    required this.count,
    required this.drawDateLabel,
    required this.empty,
    this.onHero = false,
  });

  final int count;
  final String drawDateLabel;
  final bool empty;
  final bool onHero;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final titleColor = onHero ? colorScheme.onPrimary : colorScheme.onSurface;
    final subtitleColor = onHero
        ? colorScheme.onPrimary.withValues(alpha: 0.88)
        : colorScheme.onSurfaceVariant;
    final summary = Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.cartHeaderCount(count),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: titleColor,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (drawDateLabel.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              drawDateLabel,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: subtitleColor,
                fontWeight: FontWeight.w400,
              ),
            ),
          ] else if (empty) ...[
            const SizedBox(height: 4),
            Text(
              l10n.cartEmptySubtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: subtitleColor,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ],
      ),
    );

    if (!onHero) return summary;
    return Align(
      alignment: Alignment.topLeft,
      child: Padding(padding: const EdgeInsets.only(top: 4), child: summary),
    );
  }
}

class _CartEmptySheetState extends StatelessWidget {
  const _CartEmptySheetState({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 52),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.appMuted,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.appMuted,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _CartPurchaseLimitNotice extends StatelessWidget {
  const _CartPurchaseLimitNotice({required this.onAddMore});

  final VoidCallback onAddMore;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _CartPurchaseLimitMessage(),
        const SizedBox(height: 12),
        _CartAddMoreButton(onAddMore: onAddMore),
      ],
    );
  }
}

class _CartPurchaseLimitMessage extends StatelessWidget {
  const _CartPurchaseLimitMessage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Text(
        context.l10n.cartPurchaseLimitMessage,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppTheme.appMuted,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          height: 1.45,
        ),
      ),
    );
  }
}

class _CartAddMoreButton extends StatelessWidget {
  const _CartAddMoreButton({required this.onAddMore});

  final VoidCallback onAddMore;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Align(
      alignment: Alignment.center,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.appGreenPillStart, AppTheme.appGreenPillEnd],
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: FilledButton.icon(
          onPressed: onAddMore,
          style:
              FilledButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: AppTheme.appSheet,
                shadowColor: Colors.transparent,
                minimumSize: const Size(0, 47),
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 12,
                ),
                shape: const StadiumBorder(),
                textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ).copyWith(
                overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              ),
          icon: const Icon(Icons.add, size: 22),
          label: Text(l10n.cartAddMoreTickets),
        ),
      ),
    );
  }
}

class _CartRemoveConfirmationDialog extends StatelessWidget {
  const _CartRemoveConfirmationDialog({
    required this.title,
    required this.message,
    required this.removing,
    required this.onCancel,
    required this.onConfirm,
  });

  final String title;
  final String message;
  final bool removing;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final actionTextStyle = theme.textTheme.titleSmall?.copyWith(
      fontSize: 18,
      fontWeight: FontWeight.w800,
    );
    return Dialog(
      key: const ValueKey('cart-remove-confirmation-dialog'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      backgroundColor: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 338),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 30, 24, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: colorScheme.onSurface,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 27),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 54,
                      child: OutlinedButton(
                        onPressed: removing ? null : onCancel,
                        style:
                            _lotteryOutlinePillButtonStyle(
                              context,
                              enabled: !removing,
                            ).copyWith(
                              textStyle: WidgetStatePropertyAll(
                                actionTextStyle,
                              ),
                            ),
                        child: Text(l10n.commonCancel),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CustomerGradientButton.text(
                      onPressed: removing ? null : onConfirm,
                      height: 54,
                      fontSize: 18,
                      label: removing
                          ? l10n.cartRemoveGroupRemoving
                          : l10n.cartRemoveGroupConfirm,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartPaymentDock extends StatelessWidget {
  const _CartPaymentDock({
    required this.total,
    required this.canCheckout,
    required this.onCheckout,
    this.deadline,
  });

  final double total;
  final LotteryReservation? deadline;
  final bool canCheckout;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final amount = _paymentAmountWithoutUnit(l10n, total);
    final bahtUnit = l10n.commonBahtSuffix;
    return DecoratedBox(
      key: const ValueKey('cart-payment-dock'),
      decoration: _lotterySurfaceDecoration(
        context,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        borderColor: Colors.transparent,
        shadowAlpha: 0.12,
        blurRadius: 26,
        shadowOffset: const Offset(0, -8),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          18,
          22,
          18,
          28 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (deadline != null) ...[
              Center(
                child: _ReservationCountdownText(
                  reservation: deadline!,
                  countdownLabelBuilder: (l10n, time) =>
                      l10n.checkoutPaymentTimer(time),
                  paymentDockStyle: true,
                ),
              ),
              const SizedBox(height: 16),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    l10n.checkoutSummaryTotal,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        amount,
                        key: const ValueKey('cart-payment-dock-amount'),
                        textAlign: TextAlign.end,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: colorScheme.primary,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                      if (bahtUnit.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Text(
                          bahtUnit,
                          key: const ValueKey('cart-payment-dock-unit'),
                          textAlign: TextAlign.end,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: colorScheme.onSurface,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                height: 1.1,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            CustomerGradientButton.text(
              onPressed: canCheckout ? onCheckout : null,
              height: 56,
              fontSize: 18,
              label: canCheckout ? l10n.cartCheckout : l10n.cartExpired,
            ),
          ],
        ),
      ),
    );
  }
}

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

String checkoutPendingPaymentPath(String orderId) {
  return Uri(
    path: '/checkout/pending',
    queryParameters: {
      if (orderId.trim().isNotEmpty) 'order_id': orderId.trim(),
    },
  ).toString();
}

String checkoutSuccessPath(String orderId) {
  return Uri(
    path: '/success',
    queryParameters: {
      if (orderId.trim().isNotEmpty) 'order_id': orderId.trim(),
    },
  ).toString();
}

class CheckoutPendingPaymentScreen extends ConsumerStatefulWidget {
  const CheckoutPendingPaymentScreen({required this.orderId, super.key});

  final String orderId;

  @override
  ConsumerState<CheckoutPendingPaymentScreen> createState() =>
      _CheckoutPendingPaymentScreenState();
}

class _CheckoutPendingPaymentScreenState
    extends ConsumerState<CheckoutPendingPaymentScreen> {
  String _noticeMessage = '';
  String _handledPaidOrderId = '';

  @override
  Widget build(BuildContext context) {
    final id = widget.orderId.trim();
    if (id.isNotEmpty) {
      listenForCustomerOperationalError<PurchaseHistoryOrder>(
        ref: ref,
        context: context,
        provider: purchaseHistoryDetailProvider(id),
      );
    }
    final order = id.isEmpty
        ? const AsyncValue<PurchaseHistoryOrder?>.data(null)
        : ref.watch(purchaseHistoryDetailProvider(id)).whenData((value) {
            return value;
          });
    return AppShell(
      title: context.l10n.checkoutPendingTitle,
      currentPath: '/buy',
      backPath: '/checkout',
      sensitive: true,
      showBottomNavigation: false,
      heroMinHeight: customerReferenceCompactHeroHeight,
      heroSheetOverlap: 0,
      heroContentTopGap: 0,
      heroContent: const SizedBox.shrink(),
      child: order.when(
        data: (item) {
          if (item != null && _checkoutOrderPaid(item)) {
            final successOrderId = item.id.trim().isNotEmpty ? item.id : id;
            if (_handledPaidOrderId != successOrderId) {
              _handledPaidOrderId = successOrderId;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                ref
                    .read(customerRevenueCacheProvider)
                    .orderChanged(
                      orderIds: [successOrderId],
                      invalidateOrderDetails: false,
                    );
                context.go(checkoutSuccessPath(successOrderId));
              });
            }
            return _LotteryDockedPage(
              children: [
                _LoadingMessageCard(
                  message: context.l10n.checkoutPendingLoading,
                ),
              ],
            );
          }
          return _LotteryDockedPage(
            children: [
              if (_noticeMessage.isNotEmpty) ...[
                _InlineNoticeCard(message: _noticeMessage),
                const SizedBox(height: 12),
              ],
              if (item == null)
                _MessageCard(
                  icon: Icons.payment_outlined,
                  title: context.l10n.checkoutPendingNoOrderTitle,
                  message: context.l10n.checkoutPendingNoOrderMessage,
                  actionLabel: context.l10n.checkoutBackToBuy,
                  onAction: () => context.go('/buy'),
                )
              else
                _CheckoutPendingPaymentCard(
                  order: item,
                  onOpenPayment: item.redirectUri == null
                      ? null
                      : () => _openPendingPayment(
                          context,
                          ref,
                          item.redirectUri!,
                        ),
                  onRefresh: () =>
                      ref.invalidate(purchaseHistoryDetailProvider(item.id)),
                  onViewReceipt: () =>
                      context.push(checkoutSuccessPath(item.id)),
                ),
            ],
          );
        },
        loading: () => _LotteryDockedPage(
          children: [
            _LoadingMessageCard(message: context.l10n.checkoutPendingLoading),
          ],
        ),
        error: (error, _) => _LotteryDockedPage(
          children: [
            _MessageCard(
              icon: Icons.error_outline,
              title: context.l10n.checkoutLoadFailedTitle,
              message: _errorMessage(error, context.l10n.cartGenericRetry),
              actionLabel: context.l10n.commonRetry,
              onAction: () => ref.invalidate(purchaseHistoryDetailProvider(id)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPendingPayment(
    BuildContext context,
    WidgetRef ref,
    Uri uri,
  ) async {
    setState(() => _noticeMessage = '');
    final ok = await ref.read(customerLinkLauncherProvider).openExternal(uri);
    if (!context.mounted || ok) return;
    setState(() => _noticeMessage = context.l10n.checkoutOpenPaymentFailed);
  }
}

class _CheckoutPendingPaymentCard extends StatelessWidget {
  const _CheckoutPendingPaymentCard({
    required this.order,
    required this.onOpenPayment,
    required this.onRefresh,
    required this.onViewReceipt,
  });

  final PurchaseHistoryOrder order;
  final VoidCallback? onOpenPayment;
  final VoidCallback onRefresh;
  final VoidCallback onViewReceipt;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final paid = _checkoutOrderPaid(order);
    return DecoratedBox(
      decoration: _lotterySurfaceDecoration(
        context,
        borderColor: colorScheme.outlineVariant.withValues(alpha: 0.45),
        blurRadius: 16,
        shadowAlpha: 0.06,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.center,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: paid
                      ? colorScheme.primary.withValues(alpha: 0.10)
                      : colorScheme.tertiaryContainer.withValues(alpha: 0.72),
                  shape: BoxShape.circle,
                ),
                child: SizedBox.square(
                  dimension: 62,
                  child: Icon(
                    paid ? Icons.check_rounded : Icons.pending_actions,
                    color: paid
                        ? colorScheme.primary
                        : colorScheme.onTertiaryContainer,
                    size: paid ? 34 : 30,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              paid ? l10n.checkoutPendingPaidTitle : l10n.checkoutPendingTitle,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              paid
                  ? l10n.checkoutPendingPaidMessage
                  : l10n.checkoutPendingMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                height: 1.45,
              ),
            ),
            Divider(
              height: 30,
              color: colorScheme.outlineVariant.withValues(alpha: 0.64),
            ),
            _CheckoutPendingInfoRow(
              label: l10n.checkoutPendingReferenceLabel,
              value: order.displayReference,
            ),
            _CheckoutPendingInfoRow(
              label: l10n.checkoutPendingAmountLabel,
              trailing: _CheckoutPendingAmountValue(total: order.total),
            ),
            _CheckoutPendingInfoRow(
              label: l10n.checkoutPendingStatusLabel,
              trailing: _CheckoutPendingStatusBadge(order: order),
            ),
            const SizedBox(height: 18),
            if (paid)
              CustomerGradientButton.text(
                onPressed: onViewReceipt,
                height: 52,
                label: l10n.checkoutPendingViewReceipt,
              )
            else ...[
              if (onOpenPayment != null) ...[
                CustomerGradientButton.text(
                  onPressed: onOpenPayment,
                  height: 52,
                  label: l10n.checkoutPendingOpenPayment,
                ),
                const SizedBox(height: 10),
              ],
              SizedBox(
                height: 50,
                child: OutlinedButton(
                  onPressed: onRefresh,
                  style: _lotteryOutlinePillButtonStyle(context),
                  child: Text(l10n.checkoutPendingRefresh),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CheckoutPendingAmountValue extends StatelessWidget {
  const _CheckoutPendingAmountValue({required this.total});

  final double total;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final amount = _paymentAmountWithoutUnit(l10n, total);
    final unit = l10n.commonBahtSuffix.trim();
    return Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: 4,
      children: [
        Text(
          amount,
          key: const ValueKey('checkout-pending-amount'),
          textAlign: TextAlign.end,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: colorScheme.primary,
            fontSize: 28,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
        if (unit.isNotEmpty)
          Text(
            unit,
            key: const ValueKey('checkout-pending-amount-unit'),
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w500,
              height: 1.1,
            ),
          ),
      ],
    );
  }
}

class _CheckoutPendingInfoRow extends StatelessWidget {
  const _CheckoutPendingInfoRow({
    required this.label,
    this.value,
    this.trailing,
  }) : assert(value != null || trailing != null);

  final String label;
  final String? value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final valueWidget =
        trailing ??
        Text(
          value!,
          textAlign: TextAlign.right,
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 340) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 4),
                Align(alignment: Alignment.centerRight, child: valueWidget),
              ],
            );
          }
          return Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                    height: 1.25,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(child: valueWidget),
            ],
          );
        },
      ),
    );
  }
}

class _CheckoutPendingStatusBadge extends StatelessWidget {
  const _CheckoutPendingStatusBadge({required this.order});

  final PurchaseHistoryOrder order;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final value = _checkoutPendingStatusValue(order);
    final colors = switch (value) {
      'paid' => (
        colorScheme.primary.withValues(alpha: 0.12),
        colorScheme.primary,
      ),
      'failed' || 'cancelled' || 'rejected' => (
        colorScheme.errorContainer.withValues(alpha: 0.56),
        colorScheme.error,
      ),
      'expired' => (
        colorScheme.surfaceContainerHighest.withValues(alpha: 0.78),
        colorScheme.onSurfaceVariant,
      ),
      'pending_payment' || 'pending' || 'processing' => (
        colorScheme.tertiaryContainer.withValues(alpha: 0.72),
        colorScheme.onTertiaryContainer,
      ),
      _ => (
        colorScheme.surfaceContainerHighest.withValues(alpha: 0.78),
        colorScheme.onSurfaceVariant,
      ),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.$1,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Text(
          _checkoutPendingStatusLabel(l10n, order),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.right,
          style: TextStyle(
            color: colors.$2,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
      ),
    );
  }
}

bool _checkoutOrderPaid(PurchaseHistoryOrder order) {
  final paymentStatus = order.paymentStatus.trim().toLowerCase();
  final status = order.status.trim().toLowerCase();
  return paymentStatus == 'paid' || status == 'paid';
}

String _checkoutPendingStatusValue(PurchaseHistoryOrder order) {
  return (order.paymentStatus.isNotEmpty ? order.paymentStatus : order.status)
      .trim()
      .toLowerCase();
}

String _checkoutPendingStatusLabel(
  CustomerLocalizations l10n,
  PurchaseHistoryOrder order,
) {
  final value = _checkoutPendingStatusValue(order);
  return switch (value) {
    'paid' => l10n.checkoutPendingStatusPaid,
    'pending_payment' ||
    'pending' ||
    'processing' => l10n.checkoutPendingStatusPending,
    'failed' || 'cancelled' || 'rejected' => l10n.checkoutPendingStatusFailed,
    'expired' => l10n.checkoutPendingStatusExpired,
    _ => l10n.checkoutPendingStatusUnknown,
  };
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  LotteryCart _cart = LotteryCart.empty();
  Timer? _deadlineTimer;
  CustomerWallet? _primaryWallet;
  double _walletBalance = 0;
  String _walletError = '';
  String _selectedPaymentMethod = '';
  bool _loading = true;
  bool _walletLoading = false;
  bool _submitting = false;
  bool _releasingExpiredCart = false;
  bool _pinStep = false;
  String _pin = '';
  String _pinError = '';
  String _error = '';
  String _noticeMessage = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _deadlineTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(lotteryStockRealtimeTickProvider, (previous, next) {
      if (previous == null || previous == next || _submitting) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_loading && !_submitting) {
          _load();
        }
      });
    });
    ref.listen<int>(cartRealtimeTickProvider, (previous, next) {
      if (previous == null || previous == next || _submitting) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_loading && !_submitting) {
          _load();
        }
      });
    });

    final l10n = context.l10n;
    if (_pinStep) {
      return PinConfirmationStep(
        title: l10n.checkoutPinTitle,
        subtitle: l10n.checkoutPinSubtitle,
        pin: _pin,
        error: _pinError,
        saving: _submitting,
        biometricEnabled: false,
        biometricLabel: l10n.pinUseBiometric,
        onBack: _cancelCheckoutPin,
        onDigit: _appendCheckoutPinDigit,
        onBackspace: _removeCheckoutPinDigit,
        onBiometric: () {},
      );
    }
    final paymentMethods = ref.watch(checkoutPaymentMethodsProvider);
    final paymentMethodLabels = ref.watch(checkoutPaymentMethodLabelsProvider);
    final defaultPaymentMethod = ref.watch(checkoutPaymentMethodProvider);
    final selectedPaymentMethod = _effectiveCheckoutPaymentMethod(
      paymentMethods,
      defaultPaymentMethod,
    );
    final usesWallet = selectedPaymentMethod == checkoutPaymentMethodWallet;
    final paymentDeadline = earliestActiveReservation(_cart.reservations);
    final paymentExpired =
        paymentDeadline != null && reservationDeadlineExpired(paymentDeadline);
    final hasActivePayment = _cart.reservationIds.isNotEmpty && !paymentExpired;
    final enoughBalance = _walletBalance >= _cart.total;
    final canUseSelectedPayment =
        !usesWallet || (!_walletLoading && enoughBalance);
    final walletName = _primaryWallet?.name.trim().isNotEmpty == true
        ? _primaryWallet!.name.trim()
        : l10n.checkoutWalletFallbackName;
    final confirmLabel = _submitting
        ? l10n.checkoutSubmitting
        : paymentExpired || !hasActivePayment
        ? l10n.cartExpired
        : usesWallet && _walletLoading
        ? l10n.checkoutWalletLoading
        : canUseSelectedPayment
        ? l10n.checkoutConfirm
        : l10n.checkoutInsufficientTitle;
    return AppShell(
      title: l10n.checkoutTitle,
      currentPath: '/buy',
      backPath: '/cart',
      sensitive: true,
      showBottomNavigation: false,
      heroMinHeight: 300,
      heroSheetOverlap: 0,
      heroContentTopGap: 16,
      heroHeaderVariant: CustomerHeroHeaderVariant.rewardFlow,
      heroContent: _CheckoutHeroSummaryCard(
        ticketCount: _cart.itemCount,
        total: _cart.total,
        loading: _loading,
        error: _error,
      ),
      child: _CheckoutDockedPage(
        physics: const AlwaysScrollableScrollPhysics(),
        dock:
            (!_loading &&
                _error.isEmpty &&
                !(_cart.isEmpty || !hasActivePayment))
            ? _CheckoutConfirmDock(
                deadline: paymentDeadline,
                submitting: _submitting,
                enabled: canUseSelectedPayment && hasActivePayment,
                label: confirmLabel,
                onConfirm: _startCheckoutPin,
              )
            : null,
        children: [
          if (_loading)
            _CheckoutSheetInset(
              child: _LoadingMessageCard(message: l10n.checkoutPreparing),
            )
          else if (_error.isNotEmpty)
            _CheckoutSheetInset(
              child: _MessageCard(
                icon: Icons.error_outline,
                title: l10n.checkoutLoadFailedTitle,
                message: _error,
                actionLabel: l10n.commonRetry,
                onAction: _load,
              ),
            )
          else if (_cart.isEmpty || !hasActivePayment)
            _CheckoutSheetInset(
              child: _MessageCard(
                icon: Icons.shopping_cart_outlined,
                title: l10n.checkoutNoPaymentTitle,
                message: l10n.checkoutNoPaymentMessage,
                actionLabel: l10n.checkoutBackToBuy,
                onAction: () => context.go('/buy'),
              ),
            )
          else ...[
            if (_noticeMessage.isNotEmpty) ...[
              _CheckoutSheetInset(
                child: _InlineNoticeCard(message: _noticeMessage),
              ),
              const SizedBox(height: 12),
            ],
            _CheckoutPaymentMethodCard(
              walletName: walletName,
              balance: _walletBalance,
              walletLoading: _walletLoading,
              enoughBalance: enoughBalance,
              walletError: _walletError,
              methods: paymentMethods,
              methodLabels: paymentMethodLabels,
              selectedMethod: selectedPaymentMethod,
              onMethodChanged: (method) {
                setState(() {
                  _selectedPaymentMethod = method;
                  _noticeMessage = '';
                });
              },
              onTopup: () => context.push('/topup?back=/checkout'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _load() async {
    final walletLoadFailed = context.l10n.checkoutWalletLoadFailed;
    setState(() {
      _loading = true;
      _error = '';
      _noticeMessage = '';
      _walletError = '';
      _walletLoading = false;
    });
    late final LotteryCart cart;
    try {
      cart = await ref.read(lotteryRepositoryProvider).cart();
    } catch (error) {
      if (!mounted) return;
      if (await handleCustomerOperationalError(
        ref: ref,
        context: context,
        error: error,
      )) {
        return;
      }
      setState(() {
        _error = _errorMessage(error, context.l10n.cartGenericRetry);
        _loading = false;
        _walletLoading = false;
      });
      _syncExpiredCartWatcher();
      return;
    }
    if (!mounted) return;
    final needsWalletSummary = _checkoutPaymentMethodsUseWallet(
      ref.read(checkoutPaymentMethodsProvider),
    );
    setState(() {
      _cart = cart;
      _loading = false;
      _walletLoading = needsWalletSummary;
      if (!needsWalletSummary) {
        _primaryWallet = null;
        _walletBalance = 0;
        _walletError = '';
      }
    });
    _syncExpiredCartWatcher();

    if (!needsWalletSummary) return;

    WalletSummary? walletSummary;
    var walletError = '';
    try {
      walletSummary = await ref.read(walletRepositoryProvider).summary();
    } catch (error) {
      if (mounted &&
          await handleCustomerOperationalError(
            ref: ref,
            context: context,
            error: error,
          )) {
        if (mounted) {
          setState(() => _walletLoading = false);
        }
        return;
      }
      walletError = _errorMessage(error, walletLoadFailed);
    }
    if (!mounted) return;
    setState(() {
      _primaryWallet = walletSummary?.primaryWallet;
      _walletBalance = walletSummary?.balance ?? 0;
      _walletError = walletError;
      _walletLoading = false;
    });
    _syncExpiredCartWatcher();
  }

  void _startCheckoutPin() {
    if (_submitting) return;
    setState(() {
      _pinStep = true;
      _pin = '';
      _pinError = '';
      _noticeMessage = '';
    });
  }

  void _cancelCheckoutPin() {
    if (_submitting) return;
    setState(() {
      _pinStep = false;
      _pin = '';
      _pinError = '';
    });
  }

  void _appendCheckoutPinDigit(String digit) {
    if (_submitting || _pin.length >= 6 || !RegExp(r'^\d$').hasMatch(digit)) {
      return;
    }
    setState(() {
      _pin += digit;
      _pinError = '';
    });
    if (_pin.length == 6) _submitCheckout();
  }

  void _removeCheckoutPinDigit() {
    if (_submitting || _pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _pinError = '';
    });
  }

  Future<void> _submitCheckout() async {
    final deadline = earliestActiveReservation(_cart.reservations);
    if (_cart.reservationIds.isEmpty ||
        _submitting ||
        (deadline != null && reservationDeadlineExpired(deadline))) {
      if (deadline != null && reservationDeadlineExpired(deadline)) {
        await _releaseExpiredCartReservations();
      }
      return;
    }
    setState(() {
      _submitting = true;
      _noticeMessage = '';
    });
    try {
      await ref.read(affiliateReferralServiceProvider).applyStored();
      final paymentMethod = _effectiveCheckoutPaymentMethod(
        ref.read(checkoutPaymentMethodsProvider),
        ref.read(checkoutPaymentMethodProvider),
      );
      final order = await ref
          .read(lotteryRepositoryProvider)
          .checkout(
            _cart.reservationIds,
            paymentMethod: paymentMethod,
            pin: _pin,
          );
      if (!mounted) return;
      ref.read(successReceiptFallbackOrderProvider.notifier).state =
          successReceiptFallbackFromCheckout(order: order, cart: _cart);
      ref
          .read(customerRevenueCacheProvider)
          .orderChanged(
            orderIds: [order.id],
            settlementChanged:
                paymentMethod != checkoutPaymentMethodExternalPayment,
          );
      if (paymentMethod == checkoutPaymentMethodExternalPayment) {
        await _openExternalPayment(order);
        if (!mounted) return;
        context.go(checkoutPendingPaymentPath(order.id));
        return;
      }
      context.go(
        Uri(
          path: '/success',
          queryParameters: {if (order.id.isNotEmpty) 'order_id': order.id},
        ).toString(),
      );
    } catch (error) {
      if (!mounted) return;
      final code = ApiErrorInfo.fromObject(error).code;
      if (code == 'pin_invalid' ||
          code == 'pin_locked' ||
          code == 'pin_required' ||
          code == 'pin_setup_required') {
        setState(() {
          _pin = '';
          _pinError = switch (code) {
            'pin_locked' => context.l10n.checkoutPinLocked,
            'pin_required' ||
            'pin_setup_required' => context.l10n.checkoutPinSetupRequired,
            _ => context.l10n.checkoutPinInvalid,
          };
        });
        return;
      }
      if (await handleCustomerOperationalError(
        ref: ref,
        context: context,
        error: error,
        handlePinRedirect: false,
      )) {
        return;
      }
      setState(() {
        _pinStep = false;
        _pin = '';
        _pinError = '';
        _noticeMessage = _checkoutErrorMessage(
          error,
          context.l10n.checkoutFailed,
        );
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _effectiveCheckoutPaymentMethod(
    List<String> configuredMethods,
    String configuredDefault,
  ) {
    final methods = configuredMethods.isEmpty
        ? const [checkoutPaymentMethodWallet]
        : configuredMethods;
    if (methods.contains(_selectedPaymentMethod)) {
      return _selectedPaymentMethod;
    }
    if (methods.contains(configuredDefault)) return configuredDefault;
    return methods.first;
  }

  bool _checkoutPaymentMethodsUseWallet(List<String> configuredMethods) {
    final methods = configuredMethods.isEmpty
        ? const [checkoutPaymentMethodWallet]
        : configuredMethods;
    return methods.contains(checkoutPaymentMethodWallet);
  }

  Future<void> _openExternalPayment(LotteryCheckoutOrder order) async {
    final uri = order.redirectUri;
    if (uri == null) return;
    bool ok;
    try {
      ok = await ref.read(customerLinkLauncherProvider).openExternal(uri);
    } catch (_) {
      ok = false;
    }
    if (!mounted || ok) return;
    setState(() => _noticeMessage = context.l10n.checkoutOpenPaymentFailed);
  }

  void _syncExpiredCartWatcher() {
    _deadlineTimer?.cancel();
    if (_loading ||
        _submitting ||
        _releasingExpiredCart ||
        _cart.reservationIds.isEmpty) {
      return;
    }

    final deadline = earliestActiveReservation(_cart.reservations);
    if (deadline == null) return;
    if (reservationDeadlineExpired(deadline)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _releaseExpiredCartReservations();
      });
      return;
    }

    _deadlineTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _loading || _submitting || _releasingExpiredCart) return;
      final latestDeadline = earliestActiveReservation(_cart.reservations);
      if (latestDeadline == null) {
        _deadlineTimer?.cancel();
        _deadlineTimer = null;
        return;
      }
      if (reservationDeadlineExpired(latestDeadline)) {
        _releaseExpiredCartReservations();
      } else {
        setState(() {});
      }
    });
  }

  Future<void> _releaseExpiredCartReservations() async {
    if (_releasingExpiredCart) return;
    final reservationIds = _cart.reservationIds;
    if (reservationIds.isEmpty) return;

    _releasingExpiredCart = true;
    _deadlineTimer?.cancel();
    _deadlineTimer = null;
    if (mounted) setState(() => _submitting = true);

    try {
      for (final reservationId in reservationIds) {
        await ref
            .read(lotteryRepositoryProvider)
            .releaseReservation(reservationId);
      }
    } catch (error) {
      if (mounted &&
          await handleCustomerOperationalError(
            ref: ref,
            context: context,
            error: error,
          )) {
        if (mounted) {
          setState(() {
            _submitting = false;
            _releasingExpiredCart = false;
          });
        }
        return;
      }
      // Nuxt clears the local cart after timeout even when release refreshes fail.
    }

    if (!mounted) return;
    setState(() {
      _cart = LotteryCart.empty();
      _submitting = false;
      _releasingExpiredCart = false;
    });
    context.go('/buy');
  }
}

class _LotteryStockList extends ConsumerStatefulWidget {
  const _LotteryStockList({
    required this.title,
    this.number = '',
    this.digits = const [],
    this.storeId = '',
    this.returnPath = '/buy',
    this.showMoreLink = true,
    this.showTitle = true,
    this.showFilterPills = true,
    this.showRefreshAction = true,
    this.showTicketImages = true,
    this.useRandomSeed = true,
    this.onCartChanged,
    this.onResetLoadingChanged,
  });

  final String title;
  final String number;
  final List<String> digits;
  final String storeId;
  final String returnPath;
  final bool showMoreLink;
  final bool showTitle;
  final bool showFilterPills;
  final bool showRefreshAction;
  final bool showTicketImages;
  final bool useRandomSeed;
  final ValueChanged<LotteryCart>? onCartChanged;
  final ValueChanged<bool>? onResetLoadingChanged;

  @override
  ConsumerState<_LotteryStockList> createState() => _LotteryStockListState();
}

class _LotteryStockListState extends ConsumerState<_LotteryStockList> {
  final _items = <LotteryStockItem>[];
  final _reservedByStockId = <String, String>{};
  ScrollPosition? _scrollPosition;
  Timer? _refreshCooldownTimer;
  Timer? _priceTrendClearTimer;
  LotteryCart _cart = LotteryCart.empty();
  LotteryStockPricePatch? _activePricePatch;
  String _gameId = '';
  String _cursor = '';
  String _randomSeed = '';
  int _refreshCooldownSeconds = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _refreshingCart = false;
  bool _hasMore = false;
  bool _canReserve = true;
  String _error = '';
  String _busyStockId = '';
  String _stockNoticeMessage = '';
  bool _stockNoticeSuccess = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(reset: true));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _attachScrollListener(),
    );
  }

  @override
  void didUpdateWidget(covariant _LotteryStockList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.number != widget.number ||
        oldWidget.storeId != widget.storeId ||
        oldWidget.digits.join() != widget.digits.join() ||
        oldWidget.useRandomSeed != widget.useRandomSeed) {
      _randomSeed = '';
      if (!_isBrowseMode) {
        _stopRefreshCooldown();
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => _load(reset: true));
    }
  }

  @override
  void dispose() {
    _scrollPosition?.removeListener(_handleParentScroll);
    _refreshCooldownTimer?.cancel();
    _priceTrendClearTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(lotteryStockRealtimeTickProvider, (previous, next) {
      if (previous == null || previous == next || _busyStockId.isNotEmpty) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_loading && !_loadingMore && _busyStockId.isEmpty) {
          _load(reset: true);
        }
      });
    });
    ref.listen<int>(cartRealtimeTickProvider, (previous, next) {
      if (previous == null ||
          previous == next ||
          _busyStockId.isNotEmpty ||
          _refreshingCart) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            !_loading &&
            !_loadingMore &&
            _busyStockId.isEmpty &&
            !_refreshingCart) {
          unawaited(_refreshCartQuietly());
        }
      });
    });
    ref.listen<LotteryStockPricePatch?>(lotteryStockPricePatchProvider, (
      previous,
      next,
    ) {
      if (next == null || previous?.flashKey == next.flashKey) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _applyPricePatch(next);
      });
    });
    ref.listen<LotteryStockAvailabilityPatch?>(
      lotteryStockAvailabilityPatchProvider,
      (previous, next) {
        if (next == null || previous?.flashKey == next.flashKey) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _applyAvailabilityPatch(next);
        });
      },
    );

    final l10n = context.l10n;
    final refreshCoolingDown = _isBrowseMode && _refreshCooldownSeconds > 0;
    final refreshLabel = _loading
        ? (_isBrowseMode ? l10n.lotteryLoadingNew : l10n.lotteryShowNew)
        : refreshCoolingDown
        ? l10n.lotteryRefreshCooldown(_refreshCooldownSeconds)
        : l10n.lotteryShowNew;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showTitle) ...[
          _LotterySectionHeading(
            title: widget.title,
            action: widget.showRefreshAction
                ? OutlinedButton.icon(
                    onPressed: _loading || refreshCoolingDown
                        ? null
                        : _refreshStockList,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: Text(refreshLabel),
                    style: _lotteryOutlinePillButtonStyle(
                      context,
                      enabled: !_loading && !refreshCoolingDown,
                    ),
                  )
                : null,
          ),
          if (widget.showFilterPills) ...[
            const SizedBox(height: 10),
            const _LotteryFilterPills(),
          ],
          const SizedBox(height: 12),
        ] else if (widget.showFilterPills) ...[
          const _LotteryFilterPills(),
          const SizedBox(height: 12),
        ],
        _buildListContent(context, l10n),
      ],
    );
  }

  Widget _buildListContent(BuildContext context, CustomerLocalizations l10n) {
    if (_loading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: lotteryStockSkeletonCards(),
      );
    }
    if (_error.isNotEmpty) {
      return _MessageCard(
        icon: Icons.error_outline,
        title: l10n.lotteryLoadFailed,
        message: _error,
        actionLabel: l10n.commonRetry,
        onAction: () => _load(reset: true),
      );
    }
    if (_items.isEmpty) {
      return _LotteryEmptyState(message: l10n.lotteryNotFoundTitle);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_stockNoticeMessage.isNotEmpty) ...[
          _InlineNoticeCard(
            message: _stockNoticeMessage,
            success: _stockNoticeSuccess,
            actionLabel: _stockNoticeSuccess ? l10n.lotteryCartAction : null,
            onAction: _stockNoticeSuccess ? () => context.push('/cart') : null,
          ),
          const SizedBox(height: 12),
        ],
        if (!_canReserve) ...[
          _LotteryStatusAlert(title: l10n.lotterySaleClosedTitle),
          const SizedBox(height: 12),
        ],
        for (var index = 0; index < _items.length; index++) ...[
          _LotteryStockCard(
            item: _items[index],
            reserved: _reservedIdForStock(_items[index]) != null,
            busy: _busyStockId == _stockUiKey(_items[index]),
            reserveDisabled: !_canReserve,
            showSellerName: false,
            showTicketImage: widget.showTicketImages,
            highlightDigits: widget.digits,
            morePath: widget.showMoreLink
                ? lotteryMorePath(
                    number: _items[index].number,
                    storeId: widget.storeId,
                    backPath: widget.returnPath,
                  )
                : '',
            onReserve: () => _toggleReservation(_items[index]),
          ),
        ],
        if (_loadingMore) ...[...lotteryStockSkeletonCards()],
      ],
    );
  }

  Future<void> _load({required bool reset}) async {
    if (_loadingMore || (!reset && (_loading || !_hasMore))) return;
    setState(() {
      _error = '';
      if (reset) {
        _loading = true;
        _cursor = '';
        _items.clear();
        _stockNoticeMessage = '';
      } else {
        _loadingMore = true;
      }
    });
    if (reset) widget.onResetLoadingChanged?.call(true);
    try {
      var gameId = _gameId;
      if (gameId.isEmpty || reset) {
        final game = await ref.read(resultRepositoryProvider).currentGame();
        gameId = game?.id ?? '';
      }
      if (gameId.isEmpty) {
        if (mounted) {
          setState(() {
            _hasMore = false;
            _canReserve = false;
          });
        }
        return;
      }
      final auth = ref.read(authControllerProvider);
      final results = await Future.wait([
        ref
            .read(lotteryRepositoryProvider)
            .search(
              gameId: gameId,
              number: widget.number,
              digits: widget.digits,
              storeId: widget.storeId,
              cursor: reset ? '' : _cursor,
              randomSeed: _stockRandomSeed(),
            ),
        if (auth.isAuthenticated)
          ref.read(lotteryRepositoryProvider).cart()
        else
          Future<LotteryCart>.value(LotteryCart.empty()),
      ]);
      final page = results[0] as LotteryStockPage;
      final cart = results[1] as LotteryCart;
      final nextItems = _itemsWithActivePricePatch(
        _normalizeBrowseStockItems(
          reset ? page.items : [..._items, ...page.items],
          enabled: _isBrowseMode,
        ),
      );
      if (!mounted) return;
      setState(() {
        _gameId = page.gameId.isNotEmpty ? page.gameId : gameId;
        _cart = cart;
        _items
          ..clear()
          ..addAll(nextItems);
        _cursor = page.nextCursor;
        _hasMore = page.hasMore;
        _canReserve = page.canReserve;
        _reservedByStockId
          ..clear()
          ..addEntries(_cartReservationEntries(cart));
      });
      widget.onCartChanged?.call(cart);
    } catch (error) {
      if (!mounted) return;
      if (await handleCustomerOperationalError(
        ref: ref,
        context: context,
        error: error,
      )) {
        return;
      }
      setState(
        () => _error = _errorMessage(error, context.l10n.lotteryLoadFailed),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
        if (reset) widget.onResetLoadingChanged?.call(false);
        _handleParentScroll();
      }
    }
  }

  bool get _isBrowseMode {
    return widget.number.trim().isEmpty &&
        widget.storeId.trim().isEmpty &&
        widget.digits.every((digit) => digit.trim().isEmpty);
  }

  Future<void> _refreshStockList() async {
    if (_loading || (_isBrowseMode && _refreshCooldownSeconds > 0)) return;
    if (widget.useRandomSeed) {
      _randomSeed = _createStockRandomSeed();
    }
    await _load(reset: true);
    if (mounted && _isBrowseMode) {
      _startRefreshCooldown();
    }
  }

  String _stockRandomSeed() {
    if (!widget.useRandomSeed) return '';
    if (_randomSeed.isEmpty) {
      _randomSeed = _createStockRandomSeed();
    }
    return _randomSeed;
  }

  void _applyPricePatch(LotteryStockPricePatch patch) {
    if (_items.isEmpty || !patch.matchesGame(_gameId)) return;
    final patchedItems = _itemsWithPricePatch(_items, patch);
    if (!_stockItemsChanged(_items, patchedItems)) return;
    setState(() {
      _activePricePatch = patch;
      _items
        ..clear()
        ..addAll(patchedItems);
    });
    _schedulePriceTrendClear(patch.flashKey);
  }

  void _applyAvailabilityPatch(LotteryStockAvailabilityPatch patch) {
    if (_items.isEmpty || !patch.matchesGame(_gameId)) return;
    final patchedItems = [
      for (final item in _items)
        patch.matchesNumber(item.number)
            ? item.copyWith(
                remainingCount: patch.remainingCount,
                status: patch.status,
              )
            : item,
    ];
    if (!_stockItemsChanged(_items, patchedItems)) return;
    setState(() {
      _items
        ..clear()
        ..addAll(patchedItems);
    });
  }

  List<LotteryStockItem> _itemsWithActivePricePatch(
    List<LotteryStockItem> items,
  ) {
    final patch = _activePricePatch;
    if (patch == null || !patch.matchesGame(_gameId)) return items;
    return _itemsWithPricePatch(items, patch);
  }

  List<LotteryStockItem> _itemsWithPricePatch(
    List<LotteryStockItem> items,
    LotteryStockPricePatch patch,
  ) {
    return [for (final item in items) _itemWithPricePatch(item, patch)];
  }

  LotteryStockItem _itemWithPricePatch(
    LotteryStockItem item,
    LotteryStockPricePatch patch,
  ) {
    final existing = _matchingStockItem(item);
    final existingTrend = existing?.priceFlashKey == patch.flashKey
        ? existing?.priceTrend ?? ''
        : '';
    if (existingTrend.isNotEmpty) {
      return item.copyWith(
        price: patch.price,
        priceTrend: existingTrend,
        priceFlashKey: patch.flashKey,
      );
    }
    if (!item.price.isFinite || item.price <= 0 || item.price == patch.price) {
      return item.price == patch.price
          ? item
          : item.copyWith(price: patch.price);
    }
    return item.copyWith(
      price: patch.price,
      priceTrend: patch.price > item.price
          ? lotteryStockPriceTrendUp
          : lotteryStockPriceTrendDown,
      priceFlashKey: patch.flashKey,
    );
  }

  LotteryStockItem? _matchingStockItem(LotteryStockItem item) {
    for (final existing in _items) {
      if (existing.localStockItemId == item.localStockItemId ||
          existing.token == item.token ||
          existing.stockRef == item.stockRef) {
        return existing;
      }
    }
    return null;
  }

  void _schedulePriceTrendClear(int flashKey) {
    _priceTrendClearTimer?.cancel();
    _priceTrendClearTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        if (_activePricePatch?.flashKey == flashKey) {
          _activePricePatch = null;
        }
        for (var index = 0; index < _items.length; index++) {
          final item = _items[index];
          if (item.priceFlashKey == flashKey) {
            _items[index] = item.copyWith(priceTrend: '', priceFlashKey: 0);
          }
        }
      });
    });
  }

  void _startRefreshCooldown() {
    _refreshCooldownTimer?.cancel();
    setState(() => _refreshCooldownSeconds = 10);
    _refreshCooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_refreshCooldownSeconds <= 1) {
        timer.cancel();
        setState(() => _refreshCooldownSeconds = 0);
        return;
      }
      setState(() => _refreshCooldownSeconds -= 1);
    });
  }

  void _stopRefreshCooldown() {
    _refreshCooldownTimer?.cancel();
    _refreshCooldownTimer = null;
    if (_refreshCooldownSeconds == 0) return;
    setState(() => _refreshCooldownSeconds = 0);
  }

  Future<void> _toggleReservation(LotteryStockItem item) async {
    if (_busyStockId.isNotEmpty) return;
    final stockKey = _stockUiKey(item);
    final reservedId = _reservedIdForStock(item);
    final auth = ref.read(authControllerProvider);
    final hasAccessToken = ref.read(authTokenStoreProvider).hasAccessToken;
    if ((reservedId == null || reservedId.isEmpty) &&
        !auth.isAuthenticated &&
        !hasAccessToken) {
      context.go(
        customerLoginRouteForRedirect(GoRouterState.of(context).uri.toString()),
      );
      return;
    }

    setState(() {
      _busyStockId = stockKey;
      _stockNoticeMessage = '';
    });
    try {
      if (reservedId != null && reservedId.isNotEmpty) {
        final cart = await ref
            .read(lotteryRepositoryProvider)
            .releaseReservation(reservedId);
        _syncReservedCart(cart);
      } else {
        final reservation = await ref
            .read(lotteryRepositoryProvider)
            .reserve(gameId: _gameId, item: item);
        if (!mounted) return;
        _syncReservedCart(_cartWithReservation(_cart, reservation));
      }
      if (!mounted) return;
      setState(() {
        final remainsReserved = _reservedIdForStock(item) != null;
        _stockNoticeSuccess = !remainsReserved;
        _stockNoticeMessage = remainsReserved
            ? ''
            : context.l10n.lotteryRemovedFromCart;
      });
    } catch (error) {
      if (!mounted) return;
      if (_isReservationUnavailableError(error)) {
        setState(() => _busyStockId = '');
        if (await _refreshCartQuietly()) return;
        if (!mounted) return;
        await _showReservationUnavailableDialog(
          item,
          removeItem: reservedId == null || reservedId.isEmpty,
        );
        return;
      }
      if (await handleCustomerOperationalError(
        ref: ref,
        context: context,
        error: error,
      )) {
        return;
      }
      setState(() {
        _stockNoticeSuccess = false;
        _stockNoticeMessage = _errorMessage(
          error,
          context.l10n.lotteryActionFailed,
        );
      });
    } finally {
      if (mounted) setState(() => _busyStockId = '');
    }
  }

  String? _reservedIdForStock(LotteryStockItem item) {
    for (final key in _stockReservationKeys(item)) {
      final reservationId = _reservedByStockId[key];
      if (reservationId != null && reservationId.isNotEmpty) {
        return reservationId;
      }
    }
    return null;
  }

  Future<bool> _refreshCartQuietly() async {
    if (_refreshingCart) return false;
    _refreshingCart = true;
    try {
      final cart = await ref.read(lotteryRepositoryProvider).cart();
      _syncReservedCart(cart);
      return false;
    } catch (error) {
      if (mounted &&
          await handleCustomerOperationalError(
            ref: ref,
            context: context,
            error: error,
          )) {
        return true;
      }
      // Nuxt refreshes cart after booking races, but keeps the customer in flow
      // even when that refresh cannot complete.
      return false;
    } finally {
      _refreshingCart = false;
    }
  }

  Future<void> _showReservationUnavailableDialog(
    LotteryStockItem item, {
    required bool removeItem,
  }) async {
    await showLotteryReservationUnavailableNotice(context);
    if (!mounted || !removeItem) return;
    final itemKeys = _stockReservationKeys(item);
    setState(() {
      _items.removeWhere(
        (candidate) => _stockReservationKeys(candidate).any(itemKeys.contains),
      );
    });
  }

  void _syncReservedCart(LotteryCart cart) {
    if (!mounted) return;
    setState(() {
      _cart = cart;
      _reservedByStockId
        ..clear()
        ..addEntries(_cartReservationEntries(cart));
    });
    widget.onCartChanged?.call(cart);
  }

  void _attachScrollListener() {
    if (!mounted) return;
    final nextPosition = Scrollable.maybeOf(context)?.position;
    if (nextPosition == null || identical(nextPosition, _scrollPosition)) {
      return;
    }
    _scrollPosition?.removeListener(_handleParentScroll);
    _scrollPosition = nextPosition;
    _scrollPosition?.addListener(_handleParentScroll);
    _handleParentScroll();
  }

  void _handleParentScroll() {
    final position = _scrollPosition;
    if (position == null ||
        !position.hasPixels ||
        !position.hasContentDimensions ||
        _loading ||
        _loadingMore ||
        _busyStockId.isNotEmpty ||
        !_hasMore) {
      return;
    }
    final distanceFromBottom = position.maxScrollExtent - position.pixels;
    if (distanceFromBottom <= 240) {
      _load(reset: false);
    }
  }
}

String _stockUiKey(LotteryStockItem item) {
  for (final value in [
    item.localStockItemId,
    item.reserveStockItemId,
    item.stockRef,
    item.id,
    item.token,
  ]) {
    final text = value.trim();
    if (text.isNotEmpty) return text;
  }
  return item.number;
}

Set<String> _stockReservationKeys(LotteryStockItem item) {
  return {
    item.localStockItemId,
    item.reserveStockItemId,
    item.stockRef,
    item.id,
    item.token,
  }.map((value) => value.trim()).where((value) => value.isNotEmpty).toSet();
}

List<MapEntry<String, String>> _cartReservationEntries(LotteryCart cart) {
  final entries = <MapEntry<String, String>>[];
  for (final item in cart.items) {
    final reservationId = item.reservationId.trim();
    if (reservationId.isEmpty) continue;
    entries.addAll(
      _stockReservationKeys(item).map((key) => MapEntry(key, reservationId)),
    );
  }
  return entries;
}

bool _stockItemsChanged(
  List<LotteryStockItem> current,
  List<LotteryStockItem> next,
) {
  if (current.length != next.length) return true;
  for (var index = 0; index < current.length; index++) {
    final currentItem = current[index];
    final nextItem = next[index];
    if (currentItem.price != nextItem.price ||
        currentItem.remainingCount != nextItem.remainingCount ||
        currentItem.status != nextItem.status ||
        currentItem.priceTrend != nextItem.priceTrend ||
        currentItem.priceFlashKey != nextItem.priceFlashKey) {
      return true;
    }
  }
  return false;
}

bool _cartSelectionReviewEnabled(LotteryCart cart) {
  final deadline = earliestActiveReservation(cart.reservations);
  return cart.reservationIds.isNotEmpty &&
      (deadline == null || !reservationDeadlineExpired(deadline));
}

bool _sameCartSummary(LotteryCart current, LotteryCart next) {
  if (current.itemCount != next.itemCount || current.total != next.total) {
    return false;
  }
  final currentIds = current.reservationIds;
  final nextIds = next.reservationIds;
  if (currentIds.length != nextIds.length) return false;
  for (var index = 0; index < currentIds.length; index++) {
    if (currentIds[index] != nextIds[index]) return false;
  }
  return true;
}

int _stockRandomSeedCounter = 0;

String _createStockRandomSeed() {
  _stockRandomSeedCounter += 1;
  return '${DateTime.now().microsecondsSinceEpoch}-$_stockRandomSeedCounter';
}

LotteryCart _cartWithReservation(
  LotteryCart cart,
  LotteryReservation reservation,
) {
  final reservations = [
    for (final existing in cart.reservations)
      if (existing.id != reservation.id) existing,
    reservation,
  ];
  return _cartFromReservations(
    reservations,
    serverTime: cart.serverTime,
    warnings: cart.warnings,
  );
}

List<LotteryStockItem> _normalizeBrowseStockItems(
  List<LotteryStockItem> items, {
  required bool enabled,
}) {
  if (!enabled) return List<LotteryStockItem>.of(items);
  return _uniqueStockItemsByNumber(_arrangeNonAdjacentStockNumbers(items));
}

List<LotteryStockItem> _uniqueStockItemsByNumber(List<LotteryStockItem> items) {
  final seenNumbers = <String>{};
  return [
    for (final item in items)
      if (seenNumbers.add(_stockNumberKey(item))) item,
  ];
}

List<LotteryStockItem> _arrangeNonAdjacentStockNumbers(
  List<LotteryStockItem> items,
) {
  final pending = List<LotteryStockItem>.of(items);
  final arranged = <LotteryStockItem>[];
  while (pending.isNotEmpty) {
    final previousNumber = arranged.isEmpty
        ? ''
        : _stockNumberKey(arranged.last);
    final nextIndex = pending.indexWhere(
      (item) => _stockNumberKey(item) != previousNumber,
    );
    final index = nextIndex >= 0 ? nextIndex : 0;
    arranged.add(pending.removeAt(index));
  }
  return arranged;
}

String _stockNumberKey(LotteryStockItem item) {
  return item.number.replaceAll(RegExp(r'\D'), '').padLeft(6, '0');
}

LotteryCart _cartFromReservations(
  List<LotteryReservation> reservations, {
  required Object? serverTime,
  required List<String> warnings,
}) {
  return LotteryCart(
    reservations: List<LotteryReservation>.unmodifiable(reservations),
    total: reservations.fold<double>(
      0,
      (sum, reservation) => sum + _reservationDisplayTotal(reservation),
    ),
    itemCount: reservations.fold<int>(
      0,
      (sum, reservation) => sum + reservation.items.length,
    ),
    serverTime: serverTime,
    warnings: List<String>.unmodifiable(warnings),
  );
}

double _reservationDisplayTotal(LotteryReservation reservation) {
  if (reservation.total > 0) return reservation.total;
  return reservation.items.fold<double>(0, (sum, item) => sum + item.price);
}

class _CartSelectionDock extends StatelessWidget {
  const _CartSelectionDock({required this.cart, required this.onReview});

  final LotteryCart cart;
  final VoidCallback? onReview;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final deadline = earliestActiveReservation(cart.reservations);
    final enabled = onReview != null;
    return DecoratedBox(
      key: const ValueKey('cart-selection-dock'),
      decoration: _lotterySurfaceDecoration(
        context,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        borderColor: Colors.transparent,
        shadowAlpha: 0.10,
        shadowOffset: const Offset(0, -8),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          25,
          27,
          25,
          27 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (deadline != null) ...[
              Center(child: _ReservationCountdownText(reservation: deadline)),
              const SizedBox(height: 18),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.cartSelectionCountLabel,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.appMuted,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 5),
                      CustomerPaymentSelectionCountText(
                        count: cart.itemCount,
                        countText: l10n.ticketsCount(cart.itemCount),
                        numberFontSize: 24,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                Flexible(
                  flex: 0,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 144,
                      maxWidth: 220,
                      minHeight: 58,
                    ),
                    child: CustomerGradientButton.text(
                      onPressed: enabled ? onReview : null,
                      height: 58,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      label: enabled
                          ? l10n.cartSelectionReview
                          : l10n.cartExpired,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LotterySearchActions extends StatelessWidget {
  const _LotterySearchActions({
    required this.onSearch,
    required this.searching,
  });

  final VoidCallback onSearch;
  final bool searching;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SizedBox(
      width: double.infinity,
      child: CustomerGradientButton.text(
        onPressed: searching ? null : onSearch,
        height: 54,
        fontSize: 17,
        label: searching ? l10n.lotterySearchLoading : l10n.lotterySearchButton,
      ),
    );
  }
}

class _LotterySearchInitialHint extends StatelessWidget {
  const _LotterySearchInitialHint({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final mutedText =
        Color.lerp(colorScheme.onSurfaceVariant, colorScheme.surface, 0.22) ??
        colorScheme.onSurfaceVariant;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: mutedText,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            height: 1.42,
          ),
        ),
      ),
    );
  }
}

class LotteryProductBrandRow extends ConsumerWidget {
  const LotteryProductBrandRow({super.key, this.productMarker = ''});

  final String productMarker;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fallbackMarker = productMarker.trim();
    final marker = ref
        .watch(mobileBootstrapProvider)
        .maybeWhen(
          data: (bootstrap) {
            final configured = bootstrap.lotteryProductLabel.trim();
            return configured.isEmpty ? fallbackMarker : configured;
          },
          orElse: () => fallbackMarker,
        );
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      key: const ValueKey('lottery-stock-brand-row'),
      mainAxisSize: MainAxisSize.max,
      children: [
        if (marker.isNotEmpty) ...[
          _LotteryProductMark(marker: marker),
          const SizedBox(width: 10),
        ],
        Flexible(
          child: Text(
            context.l10n.ticketLabelGovernmentLottery,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }
}

class _LotteryProductMark extends StatelessWidget {
  const _LotteryProductMark({required this.marker});

  final String marker;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          marker,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: colorScheme.primary,
            fontSize: 19,
            fontWeight: FontWeight.w800,
            height: 1,
            letterSpacing: 0,
          ),
        ),
        Transform.translate(
          offset: const Offset(-5, 1),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.tertiary,
              shape: BoxShape.circle,
            ),
            child: const SizedBox.square(dimension: 8),
          ),
        ),
      ],
    );
  }
}

class _LotteryStockCard extends StatelessWidget {
  const _LotteryStockCard({
    required this.item,
    required this.reserved,
    required this.busy,
    required this.reserveDisabled,
    required this.showSellerName,
    required this.showTicketImage,
    required this.highlightDigits,
    required this.morePath,
    required this.onReserve,
  });

  final LotteryStockItem item;
  final bool reserved;
  final bool busy;
  final bool reserveDisabled;
  final bool showSellerName;
  final bool showTicketImage;
  final List<String> highlightDigits;
  final String morePath;
  final VoidCallback onReserve;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final unavailable = !reserved && !item.isAvailable;
    final sellerName = item.sellerName.trim();
    return LotteryUnavailableRowVisualState(
      unavailable: unavailable,
      child: DecoratedBox(
        key: ValueKey('lottery-stock-row-${item.localStockItemId}'),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border(
            bottom: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.75),
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: LayoutBuilder(
            builder: (context, _) {
              final moreButton = morePath.isEmpty
                  ? null
                  : TextButton(
                      onPressed: () => context.push(morePath),
                      style: _lotteryTextLinkButtonStyle(context),
                      child: Text(l10n.lotteryViewMore),
                    );
              final brandHeader = Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(child: LotteryProductBrandRow()),
                  if (moreButton != null) ...[
                    const SizedBox(width: 12),
                    moreButton,
                  ],
                ],
              );
              final actionLabel = busy
                  ? reserved
                        ? l10n.lotteryRemoving
                        : l10n.lotterySelecting
                  : reserved
                  ? l10n.lotteryRemove
                  : reserveDisabled
                  ? l10n.lotterySaleClosedAction
                  : item.isAvailable
                  ? l10n.lotterySelect
                  : l10n.lotterySoldOut;
              final canToggle =
                  reserved || (item.isAvailable && !reserveDisabled);
              final Widget actionButton = reserved
                  ? DecoratedBox(
                      decoration: _lotterySmallGradientPillDecoration(
                        context,
                        enabled: !busy && canToggle,
                      ),
                      child: SizedBox(
                        height: 40,
                        child: FilledButton(
                          onPressed: busy || !canToggle ? null : onReserve,
                          style: _lotterySmallGradientPillButtonStyle(context),
                          child: Text(actionLabel),
                        ),
                      ),
                    )
                  : SizedBox(
                      height: 40,
                      child: OutlinedButton(
                        onPressed: busy || !canToggle ? null : onReserve,
                        style:
                            _lotteryOutlinePillButtonStyle(
                              context,
                              enabled: canToggle,
                            ).copyWith(
                              minimumSize: const WidgetStatePropertyAll(
                                Size(84, 40),
                              ),
                              textStyle: WidgetStatePropertyAll(
                                Theme.of(
                                  context,
                                ).textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  height: 1.1,
                                ),
                              ),
                            ),
                        child: Text(actionLabel),
                      ),
                    );
              final ticketDisplay = Column(
                key: const ValueKey('lottery-stock-ticket-display-row'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showTicketImage) ...[
                    _LotteryStockImageFrame(item: item),
                    const SizedBox(height: 10),
                  ],
                  _LotteryStockNumberMetaRow(
                    number: item.number,
                    item: item,
                    highlightDigits: highlightDigits,
                  ),
                ],
              );
              final mainRow = Row(
                key: const ValueKey('lottery-stock-main-row'),
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: ticketDisplay),
                  const SizedBox(width: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 84),
                    child: actionButton,
                  ),
                ],
              );
              final bottomRow = Row(
                key: const ValueKey('lottery-stock-meta-price-row'),
                children: [
                  if (showSellerName && sellerName.isNotEmpty)
                    Expanded(
                      child: Text(
                        sellerName,
                        key: const ValueKey('lottery-stock-seller-row'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.appMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )
                  else
                    const Spacer(),
                  if (showSellerName && sellerName.isNotEmpty)
                    const SizedBox(width: 12)
                  else
                    const SizedBox(width: 0),
                  _LotteryStockPriceText(item: item),
                ],
              );

              final content = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  brandHeader,
                  const SizedBox(height: 10),
                  mainRow,
                  const SizedBox(height: 8),
                  bottomRow,
                ],
              );
              return content;
            },
          ),
        ),
      ),
    );
  }
}

class LotteryUnavailableRowVisualState extends StatelessWidget {
  const LotteryUnavailableRowVisualState({
    required this.unavailable,
    required this.child,
    super.key,
  });

  final bool unavailable;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!unavailable) return child;
    return Opacity(
      opacity: 0.58,
      child: ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]),
        child: child,
      ),
    );
  }
}

class _LotteryStockImageFrame extends StatelessWidget {
  const _LotteryStockImageFrame({required this.item});

  final LotteryStockItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final normalizedStatus = item.imageStatus.trim().toLowerCase();
    final imageError = item.imageError.trim();
    final source = item.thumbUrl.trim().isNotEmpty
        ? item.thumbUrl.trim()
        : item.imageUrl.trim();
    final canLoadImage =
        source.isNotEmpty &&
        !{'pending_assets', 'failed', 'missing'}.contains(normalizedStatus);
    final fallbackText = normalizedStatus == 'pending_assets'
        ? l10n.ticketImagePreparing
        : normalizedStatus == 'failed' && imageError.isNotEmpty
        ? imageError
        : l10n.ticketImageUnavailable;
    final fallbackIcon = normalizedStatus == 'pending_assets'
        ? Icons.hourglass_top_outlined
        : normalizedStatus == 'failed'
        ? Icons.image_outlined
        : Icons.confirmation_number_outlined;

    return DecoratedBox(
      key: const ValueKey('lottery-stock-ticket-image-frame'),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.65),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: AspectRatio(
            aspectRatio: 5 / 2.8,
            child: canLoadImage
                ? FlexibleImage(
                    key: const ValueKey('lottery-stock-ticket-image'),
                    source: source,
                    fit: BoxFit.cover,
                    errorIcon: Icons.confirmation_number_outlined,
                  )
                : Padding(
                    key: const ValueKey('lottery-stock-ticket-image-fallback'),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          fallbackIcon,
                          color: colorScheme.primary,
                          size: 18,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          fallbackText,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                                height: 1.25,
                              ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _LotteryStockPriceText extends StatelessWidget {
  const _LotteryStockPriceText({required this.item});

  final LotteryStockItem item;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final priceTrend = item.priceTrend;
    final trendColor = priceTrend == lotteryStockPriceTrendDown
        ? colorScheme.error
        : priceTrend == lotteryStockPriceTrendUp
        ? colorScheme.tertiary
        : colorScheme.onSurface;
    final trendIcon = priceTrend == lotteryStockPriceTrendDown
        ? Icons.arrow_downward
        : priceTrend == lotteryStockPriceTrendUp
        ? Icons.arrow_upward
        : null;
    return Row(
      key: const ValueKey('lottery-stock-price-row'),
      mainAxisSize: MainAxisSize.min,
      children: [
        if (trendIcon != null) ...[
          Icon(
            trendIcon,
            key: ValueKey('lottery-stock-price-trend-$priceTrend'),
            size: 16,
            color: trendColor,
          ),
          const SizedBox(width: 2),
        ],
        Text(
          formatBaht(item.price),
          key: const ValueKey('lottery-stock-price'),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: trendColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _LotteryFilterPills extends StatelessWidget {
  const _LotteryFilterPills();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _LotteryFilterPill(
            label: l10n.lotteryFilterAll,
            icon: Icons.playlist_add_check,
            selected: true,
          ),
          const SizedBox(width: 12),
          _LotteryFilterPill(
            label: l10n.lotteryFilterDiscount,
            icon: Icons.keyboard_double_arrow_down,
            iconColor: colorScheme.error,
          ),
          const SizedBox(width: 12),
          _LotteryFilterPill(
            label: l10n.lotteryFilterAccessibleStore,
            icon: Icons.accessible_forward,
            iconColor: colorScheme.error,
          ),
          const SizedBox(width: 12),
          _LotteryFilterPill(
            label: l10n.lotteryFilterAgencyStore,
            icon: Icons.groups_2_outlined,
            iconColor: colorScheme.tertiary,
          ),
        ],
      ),
    );
  }
}

class _LotteryFilterPill extends StatelessWidget {
  const _LotteryFilterPill({
    required this.label,
    required this.icon,
    this.iconColor,
    this.selected = false,
  });

  final String label;
  final IconData icon;
  final Color? iconColor;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    const foreground = AppTheme.appFilterPillText;
    final primary = Theme.of(context).colorScheme.primary;
    final selectedForeground = selected
        ? AppTheme.primaryOutlineText(primary)
        : foreground;
    final borderColor = selected
        ? AppTheme.primaryFilterBorder(primary)
        : Colors.transparent;
    return Semantics(
      button: true,
      selected: selected,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 39),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected ? AppTheme.appSheet : AppTheme.appFilterPillFill,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: borderColor),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: iconColor ?? selectedForeground),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: selectedForeground,
                    fontWeight: FontWeight.w500,
                    height: 1.05,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LotterySectionHeading extends StatelessWidget {
  const _LotterySectionHeading({required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final action = this.action;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: _lotterySectionTitleTextStyle(context),
          ),
        ),
        if (action != null) ...[
          const SizedBox(width: 12),
          Flexible(flex: 0, child: action),
        ],
      ],
    );
  }
}

class _LotteryDockedPage extends StatelessWidget {
  const _LotteryDockedPage({required this.children, this.dock});

  final List<Widget> children;
  final Widget? dock;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _LotteryContentSheet(
                bottom: dock == null ? 128 : 220,
                children: children,
              ),
            ],
          ),
        ),
        if (dock != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _FixedPaymentDockContainer(child: dock!),
          ),
      ],
    );
  }
}

class _CartReviewDockedPage extends StatelessWidget {
  const _CartReviewDockedPage({
    required this.children,
    this.dock,
    this.dockLeading,
    this.physics,
  });

  final List<Widget> children;
  final Widget? dock;
  final Widget? dockLeading;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: ListView(
            padding: EdgeInsets.zero,
            physics: physics,
            children: [
              _LotteryContentSheet(
                bottom: dock == null ? 128 : 280,
                children: children,
              ),
            ],
          ),
        ),
        if (dock != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (dockLeading != null) ...[
                  dockLeading!,
                  const SizedBox(height: 12),
                ],
                _FixedPaymentDockContainer(child: dock!),
              ],
            ),
          ),
      ],
    );
  }
}

class _CheckoutDockedPage extends StatelessWidget {
  const _CheckoutDockedPage({required this.children, this.dock, this.physics});

  final List<Widget> children;
  final Widget? dock;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: ListView(
            padding: EdgeInsets.zero,
            physics: physics,
            children: [
              _LotteryContentSheet(
                bottom: dock == null ? 128 : 190,
                top: 0,
                mobileHorizontal: 0,
                wideHorizontal: 0,
                children: children,
              ),
            ],
          ),
        ),
        if (dock != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _FixedPaymentDockContainer(child: dock!),
          ),
      ],
    );
  }
}

class _LotteryContentSheet extends StatelessWidget {
  const _LotteryContentSheet({
    required this.children,
    required this.bottom,
    this.top = 18,
    this.mobileHorizontal = 18,
    this.wideHorizontal = 0,
  });

  final List<Widget> children;
  final double bottom;
  final double top;
  final double mobileHorizontal;
  final double wideHorizontal;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: CustomerPageBody(
        top: top,
        bottom: bottom,
        mobileHorizontal: mobileHorizontal,
        wideHorizontal: wideHorizontal,
        minViewportHeight: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

class _FixedPaymentDockContainer extends StatelessWidget {
  const _FixedPaymentDockContainer({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth
            .clamp(0.0, customerContentMaxWidthFor(context))
            .toDouble();
        return Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(width: width, child: child),
        );
      },
    );
  }
}

class _CheckoutSheetInset extends StatelessWidget {
  const _CheckoutSheetInset({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 23, 18, 0),
      child: child,
    );
  }
}

class _CheckoutHeroSummaryCard extends StatelessWidget {
  const _CheckoutHeroSummaryCard({
    required this.ticketCount,
    required this.total,
    required this.loading,
    required this.error,
  });

  final int ticketCount;
  final double total;
  final bool loading;
  final String error;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final statusMessage = loading ? l10n.checkoutPreparing : error.trim();
    final statusColor = error.trim().isNotEmpty
        ? colorScheme.error
        : colorScheme.primary;
    return DecoratedBox(
      key: const ValueKey('checkout-summary-card'),
      decoration: _lotterySurfaceDecoration(
        context,
        borderColor: Colors.transparent,
        shadowAlpha: 0.09,
        blurRadius: 22,
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _CheckoutProductSummary(),
            const SizedBox(height: 12),
            _AmountRow(
              label: l10n.checkoutTicketCount,
              value: l10n.ticketsCount(ticketCount),
            ),
            _CheckoutSummaryTotalRow(
              label: l10n.checkoutSummaryTotal,
              total: total,
            ),
            if (statusMessage.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                statusMessage,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CheckoutProductSummary extends StatelessWidget {
  const _CheckoutProductSummary();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.75),
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.78),
                ),
              ),
              child: const SizedBox.square(
                dimension: 48,
                child: Center(child: _CheckoutProductMark()),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                context.l10n.ticketLabelGovernmentLottery,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckoutProductMark extends ConsumerWidget {
  const _CheckoutProductMark();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final bootstrap = ref.watch(mobileBootstrapProvider);
    return bootstrap.maybeWhen(
      data: (data) {
        final rawLogoUrl = data.brand.logoUrl.trim();
        if (rawLogoUrl.isEmpty) {
          return Icon(
            Icons.confirmation_number_outlined,
            color: colorScheme.primary,
            size: 26,
          );
        }
        return FlexibleImage(
          key: const ValueKey('checkout-product-brand-logo'),
          source: _resolveCheckoutBrandLogoUrl(ref, rawLogoUrl),
          width: 34,
          height: 34,
          fit: BoxFit.contain,
          errorIcon: Icons.confirmation_number_outlined,
        );
      },
      orElse: () => Icon(
        Icons.confirmation_number_outlined,
        color: colorScheme.primary,
        size: 26,
      ),
    );
  }
}

String _resolveCheckoutBrandLogoUrl(WidgetRef ref, String value) {
  final trimmed = value.trim();
  final uri = Uri.tryParse(trimmed);
  if (uri != null &&
      (uri.hasScheme ||
          trimmed.startsWith('data:') ||
          trimmed.startsWith('//'))) {
    return trimmed;
  }
  return ref.watch(assetUrlResolverProvider)(trimmed);
}

class _CheckoutPaymentMethodCard extends StatelessWidget {
  const _CheckoutPaymentMethodCard({
    required this.walletName,
    required this.balance,
    required this.walletLoading,
    required this.enoughBalance,
    required this.walletError,
    required this.methods,
    required this.methodLabels,
    required this.selectedMethod,
    required this.onMethodChanged,
    required this.onTopup,
  });

  final String walletName;
  final double balance;
  final bool walletLoading;
  final bool enoughBalance;
  final String walletError;
  final List<String> methods;
  final Map<String, String> methodLabels;
  final String selectedMethod;
  final ValueChanged<String> onMethodChanged;
  final VoidCallback onTopup;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final normalizedMethods = methods.isEmpty
        ? const [checkoutPaymentMethodWallet]
        : methods;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          key: const ValueKey('checkout-payment-method-section-header'),
          padding: const EdgeInsets.fromLTRB(18, 23, 18, 20),
          child: Text(
            l10n.checkoutPaymentMethodTitle,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: colorScheme.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
          child: Column(
            children: [
              for (final method in normalizedMethods) ...[
                _CheckoutPaymentMethodOptionCard(
                  method: method,
                  runtimeLabel: methodLabels[method] ?? '',
                  selected: method == selectedMethod,
                  walletName: walletName,
                  balance: balance,
                  walletLoading: walletLoading,
                  enoughBalance: enoughBalance,
                  walletError: walletError,
                  onSelected: () => onMethodChanged(method),
                  onTopup: onTopup,
                ),
                if (method != normalizedMethods.last)
                  const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _CheckoutConfirmDock extends StatelessWidget {
  const _CheckoutConfirmDock({
    required this.deadline,
    required this.submitting,
    required this.enabled,
    required this.label,
    required this.onConfirm,
  });

  final LotteryReservation? deadline;
  final bool submitting;
  final bool enabled;
  final String label;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const ValueKey('checkout-payment-dock'),
      decoration: _lotterySurfaceDecoration(
        context,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        borderColor: Colors.transparent,
        shadowAlpha: 0.12,
        blurRadius: 26,
        shadowOffset: const Offset(0, -8),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          18,
          22,
          18,
          22 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (deadline != null) ...[
              Center(
                child: _ReservationCountdownText(
                  reservation: deadline!,
                  countdownLabelBuilder: (l10n, time) =>
                      l10n.checkoutPaymentTimer(time),
                  paymentDockStyle: true,
                ),
              ),
              const SizedBox(height: 16),
            ],
            CustomerGradientButton.text(
              onPressed: submitting || !enabled ? null : onConfirm,
              height: 56,
              fontSize: 18,
              label: label,
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckoutPaymentMethodOptionCard extends StatelessWidget {
  const _CheckoutPaymentMethodOptionCard({
    required this.method,
    required this.runtimeLabel,
    required this.selected,
    required this.walletName,
    required this.balance,
    required this.walletLoading,
    required this.enoughBalance,
    required this.walletError,
    required this.onSelected,
    required this.onTopup,
  });

  final String method;
  final String runtimeLabel;
  final bool selected;
  final String walletName;
  final double balance;
  final bool walletLoading;
  final bool enoughBalance;
  final String walletError;
  final VoidCallback onSelected;
  final VoidCallback onTopup;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final walletMethod = method == checkoutPaymentMethodWallet;
    final title = walletMethod
        ? walletName
        : runtimeLabel.trim().isNotEmpty
        ? runtimeLabel.trim()
        : l10n.checkoutExternalPaymentName;
    final subtitle = walletMethod && walletLoading
        ? l10n.checkoutWalletLoading
        : walletMethod
        ? formatBaht(balance)
        : l10n.checkoutExternalPaymentSubtitle;
    final note = walletMethod
        ? l10n.checkoutWalletPaymentNote
        : l10n.checkoutExternalPaymentNote;
    final borderColor = selected
        ? AppTheme.checkoutWalletBorder(colorScheme.primary)
        : colorScheme.outlineVariant.withValues(alpha: 0.7);
    return DecoratedBox(
      key: ValueKey('checkout-payment-method-option-$method'),
      decoration: _lotterySurfaceDecoration(
        context,
        borderColor: Colors.transparent,
        borderWidth: 0,
        shadowAlpha: selected ? 0.09 : 0,
        blurRadius: selected ? 22 : 0,
      ),
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: selected ? 1.5 : 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: MouseRegion(
            cursor: selected
                ? SystemMouseCursors.basic
                : SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: selected ? null : onSelected,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final compact = constraints.maxWidth < 420;
                        final selector = Icon(
                          selected ? Icons.check_circle : Icons.circle_outlined,
                          key: ValueKey(
                            'checkout-payment-method-selector-$method',
                          ),
                          size: 30,
                          color: selected
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                        );
                        final topupAction = walletMethod
                            ? OutlinedButton.icon(
                                onPressed: onTopup,
                                style: _lotteryOutlinePillButtonStyle(context)
                                    .copyWith(
                                      minimumSize: const WidgetStatePropertyAll(
                                        Size(0, 36),
                                      ),
                                      padding: const WidgetStatePropertyAll(
                                        EdgeInsets.symmetric(horizontal: 14),
                                      ),
                                      textStyle: WidgetStatePropertyAll(
                                        theme.textTheme.labelLarge?.copyWith(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          height: 1,
                                        ),
                                      ),
                                    ),
                                icon: const Icon(Icons.add, size: 18),
                                label: Text(l10n.homeActionTopup),
                              )
                            : null;
                        final copy = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontSize: 18,
                                color: walletMethod
                                    ? colorScheme.onSurface
                                    : colorScheme.onSurfaceVariant,
                                fontWeight: walletMethod
                                    ? FontWeight.w700
                                    : FontWeight.w700,
                                height: 1.2,
                              ),
                            ),
                            if (walletMethod &&
                                !walletLoading &&
                                walletError.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                walletError,
                                style: TextStyle(
                                  color: colorScheme.error,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ] else if (walletMethod &&
                                !walletLoading &&
                                !enoughBalance) ...[
                              const SizedBox(height: 4),
                              Text(
                                l10n.checkoutInsufficientTitle,
                                style: TextStyle(
                                  color: colorScheme.error,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                            if (topupAction != null) ...[
                              const SizedBox(height: 8),
                              topupAction,
                            ],
                          ],
                        );
                        final markText = walletMethod
                            ? _checkoutWalletMethodMark(walletName)
                            : '';
                        final markSelected = selected || walletMethod;
                        final methodMark = DecoratedBox(
                          decoration: BoxDecoration(
                            color: markSelected
                                ? AppTheme.checkoutWalletMark(
                                    colorScheme.primary,
                                    colorScheme.secondary,
                                  )
                                : colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: SizedBox.square(
                            dimension: 55,
                            child: walletMethod && markText.isNotEmpty
                                ? Center(
                                    child: Text(
                                      markText,
                                      key: const ValueKey(
                                        'checkout-wallet-method-mark',
                                      ),
                                      style: theme.textTheme.headlineSmall
                                          ?.copyWith(
                                            color: markSelected
                                                ? colorScheme.onPrimary
                                                : colorScheme.onSurfaceVariant,
                                            fontWeight: FontWeight.w900,
                                          ),
                                    ),
                                  )
                                : Center(
                                    child: Icon(
                                      Icons.payment_outlined,
                                      color: markSelected
                                          ? colorScheme.onPrimary
                                          : colorScheme.onSurfaceVariant,
                                      size: 28,
                                    ),
                                  ),
                          ),
                        );

                        if (compact) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  selector,
                                  const SizedBox(width: 14),
                                  Expanded(child: copy),
                                  const SizedBox(width: 12),
                                  methodMark,
                                ],
                              ),
                            ],
                          );
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            selector,
                            const SizedBox(width: 14),
                            Expanded(child: copy),
                            const SizedBox(width: 12),
                            methodMark,
                          ],
                        );
                      },
                    ),
                  ),
                  Container(
                    key: ValueKey('checkout-payment-method-note-$method'),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: walletMethod
                          ? AppTheme.checkoutWalletNoteFill(colorScheme.primary)
                          : colorScheme.surfaceContainerHighest.withValues(
                              alpha: selected ? 0.56 : 0.36,
                            ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Text(
                      note,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: walletMethod
                            ? AppTheme.checkoutWalletNoteText(
                                colorScheme.primary,
                              )
                            : colorScheme.onSurfaceVariant,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        height: 1.38,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _checkoutWalletMethodMark(String walletName) {
  final trimmed = walletName.trim();
  if (trimmed.isEmpty) return '';
  return String.fromCharCode(trimmed.runes.first).toUpperCase();
}

class _CartTicketGroupCard extends StatelessWidget {
  const _CartTicketGroupCard({
    required this.group,
    required this.productMarker,
    required this.busy,
    required this.onRelease,
  });

  final CartTicketGroup group;
  final String productMarker;
  final bool busy;
  final VoidCallback onRelease;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      key: ValueKey('cart-ticket-row-${group.key}'),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.75),
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CartTicketBrandActionRow(productMarker: productMarker),
            const SizedBox(height: 12),
            Row(
              children: [
                _LotteryStockNumberMetaRow(
                  number: group.number,
                  item: group.primaryItem,
                ),
                const Spacer(),
                const SizedBox(width: 12),
                _CartRemovePillButton(
                  key: const ValueKey('cart-ticket-remove-action'),
                  onPressed: busy ? null : onRelease,
                  label: l10n.lotteryRemove,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              key: const ValueKey('cart-ticket-summary-row'),
              children: [
                if (group.count > 1) ...[
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withValues(
                        alpha: 0.42,
                      ),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      child: Text(
                        '${l10n.ticketLabelCount} ${l10n.ticketsCount(group.count)}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                const Spacer(),
                Text(
                  formatBaht(group.total),
                  textAlign: TextAlign.end,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CartTicketBrandActionRow extends ConsumerWidget {
  const _CartTicketBrandActionRow({required this.productMarker});

  final String productMarker;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final fallbackMarker = productMarker.trim();
    final marker = ref
        .watch(mobileBootstrapProvider)
        .maybeWhen(
          data: (bootstrap) {
            final configured = bootstrap.lotteryProductLabel.trim();
            return configured.isEmpty ? fallbackMarker : configured;
          },
          orElse: () => fallbackMarker,
        );
    return Row(
      key: const ValueKey('cart-ticket-product-row'),
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (marker.isNotEmpty) ...[
                _LotteryProductMark(marker: marker),
                const SizedBox(width: 11),
              ],
              Flexible(
                child: Text(
                  l10n.ticketLabelGovernmentLottery,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: colorScheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.22,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CartRemovePillButton extends StatelessWidget {
  const _CartRemovePillButton({
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final primary = Theme.of(context).colorScheme.primary;
    final foreground = enabled
        ? AppTheme.appSheet
        : AppTheme.appOutlinePillDisabledText;
    final decoration = BoxDecoration(
      gradient: enabled
          ? LinearGradient(
              colors: [
                AppTheme.primaryActionStart(primary),
                AppTheme.primaryActionEnd(primary),
              ],
            )
          : null,
      color: enabled ? null : AppTheme.appOutlinePillDisabledFill,
      borderRadius: BorderRadius.circular(999),
    );
    return DecoratedBox(
      key: const ValueKey('cart-ticket-remove-pill'),
      decoration: decoration,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 40),
        child: FilledButton(
          onPressed: onPressed,
          style:
              FilledButton.styleFrom(
                backgroundColor: Colors.transparent,
                disabledBackgroundColor: Colors.transparent,
                foregroundColor: foreground,
                disabledForegroundColor: foreground,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                shape: const StadiumBorder(),
                textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ).copyWith(
                overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              ),
          child: Text(label),
        ),
      ),
    );
  }
}

class _LotteryNumber extends StatelessWidget {
  const _LotteryNumber({required this.number, this.highlightDigits = const []});

  final String number;
  final List<String> highlightDigits;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final digits = number.split('');
    final normalizedHighlights = _normalizedLotteryHighlightDigits(
      highlightDigits,
      expectedLength: digits.length,
    );
    final hasHighlights = normalizedHighlights.any((digit) => digit.isNotEmpty);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.appLotteryNumberFill,
        borderRadius: BorderRadius.circular(7),
      ),
      child: SizedBox(
        width: 154,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(
            children: [
              for (var index = 0; index < digits.length; index++)
                Expanded(
                  child: Text(
                    digits[index],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color:
                          hasHighlights &&
                              normalizedHighlights[index] != digits[index]
                          ? colorScheme.onSurfaceVariant.withValues(alpha: 0.78)
                          : colorScheme.onSurface,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      height: 1,
                      letterSpacing: 0,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LotteryStockNumberMetaRow extends StatelessWidget {
  const _LotteryStockNumberMetaRow({
    required this.number,
    this.item,
    this.highlightDigits = const [],
  });

  final String number;
  final LotteryStockItem? item;
  final List<String> highlightDigits;

  @override
  Widget build(BuildContext context) {
    return _LotteryNumber(
      number: number,
      highlightDigits: _effectiveLotteryHighlightDigits(item, highlightDigits),
    );
  }
}

List<String> _effectiveLotteryHighlightDigits(
  LotteryStockItem? item,
  List<String> fallbackDigits,
) {
  final raw = item?.raw;
  final rawDigits = raw == null
      ? const <String>[]
      : _normalizedLotteryHighlightDigits(
          raw['highlightDigits'] ??
              raw['highlight_digits'] ??
              raw['matchedDigits'] ??
              raw['matched_digits'] ??
              raw['search_digits'],
        );
  if (rawDigits.any((digit) => digit.isNotEmpty)) {
    return rawDigits;
  }

  final fallback = _normalizedLotteryHighlightDigits(fallbackDigits);
  if (fallback.any((digit) => digit.isNotEmpty)) {
    return fallback;
  }

  final highlight =
      (raw?['highlight'] ?? raw?['matched_suffix'])?.toString().replaceAll(
        RegExp(r'\D'),
        '',
      ) ??
      '';
  final number = item?.number ?? '';
  if (highlight.isEmpty || number.isEmpty || !number.endsWith(highlight)) {
    return const <String>[];
  }

  final start = number.length - highlight.length;
  return [
    for (var index = 0; index < number.length; index++)
      index >= start ? number[index] : '',
  ];
}

List<String> _normalizedLotteryHighlightDigits(
  Object? value, {
  int expectedLength = 6,
}) {
  if (value == null) return List.filled(expectedLength, '');
  final values = value is Iterable
      ? value
      : value.toString().contains(',')
      ? value.toString().split(',')
      : value.toString().split('');
  final normalized = [
    for (final raw in values)
      raw == null ? '' : raw.toString().replaceAll(RegExp(r'\D'), '').trim(),
  ];
  return [
    for (var index = 0; index < expectedLength; index++)
      index < normalized.length && normalized[index].isNotEmpty
          ? normalized[index].substring(0, 1)
          : '',
  ];
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final labelStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      color: colorScheme.onSurfaceVariant,
      fontSize: 18,
      fontWeight: FontWeight.w500,
      height: 1.2,
    );
    final valueStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      color: colorScheme.onSurface,
      fontSize: 18,
      fontWeight: FontWeight.w700,
      height: 1.2,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(label, style: labelStyle)),
          const SizedBox(width: 12),
          Text(value, textAlign: TextAlign.right, style: valueStyle),
        ],
      ),
    );
  }
}

typedef ReservationCountdownLabelBuilder =
    String Function(CustomerLocalizations l10n, String time);

Duration reservationServerTimeOffset(Object? serverTime, {DateTime? localNow}) {
  final serverNow = parseDateTime(serverTime);
  if (serverNow == null) return Duration.zero;
  return serverNow.difference(localNow ?? DateTime.now());
}

bool reservationDeadlineExpired(
  LotteryReservation reservation, {
  DateTime? localNow,
  DateTime? fallbackExpiresAt,
}) {
  if (!_hasReservationDeadline(reservation)) return false;
  final anchor = localNow ?? DateTime.now();
  final serverNow = anchor.add(
    reservationServerTimeOffset(reservation.serverTime, localNow: anchor),
  );
  return reservationRemainingDuration(
        reservation,
        now: serverNow,
        fallbackExpiresAt: fallbackExpiresAt,
      ).inSeconds <=
      0;
}

Duration reservationRemainingDuration(
  LotteryReservation reservation, {
  required DateTime now,
  DateTime? fallbackExpiresAt,
}) {
  final expiresAt = parseDateTime(reservation.expiresAt);
  if (expiresAt != null) {
    return nonNegativeDuration(expiresAt.difference(now));
  }
  if (fallbackExpiresAt != null) {
    return nonNegativeDuration(fallbackExpiresAt.difference(now));
  }
  if (reservation.expiresInSeconds > 0) {
    return Duration(seconds: reservation.expiresInSeconds);
  }
  return Duration.zero;
}

Duration nonNegativeDuration(Duration value) {
  return value.isNegative ? Duration.zero : value;
}

String formatReservationCountdown(Duration value) {
  final totalSeconds = value.inSeconds <= 0 ? 0 : value.inSeconds;
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}

LotteryReservation? earliestActiveReservation(
  List<LotteryReservation> reservations,
) {
  final active = reservations
      .where((reservation) => reservation.status == 'active')
      .toList(growable: false);
  if (active.isEmpty) return null;
  final sorted = [...active]..sort(_compareReservationDeadline);
  return sorted.first;
}

int _compareReservationDeadline(LotteryReservation a, LotteryReservation b) {
  final aExpiresAt = parseDateTime(a.expiresAt);
  final bExpiresAt = parseDateTime(b.expiresAt);
  if (aExpiresAt != null && bExpiresAt != null) {
    return aExpiresAt.compareTo(bExpiresAt);
  }
  if (aExpiresAt != null) return -1;
  if (bExpiresAt != null) return 1;
  return a.expiresInSeconds.compareTo(b.expiresInSeconds);
}

bool _hasReservationDeadline(LotteryReservation reservation) {
  return parseDateTime(reservation.expiresAt) != null ||
      reservation.expiresInSeconds > 0;
}

class _ReservationCountdownText extends StatefulWidget {
  const _ReservationCountdownText({
    required this.reservation,
    this.countdownLabelBuilder,
    this.paymentDockStyle = false,
  });

  final LotteryReservation reservation;
  final ReservationCountdownLabelBuilder? countdownLabelBuilder;
  final bool paymentDockStyle;

  @override
  State<_ReservationCountdownText> createState() =>
      _ReservationCountdownTextState();
}

class _ReservationCountdownTextState extends State<_ReservationCountdownText> {
  Timer? _timer;
  Duration _serverOffset = Duration.zero;
  DateTime? _fallbackExpiresAt;

  @override
  void initState() {
    super.initState();
    _syncServerOffset();
    _startTimerIfNeeded();
  }

  @override
  void didUpdateWidget(covariant _ReservationCountdownText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reservation.id != widget.reservation.id ||
        oldWidget.reservation.expiresAt != widget.reservation.expiresAt ||
        oldWidget.reservation.expiresInSeconds !=
            widget.reservation.expiresInSeconds ||
        oldWidget.reservation.serverTime != widget.reservation.serverTime) {
      _syncServerOffset();
      _startTimerIfNeeded();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (!_hasReservationDeadline(widget.reservation)) {
      return const SizedBox.shrink();
    }
    final now = DateTime.now().add(_serverOffset);
    final remaining = reservationRemainingDuration(
      widget.reservation,
      now: now,
      fallbackExpiresAt: _fallbackExpiresAt,
    );
    final formattedTime = formatReservationCountdown(remaining);
    final text = remaining.inSeconds <= 0
        ? l10n.cartExpired
        : (widget.countdownLabelBuilder ?? _defaultCountdownLabel)(
            l10n,
            formattedTime,
          );
    if (widget.paymentDockStyle && remaining.inSeconds > 0) {
      return _PaymentDockCountdownText(
        text: text,
        highlightedText: formattedTime,
      );
    }
    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: remaining.inSeconds <= 0
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  void _syncServerOffset() {
    _serverOffset = reservationServerTimeOffset(widget.reservation.serverTime);
    if (parseDateTime(widget.reservation.expiresAt) == null &&
        widget.reservation.expiresInSeconds > 0) {
      _fallbackExpiresAt = DateTime.now()
          .add(_serverOffset)
          .add(Duration(seconds: widget.reservation.expiresInSeconds));
    } else {
      _fallbackExpiresAt = null;
    }
  }

  void _startTimerIfNeeded() {
    _timer?.cancel();
    if (!_hasReservationDeadline(widget.reservation)) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }
}

class _PaymentDockCountdownText extends StatelessWidget {
  const _PaymentDockCountdownText({
    required this.text,
    required this.highlightedText,
  });

  final String text;
  final String highlightedText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final baseStyle = theme.textTheme.bodyMedium?.copyWith(
      color: colorScheme.onSurface,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      height: 1.25,
    );
    final highlightIndex = highlightedText.isEmpty
        ? -1
        : text.indexOf(highlightedText);
    if (highlightIndex < 0) {
      return Text(text, textAlign: TextAlign.center, style: baseStyle);
    }
    final before = text.substring(0, highlightIndex);
    final after = text.substring(highlightIndex + highlightedText.length);
    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: [
          if (before.isNotEmpty) TextSpan(text: before),
          TextSpan(
            text: highlightedText,
            style: baseStyle?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (after.isNotEmpty) TextSpan(text: after),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

String _defaultCountdownLabel(CustomerLocalizations l10n, String time) {
  return l10n.cartExpiresCountdown(time);
}

class _LotteryEmptyState extends StatelessWidget {
  const _LotteryEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 52),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          height: 1.35,
        ),
      ),
    );
  }
}

class _LotteryStatusAlert extends StatelessWidget {
  const _LotteryStatusAlert({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = colorScheme.onTertiaryContainer;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.tertiaryContainer.withValues(alpha: 0.56),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: colorScheme.tertiary,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: foreground,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: _lotterySurfaceDecoration(
        context,
        borderColor: colorScheme.outlineVariant,
        shadowAlpha: 0.06,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
        child: Column(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: SizedBox.square(
                dimension: 58,
                child: Icon(icon, size: 30, color: colorScheme.primary),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                height: 1.45,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              OutlinedButton(
                onPressed: onAction,
                style: _lotteryOutlinePillButtonStyle(context),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InlineNoticeCard extends StatelessWidget {
  const _InlineNoticeCard({
    required this.message,
    this.success = false,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final bool success;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = success ? colorScheme.primary : colorScheme.error;
    final background = success
        ? colorScheme.primary.withValues(alpha: 0.08)
        : colorScheme.errorContainer.withValues(alpha: 0.42);
    final border = success
        ? colorScheme.primary.withValues(alpha: 0.18)
        : colorScheme.error.withValues(alpha: 0.18);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              success
                  ? Icons.check_circle_outline_rounded
                  : Icons.error_outline_rounded,
              color: foreground,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: foreground,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  height: 1.4,
                ),
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  textStyle: const TextStyle(fontWeight: FontWeight.w900),
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Future<void> showLotteryReservationUnavailableNotice(BuildContext context) {
  final l10n = context.l10n;
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: const Color(0x94001636),
    builder: (_) => _ReservationUnavailableDialog(
      title: l10n.lotteryReservationUnavailableTitle,
      message: l10n.lotteryReservationUnavailableMessage,
      actionLabel: l10n.lotteryReservationUnavailableAction,
    ),
  );
}

class _ReservationUnavailableDialog extends StatelessWidget {
  const _ReservationUnavailableDialog({
    required this.title,
    required this.message,
    required this.actionLabel,
  });

  final String title;
  final String message;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Dialog(
      key: const ValueKey('reservation-unavailable-dialog'),
      insetPadding: const EdgeInsets.all(28),
      elevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 342),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 31, 24, 25),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFFFF),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x3D002658),
                  blurRadius: 44,
                  offset: Offset(0, 20),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 66,
                  height: 66,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFF4DF),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.priority_high_rounded,
                    color: Color(0xFFF19B00),
                    size: 38,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: textTheme.titleLarge?.copyWith(
                    color: const Color(0xFF242833),
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF5D6470),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: CustomerGradientButton.text(
                    onPressed: () => Navigator.of(context).pop(),
                    height: 52,
                    fontSize: 18,
                    label: actionLabel,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckoutSummaryTotalRow extends StatelessWidget {
  const _CheckoutSummaryTotalRow({required this.label, required this.total});

  final String label;
  final double total;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final amount = _checkoutAmountWithoutUnit(l10n, total);
    final unit = l10n.commonBahtSuffix;
    final amountText = Text(
      amount,
      key: const ValueKey('checkout-summary-total-amount'),
      textAlign: TextAlign.end,
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
        color: colorScheme.primary,
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 1,
      ),
    );
    final unitText = unit.isEmpty
        ? null
        : Text(
            unit,
            key: const ValueKey('checkout-summary-total-unit'),
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: colorScheme.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.w500,
              height: 1.1,
            ),
          );
    final labelStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      color: colorScheme.onSurfaceVariant,
      fontSize: 18,
      fontWeight: FontWeight.w500,
      height: 1.2,
    );
    final value = Row(
      key: const ValueKey('checkout-summary-total-value'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        amountText,
        if (unitText != null) ...[const SizedBox(width: 4), unitText],
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        key: const ValueKey('checkout-summary-total-row'),
        children: [
          Expanded(child: Text(label, style: labelStyle)),
          const SizedBox(width: 12),
          value,
        ],
      ),
    );
  }
}

class _LoadingMessageCard extends StatelessWidget {
  const _LoadingMessageCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: _lotterySurfaceDecoration(
        context,
        borderColor: colorScheme.outlineVariant,
        shadowAlpha: 0.06,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
        child: Column(
          children: [
            CustomerLoadingMark(
              width: 48,
              height: 28,
              color: colorScheme.primary,
              trackColor: colorScheme.primary.withValues(alpha: 0.14),
              semanticLabel: message,
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

BoxDecoration _lotterySurfaceDecoration(
  BuildContext context, {
  BorderRadiusGeometry? borderRadius,
  Color? borderColor,
  Color? color,
  double borderWidth = 1,
  double shadowAlpha = 0.08,
  double blurRadius = 24,
  Offset shadowOffset = const Offset(0, 10),
}) {
  final colorScheme = Theme.of(context).colorScheme;
  return BoxDecoration(
    color: color ?? colorScheme.surface,
    borderRadius: borderRadius ?? BorderRadius.circular(12),
    border: Border.all(
      color: borderColor ?? colorScheme.primary.withValues(alpha: 0.12),
      width: borderWidth,
    ),
    boxShadow: [
      BoxShadow(
        color: colorScheme.primary.withValues(alpha: shadowAlpha),
        blurRadius: blurRadius,
        offset: shadowOffset,
      ),
    ],
  );
}

BoxDecoration _lotterySmallGradientPillDecoration(
  BuildContext context, {
  bool enabled = true,
}) {
  final primary = Theme.of(context).colorScheme.primary;
  return BoxDecoration(
    gradient: enabled
        ? LinearGradient(
            colors: [
              AppTheme.primaryActionStart(primary),
              AppTheme.primaryActionEnd(primary),
            ],
          )
        : null,
    color: enabled ? null : AppTheme.appOutlinePillDisabledFill,
    borderRadius: BorderRadius.circular(999),
  );
}

ButtonStyle _lotterySmallGradientPillButtonStyle(BuildContext context) {
  final textStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
    fontWeight: FontWeight.w700,
    height: 1.1,
    letterSpacing: 0,
  );
  return FilledButton.styleFrom(
    backgroundColor: Colors.transparent,
    disabledBackgroundColor: Colors.transparent,
    foregroundColor: AppTheme.appSheet,
    disabledForegroundColor: AppTheme.appOutlinePillDisabledText,
    shadowColor: Colors.transparent,
    minimumSize: const Size(84, 40),
    padding: const EdgeInsets.symmetric(horizontal: 18),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    visualDensity: VisualDensity.compact,
    shape: const StadiumBorder(),
    textStyle: textStyle,
  ).copyWith(overlayColor: const WidgetStatePropertyAll(Colors.transparent));
}

TextStyle? _lotterySectionTitleTextStyle(BuildContext context) {
  final theme = Theme.of(context);
  return theme.textTheme.titleLarge?.copyWith(
    color: theme.colorScheme.onSurface,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );
}

TextStyle? _lotteryDrawDateTextStyle(BuildContext context) {
  final theme = Theme.of(context);
  return theme.textTheme.titleMedium?.copyWith(
    color: theme.colorScheme.onSurface,
    fontSize: 20,
    fontWeight: FontWeight.w400,
    height: 1.2,
  );
}

LotteryDigitInputStyle _lotteryDigitBoxesStyle(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;
  return LotteryDigitInputStyle(
    fillColor: colorScheme.surface,
    textColor: colorScheme.primary,
    hintColor: colorScheme.outlineVariant,
    focusedBorderColor: colorScheme.primary,
    enabledBorderColor: colorScheme.outlineVariant,
    borderRadius: 9,
    spacing: 18,
    verticalPadding: 7,
    fontWeight: FontWeight.w700,
  );
}

ButtonStyle _lotteryTextLinkButtonStyle(BuildContext context) {
  final theme = Theme.of(context);
  final primary = theme.colorScheme.primary;
  return TextButton.styleFrom(
    foregroundColor: AppTheme.primaryLink(primary),
    minimumSize: const Size(0, 36),
    padding: EdgeInsets.zero,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    visualDensity: VisualDensity.compact,
    textStyle: theme.textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w600,
      height: 1.2,
      letterSpacing: 0,
    ),
  ).copyWith(overlayColor: const WidgetStatePropertyAll(Colors.transparent));
}

ButtonStyle _lotteryOutlinePillButtonStyle(
  BuildContext context, {
  bool enabled = true,
}) {
  final theme = Theme.of(context);
  final primary = theme.colorScheme.primary;
  final outlineText = AppTheme.primaryOutlineText(primary);
  final outlineBorder = AppTheme.primaryOutlineBorder(primary);
  return OutlinedButton.styleFrom(
    foregroundColor: outlineText,
    disabledForegroundColor: AppTheme.appOutlinePillDisabledText,
    minimumSize: const Size(0, 40),
    padding: const EdgeInsets.symmetric(horizontal: 14),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    visualDensity: VisualDensity.compact,
    backgroundColor: AppTheme.appSheet,
    disabledBackgroundColor: AppTheme.appOutlinePillDisabledFill,
    shape: const StadiumBorder(),
    side: BorderSide(
      color: enabled ? outlineBorder : AppTheme.appOutlinePillDisabledBorder,
    ),
    textStyle: theme.textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w600,
      height: 1.2,
      letterSpacing: 0,
    ),
  ).copyWith(
    overlayColor: const WidgetStatePropertyAll(Colors.transparent),
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      if (!enabled || states.contains(WidgetState.disabled)) {
        return AppTheme.appOutlinePillDisabledFill;
      }
      return AppTheme.appSheet;
    }),
    side: WidgetStateProperty.resolveWith((states) {
      if (!enabled || states.contains(WidgetState.disabled)) {
        return const BorderSide(color: AppTheme.appOutlinePillDisabledBorder);
      }
      return BorderSide(color: outlineBorder);
    }),
  );
}

String _errorMessage(Object error, String fallback) {
  return customerErrorMessage(error, fallback);
}

String _checkoutErrorMessage(Object error, String fallback) {
  final message = ApiErrorInfo.fromObject(error).message.trim();
  if (message.isEmpty) return fallback;
  if (error is DioException || error is Map) return message;
  return fallback;
}

bool _isReservationUnavailableError(Object error) {
  final code = ApiErrorInfo.fromObject(error).code.trim().toLowerCase();
  return code == 'reservation_unavailable';
}
