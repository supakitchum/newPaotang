import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/i18n/customer_localizations.dart';
import '../../../core/utils/api_errors.dart';
import '../../../core/utils/formatters.dart';
import '../../../features/lottery/data/lottery_models.dart';
import '../../../features/lottery/data/lottery_repository.dart';
import '../../../features/results/data/result_repository.dart';
import '../../../features/lottery/presentation/lottery_digit_input_row.dart';
import '../../../features/lottery/presentation/lottery_screens.dart';
import '../../../features/lottery/presentation/lottery_stock_realtime_monitor.dart';
import '../../../features/lottery/presentation/lottery_stock_skeleton.dart';
import '../../../features/lottery/presentation/lottery_store_segment_tabs.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/customer_page_body.dart';
import '../../../shared/widgets/customer_section_header.dart';
import '../data/store_models.dart';
import '../data/store_repository.dart';

class StoresScreen extends ConsumerStatefulWidget {
  const StoresScreen({super.key});

  @override
  ConsumerState<StoresScreen> createState() => _StoresScreenState();
}

class _StoresScreenState extends ConsumerState<StoresScreen> {
  final _search = TextEditingController();
  final _scrollController = ScrollController();
  final _stores = <StoreItem>[];
  String _cursor = '';
  bool _hasMore = false;
  bool _loading = true;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(reset: true));
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppShell(
      title: l10n.storesTitle,
      currentPath: '/stores',
      child: RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: ListView(
          controller: _scrollController,
          children: [
            CustomerPageBody(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const LotteryStoreSegmentTabs(activePath: '/stores'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _search,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      labelText: l10n.storesSearchLabel,
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        onPressed: () {
                          _search.clear();
                          _load(reset: true);
                        },
                        icon: const Icon(Icons.close),
                      ),
                    ),
                    onSubmitted: (_) => _load(reset: true),
                  ),
                  const SizedBox(height: 20),
                  CustomerSectionHeader(
                    title: l10n.storesRecommendedTitle,
                    leading: const Icon(Icons.storefront_outlined),
                  ),
                  const SizedBox(height: 16),
                  if (_loading)
                    const Center(child: CircularProgressIndicator())
                  else if (_stores.isEmpty)
                    _EmptyCard(
                      icon: Icons.storefront_outlined,
                      title: l10n.storesEmptyTitle,
                      message: l10n.storesEmptyMessage,
                    )
                  else
                    for (final store in _stores)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _StoreCard(store: store),
                      ),
                  if (_hasMore) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed:
                          _loadingMore ? null : () => _load(reset: false),
                      icon: _loadingMore
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.expand_more),
                      label: Text(
                        _loadingMore
                            ? l10n.commonLoadingMore
                            : l10n.commonLoadMore,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _load({required bool reset}) async {
    if (_loadingMore || (!reset && (_loading || !_hasMore))) return;
    setState(() {
      if (reset) {
        _loading = true;
        _cursor = '';
        _stores.clear();
      } else {
        _loadingMore = true;
      }
    });
    try {
      final page = await ref.read(storeRepositoryProvider).list(
            q: _search.text,
            cursor: reset ? '' : _cursor,
          );
      if (!mounted) return;
      setState(() {
        _stores.addAll(page.items);
        _cursor = page.nextCursor;
        _hasMore = page.hasMore;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  void _handleScroll() {
    if (!_scrollController.hasClients ||
        _loading ||
        _loadingMore ||
        !_hasMore) {
      return;
    }
    final position = _scrollController.position;
    if (!position.hasPixels || !position.hasContentDimensions) return;
    final distanceFromBottom = position.maxScrollExtent - position.pixels;
    if (distanceFromBottom <= 240) {
      _load(reset: false);
    }
  }
}

class StoreLotteriesScreen extends ConsumerStatefulWidget {
  const StoreLotteriesScreen({
    super.key,
    required this.storeId,
    this.storeName = '',
    this.gameId = '',
  });

  final String storeId;
  final String storeName;
  final String gameId;

  @override
  ConsumerState<StoreLotteriesScreen> createState() =>
      _StoreLotteriesScreenState();
}

class _StoreLotteriesScreenState extends ConsumerState<StoreLotteriesScreen> {
  final _digits = List.generate(6, (_) => TextEditingController());
  final _scrollController = ScrollController();
  final _tickets = <StoreLotteryTicket>[];
  final _reservedByStockId = <String, String>{};
  LotteryCart _cart = LotteryCart.empty();
  Timer? _refreshCooldownTimer;
  String _cursor = '';
  String _storeName = '';
  String _gameId = '';
  String _busyStockId = '';
  int _refreshCooldownSeconds = 0;
  bool _hasMore = false;
  bool _canReserve = true;
  bool _loading = true;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _storeName = widget.storeName;
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(reset: true));
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _refreshCooldownTimer?.cancel();
    for (final controller in _digits) {
      controller.dispose();
    }
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

    final l10n = context.l10n;
    final storeName =
        _storeName.isEmpty ? l10n.storesFallbackStoreName : _storeName;
    final showCartDock = _storeCartSelectionReviewEnabled(_cart);
    return AppShell(
      title: l10n.storesLotteriesTitle,
      currentPath: '/stores',
      child: Stack(
        children: [
          Positioned.fill(
            child: RefreshIndicator(
              onRefresh: () => _load(reset: true),
              child: ListView(
                controller: _scrollController,
                children: [
                  CustomerPageBody(
                    bottom: showCartDock ? 220 : 128,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Card(
                          margin: EdgeInsets.zero,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer,
                              child: const Icon(Icons.storefront_outlined),
                            ),
                            title: Text(
                              storeName,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w900),
                            ),
                            subtitle: Text(l10n.storesLotteriesSubtitle),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.storesLotteriesSubtitle,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                LotteryDigitInputRow(
                                  controllers: _digits,
                                  onSubmitted: _submitSearch,
                                ),
                                const SizedBox(height: 12),
                                _StoreLotterySearchActions(
                                  onSearch: _submitSearch,
                                  onClear: _clearSearch,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        CustomerSectionHeader(
                          title: l10n.lotteryStockTitle,
                          action: TextButton.icon(
                            onPressed:
                                _refreshDisabled ? null : _refreshLotteries,
                            icon: const Icon(Icons.refresh, size: 18),
                            label: Text(_refreshLabel(l10n)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_loading && _tickets.isEmpty)
                          ...lotteryStockSkeletonCards(
                            keyPrefix: 'store-lottery-stock-skeleton',
                          )
                        else if (_tickets.isEmpty)
                          _EmptyCard(
                            icon: Icons.confirmation_number_outlined,
                            title: l10n.storesLotteriesEmptyTitle,
                            message: l10n.storesLotteriesEmptyMessage,
                          )
                        else ...[
                          if (!_canReserve) ...[
                            _StoreSaleClosedNotice(
                              title: l10n.lotterySaleClosedTitle,
                              message: l10n.lotterySaleClosedMessage,
                            ),
                            const SizedBox(height: 12),
                          ],
                          for (final ticket in _tickets)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _LotteryTicketCard(
                                ticket: ticket,
                                canReserve: _canReserve,
                                reserved: _reservedByStockId.containsKey(
                                  ticket.localStockItemId,
                                ),
                                busy: _busyStockId == ticket.localStockItemId,
                                onToggle: () => _toggleReservation(ticket),
                              ),
                            ),
                        ],
                        if (_loadingMore) ...[
                          if (_tickets.isNotEmpty) const SizedBox(height: 10),
                          ...lotteryStockSkeletonCards(
                            keyPrefix: 'store-lottery-stock-skeleton-more',
                          ),
                        ] else if (_hasMore) ...[
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed:
                                _loadingMore ? null : () => _load(reset: false),
                            icon: _loadingMore
                                ? const SizedBox.square(
                                    dimension: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.expand_more),
                            label: Text(
                              _loadingMore
                                  ? l10n.commonLoadingMore
                                  : l10n.commonLoadMore,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (showCartDock)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _StoreFixedPaymentDockContainer(
                child: _StoreCartSelectionDock(
                  cart: _cart,
                  onReview: () => context.go('/cart'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _load({required bool reset}) async {
    if (_loadingMore || (!reset && (_loading || !_hasMore))) return;
    setState(() {
      if (reset) {
        _loading = true;
        _cursor = '';
        _tickets.clear();
      } else {
        _loadingMore = true;
      }
    });
    try {
      var gameId = widget.gameId;
      if (gameId.isEmpty) {
        final game = await ref.read(resultRepositoryProvider).currentGame();
        gameId = game?.id ?? '';
      }
      if (gameId.isEmpty) {
        if (mounted) setState(() => _hasMore = false);
        return;
      }
      final repo = ref.read(storeRepositoryProvider);
      final auth = ref.read(authControllerProvider);
      final results = await Future.wait([
        repo.lotteries(
          storeId: widget.storeId,
          gameId: gameId,
          digits: _searchDigits,
          cursor: reset ? '' : _cursor,
        ),
        if (auth.isAuthenticated)
          ref.read(lotteryRepositoryProvider).cart()
        else
          Future<LotteryCart>.value(LotteryCart.empty()),
      ]);
      final page = results[0] as StoreLotteryPage;
      final cart = results[1] as LotteryCart;
      if (!mounted) return;
      setState(() {
        _gameId = page.gameId.isNotEmpty ? page.gameId : gameId;
        _tickets.addAll(page.items);
        _cursor = page.nextCursor;
        _hasMore = page.hasMore;
        _canReserve = page.canReserve;
        if (page.sellerName.isNotEmpty) _storeName = page.sellerName;
        _syncReservedCart(cart);
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  void _handleScroll() {
    if (!_scrollController.hasClients ||
        _loading ||
        _loadingMore ||
        _busyStockId.isNotEmpty ||
        !_hasMore) {
      return;
    }
    final position = _scrollController.position;
    if (!position.hasPixels || !position.hasContentDimensions) return;
    final distanceFromBottom = position.maxScrollExtent - position.pixels;
    if (distanceFromBottom <= 180) {
      _load(reset: false);
    }
  }

  List<String> get _searchDigits {
    return _digits.map((controller) => controller.text).toList(
          growable: false,
        );
  }

  void _submitSearch() {
    _load(reset: true);
  }

  void _clearSearch() {
    for (final controller in _digits) {
      controller.clear();
    }
    _load(reset: true);
  }

  bool get _refreshDisabled {
    return _loading ||
        _loadingMore ||
        _busyStockId.isNotEmpty ||
        _refreshCooldownSeconds > 0;
  }

  String _refreshLabel(CustomerLocalizations l10n) {
    if (_loading) return l10n.lotteryLoadingNew;
    if (_refreshCooldownSeconds > 0) {
      return l10n.lotteryRefreshCooldown(_refreshCooldownSeconds);
    }
    return l10n.lotteryShowNew;
  }

  Future<void> _refreshLotteries() async {
    if (_refreshDisabled) return;
    await _load(reset: true);
    if (mounted) _startRefreshCooldown();
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

  Future<void> _toggleReservation(StoreLotteryTicket ticket) async {
    if (_busyStockId.isNotEmpty) return;
    final reservedId = _reservedByStockId[ticket.localStockItemId];
    if (!_canReserve && (reservedId == null || reservedId.isEmpty)) {
      return;
    }
    final auth = ref.read(authControllerProvider);
    if (!auth.isAuthenticated) {
      context.go('/login');
      return;
    }

    setState(() => _busyStockId = ticket.localStockItemId);
    try {
      final repo = ref.read(lotteryRepositoryProvider);
      if (reservedId != null && reservedId.isNotEmpty) {
        final cart = await repo.releaseReservation(reservedId);
        _syncReservedCart(cart);
      } else {
        final reservation = await repo.reserve(
          gameId: _gameId,
          item: _toLotteryStockItem(ticket),
        );
        if (!mounted) return;
        setState(() {
          _cart = _storeCartWithReservation(_cart, reservation);
          for (final item in reservation.items) {
            _reservedByStockId[item.localStockItemId] = reservation.id;
          }
        });
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _reservedByStockId.containsKey(ticket.localStockItemId)
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
      if (_storeReservationUnavailable(error)) {
        setState(() => _busyStockId = '');
        await _refreshStoreCartQuietly();
        if (!mounted) return;
        await _showStoreReservationUnavailableDialog(
          ticket,
          removeItem: reservedId?.isEmpty ?? true,
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.lotteryActionFailed)),
      );
    } finally {
      if (mounted) setState(() => _busyStockId = '');
    }
  }

  Future<void> _refreshStoreCartQuietly() async {
    try {
      final cart = await ref.read(lotteryRepositoryProvider).cart();
      if (!mounted) return;
      setState(() => _syncReservedCart(cart));
    } catch (_) {
      // Keep the Nuxt sold-ticket recovery flow even if cart refresh fails.
    }
  }

  Future<void> _showStoreReservationUnavailableDialog(
    StoreLotteryTicket ticket, {
    required bool removeItem,
  }) async {
    final l10n = context.l10n;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.error_outline),
        title: Text(l10n.lotteryReservationUnavailableTitle),
        content: Text(l10n.lotteryReservationUnavailableMessage),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.lotteryReservationUnavailableAction),
          ),
        ],
      ),
    );
    if (!mounted || !removeItem) return;
    setState(() {
      _tickets.removeWhere(
        (candidate) =>
            candidate.localStockItemId == ticket.localStockItemId ||
            candidate.token == ticket.token,
      );
    });
  }

  void _syncReservedCart(LotteryCart cart) {
    _cart = cart;
    _reservedByStockId
      ..clear()
      ..addEntries(
        cart.items.map(
          (item) => MapEntry(item.localStockItemId, item.reservationId),
        ),
      );
  }
}

bool _storeReservationUnavailable(Object error) {
  return ApiErrorInfo.fromObject(error).code.trim().toLowerCase() ==
      'reservation_unavailable';
}

bool _storeCartSelectionReviewEnabled(LotteryCart cart) {
  final deadline = earliestActiveReservation(cart.reservations);
  return cart.reservationIds.isNotEmpty &&
      (deadline == null || !reservationDeadlineExpired(deadline));
}

LotteryCart _storeCartWithReservation(
  LotteryCart cart,
  LotteryReservation reservation,
) {
  final reservations = [
    ...cart.reservations.where((item) => item.id != reservation.id),
    reservation,
  ];
  return LotteryCart(
    reservations: List<LotteryReservation>.unmodifiable(reservations),
    total: reservations.fold<double>(
      0,
      (sum, item) => sum + _storeReservationDisplayTotal(item),
    ),
    itemCount: reservations.fold<int>(
      0,
      (sum, item) => sum + item.items.length,
    ),
    serverTime: reservation.serverTime ?? cart.serverTime,
    warnings: cart.warnings,
  );
}

double _storeReservationDisplayTotal(LotteryReservation reservation) {
  if (reservation.total > 0) return reservation.total;
  return reservation.items.fold<double>(0, (sum, item) => sum + item.price);
}

bool _storeHasReservationDeadline(LotteryReservation reservation) {
  return parseDateTime(reservation.expiresAt) != null ||
      reservation.expiresInSeconds > 0;
}

class _StoreCartSelectionDock extends StatelessWidget {
  const _StoreCartSelectionDock({
    required this.cart,
    required this.onReview,
  });

  final LotteryCart cart;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final deadline = earliestActiveReservation(cart.reservations);
    return Card(
      key: const ValueKey('store-cart-selection-dock'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (deadline != null) ...[
              Center(
                child: _StoreReservationCountdownText(reservation: deadline),
              ),
              const SizedBox(height: 12),
            ],
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 420;
                final summary = Column(
                  crossAxisAlignment: compact
                      ? CrossAxisAlignment.stretch
                      : CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.cartSelectionCountLabel,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.ticketsCount(cart.itemCount),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ],
                );
                final action = SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: onReview,
                    icon: const Icon(Icons.shopping_cart_checkout),
                    label: Text(l10n.cartSelectionReview),
                  ),
                );
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      summary,
                      const SizedBox(height: 12),
                      action,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: summary),
                    const SizedBox(width: 16),
                    Flexible(child: action),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StoreFixedPaymentDockContainer extends StatelessWidget {
  const _StoreFixedPaymentDockContainer({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontal = constraints.maxWidth >= 720 ? 28.0 : 0.0;
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontal),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: child,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StoreReservationCountdownText extends StatefulWidget {
  const _StoreReservationCountdownText({required this.reservation});

  final LotteryReservation reservation;

  @override
  State<_StoreReservationCountdownText> createState() =>
      _StoreReservationCountdownTextState();
}

class _StoreReservationCountdownTextState
    extends State<_StoreReservationCountdownText> {
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
  void didUpdateWidget(covariant _StoreReservationCountdownText oldWidget) {
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
    if (!_storeHasReservationDeadline(widget.reservation)) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final now = DateTime.now().add(_serverOffset);
    final remaining = reservationRemainingDuration(
      widget.reservation,
      now: now,
      fallbackExpiresAt: _fallbackExpiresAt,
    );
    final text = remaining.inSeconds <= 0
        ? l10n.cartExpired
        : l10n.cartExpiresCountdown(formatReservationCountdown(remaining));
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
    if (!_storeHasReservationDeadline(widget.reservation)) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }
}

class _StoreCard extends StatelessWidget {
  const _StoreCard({required this.store});

  final StoreItem store;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final storeName =
        store.name.isEmpty ? l10n.storesFallbackStoreName : store.name;
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.storefront_outlined)),
        title: Text(
          storeName,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: store.code.isEmpty ? null : Text(l10n.storeCode(store.code)),
      ),
    );
  }
}

class _StoreLotterySearchActions extends StatelessWidget {
  const _StoreLotterySearchActions({
    required this.onSearch,
    required this.onClear,
  });

  final VoidCallback onSearch;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 380;
        final searchButton = FilledButton.icon(
          onPressed: onSearch,
          icon: const Icon(Icons.search),
          label: Text(l10n.lotterySearchButton),
        );
        final clearButton = OutlinedButton.icon(
          onPressed: onClear,
          icon: const Icon(Icons.refresh),
          label: Text(l10n.lotteryClearButton),
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 50, child: searchButton),
              const SizedBox(height: 10),
              SizedBox(height: 48, child: clearButton),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: SizedBox(height: 50, child: searchButton)),
            const SizedBox(width: 10),
            SizedBox(height: 50, child: clearButton),
          ],
        );
      },
    );
  }
}

class _LotteryTicketCard extends StatelessWidget {
  const _LotteryTicketCard({
    required this.ticket,
    required this.canReserve,
    required this.reserved,
    required this.busy,
    required this.onToggle,
  });

  final StoreLotteryTicket ticket;
  final bool canReserve;
  final bool reserved;
  final bool busy;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final digits = ticket.number.split('');
    final sellerName = ticket.sellerName.isEmpty
        ? l10n.storesFallbackStoreName
        : ticket.sellerName;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sellerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 5,
                    children: [
                      for (final digit in digits)
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            child: Text(
                              digit,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FilledButton.tonal(
                  onPressed: reserved || (canReserve && ticket.isAvailable)
                      ? onToggle
                      : null,
                  child: busy
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          reserved
                              ? l10n.lotteryRemove
                              : canReserve
                                  ? l10n.lotterySelect
                                  : l10n.lotterySaleClosedAction,
                        ),
                ),
                const SizedBox(height: 8),
                Text(
                  formatBaht(ticket.price),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Chip(
                  label: Text(
                    ticket.isAvailable
                        ? l10n.storesTicketAvailable
                        : l10n.storesTicketSoldOut,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StoreSaleClosedNotice extends StatelessWidget {
  const _StoreSaleClosedNotice({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      color: colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.lock_clock_outlined,
              color: colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: colorScheme.onErrorContainer,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onErrorContainer,
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

LotteryStockItem _toLotteryStockItem(StoreLotteryTicket ticket) {
  return LotteryStockItem(
    id: ticket.id,
    token: ticket.token,
    localStockItemId: ticket.localStockItemId,
    stockRef: ticket.stockRef,
    number: ticket.number,
    sellerName: ticket.sellerName,
    storeName: ticket.storeName,
    price: ticket.price,
    remainingCount: ticket.remainingCount,
    status: ticket.status,
    reservationId: ticket.reservationId,
    reservationExpiresAt: null,
    serverTime: null,
    imageUrl: '',
    thumbUrl: '',
    raw: const {},
  );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Icon(icon, size: 42),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
