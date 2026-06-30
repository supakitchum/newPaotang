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
import '../../../core/utils/formatters.dart';
import '../../../features/purchase_history/data/purchase_history_models.dart';
import '../../../features/purchase_history/data/purchase_history_repository.dart';
import '../../../features/purchase_history/presentation/purchase_history_localization.dart';
import '../../../features/results/data/result_models.dart';
import '../../../features/results/data/result_repository.dart';
import 'success_receipt_state.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/customer_page_body.dart';
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
        final message = data.maintenance.message.isNotEmpty
            ? data.maintenance.message
            : l10n.maintenanceDefaultMessage;
        final supportUri = maintenanceSupportPhoneUri(data.supportPhone);
        return _FullPageState(
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
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            if (data.supportPhone.isNotEmpty)
              OutlinedButton.icon(
                onPressed: supportUri == null
                    ? null
                    : () async {
                        await ref
                            .read(customerLinkLauncherProvider)
                            .openExternal(supportUri);
                      },
                icon: const Icon(Icons.support_agent_outlined),
                label: Text(l10n.maintenanceSupport(data.supportPhone)),
              ),
          ],
        );
      },
      loading: () => _FullPageState(
        icon: Icons.construction_outlined,
        title: l10n.maintenanceLoadingTitle,
        message: l10n.maintenanceLoadingMessage,
        loading: true,
      ),
      error: (_, __) => _FullPageState(
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

class AccountSuspendedScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final untilText = permanent
        ? l10n.accountSuspendedPermanent
        : suspendedUntil == null || suspendedUntil!.isEmpty
            ? l10n.accountSuspendedTemporary
            : l10n.accountSuspendedUntil(
                formatLocalizedDateTime(suspendedUntil, localeTag(l10n.locale)),
              );
    return _FullPageState(
      icon: Icons.shield_outlined,
      iconColor: Colors.red.shade700,
      title: l10n.accountSuspendedTitle,
      message: l10n.accountSuspendedMessage,
      footer: [
        _InfoPanel(
          label: l10n.accountSuspendedReason,
          value: reason.trim().isEmpty
              ? l10n.accountSuspendedNoReason
              : reason.trim(),
        ),
        _InfoPanel(label: l10n.accountSuspendedDuration, value: untilText),
        FilledButton(
          onPressed: () => context.go('/login'),
          child: Text(l10n.accountSuspendedBackToLogin),
        ),
      ],
    );
  }
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
    return AppShell(
      title: l10n.countdownTitle,
      currentPath: '/',
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
          return _SystemPageList(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    children: [
                      const Icon(Icons.hourglass_top, size: 54),
                      const SizedBox(height: 14),
                      Text(
                        l10n.countdownWaitingTitle,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        current?.name.isNotEmpty == true
                            ? current!.name
                            : l10n.countdownCurrentDrawFallback,
                        textAlign: TextAlign.center,
                      ),
                      if (saleStartAt != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          l10n.countdownSaleOpensAt(
                            formatLocalizedDateTime(
                              saleStartAt,
                              localeTag(l10n.locale),
                            ),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 18),
                      _CountdownGrid(remaining: remaining),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => context.go('/result'),
                icon: const Icon(Icons.emoji_events_outlined),
                label: Text(l10n.waitingResultCheckResult),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _ErrorCard(
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

class SuccessScreen extends ConsumerWidget {
  const SuccessScreen({super.key, this.orderId});

  final String? orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = orderId ?? '';
    final receiptBoundaryKey = GlobalKey();
    final productLabel =
        ref.watch(mobileBootstrapProvider).valueOrNull?.lotteryProductLabel ??
            '';
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
      return _SystemPageList(
        children: [
          RepaintBoundary(
            key: receiptBoundaryKey,
            child: _SuccessReceiptCard(
              item: item,
              productLabel: productLabel,
              statusContent: statusContent,
            ),
          ),
          const SizedBox(height: 14),
          if (item != null) ...[
            OutlinedButton.icon(
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
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.successReceiptSaved)),
                );
              },
              icon: const Icon(Icons.download_outlined),
              label: Text(context.l10n.successSaveReceipt),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () async {
                final l10n = context.l10n;
                final receiptText = successReceiptClipboardText(
                  context,
                  item,
                );
                Uint8List? imageBytes;
                Uint8List? pdfBytes;
                try {
                  imageBytes = await ref
                      .read(receiptImageExporterProvider)
                      .capturePng(receiptBoundaryKey);
                } catch (_) {
                  imageBytes = null;
                }
                if (imageBytes != null) {
                  try {
                    pdfBytes = await ref
                        .read(receiptPdfExporterProvider)
                        .buildPdf(imageBytes: imageBytes);
                  } catch (_) {
                    pdfBytes = null;
                  }
                }
                try {
                  await ref.read(receiptShareServiceProvider).shareReceipt(
                        text: receiptText,
                        subject: l10n.successPurchaseTitle,
                        imageBytes: imageBytes,
                        fileName: imageBytes == null
                            ? null
                            : successReceiptImageFileName(item),
                        pdfBytes: pdfBytes,
                        pdfFileName: pdfBytes == null
                            ? null
                            : successReceiptPdfFileName(item),
                      );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.successReceiptShareStarted)),
                  );
                } catch (_) {
                  await Clipboard.setData(ClipboardData(text: receiptText));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.successReceiptShareFailedCopied),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.ios_share_outlined),
              label: Text(context.l10n.successShareReceipt),
            ),
            const SizedBox(height: 10),
          ],
          FilledButton.icon(
            onPressed: () => context.go('/tickets'),
            icon: const Icon(Icons.confirmation_number_outlined),
            label: Text(context.l10n.successViewTickets),
          ),
        ],
      );
    }

    return AppShell(
      title: context.l10n.successTitle,
      currentPath: '/tickets',
      sensitive: true,
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
              actionLabel: context.l10n.commonRetry,
              onAction: () => ref.invalidate(purchaseHistoryDetailProvider(id)),
            ),
          );
        },
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
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            _SuccessReceiptHeader(productLabel: productLabel),
            if (item != null) ...[
              const Divider(height: 30),
              _ReceiptRow(
                label: l10n.purchaseHistoryTicketCountLabel,
                value: l10n.purchaseHistoryTicketCount(item!.ticketCount),
              ),
              _ReceiptRow(
                label: l10n.purchaseHistoryDrawDateLabel,
                value: localizedPurchaseDrawDate(context, item!),
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
    );
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
            const TenantBrandHeader(
              icon: Icons.storefront_outlined,
              showName: false,
              size: 44,
            ),
            if (productLabel.trim().isNotEmpty) ...[
              Container(
                width: 1,
                height: 34,
                margin: const EdgeInsets.symmetric(horizontal: 14),
                color: colorScheme.outlineVariant,
              ),
              Text(
                productLabel.trim(),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        CircleAvatar(
          radius: 36,
          backgroundColor: Colors.green.shade50,
          child: Icon(
            Icons.check_rounded,
            color: Colors.green.shade700,
            size: 42,
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
            const CircularProgressIndicator()
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

class _SuccessTotalRow extends StatelessWidget {
  const _SuccessTotalRow({required this.total});

  final double total;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return LayoutBuilder(
      builder: (context, constraints) {
        final value = Text(
          formatBaht(total),
          textAlign:
              constraints.maxWidth < 360 ? TextAlign.left : TextAlign.end,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        );
        if (constraints.maxWidth < 360) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.purchaseHistoryTotalLabel),
              const SizedBox(height: 4),
              value,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: Text(l10n.purchaseHistoryTotalLabel)),
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

class _SystemPageList extends StatelessWidget {
  const _SystemPageList({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        CustomerPageBody(
          maxWidth: 760,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ],
    );
  }
}

class _FullPageState extends StatelessWidget {
  const _FullPageState({
    required this.icon,
    required this.title,
    required this.message,
    this.iconColor,
    this.footer = const [],
    this.loading = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color? iconColor;
  final List<Widget> footer;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? Theme.of(context).colorScheme.primary;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 42,
                        backgroundColor: color.withValues(alpha: 0.12),
                        child: Icon(icon, size: 42, color: color),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(height: 1.45),
                      ),
                      if (loading) ...[
                        const SizedBox(height: 18),
                        const CircularProgressIndicator(),
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
            ),
          ),
        ),
      ),
    );
  }
}

class _CountdownGrid extends StatelessWidget {
  const _CountdownGrid({required this.remaining});

  final Duration remaining;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 0.95,
      children: [
        for (final item in items)
          DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item.$2.toString().padLeft(2, '0'),
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                Text(item.$1),
              ],
            ),
          ),
      ],
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
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(context.l10n.commonRetry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
