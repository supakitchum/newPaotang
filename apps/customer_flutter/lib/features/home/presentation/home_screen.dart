import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/i18n/app_locale.dart';
import '../../../core/i18n/customer_localizations.dart';
import '../../../core/navigation/customer_link_launcher.dart';
import '../../../core/utils/formatters.dart';
import '../../../features/activities/data/activity_models.dart';
import '../../../features/activities/data/activity_repository.dart';
import '../../../features/activities/presentation/activity_localization.dart';
import '../../../features/lottery/presentation/lottery_digit_input_row.dart';
import '../../../features/lottery/presentation/lottery_navigation.dart';
import '../../../features/lottery/presentation/lottery_screens.dart'
    show
        earliestActiveReservation,
        formatReservationCountdown,
        reservationDeadlineExpired,
        reservationRemainingDuration;
import '../../../features/lottery/data/lottery_models.dart';
import '../../../features/lottery/data/lottery_repository.dart';
import '../../../features/news/data/news_models.dart';
import '../../../features/news/data/news_repository.dart';
import '../../../features/news/presentation/news_card.dart';
import '../../../features/news/presentation/news_link_target.dart';
import '../../../features/results/data/result_models.dart';
import '../../../features/results/data/result_repository.dart';
import '../../../features/results/presentation/result_widgets.dart';
import '../../../features/wallet/data/wallet_repository.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/async/async_state_view.dart';
import '../../../shared/widgets/customer_loading_indicator.dart';
import '../../../shared/widgets/customer_page_body.dart';
import '../../../shared/widgets/customer_section_header.dart';
import '../../../shared/widgets/customer_wallet_card.dart';
import '../../../shared/widgets/tenant_brand_header.dart';

final _homeCartProvider = FutureProvider.autoDispose<LotteryCart>((ref) async {
  final auth = ref.watch(authControllerProvider);
  if (!auth.isAuthenticated || auth.pinRequired) {
    return LotteryCart.empty();
  }
  return ref.watch(lotteryRepositoryProvider).cart();
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final wallet =
        auth.isAuthenticated ? ref.watch(walletSummaryProvider) : null;
    final activities = ref.watch(activityListProvider);
    final news = ref.watch(newsListProvider);
    final result = ref.watch(currentResultProvider);
    final cart =
        ref.watch(_homeCartProvider).valueOrNull ?? LotteryCart.empty();
    final showCartDock = _homeCartSelectionEnabled(cart);
    final l10n = context.l10n;

    return AppShell(
      title: l10n.homeTitle,
      currentPath: '/',
      sensitive: true,
      fullScreen: true,
      child: Stack(
        children: [
          Positioned.fill(
            child: _HomePageList(
              hero: _HomeLotteryHero(value: result),
              bottom: showCartDock ? 236 : 116,
              children: [
                const _HomeQuickActionPanel(),
                const SizedBox(height: 16),
                if (wallet == null) ...[
                  const _HomeGuestPanel(),
                ] else ...[
                  AsyncStateView(
                    value: wallet,
                    data: (summary) => CustomerWalletBalanceCard(
                      balance: summary.balance,
                      title: l10n.commonWalletBalance,
                      onOpenWallet: () => context.go('/my-wallet'),
                      actions: _walletCardActions(context),
                      compact: true,
                    ),
                    empty: CustomerWalletBalanceCard(
                      balance: 0,
                      title: l10n.commonWalletBalance,
                      onOpenWallet: () => context.go('/my-wallet'),
                      actions: _walletCardActions(context),
                      compact: true,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                _ActivitiesRail(value: activities),
                const SizedBox(height: 18),
                _HomeResultSection(value: result),
                _NewsRail(value: news),
              ],
            ),
          ),
          if (showCartDock)
            Positioned(
              left: 0,
              right: 0,
              bottom: 86,
              child: _HomeFloatingCartDock(
                cart: cart,
                onCheckout: () => context.go('/checkout'),
              ),
            ),
        ],
      ),
    );
  }
}

bool _homeCartSelectionEnabled(LotteryCart cart) {
  if (cart.reservationIds.isEmpty) return false;
  final deadline = earliestActiveReservation(cart.reservations);
  return deadline == null || !reservationDeadlineExpired(deadline);
}

class _HomeFloatingCartDock extends StatelessWidget {
  const _HomeFloatingCartDock({
    required this.cart,
    required this.onCheckout,
  });

  final LotteryCart cart;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final deadline = earliestActiveReservation(cart.reservations);
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.symmetric(horizontal: 18),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: DecoratedBox(
            key: const ValueKey('home-cart-payment-dock'),
            decoration: _homeSurfaceDecoration(context, radius: 12).copyWith(
              border: Border.all(color: Colors.transparent),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, -8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.cartSelectionTitle,
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: _homeTitleColor(context),
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.ticketsCount(cart.itemCount),
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.w900,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 144,
                      maxWidth: 176,
                      minHeight: 58,
                    ),
                    child: DecoratedBox(
                      decoration: _homeDockButtonDecoration(context),
                      child: SizedBox(
                        height: 58,
                        child: FilledButton(
                          onPressed: onCheckout,
                          style: _homeDockButtonStyle(context),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(l10n.cartCheckout),
                              if (deadline != null)
                                _HomeCartCountdownText(deadline: deadline),
                            ],
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
      ),
    );
  }
}

class _HomeCartCountdownText extends StatefulWidget {
  const _HomeCartCountdownText({required this.deadline});

  final LotteryReservation deadline;

  @override
  State<_HomeCartCountdownText> createState() => _HomeCartCountdownTextState();
}

class _HomeCartCountdownTextState extends State<_HomeCartCountdownText> {
  late DateTime _fallbackExpiresAt;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _fallbackExpiresAt = DateTime.now().add(
      Duration(seconds: widget.deadline.expiresInSeconds),
    );
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant _HomeCartCountdownText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deadline.id != widget.deadline.id ||
        oldWidget.deadline.expiresAt != widget.deadline.expiresAt ||
        oldWidget.deadline.expiresInSeconds !=
            widget.deadline.expiresInSeconds) {
      _fallbackExpiresAt = DateTime.now().add(
        Duration(seconds: widget.deadline.expiresInSeconds),
      );
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = reservationRemainingDuration(
      widget.deadline,
      now: DateTime.now(),
      fallbackExpiresAt:
          widget.deadline.expiresInSeconds > 0 ? _fallbackExpiresAt : null,
    );
    if (remaining.inSeconds <= 0) return const SizedBox.shrink();
    final l10n = context.l10n;
    return Text(
      l10n.cartSelectionTimer(formatReservationCountdown(remaining)),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color:
                Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.92),
            fontWeight: FontWeight.w700,
            height: 1.1,
          ),
    );
  }
}

class _HomePageList extends StatelessWidget {
  const _HomePageList({
    required this.hero,
    required this.children,
    required this.bottom,
  });

  final Widget hero;
  final List<Widget> children;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Stack(
          children: [
            SizedBox(height: _homeHeroHeight, child: hero),
            Padding(
              padding: const EdgeInsets.only(
                top: _homeHeroHeight - _homeSheetOverlap,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(34),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.08),
                      blurRadius: 28,
                      offset: const Offset(0, -8),
                    ),
                  ],
                ),
                child: CustomerPageBody(
                  top: 23,
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

class _HomeLotteryHero extends StatefulWidget {
  const _HomeLotteryHero({required this.value});

  final AsyncValue<RewardResultBundle> value;

  @override
  State<_HomeLotteryHero> createState() => _HomeLotteryHeroState();
}

class _HomeLotteryHeroState extends State<_HomeLotteryHero> {
  late final _digits = List.generate(
    6,
    (index) => TextEditingController(text: '${index + 1}'),
  );

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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final currentGame = widget.value.maybeWhen(
      data: (bundle) => bundle.currentGame,
      orElse: () => null,
    );
    final drawText = _drawText(context, currentGame);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary,
            Color.lerp(colorScheme.primary, colorScheme.secondary, 0.48) ??
                colorScheme.primary,
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -28,
            bottom: -20,
            child: Container(
              width: 144,
              height: 144,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.tertiary.withValues(alpha: 0.86),
              ),
            ),
          ),
          Positioned(
            left: -58,
            top: 18,
            child: Transform.rotate(
              angle: -0.55,
              child: Container(
                width: 260,
                height: 92,
                decoration: BoxDecoration(
                  color: colorScheme.onPrimary.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(50),
                ),
              ),
            ),
          ),
          Positioned(
            right: 34,
            top: 112,
            child: Transform.rotate(
              angle: 0.22,
              child: Container(
                width: 150,
                height: 46,
                decoration: BoxDecoration(
                  color: colorScheme.onPrimary.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: _homeHeroHeight),
            child: CustomerPageBody(
              top: MediaQuery.paddingOf(context).top + 12,
              bottom: 56,
              mobileHorizontal: 20,
              wideHorizontal: 28,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _HomeHeroTopRow(),
                  const SizedBox(height: 22),
                  Text(
                    l10n.homeProductTitle,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.w900,
                      height: 1.02,
                    ),
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 320;
                      final searchCopy = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  l10n.lotterySearchHeroTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: colorScheme.onPrimary,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 5),
                              Icon(
                                Icons.info_outline,
                                size: 16,
                                color: colorScheme.onPrimary
                                    .withValues(alpha: 0.88),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            drawText,
                            maxLines: compact ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color:
                                  colorScheme.onPrimary.withValues(alpha: 0.90),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      );

                      if (compact) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            searchCopy,
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: _HomeSaleBadge(
                                label: l10n.homeSaleLabel,
                                amount: l10n.homeSaleAmount,
                              ),
                            ),
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: searchCopy),
                          const SizedBox(width: 12),
                          _HomeSaleBadge(
                            label: l10n.homeSaleLabel,
                            amount: l10n.homeSaleAmount,
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                  LotteryDigitInputRow(
                    controllers: _digits,
                    readOnly: true,
                    onTap: _goSearch,
                    onSubmitted: _goSearch,
                    style: LotteryDigitInputStyle(
                      borderRadius: 12,
                      spacing: 8,
                      fillColor: colorScheme.surface,
                      hintColor: colorScheme.onSurface.withValues(alpha: 0.20),
                      focusedBorderColor: colorScheme.tertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _drawText(BuildContext context, CurrentGame? game) {
    final l10n = context.l10n;
    if (game == null) return l10n.countdownCurrentDrawFallback;

    final parsed = parseDateTime(game.drawAt);
    if (parsed != null) {
      return l10n.resultDrawDate(
        formatLocalizedDateTime(parsed, localeTag(l10n.locale)),
      );
    }

    if (game.name.trim().isNotEmpty) return game.name.trim();
    return l10n.countdownCurrentDrawFallback;
  }

  void _goSearch() {
    context.go(lotterySearchPath());
  }
}

class _HomeHeroTopRow extends StatelessWidget {
  const _HomeHeroTopRow();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      children: [
        const SizedBox(
          width: 64,
          child: Align(
            alignment: Alignment.centerLeft,
            child: TenantBrandHeader(
              showName: false,
              size: 54,
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: _HomePriceBadge(
              amount: l10n.homePriceAmount,
              unit: l10n.homePriceUnit,
            ),
          ),
        ),
        const SizedBox(width: 64),
      ],
    );
  }
}

class _HomePriceBadge extends StatelessWidget {
  const _HomePriceBadge({required this.amount, required this.unit});

  final String amount;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colorScheme.tertiary,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            amount,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: colorScheme.onTertiary,
                  fontWeight: FontWeight.w900,
                  height: 0.92,
                ),
          ),
          Text(
            unit,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onTertiary,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                ),
          ),
        ],
      ),
    );
  }
}

class _HomeSaleBadge extends StatelessWidget {
  const _HomeSaleBadge({required this.label, required this.amount});

  final String label;
  final String amount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 122),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: colorScheme.scrim.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colorScheme.onPrimary,
                  fontWeight: FontWeight.w800,
                  height: 1.05,
                ),
          ),
          const SizedBox(height: 3),
          Text(
            amount,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colorScheme.tertiary,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                ),
          ),
        ],
      ),
    );
  }
}

class _HomeQuickActionPanel extends StatelessWidget {
  const _HomeQuickActionPanel();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DecoratedBox(
      decoration: _homeSurfaceDecoration(context, radius: 14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
        child: Row(
          children: [
            Expanded(
              child: _HomeQuickAction(
                icon: Icons.phone_iphone,
                label: l10n.homeBuyLotteryTitle,
                path: '/buy',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _HomeQuickAction(
                icon: Icons.qr_code_scanner,
                label: l10n.homeScanLotteryTitle,
                path: '/stores',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeQuickAction extends StatelessWidget {
  const _HomeQuickAction({
    required this.icon,
    required this.label,
    required this.path,
  });

  final IconData icon;
  final String label;
  final String path;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.go(path),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 70,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      colorScheme.primary.withValues(alpha: 0.12),
                      colorScheme.primary.withValues(alpha: 0.34),
                    ],
                  ),
                ),
                child: Icon(icon, color: colorScheme.primary, size: 28),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: _homeTitleColor(context),
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeGuestPanel extends StatelessWidget {
  const _HomeGuestPanel();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DecoratedBox(
      decoration: _homeSurfaceDecoration(context, radius: 12),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 390;
            final copy = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.homeGuestTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: _homeTitleColor(context),
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.homeGuestSubtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: _homeBodyColor(context),
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                ),
              ],
            );
            final actions = Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: compact ? WrapAlignment.start : WrapAlignment.end,
              children: [
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(118, 42),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => context.go('/login'),
                  child: Text(l10n.loginTitle),
                ),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(118, 42),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => context.go('/register'),
                  child: Text(l10n.registerTitle),
                ),
              ],
            );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  copy,
                  const SizedBox(height: 14),
                  actions,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: copy),
                const SizedBox(width: 14),
                actions,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ActivitiesRail extends StatelessWidget {
  const _ActivitiesRail({required this.value});

  final AsyncValue<List<ActivityItem>> value;

  @override
  Widget build(BuildContext context) {
    return value.maybeWhen(
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CustomerSectionHeader(
              title: context.l10n.homeActivities,
              actionLabel: context.l10n.commonViewAll,
              onAction: () => context.go('/activities'),
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth = _activityCardWidth(constraints.maxWidth);
                return SizedBox(
                  height: constraints.maxWidth < 380 ? 148 : 158,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    primary: false,
                    padding: EdgeInsets.zero,
                    itemCount: items.length.clamp(0, 8),
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final activity = items[index];
                      return _ActivityCard(
                        activity: activity,
                        width: cardWidth,
                      );
                    },
                  ),
                );
              },
            ),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  double _activityCardWidth(double availableWidth) {
    if (availableWidth < 380) {
      return (availableWidth * 0.88).clamp(248.0, 310.0).toDouble();
    }
    if (availableWidth < 720) return 320;
    return ((availableWidth - 14) / 2).clamp(320.0, 380.0).toDouble();
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.activity, required this.width});

  final ActivityItem activity;
  final double width;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final slug = activity.slug.trim();
    return SizedBox(
      width: width,
      child: DecoratedBox(
        decoration: _homeSurfaceDecoration(context, radius: 14),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: slug.isEmpty
                  ? null
                  : () => context.go(
                        '/activities/${Uri.encodeComponent(slug)}',
                      ),
              child: Row(
                children: [
                  Container(
                    width: width < 280 ? 96 : 124,
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: activity.imageUrl.isEmpty
                        ? _ActivityImageFallback(width: width)
                        : Image.network(
                            activity.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _ActivityImageFallback(width: width),
                          ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Container(
                                  constraints:
                                      const BoxConstraints(minHeight: 23),
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 9),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    l10n.activityTypeLabel(activity.type),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                          height: 1,
                                        ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.chevron_right,
                                color: Theme.of(context).colorScheme.primary,
                                size: 18,
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            activityDisplayName(l10n, activity),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  color: _homeTitleColor(context),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  height: 1.32,
                                ),
                          ),
                          if (activity.conditionText.trim().isNotEmpty) ...[
                            const SizedBox(height: 5),
                            Text(
                              activity.conditionText.trim(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: _homeBodyColor(context),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    height: 1.35,
                                  ),
                            ),
                          ],
                          const SizedBox(height: 5),
                          Text(
                            activityMetaText(l10n, activity),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  height: 1.2,
                                ),
                          ),
                        ],
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

class _ActivityImageFallback extends StatelessWidget {
  const _ActivityImageFallback({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary,
            Color.lerp(colorScheme.primary, colorScheme.secondary, 0.48) ??
                colorScheme.primary,
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: width < 280 ? -12 : -4,
            top: 10,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.tertiary.withValues(alpha: 0.78),
              ),
            ),
          ),
          Center(
            child: Icon(
              Icons.stars_rounded,
              color: colorScheme.onPrimary,
              size: width < 280 ? 28 : 34,
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeResultSection extends StatelessWidget {
  const _HomeResultSection({required this.value});

  final AsyncValue<RewardResultBundle> value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: value.when(
        loading: () {
          final colorScheme = Theme.of(context).colorScheme;
          return DecoratedBox(
            decoration: _homeSurfaceDecoration(context, radius: 14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              child: Row(
                children: [
                  CustomerLoadingMark(
                    width: 30,
                    height: 20,
                    color: colorScheme.primary,
                    trackColor: colorScheme.primary.withValues(alpha: 0.14),
                    semanticLabel: context.l10n.resultLoading,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      context.l10n.resultLoading,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: _homeBodyColor(context),
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        error: (_, __) => _FeatureLinkCard(
          icon: Icons.emoji_events_outlined,
          title: context.l10n.homeResultsTitle,
          subtitle: context.l10n.homeResultsSubtitle,
          path: '/result',
        ),
        data: (bundle) {
          final selected = bundle.selectedResult;
          if (selected == null) {
            return _FeatureLinkCard(
              icon: Icons.emoji_events_outlined,
              title: context.l10n.homeResultsTitle,
              subtitle: context.l10n.homeResultsSubtitle,
              path: '/result',
            );
          }

          return ResultSummaryCard(
            result: selected,
            link: selected.id.isEmpty
                ? '/result/full'
                : '/result/full?game_id=${selected.id}',
          );
        },
      ),
    );
  }
}

class _NewsRail extends StatefulWidget {
  const _NewsRail({required this.value});

  final AsyncValue<List<NewsItem>> value;

  @override
  State<_NewsRail> createState() => _NewsRailState();
}

class _NewsRailState extends State<_NewsRail> {
  String _noticeMessage = '';

  @override
  Widget build(BuildContext context) {
    return widget.value.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (items) {
        final l10n = context.l10n;
        if (items.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HomeNewsHeading(
                title: l10n.homeNews,
                actionLabel: l10n.commonViewAll,
                onAction: () => context.go('/news'),
              ),
              if (_noticeMessage.isNotEmpty) ...[
                const SizedBox(height: 10),
                NewsInlineNotice(message: _noticeMessage),
              ],
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final visibleItems = items.take(8).toList(growable: false);
                  final viewportWidth = MediaQuery.sizeOf(context).width;
                  final railInset = viewportWidth >= 720 ? 28.0 : 16.0;
                  final cardWidth =
                      (viewportWidth * 0.72).clamp(212.0, 238.0).toDouble();
                  return SizedBox(
                    height: _homeNewsRailHeight,
                    child: OverflowBox(
                      alignment: Alignment.center,
                      minWidth: constraints.maxWidth + (railInset * 2),
                      maxWidth: constraints.maxWidth + (railInset * 2),
                      child: ScrollConfiguration(
                        behavior: ScrollConfiguration.of(context).copyWith(
                          scrollbars: false,
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          clipBehavior: Clip.none,
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              railInset,
                              0,
                              railInset,
                              8,
                            ),
                            child: Row(
                              children: [
                                for (var index = 0;
                                    index < visibleItems.length;
                                    index += 1) ...[
                                  _HomeNewsCard(
                                    item: visibleItems[index],
                                    width: cardWidth,
                                    onOpenFailed: () => setState(
                                      () => _noticeMessage =
                                          context.l10n.newsOpenFailed,
                                    ),
                                  ),
                                  if (index < visibleItems.length - 1)
                                    const SizedBox(width: 12),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HomeNewsHeading extends StatelessWidget {
  const _HomeNewsHeading({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: _homeTitleColor(context),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  height: 1.25,
                ),
          ),
        ),
        const SizedBox(width: 12),
        TextButton(
          onPressed: onAction,
          style: TextButton.styleFrom(
            foregroundColor: colorScheme.primary,
            minimumSize: Size.zero,
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            textStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
          ),
          child: Text(
            actionLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _HomeNewsCard extends ConsumerWidget {
  const _HomeNewsCard({
    required this.item,
    required this.width,
    required this.onOpenFailed,
  });

  final NewsItem item;
  final double width;
  final VoidCallback onOpenFailed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final title =
        item.title.trim().isEmpty ? l10n.newsFallbackTitle : item.title.trim();
    final publishedAt = formatLocalizedDateTime(
      item.publishedAt,
      localeTag(l10n.locale),
    );

    return SizedBox(
      width: width,
      child: DecoratedBox(
        decoration: _homeSurfaceDecoration(context, radius: 14),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: hasNewsTarget(item)
                  ? () => _openHomeNews(context, ref, item)
                  : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 126,
                    width: double.infinity,
                    child: item.coverUrl.isEmpty
                        ? const _HomeNewsImageFallback()
                        : Image.network(
                            item.coverUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const _HomeNewsImageFallback(),
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: _homeTitleColor(context),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    height: 1.36,
                                  ),
                        ),
                        if (publishedAt.isNotEmpty && publishedAt != '-') ...[
                          const SizedBox(height: 5),
                          Text(
                            publishedAt,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: _homeMutedColor(context),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  height: 1.2,
                                ),
                          ),
                        ],
                        if (item.summary.trim().isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Text(
                            item.summary.trim(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: _homeBodyColor(context),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      height: 1.4,
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
        ),
      ),
    );
  }

  Future<void> _openHomeNews(
    BuildContext context,
    WidgetRef ref,
    NewsItem item,
  ) async {
    final internalPath = newsInternalPath(item);
    if (internalPath != null) {
      context.go(internalPath);
      return;
    }

    final externalUri = newsExternalUri(item);
    if (externalUri == null) return;

    final ok = await ref.read(customerLinkLauncherProvider).openExternal(
          externalUri,
        );
    if (!context.mounted || ok) return;
    onOpenFailed();
  }
}

class _HomeNewsImageFallback extends StatelessWidget {
  const _HomeNewsImageFallback();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
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
            right: 12,
            top: 10,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.tertiary.withValues(alpha: 0.78),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureLinkCard extends StatelessWidget {
  const _FeatureLinkCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.path,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String path;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: _homeSurfaceDecoration(context, radius: 14),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => context.go(path),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colorScheme.primary.withValues(alpha: 0.10),
                      ),
                      child: SizedBox.square(
                        dimension: 46,
                        child: Icon(
                          icon,
                          color: colorScheme.primary,
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  color: _homeTitleColor(context),
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: _homeBodyColor(context),
                                      fontWeight: FontWeight.w700,
                                      height: 1.32,
                                    ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colorScheme.primary.withValues(alpha: 0.08),
                      ),
                      child: SizedBox.square(
                        dimension: 34,
                        child: Icon(
                          Icons.chevron_right,
                          color: colorScheme.primary,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

List<CustomerWalletCardAction> _walletCardActions(BuildContext context) {
  final l10n = context.l10n;
  return [
    CustomerWalletCardAction(
      icon: Icons.add,
      label: l10n.homeActionTopup,
      onTap: () => context.go('/topup?back=/'),
    ),
    CustomerWalletCardAction(
      icon: Icons.confirmation_number_outlined,
      label: l10n.homeActionTickets,
      onTap: () => context.go('/tickets'),
    ),
    CustomerWalletCardAction(
      icon: Icons.payments_outlined,
      label: l10n.homeActionClaim,
      onTap: () => context.go('/reward-claims'),
    ),
    CustomerWalletCardAction(
      icon: Icons.history,
      label: l10n.homeActionHistory,
      onTap: () => context.go('/my-wallet#transactions'),
    ),
  ];
}

BoxDecoration _homeSurfaceDecoration(
  BuildContext context, {
  required double radius,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  return BoxDecoration(
    color: Theme.of(context).cardTheme.color ?? colorScheme.surface,
    border: Border.all(
      color: colorScheme.outlineVariant.withValues(alpha: 0.82),
    ),
    borderRadius: BorderRadius.circular(radius),
    boxShadow: [
      BoxShadow(
        color: colorScheme.primary.withValues(alpha: 0.08),
        blurRadius: 24,
        offset: const Offset(0, 10),
      ),
    ],
  );
}

BoxDecoration _homeDockButtonDecoration(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;
  return BoxDecoration(
    gradient: LinearGradient(
      colors: [
        colorScheme.primary,
        Color.lerp(colorScheme.primary, colorScheme.secondary, 0.55) ??
            colorScheme.primary,
      ],
    ),
    borderRadius: BorderRadius.circular(999),
    boxShadow: [
      BoxShadow(
        color: colorScheme.primary.withValues(alpha: 0.22),
        blurRadius: 20,
        offset: const Offset(0, 10),
      ),
    ],
  );
}

ButtonStyle _homeDockButtonStyle(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;
  return FilledButton.styleFrom(
    backgroundColor: Colors.transparent,
    foregroundColor: colorScheme.onPrimary,
    shadowColor: Colors.transparent,
    padding: const EdgeInsets.symmetric(horizontal: 18),
    shape: const StadiumBorder(),
    textStyle: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w900,
          height: 1.1,
        ),
  );
}

Color _homeTitleColor(BuildContext context) =>
    Theme.of(context).colorScheme.onSurface;

Color _homeBodyColor(BuildContext context) =>
    Theme.of(context).colorScheme.onSurfaceVariant;

Color _homeMutedColor(BuildContext context) =>
    Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.72);
const _homeHeroHeight = 352.0;
const _homeSheetOverlap = 60.0;
const _homeNewsRailHeight = 256.0;
