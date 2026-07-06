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
import '../../../shared/widgets/customer_loading_indicator.dart';
import '../../../shared/widgets/customer_page_body.dart';
import '../../../shared/widgets/customer_section_header.dart';
import '../../../shared/widgets/tenant_brand_header.dart';
import '../data/ticket_models.dart';
import '../data/ticket_repository.dart';
import 'ticket_localization.dart';

Color _ticketPrimaryTint(ColorScheme colorScheme) =>
    Color.lerp(colorScheme.primary, colorScheme.surface, 0.88) ??
    colorScheme.primary.withValues(alpha: 0.12);

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
      ],
      child: _TicketPageList(
        hero: const _TicketRouteTabs(current: _TicketRouteTab.current),
        children: [
          if (_showSearch) ...[
            _TicketSearchForm(
              controller: _searchController,
              onSubmit: _applySearch,
              onClear: _clearSearch,
            ),
            const SizedBox(height: 12),
          ],
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
                  else ...[
                    for (final ticket in displayTickets)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _TicketTile(ticket: ticket),
                      ),
                    const SizedBox(height: 2),
                    const _TicketAllLoadedText(),
                  ],
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
    final colorScheme = Theme.of(context).colorScheme;
    final searchFill =
        Color.lerp(colorScheme.surface, colorScheme.primaryContainer, 0.08) ??
            colorScheme.surfaceContainerHighest;
    final clearFill = Color.lerp(
          colorScheme.surfaceContainerHighest,
          colorScheme.primary,
          0.06,
        ) ??
        colorScheme.surfaceContainerHighest;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: searchFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.78),
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Icon(
                Icons.search,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  key: const ValueKey('ticket-search-input'),
                  controller: controller,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    counterText: '',
                    isCollapsed: true,
                    hintText: l10n.ticketsSearchPlaceholder,
                  ),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
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
                    style: IconButton.styleFrom(
                      fixedSize: const Size.square(32),
                      backgroundColor: clearFill,
                      foregroundColor: colorScheme.onSurfaceVariant,
                      shape: const CircleBorder(),
                      padding: EdgeInsets.zero,
                    ),
                    onPressed: onClear,
                    icon: const Icon(Icons.close, size: 18),
                  );
                },
              ),
              FilledButton(
                key: const ValueKey('ticket-search-submit'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 34),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: const StadiumBorder(),
                  textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                onPressed: onSubmit,
                child: Text(l10n.ticketsSearchSubmit),
              ),
            ],
          ),
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
    final l10n = context.l10n;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xFFFFF4BF),
            Color(0xFFFFE28A),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB0790D).withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 82),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.ticketsWinningBannerTitle,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: const Color(0xFFA56800),
                            fontWeight: FontWeight.w900,
                            height: 1.05,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.ticketsWinningBannerMessage(count),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF7A5509),
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.48),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.monetization_on_outlined,
                  color: Color(0xFFF4A900),
                  size: 32,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TicketSearchEmptyCard extends StatelessWidget {
  const _TicketSearchEmptyCard();

  @override
  Widget build(BuildContext context) {
    return _TicketEmptyState(
      title: context.l10n.ticketsSearchEmptyTitle,
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
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            Expanded(
              child: _TicketRouteTabButton(
                label: l10n.ticketsTabCurrent,
                selected: current == _TicketRouteTab.current,
                onTap: () {
                  if (current != _TicketRouteTab.current) {
                    context.go('/tickets');
                  }
                },
              ),
            ),
            Expanded(
              child: _TicketRouteTabButton(
                label: l10n.ticketsTabHistory,
                selected: current == _TicketRouteTab.history,
                onTap: () {
                  if (current != _TicketRouteTab.history) {
                    context.go('/tickets/history');
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TicketRouteTabButton extends StatelessWidget {
  const _TicketRouteTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: Ink(
        height: 43,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: selected
              ? LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color.lerp(
                          colorScheme.primary,
                          colorScheme.surface,
                          0.08,
                        ) ??
                        colorScheme.primary,
                    colorScheme.primary,
                  ],
                )
              : null,
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: colorScheme.surface.withValues(alpha: 0.52),
                    blurRadius: 0,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: selected
                        ? colorScheme.onPrimary
                        : colorScheme.onSurface,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                    height: 1,
                  ),
            ),
          ),
        ),
      ),
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
    final theme = Theme.of(context);
    return CustomerSectionHeader(
      title: l10n.ticketHistoryListTitle,
      action: TextButton.icon(
        onPressed: onToggle,
        style: TextButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          minimumSize: const Size(0, 32),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: theme.colorScheme.primary,
          textStyle: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        icon: Icon(
          showOnlyWinning ? Icons.list_alt : Icons.playlist_add_check,
          size: 18,
        ),
        label: Text(
          showOnlyWinning
              ? l10n.ticketHistoryShowAll
              : l10n.ticketHistoryShowWinning,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _TicketHistoryOverview extends StatelessWidget {
  const _TicketHistoryOverview({
    required this.groups,
    required this.itemCount,
  });

  final List<_TicketHistoryDrawGroupData> groups;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final title = groups.length == 1
        ? (groups.first.drawDate == '-'
            ? l10n.ticketHistoryCompletedDrawFallback
            : groups.first.drawDate)
        : l10n.ticketHistoryAllDraws(groups.length);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.ticketHistoryPastTicketsLabel,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w900,
                      height: 1.18,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        DecoratedBox(
          decoration: BoxDecoration(
            color: _ticketPrimaryTint(Theme.of(context).colorScheme),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withValues(
                    alpha: 0.16,
                  ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Text(
              l10n.ticketHistoryItemCount(itemCount),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TicketHistoryNoWinningBanner extends StatelessWidget {
  const _TicketHistoryNoWinningBanner();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xFFDFFFE9),
            Color(0xFFFFF6CF),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            Expanded(
              child: Text(
                context.l10n.ticketHistoryNoWinningSummary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF15803D),
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                    ),
              ),
            ),
            const SizedBox(width: 12),
            const Icon(
              Icons.auto_awesome,
              color: Color(0xFFEAB308),
              size: 38,
            ),
          ],
        ),
      ),
    );
  }
}

class _TicketPageList extends StatelessWidget {
  const _TicketPageList({
    required this.children,
    this.hero,
    this.maxWidth = 640,
    this.top = 23,
    this.bottom = _bottomPadding,
    this.heroHeight = _heroHeight,
    this.controller,
    this.physics,
  });

  static const _heroHeight = 189.0;
  static const _sheetOverlap = 41.0;
  static const _bottomPadding = 120.0;

  final List<Widget> children;
  final Widget? hero;
  final double maxWidth;
  final double top;
  final double bottom;
  final double heroHeight;
  final ScrollController? controller;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    final hero = this.hero;
    if (hero == null) {
      return ListView(
        controller: controller,
        physics: physics,
        children: [
          CustomerPageBody(
            maxWidth: maxWidth,
            top: top,
            bottom: bottom,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      );
    }

    final colorScheme = Theme.of(context).colorScheme;
    return ListView(
      padding: EdgeInsets.zero,
      controller: controller,
      physics: physics,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            _TicketHeroBand(
              maxWidth: maxWidth,
              height: heroHeight,
              child: hero,
            ),
            Padding(
              padding: EdgeInsets.only(top: heroHeight - _sheetOverlap),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(18),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF213755).withValues(alpha: 0.07),
                      blurRadius: 24,
                      offset: const Offset(0, -6),
                    ),
                  ],
                ),
                child: CustomerPageBody(
                  maxWidth: maxWidth,
                  top: top,
                  bottom: bottom,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TicketHeroBand extends StatelessWidget {
  const _TicketHeroBand({
    required this.child,
    required this.maxWidth,
    required this.height,
  });

  final Widget child;
  final double maxWidth;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLargeHero = height > 260;
    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primary,
              Color.lerp(colorScheme.primary, colorScheme.secondary, 0.46) ??
                  colorScheme.primary,
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              left: -52,
              top: 24,
              child: Transform.rotate(
                angle: -0.52,
                child: Container(
                  width: 250,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(40),
                  ),
                ),
              ),
            ),
            Positioned(
              right: -28,
              bottom: 46,
              child: Transform.rotate(
                angle: 0.26,
                child: Container(
                  width: 180,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
              ),
            ),
            CustomerPageBody(
              maxWidth: maxWidth,
              top: isLargeHero ? 52 : 78,
              bottom: isLargeHero ? 34 : 56,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyTicketsCard extends StatelessWidget {
  const _EmptyTicketsCard();

  @override
  Widget build(BuildContext context) {
    return _TicketEmptyState(
      title: context.l10n.ticketsEmptyTitle,
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

class _TicketAllLoadedText extends StatelessWidget {
  const _TicketAllLoadedText();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Text(
        context.l10n.commonAllLoaded,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
      ),
    );
  }
}

class _TicketNoticePanel extends StatelessWidget {
  const _TicketNoticePanel({
    required this.message,
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = colorScheme.onErrorContainer;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.52),
        border: Border.all(
          color:
              Color.lerp(colorScheme.outlineVariant, colorScheme.error, 0.34) ??
                  colorScheme.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline_rounded, color: foreground, size: 20),
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
            if (onRetry != null) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  foregroundColor: foreground,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 34),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                child: Text(context.l10n.commonRetry),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TicketEmptyState extends StatelessWidget {
  const _TicketEmptyState({
    required this.title,
    this.subtitle,
    this.danger = false,
    this.onRetry,
  });

  final String title;
  final String? subtitle;
  final bool danger;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = danger ? colorScheme.error : colorScheme.onSurfaceVariant;
    final subtitleText = subtitle?.trim() ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 52),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  height: 1.35,
                ),
          ),
          if (subtitleText.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              subtitleText,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    height: 1.45,
                  ),
            ),
          ],
          if (onRetry != null) ...[
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: onRetry,
              child: Text(context.l10n.commonRetry),
            ),
          ],
        ],
      ),
    );
  }
}

class _TicketTile extends StatelessWidget {
  const _TicketTile({
    required this.ticket,
    this.fromHistory = false,
    this.openDetail = true,
  });

  final CustomerTicket ticket;
  final bool fromHistory;
  final bool openDetail;

  @override
  Widget build(BuildContext context) {
    final statusColor = _ticketStatusColor(context, ticket);
    final l10n = context.l10n;
    final number = ticket.number.isEmpty
        ? context.l10n.ticketsNumberFallback
        : ticket.number;
    final isWinning = _ticketIsWinning(ticket);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final claimPath = _ticketStubClaimPath(ticket, fromHistory: fromHistory);
    final openTicket = !openDetail || ticket.id.isEmpty
        ? null
        : () => context.go(
              '/tickets/view?id=${Uri.encodeComponent(ticket.id)}'
              '${fromHistory ? '&from=history' : ''}',
            );

    return Semantics(
      button: openTicket != null,
      label: '${l10n.ticketLabelGovernmentLottery} $number',
      child: Material(
        color: Colors.transparent,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isWinning
                  ? statusColor.withValues(alpha: 0.28)
                  : colorScheme.outlineVariant.withValues(alpha: 0.52),
            ),
            boxShadow: [
              BoxShadow(
                color: (isWinning ? statusColor : colorScheme.shadow)
                    .withValues(alpha: isWinning ? 0.16 : 0.1),
                blurRadius: isWinning ? 20 : 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: openTicket,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 30, 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 48,
                                child: _TicketStubMark(),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      l10n.ticketLabelGovernmentLottery,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: textTheme.labelMedium?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w800,
                                        height: 1,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    _TicketStubNumber(number: number),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                width: 60,
                                child: Text(
                                  ticketStatusLabel(l10n, ticket),
                                  textAlign: TextAlign.center,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.labelMedium?.copyWith(
                                    color: statusColor,
                                    fontWeight: FontWeight.w900,
                                    height: 1.15,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (isWinning)
                      _TicketStubRewardStrip(
                        ticket: ticket,
                        actionPath: claimPath,
                      ),
                  ],
                ),
                Positioned.fill(
                  right: 0,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      width: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: isWinning
                              ? const [
                                  Color(0xFFF7F1FF),
                                  Color(0xFFD9CCFF),
                                ]
                              : const [
                                  Color(0xFFF5F0FF),
                                  Color(0xFFF0E9FF),
                                ],
                        ),
                      ),
                      child: RotatedBox(
                        quarterTurns: 1,
                        child: Text(
                          l10n.ticketStubDigitalLabel,
                          maxLines: 1,
                          style: textTheme.labelSmall?.copyWith(
                            color: const Color(0xFF7547C8),
                            fontWeight: FontWeight.w800,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
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

class _TicketStubMark extends StatelessWidget {
  const _TicketStubMark();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.ticketStubSeriesLabel,
          style: textTheme.titleLarge?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w900,
            height: 1,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.ticketStubPriceLabel,
          textAlign: TextAlign.center,
          style: textTheme.labelMedium?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.w900,
            height: 0.96,
          ),
        ),
      ],
    );
  }
}

class _TicketStubNumber extends StatelessWidget {
  const _TicketStubNumber({required this.number});

  final String number;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.72),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: FittedBox(
          alignment: Alignment.centerLeft,
          fit: BoxFit.scaleDown,
          child: Text(
            number,
            maxLines: 1,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w900,
                  letterSpacing: number.length > 1 ? 3 : 0,
                  height: 1,
                ),
          ),
        ),
      ),
    );
  }
}

class _TicketStubRewardStrip extends StatelessWidget {
  const _TicketStubRewardStrip({
    required this.ticket,
    required this.actionPath,
  });

  final CustomerTicket ticket;
  final String actionPath;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFF1B6), Color(0xFFFFDA68)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 9),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    ticketPrizeSummary(l10n, ticket),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelMedium?.copyWith(
                      color: const Color(0xFF8E5A03),
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                    ),
                  ),
                  if (ticket.prizes.length > 1)
                    for (final prize in ticket.prizes)
                      Text(
                        '${ticketPrizeTypeLabel(l10n, prize.prizeType)} '
                        '${formatBaht(prize.amount)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.labelSmall?.copyWith(
                          color: const Color(0xFF8A5A00),
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      )
                  else if (ticket.prizeAmount > 0)
                    Text(
                      l10n.ticketStubPrizeAmount(
                        formatBaht(ticket.prizeAmount),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.labelSmall?.copyWith(
                        color: const Color(0xFFB17309),
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _TicketClaimPill(
              label: ticket.canCreateClaim
                  ? l10n.ticketStubClaimStart
                  : l10n.ticketClaimViewReward,
              enabled: actionPath.isNotEmpty,
              onPressed:
                  actionPath.isEmpty ? null : () => context.go(actionPath),
            ),
          ],
        ),
      ),
    );
  }
}

class _TicketClaimPill extends StatelessWidget {
  const _TicketClaimPill({
    required this.label,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final bool enabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.62,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 78, minHeight: 28),
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFD95A), Color(0xFFEDB717)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFB37906).withValues(alpha: 0.22),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: const Color(0xFF6D4900),
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _ticketStubClaimPath(
  CustomerTicket ticket, {
  required bool fromHistory,
}) {
  if (ticket.canCreateClaim && ticket.id.trim().isNotEmpty) {
    return '/tickets/claim/${Uri.encodeComponent(ticket.id)}'
        '?from=${fromHistory ? 'history' : 'current'}';
  }

  final claimId = ticket.rewardClaimId.trim();
  if (claimId.isNotEmpty) {
    return '/reward-claims/${Uri.encodeComponent(claimId)}';
  }

  return '';
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
  String _loadMoreError = '';

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
    final ticketGroups = _groupTicketsByDraw(_tickets, l10n);
    final visibleTicketGroups = _groupTicketsByDraw(visibleTickets, l10n);
    final winningTicketCount = _winningTicketCount(_tickets);

    return AppShell(
      title: l10n.ticketHistoryTitle,
      currentPath: '/tickets',
      sensitive: true,
      child: RefreshIndicator(
        onRefresh: _loadInitial,
        child: _TicketPageList(
          hero: const _TicketRouteTabs(current: _TicketRouteTab.history),
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
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
              const Divider(height: 20),
              _TicketHistoryOverview(
                groups: ticketGroups,
                itemCount: _tickets.length,
              ),
              const SizedBox(height: 12),
              winningTicketCount > 0
                  ? _WinningTicketBanner(count: winningTicketCount)
                  : const _TicketHistoryNoWinningBanner(),
              const SizedBox(height: 12),
              if (visibleTickets.isEmpty)
                const _TicketHistoryWinningEmptyCard()
              else
                for (final group in visibleTicketGroups)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _TicketHistoryDrawGroup(group: group),
                  ),
              if (_loadMoreError.isNotEmpty) ...[
                _TicketNoticePanel(
                  message: _loadMoreError,
                  onRetry: _loadingMore ? null : _loadMore,
                ),
                const SizedBox(height: 10),
              ] else if (_hasMore)
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
                )
              else if (_tickets.isNotEmpty && !_loadingMore)
                const _TicketAllLoadedText(),
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
      _loadMoreError = '';
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
    setState(() {
      _loadingMore = true;
      _loadMoreError = '';
    });
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
      setState(
        () => _loadMoreError = _ticketErrorMessage(
          error,
          context.l10n.ticketHistoryLoadMoreFailed,
        ),
      );
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _maybeLoadMoreFromScroll() {
    if (_loadingInitial || _loadingMore || !_hasMore) return;
    if (_loadMoreError.isNotEmpty) return;
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

class _TicketDetailContent extends StatelessWidget {
  const _TicketDetailContent({
    required this.ticket,
    required this.fromHistory,
  });

  final CustomerTicket ticket;
  final bool fromHistory;

  @override
  Widget build(BuildContext context) {
    return _TicketPageList(
      hero: _TicketRouteTabs(
        current:
            fromHistory ? _TicketRouteTab.history : _TicketRouteTab.current,
      ),
      children: [
        _TicketDetailSummary(ticket: ticket),
        const SizedBox(height: 12),
        _TicketTile(
          ticket: ticket,
          fromHistory: fromHistory,
          openDetail: false,
        ),
        const SizedBox(height: 12),
        _TicketImageCard(ticket: ticket),
        const SizedBox(height: 12),
        _TicketDetailInfoSheet(ticket: ticket),
      ],
    );
  }
}

class _TicketDetailSummary extends StatelessWidget {
  const _TicketDetailSummary({required this.ticket});

  final CustomerTicket ticket;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
          ticketDrawDateText(l10n, ticket),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 3),
        Text(
          l10n.ticketsTotalCount(ticket.count),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
              ),
        ),
      ],
    );
  }
}

class _TicketDetailInfoSheet extends StatelessWidget {
  const _TicketDetailInfoSheet({required this.ticket});

  final CustomerTicket ticket;

  @override
  Widget build(BuildContext context) {
    final statusColor = _ticketStatusColor(context, ticket);
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.64),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.ticketDetailTitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w900,
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
            if (ticket.drawNumber.trim().isNotEmpty)
              _TicketInfoRow(
                label: l10n.ticketLabelDrawNumber,
                value: ticket.drawNumber,
              ),
            if (ticket.setNumber.trim().isNotEmpty)
              _TicketInfoRow(
                label: l10n.ticketLabelSetNumber,
                value: ticket.setNumber,
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
                    _TicketStatusPill(
                      color: colorScheme.primary,
                      label: '${ticketPrizeTypeLabel(l10n, prize.prizeType)} '
                          '${formatBaht(prize.amount)}',
                    ),
                ],
              ),
            ],
            if (ticket.rewardStatus.adminNote.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                ticket.rewardStatus.adminNote,
                style: TextStyle(
                  color: colorScheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
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
  String _claimNoticeMessage = '';
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
      title: switch (_step) {
        _ClaimStep.pin => l10n.ticketClaimPinTitle,
        _ClaimStep.confirm => l10n.ticketClaimConfirmTitle,
        _ => l10n.ticketClaimTitle,
      },
      currentPath: '/tickets',
      sensitive: true,
      showBottomNavigation: false,
      onBack: () => _handleBack(backPath),
      child: _buildBody(context),
    );
  }

  void _handleBack(String backPath) {
    if (_step == _ClaimStep.confirm) {
      setState(() {
        _step = _ClaimStep.select;
        _claimNoticeMessage = '';
      });
      return;
    }
    if (_step == _ClaimStep.pin) {
      setState(() {
        _step = _ClaimStep.confirm;
        _pin = '';
        _pinError = '';
        _claimNoticeMessage = '';
      });
      return;
    }
    context.go(backPath);
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
          if (_claimNoticeMessage.isNotEmpty) ...[
            _TicketNoticePanel(message: _claimNoticeMessage),
            const SizedBox(height: 12),
          ],
          _ExistingRewardClaimCard(
            onOpen: () => context.go('/reward-claims/${ticket.rewardClaimId}'),
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
          noticeMessage: _claimNoticeMessage,
          onMethodChanged: (value) => setState(() {
            _payoutMethod = value;
            _claimNoticeMessage = '';
          }),
          onNext: _canContinue
              ? () => setState(() {
                    _step = _ClaimStep.confirm;
                    _claimNoticeMessage = '';
                  })
              : null,
        ),
      _ClaimStep.confirm => _ClaimConfirmStep(
          ticket: ticket,
          profile: _profile,
          payoutMethod: _payoutMethod,
          submitting: _submitting,
          onConfirm: _canContinue
              ? () => setState(() {
                    _step = _ClaimStep.pin;
                    _pin = '';
                    _pinError = '';
                    _claimNoticeMessage = '';
                  })
              : null,
        ),
      _ClaimStep.pin => _ClaimPinStep(
          pin: _pin,
          error: _pinError,
          noticeMessage: _claimNoticeMessage,
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
      _claimNoticeMessage = '';
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
      _claimNoticeMessage = '';
    });
    if (_pin.length == 6) _submitClaim();
  }

  void _removePinDigit() {
    if (_pin.isEmpty || _submitting) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _pinError = '';
      _claimNoticeMessage = '';
    });
  }

  Future<void> _submitClaim({String pinAssertionToken = ''}) async {
    final ticket = _ticket;
    if (ticket == null || !_canContinue || _submitting) return;
    setState(() {
      _submitting = true;
      _claimNoticeMessage = '';
    });
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
        _claimNoticeMessage = '';
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
      if (_isClaimConflict(error)) {
        setState(() {
          _pin = '';
          _pinError = '';
          _step = _ClaimStep.select;
        });
        await _load();
        if (mounted) {
          setState(
            () => _claimNoticeMessage = context.l10n.ticketClaimConflict,
          );
        }
        return;
      }
      if (!mounted) return;
      setState(() {
        _pin = '';
        _pinError = pinError;
        _claimNoticeMessage =
            pinError.isEmpty ? _ticketErrorMessage(error, failedMessage) : '';
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _submitClaimWithBiometric() async {
    if (_submitting) return;
    setState(() {
      _pin = '';
      _pinError = '';
      _claimNoticeMessage = '';
    });
    try {
      final token =
          await ref.read(biometricAuthServiceProvider).requestPinAssertion(
                purpose: 'reward_claim',
                localizedReason: mobileBiometricPromptReason(
                  ref.read(mobileBootstrapProvider).valueOrNull,
                  purpose: 'reward_claim',
                  fallback: context.l10n.pinBiometricReason,
                ),
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

  bool _isClaimConflict(Object error) {
    final info = ApiErrorInfo.fromObject(error);
    return info.statusCode == 409 || info.code == 'resource_conflict';
  }
}

class _ExistingRewardClaimCard extends StatelessWidget {
  const _ExistingRewardClaimCard({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _ticketPrimaryTint(colorScheme)),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: colorScheme.primary,
                  size: 26,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.ticketClaimAlreadyTitle,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: colorScheme.onSurface,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.ticketClaimAlreadySubtitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              height: 1.4,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: onOpen,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: const StadiumBorder(),
                textStyle: const TextStyle(fontWeight: FontWeight.w900),
              ),
              child: Text(l10n.ticketClaimViewClaim),
            ),
          ],
        ),
      ),
    );
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

class _ClaimStepScaffold extends StatelessWidget {
  const _ClaimStepScaffold({
    required this.child,
    required this.footer,
  });

  static const footerSpace = 112.0;

  final Widget child;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        Positioned.fill(child: child),
        Align(
          alignment: Alignment.bottomCenter,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, -8),
                ),
              ],
            ),
            child: SafeArea(
              minimum: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 612),
                child: footer,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ClaimTicketHeroCard extends StatelessWidget {
  const _ClaimTicketHeroCard({required this.ticket});

  final CustomerTicket ticket;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _ticketPrimaryTint(colorScheme)),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const _ClaimLotteryLogo(),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.ticketLabelGovernmentLottery,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          height: 1.18,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        ticketDrawDateText(l10n, ticket),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _ClaimHeroInfoRow(
              label: l10n.ticketLabelLotteryNumber,
              value: ticket.number.isEmpty ? '-' : ticket.number,
            ),
            const SizedBox(height: 8),
            _ClaimHeroInfoRow(
              label: l10n.ticketLabelPrize,
              value: _ticketPrizeLinesWithAmounts(l10n, ticket),
              valueColor: colorScheme.primary,
            ),
            Divider(height: 18, color: colorScheme.outlineVariant),
            _ClaimHeroInfoRow(
              label: l10n.ticketLabelPrizeAmount,
              value: formatBaht(ticket.prizeAmount),
              valueColor: colorScheme.primary,
              valueSize: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _ClaimLotteryLogo extends ConsumerWidget {
  const _ClaimLotteryLogo();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final bootstrap = ref.watch(mobileBootstrapProvider).valueOrNull;
    final watermark = bootstrap?.ticketImageWatermark.trim() ?? '';
    final productLabel = bootstrap?.lotteryProductLabel.trim() ?? '';
    final marker = watermark.isNotEmpty
        ? watermark
        : productLabel.isNotEmpty
            ? productLabel
            : context.l10n.ticketImageGovernmentLotteryEnglish;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _ticketPrimaryTint(colorScheme)),
      ),
      child: SizedBox.square(
        dimension: 42,
        child: Center(
          child: Text(
            marker,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colorScheme.primary,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _ClaimHeroInfoRow extends StatelessWidget {
  const _ClaimHeroInfoRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.valueSize = 13,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final double valueSize;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveValueColor = valueColor ?? colorScheme.onSurface;
    final lines = value
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final line in lines.isEmpty ? ['-'] : lines)
                Text(
                  line,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: effectiveValueColor,
                    fontSize: valueSize,
                    fontWeight: FontWeight.w900,
                    height: 1.25,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ClaimSelectStep extends StatelessWidget {
  const _ClaimSelectStep({
    required this.ticket,
    required this.profile,
    required this.payoutMethod,
    required this.noticeMessage,
    required this.onMethodChanged,
    required this.onNext,
  });

  final CustomerTicket ticket;
  final CustomerProfileSettings? profile;
  final String payoutMethod;
  final String noticeMessage;
  final ValueChanged<String> onMethodChanged;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final bank = profile?.bankAccount;
    final l10n = context.l10n;
    return _ClaimStepScaffold(
      footer: FilledButton(
        onPressed: onNext,
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
        ),
        child: Text(l10n.commonNext),
      ),
      child: _TicketPageList(
        hero: _ClaimTicketHeroCard(ticket: ticket),
        heroHeight: 330,
        top: 12,
        bottom: _ClaimStepScaffold.footerSpace,
        children: [
          if (noticeMessage.isNotEmpty) ...[
            _TicketNoticePanel(message: noticeMessage),
            const SizedBox(height: 12),
          ],
          _ClaimPayoutCard(
            ticket: ticket,
            profile: profile,
            bank: bank,
            payoutMethod: payoutMethod,
            onMethodChanged: onMethodChanged,
          ),
        ],
      ),
    );
  }
}

class _ClaimPayoutCard extends StatelessWidget {
  const _ClaimPayoutCard({
    required this.ticket,
    required this.profile,
    required this.bank,
    required this.payoutMethod,
    required this.onMethodChanged,
  });

  final CustomerTicket ticket;
  final CustomerProfileSettings? profile;
  final RewardBankAccount? bank;
  final String payoutMethod;
  final ValueChanged<String> onMethodChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: const BoxDecoration(color: Colors.transparent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(
                bottom: BorderSide(color: colorScheme.outlineVariant),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
              child: Text(
                l10n.ticketClaimPayoutMethodTitle,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w900,
                      height: 1.25,
                    ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!ticket.canCreateClaim) ...[
                  _ClaimUnavailableAlert(
                    message: _ticketClaimUnavailableMessage(l10n, ticket),
                  ),
                  const SizedBox(height: 10),
                ],
                _PayoutOption(
                  selected: payoutMethod == 'wallet_credit',
                  enabled: ticket.canCreateClaim,
                  icon: Icons.account_balance_wallet_outlined,
                  title: _ticketClaimWalletOptionTitle(l10n, profile),
                  subtitle: l10n.ticketClaimWalletSubtitle,
                  onTap: () => onMethodChanged('wallet_credit'),
                ),
                const SizedBox(height: 10),
                _PayoutOption(
                  selected: payoutMethod == 'bank_transfer',
                  enabled: ticket.canCreateClaim && (bank?.isComplete ?? false),
                  icon: Icons.account_balance_outlined,
                  title: bank?.isComplete ?? false
                      ? _ticketClaimBankOptionTitle(l10n, bank!)
                      : l10n.ticketClaimBankTitle,
                  subtitle: bank?.isComplete ?? false
                      ? l10n.ticketClaimBankSubtitleReady
                      : l10n.ticketClaimBankSubtitleMissing,
                  badge: l10n.profileBadgeRecommended,
                  onTap: () => onMethodChanged('bank_transfer'),
                ),
                if (!(bank?.isComplete ?? false)) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => context.go(
                        '/profile/reward-bank?redirect=/tickets/claim/${ticket.id}',
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.primary,
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      child: Text(l10n.ticketClaimAddBank),
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
    required this.onConfirm,
  });

  final CustomerTicket ticket;
  final CustomerProfileSettings? profile;
  final String payoutMethod;
  final bool submitting;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final taxAmount = (ticket.prizeAmount * 0.005).round();
    final feeAmount = (ticket.prizeAmount * 0.01).round();
    return _ClaimStepScaffold(
      footer: FilledButton(
        onPressed: submitting ? null : onConfirm,
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
        ),
        child: Text(l10n.commonConfirm),
      ),
      child: _TicketPageList(
        bottom: _ClaimStepScaffold.footerSpace,
        children: [
          _ClaimConfirmCard(
            ticket: ticket,
            profile: profile,
            payoutMethod: payoutMethod,
            taxAmount: taxAmount,
            feeAmount: feeAmount,
          ),
        ],
      ),
    );
  }
}

class _ClaimConfirmCard extends StatelessWidget {
  const _ClaimConfirmCard({
    required this.ticket,
    required this.profile,
    required this.payoutMethod,
    required this.taxAmount,
    required this.feeAmount,
  });

  final CustomerTicket ticket;
  final CustomerProfileSettings? profile;
  final String payoutMethod;
  final int taxAmount;
  final int feeAmount;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _ticketPrimaryTint(colorScheme)),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const _ClaimLotteryLogo(),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.ticketLabelGovernmentLottery,
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        ticketDrawDateText(l10n, ticket),
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _TicketImageCard(ticket: ticket),
            const SizedBox(height: 14),
            _TicketInfoRow(
              label: l10n.ticketLabelRecipient,
              value: profile?.name ?? '-',
              emphasize: true,
            ),
            _TicketInfoRow(
              label: l10n.ticketLabelPayoutChannel,
              value: _payoutLabel(l10n, profile, payoutMethod),
              emphasize: true,
            ),
            _TicketInfoRow(
              label: l10n.rewardClaimMethodLabel,
              value: l10n.rewardClaimManualMethod,
              emphasize: true,
            ),
            _TicketInfoRow(
              label: l10n.ticketLabelLotteryNumber,
              value: ticket.number,
            ),
            _TicketInfoRow(
              label: l10n.ticketLabelPrize,
              value: _ticketPrizeLinesWithAmounts(l10n, ticket),
            ),
            Divider(height: 24, color: colorScheme.outlineVariant),
            _TicketInfoRow(
              label: l10n.ticketLabelPrizeAmount,
              value: formatBaht(ticket.prizeAmount),
              emphasize: true,
            ),
            _TicketInfoRow(
              label: l10n.rewardClaimTaxLabel,
              value: l10n.rewardClaimZeroBaht,
              discountOriginal: formatBaht(taxAmount),
              helper: l10n.rewardClaimWaived(formatBaht(taxAmount)),
              positive: true,
            ),
            _TicketInfoRow(
              label: l10n.rewardClaimFeeLabel,
              value: l10n.rewardClaimZeroBaht,
              discountOriginal: formatBaht(feeAmount),
              helper: l10n.rewardClaimWaived(formatBaht(feeAmount)),
              positive: true,
            ),
            Divider(height: 24, color: colorScheme.outlineVariant),
            _TicketInfoRow(
              label: l10n.ticketLabelNetAmount,
              value: formatBaht(ticket.prizeAmount),
              emphasize: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _ClaimPinStep extends StatelessWidget {
  const _ClaimPinStep({
    required this.pin,
    required this.error,
    required this.noticeMessage,
    required this.submitting,
    required this.biometricEnabled,
    required this.onDigit,
    required this.onBackspace,
    required this.onBiometric,
  });

  final String pin;
  final String error;
  final String noticeMessage;
  final bool submitting;
  final bool biometricEnabled;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onBiometric;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return _TicketPageList(
      maxWidth: 420,
      top: 18,
      children: [
        const SizedBox(height: 18),
        if (noticeMessage.isNotEmpty) ...[
          _TicketNoticePanel(message: noticeMessage),
          const SizedBox(height: 18),
        ],
        Center(
          child: Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _ticketPrimaryTint(colorScheme),
            ),
            child: Icon(
              Icons.lock_outline,
              size: 30,
              color: colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          l10n.ticketClaimEnterPin,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: colorScheme.onSurface,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                height: 1.22,
              ),
        ),
        const SizedBox(height: 20),
        _ClaimPinDots(length: pin.length, hasError: error.isNotEmpty),
        const SizedBox(height: 12),
        _ClaimPinMessage(
          error: error,
          submitting: submitting,
          submittingText: l10n.ticketClaimProcessingTitle,
        ),
        const SizedBox(height: 12),
        if (biometricEnabled) ...[
          TextButton.icon(
            onPressed: submitting ? null : onBiometric,
            icon: const Icon(Icons.face_retouching_natural),
            label: Text(l10n.pinUseBiometric),
            style: TextButton.styleFrom(
              foregroundColor: colorScheme.primary,
              textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        _ClaimPinKeypad(
          enabled: !submitting,
          onDigit: onDigit,
          onBackspace: onBackspace,
        ),
      ],
    );
  }
}

class _ClaimPinDots extends StatelessWidget {
  const _ClaimPinDots({required this.length, required this.hasError});

  final int length;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      label: '${'●' * length}${'○' * (6 - length)}',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var index = 0; index < 6; index += 1)
            AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOutCubic,
              width: 10,
              height: 10,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: index < length
                    ? hasError
                        ? colorScheme.error.withValues(alpha: 0.58)
                        : colorScheme.onSurface
                    : colorScheme.outlineVariant,
              ),
            ),
        ],
      ),
    );
  }
}

class _ClaimPinMessage extends StatelessWidget {
  const _ClaimPinMessage({
    required this.error,
    required this.submitting,
    required this.submittingText,
  });

  final String error;
  final bool submitting;
  final String submittingText;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final message = error.isNotEmpty
        ? error
        : submitting
            ? submittingText
            : '';
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 120),
      child: SizedBox(
        key: ValueKey(message),
        height: submitting ? 44 : 28,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (message.isNotEmpty)
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: error.isNotEmpty
                          ? colorScheme.error
                          : colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                      height: 1.35,
                    ),
              ),
            if (submitting) ...[
              const SizedBox(height: 8),
              CustomerLoadingMark(
                width: 96,
                height: 18,
                color: colorScheme.primary,
                trackColor: colorScheme.outlineVariant.withValues(alpha: 0.58),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ClaimPinKeypad extends StatelessWidget {
  const _ClaimPinKeypad({
    required this.enabled,
    required this.onDigit,
    required this.onBackspace,
  });

  final bool enabled;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', 'back'];
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: GridView.count(
          shrinkWrap: true,
          crossAxisCount: 3,
          mainAxisSpacing: 16,
          crossAxisSpacing: 24,
          childAspectRatio: 1.7,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final key in keys)
              if (key.isEmpty)
                const SizedBox.shrink()
              else
                Semantics(
                  button: true,
                  label: key == 'back' ? context.l10n.commonBack : key,
                  child: FilledButton.tonal(
                    onPressed: !enabled
                        ? null
                        : key == 'back'
                            ? onBackspace
                            : () => onDigit(key),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      disabledBackgroundColor: Colors.transparent,
                      foregroundColor: key == 'back'
                          ? colorScheme.onSurfaceVariant
                          : colorScheme.onSurface,
                      disabledForegroundColor:
                          colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                      shadowColor: Colors.transparent,
                      surfaceTintColor: Colors.transparent,
                      minimumSize: const Size(54, 42),
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: const CircleBorder(),
                      textStyle:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                                height: 1,
                              ),
                    ),
                    child: key == 'back'
                        ? const Icon(Icons.backspace_outlined, size: 21)
                        : Text(key),
                  ),
                ),
          ],
        ),
      ),
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
    final colorScheme = Theme.of(context).colorScheme;
    final bootstrap = ref.watch(mobileBootstrapProvider).valueOrNull;
    final productMarker = bootstrap?.lotteryProductLabel.trim() ?? '';
    final taxAmount = (ticket.prizeAmount * 0.005).round();
    final feeAmount = (ticket.prizeAmount * 0.01).round();
    final drawNumber = ticket.displayDrawNumber;
    final setNumber = ticket.displaySetNumber;
    return _ClaimStepScaffold(
      footer: FilledButton(
        onPressed: () => context.go('/tickets'),
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
        ),
        child: Text(l10n.ticketClaimViewMyTickets),
      ),
      child: _TicketPageList(
        bottom: _ClaimStepScaffold.footerSpace,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _ticketPrimaryTint(colorScheme)),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
              child: Column(
                children: [
                  _ClaimProcessingBrandHeader(productMarker: productMarker),
                  const SizedBox(height: 14),
                  const _ClaimProcessingStatusIcon(),
                  const SizedBox(height: 10),
                  Text(
                    l10n.ticketClaimProcessingTitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w900,
                          height: 1.25,
                        ),
                  ),
                  const SizedBox(height: 10),
                  _ClaimProcessingNote(
                    text: l10n.ticketClaimProcessingSubtitle,
                  ),
                  const SizedBox(height: 12),
                  _TicketInfoRow(
                    label: l10n.ticketLabelRecipient,
                    value: profile?.name ?? '-',
                    emphasize: true,
                  ),
                  _TicketInfoRow(
                    label: l10n.ticketLabelPayoutChannel,
                    value: _payoutLabel(l10n, profile, payoutMethod),
                    emphasize: true,
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
                  Divider(height: 22, color: colorScheme.outlineVariant),
                  _TicketInfoRow(
                    label: l10n.ticketLabelPrizeAmount,
                    value: formatBaht(ticket.prizeAmount),
                    emphasize: true,
                  ),
                  _TicketInfoRow(
                    label: l10n.rewardClaimTaxLabel,
                    value: l10n.rewardClaimZeroBaht,
                    discountOriginal: formatBaht(taxAmount),
                    helper: l10n.rewardClaimWaived(formatBaht(taxAmount)),
                    positive: true,
                  ),
                  _TicketInfoRow(
                    label: l10n.rewardClaimFeeLabel,
                    value: l10n.rewardClaimZeroBaht,
                    discountOriginal: formatBaht(feeAmount),
                    helper: l10n.rewardClaimWaived(formatBaht(feeAmount)),
                    positive: true,
                  ),
                  Divider(height: 22, color: colorScheme.outlineVariant),
                  _TicketInfoRow(
                    label: l10n.ticketLabelNetAmount,
                    value: formatBaht(ticket.prizeAmount),
                    emphasize: true,
                  ),
                  if (submittedClaim != null) ...[
                    Divider(height: 22, color: colorScheme.outlineVariant),
                    _TicketInfoRow(
                      label: l10n.ticketLabelSubmittedAt,
                      value: rewardClaimSubmittedText(l10n, submittedClaim!),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClaimProcessingStatusIcon extends StatelessWidget {
  const _ClaimProcessingStatusIcon();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primary,
        shape: BoxShape.circle,
      ),
      child: SizedBox.square(
        dimension: 52,
        child: Icon(
          Icons.schedule,
          color: colorScheme.onPrimary,
          size: 25,
        ),
      ),
    );
  }
}

class _ClaimProcessingNote extends StatelessWidget {
  const _ClaimProcessingNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w800,
                height: 1.45,
              ),
        ),
      ),
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

class _PayoutOption extends StatelessWidget {
  const _PayoutOption({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
    this.badge,
  });

  final bool selected;
  final bool enabled;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = colorScheme.primary;
    final badgeText = badge?.trim() ?? '';
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        constraints: const BoxConstraints(minHeight: 74),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? color
                : colorScheme.outlineVariant.withValues(alpha: 0.86),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.12),
                    spreadRadius: 1,
                  ),
                ]
              : null,
          color: colorScheme.surface,
        ),
        child: Row(
          children: [
            Container(
              width: 17,
              height: 17,
              decoration: BoxDecoration(
                color: selected ? color : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? color
                      : colorScheme.outlineVariant.withValues(alpha: 0.92),
                ),
              ),
              child: selected
                  ? Center(
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: colorScheme.onPrimary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          height: 1.25,
                        ),
                      ),
                      if (badgeText.isNotEmpty)
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: _ticketPrimaryTint(colorScheme),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            child: Text(
                              badgeText,
                              style: TextStyle(
                                color: colorScheme.primary,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                height: 1,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            DecoratedBox(
              decoration: BoxDecoration(
                color: selected
                    ? colorScheme.primary
                    : colorScheme.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: SizedBox.square(
                dimension: 40,
                child: Icon(
                  icon,
                  color: selected ? colorScheme.onPrimary : colorScheme.primary,
                  size: 20,
                ),
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
    return Tooltip(
      message: l10n.ticketImageOpenPreview,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => showDialog<void>(
            context: context,
            builder: (dialogContext) => _TicketImageDialog(ticket: ticket),
          ),
          child: Ink(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .outlineVariant
                    .withValues(alpha: 0.64),
              ),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context)
                      .colorScheme
                      .shadow
                      .withValues(alpha: 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
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

    final isCompact = MediaQuery.sizeOf(context).width <= 420;
    final horizontalPadding = isCompact ? 18.0 : 24.0;
    final topPadding = isCompact ? 20.0 : 24.0;
    final markerMaxWidth = isCompact ? 96.0 : 150.0;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isCompact ? 14 : 20,
        vertical: 24,
      ),
      clipBehavior: Clip.antiAlias,
      backgroundColor: colorScheme.surface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 530),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                topPadding,
                8,
                16,
              ),
              child: SizedBox(
                height: 46,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const TenantBrandHeader(
                          showName: false,
                          size: 46,
                          icon: Icons.confirmation_number_outlined,
                        ),
                        if (productMarker.isNotEmpty) ...[
                          const SizedBox(width: 14),
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: markerMaxWidth,
                            ),
                            child: Text(
                              productMarker,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    color: colorScheme.primary,
                                    fontSize: isCompact ? 30 : 34,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        tooltip: l10n.ticketImageClosePreview,
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                        iconSize: 30,
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                0,
                horizontalPadding,
                18,
              ),
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
              productName: productMarker.isEmpty
                  ? l10n.ticketLabelGovernmentLottery
                  : productMarker,
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
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.78),
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
        return ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Center(
            child: CustomerLoadingMark(
              width: 32,
              height: 20,
              semanticLabel: context.l10n.commonLoadingData,
            ),
          ),
        );
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
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFFF7FCFF),
            Color(0xFFFFF8DC),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _TicketImagePatternPainter(primary),
            ),
          ),
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
                    color: primary.withValues(alpha: 0.08),
                    fontSize: 82,
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
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 110),
                      child: Text(
                        productMarker,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w900,
                                ),
                      ),
                    ),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
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
                      size: 24,
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
                        const SizedBox(height: 4),
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
                              vertical: 4,
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
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 3,
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
          if (_ticketImageFallbackMessage(l10n, ticket).isNotEmpty)
            Align(
              alignment: Alignment.bottomLeft,
              child: _TicketImageErrorBadge(
                message: _ticketImageFallbackMessage(l10n, ticket),
              ),
            ),
        ],
      ),
    );
  }
}

class _TicketImagePatternPainter extends CustomPainter {
  const _TicketImagePatternPainter(this.primary);

  final Color primary;

  @override
  void paint(Canvas canvas, Size size) {
    final accentPaint = Paint()
      ..color = primary.withValues(alpha: 0.10)
      ..style = PaintingStyle.fill;
    final warmPaint = Paint()
      ..color = const Color(0xFFFFD200).withValues(alpha: 0.16)
      ..style = PaintingStyle.fill;
    final stripePaint = Paint()
      ..color = primary.withValues(alpha: 0.05)
      ..strokeWidth = 6;

    canvas.drawCircle(
      Offset(size.width * 0.12, size.height * 0.18),
      size.shortestSide * 0.20,
      accentPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.78, size.height * 0.30),
      size.shortestSide * 0.24,
      warmPaint,
    );

    for (var x = -size.height; x < size.width + size.height; x += 18) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        stripePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TicketImagePatternPainter oldDelegate) {
    return oldDelegate.primary != primary;
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
    final colorScheme = Theme.of(context).colorScheme;
    final noteColor = Color.alphaBlend(
      colorScheme.primary.withValues(alpha: 0.08),
      colorScheme.surface,
    );
    return ColoredBox(
      color: noteColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                siteName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colorScheme.onPrimary,
                      fontSize: 13,
                      height: 1.1,
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.ticketImageModalNote(siteName, productName),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 15,
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
  final status = ticket.imageStatus.trim().toLowerCase();
  return !{'pending_assets', 'missing', 'failed'}.contains(status);
}

String _ticketImageFallbackMessage(
  CustomerLocalizations l10n,
  CustomerTicket ticket,
) {
  final status = ticket.imageStatus.trim().toLowerCase();
  final error = ticket.imageError.trim();
  if (error.isNotEmpty) return error;
  if (status == 'pending_assets') return l10n.ticketImagePreparing;
  if (status == 'failed' || status == 'missing' || status == 'ready') {
    return l10n.ticketImageUnavailable;
  }
  return '';
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
    this.discountOriginal = '',
    this.helper = '',
    this.positive = false,
  });

  final String label;
  final String value;
  final bool emphasize;
  final String discountOriginal;
  final String helper;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final rawLines = value
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    final valueLines = rawLines.isEmpty ? ['-'] : rawLines;
    final hasDiscount = helper.isNotEmpty || discountOriginal.isNotEmpty;
    final valueColor = emphasize
        ? colorScheme.primary
        : positive
            ? colorScheme.tertiary
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
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (hasDiscount) ...[
                  Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 4,
                    runSpacing: 2,
                    children: [
                      if (discountOriginal.isNotEmpty)
                        Text(
                          discountOriginal,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.72,
                            ),
                            decoration: TextDecoration.lineThrough,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      if (helper.isNotEmpty)
                        Text(
                          helper,
                          textAlign: TextAlign.right,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                ],
                for (var index = 0; index < valueLines.length; index += 1)
                  Padding(
                    padding: EdgeInsets.only(
                      top: index == 0 ? 0 : 2,
                    ),
                    child: Text(
                      valueLines[index],
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontWeight:
                            emphasize ? FontWeight.w900 : FontWeight.w700,
                        color: valueColor,
                      ),
                    ),
                  ),
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
    return _TicketEmptyState(title: context.l10n.ticketsLoading);
  }
}

class _TicketErrorCard extends StatelessWidget {
  const _TicketErrorCard({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return _TicketEmptyState(
      title: message,
      danger: true,
      onRetry: onRetry,
    );
  }
}

class _TicketEmptyHistoryCard extends StatelessWidget {
  const _TicketEmptyHistoryCard();

  @override
  Widget build(BuildContext context) {
    return _TicketEmptyState(
      title: context.l10n.ticketHistoryEmptyTitle,
      subtitle: context.l10n.ticketHistoryEmptySubtitle,
    );
  }
}

class _TicketHistoryWinningEmptyCard extends StatelessWidget {
  const _TicketHistoryWinningEmptyCard();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _TicketEmptyState(
      title: l10n.ticketHistoryWinningEmptyTitle,
      subtitle: l10n.ticketHistoryWinningEmptySubtitle,
    );
  }
}

enum _ClaimStep { select, confirm, pin, processing }

Color _ticketStatusColor(BuildContext context, CustomerTicket ticket) {
  final colorScheme = Theme.of(context).colorScheme;
  final status = ticket.rewardStatus.status;
  final claimStatus = ticket.rewardStatus.claimStatus;
  if (status == 'paid' ||
      status == 'paid_out' ||
      status == 'claim_paid' ||
      claimStatus == 'paid' ||
      claimStatus == 'paid_out' ||
      claimStatus == 'claim_paid' ||
      ticket.status == 'paid') {
    return colorScheme.tertiary;
  }
  if (status == 'rejected' ||
      status == 'claim_rejected' ||
      claimStatus == 'rejected' ||
      claimStatus == 'claim_rejected' ||
      ticket.status == 'rejected') {
    return colorScheme.error;
  }
  if (status == 'cancelled' ||
      status == 'canceled' ||
      status == 'claim_cancelled' ||
      status == 'claim_canceled' ||
      claimStatus == 'cancelled' ||
      claimStatus == 'canceled' ||
      claimStatus == 'claim_cancelled' ||
      claimStatus == 'claim_canceled') {
    return colorScheme.error;
  }
  if (status == 'winning') return colorScheme.primary;
  if (status == 'non_winning') return colorScheme.outline;
  return colorScheme.primary;
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
    return '${bank.bankName}\n'
        '${l10n.ticketClaimBankAccountNumberLabel} '
        '${_ticketClaimMaskedBankAccount(bank.accountNumber)}';
  }
  return _ticketClaimWalletOptionTitle(l10n, profile);
}

String _ticketClaimWalletOptionTitle(
  CustomerLocalizations l10n,
  CustomerProfileSettings? profile,
) {
  final suffix = _ticketClaimWalletSuffix(profile?.walletId ?? '');
  if (suffix.isEmpty) return l10n.ticketClaimWalletTitle;
  return l10n.ticketClaimWalletAccountTitle(suffix);
}

String _ticketClaimWalletSuffix(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return '';
  final suffix =
      digits.length <= 3 ? digits : digits.substring(digits.length - 3);
  return suffix.padLeft(3, '0');
}

String _ticketClaimBankOptionTitle(
  CustomerLocalizations l10n,
  RewardBankAccount bank,
) {
  final bankName = bank.bankName.trim();
  final displayName = bankName.isEmpty
      ? l10n.ticketClaimBankTitle
      : bankName.replaceFirst(RegExp(r'^ธนาคาร'), 'บัญชี');
  return '$displayName x ${_ticketClaimAccountLast4(bank.accountNumber)}';
}

String _ticketClaimAccountLast4(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return '----';
  return digits.length <= 4 ? digits : digits.substring(digits.length - 4);
}

String _ticketClaimMaskedBankAccount(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return 'x xxx9';
  if (digits.length <= 4) return digits;
  return 'x xxx${digits.substring(digits.length - 4)}';
}
