import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/customer_localizations.dart';
import '../../../core/navigation/customer_back_navigation.dart';
import '../../../core/security/biometric_auth_service.dart';
import '../../../core/tenant/mobile_bootstrap_controller.dart';
import '../../../core/tenant/mobile_runtime_policy.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/api_errors.dart';
import '../../../core/utils/asset_url.dart';
import '../../../core/utils/formatters.dart';
import '../../../features/profile/data/profile_settings_models.dart';
import '../../../features/profile/data/profile_settings_repository.dart';
import '../../../shared/utils/customer_operational_error.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/async/async_state_view.dart';
import '../../../shared/widgets/customer_fixed_header_layout.dart';
import '../../../shared/widgets/customer_gradient_button.dart';
import '../../../shared/widgets/customer_loading_indicator.dart';
import '../../../shared/widgets/customer_page_body.dart';
import '../../../shared/widgets/pin_confirmation_step.dart';
import '../../../shared/widgets/tenant_brand_header.dart';
import '../../lottery/presentation/lottery_digit_input_row.dart';
import '../../results/data/result_models.dart';
import '../data/ticket_models.dart';
import '../data/ticket_repository.dart';
import 'ticket_localization.dart';

Color _ticketPrimaryTint(ColorScheme colorScheme) =>
    Color.lerp(colorScheme.primary, colorScheme.surface, 0.88) ??
    colorScheme.primary.withValues(alpha: 0.12);

Color _ticketTone(ColorScheme colorScheme, Color color, double surfaceMix) =>
    Color.lerp(color, colorScheme.surface, surfaceMix) ?? color;

Color _ticketWarmText(ColorScheme colorScheme, double surfaceMix) =>
    Color.lerp(
      colorScheme.onTertiaryContainer,
      colorScheme.onSurface,
      surfaceMix,
    ) ??
    colorScheme.onTertiaryContainer;

const double _ticketContentSheetOverlapMin = 34;
const double _ticketContentSheetOverlapMax = 64;

double _ticketContentSheetOverlapFor(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  return (width * 0.15)
      .clamp(_ticketContentSheetOverlapMin, _ticketContentSheetOverlapMax)
      .toDouble();
}

double _ticketContentMaxWidthFor(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width >= 1280) return 1080;
  if (width >= 768) return 720;
  return customerContentMaxWidthMobile;
}

List<CustomerTicket> _currentTicketsForGame(
  List<CustomerTicket> tickets,
  CurrentGame? game,
) {
  final gameId = game?.id.trim() ?? '';
  if (gameId.isEmpty) return tickets;
  if (!tickets.any((ticket) => ticket.gameId.trim().isNotEmpty)) {
    return tickets;
  }
  return tickets
      .where((ticket) => ticket.gameId.trim() == gameId)
      .toList(growable: false);
}

String _currentTicketDrawDate(
  CustomerLocalizations l10n,
  CurrentGame? game,
  List<CustomerTicket> tickets,
) {
  if (game != null) {
    final drawAtDate = formatLotteryDrawDateText(
      name: '',
      drawAt: game.drawAt,
      localeTag: l10n.locale.toLanguageTag(),
    );
    if (drawAtDate != '-') return drawAtDate;
    final nameDate = formatLotteryDrawDateText(
      name: game.name,
      drawAt: null,
      localeTag: l10n.locale.toLanguageTag(),
    );
    if (nameDate != '-') return nameDate;
  }
  for (final ticket in tickets) {
    final drawDate = ticketDrawDateText(l10n, ticket);
    if (drawDate != '-') return drawDate;
  }
  return '-';
}

List<String> _ticketQueryDigits(Map<String, String> query) {
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

bool _ticketQueryHasSearchInput(Map<String, String> query) {
  return _ticketQueryDigits(query).any((digit) => digit.isNotEmpty);
}

String _ticketSearchPath(List<String> digits) {
  final query = <String, String>{};
  for (var index = 0; index < 6; index++) {
    final value = index >= digits.length
        ? ''
        : digits[index].replaceAll(RegExp(r'\D'), '');
    if (value.isNotEmpty) query['d${index + 1}'] = value.substring(0, 1);
  }
  return Uri(
    path: '/tickets/search',
    queryParameters: query.isEmpty ? null : query,
  ).toString();
}

bool _ticketMatchesDigits(CustomerTicket ticket, List<String> digits) {
  final number = ticket.number.replaceAll(RegExp(r'\D'), '');
  if (number.length < 6) return false;
  for (var index = 0; index < 6; index++) {
    final digit = index >= digits.length ? '' : digits[index];
    if (digit.isNotEmpty && number[index] != digit) return false;
  }
  return true;
}

ButtonStyle _ticketFlatButtonStyle(ButtonStyle style) {
  return style.copyWith(
    overlayColor: const WidgetStatePropertyAll(Colors.transparent),
  );
}

class TicketsScreen extends ConsumerStatefulWidget {
  const TicketsScreen({super.key});

  @override
  ConsumerState<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends ConsumerState<TicketsScreen> {
  _TicketRouteTab _currentTab = _TicketRouteTab.current;

  @override
  Widget build(BuildContext context) {
    if (_currentTab == _TicketRouteTab.history) {
      return TicketHistoryScreen(onCurrentTab: _showCurrentTab);
    }

    listenForCustomerOperationalError<List<CustomerTicket>>(
      ref: ref,
      context: context,
      provider: currentTicketsProvider,
    );
    listenForCustomerOperationalError<CurrentGame?>(
      ref: ref,
      context: context,
      provider: currentTicketGameProvider,
    );
    final tickets = ref.watch(currentTicketsProvider);
    final currentGame = ref.watch(currentTicketGameProvider);
    final resolvedGame = currentGame.valueOrNull;
    final l10n = context.l10n;

    return AppShell(
      title: l10n.ticketsTitle,
      currentPath: '/tickets',
      sensitive: true,
      showBottomNavigation: true,
      fullScreen: true,
      child: _TicketPageList(
        hero: _TicketRouteHeroContent(
          title: l10n.ticketsTitle,
          current: _TicketRouteTab.current,
          searchTooltip: l10n.ticketsSearchNumbers,
          onSearch: () => context.go('/tickets/search'),
          onHistoryTab: _showHistoryTab,
        ),
        children: [
          tickets.when(
            loading: () => _CurrentTicketsState(
              tickets: const [],
              game: resolvedGame,
              child: const _TicketLoadingList(),
            ),
            error: (error, _) => _CurrentTicketsState(
              tickets: const [],
              game: resolvedGame,
              child: _TicketErrorCard(
                message: _ticketErrorMessage(error, l10n.ticketsLoadFailed),
              ),
            ),
            data: (items) {
              if (currentGame.isLoading) {
                return _CurrentTicketsState(
                  tickets: const [],
                  game: null,
                  child: const _TicketLoadingList(),
                );
              }
              final displayTickets = _currentTicketsForGame(
                items,
                resolvedGame,
              );
              final winningTicketCount = _winningTicketCount(displayTickets);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _CurrentTicketSummary(
                    tickets: displayTickets,
                    game: resolvedGame,
                  ),
                  const SizedBox(height: 24),
                  if (winningTicketCount > 0) ...[
                    _WinningTicketBanner(count: winningTicketCount),
                    const SizedBox(height: 16),
                  ],
                  if (displayTickets.isEmpty)
                    const _EmptyTicketsCard()
                  else ...[
                    _TicketTileList(tickets: displayTickets),
                    const _TicketAllLoadedText(),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          const _TicketFooterNote(),
        ],
      ),
    );
  }

  int _winningTicketCount(List<CustomerTicket> tickets) {
    return tickets.fold<int>(0, (total, ticket) {
      return total + (_isWinningTicket(ticket) ? ticket.count : 0);
    });
  }

  bool _isWinningTicket(CustomerTicket ticket) => _ticketIsWinning(ticket);

  void _showCurrentTab() {
    setState(() => _currentTab = _TicketRouteTab.current);
  }

  void _showHistoryTab() {
    setState(() => _currentTab = _TicketRouteTab.history);
  }
}

class _CurrentTicketsState extends StatelessWidget {
  const _CurrentTicketsState({
    required this.tickets,
    required this.game,
    required this.child,
  });

  final List<CustomerTicket> tickets;
  final CurrentGame? game;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CurrentTicketSummary(tickets: tickets, game: game),
        const SizedBox(height: 24),
        child,
      ],
    );
  }
}

class TicketsSearchScreen extends ConsumerStatefulWidget {
  const TicketsSearchScreen({super.key, required this.query});

  final Map<String, String> query;

  @override
  ConsumerState<TicketsSearchScreen> createState() =>
      _TicketsSearchScreenState();
}

class _TicketsSearchScreenState extends ConsumerState<TicketsSearchScreen> {
  late final List<TextEditingController> _digits;
  late bool _submitted;

  @override
  void initState() {
    super.initState();
    _digits = List.generate(6, (_) => TextEditingController());
    _submitted = _ticketQueryHasSearchInput(widget.query);
    _syncDigitsFromQuery();
  }

  @override
  void didUpdateWidget(covariant TicketsSearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query.toString() == widget.query.toString()) return;
    _submitted = _ticketQueryHasSearchInput(widget.query);
    _syncDigitsFromQuery();
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
    listenForCustomerOperationalError<List<CustomerTicket>>(
      ref: ref,
      context: context,
      provider: currentTicketsProvider,
    );
    listenForCustomerOperationalError<CurrentGame?>(
      ref: ref,
      context: context,
      provider: currentTicketGameProvider,
    );
    final l10n = context.l10n;
    final tickets = ref.watch(currentTicketsProvider);
    final currentGame = ref.watch(currentTicketGameProvider);
    final resolvedGame = currentGame.valueOrNull;
    final activeDigits = _ticketQueryDigits(widget.query);
    final drawDate = _currentTicketDrawDate(
      l10n,
      resolvedGame,
      tickets.valueOrNull ?? const [],
    );
    final loading = tickets.isLoading || currentGame.isLoading;

    return AppShell(
      title: l10n.ticketsSearchNumbers,
      currentPath: '/tickets/search',
      backPath: '/tickets',
      sensitive: true,
      showBottomNavigation: false,
      heroMinHeight: customerReferenceCompactHeroHeight,
      heroSheetOverlap: 0,
      heroContent: const SizedBox.shrink(),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _TicketSearchContentSheet(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      l10n.ticketsSearchPlaceholder,
                      style: _ticketSearchSectionTitleStyle(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    key: const ValueKey('ticket-search-clear'),
                    onPressed: loading ? null : _clearDigits,
                    style: _ticketSearchLinkStyle(context),
                    child: Text(l10n.lotteryClearButton),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                drawDate == '-'
                    ? l10n.countdownCurrentDrawFallback
                    : '${l10n.ticketsDrawDateLabel} $drawDate',
                key: const ValueKey('ticket-search-draw-date'),
                style: _ticketSearchDrawDateStyle(context),
              ),
              const SizedBox(height: 20),
              LotteryDigitInputRow(
                key: const ValueKey('ticket-search-digit-inputs'),
                controllers: _digits,
                onSubmitted: _submitDigits,
                style: _ticketSearchDigitBoxesStyle(context),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: CustomerGradientButton.text(
                  key: const ValueKey('ticket-search-submit'),
                  onPressed: loading ? null : _submitDigits,
                  height: 54,
                  fontSize: 17,
                  label: loading
                      ? l10n.lotterySearchLoading
                      : l10n.lotterySearchButton,
                ),
              ),
              if (!_submitted) ...[
                const SizedBox(height: 31),
                _TicketSearchInitialHint(
                  message: l10n.lotterySearchInitialHint,
                ),
              ],
              if (_submitted) ...[
                const Divider(height: 34),
                Text(
                  l10n.lotterySearchResultsTitle,
                  style: _ticketSearchSectionTitleStyle(context),
                ),
                const SizedBox(height: 16),
                tickets.when(
                  loading: () => const _TicketLoadingList(),
                  error: (error, _) => _TicketErrorCard(
                    message: _ticketErrorMessage(error, l10n.ticketsLoadFailed),
                  ),
                  data: (items) {
                    if (currentGame.isLoading) {
                      return const _TicketLoadingList();
                    }
                    final currentItems = _currentTicketsForGame(
                      items,
                      resolvedGame,
                    );
                    final results = currentItems
                        .where(
                          (ticket) =>
                              _ticketMatchesDigits(ticket, activeDigits),
                        )
                        .toList(growable: false);
                    if (results.isEmpty) {
                      return const _TicketSearchEmptyCard();
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _TicketTileList(tickets: results),
                        const _TicketAllLoadedText(),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _submitDigits() {
    final path = _ticketSearchPath(
      _digits.map((controller) => controller.text).toList(growable: false),
    );
    setState(() => _submitted = true);
    context.go(path);
  }

  void _clearDigits() {
    for (final controller in _digits) {
      controller.clear();
    }
    setState(() => _submitted = false);
    context.go('/tickets/search');
  }

  void _syncDigitsFromQuery() {
    final values = _ticketQueryDigits(widget.query);
    for (var index = 0; index < _digits.length; index++) {
      if (_digits[index].text != values[index]) {
        _digits[index].text = values[index];
      }
    }
  }
}

class _TicketSearchContentSheet extends StatelessWidget {
  const _TicketSearchContentSheet({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: CustomerPageBody(
        top: 18,
        bottom: 128,
        mobileHorizontal: 18,
        wideHorizontal: 0,
        minViewportHeight: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

class _TicketSearchInitialHint extends StatelessWidget {
  const _TicketSearchInitialHint({required this.message});

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

TextStyle? _ticketSearchSectionTitleStyle(BuildContext context) {
  final theme = Theme.of(context);
  return theme.textTheme.titleLarge?.copyWith(
    color: theme.colorScheme.onSurface,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );
}

TextStyle? _ticketSearchDrawDateStyle(BuildContext context) {
  final theme = Theme.of(context);
  return theme.textTheme.titleMedium?.copyWith(
    color: theme.colorScheme.onSurface,
    fontSize: 20,
    fontWeight: FontWeight.w400,
    height: 1.2,
  );
}

LotteryDigitInputStyle _ticketSearchDigitBoxesStyle(BuildContext context) {
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

ButtonStyle _ticketSearchLinkStyle(BuildContext context) {
  final primary = Theme.of(context).colorScheme.primary;
  return TextButton.styleFrom(
    foregroundColor: AppTheme.primaryLink(primary),
    minimumSize: const Size(0, 36),
    padding: EdgeInsets.zero,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    visualDensity: VisualDensity.compact,
    textStyle: const TextStyle(fontWeight: FontWeight.w600),
  ).copyWith(overlayColor: const WidgetStatePropertyAll(Colors.transparent));
}

class _CurrentTicketSummary extends StatelessWidget {
  const _CurrentTicketSummary({required this.tickets, required this.game});

  final List<CustomerTicket> tickets;
  final CurrentGame? game;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final drawDate = _currentTicketDrawDate(l10n, game, tickets);
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
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          drawDate,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 3),
        Text(
          l10n.ticketsTotalCount(totalTicketCount),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _WinningTicketBanner extends StatelessWidget {
  const _WinningTicketBanner({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            _ticketTone(colorScheme, colorScheme.tertiary, 0.76),
            _ticketTone(colorScheme, colorScheme.tertiary, 0.58),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: colorScheme.tertiary.withValues(alpha: 0.12),
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
                        color: colorScheme.onTertiaryContainer,
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.ticketsWinningBannerMessage(count),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _ticketWarmText(colorScheme, 0.16),
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
                  color: colorScheme.surface.withValues(alpha: 0.48),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.monetization_on_outlined,
                  color: colorScheme.tertiary,
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
    return _TicketEmptyState(title: context.l10n.ticketsSearchEmptyTitle);
  }
}

enum _TicketRouteTab { current, history }

class _TicketRouteHeroContent extends StatelessWidget {
  const _TicketRouteHeroContent({
    required this.title,
    required this.current,
    this.searchTooltip,
    this.onSearch,
    this.onCurrentTab,
    this.onHistoryTab,
  });

  final String title;
  final _TicketRouteTab current;
  final String? searchTooltip;
  final VoidCallback? onSearch;
  final VoidCallback? onCurrentTab;
  final VoidCallback? onHistoryTab;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 42,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 54),
                  child: Center(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: colorScheme.onPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                    ),
                  ),
                ),
              ),
              if (onSearch != null)
                Positioned(
                  top: 4,
                  right: 0,
                  child: IconButton(
                    key: const ValueKey('tickets-search-action'),
                    tooltip: searchTooltip,
                    onPressed: onSearch,
                    icon: const Icon(Icons.search, size: 24),
                    style:
                        IconButton.styleFrom(
                          fixedSize: const Size.square(42),
                          backgroundColor: colorScheme.surface.withValues(
                            alpha: 0.92,
                          ),
                          foregroundColor: colorScheme.primary,
                          shadowColor: colorScheme.shadow.withValues(
                            alpha: 0.16,
                          ),
                          elevation: 10,
                          shape: const CircleBorder(),
                          padding: EdgeInsets.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ).copyWith(
                          overlayColor: const WidgetStatePropertyAll(
                            Colors.transparent,
                          ),
                        ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _TicketRouteTabs(
          current: current,
          onCurrentTab: onCurrentTab,
          onHistoryTab: onHistoryTab,
        ),
      ],
    );
  }
}

class _TicketRouteTabs extends StatelessWidget {
  const _TicketRouteTabs({
    required this.current,
    this.onCurrentTab,
    this.onHistoryTab,
  });

  final _TicketRouteTab current;
  final VoidCallback? onCurrentTab;
  final VoidCallback? onHistoryTab;

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
                    final callback = onCurrentTab;
                    if (callback == null) {
                      context.go('/tickets');
                    } else {
                      callback();
                    }
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
                    final callback = onHistoryTab;
                    if (callback == null) {
                      context.go('/tickets/history');
                    } else {
                      callback();
                    }
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
                    AppTheme.ticketTabStart(colorScheme.primary),
                    AppTheme.ticketTabEnd(colorScheme.primary),
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
          splashFactory: NoSplash.splashFactory,
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          onTap: onTap,
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontSize: 16,
                color: selected ? colorScheme.onPrimary : colorScheme.onSurface,
                fontWeight: FontWeight.w600,
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
    final colorScheme = theme.colorScheme;
    final actionLabel = showOnlyWinning
        ? l10n.ticketHistoryShowAll
        : l10n.ticketHistoryShowWinning;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            l10n.ticketHistoryListTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              color: colorScheme.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: TextButton(
            onPressed: onToggle,
            style: _ticketFlatButtonStyle(
              TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 44),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: colorScheme.primary,
                textStyle: theme.textTheme.titleSmall?.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  showOnlyWinning ? Icons.list_alt : Icons.playlist_add_check,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    actionLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      decoration: TextDecoration.underline,
                      decorationColor: colorScheme.primary,
                      decorationThickness: 1.5,
                    ),
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

class _TicketHistoryOverview extends StatelessWidget {
  const _TicketHistoryOverview({required this.groups, required this.itemCount});

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
    final label = l10n.ticketHistoryPastTicketsLabel;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
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
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  height: 1.18,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppTheme.ticketCountFill(
              Theme.of(context).colorScheme.primary,
            ),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Text(
              l10n.ticketHistoryItemCount(itemCount),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppTheme.ticketCountText(
                  Theme.of(context).colorScheme.primary,
                ),
                fontSize: 13,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TicketHistorySummaryBanner extends StatelessWidget {
  const _TicketHistorySummaryBanner({required this.winningTicketCount});

  final int winningTicketCount;

  @override
  Widget build(BuildContext context) {
    final hasWinningTickets = winningTicketCount > 0;
    final message = hasWinningTickets
        ? context.l10n.ticketHistoryWinningSummary(winningTicketCount)
        : context.l10n.ticketHistoryNoWinningSummary;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0xFFDFFFE9), Color(0xFFFFF6CF)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF198754),
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Icon(
                Icons.auto_awesome_rounded,
                color: Color(0xFFFFC107),
                size: 40,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TicketPageList extends StatelessWidget {
  const _TicketPageList({
    required this.children,
    this.hero,
    this.top = 18,
    this.bottom = _bottomPadding,
    this.controller,
    this.physics,
  });

  static const _heroHeight = 253.0;
  static const _sheetOverlap = -1.0;
  static const _bottomPadding = 120.0;
  static const _cacheExtent = 900.0;

  final List<Widget> children;
  final Widget? hero;
  final double top;
  final double bottom;
  final ScrollController? controller;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    final hero = this.hero;
    final effectiveMaxWidth = _ticketContentMaxWidthFor(context);
    if (hero == null) {
      return ListView(
        controller: controller,
        physics: physics,
        // ignore: deprecated_member_use
        cacheExtent: _cacheExtent,
        children: [
          CustomerPageBody(
            maxWidth: effectiveMaxWidth,
            top: top,
            bottom: bottom,
            mobileHorizontal: 18,
            minViewportHeight: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      );
    }

    final colorScheme = Theme.of(context).colorScheme;
    final effectiveSheetOverlap = _sheetOverlap < 0
        ? _ticketContentSheetOverlapFor(context)
        : _sheetOverlap;
    return CustomerFixedHeaderLayout(
      headerKey: const ValueKey('ticket-fixed-header'),
      contentRegionKey: const ValueKey('ticket-content-region'),
      headerHeight: _heroHeight,
      contentOverlap: effectiveSheetOverlap,
      contentTopRadius: customerContentSheetTopRadius,
      contentBackdropColor: colorScheme.primary,
      header: _TicketHeroBand(
        maxWidth: effectiveMaxWidth,
        height: _heroHeight,
        child: hero,
      ),
      content: ListView(
        key: const ValueKey('ticket-content-scroll'),
        padding: EdgeInsets.zero,
        controller: controller,
        physics: physics,
        // ignore: deprecated_member_use
        cacheExtent: _cacheExtent,
        children: [
          DecoratedBox(
            key: const ValueKey('ticket-content-sheet'),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.07),
                  blurRadius: 24,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: CustomerPageBody(
              maxWidth: effectiveMaxWidth,
              top: top,
              bottom: bottom,
              mobileHorizontal: 18,
              minViewportHeight: true,
              alignment: Alignment.topCenter,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
        ],
      ),
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
    final topInset = MediaQuery.paddingOf(context).top;
    final topPadding = topInset + 14 < 58 ? 58.0 : topInset + 14;
    return SizedBox(
      height: height,
      child: CustomerBlueHeroBackdrop(
        primary: colorScheme.primary,
        secondary: colorScheme.secondary,
        child: CustomerPageBody(
          maxWidth: maxWidth,
          top: isLargeHero ? topInset + 32 : topPadding,
          bottom: isLargeHero ? 30 : 24,
          child: Align(
            alignment: isLargeHero
                ? Alignment.bottomCenter
                : Alignment.topCenter,
            child: child,
          ),
        ),
      ),
    );
  }
}

class _EmptyTicketsCard extends StatelessWidget {
  const _EmptyTicketsCard();

  @override
  Widget build(BuildContext context) {
    return _TicketEmptyState(title: context.l10n.ticketsEmptyTitle);
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
          fontWeight: FontWeight.w500,
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
      padding: const EdgeInsets.only(top: 16),
      child: Text(
        context.l10n.commonAllLoaded,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
          height: 1.35,
        ),
      ),
    );
  }
}

class _TicketNoticePanel extends StatelessWidget {
  const _TicketNoticePanel({required this.message});

  final String message;

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
          ],
        ),
      ),
    );
  }
}

class _TicketEmptyState extends StatelessWidget {
  const _TicketEmptyState({
    required this.title,
    this.danger = false,
    this.onRetry,
  });

  final String title;
  final bool danger;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = danger ? colorScheme.error : colorScheme.onSurfaceVariant;

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
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: onRetry,
              style: _ticketFlatButtonStyle(OutlinedButton.styleFrom()),
              child: Text(context.l10n.commonRetry),
            ),
          ],
        ],
      ),
    );
  }
}

class _TicketTileList extends StatelessWidget {
  const _TicketTileList({required this.tickets, this.fromHistory = false});

  final List<CustomerTicket> tickets;
  final bool fromHistory;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < tickets.length; index++) ...[
          if (index > 0) const SizedBox(height: 16),
          _TicketTile(
            ticket: tickets[index],
            fromHistory: fromHistory,
            openImagePreview: true,
          ),
        ],
      ],
    );
  }
}

class _TicketTile extends StatelessWidget {
  const _TicketTile({
    required this.ticket,
    this.fromHistory = false,
    this.openDetail = true,
    this.openImagePreview = false,
  });

  final CustomerTicket ticket;
  final bool fromHistory;
  final bool openDetail;
  final bool openImagePreview;

  @override
  Widget build(BuildContext context) {
    final statusColor = _ticketStatusColor(ticket);
    final l10n = context.l10n;
    final number = ticket.number.isEmpty
        ? context.l10n.ticketsNumberFallback
        : ticket.number;
    final isWinning = _ticketIsWinning(ticket);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final claimPath = _ticketStubClaimPath(ticket, fromHistory: fromHistory);
    const sideRailTextColor = Color(0xFF7547C8);
    const sideRailColors = [Color(0xFFF0E9FF), Color(0xFFF0E9FF)];
    const winningSideRailColors = [Color(0xFFF7F1FF), Color(0xFFD9CCFF)];
    final VoidCallback? openTicket;
    if (!openDetail) {
      openTicket = null;
    } else if (openImagePreview) {
      openTicket = () => _showTicketImageDialog(context, ticket);
    } else if (ticket.id.isEmpty) {
      openTicket = null;
    } else {
      openTicket = () => context.go(
        '/tickets/view?id=${Uri.encodeComponent(ticket.id)}'
        '${fromHistory ? '&from=history' : ''}',
      );
    }

    return Semantics(
      key: ValueKey(
        'ticket-tile-${fromHistory ? 'history' : 'current'}-'
        '${ticket.id.isNotEmpty ? ticket.id : number}-$number',
      ),
      button: openTicket != null,
      label: '${l10n.ticketLabelGovernmentLottery} $number',
      child: Material(
        color: Colors.transparent,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: (isWinning ? statusColor : colorScheme.shadow)
                    .withValues(alpha: isWinning ? 0.18 : 0.12),
                blurRadius: isWinning ? 22 : 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _TicketStubPatternPainter(
                      color: colorScheme.primary.withValues(alpha: 0.055),
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        splashFactory: NoSplash.splashFactory,
                        overlayColor: const WidgetStatePropertyAll(
                          Colors.transparent,
                        ),
                        onTap: openTicket,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 86),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 12, 30, 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  width: 48,
                                  child: _TicketStubPriceBlock(),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _TicketStubBody(number: number),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 60,
                                  child: Text(
                                    ticketStatusLabel(l10n, ticket),
                                    textAlign: TextAlign.center,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: textTheme.labelMedium?.copyWith(
                                      fontSize: 13,
                                      color: statusColor,
                                      fontWeight: FontWeight.w700,
                                      height: 1.15,
                                    ),
                                  ),
                                ),
                              ],
                            ),
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
                              ? winningSideRailColors
                              : sideRailColors,
                        ),
                      ),
                      child: RotatedBox(
                        quarterTurns: 1,
                        child: Text(
                          l10n.ticketStubDigitalLabel,
                          maxLines: 1,
                          style: textTheme.labelSmall?.copyWith(
                            color: sideRailTextColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
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

class _TicketStubBody extends StatelessWidget {
  const _TicketStubBody({required this.number});

  final String number;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.ticketLabelGovernmentLottery,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurface,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            height: 1,
          ),
        ),
        const SizedBox(height: 6),
        _TicketStubNumber(number: number),
      ],
    );
  }
}

class _TicketStubProductMark extends ConsumerWidget {
  const _TicketStubProductMark();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final configuredLabel =
        ref.watch(mobileBootstrapProvider).valueOrNull?.lotteryProductLabel ??
        '';
    final productLabel = configuredLabel.trim().isEmpty
        ? l10n.ticketStubSeriesLabel
        : configuredLabel.trim();

    return SizedBox(
      width: 38,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              productLabel,
              style: textTheme.titleMedium?.copyWith(
                color: colorScheme.primary,
                fontSize: 23,
                fontWeight: FontWeight.w900,
                height: 1,
                letterSpacing: 0,
              ),
            ),
            Transform.translate(
              offset: const Offset(-3, 4),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.tertiary,
                  shape: BoxShape.circle,
                ),
                child: const SizedBox.square(dimension: 6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TicketStubPriceBlock extends StatelessWidget {
  const _TicketStubPriceBlock();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final priceColor =
        Color.lerp(colorScheme.error, colorScheme.surface, 0.24) ??
        colorScheme.error;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 62),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _TicketStubProductMark(),
          const SizedBox(height: 3),
          Text(
            context.l10n.ticketStubPriceLabel,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: priceColor,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              height: 0.92,
            ),
          ),
        ],
      ),
    );
  }
}

class _TicketStubPatternPainter extends CustomPainter {
  const _TicketStubPatternPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    for (var start = -size.height; start < size.width; start += 7) {
      canvas.drawLine(
        Offset(start, size.height),
        Offset(start + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TicketStubPatternPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _TicketStubNumber extends StatelessWidget {
  const _TicketStubNumber({required this.number});

  final String number;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final numberFill =
        Color.lerp(colorScheme.tertiary, colorScheme.surface, 0.84) ??
        colorScheme.tertiaryContainer;
    final digits = number.replaceAll(RegExp(r'\D'), '');
    return DecoratedBox(
      decoration: BoxDecoration(
        color: numberFill,
        borderRadius: BorderRadius.circular(7),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 136),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: digits.length == 6
              ? Row(
                  children: [
                    for (final digit in digits.split(''))
                      Expanded(
                        child: Text(
                          digit,
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: colorScheme.onSurface,
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0,
                                height: 1,
                              ),
                        ),
                      ),
                  ],
                )
              : FittedBox(
                  alignment: Alignment.centerLeft,
                  fit: BoxFit.scaleDown,
                  child: Text(
                    number,
                    maxLines: 1,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurface,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                      height: 1,
                    ),
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
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _ticketTone(colorScheme, colorScheme.tertiary, 0.74),
            _ticketTone(colorScheme, colorScheme.tertiary, 0.48),
          ],
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
                      color: colorScheme.onTertiaryContainer,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                  if (ticket.prizes.length > 1)
                    for (final prize in ticket.prizes)
                      Text(
                        '${ticketPrizeTypeLabel(l10n, prize.prizeType)} '
                        '${formatTicketBaht(l10n, prize.amount)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.labelSmall?.copyWith(
                          color: _ticketWarmText(colorScheme, 0.08),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                        ),
                      )
                  else if (ticket.prizeAmount > 0)
                    Text(
                      l10n.ticketStubPrizeAmount(
                        formatTicketBaht(l10n, ticket.prizeAmount),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.labelSmall?.copyWith(
                        color: _ticketWarmText(colorScheme, 0.20),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
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
              onPressed: actionPath.isEmpty
                  ? null
                  : () => context.go(actionPath),
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
    final colorScheme = Theme.of(context).colorScheme;
    return Opacity(
      opacity: enabled ? 1 : 0.62,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          splashFactory: NoSplash.splashFactory,
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 78, minHeight: 28),
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    _ticketTone(colorScheme, colorScheme.tertiary, 0.36),
                    colorScheme.tertiary,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.tertiary.withValues(alpha: 0.22),
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
                  color: colorScheme.onTertiaryContainer,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
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
  const TicketHistoryScreen({super.key, this.onCurrentTab});

  final VoidCallback? onCurrentTab;

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
      showBottomNavigation: true,
      fullScreen: true,
      child: _TicketPageList(
        hero: _TicketRouteHeroContent(
          title: l10n.ticketsTitle,
          current: _TicketRouteTab.history,
          onCurrentTab: widget.onCurrentTab,
        ),
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (_loadingInitial)
            const _TicketLoadingList()
          else if (_error.isNotEmpty)
            _TicketErrorCard(message: _error)
          else if (_tickets.isEmpty)
            const _TicketEmptyHistoryCard()
          else ...[
            _TicketHistoryFilterHeader(
              showOnlyWinning: _showOnlyWinning,
              onToggle: () =>
                  setState(() => _showOnlyWinning = !_showOnlyWinning),
            ),
            const Divider(height: 33),
            _TicketHistoryOverview(
              groups: ticketGroups,
              itemCount: _tickets.length,
            ),
            const SizedBox(height: 16),
            _TicketHistorySummaryBanner(winningTicketCount: winningTicketCount),
            const SizedBox(height: 24),
            if (visibleTickets.isEmpty)
              const _TicketHistoryWinningEmptyCard()
            else
              for (var index = 0; index < visibleTicketGroups.length; index++)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: index == visibleTicketGroups.length - 1 ? 0 : 18,
                  ),
                  child: _TicketHistoryDrawGroup(
                    group: visibleTicketGroups[index],
                  ),
                ),
            if (_loadMoreError.isNotEmpty) ...[
              _TicketEmptyState(title: _loadMoreError, danger: true),
            ] else if (_loadingMore)
              _TicketEmptyState(title: l10n.ticketHistoryLoadingMore)
            else if (_hasMore)
              const SizedBox(height: 1)
            else if (_tickets.isNotEmpty && !_loadingMore)
              const _TicketAllLoadedText(),
          ],
        ],
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
      if (await handleCustomerOperationalError(
        ref: ref,
        context: context,
        error: error,
      )) {
        return;
      }
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
      final page = await ref
          .read(ticketRepositoryProvider)
          .history(cursor: cursor);
      if (!mounted) return;
      setState(() {
        _tickets.addAll(page.items);
        _cursor = page.nextCursor;
        _hasMore = page.hasMore;
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

    return Column(
      key: ValueKey('ticket-history-group-${group.key}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Text(
                l10n.ticketHistoryGroupDrawDate,
                style: textTheme.labelLarge?.copyWith(
                  color: const Color(0xFF7B8798),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  group.drawDate,
                  key: ValueKey('ticket-history-group-date-${group.key}'),
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall?.copyWith(
                    color: const Color(0xFF193767),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
        _TicketTileList(tickets: group.tickets, fromHistory: true),
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

final _ticketViewLookupProvider = FutureProvider.autoDispose
    .family<CustomerTicket?, _TicketViewLookup>((ref, lookup) async {
      final repository = ref.watch(ticketRepositoryProvider);
      if (lookup.ticketId.isNotEmpty) {
        return repository.detail(lookup.ticketId);
      }

      final tickets = <CustomerTicket>[];
      if (lookup.fromHistory) {
        String? cursor;
        for (
          var pageNumber = 0;
          pageNumber < TicketRepository.maxAutoPages;
          pageNumber++
        ) {
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
  int get hashCode =>
      Object.hash(ticketId, ticketNumber, orderId, gameId, fromHistory);
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
    final lookup = _TicketViewLookup(
      ticketId: ticketId,
      ticketNumber: ticketNumber,
      orderId: orderId,
      gameId: gameId,
      fromHistory: fromHistory,
    );
    listenForCustomerOperationalError<CustomerTicket?>(
      ref: ref,
      context: context,
      provider: _ticketViewLookupProvider(lookup),
    );
    final ticket = ref.watch(_ticketViewLookupProvider(lookup));
    return AppShell(
      title: context.l10n.ticketDetailTitle,
      currentPath: '/tickets',
      sensitive: true,
      showBottomNavigation: true,
      fullScreen: true,
      child: _TicketPageList(
        hero: _TicketRouteHeroContent(
          title: context.l10n.ticketsTitle,
          current: fromHistory
              ? _TicketRouteTab.history
              : _TicketRouteTab.current,
        ),
        children: [
          AsyncStateView(
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
        ],
      ),
    );
  }
}

class _TicketDetailContent extends StatelessWidget {
  const _TicketDetailContent({required this.ticket, required this.fromHistory});

  final CustomerTicket ticket;
  final bool fromHistory;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        Text(
          l10n.ticketImageDigitalNumberLabel,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            _ticketDisplayNumber(ticket),
            maxLines: 1,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
              height: 1,
            ),
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
    final statusColor = _ticketStatusColor(ticket);
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
            _TicketInfoRow(label: l10n.ticketLabelDraw, value: ticket.gameName),
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
                value: formatTicketBaht(l10n, ticket.prizeAmount),
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
                      label:
                          '${ticketPrizeTypeLabel(l10n, prize.prizeType)} '
                          '${formatTicketBaht(l10n, prize.amount)}',
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
    if (_step == _ClaimStep.pin) {
      return PinConfirmationStep(
        title: l10n.ticketClaimPinTitle,
        subtitle: l10n.pinDescription,
        pin: _pin,
        error: _pinError.isNotEmpty ? _pinError : _claimNoticeMessage,
        saving: _submitting,
        biometricEnabled: ref
            .watch(mobileBootstrapProvider)
            .maybeWhen(
              data: (data) => mobileBiometricAllowedForPlatform(
                data,
                ref.watch(customerPlatformKeyProvider),
              ),
              orElse: () => false,
            ),
        biometricLabel: l10n.pinUseBiometric,
        onBack: () => _handleBack(backPath),
        onDigit: _appendPinDigit,
        onBackspace: _removePinDigit,
        onBiometric: _submitClaimWithBiometric,
      );
    }

    final selectStep = _step == _ClaimStep.select;
    final processingStep = _step == _ClaimStep.processing;
    final ticket = _ticket;
    return AppShell(
      title: processingStep
          ? ''
          : switch (_step) {
              _ClaimStep.confirm => l10n.ticketClaimConfirmTitle,
              _ => l10n.ticketClaimTitle,
            },
      currentPath: '/tickets',
      sensitive: true,
      showBottomNavigation: false,
      automaticallyImplyBack: false,
      onBack: processingStep ? null : () => _handleBack(backPath),
      heroContent: selectStep && ticket != null
          ? _ClaimTicketHeroCard(ticket: ticket)
          : const SizedBox.shrink(),
      heroMinHeight: selectStep
          ? 306
          : processingStep
          ? 176
          : 150,
      heroSheetOverlap: selectStep
          ? 0
          : processingStep
          ? 122
          : 34,
      heroContentTopGap: selectStep ? 10 : 0,
      heroHeaderVariant: CustomerHeroHeaderVariant.rewardFlow,
      child: ClipRRect(
        borderRadius: selectStep || processingStep
            ? BorderRadius.zero
            : const BorderRadius.vertical(top: Radius.circular(18)),
        child: ColoredBox(
          color: selectStep
              ? const Color(0xFFF2F3F5)
              : Theme.of(context).colorScheme.surface,
          child: _buildBody(context),
        ),
      ),
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
    navigateCustomerBack(context, fallbackPath: backPath);
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const _TicketPageList(children: [_TicketClaimLoadingState()]);
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
      _ClaimStep.pin => const SizedBox.shrink(),
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
      final ticket = await ref
          .read(ticketRepositoryProvider)
          .detail(widget.ticketId);
      TicketRewardStatus? rewardStatus;
      try {
        rewardStatus = await ref
            .read(ticketRepositoryProvider)
            .rewardStatus(widget.ticketId);
      } catch (error) {
        if (ApiErrorInfo.fromObject(error).operationalRedirectPath != null) {
          rethrow;
        }
        rewardStatus = null;
      }
      CustomerProfileSettings? profile;
      try {
        profile = await ref.read(profileSettingsRepositoryProvider).load();
      } catch (error) {
        if (ApiErrorInfo.fromObject(error).operationalRedirectPath != null) {
          rethrow;
        }
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
                          'amount': {'amount': (prize.amount * 100).round()},
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
      if (await handleCustomerOperationalError(
        ref: ref,
        context: context,
        error: error,
      )) {
        return;
      }
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
      final claim = await ref
          .read(ticketRepositoryProvider)
          .createRewardClaim(
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
        _claimNoticeMessage = pinError.isEmpty
            ? _ticketErrorMessage(error, failedMessage)
            : '';
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
      final token = await ref
          .read(biometricAuthServiceProvider)
          .requestPinAssertion(
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
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
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
            CustomerGradientButton.text(
              onPressed: onOpen,
              height: 48,
              fontSize: 15,
              shadow: false,
              label: l10n.ticketClaimViewClaim,
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
  const _ClaimStepScaffold({required this.child, required this.footer});

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
              value: formatTicketBaht(l10n, ticket.prizeAmount),
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
      footer: CustomerGradientButton.text(
        onPressed: onNext,
        height: 48,
        fontSize: 15,
        shadow: false,
        label: l10n.commonNext,
      ),
      child: _TicketPageList(
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
                  subtitle: l10n.ticketClaimWalletSubtitleFor(
                    profile?.walletName ?? '',
                  ),
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
          (prize) =>
              '${ticketPrizeTypeLabel(l10n, prize.prizeType)} '
              '${formatTicketBaht(l10n, prize.amount)}',
        )
        .join('\n');
  }

  final summary = ticketPrizeSummary(l10n, ticket);
  if (ticket.prizeAmount > 0) {
    return '$summary ${formatTicketBaht(l10n, ticket.prizeAmount)}';
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
      footer: CustomerGradientButton.text(
        onPressed: submitting ? null : onConfirm,
        height: 48,
        fontSize: 15,
        shadow: false,
        label: l10n.commonConfirm,
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
              value: formatTicketBaht(l10n, ticket.prizeAmount),
              emphasize: true,
            ),
            _TicketInfoRow(
              label: l10n.rewardClaimTaxLabel,
              value: l10n.rewardClaimZeroBaht,
              discountOriginal: formatTicketBaht(l10n, taxAmount),
              helper: l10n.rewardClaimWaived(formatTicketBaht(l10n, taxAmount)),
              positive: true,
            ),
            _TicketInfoRow(
              label: l10n.rewardClaimFeeLabel,
              value: l10n.rewardClaimZeroBaht,
              discountOriginal: formatTicketBaht(l10n, feeAmount),
              helper: l10n.rewardClaimWaived(formatTicketBaht(l10n, feeAmount)),
              positive: true,
            ),
            Divider(height: 24, color: colorScheme.outlineVariant),
            _TicketInfoRow(
              label: l10n.ticketLabelNetAmount,
              value: formatTicketBaht(l10n, ticket.prizeAmount),
              emphasize: true,
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
    final productMarker = _ticketProductMarkerLabel(context, bootstrap);
    final taxAmount = (ticket.prizeAmount * 0.005).round();
    final feeAmount = (ticket.prizeAmount * 0.01).round();
    final drawNumber = ticket.displayDrawNumber;
    final setNumber = ticket.displaySetNumber;
    return _ClaimStepScaffold(
      footer: CustomerGradientButton.text(
        onPressed: () => context.go('/tickets'),
        height: 48,
        fontSize: 15,
        shadow: false,
        label: l10n.ticketClaimViewMyTickets,
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
                    value: formatTicketBaht(l10n, ticket.prizeAmount),
                    emphasize: true,
                  ),
                  _TicketInfoRow(
                    label: l10n.rewardClaimTaxLabel,
                    value: l10n.rewardClaimZeroBaht,
                    discountOriginal: formatTicketBaht(l10n, taxAmount),
                    helper: l10n.rewardClaimWaived(
                      formatTicketBaht(l10n, taxAmount),
                    ),
                    positive: true,
                  ),
                  _TicketInfoRow(
                    label: l10n.rewardClaimFeeLabel,
                    value: l10n.rewardClaimZeroBaht,
                    discountOriginal: formatTicketBaht(l10n, feeAmount),
                    helper: l10n.rewardClaimWaived(
                      formatTicketBaht(l10n, feeAmount),
                    ),
                    positive: true,
                  ),
                  Divider(height: 22, color: colorScheme.outlineVariant),
                  _TicketInfoRow(
                    label: l10n.ticketLabelNetAmount,
                    value: formatTicketBaht(l10n, ticket.prizeAmount),
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
        child: Icon(Icons.schedule, color: colorScheme.onPrimary, size: 25),
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
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
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
    final productMarker = _ticketProductMarkerLabel(context, bootstrap);
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
          splashFactory: NoSplash.splashFactory,
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          onTap: () => _showTicketImageDialog(context, ticket),
          child: Ink(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.outlineVariant.withValues(alpha: 0.64),
              ),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(
                    context,
                  ).colorScheme.shadow.withValues(alpha: 0.08),
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

Future<void> _showTicketImageDialog(
  BuildContext context,
  CustomerTicket ticket,
) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.68),
    builder: (dialogContext) => _TicketImageDialog(ticket: ticket),
  );
}

class _TicketImageDialog extends ConsumerWidget {
  const _TicketImageDialog({required this.ticket});

  final CustomerTicket ticket;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolver = ref.watch(assetUrlResolverProvider);
    final bootstrap = ref.watch(mobileBootstrapProvider).valueOrNull;
    final productMarker = _ticketProductMarkerLabel(context, bootstrap);
    final ticketImageWatermark =
        bootstrap?.ticketImageWatermark.trim() ?? productMarker;
    final siteName = bootstrap?.siteName.trim() ?? '';
    final brandLogoSource = bootstrap?.brand.logoUrl.trim() ?? '';
    final brandLogoUrl = brandLogoSource.isEmpty
        ? ''
        : resolver(brandLogoSource);
    final supportLabel = bootstrap?.supportPhone.trim() ?? '';
    final url = resolver(ticket.primaryImageUrl);
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;

    final isCompact = MediaQuery.sizeOf(context).width <= 420;
    final horizontalPadding = isCompact ? 18.0 : 24.0;
    final topPadding = isCompact ? 20.0 : 24.0;
    final markerMaxWidth = isCompact ? 96.0 : 150.0;
    final dialogHorizontalInset = isCompact ? 14.0 : 20.0;
    final dialogVerticalInset = isCompact ? 14.0 : 20.0;
    final maxDialogHeight =
        MediaQuery.sizeOf(context).height - (dialogVerticalInset * 2);

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: dialogHorizontalInset,
        vertical: dialogVerticalInset,
      ),
      clipBehavior: Clip.antiAlias,
      backgroundColor: colorScheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 530, maxHeight: maxDialogHeight),
        child: SingleChildScrollView(
          padding: EdgeInsets.zero,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  topPadding,
                  horizontalPadding,
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
                          _TicketModalBrandLockup(
                            logoUrl: brandLogoUrl,
                            fallbackLabel: l10n.ticketImageBrandFallback,
                            siteName: siteName,
                            supportLabel: supportLabel.isEmpty
                                ? l10n.ticketImageGovernmentLotteryEnglish
                                : supportLabel,
                          ),
                          if (productMarker.isNotEmpty) ...[
                            const SizedBox(width: 14),
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: markerMaxWidth,
                              ),
                              child: _TicketModalProductMark(
                                label: productMarker,
                                fontSize: isCompact ? 30 : 34,
                              ),
                            ),
                          ],
                        ],
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          tooltip: l10n.ticketImageClosePreview,
                          style:
                              IconButton.styleFrom(
                                fixedSize: const Size.square(32),
                                foregroundColor: colorScheme.onSurface,
                                padding: EdgeInsets.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ).copyWith(
                                overlayColor: const WidgetStatePropertyAll(
                                  Colors.transparent,
                                ),
                              ),
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                          iconSize: 30,
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
                siteName: siteName.isEmpty
                    ? l10n.ticketImageTenantFallback
                    : siteName,
                productName: productMarker.isEmpty
                    ? l10n.ticketLabelGovernmentLottery
                    : productMarker,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TicketModalBrandLockup extends StatelessWidget {
  const _TicketModalBrandLockup({
    required this.logoUrl,
    required this.fallbackLabel,
    required this.siteName,
    required this.supportLabel,
  });

  final String logoUrl;
  final String fallbackLabel;
  final String siteName;
  final String supportLabel;

  @override
  Widget build(BuildContext context) {
    final normalizedLogoUrl = logoUrl.trim();
    if (normalizedLogoUrl.isNotEmpty) {
      return SizedBox(
        width: 96,
        height: 46,
        child: _TicketModalBrandImage(
          logoUrl: normalizedLogoUrl,
          fallbackLabel: fallbackLabel,
          siteName: siteName,
          supportLabel: supportLabel,
        ),
      );
    }

    return _TicketModalBrandFallback(
      label: fallbackLabel,
      siteName: siteName,
      supportLabel: supportLabel,
    );
  }
}

class _TicketModalBrandImage extends StatelessWidget {
  const _TicketModalBrandImage({
    required this.logoUrl,
    required this.fallbackLabel,
    required this.siteName,
    required this.supportLabel,
  });

  final String logoUrl;
  final String fallbackLabel;
  final String siteName;
  final String supportLabel;

  @override
  Widget build(BuildContext context) {
    final bytes = _dataImageBytes(logoUrl);
    final fallback = _TicketModalBrandFallback(
      label: fallbackLabel,
      siteName: siteName,
      supportLabel: supportLabel,
    );

    if (bytes != null) {
      return Image.memory(
        bytes,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => fallback,
      );
    }

    return Image.network(
      logoUrl,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => fallback,
    );
  }
}

class _TicketModalBrandFallback extends StatelessWidget {
  const _TicketModalBrandFallback({
    required this.label,
    required this.siteName,
    required this.supportLabel,
  });

  final String label;
  final String siteName;
  final String supportLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final secondaryLines = [
      if (siteName.trim().isNotEmpty) siteName.trim(),
      if (supportLabel.trim().isNotEmpty) supportLabel.trim(),
    ];

    return Semantics(
      label: label,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 96),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: colorScheme.primary,
                fontSize: 31,
                fontWeight: FontWeight.w800,
                height: 0.82,
                letterSpacing: 0,
              ),
            ),
            if (secondaryLines.isNotEmpty)
              Text(
                secondaryLines.join('\n'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.primary,
                  fontSize: 5.5,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                  letterSpacing: 0,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TicketModalProductMark extends StatelessWidget {
  const _TicketModalProductMark({required this.label, required this.fontSize});

  final String label;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            label,
            maxLines: 1,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: colorScheme.primary,
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              height: 0.95,
              letterSpacing: 0,
            ),
          ),
          Transform.translate(
            offset: const Offset(-5, -1),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.tertiary,
                shape: BoxShape.circle,
              ),
              child: const SizedBox.square(dimension: 8),
            ),
          ),
        ],
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
    final colorScheme = Theme.of(context).colorScheme;
    final primary = colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.surface,
            _ticketTone(colorScheme, colorScheme.primary, 0.96),
            _ticketTone(colorScheme, colorScheme.tertiary, 0.82),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _TicketImagePatternPainter(
                primary: colorScheme.primary,
                tertiary: colorScheme.tertiary,
              ),
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
          Positioned.fill(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: SizedBox(
                width: 460,
                height: 248,
                child: Column(
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
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      fontWeight: FontWeight.w900,
                                    ),
                              ),
                              Text(
                                l10n.ticketImageGovernmentLotteryEnglish,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
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
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
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
                            color: colorScheme.surface.withValues(alpha: 0.78),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.22),
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
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w900,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      _ticketTone(
                                        colorScheme,
                                        colorScheme.tertiary,
                                        0.70,
                                      ),
                                      _ticketTone(
                                        colorScheme,
                                        colorScheme.tertiary,
                                        0.44,
                                      ),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: colorScheme.tertiary.withValues(
                                      alpha: 0.50,
                                    ),
                                  ),
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
                                                  color: colorScheme.onSurface,
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
              ),
            ),
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
  const _TicketImagePatternPainter({
    required this.primary,
    required this.tertiary,
  });

  final Color primary;
  final Color tertiary;

  @override
  void paint(Canvas canvas, Size size) {
    final accentPaint = Paint()
      ..color = primary.withValues(alpha: 0.10)
      ..style = PaintingStyle.fill;
    final warmPaint = Paint()
      ..color = tertiary.withValues(alpha: 0.16)
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
    return oldDelegate.primary != primary || oldDelegate.tertiary != tertiary;
  }
}

class _TicketImageMetaPill extends StatelessWidget {
  const _TicketImageMetaPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
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
  const _TicketImageNote({required this.siteName, required this.productName});

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

String _ticketProductMarkerLabel(
  BuildContext context,
  MobileBootstrap? bootstrap,
) {
  final configured = bootstrap?.lotteryProductLabel.trim() ?? '';
  if (configured.isNotEmpty) return configured;
  final localized = context.l10n.ticketStubSeriesLabel.trim();
  if (localized.isNotEmpty) return localized;
  return context.l10n.ticketImageDigitalType.trim();
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
              style: TextStyle(color: colorScheme.onSurfaceVariant),
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
                    padding: EdgeInsets.only(top: index == 0 ? 0 : 2),
                    child: Text(
                      valueLines[index],
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontWeight: emphasize
                            ? FontWeight.w900
                            : FontWeight.w700,
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
    return _TicketEmptyState(title: message, danger: true, onRetry: onRetry);
  }
}

class _TicketEmptyHistoryCard extends StatelessWidget {
  const _TicketEmptyHistoryCard();

  @override
  Widget build(BuildContext context) {
    return _TicketEmptyState(title: context.l10n.ticketHistoryEmptyTitle);
  }
}

class _TicketHistoryWinningEmptyCard extends StatelessWidget {
  const _TicketHistoryWinningEmptyCard();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _TicketEmptyState(title: l10n.ticketHistoryWinningEmptyTitle);
  }
}

enum _ClaimStep { select, confirm, pin, processing }

Color _ticketStatusColor(CustomerTicket ticket) {
  final status = ticket.rewardStatus.status;
  final claimStatus = ticket.rewardStatus.claimStatus;
  if (status == 'paid' ||
      status == 'paid_out' ||
      status == 'claim_paid' ||
      claimStatus == 'paid' ||
      claimStatus == 'paid_out' ||
      claimStatus == 'claim_paid' ||
      ticket.status == 'paid') {
    return const Color(0xFF16A34A);
  }
  if (status == 'rejected' ||
      status == 'claim_rejected' ||
      claimStatus == 'rejected' ||
      claimStatus == 'claim_rejected' ||
      ticket.status == 'rejected') {
    return const Color(0xFFDC2626);
  }
  if (status == 'cancelled' ||
      status == 'canceled' ||
      status == 'claim_cancelled' ||
      status == 'claim_canceled' ||
      claimStatus == 'cancelled' ||
      claimStatus == 'canceled' ||
      claimStatus == 'claim_cancelled' ||
      claimStatus == 'claim_canceled') {
    return const Color(0xFFDC2626);
  }
  if (_ticketIsWinning(ticket)) return const Color(0xFFB07108);
  return const Color(0xFF8B8F96);
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
  final walletName = profile?.walletName ?? '';
  final suffix = _ticketClaimWalletSuffix(profile?.walletId ?? '');
  if (suffix.isEmpty) return l10n.ticketClaimWalletTitleFor(walletName);
  return l10n.ticketClaimWalletAccountTitle(suffix, walletName: walletName);
}

String _ticketClaimWalletSuffix(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return '';
  final suffix = digits.length <= 3
      ? digits
      : digits.substring(digits.length - 3);
  return suffix.padLeft(3, '0');
}

String _ticketClaimBankOptionTitle(
  CustomerLocalizations l10n,
  RewardBankAccount bank,
) {
  final bankName = bank.bankName.trim();
  if (bankName.isEmpty) return l10n.ticketClaimBankTitle;
  return l10n.claimBankOptionTitle(
    bankName,
    _ticketClaimAccountLast4(bank.accountNumber),
  );
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
