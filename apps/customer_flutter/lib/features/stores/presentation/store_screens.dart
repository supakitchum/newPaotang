import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/customer_localizations.dart';
import '../../../core/utils/formatters.dart';
import '../../../features/results/data/result_repository.dart';
import '../../../shared/widgets/app_shell.dart';
import '../data/store_models.dart';
import '../data/store_repository.dart';

class StoresScreen extends ConsumerStatefulWidget {
  const StoresScreen({super.key});

  @override
  ConsumerState<StoresScreen> createState() => _StoresScreenState();
}

class _StoresScreenState extends ConsumerState<StoresScreen> {
  final _search = TextEditingController();
  final _stores = <StoreItem>[];
  String _cursor = '';
  bool _hasMore = false;
  bool _loading = true;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(reset: true));
  }

  @override
  void dispose() {
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
          padding: const EdgeInsets.all(16),
          children: [
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
        ),
      ),
    );
  }

  Future<void> _load({required bool reset}) async {
    if (_loadingMore) return;
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
  final _tickets = <StoreLotteryTicket>[];
  String _cursor = '';
  String _storeName = '';
  bool _hasMore = false;
  bool _loading = true;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _storeName = widget.storeName;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(reset: true));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final storeName =
        _storeName.isEmpty ? l10n.storesFallbackStoreName : _storeName;
    return AppShell(
      title: l10n.storesLotteriesTitle,
      currentPath: '/stores',
      child: RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  child: const Icon(Icons.storefront_outlined),
                ),
                title: Text(
                  storeName,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text(l10n.storesLotteriesSubtitle),
              ),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_tickets.isEmpty)
              _EmptyCard(
                icon: Icons.confirmation_number_outlined,
                title: l10n.storesLotteriesEmptyTitle,
                message: l10n.storesLotteriesEmptyMessage,
              )
            else
              for (final ticket in _tickets)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _LotteryTicketCard(ticket: ticket),
                ),
            if (_hasMore) ...[
              const SizedBox(height: 8),
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
        ),
      ),
    );
  }

  Future<void> _load({required bool reset}) async {
    if (_loadingMore) return;
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
      final page = await ref.read(storeRepositoryProvider).lotteries(
            storeId: widget.storeId,
            gameId: gameId,
            cursor: reset ? '' : _cursor,
          );
      if (!mounted) return;
      setState(() {
        _tickets.addAll(page.items);
        _cursor = page.nextCursor;
        _hasMore = page.hasMore;
        if (page.sellerName.isNotEmpty) _storeName = page.sellerName;
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
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.storefront_outlined)),
        title: Text(
          storeName,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: store.code.isEmpty ? null : Text(l10n.storeCode(store.code)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.go(
          Uri(
            path: '/stores/lotteries',
            queryParameters: {
              'store_id': store.id,
              'store_name': storeName,
            },
          ).toString(),
        ),
      ),
    );
  }
}

class _LotteryTicketCard extends StatelessWidget {
  const _LotteryTicketCard({required this.ticket});

  final StoreLotteryTicket ticket;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final digits = ticket.number.split('');
    final sellerName = ticket.sellerName.isEmpty
        ? l10n.storesFallbackStoreName
        : ticket.sellerName;
    return Card(
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
