import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/customer_localizations.dart';
import '../../../core/security/biometric_auth_service.dart';
import '../../../core/tenant/mobile_bootstrap_controller.dart';
import '../../../core/tenant/mobile_runtime_policy.dart';
import '../../../core/utils/api_errors.dart';
import '../../../core/utils/asset_url.dart';
import '../../../core/utils/formatters.dart';
import '../../../features/profile/data/profile_settings_models.dart';
import '../../../features/profile/data/profile_settings_repository.dart';
import '../../../shared/utils/customer_operational_error.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/async/async_state_view.dart';
import '../../../shared/widgets/customer_page_body.dart';
import '../../../shared/widgets/customer_section_header.dart';
import '../../../shared/widgets/tenant_brand_header.dart';
import '../data/ticket_models.dart';
import '../data/ticket_repository.dart';
import 'ticket_localization.dart';

class TicketsScreen extends ConsumerStatefulWidget {
  const TicketsScreen({super.key});

  @override
  ConsumerState<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends ConsumerState<TicketsScreen> {
  final _searchController = TextEditingController();
  bool _showSearch = false;
  String _activeSearch = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tickets = ref.watch(currentTicketsProvider);
    final l10n = context.l10n;

    return AppShell(
      title: l10n.ticketsTitle,
      currentPath: '/tickets',
      sensitive: true,
      actions: [
        IconButton(
          tooltip: l10n.ticketsSearchNumbers,
          onPressed: () => setState(() => _showSearch = !_showSearch),
          icon: Icon(_showSearch ? Icons.search_off : Icons.search),
        ),
        IconButton(
          tooltip: l10n.ticketsHistoryTooltip,
          onPressed: () => context.go('/tickets/history'),
          icon: const Icon(Icons.history),
        ),
      ],
      child: _TicketPageList(
        children: [
          const _TicketRouteTabs(current: _TicketRouteTab.current),
          if (_showSearch) ...[
            const SizedBox(height: 12),
            _TicketSearchForm(
              controller: _searchController,
              onSubmit: _applySearch,
              onClear: _clearSearch,
            ),
          ],
          const SizedBox(height: 12),
          tickets.when(
            loading: () => const _TicketLoadingList(),
            error: (error, _) => _TicketErrorCard(
              message: _ticketErrorMessage(error, l10n.ticketsLoadFailed),
              onRetry: () => ref.invalidate(currentTicketsProvider),
            ),
            data: (items) {
              final displayTickets = _filterTickets(items);
              final winningTicketCount = _winningTicketCount(items);

              if (items.isEmpty) return const _EmptyTicketsCard();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _CurrentTicketSummary(
                    tickets: items,
                    activeSearch: _activeSearch,
                  ),
                  if (winningTicketCount > 0) ...[
                    const SizedBox(height: 12),
                    _WinningTicketBanner(count: winningTicketCount),
                  ],
                  const SizedBox(height: 12),
                  if (displayTickets.isEmpty)
                    const _TicketSearchEmptyCard()
                  else
                    for (final ticket in displayTickets)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _TicketTile(ticket: ticket),
                      ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          const _TicketFooterNote(),
        ],
      ),
    );
  }

  List<CustomerTicket> _filterTickets(List<CustomerTicket> tickets) {
    final query = _activeSearch;
    if (query.isEmpty) return tickets;

    return tickets.where((ticket) {
      final number = ticket.number.replaceAll(RegExp(r'\D'), '');
      return number.contains(query);
    }).toList(growable: false);
  }

  int _winningTicketCount(List<CustomerTicket> tickets) {
    return tickets.fold<int>(0, (total, ticket) {
      return total + (_isWinningTicket(ticket) ? ticket.count : 0);
    });
  }

  bool _isWinningTicket(CustomerTicket ticket) => _ticketIsWinning(ticket);

  void _applySearch() {
    final query = _sanitizeSearch(_searchController.text);
    setState(() {
      _searchController.text = query;
      _searchController.selection = TextSelection.collapsed(
        offset: _searchController.text.length,
      );
      _activeSearch = query;
    });
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _activeSearch = '';
    });
  }

  String _sanitizeSearch(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    return digits.length <= 6 ? digits : digits.substring(0, 6);
  }
}

class _TicketSearchForm extends StatelessWidget {
  const _TicketSearchForm({
    required this.controller,
    required this.onSubmit,
    required this.onClear,
  });

  final TextEditingController controller;
  final VoidCallback onSubmit;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Icon(
              Icons.search,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                key: const ValueKey('ticket-search-input'),
                controller: controller,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  counterText: '',
                  hintText: l10n.ticketsSearchPlaceholder,
                ),
                onSubmitted: (_) => onSubmit(),
              ),
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) {
                if (value.text.isEmpty) return const SizedBox.shrink();
                return IconButton(
                  key: const ValueKey('ticket-search-clear'),
                  tooltip: l10n.ticketsSearchClear,
                  onPressed: onClear,
                  icon: const Icon(Icons.close),
                );
              },
            ),
            FilledButton(
              key: const ValueKey('ticket-search-submit'),
              onPressed: onSubmit,
              child: Text(l10n.ticketsSearchSubmit),
            ),
          ],
        ),
      ),
    );
  }
}

class _CurrentTicketSummary extends StatelessWidget {
  const _CurrentTicketSummary({
    required this.tickets,
    required this.activeSearch,
  });

  final List<CustomerTicket> tickets;
  final String activeSearch;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final drawDate = _drawDate(l10n);
    final totalTicketCount = tickets.fold<int>(
      0,
      (total, ticket) => total + ticket.count,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.ticketsDrawDateLabel,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 3),
        Text(
          drawDate,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 3),
        Text(
          l10n.ticketsTotalCount(totalTicketCount),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
              ),
        ),
        if (activeSearch.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            l10n.ticketsSearchResult(activeSearch),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ],
    );
  }

  String _drawDate(CustomerLocalizations l10n) {
    for (final ticket in tickets) {
      final drawDate = ticketDrawDateText(l10n, ticket);
      if (drawDate != '-') return drawDate;
    }
    return '-';
  }
}

class _WinningTicketBanner extends StatelessWidget {
  const _WinningTicketBanner({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.tertiaryContainer.withValues(alpha: 0.92),
            colorScheme.secondaryContainer.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.ticketsWinningBannerTitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: colorScheme.onTertiaryContainer,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.ticketsWinningBannerMessage(count),
                    style: TextStyle(
                      color: colorScheme.onTertiaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            CircleAvatar(
              backgroundColor: Colors.white.withValues(alpha: 0.6),
              foregroundColor: colorScheme.tertiary,
              child: const Icon(Icons.monetization_on_outlined),
            ),
          ],
        ),
      ),
    );
  }
}

class _TicketSearchEmptyCard extends StatelessWidget {
  const _TicketSearchEmptyCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.search_off)),
        title: Text(context.l10n.ticketsSearchEmptyTitle),
        subtitle: Text(context.l10n.ticketsSearchEmptySubtitle),
      ),
    );
  }
}

enum _TicketRouteTab { current, history }

class _TicketRouteTabs extends StatelessWidget {
  const _TicketRouteTabs({required this.current});

  final _TicketRouteTab current;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SegmentedButton<_TicketRouteTab>(
      segments: [
        ButtonSegment(
          value: _TicketRouteTab.current,
          icon: const Icon(Icons.confirmation_number_outlined),
          label: Text(l10n.ticketsTabCurrent),
        ),
        ButtonSegment(
          value: _TicketRouteTab.history,
          icon: const Icon(Icons.history),
          label: Text(l10n.ticketsTabHistory),
        ),
      ],
      selected: {current},
      onSelectionChanged: (selection) {
        if (selection.isEmpty) return;
        final value = selection.first;
        if (value == current) return;
        context.go(
          value == _TicketRouteTab.history ? '/tickets/history' : '/tickets',
        );
      },
    );
  }
}

class _TicketHistoryFilterHeader extends StatelessWidget {
  const _TicketHistoryFilterHeader({
    required this.showOnlyWinning,
    required this.onToggle,
  });

  final bool showOnlyWinning;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return CustomerSectionHeader(
      title: l10n.ticketHistoryListTitle,
      action: TextButton.icon(
        onPressed: onToggle,
        icon: Icon(showOnlyWinning ? Icons.list_alt : Icons.playlist_add_check),
        label: Text(
          showOnlyWinning
              ? l10n.ticketHistoryShowAll
              : l10n.ticketHistoryShowWinning,
        ),
      ),
    );
  }
}

class _TicketPageList extends StatelessWidget {
  const _TicketPageList({
    required this.children,
    this.maxWidth = 760,
    this.top = 16,
    this.controller,
    this.physics,
  });

  final List<Widget> children;
  final double maxWidth;
  final double top;
  final ScrollController? controller;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: controller,
      physics: physics,
      children: [
        CustomerPageBody(
          maxWidth: maxWidth,
          top: top,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ],
    );
  }
}

class _EmptyTicketsCard extends StatelessWidget {
  const _EmptyTicketsCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(
          child: Icon(Icons.confirmation_number_outlined),
        ),
        title: Text(context.l10n.ticketsEmptyTitle),
        subtitle: Text(context.l10n.ticketsEmptySubtitle),
      ),
    );
  }
}

class _TicketFooterNote extends StatelessWidget {
  const _TicketFooterNote();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Text(
        context.l10n.ticketsFooterNote,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _TicketTile extends StatelessWidget {
  const _TicketTile({required this.ticket, this.fromHistory = false});

  final CustomerTicket ticket;
  final bool fromHistory;

  @override
  Widget build(BuildContext context) {
    final statusColor = _ticketStatusColor(context, ticket);
    final l10n = context.l10n;
    final drawDate = ticketDrawDateText(l10n, ticket);
    final number = ticket.number.isEmpty
        ? context.l10n.ticketsNumberFallback
        : ticket.number;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: ticket.id.isEmpty
            ? null
            : () => context.go(
                  '/tickets/view?id=${ticket.id}'
                  '${fromHistory ? '&from=history' : ''}',
                ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withValues(alpha: 0.72),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              child: FittedBox(
                                alignment: Alignment.centerLeft,
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  number,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 3,
                                      ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _TicketStatusPill(
                          label: ticketStatusLabel(l10n, ticket),
                          color: statusColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (ticket.gameName.trim().isNotEmpty)
                          _TicketMetaChip(
                            icon: Icons.event_outlined,
                            label: ticket.gameName.trim(),
                          ),
                        if (drawDate != '-')
                          _TicketMetaChip(
                            icon: Icons.schedule_outlined,
                            label: drawDate,
                          ),
                        _TicketMetaChip(
                          icon: Icons.confirmation_number_outlined,
                          label: l10n.ticketsCount(ticket.count),
                        ),
                      ],
                    ),
                    if (ticket.prizeAmount > 0) ...[
                      const SizedBox(height: 12),
                      Text(
                        formatBaht(ticket.prizeAmount),
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: statusColor,
                                  fontWeight: FontWeight.w900,
                                ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TicketMetaChip extends StatelessWidget {
  const _TicketMetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TicketHistoryScreen extends ConsumerStatefulWidget {
  const TicketHistoryScreen({super.key});

  @override
  ConsumerState<TicketHistoryScreen> createState() =>
      _TicketHistoryScreenState();
}

class _TicketHistoryScreenState extends ConsumerState<TicketHistoryScreen> {
  final _scrollController = ScrollController();
  final _tickets = <CustomerTicket>[];
  String? _cursor;
  bool _hasMore = false;
  bool _loadingInitial = true;
  bool _loadingMore = false;
  bool _showOnlyWinning = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_maybeLoadMoreFromScroll);
    Future.microtask(_loadInitial);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_maybeLoadMoreFromScroll)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final visibleTickets = _showOnlyWinning
        ? _tickets.where(_ticketIsWinning).toList(growable: false)
        : List<CustomerTicket>.unmodifiable(_tickets);
    final visibleTicketGroups = _groupTicketsByDraw(visibleTickets, l10n);
    final winningTicketCount = _winningTicketCount(_tickets);

    return AppShell(
      title: l10n.ticketHistoryTitle,
      currentPath: '/tickets',
      sensitive: true,
      actions: [
        IconButton(
          tooltip: l10n.ticketCurrentTooltip,
          onPressed: () => context.go('/tickets'),
          icon: const Icon(Icons.confirmation_number_outlined),
        ),
      ],
      child: RefreshIndicator(
        onRefresh: _loadInitial,
        child: _TicketPageList(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const _TicketRouteTabs(current: _TicketRouteTab.history),
            const SizedBox(height: 12),
            if (_loadingInitial)
              const _TicketLoadingList()
            else if (_error.isNotEmpty)
              _TicketErrorCard(
                message: _error,
                onRetry: _loadInitial,
              )
            else if (_tickets.isEmpty)
              const _TicketEmptyHistoryCard()
            else ...[
              _TicketHistoryFilterHeader(
                showOnlyWinning: _showOnlyWinning,
                onToggle: () => setState(
                  () => _showOnlyWinning = !_showOnlyWinning,
                ),
              ),
              if (winningTicketCount > 0) ...[
                const SizedBox(height: 12),
                _WinningTicketBanner(count: winningTicketCount),
              ],
              const SizedBox(height: 12),
              if (visibleTickets.isEmpty)
                const _TicketHistoryWinningEmptyCard()
              else
                for (final group in visibleTicketGroups)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _TicketHistoryDrawGroup(group: group),
                  ),
              if (_hasMore)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: _loadingMore ? null : _loadMore,
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
      ),
    );
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loadingInitial = true;
      _error = '';
    });
    try {
      final page = await ref.read(ticketRepositoryProvider).history();
      if (!mounted) return;
      setState(() {
        _tickets
          ..clear()
          ..addAll(page.items);
        _cursor = page.nextCursor;
        _hasMore = page.hasMore;
        _showOnlyWinning = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _error = _ticketErrorMessage(
          error,
          context.l10n.ticketHistoryLoadFailed,
        ),
      );
    } finally {
      if (mounted) setState(() => _loadingInitial = false);
    }
  }

  Future<void> _loadMore() async {
    final cursor = _cursor;
    if (cursor == null || cursor.isEmpty || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final page = await ref.read(ticketRepositoryProvider).history(
            cursor: cursor,
          );
      if (!mounted) return;
      setState(() {
        _tickets.addAll(page.items);
        _cursor = page.nextCursor;
        _hasMore = page.hasMore;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _ticketErrorMessage(
              error,
              context.l10n.ticketHistoryLoadMoreFailed,
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _maybeLoadMoreFromScroll() {
    if (_loadingInitial || _loadingMore || !_hasMore) return;
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    if (!position.hasPixels || !position.hasContentDimensions) return;
    if (position.extentAfter <= 360) {
      _loadMore();
    }
  }
}

class _TicketHistoryDrawGroupData {
  const _TicketHistoryDrawGroupData({
    required this.key,
    required this.drawDate,
    required this.tickets,
  });

  final String key;
  final String drawDate;
  final List<CustomerTicket> tickets;
}

List<_TicketHistoryDrawGroupData> _groupTicketsByDraw(
  List<CustomerTicket> tickets,
  CustomerLocalizations l10n,
) {
  final groups = <_TicketHistoryDrawGroupData>[];
  final indexes = <String, int>{};

  for (final ticket in tickets) {
    final drawDate = ticketDrawDateText(l10n, ticket);
    final key = ticket.gameId.trim().isNotEmpty
        ? ticket.gameId.trim()
        : '${drawDate}_${groups.length}';
    final index = indexes[key];

    if (index == null) {
      indexes[key] = groups.length;
      groups.add(
        _TicketHistoryDrawGroupData(
          key: key,
          drawDate: drawDate,
          tickets: [ticket],
        ),
      );
      continue;
    }

    final group = groups[index];
    groups[index] = _TicketHistoryDrawGroupData(
      key: group.key,
      drawDate: group.drawDate,
      tickets: [...group.tickets, ticket],
    );
  }

  return groups;
}

class _TicketHistoryDrawGroup extends StatelessWidget {
  const _TicketHistoryDrawGroup({required this.group});

  final _TicketHistoryDrawGroupData group;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      key: ValueKey('ticket-history-group-${group.key}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
          child: Row(
            children: [
              Text(
                l10n.ticketLabelLotteryDrawDate,
                style: textTheme.labelLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  group.drawDate,
                  key: ValueKey('ticket-history-group-date-${group.key}'),
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
        for (final ticket in group.tickets)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _TicketTile(
              ticket: ticket,
              fromHistory: true,
            ),
          ),
      ],
    );
  }
}

int _winningTicketCount(List<CustomerTicket> tickets) {
  return tickets.fold<int>(0, (total, ticket) {
    return total + (_ticketIsWinning(ticket) ? ticket.count : 0);
  });
}

bool _ticketIsWinning(CustomerTicket ticket) {
  final status = ticket.rewardStatus.status;
  final claimStatus = ticket.rewardStatus.claimStatus;
  return ticket.prizeAmount > 0 ||
      ticket.claimable ||
      ticket.hasExistingClaim ||
      const {
        'winning',
        'approved',
        'claim_approved',
        'submitted',
        'claim_submitted',
        'under_review',
        'paid',
        'paid_out',
        'rejected',
        'cancelled',
      }.contains(status) ||
      const {
        'approved',
        'claim_approved',
        'submitted',
        'claim_submitted',
        'under_review',
        'paid',
        'paid_out',
        'rejected',
        'cancelled',
      }.contains(claimStatus);
}

final _ticketViewLookupProvider =
    FutureProvider.autoDispose.family<CustomerTicket?, _TicketViewLookup>((
  ref,
  lookup,
) async {
  final repository = ref.watch(ticketRepositoryProvider);
  if (lookup.ticketId.isNotEmpty) {
    return repository.detail(lookup.ticketId);
  }

  final tickets = <CustomerTicket>[];
  if (lookup.fromHistory) {
    String? cursor;
    for (var pageNumber = 0;
        pageNumber < TicketRepository.maxAutoPages;
        pageNumber++) {
      final page = await repository.history(
        limit: TicketRepository.defaultPageLimit,
        cursor: cursor,
        gameId: lookup.gameId,
      );
      tickets.addAll(page.items);

      final nextCursor = page.nextCursor?.trim() ?? '';
      if (!page.hasMore || nextCursor.isEmpty || nextCursor == cursor) {
        break;
      }
      cursor = nextCursor;
    }
  } else {
    tickets.addAll(await repository.currentAll());
  }

  return _findTicketForLookup(tickets, lookup);
});

class _TicketViewLookup {
  const _TicketViewLookup({
    required this.ticketId,
    required this.ticketNumber,
    required this.orderId,
    required this.gameId,
    required this.fromHistory,
  });

  final String ticketId;
  final String ticketNumber;
  final String orderId;
  final String gameId;
  final bool fromHistory;

  @override
  bool operator ==(Object other) {
    return other is _TicketViewLookup &&
        other.ticketId == ticketId &&
        other.ticketNumber == ticketNumber &&
        other.orderId == orderId &&
        other.gameId == gameId &&
        other.fromHistory == fromHistory;
  }

  @override
  int get hashCode => Object.hash(
        ticketId,
        ticketNumber,
        orderId,
        gameId,
        fromHistory,
      );
}

CustomerTicket? _findTicketForLookup(
  List<CustomerTicket> tickets,
  _TicketViewLookup lookup,
) {
  if (tickets.isEmpty) return null;

  final requestedNumber = lookup.ticketNumber.trim();
  final requestedOrderId = lookup.orderId.trim();
  final requestedGameId = lookup.gameId.trim();

  if (requestedNumber.isEmpty &&
      requestedOrderId.isEmpty &&
      requestedGameId.isEmpty) {
    return tickets.first;
  }

  for (final ticket in tickets) {
    final sameNumber =
        requestedNumber.isEmpty || ticket.number == requestedNumber;
    final sameOrder =
        requestedOrderId.isEmpty || ticket.orderId == requestedOrderId;
    final sameGame =
        requestedGameId.isEmpty || ticket.gameId == requestedGameId;
    if (sameNumber && sameOrder && sameGame) return ticket;
  }

  return null;
}

class TicketViewScreen extends ConsumerWidget {
  const TicketViewScreen({
    required this.ticketId,
    required this.ticketNumber,
    required this.orderId,
    required this.gameId,
    required this.fromHistory,
    super.key,
  });

  final String ticketId;
  final String ticketNumber;
  final String orderId;
  final String gameId;
  final bool fromHistory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticket = ref.watch(
      _ticketViewLookupProvider(
        _TicketViewLookup(
          ticketId: ticketId,
          ticketNumber: ticketNumber,
          orderId: orderId,
          gameId: gameId,
          fromHistory: fromHistory,
        ),
      ),
    );
    final backPath = fromHistory ? '/tickets/history' : '/tickets';

    return AppShell(
      title: context.l10n.ticketDetailTitle,
      currentPath: '/tickets',
      sensitive: true,
      actions: [
        IconButton(
          tooltip: context.l10n.commonBack,
          onPressed: () => context.go(backPath),
          icon: const Icon(Icons.close),
        ),
      ],
      child: AsyncStateView(
        value: ticket,
        data: (item) {
          if (item == null) {
            return _TicketErrorCard(message: context.l10n.ticketsNotFound);
          }
          return _TicketDetailContent(
            ticket: item,
            fromHistory: fromHistory,
          );
        },
        empty: _TicketErrorCard(message: context.l10n.ticketsNotFound),
      ),
    );
  }
}

class _TicketDetailContent extends ConsumerWidget {
  const _TicketDetailContent({
    required this.ticket,
    required this.fromHistory,
  });

  final CustomerTicket ticket;
  final bool fromHistory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusColor = _ticketStatusColor(context, ticket);
    final l10n = context.l10n;

    return _TicketPageList(
      children: [
        _TicketImageCard(ticket: ticket),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        ticket.number.isEmpty
                            ? l10n.ticketLabelLotteryNumber
                            : ticket.number,
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 3,
                                ),
                      ),
                    ),
                    _TicketStatusPill(
                      label: ticketStatusLabel(l10n, ticket),
                      color: statusColor,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _TicketInfoRow(
                  label: l10n.ticketLabelDraw,
                  value: ticket.gameName,
                ),
                _TicketInfoRow(
                  label: l10n.ticketLabelDrawDate,
                  value: ticketDrawDateText(l10n, ticket),
                ),
                _TicketInfoRow(
                  label: l10n.ticketLabelCount,
                  value: l10n.ticketsCount(ticket.count),
                ),
                if (ticket.prizeAmount > 0)
                  _TicketInfoRow(
                    label: l10n.ticketLabelPrizeAmount,
                    value: formatBaht(ticket.prizeAmount),
                    emphasize: true,
                  ),
                if (ticket.prizes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final prize in ticket.prizes)
                        Chip(
                          label: Text(
                            '${ticketPrizeTypeLabel(l10n, prize.prizeType)} '
                            '${formatBaht(prize.amount)}',
                          ),
                        ),
                    ],
                  ),
                ],
                if (ticket.rewardStatus.adminNote.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    ticket.rewardStatus.adminNote,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (ticket.hasExistingClaim && !ticket.canCreateClaim)
          FilledButton.icon(
            onPressed: () =>
                context.go('/reward-claims/${ticket.rewardClaimId}'),
            icon: const Icon(Icons.receipt_long),
            label: Text(l10n.ticketClaimViewClaim),
          )
        else if (ticket.canCreateClaim)
          FilledButton.icon(
            onPressed: () => context.go(
              '/tickets/claim/${ticket.id}'
              '?from=${fromHistory ? 'history' : 'current'}',
            ),
            icon: const Icon(Icons.account_balance_wallet_outlined),
            label: Text(l10n.ticketClaimStart),
          )
        else
          OutlinedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.info_outline),
            label: Text(ticketStatusLabel(l10n, ticket)),
          ),
      ],
    );
  }
}

class TicketClaimScreen extends ConsumerStatefulWidget {
  const TicketClaimScreen({
    required this.ticketId,
    required this.fromHistory,
    super.key,
  });

  final String ticketId;
  final bool fromHistory;

  @override
  ConsumerState<TicketClaimScreen> createState() => _TicketClaimScreenState();
}

class _TicketClaimScreenState extends ConsumerState<TicketClaimScreen> {
  CustomerTicket? _ticket;
  CustomerProfileSettings? _profile;
  RewardClaimSubmission? _submittedClaim;
  String _payoutMethod = 'wallet_credit';
  String _pin = '';
  String _error = '';
  String _pinError = '';
  bool _loading = true;
  bool _submitting = false;
  _ClaimStep _step = _ClaimStep.select;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  Widget build(BuildContext context) {
    final backPath = widget.fromHistory ? '/tickets/history' : '/tickets';
    final l10n = context.l10n;
    return AppShell(
      title: _step == _ClaimStep.pin
          ? l10n.ticketClaimPinTitle
          : l10n.ticketClaimTitle,
      currentPath: '/tickets',
      sensitive: true,
      actions: [
        IconButton(
          tooltip: l10n.commonBack,
          onPressed: () {
            if (_step == _ClaimStep.confirm) {
              setState(() => _step = _ClaimStep.select);
              return;
            }
            if (_step == _ClaimStep.pin) {
              setState(() {
                _step = _ClaimStep.confirm;
                _pin = '';
                _pinError = '';
              });
              return;
            }
            context.go(backPath);
          },
          icon: const Icon(Icons.close),
        ),
      ],
      child: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const _TicketPageList(
        children: [_TicketClaimLoadingState()],
      );
    }
    if (_error.isNotEmpty) {
      return _TicketPageList(
        children: [_TicketErrorCard(message: _error, onRetry: _load)],
      );
    }

    final ticket = _ticket;
    if (ticket == null) {
      return Center(child: Text(context.l10n.ticketsNotFound));
    }
    if (ticket.hasExistingClaim && !ticket.canCreateClaim) {
      return _TicketPageList(
        children: [
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.receipt_long)),
              title: Text(context.l10n.ticketClaimAlreadyTitle),
              subtitle: Text(context.l10n.ticketClaimAlreadySubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/reward-claims/${ticket.rewardClaimId}'),
            ),
          ),
        ],
      );
    }

    final platformKey = ref.watch(customerPlatformKeyProvider);
    final biometricEnabled = ref.watch(mobileBootstrapProvider).maybeWhen(
          data: (data) => mobileBiometricAllowedForPlatform(data, platformKey),
          orElse: () => false,
        );

    return switch (_step) {
      _ClaimStep.select => _ClaimSelectStep(
          ticket: ticket,
          profile: _profile,
          payoutMethod: _payoutMethod,
          onMethodChanged: (value) => setState(() => _payoutMethod = value),
          onNext: _canContinue
              ? () => setState(() => _step = _ClaimStep.confirm)
              : null,
        ),
      _ClaimStep.confirm => _ClaimConfirmStep(
          ticket: ticket,
          profile: _profile,
          payoutMethod: _payoutMethod,
          submitting: _submitting,
          onBack: () => setState(() => _step = _ClaimStep.select),
          onConfirm: _canContinue
              ? () => setState(() {
                    _step = _ClaimStep.pin;
                    _pin = '';
                    _pinError = '';
                  })
              : null,
        ),
      _ClaimStep.pin => _ClaimPinStep(
          pin: _pin,
          error: _pinError,
          submitting: _submitting,
          biometricEnabled: biometricEnabled,
          onDigit: _appendPinDigit,
          onBackspace: _removePinDigit,
          onBiometric: _submitClaimWithBiometric,
        ),
      _ClaimStep.processing => _ClaimProcessingStep(
          ticket: ticket,
          profile: _profile,
          payoutMethod: _payoutMethod,
          submittedClaim: _submittedClaim,
        ),
    };
  }

  bool get _hasBankAccount => _profile?.bankAccount.isComplete ?? false;

  bool get _canContinue {
    final ticket = _ticket;
    if (ticket == null || _submitting || !ticket.canCreateClaim) return false;
    if (_payoutMethod == 'bank_transfer' && !_hasBankAccount) return false;
    return true;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final ticket =
          await ref.read(ticketRepositoryProvider).detail(widget.ticketId);
      TicketRewardStatus? rewardStatus;
      try {
        rewardStatus = await ref
            .read(ticketRepositoryProvider)
            .rewardStatus(widget.ticketId);
      } catch (_) {
        rewardStatus = null;
      }
      CustomerProfileSettings? profile;
      try {
        profile = await ref.read(profileSettingsRepositoryProvider).load();
      } catch (_) {
        profile = null;
      }
      if (!mounted) return;
      setState(() {
        _ticket = rewardStatus == null
            ? ticket
            : CustomerTicket.fromJson({
                'id': ticket.id,
                'game_id': ticket.gameId,
                'game': {
                  'id': ticket.gameId,
                  'name': ticket.gameName,
                  'draw_at': ticket.drawAt,
                },
                'draw_no': ticket.drawNumber,
                'set': ticket.setNumber,
                'full_number': ticket.number,
                'status': ticket.status,
                'reward_status': {
                  'status': rewardStatus.status,
                  'claim_status': rewardStatus.claimStatus,
                  'claimable': rewardStatus.claimable,
                  'prize_type': rewardStatus.prizeType,
                  'prize_number': rewardStatus.prizeNumber,
                  'prize_amount': {
                    'amount': (rewardStatus.prizeAmount * 100).round(),
                  },
                  'prizes': rewardStatus.prizes
                      .map(
                        (prize) => {
                          'prize_type': prize.prizeType,
                          'prize_number': prize.prizeNumber,
                          'amount': {
                            'amount': (prize.amount * 100).round(),
                          },
                        },
                      )
                      .toList(growable: false),
                  'reward_claim_id': rewardStatus.rewardClaimId,
                  'payout_method': rewardStatus.payoutMethod,
                  'admin_note': rewardStatus.adminNote,
                },
                'image_url': ticket.imageUrl,
                'image_thumb_url': ticket.imageThumbUrl,
                'preview_image_url': ticket.previewImageUrl,
                'image_status': ticket.imageStatus,
                'image_error': ticket.imageError,
              });
        _profile = profile;
        if (profile?.bankAccount.isComplete ?? false) {
          _payoutMethod = 'bank_transfer';
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _error = _ticketErrorMessage(
          error,
          context.l10n.ticketClaimLoadFailed,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _appendPinDigit(String digit) {
    if (_pin.length >= 6 || _submitting) return;
    setState(() {
      _pin += digit;
      _pinError = '';
    });
    if (_pin.length == 6) _submitClaim();
  }

  void _removePinDigit() {
    if (_pin.isEmpty || _submitting) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _pinError = '';
    });
  }

  Future<void> _submitClaim({String pinAssertionToken = ''}) async {
    final ticket = _ticket;
    if (ticket == null || !_canContinue || _submitting) return;
    setState(() => _submitting = true);
    try {
      final claim = await ref.read(ticketRepositoryProvider).createRewardClaim(
            ticketId: ticket.id,
            payoutMethod: _payoutMethod,
            pin: pinAssertionToken.isEmpty ? _pin : '',
            pinAssertionToken: pinAssertionToken,
            bankAccount: _payoutMethod == 'bank_transfer'
                ? _profile?.bankAccount.toJson()
                : null,
          );
      if (!mounted) return;
      setState(() {
        _submittedClaim = claim;
        _step = _ClaimStep.processing;
      });
    } catch (error) {
      if (!mounted) return;
      final pinError = _claimErrorText(error);
      final failedMessage = context.l10n.ticketClaimSubmitFailed;
      if (await handleCustomerOperationalError(
        ref: ref,
        context: context,
        error: error,
        handlePinRedirect: false,
      )) {
        return;
      }
      if (!mounted) return;
      setState(() {
        _pin = '';
        _pinError = pinError;
      });
      if (_pinError.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_ticketErrorMessage(error, failedMessage))),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _submitClaimWithBiometric() async {
    if (_submitting) return;
    setState(() {
      _pin = '';
      _pinError = '';
    });
    try {
      final token =
          await ref.read(biometricAuthServiceProvider).requestPinAssertion(
                purpose: 'reward_claim',
                localizedReason: context.l10n.pinBiometricReason,
              );
      if (!mounted) return;
      if (token == null || token.isEmpty) {
        setState(
          () => _pinError = context.l10n.ticketClaimBiometricUnavailable,
        );
        return;
      }
      await _submitClaim(pinAssertionToken: token);
    } catch (error) {
      if (!mounted) return;
      if (await handleCustomerOperationalError(
        ref: ref,
        context: context,
        error: error,
        handlePinRedirect: false,
      )) {
        return;
      }
      setState(() => _pinError = context.l10n.ticketClaimBiometricFailed);
    }
  }

  String _claimErrorText(Object error) {
    final code = _errorCode(error);
    final l10n = context.l10n;
    if (code == 'pin_invalid') {
      return l10n.ticketClaimPinInvalid;
    }
    if (code == 'pin_locked') {
      return l10n.ticketClaimPinLocked;
    }
    if (code == 'pin_setup_required' || code == 'pin_required') {
      return l10n.ticketClaimPinSetupRequired;
    }
    if (code == 'pin_assertion_invalid') {
      return l10n.ticketClaimPinAssertionInvalid;
    }
    if (code == 'resource_conflict') {
      return l10n.ticketClaimConflict;
    }
    return '';
  }

  String _errorCode(Object error) {
    return ApiErrorInfo.fromObject(error).code;
  }
}

class _TicketClaimLoadingState extends StatelessWidget {
  const _TicketClaimLoadingState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
      child: Text(
        context.l10n.ticketClaimLoading,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _ClaimSelectStep extends StatelessWidget {
  const _ClaimSelectStep({
    required this.ticket,
    required this.profile,
    required this.payoutMethod,
    required this.onMethodChanged,
    required this.onNext,
  });

  final CustomerTicket ticket;
  final CustomerProfileSettings? profile;
  final String payoutMethod;
  final ValueChanged<String> onMethodChanged;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final bank = profile?.bankAccount;
    final l10n = context.l10n;
    return _TicketPageList(
      children: [
        _ClaimTicketSummary(ticket: ticket),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.ticketClaimPayoutMethodTitle,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                if (!ticket.canCreateClaim) ...[
                  const SizedBox(height: 12),
                  _ClaimUnavailableAlert(
                    message: _ticketClaimUnavailableMessage(l10n, ticket),
                  ),
                ],
                const SizedBox(height: 12),
                _PayoutOption(
                  selected: payoutMethod == 'wallet_credit',
                  enabled: ticket.canCreateClaim,
                  icon: Icons.account_balance_wallet_outlined,
                  title: l10n.ticketClaimWalletTitle,
                  subtitle: l10n.ticketClaimWalletSubtitle,
                  onTap: () => onMethodChanged('wallet_credit'),
                ),
                const SizedBox(height: 8),
                _PayoutOption(
                  selected: payoutMethod == 'bank_transfer',
                  enabled: ticket.canCreateClaim && (bank?.isComplete ?? false),
                  icon: Icons.account_balance_outlined,
                  title: bank?.isComplete ?? false
                      ? '${bank!.bankName} ${bank.maskedNumber}'
                      : l10n.ticketClaimBankTitle,
                  subtitle: bank?.isComplete ?? false
                      ? l10n.ticketClaimBankSubtitleReady
                      : l10n.ticketClaimBankSubtitleMissing,
                  onTap: () => onMethodChanged('bank_transfer'),
                ),
                if (!(bank?.isComplete ?? false)) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => context.go(
                      '/profile/reward-bank?redirect=/tickets/claim/${ticket.id}',
                    ),
                    icon: const Icon(Icons.add),
                    label: Text(l10n.ticketClaimAddBank),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: onNext,
          child: Text(l10n.commonNext),
        ),
      ],
    );
  }
}

String _ticketClaimUnavailableMessage(
  CustomerLocalizations l10n,
  CustomerTicket ticket,
) {
  final rewardStatus = ticket.rewardStatus.status.trim().toLowerCase();
  if (rewardStatus == 'pending_result') {
    return l10n.ticketClaimUnavailablePendingResult;
  }
  if (rewardStatus == 'non_winning') {
    return l10n.ticketClaimUnavailableNonWinning;
  }
  if (rewardStatus == 'winning') {
    return l10n.ticketClaimUnavailableWinningNotOpen;
  }
  return l10n.ticketClaimUnavailableDefault;
}

String _ticketPrizeLinesWithAmounts(
  CustomerLocalizations l10n,
  CustomerTicket ticket,
) {
  if (ticket.prizes.isNotEmpty) {
    return ticket.prizes
        .map(
          (prize) => '${ticketPrizeTypeLabel(l10n, prize.prizeType)} '
              '${formatBaht(prize.amount)}',
        )
        .join('\n');
  }

  final summary = ticketPrizeSummary(l10n, ticket);
  if (ticket.prizeAmount > 0) {
    return '$summary ${formatBaht(ticket.prizeAmount)}';
  }
  return summary;
}

class _ClaimUnavailableAlert extends StatelessWidget {
  const _ClaimUnavailableAlert({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.secondary.withValues(alpha: 0.22),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: colorScheme.secondary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClaimConfirmStep extends StatelessWidget {
  const _ClaimConfirmStep({
    required this.ticket,
    required this.profile,
    required this.payoutMethod,
    required this.submitting,
    required this.onBack,
    required this.onConfirm,
  });

  final CustomerTicket ticket;
  final CustomerProfileSettings? profile;
  final String payoutMethod;
  final bool submitting;
  final VoidCallback onBack;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final taxAmount = ticket.prizeAmount * 0.005;
    final feeAmount = ticket.prizeAmount * 0.01;
    return _TicketPageList(
      children: [
        _ClaimTicketSummary(ticket: ticket),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _TicketInfoRow(
                  label: l10n.ticketLabelRecipient,
                  value: profile?.name ?? '-',
                ),
                _TicketInfoRow(
                  label: l10n.ticketLabelPayoutChannel,
                  value: _payoutLabel(l10n, profile, payoutMethod),
                ),
                _TicketInfoRow(
                  label: l10n.ticketLabelLotteryNumber,
                  value: ticket.number,
                ),
                _TicketInfoRow(
                  label: l10n.ticketLabelPrizeAmount,
                  value: formatBaht(ticket.prizeAmount),
                  emphasize: true,
                ),
                _TicketInfoRow(
                  label: l10n.rewardClaimTaxLabel,
                  value: l10n.rewardClaimZeroBaht,
                  helper: l10n.rewardClaimWaived(formatBaht(taxAmount)),
                  positive: true,
                ),
                _TicketInfoRow(
                  label: l10n.rewardClaimFeeLabel,
                  value: l10n.rewardClaimZeroBaht,
                  helper: l10n.rewardClaimWaived(formatBaht(feeAmount)),
                  positive: true,
                ),
                const Divider(height: 28),
                _TicketInfoRow(
                  label: l10n.ticketLabelNetAmount,
                  value: formatBaht(ticket.prizeAmount),
                  emphasize: true,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: submitting ? null : onBack,
                child: Text(l10n.commonBack),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: submitting ? null : onConfirm,
                child: Text(l10n.commonConfirm),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ClaimPinStep extends StatelessWidget {
  const _ClaimPinStep({
    required this.pin,
    required this.error,
    required this.submitting,
    required this.biometricEnabled,
    required this.onDigit,
    required this.onBackspace,
    required this.onBiometric,
  });

  final String pin;
  final String error;
  final bool submitting;
  final bool biometricEnabled;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onBiometric;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', 'back'];
    return _TicketPageList(
      maxWidth: 420,
      top: 24,
      children: [
        const SizedBox(height: 24),
        Icon(
          Icons.lock_outline,
          size: 52,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          l10n.ticketClaimEnterPin,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          '${'●' * pin.length}${'○' * (6 - pin.length)}',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        if (error.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            error,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        if (submitting) ...[
          const SizedBox(height: 12),
          const Center(child: CircularProgressIndicator()),
        ],
        const SizedBox(height: 24),
        if (biometricEnabled) ...[
          OutlinedButton.icon(
            onPressed: submitting ? null : onBiometric,
            icon: const Icon(Icons.face_retouching_natural),
            label: Text(l10n.pinUseBiometric),
          ),
          const SizedBox(height: 12),
        ],
        GridView.count(
          shrinkWrap: true,
          crossAxisCount: 3,
          childAspectRatio: 1.55,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final key in keys)
              if (key.isEmpty)
                const SizedBox.shrink()
              else
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: FilledButton.tonal(
                    onPressed: submitting
                        ? null
                        : key == 'back'
                            ? onBackspace
                            : () => onDigit(key),
                    child: key == 'back'
                        ? const Icon(Icons.backspace_outlined)
                        : Text(
                            key,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                  ),
                ),
          ],
        ),
      ],
    );
  }
}

class _ClaimProcessingStep extends ConsumerWidget {
  const _ClaimProcessingStep({
    required this.ticket,
    required this.profile,
    required this.payoutMethod,
    required this.submittedClaim,
  });

  final CustomerTicket ticket;
  final CustomerProfileSettings? profile;
  final String payoutMethod;
  final RewardClaimSubmission? submittedClaim;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final bootstrap = ref.watch(mobileBootstrapProvider).valueOrNull;
    final productMarker = bootstrap?.lotteryProductLabel.trim() ?? '';
    final taxAmount = ticket.prizeAmount * 0.005;
    final feeAmount = ticket.prizeAmount * 0.01;
    final drawNumber = ticket.displayDrawNumber;
    final setNumber = ticket.displaySetNumber;
    return _TicketPageList(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _ClaimProcessingBrandHeader(productMarker: productMarker),
                const SizedBox(height: 16),
                Icon(
                  Icons.schedule,
                  size: 56,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.ticketClaimProcessingTitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.ticketClaimProcessingSubtitle,
                  textAlign: TextAlign.center,
                ),
                const Divider(height: 28),
                _TicketInfoRow(
                  label: l10n.ticketLabelRecipient,
                  value: profile?.name ?? '-',
                ),
                _TicketInfoRow(
                  label: l10n.ticketLabelPayoutChannel,
                  value: _payoutLabel(l10n, profile, payoutMethod),
                ),
                _TicketInfoRow(
                  label: l10n.rewardClaimMethodLabel,
                  value: l10n.rewardClaimManualMethod,
                  emphasize: true,
                ),
                _TicketInfoRow(
                  label: l10n.ticketLabelLotteryDrawDate,
                  value: ticketDrawDateText(l10n, ticket),
                ),
                _TicketInfoRow(
                  label: l10n.ticketLabelLotteryNumber,
                  value: ticket.number,
                ),
                if (drawNumber.isNotEmpty)
                  _TicketInfoRow(
                    label: l10n.ticketLabelDrawNumber,
                    value: drawNumber,
                  ),
                if (setNumber.isNotEmpty)
                  _TicketInfoRow(
                    label: l10n.ticketLabelSetNumber,
                    value: setNumber,
                  ),
                _TicketInfoRow(
                  label: l10n.ticketLabelPrize,
                  value: _ticketPrizeLinesWithAmounts(l10n, ticket),
                ),
                _TicketInfoRow(
                  label: l10n.ticketLabelPrizeAmount,
                  value: formatBaht(ticket.prizeAmount),
                  emphasize: true,
                ),
                _TicketInfoRow(
                  label: l10n.rewardClaimTaxLabel,
                  value: l10n.rewardClaimZeroBaht,
                  helper: l10n.rewardClaimWaived(formatBaht(taxAmount)),
                  positive: true,
                ),
                _TicketInfoRow(
                  label: l10n.rewardClaimFeeLabel,
                  value: l10n.rewardClaimZeroBaht,
                  helper: l10n.rewardClaimWaived(formatBaht(feeAmount)),
                  positive: true,
                ),
                const Divider(height: 28),
                _TicketInfoRow(
                  label: l10n.ticketLabelNetAmount,
                  value: formatBaht(ticket.prizeAmount),
                  emphasize: true,
                ),
                if (submittedClaim != null)
                  _TicketInfoRow(
                    label: l10n.ticketLabelSubmittedAt,
                    value: rewardClaimSubmittedText(l10n, submittedClaim!),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => context.go('/tickets'),
          child: Text(l10n.ticketClaimViewMyTickets),
        ),
      ],
    );
  }
}

class _ClaimProcessingBrandHeader extends StatelessWidget {
  const _ClaimProcessingBrandHeader({required this.productMarker});

  final String productMarker;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.72),
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          children: [
            const TenantBrandHeader(
              showName: false,
              size: 46,
              icon: Icons.emoji_events_outlined,
            ),
            if (productMarker.isNotEmpty) ...[
              const SizedBox(width: 12),
              Text(
                productMarker,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ],
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                context.l10n.ticketLabelGovernmentLottery,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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

class _ClaimTicketSummary extends StatelessWidget {
  const _ClaimTicketSummary({required this.ticket});

  final CustomerTicket ticket;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.ticketLabelGovernmentLottery,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            _TicketInfoRow(
              label: l10n.ticketLabelLotteryNumber,
              value: ticket.number,
            ),
            _TicketInfoRow(
              label: l10n.ticketLabelDraw,
              value: ticketDrawDateText(l10n, ticket),
            ),
            _TicketInfoRow(
              label: l10n.ticketLabelPrize,
              value: ticketPrizeSummary(l10n, ticket),
            ),
            _TicketInfoRow(
              label: l10n.ticketLabelPrizeAmount,
              value: formatBaht(ticket.prizeAmount),
              emphasize: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _PayoutOption extends StatelessWidget {
  const _PayoutOption({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
  });

  final bool selected;
  final bool enabled;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : Theme.of(context).dividerColor,
            width: selected ? 2 : 1,
          ),
          color: selected ? color.withValues(alpha: 0.08) : null,
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              color: selected ? color : null,
            ),
            const SizedBox(width: 12),
            CircleAvatar(child: Icon(icon)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  Text(subtitle),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TicketImageCard extends ConsumerWidget {
  const _TicketImageCard({required this.ticket});

  final CustomerTicket ticket;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolver = ref.watch(assetUrlResolverProvider);
    final bootstrap = ref.watch(mobileBootstrapProvider).valueOrNull;
    final productMarker = bootstrap?.lotteryProductLabel.trim() ?? '';
    final ticketImageWatermark =
        bootstrap?.ticketImageWatermark.trim() ?? productMarker;
    final url = resolver(ticket.primaryImageUrl);
    final showRemoteImage = _canShowTicketRemoteImage(ticket, url);
    final l10n = context.l10n;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Tooltip(
        message: l10n.ticketImageOpenPreview,
        child: InkWell(
          onTap: () => showDialog<void>(
            context: context,
            builder: (dialogContext) => _TicketImageDialog(ticket: ticket),
          ),
          child: Semantics(
            button: true,
            label: l10n.ticketImageAlt(_ticketDisplayNumber(ticket)),
            child: AspectRatio(
              aspectRatio: 5 / 2.8,
              child: _TicketImageFrame(
                ticket: ticket,
                imageUrl: url,
                showRemoteImage: showRemoteImage,
                productMarker: productMarker,
                ticketImageWatermark: ticketImageWatermark,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TicketImageDialog extends ConsumerWidget {
  const _TicketImageDialog({required this.ticket});

  final CustomerTicket ticket;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolver = ref.watch(assetUrlResolverProvider);
    final bootstrap = ref.watch(mobileBootstrapProvider).valueOrNull;
    final productMarker = bootstrap?.lotteryProductLabel.trim() ?? '';
    final ticketImageWatermark =
        bootstrap?.ticketImageWatermark.trim() ?? productMarker;
    final siteName = bootstrap?.siteName.trim() ?? '';
    final url = resolver(ticket.primaryImageUrl);
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 10, 8),
              child: Row(
                children: [
                  const Expanded(child: SizedBox.shrink()),
                  const TenantBrandHeader(
                    showName: false,
                    size: 46,
                    icon: Icons.confirmation_number_outlined,
                  ),
                  if (productMarker.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Text(
                      productMarker,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w900,
                              ),
                    ),
                  ],
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        tooltip: l10n.ticketImageClosePreview,
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
              child: AspectRatio(
                aspectRatio: 5 / 2.8,
                child: _TicketImageFrame(
                  ticket: ticket,
                  imageUrl: url,
                  showRemoteImage: _canShowTicketRemoteImage(ticket, url),
                  productMarker: productMarker,
                  ticketImageWatermark: ticketImageWatermark,
                ),
              ),
            ),
            _TicketImageNote(
              siteName:
                  siteName.isEmpty ? l10n.ticketImageTenantFallback : siteName,
              productName: l10n.ticketLabelGovernmentLottery,
            ),
          ],
        ),
      ),
    );
  }
}

class _TicketImageFrame extends StatelessWidget {
  const _TicketImageFrame({
    required this.ticket,
    required this.imageUrl,
    required this.showRemoteImage,
    required this.productMarker,
    required this.ticketImageWatermark,
  });

  final CustomerTicket ticket;
  final String imageUrl;
  final bool showRemoteImage;
  final String productMarker;
  final String ticketImageWatermark;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (showRemoteImage)
              _TicketRemoteImage(
                ticket: ticket,
                imageUrl: imageUrl,
                productMarker: productMarker,
                ticketImageWatermark: ticketImageWatermark,
              )
            else
              _GeneratedTicketImage(
                ticket: ticket,
                productMarker: productMarker,
                ticketImageWatermark: ticketImageWatermark,
              ),
            _TicketSoldWatermarks(label: context.l10n.ticketImageSold),
          ],
        ),
      ),
    );
  }
}

class _TicketRemoteImage extends StatelessWidget {
  const _TicketRemoteImage({
    required this.ticket,
    required this.imageUrl,
    required this.productMarker,
    required this.ticketImageWatermark,
  });

  final CustomerTicket ticket;
  final String imageUrl;
  final String productMarker;
  final String ticketImageWatermark;

  @override
  Widget build(BuildContext context) {
    final bytes = _dataImageBytes(imageUrl);
    if (bytes != null) {
      return Image.memory(bytes, fit: BoxFit.contain);
    }

    return Image.network(
      imageUrl,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => _GeneratedTicketImage(
        ticket: ticket,
        productMarker: productMarker,
        ticketImageWatermark: ticketImageWatermark,
      ),
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return const Center(child: CircularProgressIndicator());
      },
    );
  }
}

class _GeneratedTicketImage extends StatelessWidget {
  const _GeneratedTicketImage({
    required this.ticket,
    required this.productMarker,
    required this.ticketImageWatermark,
  });

  final CustomerTicket ticket;
  final String productMarker;
  final String ticketImageWatermark;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final digits = _ticketDisplayNumber(ticket).split('');
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFFF4FBFF),
            Color(0xFFFFF8DC),
          ],
        ),
      ),
      child: Stack(
        children: [
          if (ticketImageWatermark.isNotEmpty)
            Center(
              child: Transform.rotate(
                angle: -0.24,
                child: Text(
                  ticketImageWatermark,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.08),
                    fontSize: 72,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.ticketLabelGovernmentLottery,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        Text(
                          l10n.ticketImageGovernmentLotteryEnglish,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  if (productMarker.isNotEmpty)
                    Text(
                      productMarker,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w900,
                              ),
                    ),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.78),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.22),
                      ),
                    ),
                    child: Icon(
                      Icons.confirmation_number_outlined,
                      color: Theme.of(context).colorScheme.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          l10n.ticketImageDigitalNumberLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                    fontWeight: FontWeight.w900,
                                  ),
                        ),
                        const SizedBox(height: 6),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFF4A8), Color(0xFFFFE46E)],
                            ),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFCCA400)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            child: Row(
                              children: [
                                for (final digit in digits)
                                  Expanded(
                                    child: Text(
                                      digit,
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            color: Colors.black87,
                                            fontWeight: FontWeight.w900,
                                          ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            _TicketImageMetaPill(
                              label: l10n.ticketImageCurrentDraw,
                            ),
                            _TicketImageMetaPill(
                              label: l10n.ticketImageDigitalType,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (ticket.imageError.isNotEmpty)
            Align(
              alignment: Alignment.bottomLeft,
              child: _TicketImageErrorBadge(message: ticket.imageError),
            )
          else if (ticket.imageStatus.isNotEmpty &&
              !_canShowTicketRemoteImage(ticket, ticket.primaryImageUrl))
            Align(
              alignment: Alignment.bottomLeft,
              child: _TicketImageErrorBadge(
                message: ticket.imageStatus == 'ready'
                    ? l10n.ticketImageUnavailable
                    : l10n.ticketImagePreparing,
              ),
            ),
        ],
      ),
    );
  }
}

class _TicketImageMetaPill extends StatelessWidget {
  const _TicketImageMetaPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
              ),
        ),
      ),
    );
  }
}

class _TicketImageErrorBadge extends StatelessWidget {
  const _TicketImageErrorBadge({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        message,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _TicketSoldWatermarks extends StatelessWidget {
  const _TicketSoldWatermarks({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleLarge?.copyWith(
          color: Theme.of(context).colorScheme.error.withValues(alpha: 0.55),
          fontWeight: FontWeight.w900,
        );
    const positions = <({double left, double top, double scale})>[
      (left: 0.20, top: 0.24, scale: 1),
      (left: 0.55, top: 0.22, scale: 0.95),
      (left: 0.84, top: 0.34, scale: 0.88),
      (left: 0.28, top: 0.53, scale: 0.92),
      (left: 0.68, top: 0.59, scale: 0.84),
      (left: 0.46, top: 0.81, scale: 0.98),
    ];

    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              for (final position in positions)
                Positioned(
                  left: constraints.maxWidth * position.left,
                  top: constraints.maxHeight * position.top,
                  child: Transform.translate(
                    offset: const Offset(-36, -10),
                    child: Transform.rotate(
                      angle: -0.30,
                      child: Transform.scale(
                        scale: position.scale,
                        child: Text(label, style: style),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _TicketImageNote extends StatelessWidget {
  const _TicketImageNote({
    required this.siteName,
    required this.productName,
  });

  final String siteName;
  final String productName;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ColoredBox(
      color: Theme.of(context).colorScheme.primaryContainer.withValues(
            alpha: 0.42,
          ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                siteName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.ticketImageModalNote(siteName, productName),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                      height: 1.35,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

bool _canShowTicketRemoteImage(CustomerTicket ticket, String url) {
  if (url.trim().isEmpty) return false;
  return !{'pending_assets', 'missing'}.contains(ticket.imageStatus);
}

String _ticketDisplayNumber(CustomerTicket ticket) {
  final digits = ticket.number.replaceAll(RegExp(r'\D'), '');
  final padded = digits.padLeft(6, '0');
  return padded.substring(padded.length - 6);
}

Uint8List? _dataImageBytes(String value) {
  final trimmed = value.trim();
  if (!trimmed.startsWith('data:image/')) return null;
  final commaIndex = trimmed.indexOf(',');
  if (commaIndex < 0) return null;
  try {
    return base64Decode(trimmed.substring(commaIndex + 1));
  } catch (_) {
    return null;
  }
}

class _TicketInfoRow extends StatelessWidget {
  const _TicketInfoRow({
    required this.label,
    required this.value,
    this.emphasize = false,
    this.helper = '',
    this.positive = false,
  });

  final String label;
  final String value;
  final bool emphasize;
  final String helper;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final valueColor = emphasize
        ? Theme.of(context).colorScheme.primary
        : positive
            ? Colors.green.shade700
            : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value.isEmpty ? '-' : value,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontWeight: emphasize ? FontWeight.w900 : FontWeight.w700,
                    color: valueColor,
                  ),
                ),
                if (helper.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    helper,
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: positive
                              ? Colors.green.shade700
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TicketStatusPill extends StatelessWidget {
  const _TicketStatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.12),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _TicketLoadingList extends StatelessWidget {
  const _TicketLoadingList();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Flexible(child: Text(context.l10n.ticketsLoading)),
          ],
        ),
      ),
    );
  }
}

class _TicketErrorCard extends StatelessWidget {
  const _TicketErrorCard({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(context.l10n.commonRetry),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TicketEmptyHistoryCard extends StatelessWidget {
  const _TicketEmptyHistoryCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.history)),
        title: Text(context.l10n.ticketHistoryEmptyTitle),
        subtitle: Text(context.l10n.ticketHistoryEmptySubtitle),
      ),
    );
  }
}

class _TicketHistoryWinningEmptyCard extends StatelessWidget {
  const _TicketHistoryWinningEmptyCard();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.emoji_events_outlined)),
        title: Text(l10n.ticketHistoryWinningEmptyTitle),
        subtitle: Text(l10n.ticketHistoryWinningEmptySubtitle),
      ),
    );
  }
}

enum _ClaimStep { select, confirm, pin, processing }

Color _ticketStatusColor(BuildContext context, CustomerTicket ticket) {
  final status = ticket.rewardStatus.status;
  if (status == 'paid' || status == 'paid_out' || ticket.status == 'paid') {
    return Colors.green;
  }
  if (status == 'rejected' ||
      ticket.rewardStatus.claimStatus == 'rejected' ||
      ticket.status == 'rejected') {
    return Theme.of(context).colorScheme.error;
  }
  if (status == 'winning') return Colors.orange.shade800;
  if (status == 'non_winning') return Theme.of(context).colorScheme.outline;
  return Theme.of(context).colorScheme.primary;
}

String _ticketErrorMessage(Object error, String fallback) {
  final message = ApiErrorInfo.fromObject(error).message.trim();
  if (message.isEmpty) return fallback;
  if (error is DioException || error is Map) return message;
  return fallback;
}

String _payoutLabel(
  CustomerLocalizations l10n,
  CustomerProfileSettings? profile,
  String method,
) {
  if (method == 'bank_transfer') {
    final bank = profile?.bankAccount;
    if (bank == null || !bank.isComplete) return l10n.ticketClaimBankTitle;
    return '${bank.bankName} ${bank.maskedNumber}';
  }
  return l10n.ticketClaimWalletTitle;
}
