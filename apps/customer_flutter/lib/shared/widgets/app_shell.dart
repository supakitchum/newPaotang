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
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: SafeArea(child: child),
      bottomNavigationBar: _CustomerBottomNav(currentPath: currentPath),
    );
  }
}

class _CustomerBottomNav extends StatelessWidget {
  const _CustomerBottomNav({this.currentPath});

  final String? currentPath;

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
      path: '/my-wallet',
      labelKey: _BottomNavLabel.wallet,
      icon: Icons.account_balance_wallet_outlined,
      selectedIcon: Icons.account_balance_wallet,
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

    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: (index) {
        final target = _items[index].path;
        if (target != location) context.go(target);
      },
      destinations: [
        for (final item in _items)
          NavigationDestination(
            icon: Icon(item.icon),
            selectedIcon: Icon(item.selectedIcon),
            label: item.label(l10n),
          ),
      ],
    );
  }

  int _selectedIndex(String location) {
    if (location == '/') return 0;
    if (location.startsWith('/tickets')) return 1;
    if (location.startsWith('/my-wallet') ||
        location.startsWith('/topup') ||
        location.startsWith('/reward-claims') ||
        location.startsWith('/activity-claims')) {
      return 2;
    }
    if (location.startsWith('/profile') ||
        location.startsWith('/affiliate') ||
        location.startsWith('/purchase-history')) {
      return 3;
    }
    return 0;
  }
}

enum _BottomNavLabel { home, tickets, wallet, more }

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
      _BottomNavLabel.wallet => l10n.bottomNavWallet,
      _BottomNavLabel.more => l10n.bottomNavMore,
    };
  }
}
