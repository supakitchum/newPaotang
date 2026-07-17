import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/customer_localizations.dart';
import '../../../core/tenant/mobile_bootstrap_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/asset_url.dart';
import '../../../shared/services/receipt_export_service.dart';
import '../../../shared/utils/customer_operational_error.dart';
import '../../../shared/widgets/app_alert.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/customer_loading_indicator.dart';
import '../../../shared/widgets/customer_page_body.dart';
import '../../../shared/widgets/flexible_image.dart';
import '../data/purchase_history_models.dart';
import '../data/purchase_history_repository.dart';
import 'purchase_history_localization.dart';

class PurchaseHistoryDetailScreen extends ConsumerStatefulWidget {
  const PurchaseHistoryDetailScreen({required this.orderId, super.key});

  final String orderId;

  @override
  ConsumerState<PurchaseHistoryDetailScreen> createState() =>
      _PurchaseHistoryDetailScreenState();
}

class _PurchaseHistoryDetailScreenState
    extends ConsumerState<PurchaseHistoryDetailScreen> {
  final _receiptBoundaryKey = GlobalKey();
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final order = ref.watch(purchaseHistoryDetailProvider(widget.orderId));
    ref.listen<AsyncValue<PurchaseHistoryOrder>>(
      purchaseHistoryDetailProvider(widget.orderId),
      (previous, next) {
        final error = next.error;
        if (error == null || identical(previous?.error, error)) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _handleOperationalError(error);
        });
      },
    );
    final item = order.valueOrNull;
    final compact = MediaQuery.sizeOf(context).width <= 360;
    final horizontal = compact ? 12.0 : 20.0;
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
                    top: 0,
                    bottom: 0,
                    mobileHorizontal: horizontal,
                    wideHorizontal: horizontal,
                    includeBottomSafeArea: false,
                    child: RepaintBoundary(
                      key: _receiptBoundaryKey,
                      child: order.when(
                        data: (value) => _PurchaseReceiptCard(order: value),
                        loading: () => const _PurchaseReceiptCard(
                          loading: true,
                        ),
                        error: (error, _) => _PurchaseReceiptCard(
                          errorMessage: customerErrorMessage(
                            error,
                            l10n.purchaseHistoryDetailLoadFailed,
                          ),
                          onRetry: () => ref.invalidate(
                            purchaseHistoryDetailProvider(widget.orderId),
                          ),
                        ),
                      ),
                    ),
                  ),
                  CustomerPageBody(
                    top: 26,
                    bottom: 0,
                    mobileHorizontal: horizontal,
                    wideHorizontal: horizontal,
                    includeBottomSafeArea: false,
                    child: _PurchaseReceiptSaveButton(
                      saving: _saving,
                      onPressed: item == null || _saving
                          ? null
                          : () => _saveReceipt(context, item),
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

  Future<void> _saveReceipt(
    BuildContext shareContext,
    PurchaseHistoryOrder order,
  ) async {
    if (_saving) return;
    setState(() => _saving = true);
    final l10n = context.l10n;
    final text = _purchaseReceiptText(context, order);
    final sharePositionOrigin = _sharePositionOrigin(shareContext);

    try {
      final result =
          await ref.read(receiptExportCoordinatorProvider).exportReceipt(
                boundaryKey: _receiptBoundaryKey,
                text: text,
                subject: l10n.purchaseHistoryReceiptTitle,
                imageFileName: _receiptFileName(order, 'png'),
                pdfFileName: _receiptFileName(order, 'pdf'),
                sharePositionOrigin: sharePositionOrigin,
              );
      if (!mounted) return;
      if (result == ReceiptExportResult.copied) {
        ref.read(appAlertControllerProvider.notifier).show(
              message: l10n.successReceiptShareFailedCopied,
              variant: AppAlertVariant.warning,
            );
      }
    } catch (_) {
      if (!mounted) return;
      ref.read(appAlertControllerProvider.notifier).show(
            message: l10n.successReceiptSaveFailed,
            variant: AppAlertVariant.error,
          );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _handleOperationalError(Object error) async {
    await handleCustomerOperationalError(
      ref: ref,
      context: context,
      error: error,
    );
  }
}

class _PurchaseReceiptBackground extends StatelessWidget {
  const _PurchaseReceiptBackground({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary,
            AppTheme.successGradientEnd(
              colorScheme.primary,
              colorScheme.secondary,
            ),
          ],
        ),
      ),
      child: CustomPaint(
        painter: _PurchaseReceiptBackgroundPainter(
          primary: colorScheme.primary,
          accent: colorScheme.tertiary,
        ),
        child: child,
      ),
    );
  }
}

class _PurchaseReceiptBackgroundPainter extends CustomPainter {
  const _PurchaseReceiptBackgroundPainter({
    required this.primary,
    required this.accent,
  });

  final Color primary;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;

    final blueRadius = (size.width * 0.35).clamp(124.0, 170.0);
    final blueCenter = Offset(size.width * 0.66, size.height * 0.78);
    final bluePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          AppTheme.successRadial(primary).withValues(alpha: 0.50),
          AppTheme.successRadial(primary).withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: blueCenter, radius: blueRadius));
    canvas.drawRect(rect, bluePaint);

    final yellowRadius = (size.width * 0.32).clamp(110.0, 150.0);
    final yellowCenter = Offset(size.width, size.height * 0.96);
    final yellowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          accent.withValues(alpha: 0.98),
          accent.withValues(alpha: 0),
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
  bool shouldRepaint(_PurchaseReceiptBackgroundPainter oldDelegate) {
    return oldDelegate.primary != primary || oldDelegate.accent != accent;
  }
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
  const _PurchaseReceiptSaveButton({
    required this.saving,
    required this.onPressed,
  });

  final bool saving;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final linkColor = AppTheme.primaryLink(primary);
    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: AppTheme.successRadial(primary).withValues(alpha: 0.16),
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
                  if (saving)
                    CustomerLoadingMark(
                      width: 25,
                      height: 18,
                      color: linkColor,
                      semanticLabel: context.l10n.commonLoadingData,
                    )
                  else
                    Icon(
                      Icons.download_outlined,
                      size: 29,
                      color: linkColor,
                    ),
                  const SizedBox(width: 12),
                  Text(
                    context.l10n.successSaveReceipt,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: linkColor,
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

class _PurchaseReceiptCard extends StatelessWidget {
  const _PurchaseReceiptCard({
    this.order,
    this.loading = false,
    this.errorMessage = '',
    this.onRetry,
  });

  final PurchaseHistoryOrder? order;
  final bool loading;
  final String errorMessage;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width <= 360;
    final horizontal = compact ? 16.0 : 22.0;
    final l10n = context.l10n;
    final primary = Theme.of(context).colorScheme.primary;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: AppTheme.successRadial(primary).withValues(alpha: 0.16),
            blurRadius: 44,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CustomPaint(
          painter: const _PurchaseReceiptPaperPainter(),
          child: Padding(
            padding: EdgeInsets.fromLTRB(horizontal, 28, horizontal, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _ReceiptBrand(),
                const SizedBox(height: 26),
                Text(
                  l10n.purchaseHistoryReceiptTitle,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: const Color(0xFF242833),
                        fontSize: compact ? 21 : 24,
                        fontWeight: FontWeight.w900,
                        height: 1.35,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.purchaseHistoryReceiptSubtitle,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: const Color(0xFF575F69),
                        fontSize: compact ? 15 : 18,
                        fontWeight: FontWeight.w700,
                        height: 1.45,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 26),
                if (loading)
                  _PurchaseReceiptState(
                    message: l10n.purchaseHistoryDetailLoading,
                    loading: true,
                  )
                else if (errorMessage.isNotEmpty)
                  _PurchaseReceiptState(
                    message: errorMessage,
                    onRetry: onRetry,
                  )
                else if (order == null)
                  _PurchaseReceiptState(
                    message: l10n.purchaseHistoryDetailEmpty,
                  )
                else
                  _PurchaseReceiptContent(order: order!, compact: compact),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PurchaseReceiptPaperPainter extends CustomPainter {
  const _PurchaseReceiptPaperPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x0B0582E2);
    const stripeWidth = 28.0;
    const interval = 66.0;
    final slant = size.height * 0.58;
    for (var x = -size.height; x < size.width + size.height; x += interval) {
      final path = Path()
        ..moveTo(x, 0)
        ..lineTo(x + stripeWidth, 0)
        ..lineTo(x + stripeWidth + slant, size.height)
        ..lineTo(x + slant, size.height)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_PurchaseReceiptPaperPainter oldDelegate) => false;
}

class _PurchaseReceiptContent extends StatelessWidget {
  const _PurchaseReceiptContent({required this.order, required this.compact});

  final PurchaseHistoryOrder order;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ReceiptRows(
          rows: [
            _ReceiptRow(
              l10n.purchaseHistoryTicketCountLabel,
              l10n.purchaseHistoryTicketCount(order.ticketCount),
              highlighted: true,
              compact: compact,
            ),
            _ReceiptRow(
              l10n.purchaseHistoryDrawDateLabel,
              localizedPurchaseDrawDate(context, order),
              highlighted: true,
              compact: compact,
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Divider(height: 1, color: Color(0xFFE5EBF2)),
        const SizedBox(height: 24),
        _ReceiptRows(
          rows: [
            _ReceiptRow(
              l10n.purchaseHistoryPayeeLabel,
              localizedPurchaseStoreName(context, order),
              compact: compact,
            ),
            _ReceiptRow(
              l10n.purchaseHistoryPaymentChannelLabel,
              localizedPurchasePaymentChannel(context, order),
              secondaryValue: order.maskedPaymentReference,
              compact: compact,
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Divider(height: 1, color: Color(0xFFE5EBF2)),
        const SizedBox(height: 24),
        _TotalRow(order: order, compact: compact),
        const SizedBox(height: 22),
        _ReceiptMeta(order: order, compact: compact),
      ],
    );
  }
}

class _ReceiptBrand extends ConsumerWidget {
  const _ReceiptBrand();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrap = ref.watch(mobileBootstrapProvider).valueOrNull;
    final rawLogoUrl = bootstrap?.brand.logoUrl.trim() ?? '';
    final logoUrl = rawLogoUrl.isEmpty
        ? ''
        : _resolvePurchaseReceiptLogoUrl(ref, rawLogoUrl);
    final configuredProduct = bootstrap?.lotteryProductLabel.trim() ?? '';
    final productLabel = configuredProduct.isNotEmpty
        ? configuredProduct
        : context.l10n.ticketStubSeriesLabel;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (logoUrl.isNotEmpty)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: FlexibleImage(
              source: logoUrl,
              height: 42,
              fit: BoxFit.contain,
              errorIcon: Icons.receipt_long_outlined,
            ),
          )
        else
          _ReceiptBrandFallback(
            brandLabel: context.l10n.ticketImageBrandFallback,
            siteName: bootstrap?.siteName.trim() ?? '',
            supportLabel: bootstrap?.supportPhone.trim() ?? '',
          ),
        const SizedBox(width: 18),
        const SizedBox(
          height: 38,
          child: VerticalDivider(
            width: 1,
            thickness: 1,
            color: Color(0xFFD7DEE8),
          ),
        ),
        const SizedBox(width: 18),
        _ReceiptProductMark(label: productLabel),
      ],
    );
  }
}

class _ReceiptBrandFallback extends StatelessWidget {
  const _ReceiptBrandFallback({
    required this.brandLabel,
    required this.siteName,
    required this.supportLabel,
  });

  final String brandLabel;
  final String siteName;
  final String supportLabel;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 150),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            brandLabel,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppTheme.lotterySix(
                    Theme.of(context).colorScheme.primary,
                  ),
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  height: 0.9,
                ),
          ),
          if (siteName.isNotEmpty)
            Text(
              siteName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF575F69),
                fontSize: 7,
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
            ),
          if (supportLabel.isNotEmpty)
            Text(
              supportLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF737B85),
                fontSize: 6,
                fontWeight: FontWeight.w600,
                height: 1.1,
              ),
            ),
        ],
      ),
    );
  }
}

class _ReceiptProductMark extends StatelessWidget {
  const _ReceiptProductMark({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                color: AppTheme.primaryLink(colorScheme.primary),
                fontSize: 36,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
        ),
        Transform.translate(
          offset: const Offset(-5, -1),
          child: SizedBox.square(
            dimension: 8,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.tertiary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReceiptRows extends StatelessWidget {
  const _ReceiptRows({required this.rows});

  final List<_ReceiptRow> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < rows.length; index++) ...[
          if (index > 0) const SizedBox(height: 18),
          rows[index],
        ],
      ],
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow(
    this.label,
    this.value, {
    required this.compact,
    this.highlighted = false,
    this.secondaryValue = '',
  });

  final String label;
  final String value;
  final bool compact;
  final bool highlighted;
  final String secondaryValue;

  @override
  Widget build(BuildContext context) {
    final fontSize = compact ? 15.0 : 18.0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 10,
          child: Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: const Color(0xFF737B85),
                  fontSize: fontSize,
                  fontWeight: FontWeight.w800,
                  height: 1.35,
                ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 11,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: highlighted
                          ? Theme.of(context).colorScheme.primary
                          : const Color(0xFF22282F),
                      fontSize: fontSize,
                      fontWeight: FontWeight.w900,
                      height: 1.35,
                    ),
              ),
              if (secondaryValue.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  secondaryValue,
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF22282F),
                        fontSize: compact ? 15 : 17,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({required this.order, required this.compact});

  final PurchaseHistoryOrder order;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text(
            context.l10n.purchaseHistoryTotalLabel,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: const Color(0xFF737B85),
                  fontSize: compact ? 15 : 18,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: localizedPurchaseMoneyAmount(context, order.total),
                style: TextStyle(
                  fontSize: compact ? 26 : 31,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const TextSpan(text: ' '),
              TextSpan(
                text: context.l10n.commonBahtSuffix,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          maxLines: 1,
          style: const TextStyle(color: Color(0xFF22282F), height: 1),
        ),
      ],
    );
  }
}

class _ReceiptMeta extends StatelessWidget {
  const _ReceiptMeta({required this.order, required this.compact});

  final PurchaseHistoryOrder order;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: const Color(0xFF626B76),
          fontSize: compact ? 15 : 17,
          fontWeight: FontWeight.w700,
          height: 1.35,
        );
    return Column(
      children: [
        Text(
          context.l10n.purchaseHistoryTransactionAt(
            localizedPurchaseTransactionDate(context, order),
          ),
          textAlign: TextAlign.center,
          style: style,
        ),
        const SizedBox(height: 7),
        Text(
          context.l10n.purchaseHistoryReference(order.displayReference),
          textAlign: TextAlign.center,
          style: style,
        ),
      ],
    );
  }
}

class _PurchaseReceiptState extends StatelessWidget {
  const _PurchaseReceiptState({
    required this.message,
    this.loading = false,
    this.onRetry,
  });

  final String message;
  final bool loading;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 18),
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: loading
                      ? const Color(0xFF8A8F98)
                      : Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w800,
                  height: 1.4,
                ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryOutlineText(primary),
                minimumSize: const Size(0, 42),
                padding: const EdgeInsets.symmetric(horizontal: 22),
                shape: const StadiumBorder(),
                side: BorderSide(
                  color: AppTheme.primaryOutlineBorder(primary),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w600),
              ).copyWith(
                overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              ),
              child: Text(context.l10n.commonRetry),
            ),
          ],
        ],
      ),
    );
  }
}

String _resolvePurchaseReceiptLogoUrl(WidgetRef ref, String value) {
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

String _purchaseReceiptText(
  BuildContext context,
  PurchaseHistoryOrder order,
) {
  final l10n = context.l10n;
  final reference = order.maskedPaymentReference;
  return [
    l10n.purchaseHistoryReceiptTitle,
    '${l10n.purchaseHistoryTicketCountLabel}: ${l10n.purchaseHistoryTicketCount(order.ticketCount)}',
    '${l10n.purchaseHistoryDrawDateLabel}: ${localizedPurchaseDrawDate(context, order)}',
    '${l10n.purchaseHistoryPayeeLabel}: ${localizedPurchaseStoreName(context, order)}',
    '${l10n.purchaseHistoryPaymentChannelLabel}: ${localizedPurchasePaymentChannel(context, order)}',
    if (reference.isNotEmpty) reference,
    '${l10n.purchaseHistoryTotalLabel}: ${localizedPurchaseMoneyAmount(context, order.total)} ${l10n.commonBahtSuffix}',
    l10n.purchaseHistoryTransactionAt(
      localizedPurchaseTransactionDate(context, order),
    ),
    l10n.purchaseHistoryReference(order.displayReference),
  ].join('\n');
}

String _receiptFileName(PurchaseHistoryOrder order, String extension) {
  final reference = order.displayReference
      .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
  final suffix = reference.isEmpty ? 'purchase' : reference;
  return 'receipt-$suffix.$extension';
}

Rect? _sharePositionOrigin(BuildContext context) {
  final renderObject = context.findRenderObject();
  if (renderObject is! RenderBox || !renderObject.hasSize) return null;
  return renderObject.localToGlobal(Offset.zero) & renderObject.size;
}
