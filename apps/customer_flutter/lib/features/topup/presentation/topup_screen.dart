import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/i18n/customer_localizations.dart';
import '../../../core/navigation/customer_link_launcher.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/async/async_state_view.dart';
import '../../../shared/widgets/customer_page_body.dart';
import '../../../shared/widgets/flexible_image.dart';
import '../../../shared/utils/customer_operational_error.dart';
import '../data/topup_models.dart';
import '../data/topup_repository.dart';
import 'topup_error_message.dart';
import 'topup_realtime_monitor.dart';

const _topupBackPathFallback = '/my-wallet';
const _topupBackPathAllowlist = {
  '/',
  '/checkout',
  '/my-wallet',
  '/profile',
};

String safeTopupBackPath(String? value) {
  final target = (value ?? '').trim();
  return _topupBackPathAllowlist.contains(target)
      ? target
      : _topupBackPathFallback;
}

class TopupScreen extends ConsumerStatefulWidget {
  const TopupScreen({
    super.key,
    this.backPath = _topupBackPathFallback,
  });

  final String backPath;

  @override
  ConsumerState<TopupScreen> createState() => _TopupScreenState();
}

class _TopupScreenState extends ConsumerState<TopupScreen> {
  final _amount = TextEditingController(text: '500');
  TopupChannel _selectedChannel = TopupChannel.qr;
  TopupSlipUpload? _bankTransferSlip;
  DateTime? _bankTransferAt;
  bool _submitting = false;
  bool _uploadingSlip = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(topupRealtimeTickProvider, (previous, next) {
      if (previous == null || previous == next) return;
      ref.invalidate(topupOverviewProvider);
    });

    final overview = ref.watch(topupOverviewProvider);
    final l10n = context.l10n;

    return AppShell(
      title: l10n.topupTitle,
      currentPath: '/my-wallet',
      backPath: widget.backPath,
      sensitive: true,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          CustomerPageBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _HeaderCard(onHistory: () => context.go('/topup/history')),
                const SizedBox(height: 12),
                AsyncStateView(
                  value: overview,
                  data: (data) {
                    final selectedChannel = data.isChannelEnabled(
                      _selectedChannel,
                    )
                        ? _selectedChannel
                        : data.firstEnabledChannel ?? _selectedChannel;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (data.waiting != null) ...[
                          _WaitingTopupCard(
                            topup: data.waiting!,
                            uploadingSlip: _uploadingSlip,
                            onUploadSlip: _uploadingSlip
                                ? null
                                : () => _pickAndUploadSlip(data.waiting!.id),
                            onOpenPayment: data.waiting!.redirectUri == null
                                ? null
                                : () => _openPayment(data.waiting!),
                            onCancel: _submitting
                                ? null
                                : () =>
                                    _confirmCancelWaitingTopup(data.waiting!),
                          ),
                          const SizedBox(height: 12),
                        ],
                        _TopupChannelLauncherCard(
                          overview: data,
                          selectedChannel: selectedChannel,
                          onChannelSelected: (channel) =>
                              _openTopupSheet(data, channel),
                        ),
                      ],
                    );
                  },
                  empty: _TopupChannelLauncherCard(
                    overview: TopupOverview(
                      bank: const TopupBankAccount(
                        bankName: '',
                        accountName: '',
                        accountNumber: '',
                      ),
                      paymentMethods: const [],
                      enabledPaymentMethods: const {},
                      waiting: null,
                      histories: const [],
                      currentPage: 1,
                      lastPage: 1,
                    ),
                    selectedChannel: _selectedChannel,
                    onChannelSelected: (channel) => _openTopupSheet(
                      TopupOverview(
                        bank: const TopupBankAccount(
                          bankName: '',
                          accountName: '',
                          accountNumber: '',
                        ),
                        paymentMethods: const [],
                        enabledPaymentMethods: const {},
                        waiting: null,
                        histories: const [],
                        currentPage: 1,
                        lastPage: 1,
                      ),
                      channel,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openTopupSheet(
    TopupOverview overview,
    TopupChannel channel,
  ) async {
    final blockedByWaiting =
        overview.waiting != null && !overview.waiting!.status.isTerminal;
    if (blockedByWaiting || !overview.isChannelEnabled(channel)) return;

    setState(() => _selectedChannel = channel);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
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
              final success = await _submitTopup(channel);
              if (success && mounted) navigator.pop();
              if (mounted) setSheetState(() {});
            }

            return _TopupSheetContent(
              overview: overview,
              amount: _amount,
              selectedChannel: channel,
              bankTransferSlip: _bankTransferSlip,
              bankTransferAt: _bankTransferAt,
              submitting: _submitting,
              onPickBankTransferSlip: pickBankTransferSlip,
              onClearBankTransferSlip: clearBankTransferSlip,
              onSelectBankTransferAt: selectBankTransferAt,
              onSubmit: submitTopup,
            );
          },
        );
      },
    );
  }

  Future<bool> _submitTopup([TopupChannel? channelOverride]) async {
    final channel = channelOverride ?? _selectedChannel;
    final amount = double.tryParse(_amount.text.trim()) ?? 0;
    final l10n = context.l10n;
    if (amount <= 0) {
      _showSnack(l10n.topupAmountRequired);
      return false;
    }
    if (channel == TopupChannel.creditCard && amount < 400) {
      _showSnack(l10n.topupCreditMinimum);
      return false;
    }
    if (channel == TopupChannel.bankTransfer && _bankTransferSlip == null) {
      _showSnack(l10n.topupBankSlipRequired);
      return false;
    }

    setState(() => _submitting = true);
    try {
      final repo = ref.read(topupRepositoryProvider);
      if (channel == TopupChannel.creditCard) {
        await repo.createCredit(amount: amount);
      } else {
        await repo.create(
          channel: channel,
          amount: amount,
          transferAt: channel == TopupChannel.bankTransfer
              ? _bankTransferAt ?? DateTime.now()
              : null,
          slip: channel == TopupChannel.bankTransfer ? _bankTransferSlip : null,
        );
      }
      ref.invalidate(topupOverviewProvider);
      if (channel == TopupChannel.bankTransfer) {
        setState(() {
          _bankTransferSlip = null;
          _bankTransferAt = null;
        });
      }
      _showSnack(
        channel == TopupChannel.bankTransfer
            ? l10n.topupBankTransferSubmitted
            : l10n.topupCreated,
      );
      return true;
    } catch (error) {
      if (!mounted) return false;
      final message = topupErrorMessage(error, l10n.topupCreateFailed);
      if (await handleCustomerOperationalError(
        ref: ref,
        context: context,
        error: error,
      )) {
        return false;
      }
      _showSnack(message);
      return false;
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _cancelWaitingTopup(String id) async {
    final l10n = context.l10n;
    setState(() => _submitting = true);
    try {
      await ref.read(topupRepositoryProvider).cancel(id);
      ref.invalidate(topupOverviewProvider);
      _showSnack(l10n.topupCancelled);
    } catch (error) {
      if (!mounted) return;
      final message = topupErrorMessage(error, l10n.topupCancelFailed);
      if (await handleCustomerOperationalError(
        ref: ref,
        context: context,
        error: error,
      )) {
        return;
      }
      _showSnack(message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _confirmCancelWaitingTopup(TopupRequestItem topup) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.topupCancelConfirmTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.topupCancelConfirmMessage(topup.id)),
            const SizedBox(height: 14),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: Theme.of(context).colorScheme.errorContainer,
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.topupCancelConfirmAmountLabel,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      formatBaht(topup.amount),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.topupCancelConfirmKeep),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.topupCancelConfirmConfirm),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _cancelWaitingTopup(topup.id);
    }
  }

  Future<void> _openPayment(TopupRequestItem topup) async {
    final uri = topup.redirectUri;
    if (uri == null) return;
    final failedMessage = context.l10n.topupOpenPaymentFailed;
    final ok = await ref.read(customerLinkLauncherProvider).openExternal(uri);
    if (mounted && !ok) _showSnack(failedMessage);
  }

  Future<void> _pickAndUploadSlip(String id) async {
    final l10n = context.l10n;
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
    );
    if (file == null) return;

    final bytes = await file.readAsBytes();

    if (bytes.lengthInBytes > 5 * 1024 * 1024) {
      _showSnack(l10n.topupSlipTooLarge);
      return;
    }

    setState(() => _uploadingSlip = true);
    try {
      await ref.read(topupRepositoryProvider).uploadSlip(
            id: id,
            slip: TopupSlipUpload(
              filename: file.name.isEmpty ? 'topup-slip.jpg' : file.name,
              bytes: bytes,
            ),
            transferAt: DateTime.now(),
          );
      ref.invalidate(topupOverviewProvider);
      _showSnack(l10n.topupSlipUploaded);
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
      _showSnack(message);
    } finally {
      if (mounted) setState(() => _uploadingSlip = false);
    }
  }

  Future<void> _pickBankTransferSlip() async {
    final l10n = context.l10n;
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
    );
    if (file == null) return;

    final bytes = await file.readAsBytes();

    if (bytes.lengthInBytes > 5 * 1024 * 1024) {
      _showSnack(l10n.topupSlipTooLarge);
      return;
    }

    setState(() {
      _bankTransferSlip = TopupSlipUpload(
        filename: file.name.isEmpty ? 'topup-slip.jpg' : file.name,
        bytes: bytes,
      );
      _bankTransferAt ??= DateTime.now();
    });
  }

  void _clearBankTransferSlip() {
    setState(() {
      _bankTransferSlip = null;
    });
  }

  Future<void> _selectBankTransferAt() async {
    final now = DateTime.now();
    final initial = _bankTransferAt ?? now;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1, 1, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (pickedTime == null || !mounted) return;

    setState(() {
      _bankTransferAt = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

IconData _iconForChannel(TopupChannel channel) {
  return switch (channel) {
    TopupChannel.qr => Icons.qr_code_2,
    TopupChannel.creditCard => Icons.qr_code_scanner,
    TopupChannel.bankTransfer => Icons.account_balance,
  };
}

String _channelLabel(CustomerLocalizations l10n, TopupChannel channel) {
  return switch (channel) {
    TopupChannel.qr => l10n.topupChannelQrLabel,
    TopupChannel.creditCard => l10n.topupChannelCreditLabel,
    TopupChannel.bankTransfer => l10n.topupChannelBankLabel,
  };
}

String _channelDescription(CustomerLocalizations l10n, TopupChannel channel) {
  return switch (channel) {
    TopupChannel.qr => l10n.topupChannelQrDescription,
    TopupChannel.creditCard => l10n.topupChannelCreditDescription,
    TopupChannel.bankTransfer => l10n.topupChannelBankDescription,
  };
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.onHistory});

  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary,
            Color.lerp(colorScheme.primary, colorScheme.secondary, 0.55) ??
                colorScheme.primary,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -28,
            bottom: -42,
            child: Container(
              width: 132,
              height: 132,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFFD629).withValues(alpha: 0.22),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.white.withValues(alpha: 0.18),
                  child: const Icon(
                    Icons.account_balance_wallet_outlined,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.topupHeaderTitle,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.topupHeaderSubtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.84),
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                ),
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.18),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: onHistory,
                  icon: const Icon(Icons.history),
                  tooltip: l10n.topupHistoryTooltip,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WaitingTopupCard extends StatelessWidget {
  const _WaitingTopupCard({
    required this.topup,
    required this.uploadingSlip,
    required this.onUploadSlip,
    required this.onOpenPayment,
    required this.onCancel,
  });

  final TopupRequestItem topup;
  final bool uploadingSlip;
  final VoidCallback? onUploadSlip;
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
          color: colorScheme.outlineVariant.withValues(alpha: 0.75),
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.12),
            blurRadius: 30,
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
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.topupWaitingTitle,
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
              amount: formatBaht(topup.amount),
              label: l10n.topupWaitingAmountLabel,
            ),
            if (topup.bonusAmount > 0) ...[
              const SizedBox(height: 10),
              _WaitingBonusPill(
                label: l10n.topupHistoryBonus(formatBaht(topup.bonusAmount)),
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
              _WaitingNotePanel(message: _waitingNote(l10n)),
            if (topup.redirectUri != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onOpenPayment,
                  icon: const Icon(Icons.open_in_new),
                  label: Text(l10n.topupOpenPayment),
                ),
              ),
            ],
            if (!topup.status.isTerminal && topup.needsSlip) ...[
              const SizedBox(height: 12),
              _WaitingSlipPanel(
                hasSlip: topup.slipUrl.isNotEmpty,
                uploadingSlip: uploadingSlip,
                onUploadSlip: onUploadSlip,
              ),
            ],
            if (!topup.status.isTerminal) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onCancel,
                  icon: const Icon(Icons.cancel_outlined),
                  label: Text(l10n.topupCancelWaiting),
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
    final background = switch (status) {
      TopupStatus.pendingPayment => colorScheme.primaryContainer,
      TopupStatus.pendingReview => colorScheme.secondaryContainer,
      TopupStatus.approved => colorScheme.tertiaryContainer,
      TopupStatus.rejected ||
      TopupStatus.cancelled ||
      TopupStatus.expired =>
        colorScheme.errorContainer,
      TopupStatus.unknown => colorScheme.surfaceContainerHighest,
    };
    final foreground = switch (status) {
      TopupStatus.pendingPayment => colorScheme.onPrimaryContainer,
      TopupStatus.pendingReview => colorScheme.onSecondaryContainer,
      TopupStatus.approved => colorScheme.onTertiaryContainer,
      TopupStatus.rejected ||
      TopupStatus.cancelled ||
      TopupStatus.expired =>
        colorScheme.onErrorContainer,
      TopupStatus.unknown => colorScheme.onSurfaceVariant,
    };

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
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: colorScheme.primaryContainer.withValues(alpha: 0.34),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final labelText = Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
              ),
            );
            final amountText = Text(
              amount,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: colorScheme.primary,
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
        color: colorScheme.tertiaryContainer,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colorScheme.onTertiaryContainer,
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
        color: colorScheme.surfaceContainerLowest,
        border: Border.all(color: colorScheme.outlineVariant),
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
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: FlexibleImage(
                source: qrCode,
                width: 220,
                height: 220,
                fit: BoxFit.contain,
                errorIcon: Icons.qr_code_2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              instruction,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
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
  const _WaitingNotePanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Center(
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
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
    required this.onUploadSlip,
  });

  final bool hasSlip;
  final bool uploadingSlip;
  final VoidCallback? onUploadSlip;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.75),
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
                        ? colorScheme.tertiaryContainer
                        : colorScheme.primaryContainer,
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
                                ? colorScheme.onTertiaryContainer
                                : colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onUploadSlip,
                icon: uploadingSlip
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_file),
                label: Text(
                  hasSlip ? l10n.topupUploadNewSlip : l10n.topupUploadSlip,
                ),
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
    required this.selectedChannel,
    required this.onChannelSelected,
  });

  final TopupOverview overview;
  final TopupChannel selectedChannel;
  final ValueChanged<TopupChannel> onChannelSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final blockedByWaiting =
        overview.waiting != null && !overview.waiting!.status.isTerminal;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.topupChooseChannel,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            if (blockedByWaiting) ...[
              const SizedBox(height: 12),
              const _TopupBlockingWaitingNotice(),
            ],
            const SizedBox(height: 12),
            for (final channel in TopupChannel.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ChannelTile(
                  channel: channel,
                  selected: selectedChannel == channel,
                  enabled: overview.isChannelEnabled(channel),
                  blocked: blockedByWaiting,
                  onTap: () => onChannelSelected(channel),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TopupSheetContent extends StatelessWidget {
  const _TopupSheetContent({
    required this.overview,
    required this.amount,
    required this.selectedChannel,
    required this.bankTransferSlip,
    required this.bankTransferAt,
    required this.submitting,
    required this.onPickBankTransferSlip,
    required this.onClearBankTransferSlip,
    required this.onSelectBankTransferAt,
    required this.onSubmit,
  });

  final TopupOverview overview;
  final TextEditingController amount;
  final TopupChannel selectedChannel;
  final TopupSlipUpload? bankTransferSlip;
  final DateTime? bankTransferAt;
  final bool submitting;
  final Future<void> Function() onPickBankTransferSlip;
  final VoidCallback onClearBankTransferSlip;
  final Future<void> Function() onSelectBankTransferAt;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset + 16),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      backgroundColor: colorScheme.primaryContainer,
                      foregroundColor: colorScheme.primary,
                      child: Icon(_iconForChannel(selectedChannel)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _channelLabel(l10n, selectedChannel),
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _channelDescription(l10n, selectedChannel),
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w700,
                                      height: 1.35,
                                    ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      tooltip:
                          MaterialLocalizations.of(context).closeButtonTooltip,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _TopupFormCard(
                  bank: overview.bank,
                  amount: amount,
                  selectedChannel: selectedChannel,
                  bankTransferSlip: bankTransferSlip,
                  bankTransferAt: bankTransferAt,
                  submitting: submitting,
                  onPickBankTransferSlip: onPickBankTransferSlip,
                  onClearBankTransferSlip: onClearBankTransferSlip,
                  onSelectBankTransferAt: onSelectBankTransferAt,
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

class _TopupFormCard extends StatelessWidget {
  const _TopupFormCard({
    required this.bank,
    required this.amount,
    required this.selectedChannel,
    required this.bankTransferSlip,
    required this.bankTransferAt,
    required this.submitting,
    required this.onPickBankTransferSlip,
    required this.onClearBankTransferSlip,
    required this.onSelectBankTransferAt,
    required this.onSubmit,
  });

  final TopupBankAccount bank;
  final TextEditingController amount;
  final TopupChannel selectedChannel;
  final TopupSlipUpload? bankTransferSlip;
  final DateTime? bankTransferAt;
  final bool submitting;
  final Future<void> Function() onPickBankTransferSlip;
  final VoidCallback onClearBankTransferSlip;
  final Future<void> Function() onSelectBankTransferAt;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TopupAmountPanel(amount: amount),
        const SizedBox(height: 16),
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
        FilledButton(
          onPressed: submitting
              ? null
              : () {
                  onSubmit();
                },
          child: submitting
              ? const CircularProgressIndicator()
              : Text(_submitLabel(l10n)),
        ),
      ],
    );
  }

  String _submitLabel(CustomerLocalizations l10n) {
    return switch (selectedChannel) {
      TopupChannel.qr => l10n.topupCreateQr,
      TopupChannel.creditCard => l10n.topupCreateCreditQr,
      TopupChannel.bankTransfer => l10n.topupCreateBankTransfer,
    };
  }

  String _deferredSlipMessage(CustomerLocalizations l10n) {
    return switch (selectedChannel) {
      TopupChannel.qr => l10n.topupDeferredSlipQr,
      TopupChannel.creditCard => l10n.topupDeferredSlipCredit,
      TopupChannel.bankTransfer => '',
    };
  }
}

class _TopupAmountPanel extends StatelessWidget {
  const _TopupAmountPanel({required this.amount});

  final TextEditingController amount;

  static const _quickAmounts = [100, 300, 500, 1000, 2000, 5000];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.topupAmountLabel,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
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
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final value in _quickAmounts)
                  OutlinedButton(
                    onPressed: () => _setAmount(value),
                    child: Text(_formatQuickAmount(value, l10n)),
                  ),
              ],
            ),
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
    return formatBahtForLocale(
      value,
      localeTag: l10n.locale.toLanguageTag(),
      unit: '',
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
        color: colorScheme.surfaceContainerLow,
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.75),
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
                      fontWeight: FontWeight.w800,
                      height: 1.35,
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
        borderRadius: BorderRadius.circular(16),
        color: colorScheme.surfaceContainerHighest,
        border: Border.all(color: colorScheme.outlineVariant),
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
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.topupBankSlipDescription,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
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
                  ),
                ),
                if (hasSlip) ...[
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    onPressed: onClearSlip,
                    icon: const Icon(Icons.close),
                    tooltip: l10n.topupBankSlipRemove,
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
          icon: const Icon(Icons.schedule),
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

class _TopupBlockingWaitingNotice extends StatelessWidget {
  const _TopupBlockingWaitingNotice();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.secondary.withValues(alpha: 0.24),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: colorScheme.secondary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.topupBlockingWaitingTitle,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: colorScheme.onSecondaryContainer,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.l10n.topupBlockingWaitingMessage,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSecondaryContainer,
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

class _ChannelTile extends StatelessWidget {
  const _ChannelTile({
    required this.channel,
    required this.selected,
    required this.enabled,
    required this.blocked,
    required this.onTap,
  });

  final TopupChannel channel;
  final bool selected;
  final bool enabled;
  final bool blocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: enabled && !blocked ? onTap : null,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected && enabled
                ? colorScheme.primary
                : Colors.black.withValues(alpha: 0.07),
            width: selected && enabled ? 1.6 : 1,
          ),
          color: enabled && !blocked
              ? Colors.white
              : colorScheme.surfaceContainerHighest,
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(
                _iconForChannel(channel),
                color: enabled && !blocked
                    ? colorScheme.primary
                    : Theme.of(context).disabledColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _channelLabel(l10n, channel),
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    if (!enabled) ...[
                      const SizedBox(height: 6),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Chip(
                          label: Text(l10n.topupChannelDisabled),
                          visualDensity: VisualDensity.compact,
                          backgroundColor:
                              Theme.of(context).colorScheme.errorContainer,
                          labelStyle: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onErrorContainer,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      _channelDescription(l10n, channel),
                      style: TextStyle(
                        color: enabled && !blocked
                            ? null
                            : Theme.of(context).disabledColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected && enabled && !blocked)
                const Icon(Icons.check_circle),
            ],
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

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.primaryContainer,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              bank.bankName.isEmpty
                  ? l10n.topupBankAccountFallback
                  : bank.bankName,
            ),
            const SizedBox(height: 6),
            Text(
              bank.accountName,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            Text(bank.accountNumber),
          ],
        ),
      ),
    );
  }
}
