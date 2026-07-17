import 'dart:async';
import 'dart:ui' as ui;

export '../../../shared/services/receipt_export_service.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/i18n/app_locale.dart';
import '../../../core/i18n/customer_localizations.dart';
import '../../../core/navigation/customer_link_launcher.dart';
import '../../../core/tenant/mobile_bootstrap_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/asset_url.dart';
import '../../../core/utils/formatters.dart';
import '../../../features/purchase_history/data/purchase_history_models.dart';
import '../../../features/purchase_history/data/purchase_history_repository.dart';
import '../../../features/purchase_history/presentation/purchase_history_localization.dart';
import '../../../features/results/data/result_models.dart';
import '../../../features/results/data/result_repository.dart';
import '../../../shared/services/receipt_export_service.dart';
import '../../../shared/utils/customer_operational_error.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/customer_gradient_button.dart';
import '../../../shared/widgets/customer_loading_indicator.dart';
import '../../../shared/widgets/customer_page_body.dart';
import '../../../shared/widgets/flexible_image.dart';
import '../../../shared/widgets/tenant_brand_header.dart';
import 'success_receipt_state.dart';

class MaintenanceScreen extends ConsumerWidget {
  const MaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrap = ref.watch(mobileBootstrapProvider);
    final l10n = context.l10n;
    return bootstrap.when(
      data: (data) {
        final colorScheme = Theme.of(context).colorScheme;
        final message = data.maintenance.message.isNotEmpty
            ? data.maintenance.message
            : l10n.maintenanceDefaultMessage;
        final supportUri = maintenanceSupportPhoneUri(data.supportPhone);
        final supportEmailUri = systemSupportEmailUri(data.supportEmail);
        final supportUrlUri = maintenanceSupportUrlUri(data.supportUrl);
        final supportActionUri = supportUri ?? supportEmailUri ?? supportUrlUri;
        return _MaintenanceStatePage(
          icon: Icons.construction_outlined,
          title: l10n.maintenanceTitle(data.siteName),
          message: message,
          footer: [
            if (data.maintenance.expectedEndAt != null)
              Text(
                l10n.maintenanceExpectedEnd(
                  formatBangkokLocalizedDateTime(
                    data.maintenance.expectedEndAt,
                    localeTag(l10n.locale),
                  ),
                ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colorScheme.onPrimary.withValues(alpha: 0.86),
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            if (supportActionUri != null)
              OutlinedButton(
                onPressed: () async {
                  await ref
                      .read(customerLinkLauncherProvider)
                      .openExternal(supportActionUri);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.primary,
                  backgroundColor: colorScheme.surface,
                  side: BorderSide.none,
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(fontWeight: FontWeight.w600),
                ),
                child: Text(l10n.maintenanceContactSupport),
              ),
          ],
        );
      },
      loading: () => _MaintenanceStatePage(
        icon: Icons.construction_outlined,
        title: l10n.maintenanceLoadingTitle,
        message: l10n.maintenanceLoadingMessage,
        loading: true,
      ),
      error: (_, __) => _MaintenanceStatePage(
        icon: Icons.construction_outlined,
        title: l10n.maintenanceFallbackTitle,
        message: l10n.maintenanceDefaultMessage,
      ),
    );
  }
}

Uri? maintenanceSupportPhoneUri(String phone) {
  return customerPhoneUri(phone);
}

Uri? maintenanceSupportUrlUri(String url) {
  return customerHttpsUri(url);
}

class AccountSuspendedScreen extends ConsumerWidget {
  const AccountSuspendedScreen({
    super.key,
    this.reason = '',
    this.suspendedUntil,
    this.permanent = false,
  });

  final String reason;
  final String? suspendedUntil;
  final bool permanent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final untilText = accountSuspensionDurationText(
      l10n,
      permanent: permanent,
      suspendedUntil: suspendedUntil,
    );
    return _AccountSuspendedStatePage(
      title: l10n.accountSuspendedTitle,
      message: l10n.accountSuspendedMessage,
      reason:
          reason.trim().isEmpty ? l10n.accountSuspendedNoReason : reason.trim(),
      duration: untilText,
      onBackToLogin: () async {
        await ref.read(authControllerProvider).logout();
        if (context.mounted) context.go('/login');
      },
    );
  }
}

String accountSuspensionDurationText(
  CustomerLocalizations l10n, {
  required bool permanent,
  required String? suspendedUntil,
}) {
  if (permanent) return l10n.accountSuspendedPermanent;
  final rawUntil = suspendedUntil?.trim() ?? '';
  if (rawUntil.isEmpty) return l10n.accountSuspendedPermanent;
  if (parseDateTime(rawUntil) == null) return l10n.accountSuspendedTemporary;
  return l10n.accountSuspendedUntil(
    formatBangkokLocalizedDateTime(rawUntil, localeTag(l10n.locale)),
  );
}

Uri? systemSupportEmailUri(String email) {
  return customerEmailUri(email);
}

class CountdownScreen extends ConsumerStatefulWidget {
  const CountdownScreen({super.key});

  @override
  ConsumerState<CountdownScreen> createState() => _CountdownScreenState();
}

class _CountdownScreenState extends ConsumerState<CountdownScreen> {
  Timer? _timer;
  DateTime _now = DateTime.now();
  bool _checkingStatus = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    listenForCustomerOperationalError<RewardResultBundle>(
      ref: ref,
      context: context,
      provider: currentResultProvider,
    );
    final game = ref.watch(currentResultProvider);
    final l10n = context.l10n;
    final productLabel =
        ref.watch(mobileBootstrapProvider).valueOrNull?.lotteryProductLabel ??
            '';
    return AppShell(
      title: l10n.countdownTitle,
      currentPath: '/',
      showBottomNavigation: true,
      fullScreen: true,
      child: game.when(
        data: (bundle) {
          final current = bundle.currentGame;
          final saleStartAt = parseDateTime(current?.saleStartAt);
          final remaining = saleStartAt == null
              ? Duration.zero
              : saleStartAt.difference(_now);
          if (saleStartAt != null && remaining.inMicroseconds <= 0) {
            _scheduleCountdownStatusRefresh();
          }
          return _CountdownPage(
            currentDrawText: countdownCurrentDrawText(context, current),
            saleStartAt: saleStartAt,
            remaining: remaining,
            productLabel: productLabel.trim().isEmpty
                ? l10n.ticketStubSeriesLabel
                : productLabel.trim(),
            onCheckResult: () => context.go('/result'),
          );
        },
        loading: () => const _CountdownLoadingPage(),
        error: (_, __) => _CountdownErrorPage(
          message: l10n.countdownLoadFailed,
          onRetry: () => ref.invalidate(currentResultProvider),
        ),
      ),
    );
  }

  void _scheduleCountdownStatusRefresh() {
    if (_checkingStatus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _checkingStatus) return;
      unawaited(_refreshAfterCountdown());
    });
  }

  Future<void> _refreshAfterCountdown() async {
    setState(() => _checkingStatus = true);
    try {
      ref.invalidate(currentResultProvider);
      final refreshed = await ref.read(currentResultProvider.future);
      if (!mounted) return;
      final current = refreshed.currentGame;
      if (countdownShouldStayOnPage(current, DateTime.now())) return;
      context.go(countdownTargetPathForGame(current));
    } finally {
      if (mounted) setState(() => _checkingStatus = false);
    }
  }
}

String countdownCurrentDrawText(BuildContext context, CurrentGame? game) {
  if (game == null) return context.l10n.countdownCurrentDrawFallback;
  final value = formatLotteryDrawDateText(
    name: game.name,
    drawAt: game.drawAt,
    localeTag: localeTag(context.l10n.locale),
  );
  if (value == '-') return context.l10n.countdownCurrentDrawFallback;
  return context.l10n.countdownCurrentDraw(value);
}

bool countdownShouldStayOnPage(CurrentGame? game, DateTime now) {
  final saleStartAt = parseDateTime(game?.saleStartAt);
  if (saleStartAt == null) return false;
  return _isOpenGameStatus(game?.status) && saleStartAt.isAfter(now);
}

String countdownTargetPathForGame(CurrentGame? game) {
  final status = _normalizedGameStatus(game?.status);
  if (_isOpenGameStatus(status)) return '/buy';
  if (_isResultGameStatus(status)) return '/result';
  return '/waiting-result';
}

bool _isOpenGameStatus(Object? status) {
  return _normalizedGameStatus(status) == 'open' ||
      _normalizedGameStatus(status) == 'sale' ||
      _normalizedGameStatus(status) == 'selling' ||
      _normalizedGameStatus(status) == '1';
}

bool _isResultGameStatus(Object? status) {
  final normalized = _normalizedGameStatus(status);
  return normalized == '2' ||
      normalized == 'published' ||
      normalized == 'resulted' ||
      normalized == 'completed' ||
      normalized == 'rewarded';
}

String _normalizedGameStatus(Object? status) {
  return (status ?? '').toString().trim().toLowerCase();
}

class SuccessScreen extends ConsumerStatefulWidget {
  const SuccessScreen({super.key, this.orderId});

  final String? orderId;

  @override
  ConsumerState<SuccessScreen> createState() => _SuccessScreenState();
}

class _SuccessScreenState extends ConsumerState<SuccessScreen> {
  final _receiptBoundaryKey = GlobalKey();
  String _receiptNoticeMessage = '';
  bool _receiptNoticeSuccess = false;
  bool _receiptSaving = false;

  @override
  Widget build(BuildContext context) {
    final id = widget.orderId ?? '';
    if (id.isNotEmpty) {
      ref.listen<AsyncValue<PurchaseHistoryOrder>>(
        purchaseHistoryDetailProvider(id),
        (previous, next) {
          final error = next.error;
          if (error == null || identical(previous?.error, error)) return;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _handleOperationalError(error);
          });
        },
      );
    }
    final bootstrap = ref.watch(mobileBootstrapProvider).valueOrNull;
    final bootstrapProductLabel = bootstrap?.lotteryProductLabel ?? '';
    final productLabel = _successProductLabel(
      context,
      bootstrapProductLabel,
    );
    final watermarkLabel = _successReceiptWatermarkLabel(
      bootstrap,
      productLabel,
    );
    final fallbackOrder = successReceiptFallbackForOrderId(
      ref.watch(successReceiptFallbackOrderProvider),
      id,
    );
    final order = id.isEmpty
        ? AsyncValue<PurchaseHistoryOrder?>.data(fallbackOrder)
        : ref
            .watch(purchaseHistoryDetailProvider(id))
            .whenData((value) => value);
    Widget content(PurchaseHistoryOrder? item, {Widget? statusContent}) {
      return _SuccessPageList(
        footer: _SuccessPrimaryActionButton(
          onPressed: () => context.go('/tickets'),
          label: context.l10n.successViewTickets,
        ),
        children: [
          RepaintBoundary(
            key: _receiptBoundaryKey,
            child: _SuccessReceiptCard(
              item: item,
              productLabel: productLabel,
              watermarkLabel: watermarkLabel,
              statusContent: statusContent,
            ),
          ),
          const SizedBox(height: 24),
          if (_receiptNoticeMessage.isNotEmpty) ...[
            _SuccessReceiptInlineNotice(
              message: _receiptNoticeMessage,
              success: _receiptNoticeSuccess,
            ),
            const SizedBox(height: 12),
          ],
          _SuccessReceiptSaveAction(
            onPressed: item == null || _receiptSaving
                ? null
                : () => _exportReceipt(context, item),
          ),
        ],
      );
    }

    return AppShell(
      title: context.l10n.successTitle,
      currentPath: '/tickets',
      showBottomNavigation: true,
      sensitive: true,
      fullScreen: true,
      child: order.when(
        data: (item) => content(item ?? fallbackOrder),
        loading: () => content(
          null,
          statusContent: _SuccessReceiptStatusMessage(
            message: context.l10n.successPaymentLoading,
            loading: true,
          ),
        ),
        error: (_, __) {
          if (fallbackOrder != null) return content(fallbackOrder);
          return content(
            null,
            statusContent: _SuccessReceiptStatusMessage(
              message: context.l10n.successPaymentLoadFailed,
              icon: Icons.error_outline,
              actionLabel: context.l10n.successViewTickets,
              onAction: () => context.go('/tickets'),
            ),
          );
        },
      ),
    );
  }

  Future<void> _exportReceipt(
    BuildContext shareContext,
    PurchaseHistoryOrder item,
  ) async {
    if (_receiptSaving) return;
    setState(() {
      _receiptSaving = true;
      _receiptNoticeMessage = '';
    });
    final l10n = context.l10n;

    try {
      final result =
          await ref.read(receiptExportCoordinatorProvider).exportReceipt(
                boundaryKey: _receiptBoundaryKey,
                text: successReceiptClipboardText(context, item),
                subject: l10n.purchaseHistoryReceiptTitle,
                imageFileName: successReceiptImageFileName(item),
                pdfFileName: successReceiptPdfFileName(item),
                sharePositionOrigin: _successSharePositionOrigin(shareContext),
              );
      if (!mounted) return;
      if (result == ReceiptExportResult.shared) {
        _showReceiptNotice(l10n.successReceiptShareStarted, success: true);
      } else {
        _showReceiptNotice(l10n.successReceiptShareFailedCopied);
      }
    } catch (_) {
      if (mounted) _showReceiptNotice(l10n.successReceiptSaveFailed);
    } finally {
      if (mounted) setState(() => _receiptSaving = false);
    }
  }

  void _showReceiptNotice(String message, {bool success = false}) {
    if (!mounted) return;
    setState(() {
      _receiptNoticeMessage = message;
      _receiptNoticeSuccess = success;
    });
  }

  Future<void> _handleOperationalError(Object error) async {
    await handleCustomerOperationalError(
      ref: ref,
      context: context,
      error: error,
    );
  }
}

class _SuccessPageList extends StatelessWidget {
  const _SuccessPageList({
    required this.children,
    required this.footer,
  });

  final List<Widget> children;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        const nuxtTopPadding = 54.0;
        const baseBottomPadding = 30.0;
        const bottomNavReserve = 98.0;
        final safePadding = MediaQuery.paddingOf(context);
        final topPadding = safePadding.top + 10 > nuxtTopPadding
            ? safePadding.top + 10
            : nuxtTopPadding;
        final bottomPadding =
            baseBottomPadding + bottomNavReserve + safePadding.bottom;
        final contentMinHeight =
            constraints.maxHeight - topPadding - bottomPadding;
        final primaryActionGap =
            _successPrimaryActionTopGap(constraints.maxHeight);
        return ListView(
          padding: EdgeInsets.zero,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: CustomPaint(
                painter: _SuccessBackgroundPainter(
                  primary: colorScheme.primary,
                  secondary: colorScheme.secondary,
                  accent: colorScheme.tertiary,
                ),
                child: SafeArea(
                  top: false,
                  bottom: false,
                  child: CustomerPageBody(
                    maxWidth: 430,
                    top: topPadding,
                    bottom: bottomPadding,
                    mobileHorizontal: 18,
                    wideHorizontal: 0,
                    includeBottomSafeArea: false,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: contentMinHeight < 0 ? 0 : contentMinHeight,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ...children,
                          SizedBox(height: primaryActionGap),
                          footer,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

double _successPrimaryActionTopGap(double viewportHeight) {
  if (!viewportHeight.isFinite || viewportHeight <= 0) {
    return 238.0;
  }
  return (viewportHeight * 0.255).clamp(120.0, 238.0).toDouble();
}

class _SuccessBackgroundPainter extends CustomPainter {
  const _SuccessBackgroundPainter({
    required this.primary,
    required this.secondary,
    required this.accent,
  });

  final Color primary;
  final Color secondary;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..shader = ui.Gradient.linear(
        rect.topLeft,
        rect.bottomRight,
        [
          primary,
          AppTheme.successGradientEnd(primary, secondary),
        ],
      );
    canvas.drawRect(rect, paint);

    canvas.drawCircle(
      Offset(size.width, size.height * 0.94),
      size.shortestSide * 0.244,
      Paint()..color = accent.withValues(alpha: 0.98),
    );

    canvas.drawCircle(
      Offset(size.width * 0.70, size.height * 0.78),
      size.shortestSide * 0.314,
      Paint()..color = AppTheme.successRadial(primary).withValues(alpha: 0.54),
    );
  }

  @override
  bool shouldRepaint(_SuccessBackgroundPainter oldDelegate) {
    return oldDelegate.primary != primary ||
        oldDelegate.secondary != secondary ||
        oldDelegate.accent != accent;
  }
}

class _SuccessReceiptSaveAction extends StatelessWidget {
  const _SuccessReceiptSaveAction({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      key: const ValueKey('success-save-action'),
      child: FractionallySizedBox(
        widthFactor: 0.5,
        child: SizedBox(
          height: 54,
          child: OutlinedButton.icon(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              backgroundColor: colorScheme.surface,
              foregroundColor: colorScheme.primary,
              minimumSize: const Size.fromHeight(54),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: const StadiumBorder(),
              side: BorderSide.none,
              textStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ).copyWith(
              overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            ),
            icon: const Icon(Icons.download_outlined, size: 25),
            label: Text(context.l10n.successSaveReceipt),
          ),
        ),
      ),
    );
  }
}

String _successProductLabel(BuildContext context, String configuredLabel) {
  final configured = configuredLabel.trim();
  if (configured.isNotEmpty) return configured;
  final localized = context.l10n.successLotteryProductLabel.trim();
  if (localized.isNotEmpty) return localized;
  return context.l10n.ticketStubSeriesLabel.trim();
}

String _successReceiptWatermarkLabel(
  MobileBootstrap? bootstrap,
  String productLabel,
) {
  final configured = bootstrap?.ticketImageWatermark.trim() ?? '';
  if (configured.isNotEmpty) return configured;
  return productLabel.trim();
}

class _SuccessPrimaryActionButton extends StatelessWidget {
  const _SuccessPrimaryActionButton({
    required this.onPressed,
    required this.label,
  });

  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('success-primary-action'),
      child: CustomerGradientButton.text(
        onPressed: onPressed,
        height: 54,
        fontSize: 17,
        label: label,
      ),
    );
  }
}

class _SuccessReceiptCard extends StatelessWidget {
  const _SuccessReceiptCard({
    required this.item,
    required this.productLabel,
    required this.watermarkLabel,
    this.statusContent,
  });

  final PurchaseHistoryOrder? item;
  final String productLabel;
  final String watermarkLabel;
  final Widget? statusContent;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      key: const ValueKey('success-receipt-card'),
      decoration: _successReceiptSurfaceDecoration(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CustomPaint(
          painter: _SuccessReceiptWatermarkPainter(
            color: colorScheme.primary.withValues(alpha: 0.035),
            label: watermarkLabel,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
            child: Column(
              children: [
                _SuccessReceiptHeader(productLabel: productLabel),
                if (item != null) ...[
                  const Divider(height: 30),
                  _ReceiptRow(
                    label: l10n.purchaseHistoryTicketCountLabel,
                    value: l10n.purchaseHistoryTicketCount(item!.ticketCount),
                    highlighted: true,
                  ),
                  _ReceiptRow(
                    label: l10n.purchaseHistoryDrawDateLabel,
                    value: localizedPurchaseDrawDate(context, item!),
                    highlighted: true,
                  ),
                  const Divider(height: 24),
                  _ReceiptRow(
                    label: l10n.purchaseHistoryPayeeLabel,
                    value: localizedPurchaseStoreName(context, item!),
                  ),
                  _ReceiptRow(
                    label: l10n.purchaseHistoryPaymentChannelLabel,
                    value: _successPaymentChannelText(context, item!),
                  ),
                  const Divider(height: 24),
                  _SuccessTotalRow(total: item!.total),
                  const SizedBox(height: 8),
                  Text(
                    [
                      '${l10n.successTransactionAtLabel} '
                          '${localizedPurchaseTransactionDate(context, item!)}',
                      '${l10n.purchaseHistoryReferenceLabel} '
                          '${item!.displayReference}',
                    ].join('\n'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          height: 1.45,
                        ),
                  ),
                ] else if (statusContent != null) ...[
                  const Divider(height: 30),
                  statusContent!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

BoxDecoration _successReceiptSurfaceDecoration(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;
  return BoxDecoration(
    color: colorScheme.surface,
    borderRadius: BorderRadius.circular(8),
  );
}

class _SuccessReceiptWatermarkPainter extends CustomPainter {
  const _SuccessReceiptWatermarkPainter({
    required this.color,
    required this.label,
  });

  final Color color;
  final String label;

  @override
  void paint(Canvas canvas, Size size) {
    final stripePaint = Paint()
      ..color = color
      ..strokeWidth = 28;
    canvas.save();
    canvas.rotate(-0.523599);
    for (var x = -size.height; x < size.width + size.height; x += 66) {
      canvas.drawLine(
        Offset(x, -size.height),
        Offset(x, size.height * 2),
        stripePaint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SuccessReceiptWatermarkPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.label != label;
  }
}

class _SuccessReceiptHeader extends StatelessWidget {
  const _SuccessReceiptHeader({required this.productLabel});

  final String productLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const _SuccessReceiptBrandLogo(),
            if (productLabel.trim().isNotEmpty) ...[
              Container(
                width: 1,
                height: 34,
                margin: const EdgeInsets.symmetric(horizontal: 14),
                color: colorScheme.outlineVariant,
              ),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: _SuccessProductMark(label: productLabel.trim()),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppTheme.appSuccessCheck,
            shape: BoxShape.circle,
          ),
          child: SizedBox.square(
            dimension: 62,
            child: Icon(
              Icons.check_rounded,
              color: AppTheme.appSheet,
              size: 38,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          l10n.successPurchaseTitle,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: colorScheme.onSurface,
                fontSize: 24,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          l10n.successPurchaseSubtitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w400,
                height: 1.4,
              ),
        ),
      ],
    );
  }
}

class _SuccessReceiptBrandLogo extends ConsumerWidget {
  const _SuccessReceiptBrandLogo();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final bootstrap = ref.watch(mobileBootstrapProvider);
    return SizedBox(
      width: 96,
      height: 40,
      child: Center(
        child: bootstrap.maybeWhen(
          data: (data) {
            final rawLogoUrl = data.brand.logoUrl.trim();
            if (rawLogoUrl.isEmpty) {
              return Icon(
                Icons.storefront_outlined,
                color: colorScheme.primary,
                size: 28,
              );
            }
            return FlexibleImage(
              key: const ValueKey('success-receipt-brand-logo'),
              source: _resolveSuccessReceiptLogoUrl(ref, rawLogoUrl),
              width: 96,
              height: 38,
              fit: BoxFit.contain,
              errorIcon: Icons.storefront_outlined,
            );
          },
          orElse: () => Icon(
            Icons.storefront_outlined,
            color: colorScheme.primary,
            size: 28,
          ),
        ),
      ),
    );
  }
}

String _resolveSuccessReceiptLogoUrl(WidgetRef ref, String value) {
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

class _SuccessProductMark extends StatelessWidget {
  const _SuccessProductMark({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppTheme.primaryLink(colorScheme.primary),
                fontSize: 32,
                fontWeight: FontWeight.w800,
                height: 1,
                letterSpacing: 0,
              ),
        ),
        Transform.translate(
          offset: const Offset(-5, 1),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.tertiary,
              shape: BoxShape.circle,
            ),
            child: const SizedBox.square(dimension: 8),
          ),
        ),
      ],
    );
  }
}

class _SuccessReceiptStatusMessage extends StatelessWidget {
  const _SuccessReceiptStatusMessage({
    required this.message,
    this.loading = false,
    this.icon,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final bool loading;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          if (loading)
            CustomerLoadingMark(
              semanticLabel: message,
            )
          else if (icon != null)
            Icon(icon, color: colorScheme.error, size: 32),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: loading
                      ? colorScheme.onSurfaceVariant
                      : colorScheme.error,
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: onAction,
              style: _successReceiptOutlinePillButtonStyle(context),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

ButtonStyle _successReceiptOutlinePillButtonStyle(BuildContext context) {
  final primary = Theme.of(context).colorScheme.primary;
  final outlineBorder = AppTheme.primaryOutlineBorder(primary);
  return OutlinedButton.styleFrom(
    foregroundColor: AppTheme.primaryOutlineText(primary),
    disabledForegroundColor: AppTheme.appOutlinePillDisabledText,
    minimumSize: const Size(0, 40),
    padding: const EdgeInsets.symmetric(horizontal: 14),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    visualDensity: VisualDensity.compact,
    backgroundColor: AppTheme.appSheet,
    disabledBackgroundColor: AppTheme.appOutlinePillDisabledFill,
    shape: const StadiumBorder(),
    side: BorderSide(color: outlineBorder),
    textStyle: const TextStyle(fontWeight: FontWeight.w600),
  ).copyWith(
    overlayColor: const WidgetStatePropertyAll(Colors.transparent),
    side: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return const BorderSide(color: AppTheme.appOutlinePillDisabledBorder);
      }
      return BorderSide(color: outlineBorder);
    }),
  );
}

class _SuccessReceiptInlineNotice extends StatelessWidget {
  const _SuccessReceiptInlineNotice({
    required this.message,
    this.success = false,
  });

  final String message;
  final bool success;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = success ? colorScheme.primary : colorScheme.error;
    final errorBackground =
        Color.lerp(colorScheme.error, colorScheme.surface, 0.88) ??
            colorScheme.errorContainer.withValues(alpha: 0.52);
    final errorBorder =
        Color.lerp(colorScheme.error, colorScheme.surface, 0.68) ??
            colorScheme.error.withValues(alpha: 0.32);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: success
            ? colorScheme.primary.withValues(alpha: 0.08)
            : errorBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: success
              ? colorScheme.primary.withValues(alpha: 0.18)
              : errorBorder,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              success
                  ? Icons.check_circle_outline_rounded
                  : Icons.error_outline_rounded,
              color: foreground,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: foreground,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      height: 1.4,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuccessTotalRow extends StatelessWidget {
  const _SuccessTotalRow({required this.total});

  final double total;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final formatted = l10n.formatBaht(total);
    final unit = l10n.commonBahtSuffix.trim();
    final amount = unit.isEmpty
        ? formatted
        : formatted.replaceFirst(RegExp('\\s*${RegExp.escape(unit)}\$'), '');
    return LayoutBuilder(
      builder: (context, constraints) {
        final value = Wrap(
          alignment: constraints.maxWidth < 360
              ? WrapAlignment.start
              : WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: 4,
          children: [
            Text(
              amount.trim(),
              textAlign:
                  constraints.maxWidth < 360 ? TextAlign.left : TextAlign.end,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
            ),
            if (unit.isNotEmpty)
              Text(
                unit,
                textAlign:
                    constraints.maxWidth < 360 ? TextAlign.left : TextAlign.end,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      height: 1.15,
                    ),
              ),
          ],
        );
        if (constraints.maxWidth < 360) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.purchaseHistoryTotalLabel,
                style: _successReceiptLabelStyle(context),
              ),
              const SizedBox(height: 4),
              value,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                l10n.purchaseHistoryTotalLabel,
                style: _successReceiptLabelStyle(context),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(child: value),
          ],
        );
      },
    );
  }
}

String successReceiptClipboardText(
  BuildContext context,
  PurchaseHistoryOrder item,
) {
  final l10n = context.l10n;
  return [
    l10n.successPurchaseTitle,
    '${l10n.purchaseHistoryTicketCountLabel}: '
        '${l10n.purchaseHistoryTicketCount(item.ticketCount)}',
    '${l10n.purchaseHistoryDrawDateLabel}: '
        '${localizedPurchaseDrawDate(context, item)}',
    '${l10n.purchaseHistoryPayeeLabel}: '
        '${localizedPurchaseStoreName(context, item)}',
    '${l10n.purchaseHistoryPaymentChannelLabel}: '
        '${_successPaymentChannelText(context, item).replaceAll('\n', ' ')}',
    '${l10n.purchaseHistoryTotalLabel}: ${formatBaht(item.total)}',
    '${l10n.successTransactionAtLabel}: '
        '${localizedPurchaseTransactionDate(context, item)}',
    '${l10n.purchaseHistoryReferenceLabel}: ${item.displayReference}',
  ].join('\n');
}

String successReceiptImageFileName(PurchaseHistoryOrder item) {
  return _successReceiptFileName(item, extension: 'png');
}

String successReceiptPdfFileName(PurchaseHistoryOrder item) {
  return _successReceiptFileName(item, extension: 'pdf');
}

Rect? _successSharePositionOrigin(BuildContext context) {
  final renderObject = context.findRenderObject();
  if (renderObject is! RenderBox || !renderObject.hasSize) return null;
  return renderObject.localToGlobal(Offset.zero) & renderObject.size;
}

String _successReceiptFileName(
  PurchaseHistoryOrder item, {
  required String extension,
}) {
  final source = item.displayReference.trim().isEmpty
      ? item.id
      : item.displayReference.trim();
  final slug = source
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9_-]+'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
  final normalizedExtension =
      extension.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '').trim();
  return 'receipt-${slug.isEmpty ? 'order' : slug}.'
      '${normalizedExtension.isEmpty ? 'txt' : normalizedExtension}';
}

String _successPaymentChannelText(
  BuildContext context,
  PurchaseHistoryOrder item,
) {
  final channel = localizedPurchasePaymentChannel(context, item);
  final reference = item.maskedPaymentReference;
  if (reference.isEmpty) return channel;
  return '$channel\n$reference';
}

class _MaintenanceStatePage extends StatelessWidget {
  const _MaintenanceStatePage({
    required this.icon,
    required this.title,
    required this.message,
    this.footer = const [],
    this.loading = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final List<Widget> footer;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: _SystemGradientScaffold(
        colors: [
          colorScheme.primary,
          AppTheme.maintenanceGradientEnd(
            colorScheme.primary,
            colorScheme.onSurface,
          ),
        ],
        child: CustomerPageBody(
          maxWidth: 520,
          top: 32,
          bottom: 32,
          mobileHorizontal: 24,
          wideHorizontal: 24,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const TenantBrandLogo(),
              const SizedBox(height: 16),
              _SystemWhiteIcon(icon: icon, color: colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: colorScheme.onPrimary,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                    ),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colorScheme.onPrimary.withValues(alpha: 0.9),
                  fontSize: 17,
                  fontWeight: FontWeight.w400,
                  height: 1.55,
                ),
              ),
              if (loading) ...[
                const SizedBox(height: 16),
                CustomerLoadingMark(
                  width: 46,
                  height: 26,
                  color: colorScheme.onPrimary,
                  trackColor: colorScheme.onPrimary.withValues(alpha: 0.24),
                  semanticLabel: message,
                ),
              ],
              if (footer.isNotEmpty) ...[
                const SizedBox(height: 16),
                for (var index = 0; index < footer.length; index++) ...[
                  footer[index],
                  if (index != footer.length - 1) const SizedBox(height: 16),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountSuspendedStatePage extends StatelessWidget {
  const _AccountSuspendedStatePage({
    required this.title,
    required this.message,
    required this.reason,
    required this.duration,
    required this.onBackToLogin,
  });

  final String title;
  final String message;
  final String reason;
  final String duration;
  final VoidCallback onBackToLogin;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: _SystemGradientScaffold(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppTheme.suspendedGradientStart(colorScheme.primary),
          AppTheme.suspendedGradientMid(colorScheme.primary),
          AppTheme.suspendedGradientEnd(
            colorScheme.primary,
            colorScheme.secondary,
          ),
        ],
        stops: const [0, 0.44, 1],
        radialAccentColor: AppTheme.suspendedRadialAccent(colorScheme.tertiary),
        child: CustomerPageBody(
          maxWidth: 440,
          top: 32,
          bottom: 32,
          mobileHorizontal: 20,
          wideHorizontal: 20,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const TenantBrandLogo(),
              const SizedBox(height: 18),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33093363),
                      blurRadius: 50,
                      offset: Offset(0, 22),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
                  child: Column(
                    children: [
                      const _AccountSuspendedIcon(),
                      const SizedBox(height: 14),
                      Text(
                        l10n.accountSuspendedKicker,
                        style: const TextStyle(
                          color: Color(0xFFDC3545),
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: const Color(0xFF17345F),
                                  fontSize: 25,
                                  fontWeight: FontWeight.w900,
                                  height: 1.22,
                                ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: const Color(0xFF60708A),
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          height: 1.55,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _InfoPanel(
                        label: l10n.accountSuspendedReason,
                        value: reason,
                      ),
                      const SizedBox(height: 14),
                      _InfoPanel(
                        label: l10n.accountSuspendedDuration,
                        value: duration,
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: _AccountSuspendedAction(
                          onPressed: onBackToLogin,
                          label: l10n.accountSuspendedBackToLogin,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountdownPage extends StatelessWidget {
  const _CountdownPage({
    required this.currentDrawText,
    required this.saleStartAt,
    required this.remaining,
    required this.productLabel,
    required this.onCheckResult,
  });

  final String currentDrawText;
  final DateTime? saleStartAt;
  final Duration remaining;
  final String productLabel;
  final VoidCallback onCheckResult;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final headlineSize = viewportWidth >= 768
        ? 58.0
        : viewportWidth >= 600
            ? 48.0
            : 34.0;

    return _SystemGradientScaffold(
      colors: [
        colorScheme.primary,
        AppTheme.countdownGradientMid(colorScheme.primary),
        AppTheme.countdownGradientEnd(
          colorScheme.primary,
          colorScheme.onSurface,
        ),
      ],
      stops: const [0, 0.58, 1],
      child: CustomerPageBody(
        maxWidth: 560,
        top: 68,
        bottom: 124,
        mobileHorizontal: 20,
        wideHorizontal: 20,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const TenantBrandLogo(),
                const SizedBox(width: 16),
                _SuccessProductMark(label: productLabel),
              ],
            ),
            const SizedBox(height: 28),
            Text(
              l10n.countdownWaitingTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.tertiary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.countdownOpensIn,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: colorScheme.onPrimary,
                    fontSize: headlineSize,
                    fontWeight: FontWeight.w800,
                    height: 1.08,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              currentDrawText,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.onPrimary.withValues(alpha: 0.92),
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
            if (saleStartAt != null) ...[
              const SizedBox(height: 8),
              Text(
                l10n.countdownSaleOpensAt(
                  formatBangkokLocalizedDateTime(
                    saleStartAt,
                    localeTag(l10n.locale),
                  ),
                ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colorScheme.onPrimary.withValues(alpha: 0.82),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ],
            const SizedBox(height: 28),
            _CountdownGrid(remaining: remaining),
            const SizedBox(height: 28),
            OutlinedButton.icon(
              onPressed: onCheckResult,
              icon: const Icon(Icons.emoji_events_outlined),
              label: Text(l10n.waitingResultCheckResult),
              style: _whiteOutlinePillStyle(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountdownLoadingPage extends StatelessWidget {
  const _CountdownLoadingPage();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return _SystemGradientScaffold(
      colors: [
        colorScheme.primary,
        AppTheme.countdownGradientMid(colorScheme.primary),
        AppTheme.countdownGradientEnd(
          colorScheme.primary,
          colorScheme.onSurface,
        ),
      ],
      stops: const [0, 0.58, 1],
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomerLoadingMark(
              width: 46,
              height: 26,
              color: colorScheme.onPrimary,
              trackColor: colorScheme.onPrimary.withValues(alpha: 0.24),
              semanticLabel: context.l10n.maintenanceLoadingMessage,
            ),
            const SizedBox(height: 18),
            Text(
              context.l10n.maintenanceLoadingMessage,
              style: TextStyle(
                color: colorScheme.onPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountdownErrorPage extends StatelessWidget {
  const _CountdownErrorPage({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return _SystemGradientScaffold(
      colors: [
        colorScheme.primary,
        AppTheme.countdownGradientMid(colorScheme.primary),
        AppTheme.countdownGradientEnd(
          colorScheme.primary,
          colorScheme.onSurface,
        ),
      ],
      stops: const [0, 0.58, 1],
      child: CustomerPageBody(
        maxWidth: 440,
        top: 48,
        bottom: 124,
        mobileHorizontal: 24,
        wideHorizontal: 24,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _SystemWhiteIcon(
              icon: Icons.error_outline,
              color: colorScheme.error,
            ),
            const SizedBox(height: 18),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.onPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w600,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            OutlinedButton(
              onPressed: onRetry,
              style: _whiteOutlinePillStyle(context),
              child: Text(context.l10n.commonRetry),
            ),
          ],
        ),
      ),
    );
  }
}

class _SystemGradientScaffold extends StatelessWidget {
  const _SystemGradientScaffold({
    required this.child,
    this.begin = Alignment.topLeft,
    this.end = Alignment.bottomRight,
    this.colors,
    this.stops,
    this.radialAccentColor,
  });

  final Widget child;
  final AlignmentGeometry begin;
  final AlignmentGeometry end;
  final List<Color>? colors;
  final List<double>? stops;
  final Color? radialAccentColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final midColor =
        Color.lerp(colorScheme.primary, colorScheme.surface, 0.18) ??
            colorScheme.primary;
    final endColor =
        Color.lerp(colorScheme.primary, colorScheme.secondary, 0.34) ??
            colorScheme.primary;

    final gradientColors = colors ?? [colorScheme.primary, midColor, endColor];
    final scrollable = SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: child,
            ),
          );
        },
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: begin,
          end: end,
          colors: gradientColors,
          stops: stops,
        ),
      ),
      child: radialAccentColor == null
          ? scrollable
          : LayoutBuilder(
              builder: (context, constraints) {
                const accentSize = 108.0;
                return Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    Positioned(
                      left: (constraints.maxWidth * 0.82) - (accentSize / 2),
                      top: (constraints.maxHeight * 0.16) - (accentSize / 2),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: radialAccentColor,
                          shape: BoxShape.circle,
                        ),
                        child: const SizedBox.square(dimension: accentSize),
                      ),
                    ),
                    Positioned.fill(child: scrollable),
                  ],
                );
              },
            ),
    );
  }
}

class _AccountSuspendedIcon extends StatelessWidget {
  const _AccountSuspendedIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 74,
      height: 74,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F1),
        borderRadius: BorderRadius.circular(24),
      ),
      alignment: Alignment.center,
      child: const Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.shield_outlined, color: Color(0xFFDC3545), size: 38),
          Padding(
            padding: EdgeInsets.only(top: 3),
            child: Icon(Icons.lock_outline, color: Color(0xFFDC3545), size: 16),
          ),
        ],
      ),
    );
  }
}

class _AccountSuspendedAction extends StatelessWidget {
  const _AccountSuspendedAction({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.systemActionStart(primary),
            AppTheme.systemActionEnd(primary),
          ],
        ),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: AppTheme.systemActionEnd(primary).withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ).copyWith(
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
        child: Text(label),
      ),
    );
  }
}

class _SystemWhiteIcon extends StatelessWidget {
  const _SystemWhiteIcon({
    required this.icon,
    required this.color,
  });

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 82,
      height: 82,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: color, size: 34),
    );
  }
}

class _CountdownGrid extends StatelessWidget {
  const _CountdownGrid({required this.remaining});

  final Duration remaining;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final onGradient = Theme.of(context).colorScheme.onPrimary;
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final wide = viewportWidth >= 768;
    final numberSize = wide
        ? 44.0
        : viewportWidth <= 380
            ? 26.0
            : 30.0;
    final safe = remaining.isNegative ? Duration.zero : remaining;
    final days = safe.inDays;
    final hours = safe.inHours.remainder(24);
    final minutes = safe.inMinutes.remainder(60);
    final seconds = safe.inSeconds.remainder(60);
    final items = [
      (l10n.countdownDay, days),
      (l10n.countdownHour, hours),
      (l10n.countdownMinute, minutes),
      (l10n.countdownSecond, seconds),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = viewportWidth <= 380 ? 2 : 4;

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: columns,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          mainAxisExtent: wide ? 100 : 82,
          children: [
            for (final item in items)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0x42002358),
                  border: Border.all(color: onGradient.withValues(alpha: 0.28)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.$2.toString().padLeft(2, '0'),
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: onGradient,
                                fontSize: numberSize,
                                fontWeight: FontWeight.w700,
                                height: 1,
                              ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.$1,
                      style: TextStyle(
                        color: onGradient.withValues(alpha: 0.86),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF4F8FF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              label,
              style: TextStyle(
                color: const Color(0xFF7A8AA2),
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                color: const Color(0xFF17345F),
                fontSize: 16,
                fontWeight: FontWeight.w700,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

ButtonStyle _whiteOutlinePillStyle(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;
  final foregroundColor = colorScheme.onPrimary;

  return OutlinedButton.styleFrom(
    foregroundColor: foregroundColor,
    side: BorderSide(color: foregroundColor.withValues(alpha: 0.68)),
    backgroundColor: foregroundColor.withValues(alpha: 0.12),
    minimumSize: const Size(0, 48),
    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
    shape: const StadiumBorder(),
    textStyle: const TextStyle(fontWeight: FontWeight.w600),
  );
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({
    required this.label,
    required this.value,
    this.highlighted = false,
  });

  final String label;
  final String value;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: _successReceiptLabelStyle(context),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: highlighted
                        ? colorScheme.primary
                        : colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

TextStyle? _successReceiptLabelStyle(BuildContext context) {
  return Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 1.25,
      );
}
