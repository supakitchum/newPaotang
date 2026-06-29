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
import 'topup_realtime_monitor.dart';

class TopupScreen extends ConsumerStatefulWidget {
  const TopupScreen({super.key});

  @override
  ConsumerState<TopupScreen> createState() => _TopupScreenState();
}

class _TopupScreenState extends ConsumerState<TopupScreen> {
  final _amount = TextEditingController(text: '500');
  TopupChannel _selectedChannel = TopupChannel.qr;
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
                                : () => _cancelWaitingTopup(data.waiting!.id),
                          ),
                          const SizedBox(height: 12),
                        ],
                        _TopupFormCard(
                          overview: data,
                          amount: _amount,
                          selectedChannel: selectedChannel,
                          submitting: _submitting,
                          onChannelChanged: (channel) =>
                              setState(() => _selectedChannel = channel),
                          onSubmit: data.waiting?.status.isTerminal == false
                              ? null
                              : () => _submitTopup(selectedChannel),
                        ),
                      ],
                    );
                  },
                  empty: _TopupFormCard(
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
                    amount: _amount,
                    selectedChannel: _selectedChannel,
                    submitting: _submitting,
                    onChannelChanged: (channel) =>
                        setState(() => _selectedChannel = channel),
                    onSubmit: _submitTopup,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitTopup([TopupChannel? channelOverride]) async {
    final channel = channelOverride ?? _selectedChannel;
    final amount = double.tryParse(_amount.text.trim()) ?? 0;
    final l10n = context.l10n;
    if (amount <= 0) {
      _showSnack(l10n.topupAmountRequired);
      return;
    }
    if (channel == TopupChannel.creditCard && amount < 400) {
      _showSnack(l10n.topupCreditMinimum);
      return;
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
          transferAt:
              channel == TopupChannel.bankTransfer ? DateTime.now() : null,
        );
      }
      ref.invalidate(topupOverviewProvider);
      _showSnack(l10n.topupCreated);
    } catch (error) {
      if (!mounted) return;
      final message = customerErrorMessage(error, l10n.topupCreateFailed);
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

  Future<void> _cancelWaitingTopup(String id) async {
    final l10n = context.l10n;
    setState(() => _submitting = true);
    try {
      await ref.read(topupRepositoryProvider).cancel(id);
      ref.invalidate(topupOverviewProvider);
      _showSnack(l10n.topupCancelled);
    } catch (error) {
      if (!mounted) return;
      final message = customerErrorMessage(error, l10n.topupCancelFailed);
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
      final message = customerErrorMessage(error, l10n.topupSlipUploadFailed);
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

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
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

    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      color: colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.topupWaitingTitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                _TopupStatusBadge(label: _statusLabel(l10n)),
              ],
            ),
            const SizedBox(height: 8),
            Text(l10n.topupReference(topup.id)),
            const SizedBox(height: 8),
            _WaitingAmountPanel(
              amount: formatBaht(topup.amount),
              label: _channelLabel(l10n),
            ),
            const SizedBox(height: 8),
            Text(
              '${_channelLabel(l10n)} • '
              '${formatLocalizedDateTime(topup.createdAt, l10n.locale.toLanguageTag())}',
            ),
            if (topup.qrCode.isNotEmpty) ...[
              const SizedBox(height: 16),
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: FlexibleImage(
                    source: topup.qrCode,
                    width: 220,
                    height: 220,
                    fit: BoxFit.contain,
                    errorIcon: Icons.qr_code_2,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(l10n.topupQrSlipInstruction),
            ],
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
            if (topup.needsSlip && topup.qrCode.isEmpty) ...[
              const SizedBox(height: 8),
              Text(l10n.topupNeedsSlip),
            ],
            if (!topup.status.isTerminal && topup.needsSlip) ...[
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
                    topup.slipUrl.isNotEmpty
                        ? l10n.topupUploadNewSlip
                        : l10n.topupUploadSlip,
                  ),
                ),
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

  String _channelLabel(CustomerLocalizations l10n) {
    return switch (topup.channel) {
      TopupChannel.qr => l10n.topupChannelQrLabel,
      TopupChannel.creditCard => l10n.topupChannelCreditLabel,
      TopupChannel.bankTransfer => l10n.topupChannelBankLabel,
    };
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
  const _TopupStatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.primary,
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
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white,
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              amount,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopupFormCard extends StatelessWidget {
  const _TopupFormCard({
    required this.overview,
    required this.amount,
    required this.selectedChannel,
    required this.submitting,
    required this.onChannelChanged,
    required this.onSubmit,
  });

  final TopupOverview overview;
  final TextEditingController amount;
  final TopupChannel selectedChannel;
  final bool submitting;
  final ValueChanged<TopupChannel> onChannelChanged;
  final VoidCallback? onSubmit;

  static const _quickAmounts = [100, 300, 500, 1000, 2000, 5000];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final selectedEnabled = overview.isChannelEnabled(selectedChannel);
    final submitEnabled = onSubmit != null && selectedEnabled;

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
            const SizedBox(height: 12),
            for (final channel in TopupChannel.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ChannelTile(
                  channel: channel,
                  selected: selectedChannel == channel,
                  enabled: overview.isChannelEnabled(channel),
                  onTap: () => onChannelChanged(channel),
                ),
              ),
            if (selectedChannel == TopupChannel.bankTransfer &&
                overview.bank.isConfigured) ...[
              const SizedBox(height: 10),
              _BankInfoCard(bank: overview.bank),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: amount,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: l10n.topupAmountLabel,
                suffixText: l10n.topupBahtSuffix,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final value in _quickAmounts)
                  ActionChip(
                    label: Text(value.toString()),
                    onPressed: () => amount.text = value.toString(),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: submitting || !submitEnabled ? null : onSubmit,
              child: submitting
                  ? const CircularProgressIndicator()
                  : Text(_submitLabel(l10n)),
            ),
          ],
        ),
      ),
    );
  }

  String _submitLabel(CustomerLocalizations l10n) {
    return switch (selectedChannel) {
      TopupChannel.qr => l10n.topupCreateQr,
      TopupChannel.creditCard => l10n.topupCreateCreditQr,
      TopupChannel.bankTransfer => l10n.topupCreateBankTransfer,
    };
  }
}

class _ChannelTile extends StatelessWidget {
  const _ChannelTile({
    required this.channel,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final TopupChannel channel;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: enabled ? onTap : null,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected && enabled
                ? colorScheme.primary
                : Colors.black.withValues(alpha: 0.07),
            width: selected && enabled ? 1.6 : 1,
          ),
          color: enabled ? Colors.white : colorScheme.surfaceContainerHighest,
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(
                _icon,
                color: enabled
                    ? colorScheme.primary
                    : Theme.of(context).disabledColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _channelLabel(l10n),
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
                      _channelDescription(l10n),
                      style: TextStyle(
                        color: enabled ? null : Theme.of(context).disabledColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected && enabled) const Icon(Icons.check_circle),
            ],
          ),
        ),
      ),
    );
  }

  IconData get _icon {
    return switch (channel) {
      TopupChannel.qr => Icons.qr_code_2,
      TopupChannel.creditCard => Icons.qr_code_scanner,
      TopupChannel.bankTransfer => Icons.account_balance,
    };
  }

  String _channelLabel(CustomerLocalizations l10n) {
    return switch (channel) {
      TopupChannel.qr => l10n.topupChannelQrLabel,
      TopupChannel.creditCard => l10n.topupChannelCreditLabel,
      TopupChannel.bankTransfer => l10n.topupChannelBankLabel,
    };
  }

  String _channelDescription(CustomerLocalizations l10n) {
    return switch (channel) {
      TopupChannel.qr => l10n.topupChannelQrDescription,
      TopupChannel.creditCard => l10n.topupChannelCreditDescription,
      TopupChannel.bankTransfer => l10n.topupChannelBankDescription,
    };
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
