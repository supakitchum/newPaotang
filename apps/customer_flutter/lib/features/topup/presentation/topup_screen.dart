import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/customer_localizations.dart';
import '../../../core/navigation/customer_back_navigation.dart';
import '../../../core/navigation/customer_link_launcher.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/services/receipt_export_service.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/customer_fixed_header_layout.dart';
import '../../../shared/widgets/customer_gradient_button.dart';
import '../../../shared/widgets/customer_loading_indicator.dart';
import '../../../shared/widgets/customer_page_body.dart';
import '../../../shared/widgets/flexible_image.dart';
import '../../../shared/utils/customer_operational_error.dart';
import '../data/topup_models.dart';
import '../data/topup_repository.dart';
import 'topup_error_message.dart';
import 'topup_money_format.dart';
import 'topup_realtime_monitor.dart';
import 'topup_slip_picker.dart';

const _topupBackPathFallback = '/my-wallet';
const _topupBackPathAllowlist = {'/', '/checkout', '/my-wallet', '/profile'};
const _topupDetailBackPathAllowlist = {
  ..._topupBackPathAllowlist,
  '/topup/history',
};

typedef TopupQrImagePreloader =
    Future<void> Function(BuildContext context, ImageProvider<Object> provider);

typedef TopupQrSaveCallback = void Function(ImageProvider<Object> provider);

final topupQrImagePreloaderProvider = Provider<TopupQrImagePreloader>((ref) {
  return (context, provider) async {
    await precacheImage(provider, context);
  };
});

Future<void> _waitForTopupQrFrame() {
  final completer = Completer<void>();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!completer.isCompleted) completer.complete();
  });
  WidgetsBinding.instance.ensureVisualUpdate();
  return completer.future;
}

Color _topupPrimaryTint(ColorScheme colorScheme) =>
    Color.lerp(colorScheme.primary, colorScheme.surface, 0.88) ??
    colorScheme.primary.withValues(alpha: 0.12);

Color _topupSoftSurface(ColorScheme colorScheme) =>
    Color.lerp(colorScheme.primary, colorScheme.surface, 0.94) ??
    colorScheme.surface;

Color _topupPrimaryBorder(ColorScheme colorScheme) =>
    Color.lerp(colorScheme.primary, colorScheme.surface, 0.76) ??
    colorScheme.primary.withValues(alpha: 0.24);

Color _topupSuccessTint(ColorScheme colorScheme) =>
    Color.lerp(colorScheme.primary, colorScheme.surface, 0.88) ??
    colorScheme.primary.withValues(alpha: 0.12);

Color _topupSuccessForeground(ColorScheme colorScheme) => colorScheme.primary;

Color _topupWarningTint(ColorScheme colorScheme) =>
    Color.lerp(colorScheme.tertiary, colorScheme.surface, 0.86) ??
    colorScheme.tertiary.withValues(alpha: 0.14);

Color _topupWarningBorder(ColorScheme colorScheme) =>
    Color.lerp(colorScheme.tertiary, colorScheme.surface, 0.62) ??
    colorScheme.tertiary.withValues(alpha: 0.38);

Color _topupWarningForeground(ColorScheme colorScheme) => colorScheme.tertiary;

Color _topupErrorTint(ColorScheme colorScheme) =>
    Color.lerp(colorScheme.error, colorScheme.surface, 0.88) ??
    colorScheme.errorContainer.withValues(alpha: 0.52);

Color _topupErrorBorder(ColorScheme colorScheme) =>
    Color.lerp(colorScheme.error, colorScheme.surface, 0.68) ??
    colorScheme.error.withValues(alpha: 0.32);

Color _topupErrorForeground(ColorScheme colorScheme) => colorScheme.error;

Color _topupStatusBackground(TopupStatus status, ColorScheme colorScheme) {
  return switch (status) {
    TopupStatus.pendingPayment => _topupPrimaryTint(colorScheme),
    TopupStatus.pendingReview => _topupWarningTint(colorScheme),
    TopupStatus.approved => _topupSuccessTint(colorScheme),
    TopupStatus.rejected => _topupErrorTint(colorScheme),
    TopupStatus.cancelled ||
    TopupStatus.expired ||
    TopupStatus.unknown => colorScheme.surfaceContainerHighest,
  };
}

Color _topupStatusForeground(TopupStatus status, ColorScheme colorScheme) {
  return switch (status) {
    TopupStatus.pendingPayment => colorScheme.primary,
    TopupStatus.pendingReview => _topupWarningForeground(colorScheme),
    TopupStatus.approved => _topupSuccessForeground(colorScheme),
    TopupStatus.rejected => _topupErrorForeground(colorScheme),
    TopupStatus.cancelled ||
    TopupStatus.expired ||
    TopupStatus.unknown => colorScheme.onSurfaceVariant,
  };
}

String safeTopupBackPath(String? value) {
  final target = (value ?? '').trim();
  return _topupBackPathAllowlist.contains(target)
      ? target
      : _topupBackPathFallback;
}

String safeTopupDetailBackPath(String? value) {
  final target = (value ?? '').trim();
  return _topupDetailBackPathAllowlist.contains(target)
      ? target
      : _topupBackPathFallback;
}

String topupDetailLocation(String id, {String? backPath}) {
  final encodedId = Uri.encodeComponent(id.trim());
  final safeBackPath = safeTopupDetailBackPath(backPath);
  final query = Uri(queryParameters: {'back': safeBackPath}).query;
  return '/topup/$encodedId?$query';
}

String topupLocation({String? backPath}) {
  final query = Uri(
    queryParameters: {'back': safeTopupBackPath(backPath)},
  ).query;
  return '/topup?$query';
}

String _safeTopupFileId(String value) {
  final normalized = value.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '-');
  return normalized.isEmpty ? 'qr' : normalized;
}

TopupOverview _emptyTopupOverview() {
  return const TopupOverview(
    bank: TopupBankAccount(bankName: '', accountName: '', accountNumber: ''),
    paymentMethods: [],
    enabledPaymentMethods: {},
    waiting: null,
    histories: [],
    currentPage: 1,
    lastPage: 1,
  );
}

class TopupScreen extends ConsumerStatefulWidget {
  const TopupScreen({
    super.key,
    this.backPath = _topupBackPathFallback,
    this.detailTopupId,
  });

  final String backPath;
  final String? detailTopupId;

  @override
  ConsumerState<TopupScreen> createState() => _TopupScreenState();
}

class _TopupScreenState extends ConsumerState<TopupScreen> {
  final _amount = TextEditingController(text: '500');
  final _qrExportBoundaryKey = GlobalKey();
  TopupChannel _selectedChannel = TopupChannel.qr;
  TopupSlipUpload? _bankTransferSlip;
  DateTime? _bankTransferAt;
  DateTime? _waitingSlipTransferAt;
  bool _submitting = false;
  bool _uploadingSlip = false;
  bool _savingQr = false;
  bool _feedbackDialogOpen = false;
  final Set<String> _expiringTopupIds = <String>{};
  final Set<String> _submittedSlipTopupIds = <String>{};
  String _pageNoticeMessage = '';
  bool _pageNoticeIsError = true;
  String _sheetNoticeMessage = '';
  bool _sheetNoticeIsError = true;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detailTopupId = widget.detailTopupId?.trim();
    if (detailTopupId != null && detailTopupId.isNotEmpty) {
      return _buildTopupDetailPage(detailTopupId);
    }

    ref.listen<int>(topupRealtimeTickProvider, (previous, next) {
      if (previous == null || previous == next) return;
      ref.invalidate(topupOverviewProvider);
    });
    listenForCustomerOperationalError<TopupOverview>(
      ref: ref,
      context: context,
      provider: topupOverviewProvider,
    );

    final overview = ref.watch(topupOverviewProvider);
    final l10n = context.l10n;

    return AppShell(
      title: l10n.topupTitle,
      currentPath: '/topup',
      backPath: widget.backPath,
      sensitive: true,
      showBottomNavigation: false,
      fullScreen: true,
      child: overview.when(
        data: _buildTopupPage,
        loading: () => _buildTopupPage(
          _emptyTopupOverview(),
          overviewState: _TopupOverviewState.loading,
        ),
        error: (error, _) => _buildTopupPage(
          _emptyTopupOverview(),
          overviewState: _TopupOverviewState.error,
          overviewMessage: topupErrorMessage(
            error,
            l10n.topupLoadFailedMessage,
          ),
        ),
      ),
    );
  }

  Widget _buildTopupDetailPage(String topupId) {
    ref.listen<int>(topupRealtimeTickProvider, (previous, next) {
      if (previous == null || previous == next) return;
      ref.invalidate(topupDetailProvider(topupId));
      ref.invalidate(topupOverviewProvider);
    });
    listenForCustomerOperationalError<TopupRequestItem>(
      ref: ref,
      context: context,
      provider: topupDetailProvider(topupId),
    );

    final detail = ref.watch(topupDetailProvider(topupId));
    final l10n = context.l10n;
    final backPath = safeTopupDetailBackPath(widget.backPath);

    return AppShell(
      title: l10n.topupDetailTitle,
      currentPath: '/topup/$topupId',
      backPath: backPath,
      sensitive: true,
      showBottomNavigation: false,
      fullScreen: true,
      child: detail.when(
        data: (topup) {
          final usesQrLayout =
              topup.channel == TopupChannel.qr ||
              topup.channel == TopupChannel.creditCard;
          return _TopupDetailPageShell(
            backPath: backPath,
            blueBackground: usesQrLayout,
            child: _WaitingTopupCard(
              title: l10n.topupDetailRequestTitle,
              topup: topup,
              simplifiedQrDetail: true,
              qrExportBoundaryKey: _qrExportBoundaryKey,
              savingQr: _savingQr,
              onSaveQr: _savingQr
                  ? null
                  : (provider) => _saveTopupQr(topup, provider),
              uploadingSlip: _uploadingSlip,
              waitingSlipTransferAt: _waitingSlipTransferAt,
              onUploadSlip: _uploadingSlip
                  ? null
                  : () => _pickAndUploadSlip(topup.id),
              onSelectSlipTransferAt: _uploadingSlip
                  ? null
                  : () => _selectWaitingSlipTransferAt(topup),
              onOpenPayment: topup.redirectUri == null
                  ? null
                  : () => _openPayment(topup),
              onCancel: _submitting
                  ? null
                  : () => _confirmCancelWaitingTopup(topup),
              onQrExpired: () => _expireWaitingTopup(topup),
              onReportProblem: () => context.push('/support/new'),
            ),
          );
        },
        loading: () => _TopupDetailPageShell(
          backPath: backPath,
          child: _TopupOverviewStatePanel(
            state: _TopupOverviewState.loading,
            message: l10n.topupDetailLoadingMessage,
            onRetry: () => ref.invalidate(topupDetailProvider(topupId)),
          ),
        ),
        error: (error, _) => _TopupDetailPageShell(
          backPath: backPath,
          child: _TopupOverviewStatePanel(
            state: _TopupOverviewState.error,
            message: topupErrorMessage(error, l10n.topupDetailLoadFailed),
            onRetry: () => ref.invalidate(topupDetailProvider(topupId)),
          ),
        ),
      ),
    );
  }

  Widget _buildTopupPage(
    TopupOverview data, {
    _TopupOverviewState overviewState = _TopupOverviewState.ready,
    String overviewMessage = '',
  }) {
    final waiting = data.waiting;
    final hasWaiting = waiting != null;
    if (waiting != null && !waiting.status.isTerminal) {
      _scheduleWaitingTopupRedirect(waiting);
    }
    final interactionsEnabled = overviewState == _TopupOverviewState.ready;
    return _TopupPageShell(
      hasWaiting: hasWaiting,
      hero: _TopupHeroContent(
        title: context.l10n.topupTitleFor(data.walletName),
        backPath: widget.backPath,
        showHistory: true,
        overview: data,
        overviewState: overviewState,
        overviewMessage: overviewMessage,
        noticeMessage: _pageNoticeMessage,
        noticeIsError: _pageNoticeIsError,
        interactionsEnabled: interactionsEnabled,
        onRetry: () => ref.invalidate(topupOverviewProvider),
        onHistory: () => context.push('/topup/history'),
        onChannelSelected: (channel) => _openTopupSheet(data, channel),
      ),
      waiting: hasWaiting
          ? _WaitingTopupCard(
              topup: waiting,
              uploadingSlip: _uploadingSlip,
              waitingSlipTransferAt: _waitingSlipTransferAt,
              onUploadSlip: _uploadingSlip
                  ? null
                  : () => _pickAndUploadSlip(waiting.id),
              onSelectSlipTransferAt: _uploadingSlip
                  ? null
                  : () => _selectWaitingSlipTransferAt(waiting),
              onOpenPayment: waiting.redirectUri == null
                  ? null
                  : () => _openPayment(waiting),
              onCancel: _submitting
                  ? null
                  : () => _confirmCancelWaitingTopup(waiting),
            )
          : null,
      instructionSheet: null,
    );
  }

  Future<void> _openTopupSheet(
    TopupOverview overview,
    TopupChannel channel,
  ) async {
    final blockedByWaiting =
        overview.waiting != null && !overview.waiting!.status.isTerminal;
    if (blockedByWaiting || !overview.isChannelEnabled(channel)) return;

    setState(() {
      _selectedChannel = channel;
      _sheetNoticeMessage = '';
      _pageNoticeMessage = '';
      if (channel == TopupChannel.bankTransfer) {
        _bankTransferAt ??= DateTime.now();
      }
    });

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      barrierColor: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.55),
      elevation: 0,
      builder: (sheetContext) {
        var showPaymentDetails = false;
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            Future<void> submitTopup() async {
              if (_submitting) return;
              final navigator = Navigator.of(sheetContext);
              final pending = _submitTopup(
                channelOverride: channel,
                method: overview.methodForChannel(channel),
              );
              if (sheetContext.mounted) setSheetState(() {});
              final created = await pending;
              if (created != null && navigator.mounted) {
                navigator.pop();
                _goToTopupDetail(created.id);
              }
              if (sheetContext.mounted) setSheetState(() {});
            }

            Future<void> continueToPaymentDetails() async {
              if (!_validateTopupAmount(
                channel: channel,
                method: overview.methodForChannel(channel),
              )) {
                if (sheetContext.mounted) setSheetState(() {});
                return;
              }
              FocusScope.of(sheetContext).unfocus();
              setState(() => _sheetNoticeMessage = '');
              showPaymentDetails = true;
              if (sheetContext.mounted) setSheetState(() {});
            }

            void editAmount() {
              setState(() => _sheetNoticeMessage = '');
              showPaymentDetails = false;
              if (sheetContext.mounted) setSheetState(() {});
            }

            Future<void> pickBankTransferSlip() async {
              await _pickBankTransferSlip();
              if (sheetContext.mounted) setSheetState(() {});
            }

            void clearBankTransferSlip() {
              _clearBankTransferSlip();
              if (sheetContext.mounted) setSheetState(() {});
            }

            Future<void> selectBankTransferAt() async {
              await _selectBankTransferAt();
              if (sheetContext.mounted) setSheetState(() {});
            }

            Future<void> selectQuickAmount(int amount) async {
              if (_submitting) return;
              _amount.value = TextEditingValue(
                text: amount.toString(),
                selection: TextSelection.collapsed(
                  offset: amount.toString().length,
                ),
              );
            }

            return _TopupSheetContent(
              overview: overview,
              amount: _amount,
              selectedChannel: channel,
              selectedMethod: overview.methodForChannel(channel),
              bankTransferSlip: _bankTransferSlip,
              bankTransferAt: _bankTransferAt,
              noticeMessage: _sheetNoticeMessage,
              noticeIsError: _sheetNoticeIsError,
              submitting: _submitting,
              showPaymentDetails: showPaymentDetails,
              onPickBankTransferSlip: pickBankTransferSlip,
              onClearBankTransferSlip: clearBankTransferSlip,
              onSelectBankTransferAt: selectBankTransferAt,
              onContinueToPaymentDetails: continueToPaymentDetails,
              onQuickAmountSelected: selectQuickAmount,
              onEditAmount: editAmount,
              onSubmit: submitTopup,
            );
          },
        );
      },
    );
  }

  Future<TopupRequestItem?> _submitTopup({
    TopupChannel? channelOverride,
    TopupPaymentMethod? method,
  }) async {
    if (_submitting) return null;
    final channel = channelOverride ?? _selectedChannel;
    final l10n = context.l10n;
    if (!_validateTopupAmount(channel: channel, method: method)) {
      return null;
    }
    final amount = double.tryParse(_amount.text.trim()) ?? 0;
    if (channel == TopupChannel.bankTransfer && _bankTransferSlip == null) {
      _setSheetNotice(l10n.topupBankSlipRequired);
      return null;
    }

    setState(() {
      _submitting = true;
      _sheetNoticeMessage = '';
    });
    final loadingOverlay = channel == TopupChannel.bankTransfer
        ? null
        : _showTopupLoadingOverlay(l10n.topupCreatingQr);
    try {
      final repo = ref.read(topupRepositoryProvider);
      late final TopupRequestItem created;
      if (channel == TopupChannel.creditCard) {
        created = await repo.createCredit(amount: amount);
      } else {
        created = await repo.create(
          channel: channel,
          amount: amount,
          transferAt: channel == TopupChannel.bankTransfer
              ? _bankTransferAt
              : null,
          slip: channel == TopupChannel.bankTransfer ? _bankTransferSlip : null,
        );
      }
      _invalidateTopupSurfaces(created.id);
      if (channel == TopupChannel.bankTransfer) {
        setState(() {
          _bankTransferSlip = null;
          _bankTransferAt = null;
        });
      } else {
        setState(() => _waitingSlipTransferAt = null);
      }
      _setPageNotice(
        channel == TopupChannel.bankTransfer
            ? l10n.topupBankTransferSubmitted
            : l10n.topupCreated,
        isError: false,
      );
      return created;
    } catch (error) {
      if (!mounted) return null;
      final message = topupErrorMessage(error, l10n.topupCreateFailed);
      if (await handleCustomerOperationalError(
        ref: ref,
        context: context,
        error: error,
      )) {
        return null;
      }
      _setSheetNotice(message);
      return null;
    } finally {
      _removeTopupLoadingOverlay(loadingOverlay);
      if (mounted) setState(() => _submitting = false);
    }
  }

  OverlayEntry? _showTopupLoadingOverlay(String label) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return null;
    final entry = OverlayEntry(
      builder: (overlayContext) {
        final colorScheme = Theme.of(overlayContext).colorScheme;
        return Stack(
          fit: StackFit.expand,
          children: [
            ModalBarrier(
              dismissible: false,
              color: colorScheme.scrim.withValues(alpha: 0.48),
            ),
            _TopupCreateLoadingDialog(label: label),
          ],
        );
      },
    );
    overlay.insert(entry);
    return entry;
  }

  void _removeTopupLoadingOverlay(OverlayEntry? entry) {
    if (entry == null) return;
    entry.remove();
    entry.dispose();
  }

  bool _validateTopupAmount({
    required TopupChannel channel,
    TopupPaymentMethod? method,
  }) {
    final amount = double.tryParse(_amount.text.trim()) ?? 0;
    final l10n = context.l10n;
    if (amount <= 0) {
      _setSheetNotice(l10n.topupAmountRequired);
      return false;
    }
    final minimumAmount = method?.minimumAmount ?? 0;
    if (minimumAmount > 0 && amount < minimumAmount) {
      _setSheetNotice(
        l10n.topupMinimumAmount(
          _channelLabel(l10n, channel, method),
          formatTopupBaht(l10n, minimumAmount),
        ),
      );
      return false;
    }
    return true;
  }

  void _scheduleWaitingTopupRedirect(TopupRequestItem waiting) {
    final id = waiting.id.trim();
    if (id.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final uri = _currentRouterUri();
      if (uri?.path == '/topup/$id') return;
      _goToTopupDetail(id);
    });
  }

  Uri? _currentRouterUri() {
    try {
      return GoRouterState.of(context).uri;
    } catch (_) {
      return null;
    }
  }

  void _goToTopupDetail(String id) {
    final trimmedId = id.trim();
    if (trimmedId.isEmpty) return;
    try {
      context.go(topupDetailLocation(trimmedId, backPath: widget.backPath));
    } catch (_) {
      // Widget tests can mount TopupScreen without a GoRouter.
    }
  }

  Future<String?> _cancelWaitingTopup(
    String id, {
    bool showErrorNotice = true,
  }) async {
    final l10n = context.l10n;
    setState(() {
      _submitting = true;
      _pageNoticeMessage = '';
    });
    try {
      await ref.read(topupRepositoryProvider).cancel(id);
      _invalidateTopupSurfaces(id);
      setState(() => _waitingSlipTransferAt = null);
      _setPageNotice(l10n.topupCancelled, isError: false);
      return null;
    } catch (error) {
      if (!mounted) return l10n.topupCancelFailed;
      final message = topupErrorMessage(error, l10n.topupCancelFailed);
      if (await handleCustomerOperationalError(
        ref: ref,
        context: context,
        error: error,
      )) {
        return message;
      }
      if (showErrorNotice) _setPageNotice(message);
      return message;
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _confirmCancelWaitingTopup(TopupRequestItem topup) async {
    final cancelled = await showDialog<bool>(
      context: context,
      builder: (context) => _TopupCancelConfirmDialog(
        onConfirm: () => _cancelWaitingTopup(topup.id, showErrorNotice: false),
      ),
    );
    if (!mounted || cancelled != true) return;
    try {
      context.go(topupLocation(backPath: widget.backPath));
    } catch (_) {
      // Focused widget tests can mount TopupScreen without a GoRouter.
    }
  }

  Future<void> _expireWaitingTopup(TopupRequestItem topup) async {
    final id = topup.id.trim();
    if (id.isEmpty ||
        _uploadingSlip ||
        _submittedSlipTopupIds.contains(id) ||
        topup.hasSlip ||
        topup.status.isTerminal ||
        !_expiringTopupIds.add(id)) {
      return;
    }

    final l10n = context.l10n;
    var cancelled = false;
    if (mounted) {
      setState(() {
        _submitting = true;
        _pageNoticeMessage = '';
      });
    }

    try {
      await ref
          .read(topupRepositoryProvider)
          .cancel(id, reason: 'payment_qr_expired');
      cancelled = true;
      _invalidateTopupSurfaces(id);
      if (mounted) {
        await _showTopupFeedback(l10n.topupQrExpiredCancelled, isError: false);
      }
    } catch (error) {
      if (!mounted) return;
      _invalidateTopupSurfaces(id);
      if (await handleCustomerOperationalError(
        ref: ref,
        context: context,
        error: error,
      )) {
        return;
      }
      await _showTopupFeedback(
        topupErrorMessage(error, l10n.topupQrExpiryCancelFailed),
      );
    } finally {
      _expiringTopupIds.remove(id);
      if (mounted) setState(() => _submitting = false);
    }

    if (!mounted || !cancelled) return;
    try {
      context.go(topupLocation(backPath: widget.backPath));
    } catch (_) {
      // Focused widget tests can mount TopupScreen without a GoRouter.
    }
  }

  Future<void> _saveTopupQr(
    TopupRequestItem topup,
    ImageProvider<Object> qrProvider,
  ) async {
    if (_savingQr) return;
    final l10n = context.l10n;
    setState(() {
      _savingQr = true;
      _pageNoticeMessage = '';
    });

    try {
      await ref.read(topupQrImagePreloaderProvider)(context, qrProvider);
      await _waitForTopupQrFrame();
      final bytes = await ref
          .read(receiptImageExporterProvider)
          .capturePng(_qrExportBoundaryKey);
      if (!mounted) return;
      final renderBox = context.findRenderObject();
      final shareOrigin = renderBox is RenderBox
          ? renderBox.localToGlobal(Offset.zero) & renderBox.size
          : null;
      await ref
          .read(receiptShareServiceProvider)
          .shareReceipt(
            text: l10n.topupQrSaveShareText(
              formatTopupBaht(l10n, topup.amount),
              topup.displayReference,
            ),
            subject: l10n.topupQrSaveSubject,
            imageBytes: bytes,
            fileName: 'siamblend-topup-${_safeTopupFileId(topup.id)}.png',
            sharePositionOrigin: shareOrigin,
          );
      if (mounted) {
        await _showTopupFeedback(l10n.topupQrSaveReady, isError: false);
      }
    } catch (_) {
      if (mounted) await _showTopupFeedback(l10n.topupQrSaveFailed);
    } finally {
      if (mounted) setState(() => _savingQr = false);
    }
  }

  Future<void> _openPayment(TopupRequestItem topup) async {
    final uri = topup.redirectUri;
    if (uri == null) return;
    final failedMessage = context.l10n.topupOpenPaymentFailed;
    final ok = await ref.read(customerLinkLauncherProvider).openExternal(uri);
    if (mounted && !ok) await _showTopupFeedback(failedMessage);
  }

  Future<void> _pickAndUploadSlip(String id) async {
    final l10n = context.l10n;
    final slip = await pickTopupSlipUpload();
    if (slip == null) return;

    if (slip.sizeInBytes > 5 * 1024 * 1024) {
      await _showTopupFeedback(l10n.topupSlipTooLarge);
      return;
    }

    setState(() {
      _uploadingSlip = true;
      _pageNoticeMessage = '';
    });
    try {
      final updatedTopup = await ref
          .read(topupRepositoryProvider)
          .uploadSlip(id: id, slip: slip, transferAt: _waitingSlipTransferAt);
      if (updatedTopup.hasSlip) _submittedSlipTopupIds.add(id);
      _invalidateTopupSurfaces(id);
      setState(() => _waitingSlipTransferAt = null);
      await _showTopupFeedback(l10n.topupSlipUploaded, isError: false);
    } catch (error) {
      if (!mounted) return;
      final message = topupErrorMessage(error, l10n.topupSlipUploadFailed);
      if (await handleCustomerOperationalError(
        ref: ref,
        context: context,
        error: error,
      )) {
        return;
      }
      await _showTopupFeedback(message);
    } finally {
      if (mounted) setState(() => _uploadingSlip = false);
    }
  }

  Future<void> _pickBankTransferSlip() async {
    final l10n = context.l10n;
    final slip = await pickTopupSlipUpload();
    if (slip == null) return;

    if (slip.sizeInBytes > 5 * 1024 * 1024) {
      _setSheetNotice(l10n.topupSlipTooLarge);
      return;
    }

    setState(() {
      _bankTransferSlip = slip;
      _sheetNoticeMessage = '';
    });
  }

  void _clearBankTransferSlip() {
    setState(() {
      _bankTransferSlip = null;
      _sheetNoticeMessage = '';
    });
  }

  Future<void> _selectBankTransferAt() async {
    final selected = await _pickTransferDateTime(_bankTransferAt);
    if (selected != null && mounted) setState(() => _bankTransferAt = selected);
  }

  Future<void> _selectWaitingSlipTransferAt(TopupRequestItem topup) async {
    final selected = await _pickTransferDateTime(
      _waitingSlipTransferAt ?? parseDateTime(topup.transferAt),
    );
    if (selected != null && mounted) {
      setState(() => _waitingSlipTransferAt = selected);
    }
  }

  Future<DateTime?> _pickTransferDateTime(DateTime? current) async {
    final now = DateTime.now();
    final initial = current ?? now;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1, 1, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (pickedDate == null || !mounted) return null;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (pickedTime == null || !mounted) return null;

    return DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
  }

  void _setPageNotice(String message, {bool isError = true}) {
    if (!mounted) return;
    setState(() {
      _pageNoticeMessage = message;
      _pageNoticeIsError = isError;
    });
  }

  Future<void> _showTopupFeedback(String message, {bool isError = true}) async {
    if (!mounted || message.trim().isEmpty) return;
    final isDetailPage = (widget.detailTopupId ?? '').trim().isNotEmpty;
    if (!isDetailPage) {
      _setPageNotice(message, isError: isError);
      return;
    }
    if (_feedbackDialogOpen) return;

    _feedbackDialogOpen = true;
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => _TopupFeedbackDialog(
          message: message,
          isError: isError,
          onClose: () => Navigator.of(dialogContext).pop(),
        ),
      );
    } finally {
      _feedbackDialogOpen = false;
    }
  }

  void _setSheetNotice(String message, {bool isError = true}) {
    if (!mounted) return;
    setState(() {
      _sheetNoticeMessage = message;
      _sheetNoticeIsError = isError;
    });
  }

  void _invalidateTopupSurfaces([String? id]) {
    ref.invalidate(topupOverviewProvider);
    final detailId = (id ?? widget.detailTopupId ?? '').trim();
    if (detailId.isNotEmpty) {
      ref.invalidate(topupDetailProvider(detailId));
    }
  }
}

enum _TopupOverviewState { ready, loading, error }

class _TopupCreateLoadingDialog extends StatelessWidget {
  const _TopupCreateLoadingDialog({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      child: Center(
        child: Material(
          key: const ValueKey('topup-create-loading-dialog'),
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          elevation: 8,
          shadowColor: colorScheme.shadow.withValues(alpha: 0.18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomerLoadingMark(
                  color: colorScheme.primary,
                  width: 44,
                  height: 30,
                ),
                const SizedBox(height: 14),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
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

class _TopupFeedbackDialog extends StatelessWidget {
  const _TopupFeedbackDialog({
    required this.message,
    required this.isError,
    required this.onClose,
  });

  final String message;
  final bool isError;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final foreground = isError
        ? colorScheme.error
        : _topupSuccessForeground(colorScheme);
    final background = isError
        ? colorScheme.errorContainer
        : _topupSuccessTint(colorScheme);

    return Dialog(
      key: const ValueKey('topup-feedback-dialog'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      backgroundColor: colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: background,
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    isError ? Icons.error_outline_rounded : Icons.check_rounded,
                    color: foreground,
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey('topup-feedback-close'),
                  onPressed: onClose,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    shape: const StadiumBorder(),
                  ),
                  child: Text(context.l10n.support('common.close')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopupCancelConfirmDialog extends StatefulWidget {
  const _TopupCancelConfirmDialog({required this.onConfirm});

  final Future<String?> Function() onConfirm;

  @override
  State<_TopupCancelConfirmDialog> createState() =>
      _TopupCancelConfirmDialogState();
}

class _TopupCancelConfirmDialogState extends State<_TopupCancelConfirmDialog> {
  bool _canceling = false;
  String _errorMessage = '';

  Future<void> _confirm() async {
    if (_canceling) return;
    setState(() {
      _canceling = true;
      _errorMessage = '';
    });

    final message = await widget.onConfirm();
    if (!mounted) return;
    if (message == null || message.isEmpty) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _canceling = false;
      _errorMessage = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: !_canceling,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.topupCancelConfirmTitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: colorScheme.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    height: 1.4,
                  ),
                ),
                if (_errorMessage.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer.withValues(alpha: 0.62),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colorScheme.error.withValues(alpha: 0.16),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Text(
                        _errorMessage,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onErrorContainer,
                          fontWeight: FontWeight.w800,
                          height: 1.38,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          foregroundColor: colorScheme.primary,
                          backgroundColor: colorScheme.surface,
                          side: BorderSide(
                            color: colorScheme.primaryContainer.withValues(
                              alpha: 0.7,
                            ),
                          ),
                          shape: const StadiumBorder(),
                          textStyle: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        onPressed: _canceling
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: Text(l10n.topupCancelConfirmKeep),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          backgroundColor: colorScheme.error,
                          foregroundColor: colorScheme.onError,
                          shape: const StadiumBorder(),
                          textStyle: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        onPressed: _canceling ? null : _confirm,
                        child: Text(
                          _canceling
                              ? l10n.topupCancelConfirmCancelling
                              : l10n.topupCancelConfirmConfirm,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopupPageShell extends StatelessWidget {
  const _TopupPageShell({
    required this.hasWaiting,
    required this.hero,
    required this.waiting,
    required this.instructionSheet,
  });

  static const _launcherHeroHeight = 458.0;
  static const _narrowLauncherHeroHeight = 560.0;
  static const _waitingHeroHeight = 408.0;
  static const _narrowWaitingHeroHeight = 520.0;
  static const _waitingOverlap = 14.0;
  static const _instructionOverlap = 18.0;
  static const _launcherHeroViewportRatio = 0.54;

  final bool hasWaiting;
  final Widget hero;
  final Widget? waiting;
  final Widget? instructionSheet;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 344;
        final viewportHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height;
        final hasInstructionSheet = !hasWaiting && instructionSheet != null;
        final launcherHeroHeight = math.max(
          narrow ? _narrowLauncherHeroHeight : _launcherHeroHeight,
          viewportHeight * _launcherHeroViewportRatio,
        );
        final heroMinHeight = hasWaiting
            ? (narrow ? _narrowWaitingHeroHeight : _waitingHeroHeight)
            : hasInstructionSheet
            ? math.min(viewportHeight, launcherHeroHeight)
            : viewportHeight;
        final instructionTop = heroMinHeight - _instructionOverlap;
        final instructionMinHeight = math.max(
          0.0,
          viewportHeight - instructionTop,
        );
        if (!hasWaiting && !hasInstructionSheet) {
          return ListView(
            padding: EdgeInsets.zero,
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(minHeight: heroMinHeight),
                child: _TopupHeroBand(child: hero),
              ),
            ],
          );
        }
        final contentOverlap = hasWaiting
            ? _waitingOverlap
            : _instructionOverlap;
        return CustomerFixedHeaderLayout(
          headerKey: const ValueKey('topup-fixed-header'),
          contentRegionKey: const ValueKey('topup-content-region'),
          headerHeight: heroMinHeight,
          contentOverlap: contentOverlap,
          contentTopRadius: customerContentSheetTopRadius,
          contentBackdropColor: Theme.of(context).colorScheme.primary,
          header: _TopupHeroBand(child: hero),
          content: ListView(
            key: const ValueKey('topup-content-scroll'),
            padding: EdgeInsets.zero,
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              if (hasWaiting && waiting != null)
                CustomerPageBody(
                  maxWidth: 640,
                  top: 0,
                  bottom: 56,
                  mobileHorizontal: 16,
                  wideHorizontal: 0,
                  minViewportHeight: true,
                  child: waiting!,
                ),
              if (hasInstructionSheet)
                CustomerPageBody(
                  maxWidth: 640,
                  top: 0,
                  bottom: 0,
                  mobileHorizontal: 0,
                  wideHorizontal: 0,
                  minViewportHeight: true,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: instructionMinHeight,
                    ),
                    child: instructionSheet!,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _TopupDetailPageShell extends StatelessWidget {
  const _TopupDetailPageShell({
    required this.backPath,
    required this.child,
    this.blueBackground = false,
  });

  final String backPath;
  final Widget child;
  final bool blueBackground;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ColoredBox(
      key: const ValueKey('topup-detail-headerless-page'),
      color: blueBackground ? colorScheme.primary : colorScheme.surface,
      child: SafeArea(
        child: Stack(
          children: [
            ListView(
              key: const ValueKey('topup-detail-content-scroll'),
              padding: EdgeInsets.zero,
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                CustomerPageBody(
                  maxWidth: 640,
                  top: 58,
                  bottom: 56,
                  mobileHorizontal: 16,
                  wideHorizontal: 0,
                  minViewportHeight: true,
                  child: child,
                ),
              ],
            ),
            PositionedDirectional(
              top: 4,
              start: 8,
              child: IconButton(
                key: const ValueKey('topup-detail-back-button'),
                tooltip: context.l10n.commonBack,
                onPressed: () =>
                    navigateCustomerBack(context, fallbackPath: backPath),
                icon: const Icon(Icons.arrow_back_ios_new, size: 24),
                style: IconButton.styleFrom(
                  foregroundColor: blueBackground
                      ? colorScheme.onPrimary
                      : colorScheme.onSurface,
                  fixedSize: const Size.square(44),
                  minimumSize: const Size.square(44),
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopupHeroBand extends StatelessWidget {
  const _TopupHeroBand({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return CustomerBlueHeroBackdrop(
      primary: colorScheme.primary,
      secondary: colorScheme.secondary,
      child: SafeArea(
        bottom: false,
        child: CustomerPageBody(
          top: 30,
          bottom: 24,
          maxWidth: 640,
          mobileHorizontal: 20,
          wideHorizontal: 0,
          child: child,
        ),
      ),
    );
  }
}

IconData _iconForChannel(TopupChannel channel) {
  return switch (channel) {
    TopupChannel.qr => Icons.qr_code_2,
    TopupChannel.creditCard => Icons.qr_code_scanner,
    TopupChannel.bankTransfer => Icons.account_balance,
  };
}

String _channelLabel(
  CustomerLocalizations l10n,
  TopupChannel channel, [
  TopupPaymentMethod? method,
]) {
  return switch (channel) {
    TopupChannel.qr => l10n.topupChannelQrLabel,
    TopupChannel.creditCard => l10n.topupChannelCreditLabel,
    TopupChannel.bankTransfer => l10n.topupChannelBankLabel,
  };
}

String _channelDescription(
  CustomerLocalizations l10n,
  TopupChannel channel, [
  TopupPaymentMethod? method,
]) {
  return switch (channel) {
    TopupChannel.qr => l10n.topupChannelQrDescription,
    TopupChannel.creditCard => l10n.topupChannelCreditDescription,
    TopupChannel.bankTransfer => l10n.topupChannelBankDescription,
  };
}

class _TopupHeroContent extends StatelessWidget {
  const _TopupHeroContent({
    required this.title,
    required this.backPath,
    required this.showHistory,
    required this.overview,
    required this.overviewState,
    required this.overviewMessage,
    required this.noticeMessage,
    required this.noticeIsError,
    required this.interactionsEnabled,
    required this.onRetry,
    required this.onHistory,
    required this.onChannelSelected,
  });

  final String title;
  final String backPath;
  final bool showHistory;
  final TopupOverview overview;
  final _TopupOverviewState overviewState;
  final String overviewMessage;
  final String noticeMessage;
  final bool noticeIsError;
  final bool interactionsEnabled;
  final VoidCallback onRetry;
  final VoidCallback onHistory;
  final ValueChanged<TopupChannel> onChannelSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 42,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: _TopupHeroBackButton(backPath: backPath),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 56),
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.onPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    height: 1.16,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          l10n.topupChooseChannel,
          style: textTheme.titleMedium?.copyWith(
            color: colorScheme.onPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 16),
        if (overviewState != _TopupOverviewState.ready) ...[
          _TopupOverviewStatePanel(
            state: overviewState,
            message: overviewMessage,
            onRetry: onRetry,
          ),
          const SizedBox(height: 12),
        ],
        if (noticeMessage.isNotEmpty) ...[
          _TopupNoticePanel(message: noticeMessage, isError: noticeIsError),
          const SizedBox(height: 12),
        ],
        _TopupChannelLauncherCard(
          overview: overview,
          interactionsEnabled: interactionsEnabled,
          onChannelSelected: onChannelSelected,
        ),
        if (showHistory) ...[
          const SizedBox(height: 14),
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.14),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Material(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                splashFactory: NoSplash.splashFactory,
                overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                onTap: onHistory,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 58),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.history,
                          color: colorScheme.primary,
                          size: 21,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            l10n.topupHistoryTooltip,
                            style: textTheme.labelLarge?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: colorScheme.onSurfaceVariant,
                          size: 22,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _TopupHeroBackButton extends StatelessWidget {
  const _TopupHeroBackButton({required this.backPath});

  final String backPath;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: context.l10n.commonBack,
      onPressed: () => navigateCustomerBack(context, fallbackPath: backPath),
      icon: const Icon(Icons.arrow_back_ios_new, size: 31),
      style:
          IconButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: colorScheme.onPrimary,
            fixedSize: const Size.square(42),
            minimumSize: const Size.square(42),
            padding: EdgeInsets.zero,
          ).copyWith(
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          ),
    );
  }
}

bool _isRenderableTopupImageSource(String value) {
  final trimmed = value.trim();
  if (trimmed.startsWith('data:image/')) return true;
  final uri = Uri.tryParse(trimmed);
  if (uri == null) return false;
  return uri.hasScheme || trimmed.startsWith('//');
}

ImageProvider<Object>? _topupQrImageProvider(String source) {
  final trimmed = source.trim();
  if (trimmed.startsWith('data:image/')) {
    final commaIndex = trimmed.indexOf(',');
    if (commaIndex < 0) return null;
    try {
      return MemoryImage(base64Decode(trimmed.substring(commaIndex + 1)));
    } catch (_) {
      return null;
    }
  }

  final uri = Uri.tryParse(trimmed);
  if (uri == null || !uri.hasScheme) return null;
  return NetworkImage(trimmed);
}

class _WaitingTopupCard extends StatelessWidget {
  const _WaitingTopupCard({
    this.title,
    required this.topup,
    this.simplifiedQrDetail = false,
    this.qrExportBoundaryKey,
    this.savingQr = false,
    this.onSaveQr,
    required this.uploadingSlip,
    required this.waitingSlipTransferAt,
    required this.onUploadSlip,
    required this.onSelectSlipTransferAt,
    required this.onOpenPayment,
    required this.onCancel,
    this.onQrExpired,
    this.onReportProblem,
  });

  final String? title;
  final TopupRequestItem topup;
  final bool simplifiedQrDetail;
  final GlobalKey? qrExportBoundaryKey;
  final bool savingQr;
  final TopupQrSaveCallback? onSaveQr;
  final bool uploadingSlip;
  final DateTime? waitingSlipTransferAt;
  final VoidCallback? onUploadSlip;
  final VoidCallback? onSelectSlipTransferAt;
  final VoidCallback? onOpenPayment;
  final VoidCallback? onCancel;
  final VoidCallback? onQrExpired;
  final VoidCallback? onReportProblem;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final waitingDate = topup.transferAt ?? topup.createdAt;

    if (simplifiedQrDetail && topup.status == TopupStatus.approved) {
      return _TopupCompletedDetailCard(
        topup: topup,
        onReportProblem: onReportProblem,
      );
    }

    if (simplifiedQrDetail &&
        (topup.channel == TopupChannel.qr ||
            topup.channel == TopupChannel.creditCard)) {
      return _TopupQrDetailCard(
        topup: topup,
        exportBoundaryKey: qrExportBoundaryKey,
        savingQr: savingQr,
        uploadingSlip: uploadingSlip,
        onSaveQr: onSaveQr,
        onUploadSlip: onUploadSlip,
        onOpenPayment: onOpenPayment,
        onCancel: onCancel,
        onExpired: onQrExpired,
        onReportProblem: onReportProblem,
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(color: _topupPrimaryBorder(colorScheme)),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.14),
            blurRadius: 34,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title ?? l10n.topupWaitingTitle,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.topupReference(topup.displayReference),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _TopupStatusBadge(
                  label: _statusLabel(l10n),
                  status: topup.status,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _WaitingAmountPanel(
              amount: formatTopupBaht(l10n, topup.amount),
              label: l10n.topupWaitingAmountLabel,
            ),
            if (topup.bonusAmount > 0) ...[
              const SizedBox(height: 10),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: _WaitingBonusPill(
                  label: l10n.topupHistoryBonus(
                    formatTopupBaht(l10n, topup.bonusAmount),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            _WaitingDateRow(
              dateText: formatLocalizedDateTime(
                waitingDate,
                l10n.locale.toLanguageTag(),
              ),
            ),
            const SizedBox(height: 12),
            if (topup.qrCode.isNotEmpty)
              _WaitingPaymentPanel(
                title: l10n.topupWaitingQrTitle,
                qrCode: topup.qrCode,
                instruction: l10n.topupQrSlipInstruction,
                initialRemainingSeconds: topup.paymentRemainingSeconds,
              )
            else
              _WaitingNotePanel(
                message: _waitingNote(l10n),
                status: topup.status,
              ),
            if (topup.redirectUri != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: CustomerGradientButton.text(
                  onPressed: onOpenPayment,
                  height: 46,
                  fontSize: 15,
                  shadow: false,
                  label: l10n.topupOpenPayment,
                ),
              ),
            ],
            if (!topup.status.isTerminal && topup.needsSlip) ...[
              const SizedBox(height: 12),
              _WaitingSlipPanel(
                hasSlip: topup.slipUrl.isNotEmpty,
                uploadingSlip: uploadingSlip,
                transferAt: waitingSlipTransferAt,
                onSelectTransferAt: onSelectSlipTransferAt,
                onUploadSlip: onUploadSlip,
              ),
            ],
            if (simplifiedQrDetail && onReportProblem != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: const ValueKey('topup-report-problem-button'),
                  style: _topupFlatButtonStyle(
                    OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      foregroundColor: colorScheme.primary,
                      backgroundColor: colorScheme.surface,
                      side: BorderSide(color: _topupPrimaryBorder(colorScheme)),
                      shape: const StadiumBorder(),
                      textStyle: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  onPressed: onReportProblem,
                  icon: const Icon(Icons.support_agent_outlined, size: 21),
                  label: Text(l10n.support('home.new_ticket')),
                ),
              ),
            ],
            if (!topup.status.isTerminal) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: _topupFlatButtonStyle(
                    OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      foregroundColor: colorScheme.error,
                      backgroundColor: colorScheme.errorContainer.withValues(
                        alpha: 0.46,
                      ),
                      side: BorderSide(
                        color: colorScheme.error.withValues(alpha: 0.18),
                      ),
                      shape: const StadiumBorder(),
                      textStyle: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  onPressed: onCancel,
                  child: Text(l10n.topupCancelWaiting),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _waitingNote(CustomerLocalizations l10n) {
    final message = topup.message.trim();
    if (message.isNotEmpty) return message;
    if (topup.status.isTerminal) return _statusLabel(l10n);
    return l10n.topupNeedsSlip;
  }

  String _statusLabel(CustomerLocalizations l10n) {
    return switch (topup.status) {
      TopupStatus.pendingPayment => l10n.topupStatusPendingPayment,
      TopupStatus.pendingReview => l10n.topupStatusPendingReview,
      TopupStatus.approved => l10n.topupStatusApproved,
      TopupStatus.rejected => l10n.topupStatusRejected,
      TopupStatus.cancelled => l10n.topupStatusCancelled,
      TopupStatus.expired => l10n.topupStatusExpired,
      TopupStatus.unknown => l10n.topupStatusUnknown,
    };
  }
}

class _TopupCompletedDetailCard extends StatelessWidget {
  const _TopupCompletedDetailCard({
    required this.topup,
    required this.onReportProblem,
  });

  final TopupRequestItem topup;
  final VoidCallback? onReportProblem;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final successColor = _topupSuccessForeground(colorScheme);

    return DecoratedBox(
      key: const ValueKey('topup-completed-detail'),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _topupPrimaryBorder(colorScheme)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 24, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _topupSuccessTint(colorScheme),
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Icon(
                    Icons.check_rounded,
                    color: successColor,
                    size: 36,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.topupStatusApproved,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 22),
            _TopupQrArtworkRow(
              label: l10n.topupWaitingAmountLabel,
              value: formatTopupBaht(l10n, topup.amount),
              emphasized: true,
            ),
            const SizedBox(height: 12),
            _TopupQrArtworkRow(
              label: l10n.topupQrReferenceLabel,
              value: topup.displayReference,
            ),
            const SizedBox(height: 12),
            _WaitingDateRow(
              dateText: formatLocalizedDateTime(
                topup.transferAt ?? topup.createdAt,
                l10n.locale.toLanguageTag(),
              ),
            ),
            if (onReportProblem != null) ...[
              const SizedBox(height: 22),
              OutlinedButton.icon(
                key: const ValueKey('topup-report-problem-button'),
                style: _topupFlatButtonStyle(
                  OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    foregroundColor: colorScheme.primary,
                    backgroundColor: colorScheme.surface,
                    side: BorderSide(color: _topupPrimaryBorder(colorScheme)),
                    shape: const StadiumBorder(),
                    textStyle: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                onPressed: onReportProblem,
                icon: const Icon(Icons.support_agent_outlined, size: 21),
                label: Text(l10n.support('home.new_ticket')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TopupQrDetailCard extends StatefulWidget {
  const _TopupQrDetailCard({
    required this.topup,
    required this.exportBoundaryKey,
    required this.savingQr,
    required this.uploadingSlip,
    required this.onSaveQr,
    required this.onUploadSlip,
    required this.onOpenPayment,
    required this.onCancel,
    required this.onExpired,
    required this.onReportProblem,
  });

  final TopupRequestItem topup;
  final GlobalKey? exportBoundaryKey;
  final bool savingQr;
  final bool uploadingSlip;
  final TopupQrSaveCallback? onSaveQr;
  final VoidCallback? onUploadSlip;
  final VoidCallback? onOpenPayment;
  final VoidCallback? onCancel;
  final VoidCallback? onExpired;
  final VoidCallback? onReportProblem;

  @override
  State<_TopupQrDetailCard> createState() => _TopupQrDetailCardState();
}

class _TopupQrDetailCardState extends State<_TopupQrDetailCard> {
  bool _expired = false;
  bool _expiryDispatched = false;
  ImageProvider<Object>? _qrProvider;

  @override
  void initState() {
    super.initState();
    _syncExpiry();
    _qrProvider = _topupQrImageProvider(widget.topup.qrCode);
    if (_expired) _scheduleExpiryDispatch();
  }

  @override
  void didUpdateWidget(covariant _TopupQrDetailCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.topup.paymentExpiresAt != widget.topup.paymentExpiresAt ||
        oldWidget.topup.paymentExpiresInSeconds !=
            widget.topup.paymentExpiresInSeconds ||
        oldWidget.topup.status != widget.topup.status ||
        oldWidget.topup.id != widget.topup.id) {
      _expiryDispatched = false;
      _syncExpiry();
      if (_expired) _scheduleExpiryDispatch();
    }
    if (oldWidget.topup.qrCode != widget.topup.qrCode) {
      _qrProvider = _topupQrImageProvider(widget.topup.qrCode);
    }
  }

  void _syncExpiry() {
    final remaining = widget.topup.paymentRemainingSeconds;
    _expired =
        widget.topup.status == TopupStatus.expired ||
        (remaining != null && remaining <= 0);
  }

  void _markExpired() {
    if (!mounted || _expired) return;
    setState(() => _expired = true);
    _dispatchExpiry();
  }

  void _scheduleExpiryDispatch() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _dispatchExpiry());
  }

  void _dispatchExpiry() {
    if (!mounted ||
        _expiryDispatched ||
        widget.topup.hasSlip ||
        widget.topup.status.isTerminal ||
        widget.onExpired == null) {
      return;
    }
    _expiryDispatched = true;
    widget.onExpired!();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hasQr = widget.topup.qrCode.isNotEmpty;
    final hasSlip = widget.topup.hasSlip;
    final qrProvider = _qrProvider;
    final remainingSeconds = widget.topup.paymentRemainingSeconds;
    final canAct = !_expired && !widget.topup.status.isTerminal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (remainingSeconds != null && !_expired) ...[
          Align(
            alignment: Alignment.center,
            child: _TopupLiveCountdown(
              key: ValueKey(
                'topup-qr-countdown-${widget.topup.paymentExpiresAt}-$remainingSeconds',
              ),
              initialSeconds: remainingSeconds,
              onExpired: _markExpired,
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (!_expired && hasQr && qrProvider != null)
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: RepaintBoundary(
                key: widget.exportBoundaryKey,
                child: _TopupQrArtwork(qrProvider: qrProvider),
              ),
            ),
          )
        else
          _WaitingNotePanel(
            message: _expired
                ? hasSlip
                      ? l10n.topupSlipReviewInProgress
                      : l10n.topupQrExpiredCancelled
                : widget.topup.message.trim().isNotEmpty
                ? widget.topup.message.trim()
                : l10n.topupNeedsSlip,
            status: _expired
                ? hasSlip
                      ? TopupStatus.pendingReview
                      : TopupStatus.expired
                : widget.topup.status,
          ),
        if (!_expired && hasQr && qrProvider != null) ...[
          const SizedBox(height: 10),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: SizedBox(
                width: double.infinity,
                child: _TopupQrSaveButton(
                  saving: widget.savingQr,
                  onPressed: widget.savingQr || widget.onSaveQr == null
                      ? null
                      : () => widget.onSaveQr!(qrProvider),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: _TopupQrDetailSummary(
                topup: widget.topup,
                uploadingSlip: widget.uploadingSlip,
                showUploadSlip: canAct && widget.topup.needsSlip,
                onUploadSlip: widget.onUploadSlip,
                onCancel: canAct ? widget.onCancel : null,
                onReportProblem: widget.onReportProblem,
              ),
            ),
          ),
        ],
        if (!_expired && widget.topup.redirectUri != null) ...[
          const SizedBox(height: 10),
          CustomerGradientButton.text(
            onPressed: widget.onOpenPayment,
            height: 48,
            fontSize: 15,
            shadow: false,
            label: l10n.topupOpenPayment,
          ),
        ],
      ],
    );
  }
}

class _TopupQrSaveButton extends StatelessWidget {
  const _TopupQrSaveButton({required this.saving, required this.onPressed});

  final bool saving;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return OutlinedButton.icon(
      key: const ValueKey('topup-qr-save-button'),
      style: _topupFlatButtonStyle(
        OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(44),
          foregroundColor: colorScheme.primary,
          backgroundColor: colorScheme.surface,
          side: BorderSide(color: colorScheme.onPrimary, width: 1.2),
          shape: const StadiumBorder(),
          textStyle: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      onPressed: onPressed,
      icon: saving
          ? SizedBox.square(
              dimension: 17,
              child: CircularProgressIndicator(
                color: colorScheme.primary,
                strokeWidth: 2.2,
              ),
            )
          : const Icon(Icons.download_outlined, size: 21),
      label: Text(saving ? l10n.topupQrSaving : l10n.topupQrSave),
    );
  }
}

class _TopupQrDetailSummary extends StatelessWidget {
  const _TopupQrDetailSummary({
    required this.topup,
    required this.uploadingSlip,
    required this.showUploadSlip,
    required this.onUploadSlip,
    required this.onCancel,
    required this.onReportProblem,
  });

  final TopupRequestItem topup;
  final bool uploadingSlip;
  final bool showUploadSlip;
  final VoidCallback? onUploadSlip;
  final VoidCallback? onCancel;
  final VoidCallback? onReportProblem;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      key: const ValueKey('topup-qr-detail-summary'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TopupQrDetailSummaryRow(
          label: l10n.topupWaitingAmountLabel,
          value: formatTopupBaht(l10n, topup.amount),
          emphasized: true,
        ),
        Divider(color: colorScheme.onPrimary.withValues(alpha: 0.24)),
        _TopupQrDetailSummaryRow(
          label: l10n.topupQrReferenceLabel,
          value: topup.displayReference,
        ),
        const SizedBox(height: 10),
        Wrap(
          key: const ValueKey('topup-qr-compact-actions'),
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            if (onReportProblem != null)
              _TopupQrCompactAction(
                key: const ValueKey('topup-report-problem-button'),
                icon: Icons.support_agent_outlined,
                label: l10n.support('home.new_ticket'),
                onPressed: onReportProblem,
              ),
            if (onCancel != null)
              _TopupQrCompactAction(
                key: const ValueKey('topup-qr-cancel-button'),
                icon: Icons.close_rounded,
                label: l10n.topupQrCancelAction,
                onPressed: onCancel,
                destructive: true,
              ),
            if (showUploadSlip)
              _TopupQrCompactAction(
                key: const ValueKey('topup-qr-slip-button'),
                icon: uploadingSlip
                    ? Icons.hourglass_top_rounded
                    : Icons.image_outlined,
                label: uploadingSlip
                    ? l10n.topupUploadingSlip
                    : l10n.topupQrAttachSlipAction,
                onPressed: uploadingSlip ? null : onUploadSlip,
              ),
          ],
        ),
      ],
    );
  }
}

class _TopupQrDetailSummaryRow extends StatelessWidget {
  const _TopupQrDetailSummaryRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 4,
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onPrimary.withValues(alpha: 0.82),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 6,
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style:
                (emphasized
                        ? theme.textTheme.titleLarge
                        : theme.textTheme.bodySmall)
                    ?.copyWith(
                      color: colorScheme.onPrimary,
                      fontSize: emphasized ? 22 : 12,
                      fontWeight: emphasized
                          ? FontWeight.w900
                          : FontWeight.w600,
                      height: 1.25,
                    ),
          ),
        ),
      ],
    );
  }
}

class _TopupQrCompactAction extends StatelessWidget {
  const _TopupQrCompactAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final foreground = destructive ? colorScheme.error : colorScheme.onPrimary;
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: _topupFlatButtonStyle(
        OutlinedButton.styleFrom(
          minimumSize: const Size(0, 34),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          foregroundColor: foreground,
          backgroundColor: destructive
              ? colorScheme.surface
              : colorScheme.onPrimary.withValues(alpha: 0.12),
          side: BorderSide(
            color: destructive
                ? colorScheme.error.withValues(alpha: 0.5)
                : colorScheme.onPrimary.withValues(alpha: 0.52),
          ),
          shape: const StadiumBorder(),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: theme.textTheme.labelSmall?.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      icon: Icon(icon, size: 16),
      label: Text(label),
    );
  }
}

class _TopupQrArtwork extends StatelessWidget {
  const _TopupQrArtwork({required this.qrProvider});

  static const _brandAsset = 'assets/images/topup/siamblend_qr_footer.png';

  final ImageProvider<Object> qrProvider;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final darkPrimary =
        Color.lerp(colorScheme.primary, Colors.black, 0.32) ??
        colorScheme.primary;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: ColoredBox(
        color: colorScheme.primary,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DecoratedBox(
                key: const ValueKey('topup-qr-payment-card'),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    children: [
                      ColoredBox(
                        color: darkPrimary,
                        child: SizedBox(
                          height: 46,
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.qr_code_2,
                                  color: Colors.white,
                                  size: 22,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  l10n.topupQrPaymentLabel,
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                        child: Column(
                          children: [
                            Center(
                              child: SizedBox.square(
                                dimension: 232,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: ColoredBox(
                                    color: Colors.white,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.all(4),
                                          child: _StableTopupQrImage(
                                            provider: qrProvider,
                                            width: 224,
                                            height: 224,
                                          ),
                                        ),
                                        IgnorePointer(
                                          child: Transform.rotate(
                                            angle: -math.pi / 7,
                                            child: Container(
                                              key: const ValueKey(
                                                'topup-qr-red-watermark',
                                              ),
                                              width: 278,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 4,
                                                    horizontal: 8,
                                                  ),
                                              color: Colors.red.withValues(
                                                alpha: 0.78,
                                              ),
                                              child: Text(
                                                l10n.topupQrWatermark,
                                                maxLines: 1,
                                                overflow: TextOverflow.fade,
                                                softWrap: false,
                                                textAlign: TextAlign.center,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .labelSmall
                                                    ?.copyWith(
                                                      color: Colors.white,
                                                      fontSize: 9,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                    ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                        child: SizedBox(
                          height: 96,
                          child: Image.asset(_brandAsset, fit: BoxFit.contain),
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

class _StableTopupQrImage extends StatelessWidget {
  const _StableTopupQrImage({
    required this.provider,
    required this.width,
    required this.height,
  });

  final ImageProvider<Object> provider;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Image(
      key: ValueKey('stable-topup-qr-${provider.hashCode}'),
      image: provider,
      width: width,
      height: height,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) =>
          _TopupQrImageError(width: width, height: height),
    );
  }
}

class _TopupQrImageError extends StatelessWidget {
  const _TopupQrImageError({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Icon(
          Icons.qr_code_2,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          size: 52,
        ),
      ),
    );
  }
}

class _TopupQrArtworkRow extends StatelessWidget {
  const _TopupQrArtworkRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style:
                (emphasized
                        ? Theme.of(context).textTheme.titleLarge
                        : Theme.of(context).textTheme.labelSmall)
                    ?.copyWith(
                      color: emphasized
                          ? colorScheme.primary
                          : colorScheme.onSurface,
                      fontWeight: emphasized
                          ? FontWeight.w900
                          : FontWeight.w600,
                      fontSize: emphasized ? null : 10.5,
                      height: 1.25,
                    ),
          ),
        ),
      ],
    );
  }
}

class _TopupOverviewStatePanel extends StatelessWidget {
  const _TopupOverviewStatePanel({
    required this.state,
    required this.message,
    required this.onRetry,
  });

  final _TopupOverviewState state;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final loading = state == _TopupOverviewState.loading;
    final title = loading ? l10n.topupLoading : l10n.topupLoadFailed;
    final body = loading
        ? l10n.topupLoadingMessage
        : message.trim().isEmpty
        ? l10n.topupLoadFailedMessage
        : message.trim();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(
          color:
              Color.lerp(colorScheme.primary, colorScheme.surface, 0.76) ??
              colorScheme.primary.withValues(alpha: 0.24),
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox.square(
              dimension: 42,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: loading
                      ? _topupPrimaryTint(colorScheme)
                      : colorScheme.errorContainer.withValues(alpha: 0.66),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: loading
                      ? Icon(
                          Icons.account_balance_wallet_outlined,
                          color: colorScheme.primary,
                          size: 23,
                        )
                      : Icon(
                          Icons.error_outline_rounded,
                          color: colorScheme.error,
                        ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: loading
                          ? colorScheme.onSurface
                          : colorScheme.error,
                      fontWeight: FontWeight.w900,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                  if (loading) ...[
                    const SizedBox(height: 12),
                    CustomerLoadingMark(
                      width: 104,
                      height: 18,
                      color: colorScheme.primary,
                      trackColor: colorScheme.outlineVariant.withValues(
                        alpha: 0.56,
                      ),
                    ),
                  ],
                  if (!loading) ...[
                    const SizedBox(height: 10),
                    OutlinedButton(
                      style: _topupOutlinePillStyle(context),
                      onPressed: onRetry,
                      child: Text(l10n.commonRetry),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopupNoticePanel extends StatelessWidget {
  const _TopupNoticePanel({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final background = isError
        ? _topupErrorTint(colorScheme)
        : _topupSuccessTint(colorScheme);
    final border = isError
        ? _topupErrorBorder(colorScheme)
        : _topupPrimaryBorder(colorScheme);
    final foreground = isError
        ? _topupErrorForeground(colorScheme)
        : _topupSuccessForeground(colorScheme);
    final icon = isError
        ? Icons.error_outline_rounded
        : Icons.check_circle_outline_rounded;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: foreground, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: foreground,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  height: 1.42,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopupStatusBadge extends StatelessWidget {
  const _TopupStatusBadge({required this.label, required this.status});

  final String label;
  final TopupStatus status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final background = _topupStatusBackground(status, colorScheme);
    final foreground = _topupStatusForeground(status, colorScheme);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: foreground,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _WaitingAmountPanel extends StatelessWidget {
  const _WaitingAmountPanel({required this.amount, required this.label});

  final String amount;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: _topupPrimaryTint(colorScheme),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final labelText = Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            );
            final amountText = Text(
              amount,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: colorScheme.primary,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            );

            if (constraints.maxWidth < 330) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  labelText,
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FittedBox(fit: BoxFit.scaleDown, child: amountText),
                  ),
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: labelText),
                const SizedBox(width: 12),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: amountText,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _WaitingBonusPill extends StatelessWidget {
  const _WaitingBonusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: _topupSuccessTint(colorScheme),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: _topupSuccessForeground(colorScheme),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _WaitingDateRow extends StatelessWidget {
  const _WaitingDateRow({required this.dateText});

  final String dateText;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(Icons.access_time, size: 16, color: colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            dateText,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _WaitingPaymentPanel extends StatefulWidget {
  const _WaitingPaymentPanel({
    required this.title,
    required this.qrCode,
    required this.instruction,
    required this.initialRemainingSeconds,
  });

  final String title;
  final String qrCode;
  final String instruction;
  final int? initialRemainingSeconds;

  @override
  State<_WaitingPaymentPanel> createState() => _WaitingPaymentPanelState();
}

class _WaitingPaymentPanelState extends State<_WaitingPaymentPanel> {
  Timer? _timer;
  DateTime? _deadline;
  int? _remainingSeconds;

  @override
  void initState() {
    super.initState();
    _resetCountdown();
  }

  @override
  void didUpdateWidget(covariant _WaitingPaymentPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialRemainingSeconds != widget.initialRemainingSeconds ||
        oldWidget.qrCode != widget.qrCode) {
      _resetCountdown();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _resetCountdown() {
    _timer?.cancel();
    _remainingSeconds = widget.initialRemainingSeconds;
    _deadline = _remainingSeconds == null
        ? null
        : DateTime.now().add(Duration(seconds: _remainingSeconds!));
    if ((_remainingSeconds ?? 0) <= 0) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      final milliseconds = _deadline!.difference(DateTime.now()).inMilliseconds;
      final next = milliseconds <= 0 ? 0 : (milliseconds + 999) ~/ 1000;
      setState(() => _remainingSeconds = math.max(0, next));
      if (next <= 0) timer.cancel();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final expired = _remainingSeconds != null && _remainingSeconds! <= 0;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _topupSoftSurface(colorScheme),
        border: Border.all(color: _topupPrimaryBorder(colorScheme)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: colorScheme.onSurface,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (!expired) ...[
              if (_remainingSeconds != null) ...[
                const SizedBox(height: 8),
                _TopupQrCountdown(seconds: _remainingSeconds!),
              ],
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: FlexibleImage(
                  source: widget.qrCode,
                  width: 240,
                  height: 240,
                  fit: BoxFit.contain,
                  errorIcon: Icons.qr_code_2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.instruction,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ] else ...[
              const SizedBox(height: 14),
              Icon(
                Icons.timer_off_outlined,
                color: colorScheme.onSurfaceVariant,
                size: 42,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.topupQrExpired,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TopupLiveCountdown extends StatefulWidget {
  const _TopupLiveCountdown({
    required this.initialSeconds,
    required this.onExpired,
    super.key,
  });

  final int initialSeconds;
  final VoidCallback onExpired;

  @override
  State<_TopupLiveCountdown> createState() => _TopupLiveCountdownState();
}

class _TopupLiveCountdownState extends State<_TopupLiveCountdown> {
  Timer? _timer;
  late DateTime _deadline;
  late int _remainingSeconds;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(covariant _TopupLiveCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSeconds != widget.initialSeconds) _start();
  }

  void _start() {
    _timer?.cancel();
    _remainingSeconds = math.max(0, widget.initialSeconds);
    _deadline = DateTime.now().add(Duration(seconds: _remainingSeconds));
    if (_remainingSeconds <= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onExpired();
      });
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      final milliseconds = _deadline.difference(DateTime.now()).inMilliseconds;
      final next = milliseconds <= 0 ? 0 : (milliseconds + 999) ~/ 1000;
      if (next != _remainingSeconds) {
        setState(() => _remainingSeconds = next);
      }
      if (next <= 0) {
        timer.cancel();
        widget.onExpired();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _TopupQrCountdown(seconds: _remainingSeconds);
  }
}

class _TopupQrCountdown extends StatelessWidget {
  const _TopupQrCountdown({required this.seconds});

  final int seconds;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final minutes = seconds ~/ 60;
    final remaining = seconds % 60;
    final time =
        '${minutes.toString().padLeft(2, '0')}:'
        '${remaining.toString().padLeft(2, '0')}';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: _topupPrimaryTint(colorScheme),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          l10n.topupQrExpiresIn(time),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _WaitingNotePanel extends StatelessWidget {
  const _WaitingNotePanel({required this.message, required this.status});

  final String message;
  final TopupStatus status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final background = switch (status) {
      TopupStatus.approved => _topupSuccessTint(colorScheme),
      TopupStatus.rejected => _topupErrorTint(colorScheme),
      TopupStatus.cancelled ||
      TopupStatus.expired => colorScheme.surfaceContainerHighest,
      TopupStatus.pendingPayment ||
      TopupStatus.pendingReview ||
      TopupStatus.unknown => _topupSoftSurface(colorScheme),
    };
    final foreground = switch (status) {
      TopupStatus.approved => _topupSuccessForeground(colorScheme),
      TopupStatus.rejected => _topupErrorForeground(colorScheme),
      TopupStatus.cancelled ||
      TopupStatus.expired => colorScheme.onSurfaceVariant,
      TopupStatus.pendingPayment ||
      TopupStatus.pendingReview ||
      TopupStatus.unknown => colorScheme.onSurfaceVariant,
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Center(
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: foreground,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _WaitingSlipPanel extends StatelessWidget {
  const _WaitingSlipPanel({
    required this.hasSlip,
    required this.uploadingSlip,
    required this.transferAt,
    required this.onSelectTransferAt,
    required this.onUploadSlip,
  });

  final bool hasSlip;
  final bool uploadingSlip;
  final DateTime? transferAt;
  final VoidCallback? onSelectTransferAt;
  final VoidCallback? onUploadSlip;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: _topupPrimaryTint(colorScheme),
        border: Border.all(
          color:
              Color.lerp(colorScheme.primary, colorScheme.surface, 0.76) ??
              colorScheme.primary.withValues(alpha: 0.24),
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.topupWaitingSlipTitle,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: colorScheme.onSurface,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasSlip
                            ? l10n.topupWaitingSlipSentDescription
                            : l10n.topupWaitingSlipPendingDescription,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: hasSlip
                        ? _topupSuccessTint(colorScheme)
                        : _topupWarningTint(colorScheme),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Text(
                      hasSlip
                          ? l10n.topupWaitingSlipSent
                          : l10n.topupWaitingSlipPending,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: hasSlip
                            ? _topupSuccessForeground(colorScheme)
                            : _topupWarningForeground(colorScheme),
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _TransferTimePickerRow(
              value: transferAt == null
                  ? l10n.topupBankSlipTransferAtUnset
                  : formatLocalizedDateTime(
                      transferAt,
                      l10n.locale.toLanguageTag(),
                    ),
              onPressed: onSelectTransferAt,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: CustomerGradientButton.text(
                onPressed: onUploadSlip,
                height: 46,
                fontSize: 15,
                shadow: false,
                label: uploadingSlip
                    ? l10n.topupUploadingSlip
                    : hasSlip
                    ? l10n.topupUploadNewSlip
                    : l10n.topupUploadSlip,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopupChannelLauncherCard extends StatelessWidget {
  const _TopupChannelLauncherCard({
    required this.overview,
    required this.interactionsEnabled,
    required this.onChannelSelected,
  });

  final TopupOverview overview;
  final bool interactionsEnabled;
  final ValueChanged<TopupChannel> onChannelSelected;

  @override
  Widget build(BuildContext context) {
    final blockedByWaiting =
        overview.waiting != null && !overview.waiting!.status.isTerminal;

    return SizedBox(
      height: 120,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < TopupChannel.values.length; index++) ...[
            Expanded(
              child: _ChannelTile(
                channel: TopupChannel.values[index],
                method: overview.methodForChannel(TopupChannel.values[index]),
                enabled: interactionsEnabled
                    ? overview.isChannelEnabled(TopupChannel.values[index])
                    : true,
                blocked: blockedByWaiting || !interactionsEnabled,
                compact: true,
                onTap: () => onChannelSelected(TopupChannel.values[index]),
              ),
            ),
            if (index < TopupChannel.values.length - 1)
              const SizedBox(width: 12),
          ],
        ],
      ),
    );
  }
}

class _TopupSheetContent extends StatelessWidget {
  const _TopupSheetContent({
    required this.overview,
    required this.amount,
    required this.selectedChannel,
    required this.selectedMethod,
    required this.bankTransferSlip,
    required this.bankTransferAt,
    required this.noticeMessage,
    required this.noticeIsError,
    required this.submitting,
    required this.showPaymentDetails,
    required this.onPickBankTransferSlip,
    required this.onClearBankTransferSlip,
    required this.onSelectBankTransferAt,
    required this.onContinueToPaymentDetails,
    required this.onQuickAmountSelected,
    required this.onEditAmount,
    required this.onSubmit,
  });

  final TopupOverview overview;
  final TextEditingController amount;
  final TopupChannel selectedChannel;
  final TopupPaymentMethod? selectedMethod;
  final TopupSlipUpload? bankTransferSlip;
  final DateTime? bankTransferAt;
  final String noticeMessage;
  final bool noticeIsError;
  final bool submitting;
  final bool showPaymentDetails;
  final Future<void> Function() onPickBankTransferSlip;
  final VoidCallback onClearBankTransferSlip;
  final Future<void> Function() onSelectBankTransferAt;
  final Future<void> Function() onContinueToPaymentDetails;
  final Future<void> Function(int amount) onQuickAmountSelected;
  final VoidCallback onEditAmount;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    final viewportHeight = mediaQuery.size.height;
    final modalMaxHeight = math.min(
      viewportHeight * 0.9,
      math.max(96.0, viewportHeight - bottomInset - 12),
    );
    const scrollPadding = EdgeInsets.fromLTRB(16, 16, 16, 12);
    final actionPadding = EdgeInsets.fromLTRB(
      16,
      12,
      16,
      16 + mediaQuery.viewPadding.bottom,
    );

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 430, maxHeight: modalMaxHeight),
          child: Material(
            key: const ValueKey('topup-modal-bottom-sheet'),
            color: _topupSoftSurface(colorScheme),
            surfaceTintColor: Colors.transparent,
            elevation: 20,
            shadowColor: colorScheme.shadow.withValues(alpha: 0.24),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      fit: FlexFit.loose,
                      child: SingleChildScrollView(
                        primary: false,
                        padding: scrollPadding,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox.square(
                                  dimension: 44,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: _topupPrimaryTint(colorScheme),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      _iconForChannel(selectedChannel),
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _channelLabel(
                                          l10n,
                                          selectedChannel,
                                          selectedMethod,
                                        ),
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w900,
                                            ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        _channelDescription(
                                          l10n,
                                          selectedChannel,
                                          selectedMethod,
                                        ),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                              fontWeight: FontWeight.w700,
                                              height: 1.35,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: colorScheme.surface,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: colorScheme.primary.withValues(
                                          alpha: 0.12,
                                        ),
                                        blurRadius: 14,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: SizedBox.square(
                                    dimension: 40,
                                    child: IconButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(),
                                      icon: Icon(
                                        Icons.close,
                                        color: colorScheme.onSurface,
                                      ),
                                      padding: EdgeInsets.zero,
                                      tooltip: MaterialLocalizations.of(
                                        context,
                                      ).closeButtonTooltip,
                                      style: IconButton.styleFrom().copyWith(
                                        overlayColor:
                                            const WidgetStatePropertyAll(
                                              Colors.transparent,
                                            ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            if (noticeMessage.isNotEmpty) ...[
                              _TopupNoticePanel(
                                message: noticeMessage,
                                isError: noticeIsError,
                              ),
                              const SizedBox(height: 14),
                            ],
                            _TopupFormCard(
                              bank: overview.bank,
                              amount: amount,
                              selectedChannel: selectedChannel,
                              selectedMethod: selectedMethod,
                              bankTransferSlip: bankTransferSlip,
                              bankTransferAt: bankTransferAt,
                              submitting: submitting,
                              showPaymentDetails: showPaymentDetails,
                              onQuickAmountSelected: onQuickAmountSelected,
                              onPickBankTransferSlip: onPickBankTransferSlip,
                              onClearBankTransferSlip: onClearBankTransferSlip,
                              onSelectBankTransferAt: onSelectBankTransferAt,
                            ),
                          ],
                        ),
                      ),
                    ),
                    _TopupSheetActionDock(
                      selectedChannel: selectedChannel,
                      submitting: submitting,
                      showPaymentDetails: showPaymentDetails,
                      padding: actionPadding,
                      onContinueToPaymentDetails: onContinueToPaymentDetails,
                      onEditAmount: onEditAmount,
                      onSubmit: onSubmit,
                    ),
                  ],
                ),
                if (submitting && selectedChannel == TopupChannel.bankTransfer)
                  Positioned.fill(
                    child: AbsorbPointer(
                      child: ColoredBox(
                        color: colorScheme.scrim.withValues(alpha: 0.34),
                        child: Center(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: colorScheme.surface,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 22,
                                vertical: 18,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(
                                    color: colorScheme.primary,
                                    strokeWidth: 3,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    selectedChannel == TopupChannel.bankTransfer
                                        ? l10n.topupSubmittingBankTransfer
                                        : l10n.topupCreatingQr,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
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

class _TopupSheetActionDock extends StatelessWidget {
  const _TopupSheetActionDock({
    required this.selectedChannel,
    required this.submitting,
    required this.showPaymentDetails,
    required this.padding,
    required this.onContinueToPaymentDetails,
    required this.onEditAmount,
    required this.onSubmit,
  });

  final TopupChannel selectedChannel;
  final bool submitting;
  final bool showPaymentDetails;
  final EdgeInsets padding;
  final Future<void> Function() onContinueToPaymentDetails;
  final VoidCallback onEditAmount;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final primaryLabel = submitting
        ? _submittingLabel(l10n)
        : showPaymentDetails
        ? l10n.topupConfirmPayment
        : l10n.topupContinuePayment;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: _topupSoftSurface(colorScheme),
        border: Border(
          top: BorderSide(color: _topupPrimaryBorder(colorScheme)),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showPaymentDetails) ...[
              OutlinedButton(
                style: _topupFlatButtonStyle(
                  OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    foregroundColor: colorScheme.primary,
                    backgroundColor: colorScheme.surface,
                    side: BorderSide(color: _topupPrimaryBorder(colorScheme)),
                    shape: const StadiumBorder(),
                    textStyle: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                onPressed: submitting ? null : onEditAmount,
                child: Text(l10n.topupEditAmount),
              ),
              const SizedBox(height: 10),
            ],
            CustomerGradientButton.text(
              onPressed: submitting
                  ? null
                  : !showPaymentDetails
                  ? onContinueToPaymentDetails
                  : () {
                      onSubmit();
                    },
              height: 48,
              fontSize: 15,
              shadow: false,
              label: primaryLabel,
            ),
          ],
        ),
      ),
    );
  }

  String _submittingLabel(CustomerLocalizations l10n) {
    return switch (selectedChannel) {
      TopupChannel.qr || TopupChannel.creditCard => l10n.topupCreatingQr,
      TopupChannel.bankTransfer => l10n.topupSubmittingBankTransfer,
    };
  }
}

class _TopupFormCard extends StatelessWidget {
  const _TopupFormCard({
    required this.bank,
    required this.amount,
    required this.selectedChannel,
    required this.selectedMethod,
    required this.bankTransferSlip,
    required this.bankTransferAt,
    required this.submitting,
    required this.showPaymentDetails,
    required this.onQuickAmountSelected,
    required this.onPickBankTransferSlip,
    required this.onClearBankTransferSlip,
    required this.onSelectBankTransferAt,
  });

  final TopupBankAccount bank;
  final TextEditingController amount;
  final TopupChannel selectedChannel;
  final TopupPaymentMethod? selectedMethod;
  final TopupSlipUpload? bankTransferSlip;
  final DateTime? bankTransferAt;
  final bool submitting;
  final bool showPaymentDetails;
  final Future<void> Function(int amount) onQuickAmountSelected;
  final Future<void> Function() onPickBankTransferSlip;
  final VoidCallback onClearBankTransferSlip;
  final Future<void> Function() onSelectBankTransferAt;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final currentAmount = double.tryParse(amount.text.trim()) ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!showPaymentDetails) ...[
          _TopupAmountPanel(
            amount: amount,
            minimumAmount: selectedMethod?.minimumAmount ?? 0,
            submitting: submitting,
            onQuickAmountSelected: onQuickAmountSelected,
          ),
        ] else ...[
          _TopupPaymentAmountSummary(
            amount: formatTopupBaht(l10n, currentAmount),
          ),
          const SizedBox(height: 14),
          _TopupPaymentDetailsPanel(
            channel: selectedChannel,
            method: selectedMethod,
          ),
          const SizedBox(height: 12),
          if (selectedChannel != TopupChannel.bankTransfer) ...[
            _DeferredSlipNote(message: _deferredSlipMessage(l10n)),
            const SizedBox(height: 16),
          ],
          if (selectedChannel == TopupChannel.bankTransfer &&
              bank.isConfigured) ...[
            _BankInfoCard(bank: bank),
            const SizedBox(height: 10),
          ],
          if (selectedChannel == TopupChannel.bankTransfer) ...[
            _BankTransferSlipPanel(
              slip: bankTransferSlip,
              transferAt: bankTransferAt,
              onPickSlip: submitting
                  ? null
                  : () {
                      onPickBankTransferSlip();
                    },
              onClearSlip: submitting || bankTransferSlip == null
                  ? null
                  : onClearBankTransferSlip,
              onSelectTransferAt: submitting
                  ? null
                  : () {
                      onSelectBankTransferAt();
                    },
            ),
            const SizedBox(height: 16),
          ],
        ],
      ],
    );
  }

  String _deferredSlipMessage(CustomerLocalizations l10n) {
    return switch (selectedChannel) {
      TopupChannel.qr => l10n.topupDeferredSlipQr,
      TopupChannel.creditCard => l10n.topupDeferredSlipCredit,
      TopupChannel.bankTransfer => '',
    };
  }
}

class _TopupPaymentAmountSummary extends StatelessWidget {
  const _TopupPaymentAmountSummary({required this.amount});

  final String amount;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(color: _topupPrimaryBorder(colorScheme)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.topupPaymentAmountDue,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              amount,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: colorScheme.primary,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopupPaymentDetailsPanel extends StatelessWidget {
  const _TopupPaymentDetailsPanel({
    required this.channel,
    required this.method,
  });

  final TopupChannel channel;
  final TopupPaymentMethod? method;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: _topupPrimaryTint(colorScheme),
        border: Border.all(color: _topupPrimaryBorder(colorScheme)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox.square(
              dimension: 38,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  _iconForChannel(channel),
                  color: colorScheme.primary,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.topupPaymentDetailsTitle,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _channelLabel(l10n, channel, method),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: colorScheme.onSurface,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _channelDescription(l10n, channel, method),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
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

class _TopupAmountPanel extends StatelessWidget {
  const _TopupAmountPanel({
    required this.amount,
    required this.minimumAmount,
    required this.submitting,
    required this.onQuickAmountSelected,
  });

  final TextEditingController amount;
  final double minimumAmount;
  final bool submitting;
  final Future<void> Function(int amount) onQuickAmountSelected;

  static const _quickAmounts = [100, 300, 500, 1000, 2000, 5000];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(
          color:
              Color.lerp(colorScheme.primary, colorScheme.surface, 0.78) ??
              colorScheme.primary.withValues(alpha: 0.22),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.topupAmountLabel,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: amount,
              enabled: !submitting,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                hintText: '0',
                suffixText: l10n.topupBahtSuffix,
                filled: true,
                fillColor: _topupPrimaryTint(colorScheme),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color:
                        Color.lerp(
                          colorScheme.primary,
                          colorScheme.surface,
                          0.76,
                        ) ??
                        colorScheme.primary.withValues(alpha: 0.24),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colorScheme.primary),
                ),
              ),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: amount,
              builder: (context, amountValue, _) {
                final currentAmount = amountValue.text.trim();
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    mainAxisExtent: 38,
                  ),
                  itemCount: _quickAmounts.length,
                  itemBuilder: (context, index) {
                    final value = _quickAmounts[index];
                    final selected = currentAmount == value.toString();
                    return OutlinedButton(
                      style: _topupFlatButtonStyle(
                        OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          shape: const StadiumBorder(),
                          foregroundColor: selected
                              ? colorScheme.onPrimary
                              : colorScheme.primary,
                          backgroundColor: selected
                              ? colorScheme.primary
                              : colorScheme.surface,
                          side: BorderSide(
                            color: selected
                                ? colorScheme.primary
                                : colorScheme.primary.withValues(alpha: 0.24),
                          ),
                          textStyle: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      onPressed: submitting
                          ? null
                          : () {
                              onQuickAmountSelected(value);
                            },
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(_formatQuickAmount(value, l10n)),
                      ),
                    );
                  },
                );
              },
            ),
            if (minimumAmount > 0) ...[
              const SizedBox(height: 10),
              _TopupMinimumHint(amount: formatTopupBaht(l10n, minimumAmount)),
            ],
          ],
        ),
      ),
    );
  }

  String _formatQuickAmount(int value, CustomerLocalizations l10n) {
    return formatTopupAmount(l10n, value);
  }
}

class _TopupMinimumHint extends StatelessWidget {
  const _TopupMinimumHint({required this.amount});

  final String amount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _topupWarningTint(colorScheme),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _topupWarningBorder(colorScheme)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline, size: 16, color: colorScheme.secondary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                context.l10n.topupMinimumHint(amount),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: _topupWarningForeground(colorScheme),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeferredSlipNote extends StatelessWidget {
  const _DeferredSlipNote({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: _topupPrimaryTint(colorScheme),
        border: Border.all(
          color:
              Color.lerp(colorScheme.primary, colorScheme.surface, 0.76) ??
              colorScheme.primary.withValues(alpha: 0.24),
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BankTransferSlipPanel extends StatelessWidget {
  const _BankTransferSlipPanel({
    required this.slip,
    required this.transferAt,
    required this.onPickSlip,
    required this.onClearSlip,
    required this.onSelectTransferAt,
  });

  final TopupSlipUpload? slip;
  final DateTime? transferAt;
  final VoidCallback? onPickSlip;
  final VoidCallback? onClearSlip;
  final VoidCallback? onSelectTransferAt;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final hasSlip = slip != null;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: _topupPrimaryTint(colorScheme),
        border: Border.all(
          color:
              Color.lerp(colorScheme.primary, colorScheme.surface, 0.76) ??
              colorScheme.primary.withValues(alpha: 0.24),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.receipt_long, color: colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.topupBankSlipTitle,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: colorScheme.onSurface,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.topupBankSlipDescription,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _TransferTimePickerRow(
              value: transferAt == null
                  ? l10n.topupBankSlipTransferAtUnset
                  : formatLocalizedDateTime(
                      transferAt,
                      l10n.locale.toLanguageTag(),
                    ),
              onPressed: onSelectTransferAt,
            ),
            if (hasSlip) ...[
              const SizedBox(height: 12),
              _SlipMetaRow(
                icon: Icons.image_outlined,
                label: l10n.topupBankSlipFileLabel,
                value: slip!.filename,
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onPickSlip,
                    icon: Icon(hasSlip ? Icons.change_circle : Icons.upload),
                    label: Text(
                      hasSlip
                          ? l10n.topupBankSlipChange
                          : l10n.topupBankSlipAttach,
                    ),
                    style: _topupFlatButtonStyle(
                      OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(46),
                        foregroundColor: colorScheme.primary,
                        backgroundColor: colorScheme.surface,
                        side: BorderSide(
                          color: _topupPrimaryBorder(colorScheme),
                        ),
                        shape: const StadiumBorder(),
                        textStyle: Theme.of(context).textTheme.labelLarge
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ),
                if (hasSlip) ...[
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    onPressed: onClearSlip,
                    icon: const Icon(Icons.close),
                    tooltip: l10n.topupBankSlipRemove,
                    style:
                        IconButton.styleFrom(
                          foregroundColor: colorScheme.error,
                          side: BorderSide(
                            color: _topupErrorBorder(colorScheme),
                          ),
                        ).copyWith(
                          overlayColor: const WidgetStatePropertyAll(
                            Colors.transparent,
                          ),
                        ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TransferTimePickerRow extends StatelessWidget {
  const _TransferTimePickerRow({required this.value, required this.onPressed});

  final String value;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.topupBankSlipTransferAt,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        OutlinedButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.schedule, size: 18),
          style: _topupFlatButtonStyle(
            OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              alignment: Alignment.centerLeft,
              foregroundColor: colorScheme.onSurface,
              backgroundColor: _topupPrimaryTint(colorScheme),
              side: BorderSide(
                color:
                    Color.lerp(
                      colorScheme.primary,
                      colorScheme.surface,
                      0.76,
                    ) ??
                    colorScheme.primary.withValues(alpha: 0.24),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          label: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(value, overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
    );
  }
}

class _SlipMetaRow extends StatelessWidget {
  const _SlipMetaRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChannelTile extends StatelessWidget {
  const _ChannelTile({
    required this.channel,
    required this.method,
    required this.enabled,
    required this.blocked,
    required this.compact,
    required this.onTap,
  });

  final TopupChannel channel;
  final TopupPaymentMethod? method;
  final bool enabled;
  final bool blocked;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;

    final available = enabled && !blocked;
    final blockedOnly = enabled && blocked;
    final borderColor = enabled
        ? colorScheme.onPrimary.withValues(alpha: 0.25)
        : colorScheme.outlineVariant;
    final tileColor = enabled
        ? colorScheme.surface
        : colorScheme.surfaceContainerHighest;
    final iconColor = enabled
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant.withValues(alpha: 0.72);
    final textColor = enabled
        ? colorScheme.onSurface
        : colorScheme.onSurfaceVariant;
    final descriptionColor = colorScheme.onSurfaceVariant;

    final tile = Opacity(
      opacity: blockedOnly ? 0.62 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
          color: tileColor,
          boxShadow: enabled
              ? null
              : [
                  BoxShadow(
                    color: colorScheme.surface.withValues(alpha: 0.55),
                    spreadRadius: 1,
                  ),
                ],
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: compact ? 104 : 0),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 8 : 14,
              vertical: compact ? 7 : 13,
            ),
            child: compact
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _TopupChannelMark(
                        channel: channel,
                        method: method,
                        enabled: enabled,
                        iconColor: iconColor,
                        compact: true,
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 34,
                        child: Center(
                          child: Text(
                            _channelLabel(l10n, channel, method),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: textColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  height: 1.16,
                                ),
                          ),
                        ),
                      ),
                      if (!enabled) ...[
                        const SizedBox(height: 3),
                        _ChannelDisabledBadge(
                          label: l10n.topupChannelDisabled,
                          compact: true,
                        ),
                      ],
                    ],
                  )
                : Row(
                    children: [
                      _TopupChannelMark(
                        channel: channel,
                        method: method,
                        enabled: enabled,
                        iconColor: iconColor,
                        compact: false,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  _channelLabel(l10n, channel, method),
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(
                                        color: textColor,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                                if (!enabled)
                                  _ChannelDisabledBadge(
                                    label: l10n.topupChannelDisabled,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _channelDescription(l10n, channel, method),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: descriptionColor,
                                    fontWeight: FontWeight.w700,
                                    height: 1.3,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      if (available) ...[
                        const SizedBox(width: 10),
                        Icon(
                          Icons.chevron_right,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );

    if (!available) return tile;

    return Semantics(
      button: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: tile,
        ),
      ),
    );
  }
}

class _TopupChannelMark extends StatelessWidget {
  const _TopupChannelMark({
    required this.channel,
    required this.method,
    required this.enabled,
    required this.iconColor,
    required this.compact,
  });

  final TopupChannel channel;
  final TopupPaymentMethod? method;
  final bool enabled;
  final Color iconColor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final logoSource = method?.iconUrl.trim() ?? '';
    final hasLogo = _isRenderableTopupImageSource(logoSource);
    final size = compact ? 38.0 : 38.0;
    final iconSize = compact ? 25.0 : 24.0;
    final radius = BorderRadius.circular(compact ? 14 : 12);

    if (compact) {
      return SizedBox.square(
        dimension: size,
        child: Icon(_iconForChannel(channel), color: iconColor, size: iconSize),
      );
    }

    if (hasLogo) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: radius,
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.46),
          ),
        ),
        child: SizedBox.square(
          dimension: size,
          child: Padding(
            padding: EdgeInsets.all(compact ? 7 : 5),
            child: FlexibleImage(
              key: ValueKey('topup-channel-method-logo-${channel.apiValue}'),
              source: logoSource,
              fit: BoxFit.contain,
              errorIcon: _iconForChannel(channel),
            ),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: enabled ? _topupPrimaryTint(colorScheme) : colorScheme.surface,
        borderRadius: radius,
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.46),
        ),
      ),
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(_iconForChannel(channel), color: iconColor, size: iconSize),
          ],
        ),
      ),
    );
  }
}

class _ChannelDisabledBadge extends StatelessWidget {
  const _ChannelDisabledBadge({required this.label, this.compact = false});

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : 8,
          vertical: compact ? 3 : 4,
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w900,
            fontSize: compact ? 9 : null,
            height: compact ? 1.1 : null,
          ),
        ),
      ),
    );
  }
}

class _BankInfoCard extends StatelessWidget {
  const _BankInfoCard({required this.bank});

  final TopupBankAccount bank;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: _topupPrimaryTint(colorScheme),
        border: Border.all(
          color:
              Color.lerp(colorScheme.primary, colorScheme.surface, 0.76) ??
              colorScheme.primary.withValues(alpha: 0.24),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.topupBankAccountFallback,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.account_balance,
                  color: colorScheme.primary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    bank.bankName.isEmpty
                        ? l10n.topupBankAccountFallback
                        : bank.bankName,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              bank.accountName,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              bank.accountNumber,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: colorScheme.primary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

ButtonStyle _topupOutlinePillStyle(BuildContext context) {
  return _topupFlatButtonStyle(
    OutlinedButton.styleFrom(
      minimumSize: const Size(160, 44),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      shape: const StadiumBorder(),
      side: BorderSide(color: Theme.of(context).colorScheme.primary),
      textStyle: Theme.of(
        context,
      ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
    ),
  );
}

ButtonStyle _topupFlatButtonStyle(ButtonStyle style) {
  return style.copyWith(
    overlayColor: const WidgetStatePropertyAll(Colors.transparent),
  );
}
