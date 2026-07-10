import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_error_message.dart';
import '../../../core/i18n/customer_localizations.dart';
import '../../../core/security/biometric_auth_service.dart';
import '../../../core/tenant/mobile_bootstrap_controller.dart';
import '../../../core/tenant/mobile_runtime_policy.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/api_errors.dart';
import '../../../shared/utils/customer_operational_error.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/customer_gradient_button.dart';
import '../../../shared/widgets/customer_loading_indicator.dart';
import '../../../shared/widgets/customer_page_body.dart';
import '../../../shared/widgets/pin_confirmation_step.dart';
import '../data/profile_settings_models.dart';
import '../data/profile_settings_repository.dart';

Color _rewardBankPrimaryTint(ColorScheme colorScheme) =>
    Color.lerp(colorScheme.primary, colorScheme.surface, 0.88) ??
    colorScheme.primary.withValues(alpha: 0.12);

Color _rewardBankSurfaceTint(ColorScheme colorScheme) =>
    Color.lerp(colorScheme.surface, colorScheme.primaryContainer, 0.08) ??
    colorScheme.surface;

Color _rewardBankSuccessTint(ColorScheme colorScheme) =>
    Color.lerp(colorScheme.tertiaryContainer, colorScheme.surface, 0.36) ??
    colorScheme.tertiaryContainer.withValues(alpha: 0.64);

class RewardBankScreen extends ConsumerStatefulWidget {
  const RewardBankScreen({this.redirect, super.key});

  final String? redirect;

  @override
  ConsumerState<RewardBankScreen> createState() => _RewardBankScreenState();
}

class _RewardBankScreenState extends ConsumerState<RewardBankScreen> {
  final _accountName = TextEditingController();
  final _accountNumber = TextEditingController();
  String _bankName = '';
  String _pin = '';
  String _pinError = '';
  String _formNoticeMessage = '';
  bool _formNoticeIsError = true;
  String _hydratedProfileId = '';
  bool _saving = false;
  bool _pinStep = false;

  @override
  void initState() {
    super.initState();
    _accountName.addListener(_refreshPreview);
    _accountNumber.addListener(_refreshPreview);
  }

  @override
  void dispose() {
    _accountName.removeListener(_refreshPreview);
    _accountNumber.removeListener(_refreshPreview);
    _accountName.dispose();
    _accountNumber.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final profile = ref.watch(customerProfileSettingsProvider);
    final platformKey = ref.watch(customerPlatformKeyProvider);
    final biometricEnabled = ref.watch(mobileBootstrapProvider).maybeWhen(
          data: (data) => mobileBiometricAllowedForPlatform(data, platformKey),
          orElse: () => false,
        );
    return _pinStep
        ? PinConfirmationStep(
            title: l10n.profileRewardBankPinTitle,
            subtitle: l10n.profileRewardBankPinSubtitle,
            pin: _pin,
            error: _pinError,
            saving: _saving,
            biometricEnabled: biometricEnabled,
            biometricLabel: l10n.pinUseBiometric,
            onBack: () => setState(() {
              _pinStep = false;
              _pin = '';
              _pinError = '';
            }),
            onDigit: _appendPinDigit,
            onBackspace: _removePinDigit,
            onBiometric: _submitBankAccountWithBiometric,
          )
        : AppShell(
            title: l10n.profileRewardBank,
            currentPath: '/profile',
            sensitive: true,
            fullScreen: true,
            child: RefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(customerProfileSettingsProvider),
              child: ListView(
                padding: EdgeInsets.zero,
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  _RewardBankHero(onBack: () => context.go('/profile')),
                  _RewardBankContentSheet(
                    child: CustomerPageBody(
                      top: 16,
                      bottom: 128,
                      maxWidth: 640,
                      child: profile.when(
                        data: (data) {
                          _hydrateFromProfile(data);
                          return _RewardBankForm(
                            bankName: _bankName,
                            accountName: _accountName,
                            accountNumber: _accountNumber,
                            noticeMessage: _formNoticeMessage,
                            noticeIsError: _formNoticeIsError,
                            saving: _saving,
                            onBankChanged: (value) => setState(() {
                              _bankName = value ?? '';
                              _formNoticeMessage = '';
                            }),
                            onSubmit: _startSave,
                          );
                        },
                        loading: () => const _RewardBankStatePanel(),
                        error: (_, __) => _RewardBankStatePanel(
                          message: l10n.profileRewardBankLoadFailed,
                          onRetry: () => ref.invalidate(
                            customerProfileSettingsProvider,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
  }

  void _hydrateFromProfile(CustomerProfileSettings profile) {
    if (_hydratedProfileId == profile.id) return;
    _hydratedProfileId = profile.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final bank = profile.bankAccount;
      setState(() {
        _bankName = bank.bankName;
        _accountName.text = bank.accountName;
        _accountNumber.text = bank.accountNumber;
      });
    });
  }

  void _refreshPreview() {
    if (mounted) {
      setState(() {
        if (_formNoticeMessage.isNotEmpty) _formNoticeMessage = '';
      });
    }
  }

  void _startSave() {
    final account = _currentAccount();
    if (!account.isComplete) {
      setState(() {
        _formNoticeMessage = context.l10n.profileRewardBankIncomplete;
        _formNoticeIsError = true;
      });
      return;
    }
    setState(() {
      _pinStep = true;
      _pin = '';
      _pinError = '';
      _formNoticeMessage = '';
    });
  }

  RewardBankAccount _currentAccount() {
    return RewardBankAccount(
      bankName: _bankName,
      accountName: _accountName.text.trim(),
      accountNumber: _accountNumber.text.replaceAll(RegExp(r'\D'), ''),
    );
  }

  Future<void> _appendPinDigit(String digit) async {
    if (_saving || _pin.length >= 6 || !RegExp(r'^\d$').hasMatch(digit)) {
      return;
    }
    setState(() {
      _pinError = '';
      _pin += digit;
    });
    if (_pin.length == 6) await _submitBankAccount();
  }

  void _removePinDigit() {
    if (_saving || _pin.isEmpty) return;
    setState(() {
      _pinError = '';
      _pin = _pin.substring(0, _pin.length - 1);
    });
  }

  Future<void> _submitBankAccount({String pinAssertionToken = ''}) async {
    final l10n = context.l10n;
    final savedMessage = l10n.profileRewardBankSaved;
    final saveFailedMessage = l10n.profileRewardBankSaveFailed;
    final pinInvalidMessage = l10n.profileRewardBankPinInvalid;
    final pinLockedMessage = l10n.profileRewardBankPinLocked;
    final pinRequiredMessage = l10n.profileRewardBankPinRequired;
    setState(() => _saving = true);
    try {
      await ref.read(profileSettingsRepositoryProvider).saveRewardBank(
            bankAccount: _currentAccount(),
            pin: pinAssertionToken.isEmpty ? _pin : '',
            pinAssertionToken: pinAssertionToken,
          );
      ref.invalidate(customerProfileSettingsProvider);
      if (!mounted) return;
      final redirect = widget.redirect ?? '';
      if (redirect.startsWith('/') && !redirect.startsWith('//')) {
        context.go(redirect);
      } else {
        setState(() {
          _pinStep = false;
          _pin = '';
          _pinError = '';
          _formNoticeMessage = savedMessage;
          _formNoticeIsError = false;
        });
      }
    } catch (error) {
      final code = _errorCode(error);
      if (!mounted) return;
      if (await handleCustomerOperationalError(
        ref: ref,
        context: context,
        error: error,
        handlePinRedirect: false,
      )) {
        return;
      }
      setState(() => _pin = '');
      if (code == 'pin_invalid') {
        setState(() => _pinError = pinInvalidMessage);
      } else if (code == 'pin_locked') {
        setState(() => _pinError = pinLockedMessage);
      } else if (code == 'pin_setup_required' || code == 'pin_required') {
        setState(() => _pinError = pinRequiredMessage);
      } else if (code == 'pin_assertion_invalid') {
        setState(() => _pinError = l10n.pinBiometricFailed);
      } else {
        setState(() {
          _pinStep = false;
          _formNoticeMessage = authErrorMessage(error, saveFailedMessage);
          _formNoticeIsError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _submitBankAccountWithBiometric() async {
    if (_saving) return;
    setState(() {
      _pin = '';
      _pinError = '';
    });
    try {
      final token =
          await ref.read(biometricAuthServiceProvider).requestPinAssertion(
                purpose: 'profile_update',
                localizedReason: mobileBiometricPromptReason(
                  ref.read(mobileBootstrapProvider).valueOrNull,
                  purpose: 'profile_update',
                  fallback: context.l10n.pinBiometricReason,
                ),
              );
      if (!mounted) return;
      if (token == null || token.isEmpty) {
        setState(() => _pinError = context.l10n.pinBiometricUnavailable);
        return;
      }
      await _submitBankAccount(pinAssertionToken: token);
    } catch (error) {
      if (!mounted) return;
      if (await handleCustomerOperationalError(
        ref: ref,
        context: context,
        error: error,
        handlePinRedirect: false,
      )) {
        return;
      }
      setState(() => _pinError = context.l10n.pinBiometricFailed);
    }
  }

  String _errorCode(Object error) {
    return ApiErrorInfo.fromObject(error).code;
  }
}

class _RewardBankHero extends StatelessWidget {
  const _RewardBankHero({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final topInset = MediaQuery.paddingOf(context).top;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary,
            AppTheme.heroGradientEnd(colorScheme.primary),
          ],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontal = constraints.maxWidth >= 720 ? 28.0 : 18.0;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontal,
                  topInset + 58,
                  horizontal,
                  38,
                ),
                child: Column(
                  children: [
                    _RewardBankHeroTitleRow(
                      title: l10n.profileRewardBank,
                      onBack: onBack,
                    ),
                    const SizedBox(height: 22),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: SizedBox.square(
                            dimension: 48,
                            child: Icon(
                              Icons.account_balance_outlined,
                              color: colorScheme.primary,
                              size: 24,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.profileRewardBankHeroTitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      color: colorScheme.onPrimary,
                                      fontWeight: FontWeight.w900,
                                      height: 1.3,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                l10n.profileRewardBankHeroSubtitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: colorScheme.onPrimary.withValues(
                                    alpha: 0.92,
                                  ),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RewardBankHeroTitleRow extends StatelessWidget {
  const _RewardBankHeroTitleRow({
    required this.title,
    required this.onBack,
  });

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 42,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 0,
            child: IconButton(
              tooltip: context.l10n.commonBack,
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_ios_new, size: 31),
              color: colorScheme.onPrimary,
              style: IconButton.styleFrom(
                fixedSize: const Size.square(42),
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                backgroundColor: Colors.transparent,
                foregroundColor: colorScheme.onPrimary,
                shape: const CircleBorder(),
              ).copyWith(
                overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 54),
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colorScheme.onPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardBankContentSheet extends StatelessWidget {
  const _RewardBankContentSheet({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(color: colorScheme.primary),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: child,
      ),
    );
  }
}

class _RewardBankForm extends StatelessWidget {
  const _RewardBankForm({
    required this.bankName,
    required this.accountName,
    required this.accountNumber,
    required this.noticeMessage,
    required this.noticeIsError,
    required this.saving,
    required this.onBankChanged,
    required this.onSubmit,
  });

  final String bankName;
  final TextEditingController accountName;
  final TextEditingController accountNumber;
  final String noticeMessage;
  final bool noticeIsError;
  final bool saving;
  final ValueChanged<String?> onBankChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final bankOptions = l10n.profileRewardBankOptions;
    final preview = RewardBankAccount(
      bankName: bankName,
      accountName: accountName.text,
      accountNumber: accountNumber.text,
    );
    return _RewardBankPanel(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.profileRewardBankFormTitle,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.profileRewardBankFormDescription,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            if (noticeMessage.isNotEmpty) ...[
              _RewardBankNotice(
                message: noticeMessage,
                isError: noticeIsError,
              ),
              const SizedBox(height: 14),
            ],
            DropdownButtonFormField<String>(
              initialValue: bankName.isEmpty || !bankOptions.contains(bankName)
                  ? null
                  : bankName,
              items: [
                if (bankName.isNotEmpty && !bankOptions.contains(bankName))
                  DropdownMenuItem(value: bankName, child: Text(bankName)),
                for (final bank in bankOptions)
                  DropdownMenuItem(value: bank, child: Text(bank)),
              ],
              onChanged: saving ? null : onBankChanged,
              decoration: _rewardBankInputDecoration(
                context,
                l10n.profileRewardBankBankLabel,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: accountName,
              enabled: !saving,
              textInputAction: TextInputAction.next,
              decoration: _rewardBankInputDecoration(
                context,
                l10n.profileRewardBankAccountNameLabel,
                hint: l10n.profileRewardBankAccountNameHint,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: accountNumber,
              enabled: !saving,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(20),
              ],
              decoration: _rewardBankInputDecoration(
                context,
                l10n.profileRewardBankAccountNumberLabel,
                hint: l10n.profileRewardBankAccountNumberHint,
              ),
            ),
            const SizedBox(height: 16),
            _RewardBankPreview(account: preview),
            const SizedBox(height: 16),
            CustomerGradientButton(
              onPressed: saving ? null : onSubmit,
              height: 47,
              fontSize: 15,
              shadow: false,
              child: saving
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox.square(
                          dimension: 16,
                          child: CustomerLoadingMark(
                            width: 18,
                            height: 14,
                            color: colorScheme.onPrimary,
                            trackColor:
                                colorScheme.onPrimary.withValues(alpha: 0.24),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(l10n.profileRewardBankSaveButton),
                      ],
                    )
                  : Text(l10n.profileRewardBankSaveButton),
            ),
          ],
        ),
      ),
    );
  }
}

class _RewardBankPanel extends StatelessWidget {
  const _RewardBankPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.09),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _RewardBankStatePanel extends StatelessWidget {
  const _RewardBankStatePanel({
    this.message = '',
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final isError = message.isNotEmpty;
    return _RewardBankPanel(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Center(
          child: isError
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w800,
                            height: 1.45,
                          ),
                    ),
                    if (onRetry != null) ...[
                      const SizedBox(height: 12),
                      OutlinedButton(
                        style: _rewardBankOutlinePillStyle(context),
                        onPressed: onRetry,
                        child: Text(context.l10n.commonRetry),
                      ),
                    ],
                  ],
                )
              : CustomerLoadingMark(
                  width: 46,
                  height: 28,
                  semanticLabel: context.l10n.commonLoadingData,
                ),
        ),
      ),
    );
  }
}

class _RewardBankNotice extends StatelessWidget {
  const _RewardBankNotice({
    required this.message,
    required this.isError,
  });

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = isError ? colorScheme.error : colorScheme.tertiary;
    final background = isError
        ? colorScheme.errorContainer.withValues(alpha: 0.50)
        : _rewardBankSuccessTint(colorScheme);
    final border = isError
        ? colorScheme.error.withValues(alpha: 0.22)
        : colorScheme.tertiary.withValues(alpha: 0.22);
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
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: foreground,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: foreground,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
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

InputDecoration _rewardBankInputDecoration(
  BuildContext context,
  String label, {
  String? hint,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: colorScheme.outlineVariant),
  );
  return InputDecoration(
    labelText: label,
    hintText: hint,
    filled: true,
    fillColor: _rewardBankSurfaceTint(colorScheme),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
    labelStyle: TextStyle(
      color: colorScheme.onSurfaceVariant,
      fontSize: 13,
      fontWeight: FontWeight.w800,
    ),
    hintStyle: TextStyle(
      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.78),
      fontWeight: FontWeight.w700,
    ),
    enabledBorder: border,
    disabledBorder: border,
    focusedBorder: border.copyWith(
      borderSide: BorderSide(color: colorScheme.primary, width: 1.4),
    ),
    errorBorder: border.copyWith(
      borderSide: BorderSide(color: colorScheme.error, width: 1.4),
    ),
    focusedErrorBorder: border.copyWith(
      borderSide: BorderSide(color: colorScheme.error, width: 1.4),
    ),
  );
}

ButtonStyle _rewardBankOutlinePillStyle(BuildContext context) {
  return OutlinedButton.styleFrom(
    foregroundColor: Theme.of(context).colorScheme.primary,
    side: BorderSide(color: Theme.of(context).colorScheme.primary),
    shape: const StadiumBorder(),
    minimumSize: const Size(132, 42),
    padding: const EdgeInsets.symmetric(horizontal: 18),
    textStyle: const TextStyle(fontWeight: FontWeight.w800),
  );
}

class _RewardBankPreview extends StatelessWidget {
  const _RewardBankPreview({required this.account});

  final RewardBankAccount account;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: account.isComplete
            ? _rewardBankSuccessTint(colorScheme)
            : _rewardBankPrimaryTint(colorScheme),
        border: Border.all(
          color: account.isComplete
              ? colorScheme.tertiary.withValues(alpha: 0.22)
              : colorScheme.primary.withValues(alpha: 0.24),
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                shape: BoxShape.circle,
              ),
              child: SizedBox.square(
                dimension: 40,
                child: Icon(
                  Icons.credit_card_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.isComplete
                        ? account.bankName
                        : l10n.profileRewardBankPreviewEmptyTitle,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    account.isComplete
                        ? '${account.accountName} · ${account.maskedNumber}'
                        : l10n.profileRewardBankPreviewEmptySubtitle,
                    style: TextStyle(
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
