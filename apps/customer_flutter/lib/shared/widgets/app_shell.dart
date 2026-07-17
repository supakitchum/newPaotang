import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/customer_localizations.dart';
import '../../core/tenant/mobile_bootstrap_controller.dart';
import '../../core/tenant/mobile_runtime_policy.dart';
import '../../core/theme/app_theme.dart';
import 'customer_fixed_header_layout.dart';
import 'customer_page_body.dart';

enum CustomerHeroHeaderVariant { standard, compact, rewardFlow }

const double customerReferenceCompactHeroHeight = 150;

class AppShell extends StatelessWidget {
  const AppShell({
    required this.title,
    required this.child,
    super.key,
    this.currentPath,
    this.backPath,
    this.onBack,
    this.sensitive = false,
    this.showBottomNavigation = false,
    this.compactHeader = false,
    this.fullScreen = false,
    this.heroContent,
    this.heroMinHeight = customerReferenceCompactHeroHeight,
    this.heroSheetOverlap = _defaultHeroSheetOverlap,
    this.heroContentTopGap = 24,
    this.heroInFlow = false,
    this.heroSheetTopRadius = customerContentSheetTopRadius,
    this.automaticallyImplyBack = true,
    this.heroHeaderVariant = CustomerHeroHeaderVariant.standard,
    this.actions = const [],
  });

  final String title;
  final Widget child;
  final String? currentPath;
  final String? backPath;
  final VoidCallback? onBack;
  final bool sensitive;
  final bool showBottomNavigation;
  final bool compactHeader;
  final bool fullScreen;
  final Widget? heroContent;
  final double heroMinHeight;
  final double heroSheetOverlap;
  final double heroContentTopGap;
  final bool heroInFlow;
  final double heroSheetTopRadius;
  final bool automaticallyImplyBack;
  final CustomerHeroHeaderVariant heroHeaderVariant;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final routePath = _routePathFor(context);
    final resolvedBack = _resolvedBackAction(context, routePath);
    final expandedHero = heroContent;

    if (fullScreen) {
      return Scaffold(
        body: _AppShellBottomNavOverlay(
          currentPath: currentPath,
          showBottomNavigation: showBottomNavigation,
          child: child,
        ),
      );
    }

    if (expandedHero != null) {
      final resolvedHeroHeight = _resolvedHeroHeight(context);
      final heroHeader = _CustomerBlueHeroHeader(
        title: title,
        minHeight: resolvedHeroHeight,
        onBack: resolvedBack,
        actions: actions,
        variant: compactHeader
            ? CustomerHeroHeaderVariant.compact
            : heroHeaderVariant,
        heroContentTopGap: heroContentTopGap,
        child: expandedHero,
      );
      if (heroInFlow) {
        return Scaffold(
          body: _AppShellBottomNavOverlay(
            currentPath: currentPath,
            showBottomNavigation: showBottomNavigation,
            child: ColoredBox(
              color: colorScheme.surface,
              child: CustomerFixedHeaderLayout(
                headerKey: const ValueKey('customer-fixed-hero'),
                contentRegionKey: const ValueKey(
                  'customer-fixed-content-region',
                ),
                header: heroHeader,
                headerHeight: resolvedHeroHeight,
                allowHeaderOverflow: true,
                contentTopRadius: heroSheetTopRadius,
                contentBackdropColor: colorScheme.primary,
                content: ListView(
                  padding: EdgeInsets.zero,
                  children: [child],
                ),
              ),
            ),
          ),
        );
      }

      return Scaffold(
        body: _AppShellBottomNavOverlay(
          currentPath: currentPath,
          showBottomNavigation: showBottomNavigation,
          child: ColoredBox(
            color: colorScheme.surface,
            child: CustomerFixedHeaderLayout(
              headerKey: const ValueKey('customer-fixed-hero'),
              contentRegionKey: const ValueKey(
                'customer-fixed-content-region',
              ),
              header: heroHeader,
              headerHeight: resolvedHeroHeight,
              allowHeaderOverflow: true,
              contentOverlap: _effectiveHeroSheetOverlap(context),
              contentTopRadius: heroSheetTopRadius,
              contentBackdropColor: colorScheme.primary,
              content: SafeArea(top: false, child: child),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
        titleSpacing: 0,
        titleTextStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: colorScheme.onPrimary,
              fontSize: compactHeader ? 16 : 20,
              fontWeight: compactHeader ? FontWeight.w900 : FontWeight.w700,
              height: 1.25,
            ),
        actions: actions,
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: compactHeader ? 72 : 64,
        leadingWidth: compactHeader ? 52 : null,
        leading: resolvedBack == null
            ? null
            : IconButton(
                tooltip: context.l10n.commonBack,
                onPressed: resolvedBack,
                icon: Icon(
                  Icons.arrow_back_ios_new,
                  size: compactHeader ? 27 : 24,
                ),
                style: compactHeader
                    ? IconButton.styleFrom(
                        fixedSize: const Size.square(36),
                        minimumSize: const Size.square(36),
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: colorScheme.onPrimary,
                      ).copyWith(
                        overlayColor: const WidgetStatePropertyAll(
                          Colors.transparent,
                        ),
                      )
                    : null,
              ),
        flexibleSpace: _CustomerHeroAppBarBackground(
          primary: colorScheme.primary,
          secondary: colorScheme.secondary,
        ),
      ),
      body: _AppShellBottomNavOverlay(
        currentPath: currentPath,
        showBottomNavigation: showBottomNavigation,
        child: SafeArea(child: child),
      ),
    );
  }

  double _effectiveHeroSheetOverlap(BuildContext context) {
    if (heroSheetOverlap >= 0) return heroSheetOverlap;
    final width = MediaQuery.sizeOf(context).width;
    return (width * 0.15).clamp(34.0, 64.0);
  }

  double _resolvedHeroHeight(BuildContext context) {
    if (heroMinHeight != customerReferenceCompactHeroHeight) {
      return heroMinHeight;
    }
    final safeAreaHeight = MediaQuery.paddingOf(context).top + 104;
    return safeAreaHeight > heroMinHeight ? safeAreaHeight : heroMinHeight;
  }

  String _routePathFor(BuildContext context) {
    try {
      return GoRouterState.of(context).uri.path;
    } catch (_) {
      return currentPath ?? '';
    }
  }

  VoidCallback? _resolvedBackAction(BuildContext context, String routePath) {
    final explicitOnBack = onBack;
    if (explicitOnBack != null) return explicitOnBack;

    final explicitBackPath = backPath;
    if (explicitBackPath != null) return () => context.go(explicitBackPath);

    if (!automaticallyImplyBack) return null;
    if (!_shouldShowAutoBack(routePath)) return null;
    return () => _goBackFrom(context, routePath);
  }

  bool _shouldShowAutoBack(String path) {
    if (path.isEmpty) return false;
    return !_customerRootRoutes.contains(path);
  }

  void _goBackFrom(BuildContext context, String path) {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      context.pop();
      return;
    }
    context.go(customerDefaultBackPathFor(path));
  }
}

const double _defaultHeroSheetOverlap = -1;

const _customerRootRoutes = {'/', '/tickets', '/profile'};

String customerDefaultBackPathFor(String path) {
  final normalized = path.isEmpty ? '/' : path;
  if (normalized == '/') return '/';
  if (normalized == '/tickets' || normalized == '/profile') return '/';
  if (normalized.startsWith('/buy/search') ||
      normalized == '/search' ||
      normalized.startsWith('/search')) {
    return '/buy';
  }
  if (normalized.startsWith('/buy/more')) return '/buy';
  if (normalized == '/buy') return '/';
  if (normalized.startsWith('/stores/lotteries')) return '/stores';
  if (normalized.startsWith('/stores')) return '/buy';
  if (normalized.startsWith('/cart')) return '/buy';
  if (normalized.startsWith('/checkout/pending')) return '/checkout';
  if (normalized.startsWith('/checkout')) return '/cart';
  if (normalized.startsWith('/success')) return '/tickets';
  if (normalized.startsWith('/tickets/history')) return '/tickets';
  if (normalized.startsWith('/tickets/view')) return '/tickets';
  if (normalized.startsWith('/tickets/claim')) return '/tickets';
  if (normalized.startsWith('/my-wallet')) return '/profile';
  if (normalized.startsWith('/topup/history')) return '/topup';
  if (normalized.startsWith('/topup')) return '/my-wallet';
  if (normalized.startsWith('/purchase-history/')) return '/purchase-history';
  if (normalized.startsWith('/purchase-history')) return '/profile';
  if (normalized.startsWith('/reward-claims/')) return '/reward-claims';
  if (normalized.startsWith('/reward-claims')) return '/profile';
  if (normalized.startsWith('/activity-claims/')) return '/activity-claims';
  if (normalized.startsWith('/activity-claims')) return '/profile';
  if (normalized.startsWith('/activities/history')) return '/activities';
  if (normalized.startsWith('/activities/')) return '/activities';
  if (normalized.startsWith('/activities')) return '/';
  if (normalized.startsWith('/affiliate')) return '/profile';
  if (normalized.startsWith('/news/')) return '/news';
  if (normalized.startsWith('/news')) return '/profile';
  if (normalized.startsWith('/result/full')) return '/result';
  if (normalized.startsWith('/results/full')) return '/results';
  if (normalized.startsWith('/result') || normalized.startsWith('/results')) {
    return '/';
  }
  if (normalized.startsWith('/waiting-result')) return '/tickets';
  if (normalized.startsWith('/profile/')) return '/profile';
  if (normalized == '/term-reward') return '/';
  if (normalized == '/terms' ||
      normalized == '/privacy' ||
      normalized == '/lottery-knowledge') {
    return '/profile';
  }
  return '/';
}

class _AppShellBottomNavOverlay extends StatelessWidget {
  const _AppShellBottomNavOverlay({
    required this.child,
    required this.showBottomNavigation,
    this.currentPath,
  });

  final Widget child;
  final bool showBottomNavigation;
  final String? currentPath;

  @override
  Widget build(BuildContext context) {
    if (!showBottomNavigation) return child;
    return SizedBox.expand(
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: child),
          Positioned(
            right: 0,
            bottom: 0,
            left: 0,
            child: _CustomerBottomNav(currentPath: currentPath),
          ),
        ],
      ),
    );
  }
}

class _CustomerHeroAppBarBackground extends StatelessWidget {
  const _CustomerHeroAppBarBackground({
    required this.primary,
    required this.secondary,
    this.child,
  });

  final Color primary;
  final Color secondary;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return CustomerBlueHeroBackdrop(
      primary: primary,
      secondary: secondary,
      child: child,
    );
  }
}

class CustomerBlueHeroBackdrop extends StatelessWidget {
  const CustomerBlueHeroBackdrop({
    required this.primary,
    required this.secondary,
    super.key,
    this.child,
  });

  final Color primary;
  final Color secondary;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final heroStart = AppTheme.heroGradientStart(primary);
    final heroEnd = AppTheme.heroGradientEnd(primary);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            heroStart,
            primary,
            heroEnd,
          ],
          stops: const [0, 0.54, 1],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _CustomerBlueHeaderPainter(
                sky: secondary,
                yellow: colorScheme.tertiary,
                highlight: colorScheme.onPrimary,
              ),
            ),
          ),
          child ?? const SizedBox.expand(),
        ],
      ),
    );
  }
}

class _CustomerBlueHeaderPainter extends CustomPainter {
  const _CustomerBlueHeaderPainter({
    required this.sky,
    required this.yellow,
    required this.highlight,
  });

  final Color sky;
  final Color yellow;
  final Color highlight;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;

    final skyRadius = (size.width * 0.44).clamp(152.0, 230.0);
    final skyCenter = Offset(size.width * 0.64, size.height * 1.28);
    final skyPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          sky.withValues(alpha: 0.80),
          sky.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: skyCenter, radius: skyRadius));
    canvas.drawRect(rect, skyPaint);

    final yellowRadius = (size.width * 0.14).clamp(55.0, 86.0);
    final yellowCenter = Offset(size.width * 0.78, size.height * 0.98);
    final yellowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          yellow.withValues(alpha: 0.96),
          yellow.withValues(alpha: 0),
        ],
      ).createShader(
        Rect.fromCircle(center: yellowCenter, radius: yellowRadius),
      );
    canvas.drawRect(rect, yellowPaint);

    void drawDiagonalBand(double dx, double alpha) {
      final band = Paint()
        ..color = highlight.withValues(alpha: alpha)
        ..style = PaintingStyle.fill;
      final path = Path()
        ..moveTo(size.width * 0.20 + dx, 0)
        ..lineTo(size.width * 0.38 + dx, 0)
        ..lineTo(size.width * 0.72 + dx, size.height)
        ..lineTo(size.width * 0.52 + dx, size.height)
        ..close();
      canvas.drawPath(path, band);
    }

    drawDiagonalBand(0, 0.11);
    drawDiagonalBand(54, 0.05);
  }

  @override
  bool shouldRepaint(covariant _CustomerBlueHeaderPainter oldDelegate) {
    return sky != oldDelegate.sky ||
        yellow != oldDelegate.yellow ||
        highlight != oldDelegate.highlight;
  }
}

class _CustomerBlueHeroHeader extends StatelessWidget {
  const _CustomerBlueHeroHeader({
    required this.title,
    required this.minHeight,
    required this.child,
    required this.actions,
    required this.variant,
    required this.heroContentTopGap,
    this.onBack,
  });

  final String title;
  final double minHeight;
  final Widget child;
  final List<Widget> actions;
  final CustomerHeroHeaderVariant variant;
  final double heroContentTopGap;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final topInset = MediaQuery.paddingOf(context).top;
    final compactHeader = variant == CustomerHeroHeaderVariant.compact;
    final rewardFlow = variant == CustomerHeroHeaderVariant.rewardFlow;
    final topPadding = compactHeader
        ? (topInset + 10 < 44 ? 44.0 : topInset + 10)
        : rewardFlow
            ? (topInset + 16 < 50 ? 50.0 : topInset + 16)
            : (topInset + 14 < 58 ? 58.0 : topInset + 14);
    final bottomPadding = compactHeader
        ? 10.0
        : rewardFlow
            ? 26.0
            : 24.0;
    final rowHeight = compactHeader
        ? 36.0
        : rewardFlow
            ? 40.0
            : 42.0;
    final backButtonSize = compactHeader
        ? 36.0
        : rewardFlow
            ? 40.0
            : 42.0;
    final backIconSize = compactHeader
        ? 27.0
        : rewardFlow
            ? 26.0
            : 31.0;
    final l10n = context.l10n;

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: _CustomerHeroAppBarBackground(
        primary: colorScheme.primary,
        secondary: colorScheme.secondary,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            customerSheetMobileHorizontalPadding,
            topPadding,
            customerSheetMobileHorizontalPadding,
            bottomPadding,
          ),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: customerContentMaxWidthFor(context),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: rowHeight,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (onBack != null)
                          Positioned(
                            left: 0,
                            child: _HeroCircleButton(
                              tooltip: l10n.commonBack,
                              icon: Icons.arrow_back_ios_new,
                              onPressed: onBack!,
                              dimension: backButtonSize,
                              iconSize: backIconSize,
                            ),
                          ),
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 54),
                            child: Center(
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      color: colorScheme.onPrimary,
                                      fontSize: compactHeader
                                          ? 16
                                          : rewardFlow
                                              ? 20
                                              : 22,
                                      fontWeight: compactHeader || rewardFlow
                                          ? FontWeight.w900
                                          : FontWeight.w700,
                                      height: compactHeader || rewardFlow
                                          ? 1.25
                                          : 1.15,
                                    ),
                              ),
                            ),
                          ),
                        ),
                        if (actions.isNotEmpty)
                          Positioned(
                            right: 0,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: actions,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (heroContentTopGap > 0)
                    Padding(
                      padding: EdgeInsets.only(top: heroContentTopGap),
                      child: child,
                    )
                  else
                    child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroCircleButton extends StatelessWidget {
  const _HeroCircleButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    required this.dimension,
    required this.iconSize,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final double dimension;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final onPrimary = Theme.of(context).colorScheme.onPrimary;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: iconSize),
      color: onPrimary,
      style: IconButton.styleFrom(
        fixedSize: Size.square(dimension),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: Colors.transparent,
        foregroundColor: onPrimary,
        shape: const CircleBorder(),
      ),
    );
  }
}

class _CustomerBottomNav extends ConsumerWidget {
  const _CustomerBottomNav({this.currentPath});

  final String? currentPath;

  static const bottomNavKey = Key('customer_bottom_nav');

  static const _items = [
    _BottomNavItem(
      path: '/',
      labelKey: _BottomNavLabel.home,
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_outlined,
    ),
    _BottomNavItem(
      path: '/tickets',
      labelKey: _BottomNavLabel.tickets,
      icon: Icons.credit_card_outlined,
      selectedIcon: Icons.credit_card_outlined,
    ),
    _BottomNavItem(
      path: '/profile',
      labelKey: _BottomNavLabel.more,
      icon: Icons.more_horiz,
      selectedIcon: Icons.more_horiz,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = currentPath ?? GoRouterState.of(context).uri.path;
    final bootstrap = ref.watch(mobileBootstrapProvider).valueOrNull;
    final visibleItems = _items
        .where((item) => mobileCustomerRouteAllowed(bootstrap, item.path))
        .toList(growable: false);
    final l10n = context.l10n;
    final primary = Theme.of(context).colorScheme.primary;

    return LayoutBuilder(
      builder: (context, constraints) {
        return MediaQuery.removePadding(
          context: context,
          removeBottom: true,
          child: DecoratedBox(
            key: bottomNavKey,
            decoration: BoxDecoration(
              color: AppTheme.appSheet.withValues(alpha: 0.96),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(34),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.appBottomNavShadow.withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, -8),
                ),
              ],
            ),
            child: SizedBox(
              height: 98,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final horizontal = constraints.maxWidth >= 768
                      ? (constraints.maxWidth * 0.08).clamp(24.0, 96.0)
                      : 0.0;
                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: horizontal),
                    child: Row(
                      children: [
                        for (final item in visibleItems)
                          Expanded(
                            child: _CustomerBottomNavButton(
                              item: item,
                              selected: _isSelected(item, location),
                              label: item.label(l10n),
                              selectedColor:
                                  AppTheme.bottomNavigationActive(primary),
                              unselectedColor: AppTheme.appBottomNavInactive,
                              onTap: () {
                                final target = item.path;
                                if (target != location) context.go(target);
                              },
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  bool _isSelected(_BottomNavItem item, String location) {
    return switch (item.labelKey) {
      _BottomNavLabel.home => _isHomeRoute(location),
      _BottomNavLabel.tickets => location.startsWith('/tickets'),
      _BottomNavLabel.more => location.startsWith('/profile') ||
          location.startsWith('/my-wallet') ||
          location.startsWith('/topup') ||
          location.startsWith('/reward-claims') ||
          location.startsWith('/activity-claims') ||
          location.startsWith('/affiliate') ||
          location.startsWith('/purchase-history'),
    };
  }

  bool _isHomeRoute(String location) {
    if (location == '/') return true;
    const homePrefixes = [
      '/buy',
      '/stores',
      '/cart',
      '/checkout',
      '/result',
      '/waiting-result',
      '/news',
      '/activities',
    ];
    return homePrefixes.any(
      (prefix) => location == prefix || location.startsWith('$prefix/'),
    );
  }
}

class _CustomerBottomNavButton extends StatelessWidget {
  const _CustomerBottomNavButton({
    required this.item,
    required this.selected,
    required this.label,
    required this.selectedColor,
    required this.unselectedColor,
    required this.onTap,
  });

  final _BottomNavItem item;
  final bool selected;
  final String label;
  final Color selectedColor;
  final Color unselectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
          color: selected ? selectedColor : unselectedColor,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 1.1,
        );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        splashFactory: NoSplash.splashFactory,
        child: SizedBox(
          height: 98,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final highlightWidth = constraints.maxWidth.clamp(108.0, 156.0);
              return Stack(
                alignment: Alignment.topCenter,
                children: [
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: selected ? 1 : 0,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Container(
                        width: highlightWidth,
                        height: 98,
                        decoration: BoxDecoration(
                          color: AppTheme.bottomNavigationActiveFill(
                            Theme.of(context).colorScheme.primary,
                          ),
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(70),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          selected ? item.selectedIcon : item.icon,
                          color: selected ? selectedColor : unselectedColor,
                          size: 25,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: textStyle,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

enum _BottomNavLabel { home, tickets, more }

class _BottomNavItem {
  const _BottomNavItem({
    required this.path,
    required this.labelKey,
    required this.icon,
    required this.selectedIcon,
  });

  final String path;
  final _BottomNavLabel labelKey;
  final IconData icon;
  final IconData selectedIcon;

  String label(CustomerLocalizations l10n) {
    return switch (labelKey) {
      _BottomNavLabel.home => l10n.bottomNavHome,
      _BottomNavLabel.tickets => l10n.bottomNavTickets,
      _BottomNavLabel.more => l10n.bottomNavMore,
    };
  }
}
