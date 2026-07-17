import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/i18n/app_locale.dart';
import '../../../core/i18n/customer_localizations.dart';
import '../../../core/navigation/customer_link_launcher.dart';
import '../../../core/tenant/mobile_bootstrap_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/asset_url.dart';
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
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/customer_gradient_button.dart';
import '../../../shared/widgets/customer_page_body.dart';
import '../../../shared/widgets/customer_section_header.dart';
import '../../../shared/widgets/flexible_image.dart';

final _homeCartProvider = FutureProvider.autoDispose<LotteryCart>((ref) async {
  final auth = ref.watch(authControllerProvider);
  if (!auth.isAuthenticated || auth.pinRequired) {
    return LotteryCart.empty();
  }
  return ref.watch(lotteryRepositoryProvider).cart();
});

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _dismissedSaleNoticeKey = '';

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final activities = ref.watch(activityListProvider);
    final news = ref.watch(newsListProvider);
    final result = ref.watch(currentResultProvider);
    final cart =
        ref.watch(_homeCartProvider).valueOrNull ?? LotteryCart.empty();
    final showCartDock = _homeCartSelectionEnabled(cart);
    final homeCartDockBottom = MediaQuery.sizeOf(context).height * 0.12;
    final l10n = context.l10n;
    final currentGame = result.valueOrNull?.currentGame;
    final saleCloseAt = _homeDrawDaySaleCloseAt(currentGame);
    final saleNoticeKey = _homeSaleNoticeKey(currentGame);
    final showSaleNotice =
        saleCloseAt != null &&
        saleNoticeKey.isNotEmpty &&
        saleNoticeKey != _dismissedSaleNoticeKey;
    final heroHeight = _homeHeroHeightFor(
      context,
      showDrawDaySaleNotice: showSaleNotice,
    );

    return AppShell(
      title: l10n.homeTitle,
      currentPath: '/',
      sensitive: true,
      showBottomNavigation: true,
      fullScreen: true,
      child: Stack(
        children: [
          Positioned.fill(
            child: _HomePageList(
              heroHeight: heroHeight,
              hero: _HomeLotteryHero(
                value: result,
                saleCloseAt: showSaleNotice ? saleCloseAt : null,
                onDismissSaleNotice: showSaleNotice
                    ? () => setState(
                        () => _dismissedSaleNoticeKey = saleNoticeKey,
                      )
                    : null,
              ),
              bottom: showCartDock ? 236 : 116,
              children: [
                const _HomeQuickActionPanel(),
                if (!auth.isAuthenticated) ...[
                  const SizedBox(height: 24),
                  const _HomeGuestPanel(),
                ],
                const SizedBox(height: 24),
                _HomeResultSection(value: result),
                _ActivitiesRail(value: activities),
                _NewsRail(value: news),
              ],
            ),
          ),
          if (showCartDock)
            Positioned(
              left: 0,
              right: 0,
              bottom: homeCartDockBottom,
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
  const _HomeFloatingCartDock({required this.cart, required this.onCheckout});

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
          constraints: BoxConstraints(
            maxWidth: customerContentMaxWidthFor(context),
          ),
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
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: AppTheme.appInk,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                height: 1.2,
                              ),
                        ),
                        const SizedBox(height: 4),
                        CustomerPaymentSelectionCountText(
                          count: cart.itemCount,
                          countText: l10n.ticketsCount(cart.itemCount),
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
                    child: CustomerGradientButton(
                      onPressed: onCheckout,
                      height: 58,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      horizontalPadding: 18,
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
      fallbackExpiresAt: widget.deadline.expiresInSeconds > 0
          ? _fallbackExpiresAt
          : null,
    );
    if (remaining.inSeconds <= 0) return const SizedBox.shrink();
    final l10n = context.l10n;
    return Text(
      l10n.cartSelectionTimer(formatReservationCountdown(remaining)),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.92),
        fontWeight: FontWeight.w700,
        height: 1.1,
      ),
    );
  }
}

class _HomePageList extends StatelessWidget {
  const _HomePageList({
    required this.hero,
    required this.heroHeight,
    required this.children,
    required this.bottom,
  });

  final Widget hero;
  final double heroHeight;
  final List<Widget> children;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    final viewportHeight = MediaQuery.sizeOf(context).height;
    final sheetTop = heroHeight - _homeSheetOverlap;
    final minSheetHeight = (viewportHeight - sheetTop)
        .clamp(0.0, double.infinity)
        .toDouble();
    return ListView(
      key: const ValueKey('home-page-scroll'),
      padding: EdgeInsets.zero,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            SizedBox(
              key: const ValueKey('home-scroll-header'),
              height: heroHeight,
              width: double.infinity,
              child: hero,
            ),
            Padding(
              key: const ValueKey('home-content-region'),
              padding: EdgeInsets.only(top: sheetTop),
              child: DecoratedBox(
                key: const ValueKey('home-content-sheet'),
                decoration: BoxDecoration(
                  color: _homeSheetColor(context),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(34),
                  ),
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: minSheetHeight),
                  child: CustomerPageBody(
                    top: 23,
                    bottom: bottom,
                    alignment: Alignment.topCenter,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: children,
                    ),
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
  const _HomeLotteryHero({
    required this.value,
    required this.saleCloseAt,
    required this.onDismissSaleNotice,
  });

  final AsyncValue<RewardResultBundle> value;
  final DateTime? saleCloseAt;
  final VoidCallback? onDismissSaleNotice;

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
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final homeDigitWidth = (viewportWidth * 0.10).clamp(36.0, 58.0).toDouble();
    final productTitleSize = viewportWidth >= 1200
        ? 40.0
        : viewportWidth >= 768
        ? 34.0
        : 28.0;
    final currentGame = widget.value.maybeWhen(
      data: (bundle) => bundle.currentGame,
      orElse: () => null,
    );
    final drawText = _drawText(context, currentGame);
    final heroHeight = _homeHeroHeightFor(
      context,
      showDrawDaySaleNotice: widget.saleCloseAt != null,
    );

    return CustomerBlueHeroBackdrop(
      primary: colorScheme.primary,
      secondary: colorScheme.secondary,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: heroHeight),
        child: CustomerPageBody(
          top: MediaQuery.paddingOf(context).top + 12,
          bottom: 32,
          mobileHorizontal: 20,
          wideHorizontal: 28,
          alignment: Alignment.topCenter,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _HomeHeroTopRow(),
              const SizedBox(height: 22),
              Text(
                l10n.homeProductTitle,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: colorScheme.onPrimary,
                  fontSize: productTitleSize,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
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
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                height: 1.12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.info_outline,
                            size: 18,
                            color: colorScheme.onPrimary.withValues(
                              alpha: 0.88,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        drawText,
                        maxLines: compact ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: colorScheme.onPrimary.withValues(alpha: 0.90),
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          height: 1.25,
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
              const SizedBox(height: 27),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: LotteryDigitInputRow(
                    controllers: _digits,
                    readOnly: true,
                    onTap: _goSearch,
                    onSubmitted: _goSearch,
                    style: LotteryDigitInputStyle(
                      borderRadius: 8,
                      spacing: 0,
                      verticalPadding: 8,
                      fillColor: colorScheme.surface,
                      enabledBorderColor: colorScheme.outlineVariant.withValues(
                        alpha: 0.92,
                      ),
                      shadowColor: colorScheme.shadow.withValues(alpha: 0.12),
                      shadowBlurRadius: 5,
                      shadowOffset: const Offset(0, 2),
                      hintColor: colorScheme.onSurface.withValues(alpha: 0.20),
                      focusedBorderColor: colorScheme.tertiary,
                      maxDigitWidth: homeDigitWidth,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              if (widget.saleCloseAt case final saleCloseAt?) ...[
                const SizedBox(height: 22),
                _HomeDrawDaySaleNotice(
                  saleCloseAt: saleCloseAt,
                  onDismiss: widget.onDismissSaleNotice,
                ),
              ],
            ],
          ),
        ),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(
          width: 128,
          child: Align(
            alignment: Alignment.centerLeft,
            child: _HomeHeroBrandLockup(),
          ),
        ),
        const Spacer(),
        _HomePriceBadge(amount: l10n.homePriceAmount, unit: l10n.homePriceUnit),
      ],
    );
  }
}

class _HomeHeroBrandLockup extends ConsumerWidget {
  const _HomeHeroBrandLockup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final bootstrap = ref.watch(mobileBootstrapProvider);
    return bootstrap.maybeWhen(
      data: (data) {
        final rawLogoUrl = data.brand.logoUrl.trim();
        if (rawLogoUrl.isNotEmpty) {
          return SizedBox(
            width: 128,
            height: 34,
            child: FlexibleImage(
              source: _resolveHomeBrandLogoUrl(ref, rawLogoUrl),
              fit: BoxFit.contain,
              errorIcon: Icons.confirmation_number_outlined,
            ),
          );
        }
        final siteName = data.siteName.trim();
        final supportLabel = data.supportPhone.trim();
        if (siteName.isEmpty && supportLabel.isEmpty) {
          return const SizedBox(width: 128, height: 34);
        }
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 128),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (siteName.isNotEmpty)
                Text(
                  siteName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colorScheme.onPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    height: 0.92,
                  ),
                ),
              if (supportLabel.isNotEmpty)
                Text(
                  supportLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onPrimary.withValues(alpha: 0.9),
                    fontSize: 6,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
            ],
          ),
        );
      },
      orElse: () => const SizedBox(width: 128, height: 34),
    );
  }
}

class _HomeDrawDaySaleNotice extends StatelessWidget {
  const _HomeDrawDaySaleNotice({
    required this.saleCloseAt,
    required this.onDismiss,
  });

  final DateTime saleCloseAt;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final time = _homeSaleCloseTime(saleCloseAt);
    final message = l10n.homeDrawDaySaleNotice(time);
    final timeIndex = message.indexOf(time);
    final baseStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
      color: AppTheme.appInk,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      height: 1.48,
    );

    return DecoratedBox(
      key: const ValueKey('home-draw-day-sale-notice'),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCFA),
        border: Border.all(color: const Color(0xFFF5E8DD)),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Color(0xFFFFE9C7),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.campaign_rounded,
                color: Color(0xFFF08022),
                size: 27,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text.rich(
                TextSpan(
                  style: baseStyle,
                  children: timeIndex < 0
                      ? [TextSpan(text: message)]
                      : [
                          TextSpan(text: message.substring(0, timeIndex)),
                          TextSpan(
                            text: time,
                            style: baseStyle?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          TextSpan(
                            text: message.substring(timeIndex + time.length),
                          ),
                        ],
                ),
              ),
            ),
            IconButton(
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              onPressed: onDismiss,
              icon: const Icon(Icons.close, size: 24),
              color: AppTheme.appInk,
              style:
                  IconButton.styleFrom(
                    fixedSize: const Size.square(40),
                    minimumSize: const Size.square(40),
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ).copyWith(
                    overlayColor: const WidgetStatePropertyAll(
                      Colors.transparent,
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

String _resolveHomeBrandLogoUrl(WidgetRef ref, String value) {
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

class _HomePriceBadge extends StatelessWidget {
  const _HomePriceBadge({required this.amount, required this.unit});

  final String amount;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colorScheme.tertiary,
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.16),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
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
              fontWeight: FontWeight.w700,
              height: 0.92,
            ),
          ),
          Text(
            unit,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onTertiary,
              fontWeight: FontWeight.w700,
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
      constraints: const BoxConstraints(minWidth: 136),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        color: Color.lerp(
          colorScheme.primary,
          colorScheme.scrim,
          0.50,
        )?.withValues(alpha: 0.56),
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
              fontSize: 16,
              fontWeight: FontWeight.w400,
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
              fontSize: 20,
              fontWeight: FontWeight.w700,
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
    final horizontalPadding = MediaQuery.sizeOf(context).width >= 1024
        ? 26.0
        : 16.0;
    return DecoratedBox(
      decoration: _homeSurfaceDecoration(context, radius: 16, outlined: false),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: 22,
        ),
        child: Row(
          children: [
            Expanded(
              child: _HomeQuickAction(
                kind: _HomeQuickActionKind.buy,
                label: l10n.homeBuyLotteryTitle,
                path: '/buy',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _HomeQuickAction(
                kind: _HomeQuickActionKind.scan,
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
    required this.kind,
    required this.label,
    required this.path,
  });

  final _HomeQuickActionKind kind;
  final String label;
  final String path;

  @override
  Widget build(BuildContext context) {
    return _HomeLinkGesture(
      onTap: () => context.go(path),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 70,
              height: 60,
              alignment: Alignment.center,
              child: _HomeQuickIllustration(kind: kind),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _HomeQuickActionKind { buy, scan }

class _HomeQuickIllustration extends StatelessWidget {
  const _HomeQuickIllustration({required this.kind});

  final _HomeQuickActionKind kind;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(colorScheme.surface, colorScheme.primary, 0.12)!,
            Color.lerp(colorScheme.surface, colorScheme.primary, 0.38)!,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          kind == _HomeQuickActionKind.buy
              ? Icons.phone_android_outlined
              : Icons.qr_code_scanner,
          color: colorScheme.primary,
          size: 28,
        ),
      ),
    );
  }
}

// ignore: unused_element
class _HomeQuickIllustrationPainter extends CustomPainter {
  const _HomeQuickIllustrationPainter({
    required this.kind,
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.ink,
    required this.surface,
  });

  final _HomeQuickActionKind kind;
  final Color primary;
  final Color secondary;
  final Color accent;
  final Color ink;
  final Color surface;

  @override
  void paint(Canvas canvas, Size size) {
    _paintBase(canvas, size);
    switch (kind) {
      case _HomeQuickActionKind.buy:
        _paintBuy(canvas, size);
      case _HomeQuickActionKind.scan:
        _paintScan(canvas, size);
    }
  }

  void _paintBase(Canvas canvas, Size size) {
    final basePaint = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.lerp(surface, secondary, 0.20) ?? surface,
              Color.lerp(surface, primary, 0.28) ?? surface,
            ],
          ).createShader(
            Rect.fromLTWH(
              size.width * 0.10,
              9,
              size.width * 0.80,
              size.height - 9,
            ),
          );
    canvas.drawOval(
      Rect.fromLTWH(size.width * 0.10, 9, size.width * 0.80, size.height - 9),
      basePaint,
    );

    canvas.drawOval(
      Rect.fromLTWH(size.width * 0.25, size.height - 8, size.width * 0.50, 6),
      Paint()..color = primary.withValues(alpha: 0.12),
    );
  }

  void _paintBuy(Canvas canvas, Size size) {
    final phoneRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.31, 11, 22, 34),
      const Radius.circular(5),
    );
    canvas.drawRRect(
      phoneRect.shift(const Offset(0, 2)),
      Paint()..color = ink.withValues(alpha: 0.08),
    );
    canvas.drawRRect(
      phoneRect,
      Paint()..color = Color.lerp(surface, primary, 0.10)!,
    );
    canvas.drawRRect(
      phoneRect,
      Paint()
        ..color = primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.35, 17, 14, 15),
      Paint()..color = primary.withValues(alpha: 0.18),
    );
    canvas.drawLine(
      Offset(size.width * 0.36, 37),
      Offset(size.width * 0.55, 37),
      Paint()
        ..color = primary
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round,
    );

    final ticket = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.49, 6, 28, 20),
      const Radius.circular(4),
    );
    canvas.drawRRect(
      ticket.shift(const Offset(0, 2)),
      Paint()..color = ink.withValues(alpha: 0.08),
    );
    canvas.drawRRect(ticket, Paint()..color = surface);
    canvas.drawRRect(
      ticket,
      Paint()
        ..color = primary.withValues(alpha: 0.68)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    final digitPaint = Paint()
      ..color = primary
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    for (var index = 0; index < 4; index += 1) {
      final x = size.width * 0.54 + (index * 4.6);
      canvas.drawLine(Offset(x, 15), Offset(x + 1.6, 15), digitPaint);
    }
    canvas.drawCircle(Offset(size.width * 0.65, 8), 5, Paint()..color = accent);
    canvas.drawCircle(
      Offset(size.width * 0.70, 17),
      3.5,
      Paint()..color = accent.withValues(alpha: 0.90),
    );
  }

  void _paintScan(Canvas canvas, Size size) {
    final device = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.30, 15, 20, 30),
      const Radius.circular(5),
    );
    canvas.drawRRect(
      device.shift(const Offset(0, 2)),
      Paint()..color = ink.withValues(alpha: 0.08),
    );
    canvas.drawRRect(
      device,
      Paint()..color = Color.lerp(surface, primary, 0.14)!,
    );
    canvas.drawRRect(
      device,
      Paint()
        ..color = primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    final ticketRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.48, 7, 24, 30),
      const Radius.circular(4),
    );
    canvas.drawRRect(
      ticketRect.shift(const Offset(0, 2)),
      Paint()..color = ink.withValues(alpha: 0.08),
    );
    canvas.drawRRect(ticketRect, Paint()..color = surface);
    canvas.drawRRect(
      ticketRect,
      Paint()
        ..color = primary.withValues(alpha: 0.74)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    final qrPaint = Paint()..color = ink.withValues(alpha: 0.78);
    const cell = 2.7;
    final left = size.width * 0.525;
    const top = 13.0;
    final blocks = <Offset>[
      const Offset(0, 0),
      const Offset(1, 0),
      const Offset(0, 1),
      const Offset(3, 0),
      const Offset(4, 0),
      const Offset(4, 1),
      const Offset(1, 3),
      const Offset(2, 2),
      const Offset(3, 3),
      const Offset(0, 4),
      const Offset(2, 4),
      const Offset(4, 4),
    ];
    for (final block in blocks) {
      canvas.drawRect(
        Rect.fromLTWH(left + block.dx * cell, top + block.dy * cell, 2, 2),
        qrPaint,
      );
    }

    canvas.drawLine(
      Offset(size.width * 0.31, 33),
      Offset(size.width * 0.58, 25),
      Paint()
        ..color = secondary.withValues(alpha: 0.65)
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      Offset(size.width * 0.68, 40),
      4.5,
      Paint()..color = accent.withValues(alpha: 0.92),
    );
  }

  @override
  bool shouldRepaint(_HomeQuickIllustrationPainter oldDelegate) {
    return oldDelegate.kind != kind ||
        oldDelegate.primary != primary ||
        oldDelegate.secondary != secondary ||
        oldDelegate.accent != accent ||
        oldDelegate.ink != ink ||
        oldDelegate.surface != surface;
  }
}

class _HomeLinkGesture extends StatelessWidget {
  const _HomeLinkGesture({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Semantics(
      button: enabled,
      enabled: enabled,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: child,
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
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 520;
            final copy = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.homeGuestTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: _homeTitleColor(context),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.homeGuestSubtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: _homeBodyColor(context),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.45,
                  ),
                ),
              ],
            );
            final actions = _HomeGuestActions(
              compact: compact,
              onLogin: () => context.go('/login'),
              onRegister: () => context.go('/register'),
            );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [copy, const SizedBox(height: 14), actions],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
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

class _HomeGuestActions extends StatelessWidget {
  const _HomeGuestActions({
    required this.compact,
    required this.onLogin,
    required this.onRegister,
  });

  final bool compact;
  final VoidCallback onLogin;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final secondaryStyle = FilledButton.styleFrom(
      backgroundColor: colorScheme.primary.withValues(alpha: 0.10),
      foregroundColor: colorScheme.primary,
      minimumSize: const Size(118, 42),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      shape: const StadiumBorder(),
      textStyle: const TextStyle(fontWeight: FontWeight.w900),
      visualDensity: VisualDensity.compact,
    );
    final login = CustomerGradientButton.text(
      onPressed: onLogin,
      height: 42,
      fontSize: 15,
      horizontalPadding: 16,
      shadow: false,
      label: l10n.loginTitle,
    );
    final register = FilledButton(
      style: secondaryStyle,
      onPressed: onRegister,
      child: Text(l10n.registerTitle),
    );

    if (compact) {
      return Row(
        children: [
          Expanded(child: login),
          const SizedBox(width: 8),
          Expanded(child: register),
        ],
      );
    }

    return SizedBox(
      width: 132,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [login, const SizedBox(height: 8), register],
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
        return Padding(
          key: const ValueKey('home-activities-section'),
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomerSectionHeader(
                title: context.l10n.homeActivities,
                actionLabel: context.l10n.commonViewAll,
                onAction: () => context.go('/activities'),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final cardWidth = _activityCardWidth(constraints.maxWidth);
                  final railHeight = (cardWidth * 9 / 16) + 116;
                  return SizedBox(
                    height: railHeight,
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
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  double _activityCardWidth(double availableWidth) {
    if (availableWidth < 380) {
      return (availableWidth * 0.68).clamp(196.0, 236.0).toDouble();
    }
    if (availableWidth < 720) {
      return (availableWidth * 0.54).clamp(220.0, 270.0).toDouble();
    }
    return (availableWidth * 0.30).clamp(248.0, 286.0).toDouble();
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
      key: Key('home-activity-card-${activity.id}'),
      width: width,
      child: DecoratedBox(
        decoration: _homeSurfaceDecoration(context, radius: 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: _HomeLinkGesture(
            onTap: slug.isEmpty
                ? null
                : () => context.go('/activities/${Uri.encodeComponent(slug)}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  key: Key('home-activity-artwork-${activity.id}'),
                  aspectRatio: 16 / 9,
                  child: ColoredBox(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: activity.imageUrl.isEmpty
                        ? _ActivityImageFallback(width: width)
                        : Image.network(
                            activity.imageUrl,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _ActivityImageFallback(width: width),
                          ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Container(
                                constraints: const BoxConstraints(
                                  minHeight: 20,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                ),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  l10n.activityTypeLabel(activity.type),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        height: 1,
                                      ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.chevron_right,
                              color: Theme.of(context).colorScheme.primary,
                              size: 16,
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        Text(
                          activityDisplayName(l10n, activity),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: _homeTitleColor(context),
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                height: 1.28,
                              ),
                        ),
                        const Spacer(),
                        Text(
                          activityMetaText(l10n, activity),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                height: 1.25,
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
            AppTheme.homeActivityFallbackStart(colorScheme.primary),
            AppTheme.homeActivityFallbackEnd(
              colorScheme.primary,
              colorScheme.secondary,
            ),
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
                color: AppTheme.fallbackSpark(
                  colorScheme.tertiary,
                ).withValues(alpha: 0.82),
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
      key: const ValueKey('home-result-section'),
      padding: const EdgeInsets.only(bottom: 12),
      child: value.when(
        loading: () {
          return DecoratedBox(
            decoration: _homeSurfaceDecoration(
              context,
              radius: 8,
              outlined: false,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
              child: Text(
                context.l10n.resultLoading,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _homeMutedColor(context),
                  fontWeight: FontWeight.w400,
                ),
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

          return ResultSummaryCard(result: selected, link: '/result');
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
  final PageController _controller = PageController(viewportFraction: 0.90);
  int _currentPage = 0;
  String _noticeMessage = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.value.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (items) {
        final l10n = context.l10n;
        if (items.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 12),
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
                  final carouselWidth = constraints.maxWidth
                      .clamp(0.0, 620.0)
                      .toDouble();
                  final slideWidth = carouselWidth * 0.90;
                  final carouselHeight = (slideWidth * 9 / 16)
                      .clamp(148.0, 314.0)
                      .toDouble();
                  final activePage = _currentPage
                      .clamp(0, items.length - 1)
                      .toInt();
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: carouselWidth,
                      child: Column(
                        children: [
                          SizedBox(
                            height: carouselHeight,
                            child: PageView.builder(
                              key: const ValueKey('home-news-carousel'),
                              controller: _controller,
                              padEnds: false,
                              itemCount: items.length,
                              onPageChanged: (page) {
                                setState(() => _currentPage = page);
                              },
                              itemBuilder: (context, index) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 10),
                                  child: _HomeNewsSlide(
                                    item: items[index],
                                    onOpenFailed: () => setState(
                                      () => _noticeMessage =
                                          context.l10n.newsOpenFailed,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          if (items.length > 1) ...[
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(items.length, (index) {
                                final selected = index == activePage;
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  width: selected ? 18 : 6,
                                  height: 6,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(
                                            context,
                                          ).colorScheme.outlineVariant,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                );
                              }),
                            ),
                          ],
                        ],
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

class _HomeNewsSlide extends ConsumerWidget {
  const _HomeNewsSlide({required this.item, required this.onOpenFailed});

  final NewsItem item;
  final VoidCallback onOpenFailed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final title = item.title.trim().isEmpty
        ? l10n.newsFallbackTitle
        : item.title.trim();
    final canOpen = hasNewsTarget(item);

    return Semantics(
      label: title,
      button: canOpen,
      enabled: canOpen,
      child: DecoratedBox(
        key: Key('home-news-slide-${item.id}'),
        decoration: _homeSurfaceDecoration(context, radius: 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: _HomeLinkGesture(
            onTap: canOpen ? () => _openHomeNews(context, ref, item) : null,
            child: SizedBox.expand(
              child: item.coverUrl.isEmpty
                  ? const _HomeNewsImageFallback()
                  : Image.network(
                      item.coverUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const _HomeNewsImageFallback(),
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

    final ok = await ref
        .read(customerLinkLauncherProvider)
        .openExternal(externalUri);
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
            AppTheme.homeNewsFallbackStart(colorScheme.primary),
            AppTheme.homeNewsFallbackEnd(
              colorScheme.primary,
              colorScheme.onSurface,
            ),
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
                color: AppTheme.fallbackSpark(
                  colorScheme.tertiary,
                ).withValues(alpha: 0.72),
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
          child: _HomeLinkGesture(
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
                      child: Icon(icon, color: colorScheme.primary, size: 24),
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
                          style: Theme.of(context).textTheme.titleSmall
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
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
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
    );
  }
}

Color _homeSheetColor(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;
  return Color.lerp(
        colorScheme.surfaceContainerHighest,
        AppTheme.appSoft,
        0.68,
      ) ??
      AppTheme.appSoft;
}

BoxDecoration _homeSurfaceDecoration(
  BuildContext context, {
  required double radius,
  bool outlined = true,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  return BoxDecoration(
    color: Theme.of(context).cardTheme.color ?? colorScheme.surface,
    border: outlined
        ? Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.74))
        : null,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: [
      BoxShadow(
        color: colorScheme.shadow.withValues(alpha: 0.08),
        blurRadius: 24,
        offset: const Offset(0, 10),
      ),
    ],
  );
}

Color _homeTitleColor(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;
  return Color.lerp(colorScheme.primary, AppTheme.appInk, 0.58) ??
      AppTheme.appInk;
}

Color _homeBodyColor(BuildContext context) =>
    Color.lerp(AppTheme.appMuted, AppTheme.appInk, 0.10) ?? AppTheme.appMuted;

Color _homeMutedColor(BuildContext context) =>
    Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.72);

double _homeHeroHeightFor(
  BuildContext context, {
  bool showDrawDaySaleNotice = false,
}) {
  return _homeHeroBaseHeight +
      MediaQuery.paddingOf(context).top +
      (showDrawDaySaleNotice
          ? MediaQuery.sizeOf(context).width < 380
                ? _homeDrawDayNoticeNarrowExtraHeight
                : MediaQuery.sizeOf(context).width < 430
                ? _homeDrawDayNoticeCompactExtraHeight
                : _homeDrawDayNoticeWideExtraHeight
          : 0);
}

DateTime? _homeDrawDaySaleCloseAt(CurrentGame? game) {
  if (game == null) return null;
  final drawAt = _homeBangkokDateTime(game.drawAt);
  final saleCloseAt = _homeBangkokDateTime(game.saleCloseAt);
  final serverTime =
      _homeBangkokDateTime(game.serverTime) ??
      DateTime.now().toUtc().add(const Duration(hours: 7));
  if (drawAt == null || saleCloseAt == null) return null;
  if (!_homeSameDate(drawAt, saleCloseAt) ||
      !_homeSameDate(drawAt, serverTime)) {
    return null;
  }
  return saleCloseAt;
}

DateTime? _homeBangkokDateTime(Object? value) {
  final parsed = parseDateTime(value);
  return parsed?.toUtc().add(const Duration(hours: 7));
}

bool _homeSameDate(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

String _homeSaleNoticeKey(CurrentGame? game) {
  if (game == null) return '';
  if (game.id.trim().isNotEmpty) return game.id.trim();
  return game.drawAt?.toString().trim() ?? '';
}

String _homeSaleCloseTime(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

const _homeHeroBaseHeight = 352.0;
const _homeDrawDayNoticeNarrowExtraHeight = 160.0;
const _homeDrawDayNoticeCompactExtraHeight = 140.0;
const _homeDrawDayNoticeWideExtraHeight = 116.0;
const _homeSheetOverlap = 34.0;
