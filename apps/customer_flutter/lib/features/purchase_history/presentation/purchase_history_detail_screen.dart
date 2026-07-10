import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/customer_localizations.dart';
import '../../../core/tenant/mobile_bootstrap_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/async/async_state_view.dart';
import '../../../shared/widgets/customer_page_body.dart';
import '../../../shared/widgets/tenant_brand_header.dart';
import '../data/purchase_history_models.dart';
import '../data/purchase_history_repository.dart';
import 'purchase_history_localization.dart';

class PurchaseHistoryDetailScreen extends ConsumerWidget {
  const PurchaseHistoryDetailScreen({required this.orderId, super.key});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(purchaseHistoryDetailProvider(orderId));
    final l10n = context.l10n;

    return AppShell(
      title: l10n.purchaseHistoryDetailTitle,
      currentPath: '/profile',
      sensitive: true,
      fullScreen: true,
      showBottomNavigation: false,
      child: _PurchaseReceiptBackground(
        child: Stack(
          children: [
            Positioned.fill(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  0,
                  MediaQuery.paddingOf(context).top + 88,
                  0,
                  MediaQuery.paddingOf(context).bottom + 44,
                ),
                children: [
                  CustomerPageBody(
                    maxWidth: 520,
                    top: 0,
                    bottom: 0,
                    mobileHorizontal: 20,
                    wideHorizontal: 28,
                    includeBottomSafeArea: false,
                    child: AsyncStateView(
                      value: order,
                      data: (item) => _PurchaseReceipt(order: item),
                      empty: const _PurchaseReceiptEmpty(),
                    ),
                  ),
                  CustomerPageBody(
                    maxWidth: 520,
                    top: 26,
                    bottom: 0,
                    mobileHorizontal: 20,
                    wideHorizontal: 28,
                    includeBottomSafeArea: false,
                    child: _PurchaseReceiptSaveButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.successReceiptSaved)),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: MediaQuery.paddingOf(context).top + 34,
              left: 18,
              child: _PurchaseReceiptBackButton(
                onPressed: () => context.go('/purchase-history'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PurchaseReceiptBackground extends StatelessWidget {
  const _PurchaseReceiptBackground({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.appBlue, AppTheme.appSuccessGradientEnd],
        ),
      ),
      child: CustomPaint(
        painter: const _PurchaseReceiptBackgroundPainter(),
        child: child,
      ),
    );
  }
}

class _PurchaseReceiptBackgroundPainter extends CustomPainter {
  const _PurchaseReceiptBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;

    final blueRadius = (size.width * 0.35).clamp(124.0, 170.0);
    final blueCenter = Offset(size.width * 0.66, size.height * 0.78);
    final bluePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          AppTheme.appSuccessRadialBlue.withValues(alpha: 0.50),
          AppTheme.appSuccessRadialBlue.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: blueCenter, radius: blueRadius));
    canvas.drawRect(rect, bluePaint);

    final yellowRadius = (size.width * 0.32).clamp(110.0, 150.0);
    final yellowCenter = Offset(size.width, size.height * 0.96);
    final yellowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          AppTheme.appYellow.withValues(alpha: 0.98),
          AppTheme.appYellow.withValues(alpha: 0),
        ],
      ).createShader(
        Rect.fromCircle(center: yellowCenter, radius: yellowRadius),
      );
    canvas.drawRect(rect, yellowPaint);

    void drawBand(double dx, double alpha) {
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: alpha)
        ..style = PaintingStyle.fill;
      final path = Path()
        ..moveTo(size.width * 0.14 + dx, 0)
        ..lineTo(size.width * 0.32 + dx, 0)
        ..lineTo(size.width * 0.72 + dx, size.height)
        ..lineTo(size.width * 0.50 + dx, size.height)
        ..close();
      canvas.drawPath(path, paint);
    }

    drawBand(0, 0.12);
    drawBand(58, 0.05);
  }

  @override
  bool shouldRepaint(_PurchaseReceiptBackgroundPainter oldDelegate) => false;
}

class _PurchaseReceiptBackButton extends StatelessWidget {
  const _PurchaseReceiptBackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: context.l10n.commonBack,
      onPressed: onPressed,
      icon: const Icon(Icons.chevron_left, size: 38),
      color: Colors.white,
      style: IconButton.styleFrom(
        fixedSize: const Size.square(44),
        minimumSize: const Size.square(44),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: Colors.white,
      ).copyWith(
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
    );
  }
}

class _PurchaseReceiptSaveButton extends StatelessWidget {
  const _PurchaseReceiptSaveButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: AppTheme.appSuccessRadialBlue.withValues(alpha: 0.16),
              blurRadius: 34,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(999),
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            splashFactory: NoSplash.splashFactory,
            child: SizedBox(
              width: 174,
              height: 72,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.download_outlined,
                    size: 29,
                    color: AppTheme.appBlueLink,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    context.l10n.successSaveReceipt,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppTheme.appBlueLink,
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
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

class _PurchaseReceipt extends StatelessWidget {
  const _PurchaseReceipt({required this.order});

  final PurchaseHistoryOrder order;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration:
              _purchaseHistoryDetailSurfaceDecoration(context, radius: 8),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _ReceiptBrand(),
                const SizedBox(height: 26),
                Text(
                  l10n.purchaseHistoryReceiptTitle,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        height: 1.35,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.purchaseHistoryReceiptSubtitle,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        height: 1.45,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 26),
                _ReceiptSection(
                  showTopDivider: false,
                  rows: [
                    _ReceiptRow(
                      l10n.purchaseHistoryTicketCountLabel,
                      l10n.purchaseHistoryTicketCount(order.ticketCount),
                      highlighted: true,
                    ),
                    _ReceiptRow(
                      l10n.purchaseHistoryDrawDateLabel,
                      localizedPurchaseDrawDate(context, order),
                      highlighted: true,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _ReceiptSection(
                  rows: [
                    _ReceiptRow(
                      l10n.purchaseHistoryPayeeLabel,
                      localizedPurchaseStoreName(context, order),
                    ),
                    _ReceiptRow(
                      l10n.purchaseHistoryPaymentChannelLabel,
                      _paymentChannelText(context, order),
                    ),
                  ],
                ),
                Divider(
                  height: 1,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                const SizedBox(height: 24),
                _TotalRow(order: order),
                const SizedBox(height: 22),
                _ReceiptMeta(order: order),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _paymentChannelText(BuildContext context, PurchaseHistoryOrder order) {
    final reference = order.maskedPaymentReference;
    final channel = localizedPurchasePaymentChannel(order);
    if (reference.isEmpty) return channel;
    return '$channel\n$reference';
  }
}

class _ReceiptBrand extends ConsumerWidget {
  const _ReceiptBrand();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final productLabel = ref
            .watch(mobileBootstrapProvider)
            .valueOrNull
            ?.lotteryProductLabel
            .trim() ??
        '';
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        const TenantBrandHeader(
          size: 58,
          maxWidth: 58,
          showName: false,
          icon: Icons.receipt_long_outlined,
        ),
        if (productLabel.isNotEmpty) ...[
          const SizedBox(width: 18),
          SizedBox(
            height: 38,
            child: VerticalDivider(
              width: 1,
              thickness: 1,
              color: colorScheme.outlineVariant,
            ),
          ),
          const SizedBox(width: 18),
          Text(
            productLabel,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
          ),
        ],
      ],
    );
  }
}

class _ReceiptSection extends StatelessWidget {
  const _ReceiptSection({required this.rows, this.showTopDivider = true});

  final List<_ReceiptRow> rows;
  final bool showTopDivider;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        if (showTopDivider) ...[
          Divider(height: 1, color: colorScheme.outlineVariant),
          const SizedBox(height: 18),
        ],
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: row,
          ),
      ],
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow(this.label, this.value, {this.highlighted = false});

  final String label;
  final String value;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Text(
            label,
            style: textTheme.titleSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              height: 1.35,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 5,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: textTheme.titleSmall?.copyWith(
              color: highlighted ? colorScheme.primary : colorScheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({required this.order});

  final PurchaseHistoryOrder order;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text(
            l10n.purchaseHistoryTotalLabel,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
        Text(
          formatBaht(order.total),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
        ),
      ],
    );
  }
}

class _ReceiptMeta extends StatelessWidget {
  const _ReceiptMeta({required this.order});

  final PurchaseHistoryOrder order;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          l10n.purchaseHistoryTransactionAt(
            localizedPurchaseTransactionDate(context, order),
          ),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
        ),
        const SizedBox(height: 7),
        Text(
          l10n.purchaseHistoryReference(order.displayReference),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
        ),
      ],
    );
  }
}

class _PurchaseReceiptEmpty extends StatelessWidget {
  const _PurchaseReceiptEmpty();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: _purchaseHistoryDetailSurfaceDecoration(context, radius: 14),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          context.l10n.purchaseHistoryDetailEmpty,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

BoxDecoration _purchaseHistoryDetailSurfaceDecoration(
  BuildContext context, {
  required double radius,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  return BoxDecoration(
    color: colorScheme.surface,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: [
      BoxShadow(
        color: AppTheme.appSuccessRadialBlue.withValues(alpha: 0.16),
        blurRadius: 44,
        offset: const Offset(0, 18),
      ),
    ],
  );
}
