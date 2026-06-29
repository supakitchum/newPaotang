import 'package:flutter/material.dart';

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
  });

  final double balance;
  final String title;
  final List<CustomerWalletCardAction> actions;
  final VoidCallback? onOpenWallet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final primary = colorScheme.primary;
    final secondary = colorScheme.secondary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpenWallet,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                primary,
                Color.lerp(primary, secondary, 0.52) ?? primary,
                const Color(0xFF11A878),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: primary.withValues(alpha: 0.22),
                blurRadius: 26,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              children: [
                Positioned(
                  right: -22,
                  top: -18,
                  child: _WalletOrb(
                    size: 104,
                    color: const Color(0xFFFFD629).withValues(alpha: 0.86),
                  ),
                ),
                Positioned(
                  left: -46,
                  bottom: -62,
                  child: _WalletOrb(
                    size: 150,
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.account_balance_wallet_outlined,
                            color: Colors.white.withValues(alpha: 0.92),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: Colors.white.withValues(alpha: 0.92),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (onOpenWallet != null)
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: IconButton(
                                visualDensity: VisualDensity.compact,
                                tooltip: title,
                                onPressed: onOpenWallet,
                                icon: const Icon(Icons.qr_code_2_rounded),
                                color: Colors.white,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        formatBaht(balance),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          for (var index = 0; index < actions.length; index++)
                            Expanded(
                              child: _WalletCardActionButton(
                                action: actions[index],
                              ),
                            ),
                        ],
                      ),
                    ],
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

class _WalletCardActionButton extends StatelessWidget {
  const _WalletCardActionButton({required this.action});

  final CustomerWalletCardAction action;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: action.onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.16),
              ),
              child: Icon(action.icon, color: Colors.white, size: 20),
            ),
            const SizedBox(height: 7),
            Text(
              action.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
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
