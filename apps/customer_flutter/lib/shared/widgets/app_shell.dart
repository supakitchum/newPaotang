import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/customer_localizations.dart';
import '../../core/tenant/mobile_bootstrap_controller.dart';
import '../../core/tenant/mobile_runtime_policy.dart';

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
    this.heroSheetOverlap = 34,
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
                top: (heroMinHeight - heroSheetOverlap).clamp(
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
    final l10n = context.l10n;

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: _CustomerHeroAppBarBackground(
        primary: colorScheme.primary,
        secondary: colorScheme.secondary,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, topInset + 18, 20, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
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
      icon: Icon(icon, size: 22),
      color: Colors.white,
      style: IconButton.styleFrom(
        fixedSize: const Size.square(42),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: Colors.white.withValues(alpha: 0.14),
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
      selectedIcon: Icons.home,
    ),
    _BottomNavItem(
      path: '/tickets',
      labelKey: _BottomNavLabel.tickets,
      icon: Icons.confirmation_number_outlined,
      selectedIcon: Icons.confirmation_number,
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

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Align(
        alignment: Alignment.bottomCenter,
        heightFactor: 1,
        child: ConstrainedBox(
          key: bottomNavKey,
          constraints: const BoxConstraints(maxWidth: 920),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: SizedBox(
              height: 86,
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
            ),
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
          fontWeight: FontWeight.w800,
        );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Stack(
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              top: selected ? -24 : 10,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: selected ? 1 : 0,
                child: Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selectedColor.withValues(alpha: 0.10),
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
                    size: 26,
                  ),
                  const SizedBox(height: 7),
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
