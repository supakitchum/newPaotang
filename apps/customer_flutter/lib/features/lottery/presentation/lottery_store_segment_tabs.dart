import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/customer_localizations.dart';

class LotteryStoreSegmentTabs extends StatelessWidget {
  const LotteryStoreSegmentTabs({
    required this.activePath,
    super.key,
  });

  final String activePath;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final selected = activePath == '/stores' ? '/stores' : '/buy';
    final colorScheme = Theme.of(context).colorScheme;
    final tabs = [
      (path: '/buy', label: l10n.lotteryAllTab),
      (path: '/stores', label: l10n.lotteryStoresTab),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            for (final tab in tabs)
              Expanded(
                child: _LotteryStoreSegmentTab(
                  label: tab.label,
                  selected: tab.path == selected,
                  onTap: () {
                    if (tab.path != selected) context.go(tab.path);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LotteryStoreSegmentTab extends StatelessWidget {
  const _LotteryStoreSegmentTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final radius = BorderRadius.circular(999);
    return Semantics(
      button: true,
      selected: selected,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: selected
              ? LinearGradient(
                  colors: [
                    Color.lerp(
                          colorScheme.primary,
                          colorScheme.secondary,
                          0.16,
                        ) ??
                        colorScheme.primary,
                    colorScheme.primary,
                  ],
                )
              : null,
          border: selected
              ? Border.all(
                  color: colorScheme.onPrimary.withValues(alpha: 0.52),
                  width: 2,
                )
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          child: InkWell(
            borderRadius: radius,
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            splashFactory: NoSplash.splashFactory,
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 43),
              child: Center(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: selected
                        ? colorScheme.onPrimary
                        : colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
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
