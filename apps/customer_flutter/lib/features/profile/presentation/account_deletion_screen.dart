import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/customer_localizations.dart';
import '../../../core/utils/api_errors.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/customer_page_body.dart';
import '../data/account_deletion_repository.dart';

enum _DeletionStep { impact, reason, pin, otp }

class AccountDeletionScreen extends ConsumerStatefulWidget {
  const AccountDeletionScreen({super.key});

  @override
  ConsumerState<AccountDeletionScreen> createState() =>
      _AccountDeletionScreenState();
}

class _AccountDeletionScreenState extends ConsumerState<AccountDeletionScreen> {
  final _detailController = TextEditingController();
  final _pinController = TextEditingController();
  final _otpController = TextEditingController();
  _DeletionStep _step = _DeletionStep.impact;
  String _reasonCode = '';
  String _pinVerificationToken = '';
  bool _busy = false;
  String _error = '';

  @override
  void dispose() {
    _detailController.dispose();
    _pinController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(accountDeletionStatusProvider);
    return AppShell(
      title: context.l10n.accountDeletionTitle,
      currentPath: '/profile/account-deletion',
      backPath: '/profile',
      sensitive: true,
      child: status.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _LoadError(
          message: _message(error),
          onRetry: () => ref.invalidate(accountDeletionStatusProvider),
        ),
        data: (data) {
          final request = data.request;
          if (request != null && request.isOpen) {
            return _PendingDeletionView(
              request: request,
              onCancel: _showCancelSheet,
              busy: _busy,
            );
          }
          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: CustomerPageBody(
                    top: 14,
                    bottom: 24,
                    minViewportHeight: true,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: _stepContent(data),
                    ),
                  ),
                ),
              ),
              _BottomAction(
                label: _actionLabel,
                busy: _busy,
                enabled: _canContinue(data),
                onPressed: () => _continue(data),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _stepContent(AccountDeletionStatus status) {
    return switch (_step) {
      _DeletionStep.impact => _ImpactStep(
        key: const ValueKey('impact'),
        status: status,
        error: _error,
      ),
      _DeletionStep.reason => _ReasonStep(
        key: const ValueKey('reason'),
        selected: _reasonCode,
        detailController: _detailController,
        error: _error,
        onChanged: (value) => setState(() {
          _reasonCode = value;
          _error = '';
        }),
      ),
      _DeletionStep.pin => _CodeStep(
        key: const ValueKey('pin'),
        title: context.l10n.accountDeletionPinTitle,
        controller: _pinController,
        obscure: true,
        error: _error,
        onComplete: () => _continue(status),
      ),
      _DeletionStep.otp => _CodeStep(
        key: const ValueKey('otp'),
        title: context.l10n.accountDeletionOtpTitle,
        subtitle: context.l10n.accountDeletionOtpSubtitle,
        controller: _otpController,
        error: _error,
        onComplete: () => _continue(status),
      ),
    };
  }

  String get _actionLabel => switch (_step) {
    _DeletionStep.otp => context.l10n.accountDeletionConfirm,
    _ => context.l10n.accountDeletionContinue,
  };

  bool _canContinue(AccountDeletionStatus status) {
    if (_busy) return false;
    return switch (_step) {
      _DeletionStep.impact => status.eligible,
      _DeletionStep.reason =>
        _reasonCode.isNotEmpty &&
            (_reasonCode != 'other' ||
                _detailController.text.trim().isNotEmpty),
      _DeletionStep.pin => _pinController.text.length == 6,
      _DeletionStep.otp => _otpController.text.length == 6,
    };
  }

  Future<void> _continue(AccountDeletionStatus status) async {
    if (!_canContinue(status)) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _error = '';
      _busy = true;
    });
    try {
      if (_step == _DeletionStep.impact) {
        setState(() => _step = _DeletionStep.reason);
        return;
      }
      if (_step == _DeletionStep.reason) {
        setState(() => _step = _DeletionStep.pin);
        return;
      }
      if (_step == _DeletionStep.pin) {
        final result = await ref
            .read(accountDeletionRepositoryProvider)
            .requestOtp(_pinController.text);
        _pinVerificationToken = result.pinVerificationToken;
        if (!mounted) return;
        setState(() => _step = _DeletionStep.otp);
        return;
      }
      final otpToken = await ref
          .read(accountDeletionRepositoryProvider)
          .verifyOtp(_otpController.text);
      await ref
          .read(accountDeletionRepositoryProvider)
          .create(
            reasonCode: _reasonCode,
            reasonDetail: _detailController.text.trim(),
            pinVerificationToken: _pinVerificationToken,
            otpVerificationToken: otpToken,
          );
      ref.invalidate(accountDeletionStatusProvider);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _message(error);
        if (_step == _DeletionStep.otp) _otpController.clear();
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showCancelSheet() async {
    final controller = TextEditingController();
    final pin = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.viewInsetsOf(sheetContext).bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.accountDeletionCancelConfirm,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.center,
              decoration: const InputDecoration(counterText: ''),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                if (controller.text.length == 6) {
                  Navigator.of(sheetContext).pop(controller.text);
                }
              },
              child: Text(context.l10n.accountDeletionCancel),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (pin == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(accountDeletionRepositoryProvider).cancel(pin);
      ref.invalidate(accountDeletionStatusProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.accountDeletionCancelled)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_message(error))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _message(Object error) {
    final info = ApiErrorInfo.fromObject(error);
    return info.message.trim().isNotEmpty
        ? info.message.trim()
        : context.l10n.accountDeletionGenericError;
  }
}

class _ImpactStep extends StatelessWidget {
  const _ImpactStep({required this.status, required this.error, super.key});

  final AccountDeletionStatus status;
  final String error;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Panel(
          color: colors.errorContainer.withValues(alpha: 0.45),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded, color: colors.error),
              const SizedBox(height: 10),
              Text(
                context.l10n.accountDeletionImpactTitle,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.accountDeletionImpactBody,
                style: const TextStyle(height: 1.55),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _Panel(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                status.eligible ? Icons.check_circle : Icons.info_outline,
                color: status.eligible ? Colors.green : colors.error,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      status.eligible
                          ? context.l10n.accountDeletionEligibilityReady
                          : context.l10n.accountDeletionEligibilityBlocked,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    if (!status.eligible) ...[
                      const SizedBox(height: 8),
                      ...status.blockers.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Text('• ${_blockerLabel(context, item.code)}'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        if (error.isNotEmpty) _InlineError(error),
      ],
    );
  }
}

class _ReasonStep extends StatelessWidget {
  const _ReasonStep({
    required this.selected,
    required this.detailController,
    required this.error,
    required this.onChanged,
    super.key,
  });

  final String selected;
  final TextEditingController detailController;
  final String error;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final choices = {
      'no_longer_use': context.l10n.accountDeletionReasonNoLongerUse,
      'privacy': context.l10n.accountDeletionReasonPrivacy,
      'experience': context.l10n.accountDeletionReasonExperience,
      'duplicate_account': context.l10n.accountDeletionReasonDuplicate,
      'other': context.l10n.accountDeletionReasonOther,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.l10n.accountDeletionReasonTitle,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        _Panel(
          padding: EdgeInsets.zero,
          child: RadioGroup<String>(
            groupValue: selected,
            onChanged: (value) {
              if (value != null) onChanged(value);
            },
            child: Column(
              children: choices.entries
                  .map(
                    (entry) => RadioListTile<String>(
                      value: entry.key,
                      title: Text(entry.value),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: detailController,
          maxLength: 500,
          maxLines: 5,
          decoration: InputDecoration(
            labelText: context.l10n.accountDeletionReasonDetail,
            alignLabelWithHint: true,
          ),
        ),
        if (error.isNotEmpty) _InlineError(error),
      ],
    );
  }
}

class _CodeStep extends StatelessWidget {
  const _CodeStep({
    required this.title,
    required this.controller,
    required this.error,
    required this.onComplete,
    this.subtitle = '',
    this.obscure = false,
    super.key,
  });

  final String title;
  final String subtitle;
  final TextEditingController controller;
  final String error;
  final bool obscure;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 32),
        Icon(
          obscure ? Icons.lock_outline : Icons.sms_outlined,
          size: 52,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 18),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(subtitle, textAlign: TextAlign.center),
        ],
        const SizedBox(height: 24),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: TextField(
            controller: controller,
            autofocus: true,
            obscureText: obscure,
            obscuringCharacter: '●',
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            autofillHints: obscure ? null : const [AutofillHints.oneTimeCode],
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 28, letterSpacing: 0),
            decoration: const InputDecoration(counterText: ''),
            onChanged: (value) {
              if (value.length == 6 && !obscure) onComplete();
            },
            onSubmitted: (_) => onComplete(),
          ),
        ),
        if (error.isNotEmpty) _InlineError(error),
      ],
    );
  }
}

class _PendingDeletionView extends StatefulWidget {
  const _PendingDeletionView({
    required this.request,
    required this.onCancel,
    required this.busy,
  });

  final AccountDeletionRequest request;
  final VoidCallback onCancel;
  final bool busy;

  @override
  State<_PendingDeletionView> createState() => _PendingDeletionViewState();
}

class _PendingDeletionViewState extends State<_PendingDeletionView> {
  Timer? _timer;
  late int _seconds;

  @override
  void initState() {
    super.initState();
    _seconds = widget.request.remainingSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _seconds > 0) setState(() => _seconds--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final blocked = widget.request.status == 'blocked';
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: CustomerPageBody(
              top: 20,
              bottom: 24,
              minViewportHeight: true,
              child: Column(
                children: [
                  Icon(
                    blocked ? Icons.info_outline : Icons.schedule,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    blocked
                        ? context.l10n.accountDeletionBlockedTitle
                        : context.l10n.accountDeletionPendingTitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.accountDeletionPendingBody,
                    textAlign: TextAlign.center,
                  ),
                  if (!blocked) ...[
                    const SizedBox(height: 24),
                    Text(
                      _duration(_seconds),
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ],
                  if (blocked && widget.request.blockers.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: widget.request.blockers
                            .map(
                              (item) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 5,
                                ),
                                child: Text(
                                  '• ${_blockerLabel(context, item.code)}',
                                ),
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        _BottomAction(
          label: context.l10n.accountDeletionCancel,
          busy: widget.busy,
          enabled: !widget.busy,
          destructive: true,
          onPressed: widget.onCancel,
        ),
      ],
    );
  }
}

class _BottomAction extends StatelessWidget {
  const _BottomAction({
    required this.label,
    required this.busy,
    required this.enabled,
    required this.onPressed,
    this.destructive = false,
  });

  final String label;
  final bool busy;
  final bool enabled;
  final bool destructive;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(18, 12, 18, 14),
        child: FilledButton(
          onPressed: enabled ? onPressed : null,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            backgroundColor: destructive ? colors.error : colors.primary,
          ),
          child: busy
              ? const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(label),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.child,
    this.color,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: child,
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onRetry,
              child: Text(context.l10n.accountDeletionRetry),
            ),
          ],
        ),
      ),
    );
  }
}

String _duration(int seconds) {
  final duration = Duration(seconds: seconds);
  final days = duration.inDays;
  final hours = duration.inHours.remainder(24);
  final minutes = duration.inMinutes.remainder(60);
  final secs = duration.inSeconds.remainder(60);
  return '${days}d ${hours.toString().padLeft(2, '0')}:'
      '${minutes.toString().padLeft(2, '0')}:'
      '${secs.toString().padLeft(2, '0')}';
}

String _blockerLabel(BuildContext context, String code) {
  final thai = Localizations.localeOf(context).languageCode == 'th';
  return switch (code) {
    'wallet_balance' =>
      thai ? 'ยังมียอดเงินใน Wallet' : 'Wallet balance remains',
    'orders_pending' =>
      thai ? 'มีคำสั่งซื้อที่กำลังดำเนินการ' : 'Orders are pending',
    'topups_pending' =>
      thai ? 'มีรายการเติมเงินที่กำลังดำเนินการ' : 'Topups are pending',
    'reward_claims_pending' =>
      thai
          ? 'มีรายการขึ้นเงินรางวัลที่กำลังดำเนินการ'
          : 'Reward claims are pending',
    'activity_claims_pending' =>
      thai
          ? 'มีรายการรับรางวัลกิจกรรมที่กำลังดำเนินการ'
          : 'Activity claims are pending',
    'activity_awards_unclaimed' =>
      thai
          ? 'มีรางวัลกิจกรรมที่ยังไม่ได้รับ'
          : 'Activity awards remain unclaimed',
    'affiliate_balance' =>
      thai ? 'ยังมียอดคอมมิชชันคงเหลือ' : 'Affiliate balance remains',
    'affiliate_payouts_pending' =>
      thai
          ? 'มีรายการถอนคอมมิชชันที่กำลังดำเนินการ'
          : 'Affiliate payouts are pending',
    _ => context.l10n.accountDeletionEligibilityBlocked,
  };
}
