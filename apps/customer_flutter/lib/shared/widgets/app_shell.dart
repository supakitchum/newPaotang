import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/customer_localizations.dart';

class AppShell extends StatelessWidget {
  const AppShell({
    required this.title,
    required this.child,
    super.key,
    this.currentPath,
    this.sensitive = false,
    this.actions = const [],
  });

  final String title;
  final Widget child;
  final String? currentPath;
  final bool sensitive;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
        actions: actions,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 64,
        flexibleSpace: _CustomerHeroAppBarBackground(
          primary: colorScheme.primary,
          secondary: colorScheme.secondary,
        ),
      ),
      body: SafeArea(child: child),
      bottomNavigationBar: _CustomerBottomNav(currentPath: currentPath),
    );
  }
}

class _CustomerHeroAppBarBackground extends StatelessWidget {
  const _CustomerHeroAppBarBackground({
    required this.primary,
    required this.secondary,
  });

  final Color primary;
  final Color secondary;

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
        ],
      ),
    );
  }
}

class _CustomerBottomNav extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final location = currentPath ?? GoRouterState.of(context).uri.path;
    final selectedIndex = _selectedIndex(location);
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
                  for (var index = 0; index < _items.length; index++)
                    Expanded(
                      child: _CustomerBottomNavButton(
                        item: _items[index],
                        selected: index == selectedIndex,
                        label: _items[index].label(l10n),
                        selectedColor: colorScheme.primary,
                        unselectedColor: colorScheme.onSurfaceVariant,
                        onTap: () {
                          final target = _items[index].path;
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

  int _selectedIndex(String location) {
    if (location == '/') return 0;
    if (location.startsWith('/tickets')) return 1;
    if (location.startsWith('/profile') ||
        location.startsWith('/my-wallet') ||
        location.startsWith('/topup') ||
        location.startsWith('/reward-claims') ||
        location.startsWith('/activity-claims') ||
        location.startsWith('/affiliate') ||
        location.startsWith('/purchase-history')) {
      return 2;
    }
    return 0;
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
