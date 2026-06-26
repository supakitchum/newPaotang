import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/customer_localizations.dart';
import '../../../core/utils/formatters.dart';
import '../../../features/results/data/result_repository.dart';
import '../../../features/wallet/data/wallet_repository.dart';
import '../../../shared/widgets/app_shell.dart';
import '../data/lottery_models.dart';
import '../data/lottery_repository.dart';
import 'lottery_navigation.dart';
import 'lottery_stock_realtime_monitor.dart';

class BuyScreen extends ConsumerStatefulWidget {
  const BuyScreen({super.key});

  @override
  ConsumerState<BuyScreen> createState() => _BuyScreenState();
}

class _BuyScreenState extends ConsumerState<BuyScreen> {
  final _digits = List.generate(6, (_) => TextEditingController());

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
      actions: [
        IconButton(
          tooltip: l10n.lotteryCartTooltip,
          onPressed: () => context.go('/cart'),
          icon: const Icon(Icons.shopping_cart_outlined),
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.lotterySearchHeroTitle,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(l10n.lotterySearchHeroSubtitle),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      for (var index = 0; index < _digits.length; index++) ...[
                        Expanded(
                          child: TextField(
                            controller: _digits[index],
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(1),
                            ],
                            decoration: InputDecoration(
                              hintText: '${index + 1}',
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onChanged: (_) {
                              if (_digits[index].text.isNotEmpty &&
                                  index < _digits.length - 1) {
                                FocusScope.of(context).nextFocus();
                              }
                            },
                          ),
                        ),
                        if (index < _digits.length - 1)
                          const SizedBox(width: 6),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _goSearch,
                          icon: const Icon(Icons.search),
                          label: Text(l10n.lotterySearchButton),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: () {
                          for (final controller in _digits) {
                            controller.clear();
                          }
                        },
                        icon: const Icon(Icons.refresh),
                        label: Text(l10n.lotteryClearButton),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _LotteryStockList(
            title: l10n.lotteryStockTitle,
            subtitle: l10n.lotteryStockSubtitle,
          ),
        ],
      ),
    );
  }

  void _goSearch() {
    context.go(
      lotterySearchPath(
        digits: _digits.map((controller) => controller.text).toList(),
      ),
    );
  }
}

class BuySearchScreen extends StatefulWidget {
  const BuySearchScreen({super.key, required this.query});

  final Map<String, String> query;

  @override
  State<BuySearchScreen> createState() => _BuySearchScreenState();
}

class _BuySearchScreenState extends State<BuySearchScreen> {
  late final TextEditingController _number;

  @override
  void initState() {
    super.initState();
    _number = TextEditingController(text: widget.query['number'] ?? '');
  }

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final digits = List.generate(6, (index) => widget.query['d${index + 1}']);
    final returnPath = lotterySearchPath(
      number: widget.query['number'] ?? '',
      digits: digits.map((value) => value ?? '').toList(),
      storeId: widget.query['store_id'] ?? '',
    );
    return AppShell(
      title: l10n.lotterySearchPageTitle,
      currentPath: '/buy',
      actions: [
        IconButton(
          tooltip: l10n.lotteryCartTooltip,
          onPressed: () => context.go('/cart'),
          icon: const Icon(Icons.shopping_cart_outlined),
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.lotterySearchCardTitle,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _number,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    decoration: InputDecoration(
                      labelText: l10n.lotteryNumberLabel,
                      prefixIcon: const Icon(Icons.search),
                    ),
                    onSubmitted: (_) => _submitNumber(),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _submitNumber,
                    icon: const Icon(Icons.search),
                    label: Text(l10n.lotterySearchAgain),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _LotteryStockList(
            title: l10n.lotterySearchResultsTitle,
            subtitle: l10n.lotterySearchResultsSubtitle,
            number: widget.query['number'] ?? '',
            digits: digits.map((value) => value ?? '').toList(),
            storeId: widget.query['store_id'] ?? '',
            returnPath: returnPath,
          ),
        ],
      ),
    );
  }

  void _submitNumber() {
    final value = _number.text.replaceAll(RegExp(r'\D'), '');
    context.go(
      lotterySearchPath(
        number: value,
        storeId: widget.query['store_id'] ?? '',
      ),
    );
  }
}

class BuyMoreScreen extends StatelessWidget {
  const BuyMoreScreen({super.key, required this.query});

  final Map<String, String> query;

  @override
  Widget build(BuildContext context) {
    final number = query['number'] ?? '';
    final backPath = safeLotteryBackPath(query['back'] ?? '', fallback: '/buy');
    final hasExplicitBackPath = (query['back'] ?? '').trim().isNotEmpty;
    final l10n = context.l10n;
    return AppShell(
      title: l10n.lotteryMoreTitle,
      currentPath: '/buy',
      actions: [
        IconButton(
          tooltip: l10n.lotteryCartTooltip,
          onPressed: () => context.go('/cart'),
          icon: const Icon(Icons.shopping_cart_outlined),
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.confirmation_num)),
              title: Text(
                number.isEmpty ? l10n.lotteryMoreFallback : number,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              subtitle: Text(l10n.lotteryMoreSubtitle),
            ),
          ),
          if (hasExplicitBackPath) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => context.go(backPath),
                icon: const Icon(Icons.arrow_back),
                label: Text(l10n.commonBack),
              ),
            ),
          ],
          const SizedBox(height: 16),
          _LotteryStockList(
            title: l10n.lotteryMoreListTitle,
            number: number,
            storeId: query['store_id'] ?? '',
            returnPath: backPath,
          ),
        ],
      ),
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
  bool _loading = true;
  bool _busy = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
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

    final l10n = context.l10n;
    return AppShell(
      title: l10n.cartTitle,
      currentPath: '/tickets',
      sensitive: true,
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.shopping_cart_outlined),
                ),
                title: Text(
                  l10n.cartReservedTitle,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text(
                  _cart.isEmpty
                      ? l10n.cartEmptySubtitle
                      : l10n.cartSummary(
                          _cart.itemCount,
                          formatBaht(_cart.total),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_error.isNotEmpty)
              _MessageCard(
                icon: Icons.error_outline,
                title: l10n.cartLoadFailedTitle,
                message: _error,
                actionLabel: l10n.commonRetry,
                onAction: _load,
              )
            else if (_cart.isEmpty)
              _MessageCard(
                icon: Icons.confirmation_number_outlined,
                title: l10n.cartEmptyTitle,
                message: l10n.cartEmptyMessage,
                actionLabel: l10n.cartFindTickets,
                onAction: () => context.go('/buy'),
              )
            else ...[
              for (final reservation in _cart.reservations)
                _ReservationCard(
                  reservation: reservation,
                  busy: _busy,
                  onRelease: () => _release(reservation.id),
                ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _busy ? null : () => context.go('/checkout'),
                icon: const Icon(Icons.payment),
                label: Text(l10n.cartCheckout),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final cart = await ref.read(lotteryRepositoryProvider).cart();
      if (!mounted) return;
      setState(() => _cart = cart);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = context.l10n.cartGenericRetry);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _release(String reservationId) async {
    if (reservationId.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      final cart = await ref.read(lotteryRepositoryProvider).releaseReservation(
            reservationId,
          );
      if (!mounted) return;
      setState(() => _cart = cart);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  LotteryCart _cart = LotteryCart.empty();
  double _walletBalance = 0;
  bool _loading = true;
  bool _submitting = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
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

    final enoughBalance = _walletBalance >= _cart.total;
    final l10n = context.l10n;
    return AppShell(
      title: l10n.checkoutTitle,
      currentPath: '/tickets',
      sensitive: true,
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.checkoutSummaryTitle,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 14),
                    _AmountRow(
                      label: l10n.checkoutTicketCount,
                      value: l10n.ticketsCount(_cart.itemCount),
                    ),
                    _AmountRow(
                      label: l10n.checkoutTotal,
                      value: formatBaht(_cart.total),
                    ),
                    _AmountRow(
                      label: l10n.checkoutWalletBalance,
                      value: formatBaht(_walletBalance),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_error.isNotEmpty)
              _MessageCard(
                icon: Icons.error_outline,
                title: l10n.checkoutLoadFailedTitle,
                message: _error,
                actionLabel: l10n.commonRetry,
                onAction: _load,
              )
            else if (_cart.isEmpty)
              _MessageCard(
                icon: Icons.shopping_cart_outlined,
                title: l10n.checkoutNoPaymentTitle,
                message: l10n.checkoutNoPaymentMessage,
                actionLabel: l10n.checkoutBackToBuy,
                onAction: () => context.go('/buy'),
              )
            else ...[
              Card(
                child: Column(
                  children: [
                    for (final item in _cart.items)
                      _CompactLotteryTile(item: item),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (!enoughBalance)
                Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: ListTile(
                    leading: const Icon(Icons.account_balance_wallet_outlined),
                    title: Text(l10n.checkoutInsufficientTitle),
                    subtitle: Text(l10n.checkoutInsufficientSubtitle),
                    trailing: TextButton(
                      onPressed: () => context.go('/topup?back=/checkout'),
                      child: Text(l10n.homeActionTopup),
                    ),
                  ),
                ),
              FilledButton.icon(
                onPressed:
                    _submitting || !enoughBalance ? null : _submitCheckout,
                icon: _submitting
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(
                  _submitting ? l10n.checkoutSubmitting : l10n.checkoutConfirm,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final results = await Future.wait([
        ref.read(lotteryRepositoryProvider).cart(),
        ref.read(walletRepositoryProvider).summary(),
      ]);
      if (!mounted) return;
      setState(() {
        _cart = results[0] as LotteryCart;
        _walletBalance = (results[1] as dynamic).balance as double;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = context.l10n.cartGenericRetry);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitCheckout() async {
    if (_cart.reservationIds.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    try {
      final order = await ref
          .read(lotteryRepositoryProvider)
          .checkout(_cart.reservationIds);
      if (!mounted) return;
      context.go(
        Uri(
          path: '/success',
          queryParameters: {if (order.id.isNotEmpty) 'order_id': order.id},
        ).toString(),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMessage(error, context.l10n.checkoutFailed)),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class _LotteryStockList extends ConsumerStatefulWidget {
  const _LotteryStockList({
    required this.title,
    this.subtitle = '',
    this.number = '',
    this.digits = const [],
    this.storeId = '',
    this.returnPath = '/buy',
  });

  final String title;
  final String subtitle;
  final String number;
  final List<String> digits;
  final String storeId;
  final String returnPath;

  @override
  ConsumerState<_LotteryStockList> createState() => _LotteryStockListState();
}

class _LotteryStockListState extends ConsumerState<_LotteryStockList> {
  final _items = <LotteryStockItem>[];
  final _reservedByStockId = <String, String>{};
  String _gameId = '';
  String _cursor = '';
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  String _error = '';
  String _busyStockId = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(reset: true));
  }

  @override
  void didUpdateWidget(covariant _LotteryStockList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.number != widget.number ||
        oldWidget.storeId != widget.storeId ||
        oldWidget.digits.join() != widget.digits.join()) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load(reset: true));
    }
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

    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  if (widget.subtitle.isNotEmpty)
                    Text(
                      widget.subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: _loading ? null : () => _load(reset: true),
              icon: const Icon(Icons.refresh),
              label: Text(l10n.lotteryShowNew),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_error.isNotEmpty)
          _MessageCard(
            icon: Icons.error_outline,
            title: l10n.lotteryLoadFailed,
            message: _error,
            actionLabel: l10n.commonRetry,
            onAction: () => _load(reset: true),
          )
        else if (_items.isEmpty)
          _MessageCard(
            icon: Icons.confirmation_number_outlined,
            title: l10n.lotteryNotFoundTitle,
            message: l10n.lotteryNotFoundMessage,
          )
        else ...[
          for (final item in _items)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _LotteryStockCard(
                item: item,
                reserved: _reservedByStockId.containsKey(item.localStockItemId),
                busy: _busyStockId == item.localStockItemId,
                morePath: lotteryMorePath(
                  number: item.number,
                  storeId: widget.storeId,
                  backPath: widget.returnPath,
                ),
                onReserve: () => _toggleReservation(item),
              ),
            ),
          if (_hasMore)
            OutlinedButton.icon(
              onPressed: _loadingMore ? null : () => _load(reset: false),
              icon: _loadingMore
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.expand_more),
              label: Text(
                _loadingMore ? l10n.commonLoadingMore : l10n.commonLoadMore,
              ),
            ),
        ],
      ],
    );
  }

  Future<void> _load({required bool reset}) async {
    if (_loadingMore) return;
    setState(() {
      _error = '';
      if (reset) {
        _loading = true;
        _cursor = '';
        _items.clear();
      } else {
        _loadingMore = true;
      }
    });
    try {
      var gameId = _gameId;
      if (gameId.isEmpty || reset) {
        final game = await ref.read(resultRepositoryProvider).currentGame();
        gameId = game?.id ?? '';
      }
      if (gameId.isEmpty) {
        if (mounted) setState(() => _hasMore = false);
        return;
      }
      final results = await Future.wait([
        ref.read(lotteryRepositoryProvider).search(
              gameId: gameId,
              number: widget.number,
              digits: widget.digits,
              storeId: widget.storeId,
              cursor: reset ? '' : _cursor,
            ),
        ref.read(lotteryRepositoryProvider).cart(),
      ]);
      final page = results[0] as LotteryStockPage;
      final cart = results[1] as LotteryCart;
      if (!mounted) return;
      setState(() {
        _gameId = page.gameId.isNotEmpty ? page.gameId : gameId;
        _items.addAll(page.items);
        _cursor = page.nextCursor;
        _hasMore = page.hasMore;
        _reservedByStockId
          ..clear()
          ..addEntries(
            cart.items.map(
              (item) => MapEntry(item.localStockItemId, item.reservationId),
            ),
          );
      });
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _error = _errorMessage(error, context.l10n.cartGenericRetry),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _toggleReservation(LotteryStockItem item) async {
    if (_busyStockId.isNotEmpty) return;
    setState(() => _busyStockId = item.localStockItemId);
    try {
      final reservedId = _reservedByStockId[item.localStockItemId];
      if (reservedId != null && reservedId.isNotEmpty) {
        final cart =
            await ref.read(lotteryRepositoryProvider).releaseReservation(
                  reservedId,
                );
        _syncReservedCart(cart);
      } else {
        final reservation = await ref.read(lotteryRepositoryProvider).reserve(
              gameId: _gameId,
              item: item,
            );
        if (!mounted) return;
        setState(() {
          for (final reservedItem in reservation.items) {
            _reservedByStockId[reservedItem.localStockItemId] = reservation.id;
          }
        });
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _reservedByStockId.containsKey(item.localStockItemId)
                ? context.l10n.lotteryAddedToCart
                : context.l10n.lotteryRemovedFromCart,
          ),
          action: SnackBarAction(
            label: context.l10n.lotteryCartAction,
            onPressed: () => context.go('/cart'),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMessage(error, context.l10n.lotteryActionFailed)),
        ),
      );
    } finally {
      if (mounted) setState(() => _busyStockId = '');
    }
  }

  void _syncReservedCart(LotteryCart cart) {
    if (!mounted) return;
    setState(() {
      _reservedByStockId
        ..clear()
        ..addEntries(
          cart.items.map(
            (item) => MapEntry(item.localStockItemId, item.reservationId),
          ),
        );
    });
  }
}

class _LotteryStockCard extends StatelessWidget {
  const _LotteryStockCard({
    required this.item,
    required this.reserved,
    required this.busy,
    required this.morePath,
    required this.onReserve,
  });

  final LotteryStockItem item;
  final bool reserved;
  final bool busy;
  final String morePath;
  final VoidCallback onReserve;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.sellerName.trim().isEmpty
                        ? l10n.ticketLabelGovernmentLottery
                        : item.sellerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 10),
                  _LotteryNumber(number: item.number),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => context.push(morePath),
                    child: Text(l10n.lotteryViewMore),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FilledButton.tonal(
                  onPressed: item.isAvailable || reserved ? onReserve : null,
                  child: busy
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          reserved ? l10n.lotteryRemove : l10n.lotterySelect,
                        ),
                ),
                const SizedBox(height: 8),
                Text(
                  formatBaht(item.price),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReservationCard extends StatelessWidget {
  const _ReservationCard({
    required this.reservation,
    required this.busy,
    required this.onRelease,
  });

  final LotteryReservation reservation;
  final bool busy;
  final VoidCallback onRelease;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.cartReservationTitle(reservation.items.length),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                TextButton.icon(
                  onPressed: busy ? null : onRelease,
                  icon: const Icon(Icons.close),
                  label: Text(l10n.lotteryRemove),
                ),
              ],
            ),
            if (reservation.expiresInSeconds > 0)
              Text(l10n.cartExpiresIn(reservation.expiresInSeconds ~/ 60)),
            const SizedBox(height: 8),
            for (final item in reservation.items)
              _CompactLotteryTile(item: item),
            const Divider(),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                formatBaht(reservation.total),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactLotteryTile extends StatelessWidget {
  const _CompactLotteryTile({required this.item});

  final LotteryStockItem item;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: _LotteryNumber(number: item.number, compact: true),
      subtitle: Text(
        item.storeName.trim().isEmpty
            ? context.l10n.storesFallbackStoreName
            : item.storeName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        formatBaht(item.price),
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _LotteryNumber extends StatelessWidget {
  const _LotteryNumber({required this.number, this.compact = false});

  final String number;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final digits = number.split('');
    return Wrap(
      spacing: compact ? 3 : 5,
      children: [
        for (final digit in digits)
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 7 : 9,
                vertical: compact ? 3 : 4,
              ),
              child: Text(
                digit,
                style: TextStyle(
                  fontSize: compact ? 15 : 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Icon(icon, size: 42),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(message, textAlign: TextAlign.center),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

String _errorMessage(Object error, String fallback) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['error'] is Map) {
      final message = (data['error'] as Map)['message'];
      if (message != null && message.toString().trim().isNotEmpty) {
        return message.toString();
      }
    }
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
  }
  return fallback;
}
