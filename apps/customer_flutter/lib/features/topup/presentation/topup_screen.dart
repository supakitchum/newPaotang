import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/customer_localizations.dart';
import '../../../core/navigation/customer_back_navigation.dart';
import '../../../core/navigation/customer_link_launcher.dart';
import '../../../core/utils/formatters.dart';
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
const _topupBackPathAllowlist = {
  '/',
  '/checkout',
  '/my-wallet',
  '/profile',
};
const _topupDetailBackPathAllowlist = {
  ..._topupBackPathAllowlist,
  '/topup/history',
};

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
    TopupStatus.unknown =>
      colorScheme.surfaceContainerHighest,
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
    TopupStatus.unknown =>
      colorScheme.onSurfaceVariant,
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

TopupOverview _emptyTopupOverview() {
  return const TopupOverview(
    bank: TopupBankAccount(
      bankName: '',
      accountName: '',
      accountNumber: '',
    ),
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
  TopupChannel _selectedChannel = TopupChannel.qr;
  TopupSlipUpload? _bankTransferSlip;
  DateTime? _bankTransferAt;
  DateTime? _waitingSlipTransferAt;
  bool _submitting = false;
  bool _uploadingSlip = false;
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
        data: (topup) => _TopupDetailPageShell(
          hero: _TopupDetailHeroContent(
            title: l10n.topupDetailTitle,
            backPath: backPath,
          ),
          child: _WaitingTopupCard(
            title: l10n.topupDetailRequestTitle,
            topup: topup,
            uploadingSlip: _uploadingSlip,
            waitingSlipTransferAt: _waitingSlipTransferAt,
            onUploadSlip:
                _uploadingSlip ? null : () => _pickAndUploadSlip(topup.id),
            onSelectSlipTransferAt: _uploadingSlip
                ? null
                : () => _selectWaitingSlipTransferAt(topup),
            onOpenPayment:
                topup.redirectUri == null ? null : () => _openPayment(topup),
            onCancel:
                _submitting ? null : () => _confirmCancelWaitingTopup(topup),
          ),
        ),
        loading: () => _TopupDetailPageShell(
          hero: _TopupDetailHeroContent(
            title: l10n.topupDetailTitle,
            backPath: backPath,
          ),
          child: _TopupOverviewStatePanel(
            state: _TopupOverviewState.loading,
            message: l10n.topupDetailLoadingMessage,
            onRetry: () => ref.invalidate(topupDetailProvider(topupId)),
          ),
        ),
        error: (error, _) => _TopupDetailPageShell(
          hero: _TopupDetailHeroContent(
            title: l10n.topupDetailTitle,
            backPath: backPath,
          ),
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
        onHistory: () => context.go('/topup/history'),
        onChannelSelected: (channel) => _openTopupSheet(data, channel),
      ),
      waiting: hasWaiting
          ? _WaitingTopupCard(
              topup: waiting,
              uploadingSlip: _uploadingSlip,
              waitingSlipTransferAt: _waitingSlipTransferAt,
              onUploadSlip:
                  _uploadingSlip ? null : () => _pickAndUploadSlip(waiting.id),
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
            void continueToPaymentDetails() {
              if (!_validateTopupAmount(
                channel: channel,
                method: overview.methodForChannel(channel),
              )) {
                if (mounted) setSheetState(() {});
                return;
              }
              FocusScope.of(sheetContext).unfocus();
              setState(() => _sheetNoticeMessage = '');
              showPaymentDetails = true;
              if (mounted) setSheetState(() {});
            }

            void editAmount() {
              setState(() => _sheetNoticeMessage = '');
              showPaymentDetails = false;
              if (mounted) setSheetState(() {});
            }

            Future<void> pickBankTransferSlip() async {
              await _pickBankTransferSlip();
              if (mounted) setSheetState(() {});
            }

            void clearBankTransferSlip() {
              _clearBankTransferSlip();
              if (mounted) setSheetState(() {});
            }

            Future<void> selectBankTransferAt() async {
              await _selectBankTransferAt();
              if (mounted) setSheetState(() {});
            }

            Future<void> submitTopup() async {
              final navigator = Navigator.of(sheetContext);
              final created = await _submitTopup(
                channelOverride: channel,
                method: overview.methodForChannel(channel),
              );
              if (created != null && mounted) {
                navigator.pop();
                _goToTopupDetail(created.id);
              }
              if (mounted) setSheetState(() {});
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
    try {
      final repo = ref.read(topupRepositoryProvider);
      late final TopupRequestItem created;
      if (channel == TopupChannel.creditCard) {
        created = await repo.createCredit(amount: amount);
      } else {
        created = await repo.create(
          channel: channel,
          amount: amount,
          transferAt:
              channel == TopupChannel.bankTransfer ? _bankTransferAt : null,
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
      if (mounted) setState(() => _submitting = false);
    }
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
    await showDialog<void>(
      context: context,
      builder: (context) => _TopupCancelConfirmDialog(
        topup: topup,
        onConfirm: () => _cancelWaitingTopup(
          topup.id,
          showErrorNotice: false,
        ),
      ),
    );
  }

  Future<void> _openPayment(TopupRequestItem topup) async {
    final uri = topup.redirectUri;
    if (uri == null) return;
    final failedMessage = context.l10n.topupOpenPaymentFailed;
    final ok = await ref.read(customerLinkLauncherProvider).openExternal(uri);
    if (mounted && !ok) _setPageNotice(failedMessage);
  }

  Future<void> _pickAndUploadSlip(String id) async {
    final l10n = context.l10n;
    final slip = await pickTopupSlipUpload();
    if (slip == null) return;

    if (slip.sizeInBytes > 5 * 1024 * 1024) {
      _setPageNotice(l10n.topupSlipTooLarge);
      return;
    }

    setState(() {
      _uploadingSlip = true;
      _pageNoticeMessage = '';
    });
    try {
      await ref.read(topupRepositoryProvider).uploadSlip(
            id: id,
            slip: slip,
            transferAt: _waitingSlipTransferAt,
          );
      _invalidateTopupSurfaces(id);
      setState(() => _waitingSlipTransferAt = null);
      _setPageNotice(l10n.topupSlipUploaded, isError: false);
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
      _setPageNotice(message);
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

class _TopupCancelConfirmDialog extends StatefulWidget {
  const _TopupCancelConfirmDialog({
    required this.topup,
    required this.onConfirm,
  });

  final TopupRequestItem topup;
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
      Navigator.of(context).pop();
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
                Align(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.warning_amber_rounded,
                      color: colorScheme.error,
                      size: 30,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  l10n.topupCancelConfirmTitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: colorScheme.primary,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        height: 1.28,
                      ),
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.topupCancelConfirmMessage(widget.topup.id),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                        height: 1.45,
                      ),
                ),
                const SizedBox(height: 14),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.topupCancelConfirmAmountLabel,
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              formatTopupBaht(l10n, widget.topup.amount),
                              style: TextStyle(
                                color: colorScheme.primary,
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
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
                            color: colorScheme.primaryContainer
                                .withValues(alpha: 0.7),
                          ),
                          shape: const StadiumBorder(),
                          textStyle:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
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
                          textStyle:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
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
        final contentOverlap =
            hasWaiting ? _waitingOverlap : _instructionOverlap;
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
    required this.hero,
    required this.child,
  });

  static const _detailHeroHeight = 252.0;
  static const _narrowDetailHeroHeight = 286.0;
  static const _detailOverlap = 24.0;

  final Widget hero;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 344;
        final heroHeight = narrow ? _narrowDetailHeroHeight : _detailHeroHeight;
        return CustomerFixedHeaderLayout(
          headerKey: const ValueKey('topup-detail-fixed-header'),
          contentRegionKey: const ValueKey('topup-detail-content-region'),
          headerHeight: heroHeight,
          contentOverlap: _detailOverlap,
          contentTopRadius: customerContentSheetTopRadius,
          contentBackdropColor: Theme.of(context).colorScheme.primary,
          header: _TopupHeroBand(child: hero),
          content: ListView(
            key: const ValueKey('topup-detail-content-scroll'),
            padding: EdgeInsets.zero,
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              CustomerPageBody(
                maxWidth: 640,
                top: 0,
                bottom: 56,
                mobileHorizontal: 16,
                wideHorizontal: 0,
                minViewportHeight: true,
                child: child,
              ),
            ],
          ),
        );
      },
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
          _TopupNoticePanel(
            message: noticeMessage,
            isError: noticeIsError,
          ),
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
      onPressed: () => navigateCustomerBack(
        context,
        fallbackPath: backPath,
      ),
      icon: const Icon(Icons.arrow_back_ios_new, size: 31),
      style: IconButton.styleFrom(
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

class _WaitingTopupCard extends StatelessWidget {
  const _WaitingTopupCard({
    this.title,
    required this.topup,
    required this.uploadingSlip,
    required this.waitingSlipTransferAt,
    required this.onUploadSlip,
    required this.onSelectSlipTransferAt,
    required this.onOpenPayment,
    required this.onCancel,
  });

  final String? title;
  final TopupRequestItem topup;
  final bool uploadingSlip;
  final DateTime? waitingSlipTransferAt;
  final VoidCallback? onUploadSlip;
  final VoidCallback? onSelectSlipTransferAt;
  final VoidCallback? onOpenPayment;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final waitingDate = topup.transferAt ?? topup.createdAt;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(
          color: _topupPrimaryBorder(colorScheme),
        ),
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
                        l10n.topupReference(topup.id),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w900,
                          height: 1.18,
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
            if (!topup.status.isTerminal) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: _topupFlatButtonStyle(
                    OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      foregroundColor: colorScheme.error,
                      backgroundColor:
                          colorScheme.errorContainer.withValues(alpha: 0.46),
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
          color: Color.lerp(colorScheme.primary, colorScheme.surface, 0.76) ??
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
                      trackColor:
                          colorScheme.outlineVariant.withValues(alpha: 0.56),
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
  const _TopupNoticePanel({
    required this.message,
    required this.isError,
  });

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final background =
        isError ? _topupErrorTint(colorScheme) : _topupSuccessTint(colorScheme);
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
  const _TopupStatusBadge({
    required this.label,
    required this.status,
  });

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
  const _WaitingAmountPanel({
    required this.amount,
    required this.label,
  });

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
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: amountText,
                    ),
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

class _WaitingPaymentPanel extends StatelessWidget {
  const _WaitingPaymentPanel({
    required this.title,
    required this.qrCode,
    required this.instruction,
  });

  final String title;
  final String qrCode;
  final String instruction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: colorScheme.onSurface,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: FlexibleImage(
                source: qrCode,
                width: 240,
                height: 240,
                fit: BoxFit.contain,
                errorIcon: Icons.qr_code_2,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              instruction,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WaitingNotePanel extends StatelessWidget {
  const _WaitingNotePanel({
    required this.message,
    required this.status,
  });

  final String message;
  final TopupStatus status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final background = switch (status) {
      TopupStatus.approved => _topupSuccessTint(colorScheme),
      TopupStatus.rejected => _topupErrorTint(colorScheme),
      TopupStatus.cancelled ||
      TopupStatus.expired =>
        colorScheme.surfaceContainerHighest,
      TopupStatus.pendingPayment ||
      TopupStatus.pendingReview ||
      TopupStatus.unknown =>
        _topupSoftSurface(colorScheme),
    };
    final foreground = switch (status) {
      TopupStatus.approved => _topupSuccessForeground(colorScheme),
      TopupStatus.rejected => _topupErrorForeground(colorScheme),
      TopupStatus.cancelled ||
      TopupStatus.expired =>
        colorScheme.onSurfaceVariant,
      TopupStatus.pendingPayment ||
      TopupStatus.pendingReview ||
      TopupStatus.unknown =>
        colorScheme.onSurfaceVariant,
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
          color: Color.lerp(colorScheme.primary, colorScheme.surface, 0.76) ??
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
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
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

class _TopupDetailHeroContent extends StatelessWidget {
  const _TopupDetailHeroContent({
    required this.title,
    required this.backPath,
  });

  final String title;
  final String backPath;

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
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.account_balance_wallet_outlined,
                color: colorScheme.primary,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.topupDetailHeaderTitle,
                    style: textTheme.titleMedium?.copyWith(
                      color: colorScheme.onPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      height: 1.16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.topupDetailHeaderSubtitle,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onPrimary.withValues(alpha: 0.86),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.34,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
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

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
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
          if (index < TopupChannel.values.length - 1) const SizedBox(width: 12),
        ],
      ],
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
  final VoidCallback onContinueToPaymentDetails;
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
            child: Column(
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
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                          color: colorScheme.onSurfaceVariant,
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
                                  onPressed: () => Navigator.of(context).pop(),
                                  icon: Icon(
                                    Icons.close,
                                    color: colorScheme.onSurface,
                                  ),
                                  padding: EdgeInsets.zero,
                                  tooltip: MaterialLocalizations.of(context)
                                      .closeButtonTooltip,
                                  style: IconButton.styleFrom().copyWith(
                                    overlayColor: const WidgetStatePropertyAll(
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
  final VoidCallback onContinueToPaymentDetails;
  final VoidCallback onEditAmount;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final primaryLabel = !showPaymentDetails
        ? l10n.topupContinuePayment
        : submitting
            ? _submittingLabel(l10n)
            : l10n.topupConfirmPayment;

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
  const _TopupPaymentAmountSummary({
    required this.amount,
  });

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
  });

  final TextEditingController amount;
  final double minimumAmount;

  static const _quickAmounts = [100, 300, 500, 1000, 2000, 5000];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(
          color: Color.lerp(colorScheme.primary, colorScheme.surface, 0.78) ??
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
                    color: Color.lerp(
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
                          textStyle: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      onPressed: () => _setAmount(value),
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
              _TopupMinimumHint(
                amount: formatTopupBaht(l10n, minimumAmount),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _setAmount(int value) {
    amount.value = TextEditingValue(
      text: value.toString(),
      selection: TextSelection.collapsed(offset: value.toString().length),
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
            Icon(
              Icons.info_outline,
              size: 16,
              color: colorScheme.secondary,
            ),
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
          color: Color.lerp(colorScheme.primary, colorScheme.surface, 0.76) ??
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
          color: Color.lerp(colorScheme.primary, colorScheme.surface, 0.76) ??
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
                        textStyle:
                            Theme.of(context).textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
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
                    style: IconButton.styleFrom(
                      foregroundColor: colorScheme.error,
                      side: BorderSide(color: _topupErrorBorder(colorScheme)),
                    ).copyWith(
                      overlayColor:
                          const WidgetStatePropertyAll(Colors.transparent),
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
  const _TransferTimePickerRow({
    required this.value,
    required this.onPressed,
  });

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
                color: Color.lerp(
                      colorScheme.primary,
                      colorScheme.surface,
                      0.76,
                    ) ??
                    colorScheme.primary.withValues(alpha: 0.24),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          label: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
            ),
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
    final tileColor =
        enabled ? colorScheme.surface : colorScheme.surfaceContainerHighest;
    final iconColor = enabled
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant.withValues(alpha: 0.72);
    final textColor =
        enabled ? colorScheme.onSurface : colorScheme.onSurfaceVariant;
    final descriptionColor = colorScheme.onSurfaceVariant;

    final tile = Opacity(
      opacity: blockedOnly ? 0.62 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: borderColor,
          ),
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
              vertical: compact ? 12 : 13,
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
                      const SizedBox(height: 8),
                      Text(
                        _channelLabel(l10n, channel, method),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: textColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              height: 1.22,
                            ),
                      ),
                      if (!enabled) ...[
                        const SizedBox(height: 7),
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
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelLarge
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
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
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
    final size = compact ? 48.0 : 38.0;
    final iconSize = compact ? 28.0 : 24.0;
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
  const _ChannelDisabledBadge({
    required this.label,
    this.compact = false,
  });

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
          maxLines: compact ? 2 : 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w900,
                fontSize: compact ? 10 : null,
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
          color: Color.lerp(colorScheme.primary, colorScheme.surface, 0.76) ??
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
      textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w900,
          ),
    ),
  );
}

ButtonStyle _topupFlatButtonStyle(ButtonStyle style) {
  return style.copyWith(
    overlayColor: const WidgetStatePropertyAll(Colors.transparent),
  );
}
