import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/i18n/app_locale.dart';
import '../../../core/i18n/customer_localizations.dart';
import '../../../core/navigation/customer_redirect.dart';
import '../../../core/utils/api_errors.dart';
import '../../../core/utils/formatters.dart';
import '../../../features/lottery/data/lottery_models.dart';
import '../../../features/lottery/data/lottery_repository.dart';
import '../../../features/results/data/result_repository.dart';
import '../../../features/lottery/presentation/lottery_digit_input_row.dart';
import '../../../features/lottery/presentation/lottery_navigation.dart';
import '../../../features/lottery/presentation/lottery_screens.dart';
import '../../../features/lottery/presentation/lottery_stock_realtime_monitor.dart';
import '../../../features/lottery/presentation/lottery_stock_skeleton.dart';
import '../../../features/lottery/presentation/lottery_store_segment_tabs.dart';
import '../../../shared/utils/customer_operational_error.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/customer_page_body.dart';
import '../../../shared/widgets/flexible_image.dart';
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
  LotteryCart _cart = LotteryCart.empty();
  String _cursor = '';
  bool _hasMore = false;
  bool _loading = true;
  bool _loadingMore = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load(reset: true);
      _loadCart();
    });
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
    final showCartDock = _storeCartSelectionReviewEnabled(_cart);
    return AppShell(
      title: l10n.lotteryBuyTitle,
      currentPath: '/stores',
      backPath: '/buy',
      showBottomNavigation: false,
      heroMinHeight: 252,
      heroContent: const LotteryStoreSegmentTabs(activePath: '/stores'),
      child: Stack(
        children: [
          Positioned.fill(
            child: RefreshIndicator(
              onRefresh: () async {
                await Future.wait([
                  _load(reset: true),
                  _loadCart(),
                ]);
              },
              child: ListView(
                controller: _scrollController,
                padding: EdgeInsets.zero,
                children: [
                  _StoreContentSheet(
                    bottom: showCartDock ? 220 : 128,
                    children: [
                      _StoreSearchBox(
                        controller: _search,
                        hintText: l10n.storesSearchLabel,
                        onSubmitted: (_) => _load(reset: true),
                      ),
                      const SizedBox(height: 48),
                      _StoreSectionHeader(
                        title: l10n.storesRecommendedTitle,
                      ),
                      const SizedBox(height: 24),
                      const _StoreFilterPills(),
                      const SizedBox(height: 24),
                      if (_loading && _stores.isEmpty)
                        const _StoreSkeletonRows()
                      else if (_error.isNotEmpty && _stores.isEmpty)
                        _StoreErrorCard(
                          icon: Icons.error_outline,
                          title: l10n.storesLoadFailedTitle,
                          message: _error,
                          actionLabel: l10n.commonRetry,
                          onAction: () => _load(reset: true),
                        )
                      else if (_stores.isEmpty)
                        _StoreEmptyState(message: l10n.storesEmptyTitle)
                      else
                        for (final store in _stores)
                          _StoreCard(
                            store: store,
                            onTap: () =>
                                context.go(_storeLotteriesPath(store.id)),
                          ),
                      if (_error.isNotEmpty && _stores.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _StoreErrorCard(
                          icon: Icons.error_outline,
                          title: l10n.storesLoadFailedTitle,
                          message: _error,
                          actionLabel: l10n.commonRetry,
                          onAction: () => _load(reset: false),
                        ),
                      ],
                      if (_loadingMore) ...[
                        const SizedBox(height: 8),
                        const _StoreSkeletonRows(
                          keyPrefix: 'store-list-skeleton-more',
                        ),
                      ] else if (_hasMore) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.center,
                          child: SizedBox(
                            height: 40,
                            child: OutlinedButton(
                              onPressed: _loadingMore
                                  ? null
                                  : () => _load(reset: false),
                              style: _storeOutlinePillButtonStyle(
                                context,
                                enabled: !_loadingMore,
                              ),
                              child: Text(
                                _loadingMore
                                    ? l10n.commonLoadingMore
                                    : l10n.commonLoadMore,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
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
        _stores.clear();
        _error = '';
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
        _error = '';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = customerErrorMessage(
          error,
          context.l10n.storesLoadFailedMessage,
        );
        if (reset) {
          _hasMore = false;
        }
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

  Future<void> _loadCart() async {
    final auth = ref.read(authControllerProvider);
    if (!auth.isAuthenticated) {
      if (mounted && _cart.reservationIds.isNotEmpty) {
        setState(() => _cart = LotteryCart.empty());
      }
      return;
    }
    try {
      final cart = await ref.read(lotteryRepositoryProvider).cart();
      if (!mounted) return;
      setState(() => _cart = cart);
    } catch (_) {
      // Store browsing remains usable even when the optional cart refresh fails.
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

class _StoreSectionHeader extends StatelessWidget {
  const _StoreSectionHeader({
    required this.title,
    this.action,
  });

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  height: 1.12,
                ),
          ),
        ),
        if (action != null) ...[
          const SizedBox(width: 12),
          action!,
        ],
      ],
    );
  }
}

class _StoreSearchBox extends StatelessWidget {
  const _StoreSearchBox({
    required this.controller,
    required this.hintText,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      key: const ValueKey('store-search-box'),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.14),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SizedBox(
        height: 51,
        child: Row(
          children: [
            const SizedBox(width: 16),
            Icon(
              Icons.search,
              size: 22,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: controller,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration.collapsed(
                  hintText: hintText,
                  hintStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                ),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                onSubmitted: onSubmitted,
              ),
            ),
            const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }
}

class _StoreFilterPills extends StatelessWidget {
  const _StoreFilterPills();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _StoreFilterPill(
            label: l10n.lotteryFilterAll,
            icon: Icons.playlist_add_check,
            selected: true,
          ),
          const SizedBox(width: 12),
          _StoreFilterPill(
            label: l10n.lotteryFilterDiscount,
            icon: Icons.keyboard_double_arrow_down,
            iconColor: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: 12),
          _StoreFilterPill(
            label: l10n.lotteryFilterAccessibleStore,
            icon: Icons.accessible_forward,
            iconColor: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: 12),
          _StoreFilterPill(
            label: l10n.lotteryFilterAgencyStore,
            icon: Icons.groups_2_outlined,
            iconColor: Theme.of(context).colorScheme.tertiary,
          ),
        ],
      ),
    );
  }
}

class _StoreFilterPill extends StatelessWidget {
  const _StoreFilterPill({
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
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = selected ? colorScheme.primary : colorScheme.onSurface;
    return Semantics(
      button: true,
      selected: selected,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? colorScheme.surface : colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? colorScheme.primary : Colors.transparent,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: iconColor ?? foreground),
              const SizedBox(width: 7),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
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
  Timer? _priceTrendClearTimer;
  LotteryStockPricePatch? _activePricePatch;
  String _cursor = '';
  String _storeName = '';
  String _gameId = '';
  String _drawDateLabel = '';
  String _busyStockId = '';
  String _stockNoticeMessage = '';
  int _refreshCooldownSeconds = 0;
  bool _hasMore = false;
  bool _canReserve = true;
  bool _loading = true;
  bool _loadingMore = false;
  bool _stockNoticeSuccess = false;
  String _error = '';

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
    _priceTrendClearTimer?.cancel();
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
    final storeName =
        _storeName.isEmpty ? l10n.storesFallbackStoreName : _storeName;
    final showCartDock = _storeCartSelectionReviewEnabled(_cart);
    return AppShell(
      title: l10n.storesLotteriesTitle,
      currentPath: '/stores',
      backPath: '/stores',
      showBottomNavigation: false,
      heroMinHeight: 312,
      heroContent: _StoreLotteriesHero(storeName: storeName),
      child: Stack(
        children: [
          Positioned.fill(
            child: RefreshIndicator(
              onRefresh: () => _load(reset: true),
              child: ListView(
                controller: _scrollController,
                padding: EdgeInsets.zero,
                children: [
                  _StoreContentSheet(
                    bottom: showCartDock ? 220 : 128,
                    children: [
                      Column(
                        key: const ValueKey('store-lotteries-search-panel'),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.storesLotteriesSubtitle,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          if (_drawDateLabel.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              _drawDateLabel,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ],
                          const SizedBox(height: 20),
                          LotteryDigitInputRow(
                            controllers: _digits,
                            readOnly: true,
                            onTap: _openStoreSearch,
                            style: LotteryDigitInputStyle(
                              enabledBorderColor:
                                  Theme.of(context).colorScheme.outlineVariant,
                              focusedBorderColor:
                                  Theme.of(context).colorScheme.primary,
                              hintColor: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.18),
                              borderRadius: 9,
                              spacing: 18,
                              verticalPadding: 8,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 34),
                      _StoreSectionHeader(
                        title: l10n.lotteryStockTitle,
                        action: OutlinedButton.icon(
                          onPressed:
                              _refreshDisabled ? null : _refreshLotteries,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: Text(_refreshLabel(l10n)),
                          style: _storeOutlinePillButtonStyle(
                            context,
                            enabled: !_refreshDisabled,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_loading && _tickets.isEmpty)
                        ...lotteryStockSkeletonCards(
                          keyPrefix: 'store-lottery-stock-skeleton',
                        )
                      else if (_error.isNotEmpty && _tickets.isEmpty)
                        _StoreErrorCard(
                          icon: Icons.error_outline,
                          title: l10n.storesLotteriesLoadFailedTitle,
                          message: _error,
                          actionLabel: l10n.commonRetry,
                          onAction: () => _load(reset: true),
                        )
                      else if (_tickets.isEmpty)
                        _StoreEmptyState(
                          message: l10n.storesLotteriesEmptyTitle,
                        )
                      else ...[
                        if (_stockNoticeMessage.isNotEmpty) ...[
                          _StoreInlineNoticeCard(
                            message: _stockNoticeMessage,
                            success: _stockNoticeSuccess,
                            actionLabel: _stockNoticeSuccess
                                ? l10n.lotteryCartAction
                                : null,
                            onAction: _stockNoticeSuccess
                                ? () => context.go('/cart')
                                : null,
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (!_canReserve) ...[
                          _StoreSaleClosedNotice(
                            title: l10n.lotterySaleClosedTitle,
                          ),
                          const SizedBox(height: 12),
                        ],
                        for (final ticket in _tickets)
                          _LotteryTicketCard(
                            ticket: ticket,
                            morePath: lotteryMorePath(
                              number: ticket.number,
                              storeId: widget.storeId,
                              backPath: _storeLotteriesBackPath(
                                widget.storeId,
                              ),
                            ),
                            canReserve: _canReserve,
                            reserved: _reservedByStockId.containsKey(
                              ticket.localStockItemId,
                            ),
                            busy: _busyStockId == ticket.localStockItemId,
                            onToggle: () => _toggleReservation(ticket),
                          ),
                      ],
                      if (_loadingMore) ...[
                        if (_tickets.isNotEmpty) const SizedBox(height: 10),
                        ...lotteryStockSkeletonCards(
                          keyPrefix: 'store-lottery-stock-skeleton-more',
                        ),
                      ] else if (_hasMore) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.center,
                          child: SizedBox(
                            height: 40,
                            child: OutlinedButton(
                              onPressed: _loadingMore
                                  ? null
                                  : () => _load(reset: false),
                              style: _storeOutlinePillButtonStyle(
                                context,
                                enabled: !_loadingMore,
                              ),
                              child: Text(
                                _loadingMore
                                    ? l10n.commonLoadingMore
                                    : l10n.commonLoadMore,
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (_error.isNotEmpty && _tickets.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _StoreErrorCard(
                          icon: Icons.error_outline,
                          title: l10n.storesLotteriesLoadFailedTitle,
                          message: _error,
                          actionLabel: l10n.commonRetry,
                          onAction: () => _load(reset: false),
                        ),
                      ],
                    ],
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
    final l10n = context.l10n;
    var nextDrawDateLabel = _drawDateLabel;
    setState(() {
      if (reset) {
        _loading = true;
        _cursor = '';
        _tickets.clear();
        _error = '';
        _stockNoticeMessage = '';
      } else {
        _loadingMore = true;
      }
    });
    try {
      var gameId = widget.gameId;
      if (gameId.isEmpty) {
        final game = await ref.read(resultRepositoryProvider).currentGame();
        gameId = game?.id ?? '';
        nextDrawDateLabel = _storeLotteriesDrawDateLabel(l10n, game?.drawAt);
      }
      if (gameId.isEmpty) {
        if (mounted) {
          setState(() {
            _drawDateLabel = nextDrawDateLabel;
            _hasMore = false;
          });
        }
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
      final nextGameId = page.gameId.isNotEmpty ? page.gameId : gameId;
      final nextTickets = _ticketsWithActivePricePatch(
        page.items,
        gameId: nextGameId,
      );
      if (!mounted) return;
      setState(() {
        _drawDateLabel = nextDrawDateLabel;
        _gameId = nextGameId;
        _tickets.addAll(nextTickets);
        _cursor = page.nextCursor;
        _hasMore = page.hasMore;
        _canReserve = page.canReserve;
        if (page.sellerName.isNotEmpty) _storeName = page.sellerName;
        _syncReservedCart(cart);
        _error = '';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _drawDateLabel = nextDrawDateLabel;
        _error = customerErrorMessage(
          error,
          l10n.storesLotteriesLoadFailedMessage,
        );
        if (reset) {
          _hasMore = false;
        }
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
    return const ['', '', '', '', '', ''];
  }

  void _openStoreSearch() {
    context.go(lotterySearchPath(storeId: widget.storeId));
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

  void _applyPricePatch(LotteryStockPricePatch patch) {
    if (_tickets.isEmpty || !patch.matchesGame(_gameId)) return;
    final patchedTickets = _ticketsWithPricePatch(_tickets, patch);
    if (!_storeLotteryTicketsChanged(_tickets, patchedTickets)) return;
    setState(() {
      _activePricePatch = patch;
      _tickets
        ..clear()
        ..addAll(patchedTickets);
    });
    _schedulePriceTrendClear(patch.flashKey);
  }

  void _applyAvailabilityPatch(LotteryStockAvailabilityPatch patch) {
    if (_tickets.isEmpty || !patch.matchesGame(_gameId)) return;
    final patchedTickets = [
      for (final ticket in _tickets)
        patch.matchesNumber(ticket.number)
            ? ticket.copyWith(
                remainingCount: patch.remainingCount,
                status: patch.status,
              )
            : ticket,
    ];
    if (!_storeLotteryTicketsChanged(_tickets, patchedTickets)) return;
    setState(() {
      _tickets
        ..clear()
        ..addAll(patchedTickets);
    });
  }

  List<StoreLotteryTicket> _ticketsWithActivePricePatch(
    List<StoreLotteryTicket> tickets, {
    required String gameId,
  }) {
    final patch = _activePricePatch;
    if (patch == null || !patch.matchesGame(gameId)) return tickets;
    return _ticketsWithPricePatch(tickets, patch);
  }

  List<StoreLotteryTicket> _ticketsWithPricePatch(
    List<StoreLotteryTicket> tickets,
    LotteryStockPricePatch patch,
  ) {
    return [
      for (final ticket in tickets) _ticketWithPricePatch(ticket, patch),
    ];
  }

  StoreLotteryTicket _ticketWithPricePatch(
    StoreLotteryTicket ticket,
    LotteryStockPricePatch patch,
  ) {
    final existing = _matchingStoreTicket(ticket);
    final existingTrend = existing?.priceFlashKey == patch.flashKey
        ? existing?.priceTrend ?? ''
        : '';
    if (existingTrend.isNotEmpty) {
      return ticket.copyWith(
        price: patch.price,
        priceTrend: existingTrend,
        priceFlashKey: patch.flashKey,
      );
    }
    if (!ticket.price.isFinite ||
        ticket.price <= 0 ||
        ticket.price == patch.price) {
      return ticket.price == patch.price
          ? ticket
          : ticket.copyWith(price: patch.price);
    }
    return ticket.copyWith(
      price: patch.price,
      priceTrend: patch.price > ticket.price
          ? lotteryStockPriceTrendUp
          : lotteryStockPriceTrendDown,
      priceFlashKey: patch.flashKey,
    );
  }

  StoreLotteryTicket? _matchingStoreTicket(StoreLotteryTicket ticket) {
    for (final existing in _tickets) {
      if (existing.localStockItemId == ticket.localStockItemId ||
          existing.token == ticket.token ||
          existing.stockRef == ticket.stockRef) {
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
        for (var index = 0; index < _tickets.length; index++) {
          final ticket = _tickets[index];
          if (ticket.priceFlashKey == flashKey) {
            _tickets[index] = ticket.copyWith(
              priceTrend: '',
              priceFlashKey: 0,
            );
          }
        }
      });
    });
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
      context.go(
        customerLoginRouteForRedirect(GoRouterState.of(context).uri.toString()),
      );
      return;
    }

    setState(() {
      _busyStockId = ticket.localStockItemId;
      _stockNoticeMessage = '';
    });
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
      setState(() {
        _stockNoticeSuccess = true;
        _stockNoticeMessage =
            _reservedByStockId.containsKey(ticket.localStockItemId)
                ? context.l10n.lotteryAddedToCart
                : context.l10n.lotteryRemovedFromCart;
      });
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
      setState(() {
        _stockNoticeSuccess = false;
        _stockNoticeMessage = customerErrorMessage(
          error,
          context.l10n.lotteryActionFailed,
        );
      });
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
    await showLotteryReservationUnavailableNotice(context);
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
    return DecoratedBox(
      key: const ValueKey('cart-selection-dock'),
      decoration: _storeSurfaceDecoration(
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
              Center(
                child: _StoreReservationCountdownText(reservation: deadline),
              ),
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
                        l10n.cartSelectionTitle,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        l10n.ticketsCount(cart.itemCount),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w900,
                            ),
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
                    child: DecoratedBox(
                      decoration: _storeDockButtonDecoration(context),
                      child: SizedBox(
                        height: 58,
                        child: FilledButton(
                          onPressed: onReview,
                          style: _storeDockButtonStyle(context),
                          child: Text(l10n.cartSelectionReview),
                        ),
                      ),
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

class _StoreContentSheet extends StatelessWidget {
  const _StoreContentSheet({
    required this.children,
    required this.bottom,
  });

  final List<Widget> children;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 620),
        child: CustomerPageBody(
          top: 23,
          bottom: bottom,
          mobileHorizontal: 18,
          wideHorizontal: 0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
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
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: customerContentMaxWidthFor(context),
        ),
        child: child,
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

String _storeLotteriesDrawDateLabel(
  CustomerLocalizations l10n,
  Object? drawAt,
) {
  final drawDate = parseDateTime(drawAt);
  if (drawDate == null) return '';
  return l10n.cartDrawDate(
    formatLocalizedShortDate(drawDate, localeTag(l10n.locale)),
  );
}

class _StoreCard extends StatelessWidget {
  const _StoreCard({
    required this.store,
    required this.onTap,
  });

  final StoreItem store;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final storeName =
        store.name.isEmpty ? l10n.storesFallbackStoreName : store.name;
    return Semantics(
      key: ValueKey('store-list-row-${store.id}'),
      button: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border(
            bottom: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.75),
            ),
          ),
        ),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 72),
              child: Row(
                children: [
                  SizedBox.square(
                    dimension: 40,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.storefront_outlined,
                        color: colorScheme.onPrimary,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      storeName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
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

class _StoreLotteriesHero extends StatelessWidget {
  const _StoreLotteriesHero({required this.storeName});

  final String storeName;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      key: const ValueKey('store-lotteries-hero'),
      decoration: _storeSurfaceDecoration(
        context,
        borderRadius: BorderRadius.circular(12),
        borderColor: Colors.transparent,
        shadowAlpha: 0.09,
        blurRadius: 22,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Icon(
                      Icons.storefront_outlined,
                      color: colorScheme.onPrimary,
                      size: 26,
                    ),
                  ),
                ),
                Positioned(
                  right: 2,
                  bottom: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colorScheme.tertiary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colorScheme.surface,
                        width: 1.5,
                      ),
                    ),
                    child: const SizedBox.square(dimension: 10),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                storeName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              Icons.favorite_border,
              key: const ValueKey('store-lotteries-hero-favorite'),
              color: colorScheme.onSurfaceVariant,
              size: 32,
            ),
          ],
        ),
      ),
    );
  }
}

class _StoreSkeletonRows extends StatelessWidget {
  const _StoreSkeletonRows({
    this.keyPrefix = 'store-list-skeleton',
  });

  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    const count = 6;
    final colorScheme = Theme.of(context).colorScheme;
    final placeholderColor =
        colorScheme.surfaceContainerHighest.withValues(alpha: 0.72);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < count; index++)
          DecoratedBox(
            key: ValueKey('$keyPrefix-$index'),
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
              child: Row(
                children: [
                  DecoratedBox(
                    decoration: _storeSkeletonBlockDecoration(
                      context,
                      color: placeholderColor,
                      shape: BoxShape.circle,
                    ),
                    child: const SizedBox.square(dimension: 40),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DecoratedBox(
                      decoration: _storeSkeletonBlockDecoration(
                        context,
                        color: placeholderColor,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const SizedBox(height: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

BoxDecoration _storeSkeletonBlockDecoration(
  BuildContext context, {
  required Color color,
  BorderRadiusGeometry? borderRadius,
  BoxShape shape = BoxShape.rectangle,
}) {
  final highlight =
      Color.lerp(color, Theme.of(context).colorScheme.surface, 0.62) ?? color;
  return BoxDecoration(
    gradient: LinearGradient(colors: [color, highlight, color]),
    borderRadius: shape == BoxShape.circle ? null : borderRadius,
    shape: shape,
  );
}

class _LotteryTicketCard extends StatelessWidget {
  const _LotteryTicketCard({
    required this.ticket,
    required this.morePath,
    required this.canReserve,
    required this.reserved,
    required this.busy,
    required this.onToggle,
  });

  final StoreLotteryTicket ticket;
  final String morePath;
  final bool canReserve;
  final bool reserved;
  final bool busy;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final unavailable = !reserved && !ticket.isAvailable;
    final sellerName = ticket.sellerName.isEmpty
        ? l10n.storesFallbackStoreName
        : ticket.sellerName;
    final actionLabel = busy
        ? reserved
            ? l10n.lotteryRemoving
            : l10n.lotterySelecting
        : reserved
            ? l10n.lotteryRemove
            : !ticket.isAvailable
                ? l10n.lotterySoldOut
                : canReserve
                    ? l10n.lotterySelect
                    : l10n.lotterySaleClosedAction;
    final canToggle = reserved || (canReserve && ticket.isAvailable);
    final actionButton = reserved
        ? FilledButton(
            onPressed: busy || !canToggle ? null : onToggle,
            style: FilledButton.styleFrom(
              minimumSize: const Size(96, 42),
              shape: const StadiumBorder(),
              textStyle: const TextStyle(fontWeight: FontWeight.w900),
            ),
            child: Text(actionLabel),
          )
        : OutlinedButton(
            onPressed: busy || !canToggle ? null : onToggle,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(96, 42),
              shape: const StadiumBorder(),
              side: BorderSide(
                color: canToggle
                    ? colorScheme.primary
                    : colorScheme.outlineVariant,
              ),
              textStyle: const TextStyle(fontWeight: FontWeight.w900),
            ),
            child: Text(actionLabel),
          );
    return LotteryUnavailableRowVisualState(
      unavailable: unavailable,
      child: DecoratedBox(
        key: ValueKey('store-lottery-ticket-row-${ticket.localStockItemId}'),
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
                      key: const ValueKey('store-lottery-more-link'),
                      onPressed: () => context.push(morePath),
                      style: _storeTextLinkButtonStyle(context),
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
              final ticketDisplay = Column(
                key: const ValueKey('store-lottery-ticket-display-row'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StoreLotteryImageFrame(ticket: ticket),
                  const SizedBox(height: 10),
                  _StoreLotteryNumber(number: ticket.number),
                ],
              );
              final mainRow = Row(
                key: const ValueKey('store-lottery-ticket-main-row'),
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: ticketDisplay),
                  const SizedBox(width: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 96),
                    child: SizedBox(height: 42, child: actionButton),
                  ),
                ],
              );
              final bottomRow = Row(
                key: const ValueKey('store-lottery-ticket-meta-price-row'),
                children: [
                  Expanded(
                    child: Text(
                      sellerName,
                      key: const ValueKey('lottery-stock-seller-row'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _StoreLotteryPriceText(ticket: ticket),
                ],
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  brandHeader,
                  const SizedBox(height: 10),
                  mainRow,
                  const SizedBox(height: 8),
                  bottomRow,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _StoreLotteryImageFrame extends StatelessWidget {
  const _StoreLotteryImageFrame({required this.ticket});

  final StoreLotteryTicket ticket;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final normalizedStatus = ticket.imageStatus.trim().toLowerCase();
    final imageError = ticket.imageError.trim();
    final source = ticket.thumbUrl.trim().isNotEmpty
        ? ticket.thumbUrl.trim()
        : ticket.imageUrl.trim();
    final canLoadImage = source.isNotEmpty &&
        !{
          'pending_assets',
          'failed',
          'missing',
        }.contains(normalizedStatus);
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
      key: const ValueKey('store-lottery-ticket-image-frame'),
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
                    key: const ValueKey('store-lottery-ticket-image'),
                    source: source,
                    fit: BoxFit.cover,
                    errorIcon: Icons.confirmation_number_outlined,
                  )
                : Padding(
                    key: const ValueKey('store-lottery-ticket-image-fallback'),
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
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
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

class _StoreLotteryPriceText extends StatelessWidget {
  const _StoreLotteryPriceText({required this.ticket});

  final StoreLotteryTicket ticket;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final priceTrend = ticket.priceTrend;
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
      key: const ValueKey('store-lottery-ticket-price-row'),
      mainAxisSize: MainAxisSize.min,
      children: [
        if (trendIcon != null) ...[
          Icon(
            trendIcon,
            key: ValueKey('store-lottery-ticket-price-trend-$priceTrend'),
            size: 16,
            color: trendColor,
          ),
          const SizedBox(width: 2),
        ],
        Text(
          formatBaht(ticket.price),
          key: const ValueKey('store-lottery-ticket-price'),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: trendColor,
                fontWeight: FontWeight.w900,
              ),
        ),
      ],
    );
  }
}

class _StoreLotteryNumber extends StatelessWidget {
  const _StoreLotteryNumber({required this.number});

  final String number;

  @override
  Widget build(BuildContext context) {
    final digits = number.split('');
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9DF),
        borderRadius: BorderRadius.circular(7),
      ),
      child: SizedBox(
        width: 154,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(
            children: [
              for (final digit in digits)
                Expanded(
                  child: Text(
                    digit,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF030303),
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

String _storeLotteriesBackPath(String storeId) {
  return _storeLotteriesPath(storeId);
}

String _storeLotteriesPath(String storeId) {
  final normalizedStoreId = storeId.trim();
  return Uri(
    path: '/stores/lotteries',
    queryParameters:
        normalizedStoreId.isEmpty ? null : {'store_id': normalizedStoreId},
  ).toString();
}

bool _storeLotteryTicketsChanged(
  List<StoreLotteryTicket> current,
  List<StoreLotteryTicket> next,
) {
  if (current.length != next.length) return true;
  for (var index = 0; index < current.length; index++) {
    final currentTicket = current[index];
    final nextTicket = next[index];
    if (currentTicket.price != nextTicket.price ||
        currentTicket.remainingCount != nextTicket.remainingCount ||
        currentTicket.status != nextTicket.status ||
        currentTicket.priceTrend != nextTicket.priceTrend ||
        currentTicket.priceFlashKey != nextTicket.priceFlashKey) {
      return true;
    }
  }
  return false;
}

class _StoreSaleClosedNotice extends StatelessWidget {
  const _StoreSaleClosedNotice({
    required this.title,
  });

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

class _StoreInlineNoticeCard extends StatelessWidget {
  const _StoreInlineNoticeCard({
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
    return DecoratedBox(
      decoration: _storeSurfaceDecoration(
        context,
        color: success
            ? colorScheme.primary.withValues(alpha: 0.08)
            : const Color(0xFFFFF5F5),
        borderColor: success
            ? colorScheme.primary.withValues(alpha: 0.18)
            : const Color(0xFFFECACA),
        shadowAlpha: 0.04,
        blurRadius: 16,
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
    imageUrl: ticket.imageUrl,
    thumbUrl: ticket.thumbUrl,
    imageStatus: ticket.imageStatus,
    imageError: ticket.imageError,
    raw: const {},
  );
}

class _StoreEmptyState extends StatelessWidget {
  const _StoreEmptyState({required this.message});

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

class _StoreErrorCard extends StatelessWidget {
  const _StoreErrorCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: _storeSurfaceDecoration(context),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Icon(icon, size: 42),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onAction,
              style: _storeOutlinePillButtonStyle(context),
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}

BoxDecoration _storeSurfaceDecoration(
  BuildContext context, {
  BorderRadiusGeometry? borderRadius,
  Color? borderColor,
  Color? color,
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

BoxDecoration _storeDockButtonDecoration(
  BuildContext context, {
  bool enabled = true,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  return BoxDecoration(
    gradient: enabled
        ? LinearGradient(
            colors: [
              colorScheme.primary,
              Color.lerp(colorScheme.primary, colorScheme.secondary, 0.55) ??
                  colorScheme.primary,
            ],
          )
        : null,
    color: enabled ? null : colorScheme.surfaceContainerHighest,
    borderRadius: BorderRadius.circular(999),
    boxShadow: enabled
        ? [
            BoxShadow(
              color: colorScheme.primary.withValues(alpha: 0.22),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ]
        : null,
  );
}

ButtonStyle _storeDockButtonStyle(
  BuildContext context, {
  double fontSize = 20,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  return FilledButton.styleFrom(
    backgroundColor: Colors.transparent,
    disabledBackgroundColor: Colors.transparent,
    foregroundColor: colorScheme.onPrimary,
    disabledForegroundColor: colorScheme.onSurfaceVariant,
    shadowColor: Colors.transparent,
    padding: const EdgeInsets.symmetric(horizontal: 18),
    shape: const StadiumBorder(),
    textStyle: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          height: 1.1,
        ),
  );
}

ButtonStyle _storeTextLinkButtonStyle(BuildContext context) {
  return TextButton.styleFrom(
    foregroundColor: Theme.of(context).colorScheme.primary,
    minimumSize: const Size(0, 36),
    padding: EdgeInsets.zero,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    visualDensity: VisualDensity.compact,
    textStyle: const TextStyle(fontWeight: FontWeight.w700),
  );
}

ButtonStyle _storeOutlinePillButtonStyle(
  BuildContext context, {
  bool enabled = true,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  return OutlinedButton.styleFrom(
    foregroundColor:
        enabled ? colorScheme.primary : colorScheme.onSurfaceVariant,
    disabledForegroundColor: colorScheme.onSurfaceVariant,
    minimumSize: const Size(0, 40),
    padding: const EdgeInsets.symmetric(horizontal: 14),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    visualDensity: VisualDensity.compact,
    backgroundColor:
        enabled ? colorScheme.surface : colorScheme.surfaceContainerHighest,
    shape: const StadiumBorder(),
    side: BorderSide(
      color: enabled
          ? colorScheme.primary.withValues(alpha: 0.72)
          : colorScheme.outlineVariant,
    ),
    textStyle: const TextStyle(fontWeight: FontWeight.w600),
  );
}
