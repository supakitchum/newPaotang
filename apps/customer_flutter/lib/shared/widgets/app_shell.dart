import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/customer_localizations.dart';
import '../../core/tenant/mobile_bootstrap_controller.dart';
import '../../core/tenant/mobile_runtime_policy.dart';
import 'customer_page_body.dart';

class AppShell extends StatelessWidget {
  const AppShell({
    required this.title,
    required this.child,
    super.key,
    this.currentPath,
    this.backPath,
    this.onBack,
    this.sensitive = false,
    this.showBottomNavigation = true,
    this.compactHeader = false,
    this.fullScreen = false,
    this.heroContent,
    this.heroMinHeight = 174,
    this.heroSheetOverlap = _defaultHeroSheetOverlap,
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
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final expandedHero = heroContent;

    if (fullScreen) {
      return Scaffold(
        extendBody: showBottomNavigation,
        body: child,
        bottomNavigationBar: showBottomNavigation
            ? _CustomerBottomNav(currentPath: currentPath)
            : null,
      );
    }

    if (expandedHero != null) {
      return Scaffold(
        extendBody: showBottomNavigation,
        body: ColoredBox(
          color: colorScheme.surface,
          child: Stack(
            children: [
              Positioned(
                top: 0,
                right: 0,
                left: 0,
                child: _CustomerBlueHeroHeader(
                  title: title,
                  minHeight: heroMinHeight,
                  backPath: backPath,
                  onBack: onBack,
                  actions: actions,
                  compactHeader: compactHeader,
                  child: expandedHero,
                ),
              ),
              Positioned.fill(
                top:
                    (heroMinHeight - _effectiveHeroSheetOverlap(context)).clamp(
                  0,
                  double.infinity,
                ),
                child: SafeArea(top: false, child: child),
              ),
            ],
          ),
        ),
        bottomNavigationBar: showBottomNavigation
            ? _CustomerBottomNav(currentPath: currentPath)
            : null,
      );
    }

    return Scaffold(
      extendBody: showBottomNavigation,
      appBar: AppBar(
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
        titleTextStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontSize: compactHeader ? 16 : 20,
              fontWeight: compactHeader ? FontWeight.w900 : FontWeight.w700,
              height: 1.25,
            ),
        actions: actions,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: compactHeader ? 72 : 64,
        leading: backPath == null && onBack == null
            ? null
            : IconButton(
                tooltip: context.l10n.commonBack,
                onPressed: onBack ?? () => context.go(backPath!),
                icon: Icon(
                  Icons.arrow_back_ios_new,
                  size: compactHeader ? 27 : 24,
                ),
              ),
        flexibleSpace: _CustomerHeroAppBarBackground(
          primary: colorScheme.primary,
          secondary: colorScheme.secondary,
        ),
      ),
      body: SafeArea(child: child),
      bottomNavigationBar: showBottomNavigation
          ? _CustomerBottomNav(currentPath: currentPath)
          : null,
    );
  }

  double _effectiveHeroSheetOverlap(BuildContext context) {
    if (heroSheetOverlap >= 0) return heroSheetOverlap;
    final width = MediaQuery.sizeOf(context).width;
    return (width * 0.15).clamp(34.0, 64.0);
  }
}

const double _defaultHeroSheetOverlap = -1;

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
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primary,
            Color.lerp(primary, secondary, 0.46) ?? primary,
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -76,
            bottom: -138,
            child: Container(
              width: 340,
              height: 340,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: secondary.withValues(alpha: 0.34),
              ),
            ),
          ),
          Positioned(
            right: 38,
            bottom: -48,
            child: Container(
              width: 118,
              height: 118,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFFD629).withValues(alpha: 0.82),
              ),
            ),
          ),
          Positioned(
            left: -44,
            top: -40,
            child: Transform.rotate(
              angle: -0.58,
              child: Container(
                width: 240,
                height: 88,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(44),
                ),
              ),
            ),
          ),
          if (child != null) child!,
        ],
      ),
    );
  }
}

class _CustomerBlueHeroHeader extends StatelessWidget {
  const _CustomerBlueHeroHeader({
    required this.title,
    required this.minHeight,
    required this.child,
    required this.actions,
    required this.compactHeader,
    this.backPath,
    this.onBack,
  });

  final String title;
  final double minHeight;
  final Widget child;
  final List<Widget> actions;
  final bool compactHeader;
  final String? backPath;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final topInset = MediaQuery.paddingOf(context).top;
    final topPadding = topInset + 14 < 58 ? 58.0 : topInset + 14;
    final l10n = context.l10n;

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: _CustomerHeroAppBarBackground(
        primary: colorScheme.primary,
        secondary: colorScheme.secondary,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, topPadding, 20, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: customerContentMaxWidthFor(context),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 42,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (backPath != null || onBack != null)
                          Positioned(
                            left: 0,
                            child: _HeroCircleButton(
                              tooltip: l10n.commonBack,
                              icon: Icons.arrow_back_ios_new,
                              onPressed: onBack ?? () => context.go(backPath!),
                            ),
                          ),
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.white,
                                    fontSize: compactHeader ? 18 : 22,
                                    fontWeight: FontWeight.w800,
                                    height: 1.15,
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
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: child,
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

class _HeroCircleButton extends StatelessWidget {
  const _HeroCircleButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 31),
      color: Colors.white,
      style: IconButton.styleFrom(
        fixedSize: const Size.square(42),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return DecoratedBox(
      key: bottomNavKey,
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.96),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(34)),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SizedBox(
        height: 98 + bottomInset,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final horizontal = constraints.maxWidth >= 768
                  ? constraints.maxWidth * 0.08
                  : 0.0;
              return Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontal.clamp(0.0, 96.0),
                ),
                child: Row(
                  children: [
                    for (final item in visibleItems)
                      Expanded(
                        child: _CustomerBottomNavButton(
                          item: item,
                          selected: _isSelected(item, location),
                          label: item.label(l10n),
                          selectedColor: colorScheme.primary,
                          unselectedColor: colorScheme.onSurfaceVariant,
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
  }

  bool _isSelected(_BottomNavItem item, String location) {
    return switch (item.labelKey) {
      _BottomNavLabel.home => location == '/',
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
                          color: selectedColor.withValues(alpha: 0.08),
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
