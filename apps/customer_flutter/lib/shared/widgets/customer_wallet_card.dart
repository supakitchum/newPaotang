import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';

class CustomerWalletCardAction {
  const CustomerWalletCardAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class CustomerWalletBalanceCard extends StatelessWidget {
  const CustomerWalletBalanceCard({
    required this.balance,
    required this.title,
    required this.actions,
    super.key,
    this.onOpenWallet,
    this.customerLabel = '',
    this.loading = false,
    this.loadingLabel = '',
    this.compact = false,
  });

  final double balance;
  final String title;
  final List<CustomerWalletCardAction> actions;
  final VoidCallback? onOpenWallet;
  final String customerLabel;
  final bool loading;
  final String loadingLabel;
  final bool compact;

  static const _cardRadius = 16.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final primary = colorScheme.primary;
    final secondary = colorScheme.secondary;
    final onHero = colorScheme.onPrimary;
    final heroScrim = colorScheme.scrim;

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = MediaQuery.sizeOf(context).width;
        final narrow = viewportWidth <= 360;
        final paddingValue = compact
            ? (viewportWidth * 0.048).clamp(18.0, 24.0)
            : (viewportWidth * 0.05).clamp(19.0, 26.0);
        final padding = EdgeInsets.all(paddingValue);
        final gridGap = compact
            ? (viewportWidth * 0.04).clamp(15.0, 20.0)
            : (viewportWidth * 0.04).clamp(17.0, 22.0);
        final actionGap = compact
            ? 0.0
            : narrow
                ? 6.0
                : (viewportWidth * 0.03).clamp(8.0, 14.0);
        final amountFontSize = (viewportWidth * 0.08).clamp(26.0, 34.0);
        final yellowAccentRight =
            (constraints.maxWidth * 0.12 - 38).clamp(0.0, double.infinity);
        final gradientEnd =
            primary == AppTheme.appBlue && secondary == AppTheme.appSky
                ? AppTheme.appWalletGradientEnd
                : Color.lerp(secondary, primary, 0.18) ?? secondary;

        return Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(_cardRadius),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_cardRadius),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  primary,
                  Color.lerp(primary, secondary, 0.52) ?? primary,
                  gradientEnd,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: primary.withValues(alpha: 0.23),
                  blurRadius: 30,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_cardRadius),
              child: Stack(
                children: [
                  Positioned(
                    right: yellowAccentRight,
                    top: -38,
                    child: _WalletOrb(
                      size: 76,
                      color: colorScheme.tertiary.withValues(alpha: 0.92),
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.transparent,
                            Colors.transparent,
                            onHero.withValues(alpha: 0.13),
                            Colors.transparent,
                            Colors.transparent,
                          ],
                          stops: const [0, 0.22, 0.226, 0.54, 1],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: padding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.account_balance_wallet_outlined,
                              color: onHero.withValues(alpha: 0.90),
                              size: 17,
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              flex: compact ? 2 : 1,
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: onHero.withValues(alpha: 0.90),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            if (compact) const Spacer(),
                            if (onOpenWallet != null)
                              Tooltip(
                                message: title,
                                child: SizedBox.square(
                                  dimension: 42,
                                  child: Material(
                                    color: (Color.lerp(
                                              primary,
                                              heroScrim,
                                              0.42,
                                            ) ??
                                            primary)
                                        .withValues(alpha: 0.24),
                                    borderRadius: BorderRadius.circular(12),
                                    child: InkWell(
                                      onTap: onOpenWallet,
                                      borderRadius: BorderRadius.circular(12),
                                      splashFactory: NoSplash.splashFactory,
                                      overlayColor:
                                          const WidgetStatePropertyAll(
                                        Colors.transparent,
                                      ),
                                      child: Icon(
                                        Icons.qr_code_scanner,
                                        color: onHero,
                                        size: 25,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        SizedBox(height: gridGap),
                        Semantics(
                          liveRegion: loading,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _balanceText(),
                              textAlign: TextAlign.center,
                              style: theme.textTheme.headlineMedium?.copyWith(
                                color: onHero,
                                fontSize: amountFontSize,
                                fontWeight: FontWeight.w900,
                                height: 1,
                              ),
                            ),
                          ),
                        ),
                        if (!compact && customerLabel.trim().isNotEmpty) ...[
                          SizedBox(height: (gridGap - 12).clamp(0.0, 10.0)),
                          Text(
                            customerLabel.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: onHero.withValues(alpha: 0.84),
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        SizedBox(height: gridGap + 2),
                        Row(
                          children: [
                            for (var index = 0;
                                index < actions.length;
                                index++) ...[
                              Expanded(
                                child: _WalletCardActionButton(
                                  action: actions[index],
                                  compact: compact,
                                  narrow: narrow,
                                ),
                              ),
                              if (index < actions.length - 1)
                                SizedBox(width: actionGap),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _balanceText() {
    if (!loading) return formatBaht(balance);
    final label = loadingLabel.trim();
    return label.isEmpty ? formatBaht(balance) : label;
  }
}

class _WalletCardActionButton extends StatelessWidget {
  const _WalletCardActionButton({
    required this.action,
    required this.compact,
    required this.narrow,
  });

  final CustomerWalletCardAction action;
  final bool compact;
  final bool narrow;

  @override
  Widget build(BuildContext context) {
    final iconSize = narrow ? 36.0 : 40.0;
    final colorScheme = Theme.of(context).colorScheme;
    final overlay = Color.lerp(colorScheme.primary, colorScheme.scrim, 0.42) ??
        colorScheme.primary;
    final onHero = colorScheme.onPrimary;
    return InkWell(
      onTap: action.onTap,
      borderRadius: BorderRadius.circular(16),
      splashFactory: NoSplash.splashFactory,
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: iconSize,
            height: iconSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: overlay.withValues(alpha: 0.42),
              border: Border.all(
                color: onHero.withValues(alpha: 0.08),
              ),
            ),
            child: Icon(action.icon, color: onHero, size: 18),
          ),
          const SizedBox(height: 6),
          Text(
            action.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: onHero,
                  fontWeight: FontWeight.w800,
                  fontSize: narrow ? 10 : 11,
                ),
          ),
        ],
      ),
    );
  }
}

class _WalletOrb extends StatelessWidget {
  const _WalletOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
