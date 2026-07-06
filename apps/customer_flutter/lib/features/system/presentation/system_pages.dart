import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../../core/i18n/app_locale.dart';
import '../../../core/i18n/customer_localizations.dart';
import '../../../core/navigation/customer_link_launcher.dart';
import '../../../core/tenant/mobile_bootstrap_controller.dart';
import '../../../core/utils/asset_url.dart';
import '../../../core/utils/formatters.dart';
import '../../../features/purchase_history/data/purchase_history_models.dart';
import '../../../features/purchase_history/data/purchase_history_repository.dart';
import '../../../features/purchase_history/presentation/purchase_history_localization.dart';
import '../../../features/results/data/result_models.dart';
import '../../../features/results/data/result_repository.dart';
import 'success_receipt_state.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/customer_loading_indicator.dart';
import '../../../shared/widgets/customer_page_body.dart';
import '../../../shared/widgets/flexible_image.dart';
import '../../../shared/widgets/tenant_brand_header.dart';

final receiptShareServiceProvider = Provider<ReceiptShareService>((ref) {
  return SharePlusReceiptShareService();
});

final receiptImageExporterProvider = Provider<ReceiptImageExporter>((ref) {
  return RepaintBoundaryReceiptImageExporter();
});

final receiptPdfExporterProvider = Provider<ReceiptPdfExporter>((ref) {
  return PdfReceiptPdfExporter();
});

abstract class ReceiptShareService {
  Future<void> shareReceipt({
    required String text,
    required String subject,
    Uint8List? imageBytes,
    String? fileName,
    Uint8List? pdfBytes,
    String? pdfFileName,
  });
}

class SharePlusReceiptShareService implements ReceiptShareService {
  @override
  Future<void> shareReceipt({
    required String text,
    required String subject,
    Uint8List? imageBytes,
    String? fileName,
    Uint8List? pdfBytes,
    String? pdfFileName,
  }) async {
    final imageFileName = fileName ?? 'receipt.png';
    final pdfName = pdfFileName ?? 'receipt.pdf';
    final files = <XFile>[];
    final fileNameOverrides = <String>[];
    if (imageBytes != null && imageBytes.isNotEmpty) {
      files.add(
        XFile.fromData(
          imageBytes,
          mimeType: 'image/png',
          name: imageFileName,
        ),
      );
      fileNameOverrides.add(imageFileName);
    }
    if (pdfBytes != null && pdfBytes.isNotEmpty) {
      files.add(
        XFile.fromData(
          pdfBytes,
          mimeType: 'application/pdf',
          name: pdfName,
        ),
      );
      fileNameOverrides.add(pdfName);
    }
    await SharePlus.instance.share(
      ShareParams(
        text: text,
        title: subject,
        subject: subject,
        files: files.isEmpty ? null : files,
        fileNameOverrides: fileNameOverrides.isEmpty ? null : fileNameOverrides,
      ),
    );
  }
}

abstract class ReceiptImageExporter {
  Future<Uint8List> capturePng(GlobalKey boundaryKey);
}

class RepaintBoundaryReceiptImageExporter implements ReceiptImageExporter {
  @override
  Future<Uint8List> capturePng(GlobalKey boundaryKey) async {
    await Future<void>.delayed(Duration.zero);
    final context = boundaryKey.currentContext;
    final renderObject = context?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) {
      throw StateError('Receipt boundary is not ready.');
    }
    final image = await renderObject.toImage(pixelRatio: 3);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) {
        throw StateError('Could not export receipt image.');
      }
      return bytes.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }
}

abstract class ReceiptPdfExporter {
  Future<Uint8List> buildPdf({required Uint8List imageBytes});
}

class PdfReceiptPdfExporter implements ReceiptPdfExporter {
  @override
  Future<Uint8List> buildPdf({required Uint8List imageBytes}) async {
    if (imageBytes.isEmpty) {
      throw StateError('Receipt image is required for PDF export.');
    }
    final document = pw.Document();
    final image = pw.MemoryImage(imageBytes);
    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (_) => pw.Center(
          child: pw.Image(image, fit: pw.BoxFit.contain),
        ),
      ),
    );
    return document.save();
  }
}

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
        final supportLabel = supportUri != null
            ? l10n.maintenanceSupport(data.supportPhone)
            : supportEmailUri != null
                ? l10n.maintenanceSupportEmail(data.supportEmail)
                : l10n.maintenanceSupportOnline;
        final supportIcon = supportUri != null
            ? Icons.support_agent_outlined
            : supportEmailUri != null
                ? Icons.mail_outline
                : Icons.open_in_new;
        return _MaintenanceStatePage(
          icon: Icons.construction_outlined,
          title: l10n.maintenanceTitle(data.siteName),
          message: message,
          footer: [
            if (data.maintenance.expectedEndAt != null)
              Text(
                l10n.maintenanceExpectedEnd(
                  formatLocalizedDateTime(
                    data.maintenance.expectedEndAt,
                    localeTag(l10n.locale),
                  ),
                ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colorScheme.onPrimary.withValues(alpha: 0.86),
                  fontWeight: FontWeight.w800,
                  height: 1.35,
                ),
              ),
            if (supportActionUri != null)
              OutlinedButton.icon(
                onPressed: () async {
                  await ref
                      .read(customerLinkLauncherProvider)
                      .openExternal(supportActionUri);
                },
                icon: Icon(supportIcon),
                label: Text(supportLabel),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.primary,
                  backgroundColor: colorScheme.surface,
                  side: BorderSide.none,
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(fontWeight: FontWeight.w900),
                ),
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
  final sanitized = phone.trim().replaceAll(RegExp(r'[^\d+]'), '');
  if (sanitized.isEmpty) return null;
  final normalized = sanitized.startsWith('+')
      ? '+${sanitized.substring(1).replaceAll('+', '')}'
      : sanitized.replaceAll('+', '');
  if (normalized.replaceAll('+', '').isEmpty) return null;
  return Uri(scheme: 'tel', path: normalized);
}

Uri? maintenanceSupportUrlUri(String url) {
  final uri = Uri.tryParse(url.trim());
  return uri?.scheme.toLowerCase() == 'https' && isSafeExternalLinkUri(uri)
      ? uri
      : null;
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
    final bootstrap = ref.watch(mobileBootstrapProvider).valueOrNull;
    final supportPhone = bootstrap?.supportPhone.trim() ?? '';
    final supportEmail = bootstrap?.supportEmail.trim() ?? '';
    final supportPhoneUri = maintenanceSupportPhoneUri(supportPhone);
    final supportEmailUri = systemSupportEmailUri(supportEmail);
    final supportUrlUri = maintenanceSupportUrlUri(bootstrap?.supportUrl ?? '');
    final supportActionUri =
        supportPhoneUri ?? supportEmailUri ?? supportUrlUri;
    final supportLabel = supportPhoneUri != null
        ? l10n.accountSuspendedContactSupportWithPhone(supportPhone)
        : supportEmailUri != null
            ? l10n.accountSuspendedContactSupportWithEmail(supportEmail)
            : l10n.accountSuspendedContactSupportOnline;
    final supportIcon = supportPhoneUri != null
        ? Icons.support_agent_outlined
        : supportEmailUri != null
            ? Icons.mail_outline
            : Icons.open_in_new;
    final untilText = permanent
        ? l10n.accountSuspendedPermanent
        : suspendedUntil == null || suspendedUntil!.isEmpty
            ? l10n.accountSuspendedTemporary
            : l10n.accountSuspendedUntil(
                formatLocalizedDateTime(suspendedUntil, localeTag(l10n.locale)),
              );
    return _AccountSuspendedStatePage(
      title: l10n.accountSuspendedTitle,
      message: l10n.accountSuspendedMessage,
      reason:
          reason.trim().isEmpty ? l10n.accountSuspendedNoReason : reason.trim(),
      duration: untilText,
      onBackToLogin: () => context.go('/login'),
      supportLabel: supportLabel,
      supportIcon: supportIcon,
      onContactSupport: supportActionUri == null
          ? null
          : () {
              unawaited(
                ref
                    .read(customerLinkLauncherProvider)
                    .openExternal(supportActionUri),
              );
            },
    );
  }
}

Uri? systemSupportEmailUri(String email) {
  final normalized = email.trim();
  if (normalized.isEmpty || normalized.contains(RegExp(r'\s'))) return null;
  if (!normalized.contains('@')) return null;
  return Uri(scheme: 'mailto', path: normalized);
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
    final game = ref.watch(currentResultProvider);
    final l10n = context.l10n;
    final productLabel =
        ref.watch(mobileBootstrapProvider).valueOrNull?.lotteryProductLabel ??
            '';
    return AppShell(
      title: l10n.countdownTitle,
      currentPath: '/',
      compactHeader: true,
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
            currentName: current?.name.isNotEmpty == true
                ? current!.name
                : l10n.countdownCurrentDrawFallback,
            saleStartAt: saleStartAt,
            remaining: remaining,
            productLabel: productLabel,
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
  String _receiptNoticeMessage = '';
  bool _receiptNoticeSuccess = false;

  @override
  Widget build(BuildContext context) {
    final id = widget.orderId ?? '';
    final receiptBoundaryKey = GlobalKey();
    final bootstrapProductLabel =
        ref.watch(mobileBootstrapProvider).valueOrNull?.lotteryProductLabel ??
            '';
    final productLabel = _successProductLabel(
      context,
      bootstrapProductLabel,
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
        children: [
          RepaintBoundary(
            key: receiptBoundaryKey,
            child: _SuccessReceiptCard(
              item: item,
              productLabel: productLabel,
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
          if (item != null) ...[
            _SuccessReceiptSaveAction(
              onPressed: () async {
                final l10n = context.l10n;
                final receiptText = successReceiptClipboardText(
                  context,
                  item,
                );
                await Clipboard.setData(
                  ClipboardData(
                    text: receiptText,
                  ),
                );
                if (!context.mounted) return;
                _showReceiptNotice(l10n.successReceiptSaved, success: true);
              },
            ),
          ],
          const SizedBox(height: 238),
          _SuccessPrimaryActionButton(
            onPressed: () => context.go('/tickets'),
            label: context.l10n.successViewTickets,
          ),
        ],
      );
    }

    return AppShell(
      title: context.l10n.successTitle,
      currentPath: '/tickets',
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

  void _showReceiptNotice(String message, {bool success = false}) {
    if (!mounted) return;
    setState(() {
      _receiptNoticeMessage = message;
      _receiptNoticeSuccess = success;
    });
  }
}

class _SuccessPageList extends StatelessWidget {
  const _SuccessPageList({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        return ListView(
          padding: EdgeInsets.zero,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.primary,
                      Color.lerp(
                            colorScheme.primary,
                            colorScheme.secondary,
                            0.72,
                          ) ??
                          colorScheme.secondary,
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -74,
                      bottom: 18,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colorScheme.tertiary.withValues(alpha: 0.88),
                          shape: BoxShape.circle,
                        ),
                        child: const SizedBox.square(dimension: 210),
                      ),
                    ),
                    Positioned(
                      right: 34,
                      bottom: 132,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.36),
                          shape: BoxShape.circle,
                        ),
                        child: const SizedBox.square(dimension: 220),
                      ),
                    ),
                    SafeArea(
                      bottom: false,
                      child: CustomerPageBody(
                        maxWidth: 430,
                        top: 54,
                        bottom: 142,
                        mobileHorizontal: 18,
                        wideHorizontal: 0,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: children,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SuccessReceiptSaveAction extends StatelessWidget {
  const _SuccessReceiptSaveAction({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
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
              textStyle: const TextStyle(fontWeight: FontWeight.w900),
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

class _SuccessPrimaryActionButton extends StatelessWidget {
  const _SuccessPrimaryActionButton({
    required this.onPressed,
    required this.label,
  });

  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final secondary =
        Color.lerp(colorScheme.primary, colorScheme.secondary, 0.72) ??
            colorScheme.secondary;
    return SizedBox(
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [secondary, colorScheme.primary]),
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withValues(alpha: 0.22),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: colorScheme.onPrimary,
            shadowColor: Colors.transparent,
            minimumSize: const Size.fromHeight(56),
            shape: const StadiumBorder(),
            textStyle: const TextStyle(fontWeight: FontWeight.w900),
          ).copyWith(
            overlayColor: WidgetStatePropertyAll(
              colorScheme.onPrimary.withValues(alpha: 0.08),
            ),
          ),
          child: Text(label, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}

class _SuccessReceiptCard extends StatelessWidget {
  const _SuccessReceiptCard({
    required this.item,
    required this.productLabel,
    this.statusContent,
  });

  final PurchaseHistoryOrder? item;
  final String productLabel;
  final Widget? statusContent;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: _successReceiptSurfaceDecoration(context),
      child: CustomPaint(
        painter: _SuccessReceiptStripePainter(
          color: colorScheme.primary.withValues(alpha: 0.035),
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
                        fontWeight: FontWeight.w700,
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

class _SuccessReceiptStripePainter extends CustomPainter {
  const _SuccessReceiptStripePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const stripeWidth = 28.0;
    const stripeStep = 66.0;
    final slant = size.height * 0.58;
    for (var x = -slant - stripeWidth;
        x < size.width + slant;
        x += stripeStep) {
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
  bool shouldRepaint(_SuccessReceiptStripePainter oldDelegate) {
    return oldDelegate.color != color;
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
            color: colorScheme.tertiary,
            shape: BoxShape.circle,
          ),
          child: SizedBox.square(
            dimension: 62,
            child: Icon(
              Icons.check_rounded,
              color: colorScheme.onTertiary,
              size: 38,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          l10n.successPurchaseTitle,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w900),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          l10n.successPurchaseSubtitle,
          textAlign: TextAlign.center,
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
    return SizedBox.square(
      dimension: 44,
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
              width: 36,
              height: 36,
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
                color: colorScheme.primary,
                fontSize: 30,
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
                  fontWeight: FontWeight.w800,
                ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
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
  final channel = localizedPurchasePaymentChannel(item);
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
        child: CustomerPageBody(
          maxWidth: 560,
          top: 32,
          bottom: 32,
          mobileHorizontal: 24,
          wideHorizontal: 24,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const TenantBrandHeader(showName: false, size: 82),
              const SizedBox(height: 16),
              _SystemWhiteIcon(icon: icon, color: colorScheme.primary),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: colorScheme.onPrimary,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      height: 1.25,
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colorScheme.onPrimary.withValues(alpha: 0.9),
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  height: 1.55,
                ),
              ),
              if (loading) ...[
                const SizedBox(height: 18),
                CustomerLoadingMark(
                  width: 46,
                  height: 26,
                  color: colorScheme.onPrimary,
                  trackColor: colorScheme.onPrimary.withValues(alpha: 0.24),
                  semanticLabel: message,
                ),
              ],
              if (footer.isNotEmpty) ...[
                const SizedBox(height: 18),
                for (final item in footer)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: item,
                  ),
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
    required this.supportLabel,
    required this.supportIcon,
    this.onContactSupport,
  });

  final String title;
  final String message;
  final String reason;
  final String duration;
  final VoidCallback onBackToLogin;
  final String supportLabel;
  final IconData supportIcon;
  final VoidCallback? onContactSupport;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: _SystemGradientScaffold(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        child: CustomerPageBody(
          maxWidth: 440,
          top: 32,
          bottom: 32,
          mobileHorizontal: 20,
          wideHorizontal: 20,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const TenantBrandHeader(showName: false, size: 74),
              const SizedBox(height: 18),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.18),
                      blurRadius: 50,
                      offset: const Offset(0, 22),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
                  child: Column(
                    children: [
                      _SystemWhiteIcon(
                        icon: Icons.lock_outline,
                        color: colorScheme.error,
                        backgroundColor: Color.lerp(
                              colorScheme.error,
                              colorScheme.surface,
                              0.88,
                            ) ??
                            colorScheme.errorContainer.withValues(alpha: 0.52),
                        size: 74,
                        radius: 24,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        l10n.accountSuspendedKicker,
                        style: TextStyle(
                          color: colorScheme.error,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          height: 1.25,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: colorScheme.onSurface,
                                  fontSize: 25,
                                  fontWeight: FontWeight.w900,
                                  height: 1.22,
                                ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          height: 1.55,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _InfoPanel(
                        label: l10n.accountSuspendedReason,
                        value: reason,
                      ),
                      const SizedBox(height: 10),
                      _InfoPanel(
                        label: l10n.accountSuspendedDuration,
                        value: duration,
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: onBackToLogin,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            shape: const StadiumBorder(),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          child: Text(l10n.accountSuspendedBackToLogin),
                        ),
                      ),
                      if (onContactSupport != null) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: onContactSupport,
                            icon: Icon(supportIcon),
                            label: Text(
                              supportLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: colorScheme.primary,
                              minimumSize: const Size.fromHeight(50),
                              side: BorderSide(
                                color: colorScheme.primary.withValues(
                                  alpha: 0.28,
                                ),
                              ),
                              shape: const StadiumBorder(),
                              textStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ],
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
    required this.currentName,
    required this.saleStartAt,
    required this.remaining,
    required this.productLabel,
    required this.onCheckResult,
  });

  final String currentName;
  final DateTime? saleStartAt;
  final Duration remaining;
  final String productLabel;
  final VoidCallback onCheckResult;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;

    return _SystemGradientScaffold(
      child: CustomerPageBody(
        maxWidth: 560,
        top: 48,
        bottom: 124,
        mobileHorizontal: 20,
        wideHorizontal: 20,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const TenantBrandHeader(showName: false, size: 64),
                if (productLabel.trim().isNotEmpty) ...[
                  const SizedBox(width: 16),
                  Text(
                    productLabel.trim(),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: colorScheme.onPrimary,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 28),
            Text(
              l10n.countdownWaitingTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.tertiary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.countdownOpensIn,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: colorScheme.onPrimary,
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                    height: 1.08,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              currentName,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.onPrimary.withValues(alpha: 0.92),
                fontWeight: FontWeight.w800,
                height: 1.35,
              ),
            ),
            if (saleStartAt != null) ...[
              const SizedBox(height: 8),
              Text(
                l10n.countdownSaleOpensAt(
                  formatLocalizedDateTime(
                    saleStartAt,
                    localeTag(l10n.locale),
                  ),
                ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colorScheme.onPrimary.withValues(alpha: 0.82),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
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
                fontWeight: FontWeight.w800,
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
                fontWeight: FontWeight.w800,
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
  });

  final Widget child;
  final AlignmentGeometry begin;
  final AlignmentGeometry end;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final midColor =
        Color.lerp(colorScheme.primary, colorScheme.surface, 0.18) ??
            colorScheme.primary;
    final endColor =
        Color.lerp(colorScheme.primary, colorScheme.secondary, 0.34) ??
            colorScheme.primary;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: begin,
          end: end,
          colors: [colorScheme.primary, midColor, endColor],
        ),
      ),
      child: SafeArea(
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
      ),
    );
  }
}

class _SystemWhiteIcon extends StatelessWidget {
  const _SystemWhiteIcon({
    required this.icon,
    required this.color,
    this.backgroundColor,
    this.size = 82,
    this.radius = 22,
  });

  final IconData icon;
  final Color color;
  final Color? backgroundColor;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(radius),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: color, size: size * 0.42),
    );
  }
}

class _CountdownGrid extends StatelessWidget {
  const _CountdownGrid({required this.remaining});

  final Duration remaining;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final onGradient = colorScheme.onPrimary;
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
        final columns = constraints.maxWidth <= 380 ? 2 : 4;

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: columns,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: columns == 2 ? 1.7 : 0.95,
          children: [
            for (final item in items)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.26),
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
                                fontWeight: FontWeight.w900,
                                height: 1,
                              ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.$1,
                      style: TextStyle(
                        color: onGradient.withValues(alpha: 0.86),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
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
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.42),
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
                color: colorScheme.onSurfaceVariant,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w900,
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
    textStyle: const TextStyle(fontWeight: FontWeight.w900),
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
        fontWeight: FontWeight.w500,
        height: 1.25,
      );
}
