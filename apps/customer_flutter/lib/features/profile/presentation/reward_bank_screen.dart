import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/customer_localizations.dart';
import '../../../core/security/biometric_auth_service.dart';
import '../../../core/tenant/mobile_bootstrap_controller.dart';
import '../../../core/tenant/mobile_runtime_policy.dart';
import '../../../shared/widgets/app_shell.dart';
import '../data/profile_settings_models.dart';
import '../data/profile_settings_repository.dart';

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
        ? _RewardBankPinStep(
            pin: _pin,
            error: _pinError,
            saving: _saving,
            biometricEnabled: biometricEnabled,
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
            child: RefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(customerProfileSettingsProvider),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  const _RewardBankHero(),
                  const SizedBox(height: 12),
                  profile.when(
                    data: (data) {
                      _hydrateFromProfile(data);
                      return _RewardBankForm(
                        bankName: _bankName,
                        accountName: _accountName,
                        accountNumber: _accountNumber,
                        saving: _saving,
                        onBankChanged: (value) =>
                            setState(() => _bankName = value ?? ''),
                        onSubmit: _startSave,
                      );
                    },
                    loading: () => const Card(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
                    error: (_, __) => Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Text(
                              l10n.profileRewardBankLoadFailed,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () => ref.invalidate(
                                customerProfileSettingsProvider,
                              ),
                              icon: const Icon(Icons.refresh),
                              label: Text(l10n.commonRetry),
                            ),
                          ],
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
    if (mounted) setState(() {});
  }

  void _startSave() {
    final account = _currentAccount();
    if (!account.isComplete) {
      _showSnack(context.l10n.profileRewardBankIncomplete);
      return;
    }
    setState(() {
      _pinStep = true;
      _pin = '';
      _pinError = '';
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
      _showSnack(savedMessage);
      final redirect = widget.redirect ?? '';
      if (redirect.startsWith('/') && !redirect.startsWith('//')) {
        context.go(redirect);
      } else {
        setState(() {
          _pinStep = false;
          _pin = '';
          _pinError = '';
        });
      }
    } catch (error) {
      final code = _errorCode(error);
      if (!mounted) return;
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
        setState(() => _pinStep = false);
        _showSnack(saveFailedMessage);
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
                localizedReason: context.l10n.pinBiometricReason,
              );
      if (!mounted) return;
      if (token == null || token.isEmpty) {
        setState(() => _pinError = context.l10n.pinBiometricUnavailable);
        return;
      }
      await _submitBankAccount(pinAssertionToken: token);
    } catch (_) {
      if (!mounted) return;
      setState(() => _pinError = context.l10n.pinBiometricFailed);
    }
  }

  String _errorCode(Object error) {
    final data = error is DioException ? error.response?.data : null;
    if (data is Map) {
      final err = data['error'];
      if (err is Map && err['code'] != null) return err['code'].toString();
      if (data['code'] != null) return data['code'].toString();
    }
    return '';
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _RewardBankHero extends StatelessWidget {
  const _RewardBankHero();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: const Icon(Icons.account_balance_outlined),
        ),
        title: Text(
          l10n.profileRewardBankHeroTitle,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(l10n.profileRewardBankHeroSubtitle),
      ),
    );
  }
}

class _RewardBankForm extends StatelessWidget {
  const _RewardBankForm({
    required this.bankName,
    required this.accountName,
    required this.accountNumber,
    required this.saving,
    required this.onBankChanged,
    required this.onSubmit,
  });

  final String bankName;
  final TextEditingController accountName;
  final TextEditingController accountNumber;
  final bool saving;
  final ValueChanged<String?> onBankChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bankOptions = l10n.profileRewardBankOptions;
    final preview = RewardBankAccount(
      bankName: bankName,
      accountName: accountName.text,
      accountNumber: accountNumber.text,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.profileRewardBankFormTitle,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.profileRewardBankFormDescription,
              style: TextStyle(color: Colors.grey.shade700, height: 1.4),
            ),
            const SizedBox(height: 16),
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
              decoration: InputDecoration(
                labelText: l10n.profileRewardBankBankLabel,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: accountName,
              enabled: !saving,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: l10n.profileRewardBankAccountNameLabel,
                hintText: l10n.profileRewardBankAccountNameHint,
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
              decoration: InputDecoration(
                labelText: l10n.profileRewardBankAccountNumberLabel,
                hintText: l10n.profileRewardBankAccountNumberHint,
              ),
            ),
            const SizedBox(height: 16),
            _RewardBankPreview(account: preview),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: saving ? null : onSubmit,
              icon: saving
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(l10n.profileRewardBankSaveButton),
            ),
          ],
        ),
      ),
    );
  }
}

class _RewardBankPreview extends StatelessWidget {
  const _RewardBankPreview({required this.account});

  final RewardBankAccount account;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: account.isComplete
            ? Theme.of(context).colorScheme.primaryContainer.withValues(
                  alpha: 0.35,
                )
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.credit_card_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.isComplete
                        ? account.bankName
                        : l10n.profileRewardBankPreviewEmptyTitle,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    account.isComplete
                        ? '${account.accountName} · ${account.maskedNumber}'
                        : l10n.profileRewardBankPreviewEmptySubtitle,
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

class _RewardBankPinStep extends StatelessWidget {
  const _RewardBankPinStep({
    required this.pin,
    required this.error,
    required this.saving,
    required this.biometricEnabled,
    required this.onBack,
    required this.onDigit,
    required this.onBackspace,
    required this.onBiometric,
  });

  final String pin;
  final String error;
  final bool saving;
  final bool biometricEnabled;
  final VoidCallback onBack;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onBiometric;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: saving ? null : onBack,
                  icon: const Icon(Icons.arrow_back_ios_new),
                ),
              ),
              const Spacer(),
              Text(
                l10n.profileRewardBankPinTitle,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w900),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(l10n.profileRewardBankPinSubtitle),
              const SizedBox(height: 18),
              Text(
                '${'●' * pin.length}${'○' * (6 - pin.length)}',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              if (error.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  error,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              if (saving) ...[
                const SizedBox(height: 16),
                const CircularProgressIndicator(),
              ],
              const SizedBox(height: 12),
              if (biometricEnabled) ...[
                OutlinedButton.icon(
                  onPressed: saving ? null : onBiometric,
                  icon: const Icon(Icons.face_retouching_natural),
                  label: Text(l10n.pinUseBiometric),
                ),
                const SizedBox(height: 24),
              ] else
                const SizedBox(height: 24),
              _PinKeypad(onDigit: onDigit, onBackspace: onBackspace),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _PinKeypad extends StatelessWidget {
  const _PinKeypad({required this.onDigit, required this.onBackspace});

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    final keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', 'back'];
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 3,
      childAspectRatio: 1.8,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (final key in keys)
          if (key.isEmpty)
            const SizedBox.shrink()
          else
            TextButton(
              onPressed: key == 'back' ? onBackspace : () => onDigit(key),
              child: key == 'back'
                  ? const Icon(Icons.backspace_outlined)
                  : Text(key, style: Theme.of(context).textTheme.titleLarge),
            ),
      ],
    );
  }
}
