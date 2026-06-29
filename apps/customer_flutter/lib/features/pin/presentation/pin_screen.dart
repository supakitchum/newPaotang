import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/auth_repository.dart';
import '../../../core/i18n/customer_localizations.dart';
import '../../../core/tenant/mobile_bootstrap_controller.dart';
import '../../../core/tenant/mobile_runtime_policy.dart';
import '../../../core/utils/api_errors.dart';
import '../../../shared/utils/customer_operational_error.dart';

class PinScreen extends ConsumerStatefulWidget {
  const PinScreen({super.key});

  @override
  ConsumerState<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends ConsumerState<PinScreen> {
  String _pin = '';
  String _setupPin = '';
  bool _confirmingSetupPin = false;
  bool _verifying = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_syncPinStatus);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final auth = ref.watch(authControllerProvider);
    final setupRequired = auth.pinSetupRequired;
    final platformKey = ref.watch(customerPlatformKeyProvider);
    final biometricEnabled = ref.watch(mobileBootstrapProvider).maybeWhen(
          data: (data) => mobileBiometricAllowedForPlatform(data, platformKey),
          orElse: () => false,
        );

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.primary,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primary,
              Color.lerp(colorScheme.primary, colorScheme.secondary, 0.68) ??
                  colorScheme.primary,
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight:
                        (constraints.maxHeight - 48).clamp(0, double.infinity),
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 430),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.18),
                              ),
                            ),
                            child: Icon(
                              setupRequired
                                  ? Icons.lock_outline
                                  : Icons.lock_open_outlined,
                              color: Colors.white,
                              size: 34,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            _title(l10n, setupRequired),
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _description(l10n, setupRequired),
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.84),
                                  fontWeight: FontWeight.w700,
                                  height: 1.42,
                                ),
                          ),
                          const SizedBox(height: 20),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.12),
                                  blurRadius: 28,
                                  offset: const Offset(0, 16),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(20, 24, 20, 20),
                              child: Column(
                                children: [
                                  _PinIndicator(length: _pin.length),
                                  if (_verifying) ...[
                                    const SizedBox(height: 14),
                                    const LinearProgressIndicator(),
                                  ],
                                  const SizedBox(height: 18),
                                  if (!setupRequired && biometricEnabled)
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        onPressed: _verifying
                                            ? null
                                            : _unlockWithBiometric,
                                        icon: const Icon(
                                          Icons.face_retouching_natural,
                                        ),
                                        label: Text(l10n.pinUseBiometric),
                                      ),
                                    ),
                                  if (!setupRequired) ...[
                                    const SizedBox(height: 4),
                                    TextButton(
                                      onPressed: _verifying
                                          ? null
                                          : _showResetPinSheet,
                                      child: Text(l10n.pinForgot),
                                    ),
                                  ],
                                  const SizedBox(height: 10),
                                  _Keypad(
                                    onDigit: _digit,
                                    onBackspace: _backspace,
                                    enabled: !_verifying,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _syncPinStatus() async {
    final auth = ref.read(authControllerProvider);
    if (!auth.isAuthenticated) return;
    try {
      await auth.syncPinStatus();
      if (!mounted) return;
      setState(() {
        _pin = '';
        _setupPin = '';
        _confirmingSetupPin = false;
      });
    } catch (error) {
      if (await handleCustomerOperationalError(
        ref: ref,
        context: context,
        error: error,
      )) {
        return;
      }
      // Keep the session-provided state when status refresh is unavailable.
    }
  }

  String _title(CustomerLocalizations l10n, bool setupRequired) {
    if (!setupRequired) return l10n.pinTitle;
    return _confirmingSetupPin ? l10n.pinSetupConfirmTitle : l10n.pinSetupTitle;
  }

  String _description(CustomerLocalizations l10n, bool setupRequired) {
    if (!setupRequired) return l10n.pinDescription;
    return _confirmingSetupPin
        ? l10n.pinSetupConfirmDescription
        : l10n.pinSetupDescription;
  }

  void _digit(String digit) {
    if (_verifying || _pin.length >= 6) return;
    setState(() => _pin += digit);
    if (_pin.length == 6) {
      if (ref.read(authControllerProvider).pinSetupRequired) {
        _handleSetupPinDigitComplete();
      } else {
        _verifyPin();
      }
    }
  }

  void _backspace() {
    if (_verifying || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _showResetPinSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _PinResetSheet(),
    );
  }

  Future<void> _unlockWithBiometric() async {
    setState(() => _verifying = true);
    try {
      final unlocked =
          await ref.read(authControllerProvider).unlockWithBiometric(
                localizedReason: context.l10n.pinBiometricReason,
              );
      if (!mounted || unlocked) return;
      _showSnack(context.l10n.pinBiometricUnavailable);
    } catch (error) {
      if (!mounted) return;
      final failedMessage = context.l10n.pinBiometricFailed;
      if (await handleCustomerOperationalError(
        ref: ref,
        context: context,
        error: error,
      )) {
        return;
      }
      _showSnack(failedMessage);
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  void _handleSetupPinDigitComplete() {
    if (!_confirmingSetupPin) {
      setState(() {
        _setupPin = _pin;
        _pin = '';
        _confirmingSetupPin = true;
      });
      return;
    }

    if (_pin != _setupPin) {
      setState(() {
        _pin = '';
        _setupPin = '';
        _confirmingSetupPin = false;
      });
      _showSnack(context.l10n.pinSetupMismatch);
      return;
    }

    _setupNewPin();
  }

  Future<void> _setupNewPin() async {
    setState(() => _verifying = true);
    try {
      await ref.read(authControllerProvider).setupPin(
            pin: _setupPin,
            pinConfirmation: _pin,
          );
    } catch (error) {
      if (!mounted) return;
      final message = _errorMessage(error, context.l10n.pinSetupFailed);
      if (await handleCustomerOperationalError(
        ref: ref,
        context: context,
        error: error,
      )) {
        return;
      }
      setState(() {
        _pin = '';
        _setupPin = '';
        _confirmingSetupPin = false;
      });
      _showSnack(message);
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _verifyPin() async {
    setState(() => _verifying = true);
    try {
      await ref.read(authControllerProvider).verifyPin(_pin);
    } catch (error) {
      if (!mounted) return;
      final message = _errorMessage(error, context.l10n.pinInvalid);
      if (await handleCustomerOperationalError(
        ref: ref,
        context: context,
        error: error,
      )) {
        return;
      }
      setState(() => _pin = '');
      _showSnack(message);
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  String _errorMessage(Object error, String fallback) {
    final info = ApiErrorInfo.fromObject(error);
    if (info.isSmsOtpProviderNotConfigured) {
      return context.l10n.pinResetOtpProviderUnavailable;
    }
    if (info.message.trim().isNotEmpty) return info.message;
    return fallback;
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

enum _PinResetStep { request, otp, pin, done }

class _PinResetSheet extends ConsumerStatefulWidget {
  const _PinResetSheet();

  @override
  ConsumerState<_PinResetSheet> createState() => _PinResetSheetState();
}

class _PinResetSheetState extends ConsumerState<_PinResetSheet> {
  final _formKey = GlobalKey<FormState>();
  final _otp = TextEditingController();
  final _pin = TextEditingController();
  final _pinConfirmation = TextEditingController();

  _PinResetStep _step = _PinResetStep.request;
  bool _confirmingResetPin = false;
  bool _submitting = false;
  String _maskedPhone = '';
  String _otpToken = '';
  int _resendAfter = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _otp.dispose();
    _pin.dispose();
    _pinConfirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final l10n = context.l10n;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.42,
        maxChildSize: 0.92,
        builder: (context, scrollController) {
          return Form(
            key: _formKey,
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .outlineVariant
                          .withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.lock_reset,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _title(l10n),
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _description(l10n),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (_step == _PinResetStep.request) _requestCard(context),
                if (_step == _PinResetStep.otp) _otpCard(context),
                if (_step == _PinResetStep.pin) _pinFields(),
                if (_step == _PinResetStep.done) _doneCard(context),
                const SizedBox(height: 20),
                if (_step != _PinResetStep.done && _step != _PinResetStep.pin)
                  FilledButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : Text(_buttonLabel(l10n)),
                  )
                else
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.pinResetBackToApp),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _requestCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.sms_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(context.l10n.pinResetRequestInfo),
            ),
          ],
        ),
      ),
    );
  }

  Widget _otpCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.pinResetOtpSentTo(
                _maskedPhone.isEmpty
                    ? context.l10n.accountPhoneFallback
                    : _maskedPhone,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _otp,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              decoration: InputDecoration(
                labelText: context.l10n.pinResetOtpLabel,
              ),
              validator: _otpValidator,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _resendAfter > 0 || _submitting ? null : _requestOtp,
                child: Text(
                  _resendAfter > 0
                      ? context.l10n.pinResetResendIn(_resendAfter)
                      : context.l10n.pinResetResend,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pinFields() {
    final digits = _activeResetPinDigits;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
        child: Column(
          children: [
            Text(
              _confirmingResetPin
                  ? context.l10n.pinResetConfirmPinLabel
                  : context.l10n.pinResetNewPinLabel,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              _pinDots(digits.length),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    letterSpacing: 4,
                    fontWeight: FontWeight.w900,
                  ),
              semanticsLabel: context.l10n.pinResetPinRequired,
            ),
            const SizedBox(height: 8),
            Text(
              _confirmingResetPin
                  ? context.l10n.pinResetDescriptionConfirmPin
                  : context.l10n.pinResetDescriptionPin,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 14),
            _Keypad(onDigit: _resetPinDigit, onBackspace: _resetPinBackspace),
            if (_submitting) ...[
              const SizedBox(height: 8),
              const SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _doneCard(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline),
            const SizedBox(width: 12),
            Expanded(child: Text(context.l10n.pinResetDoneMessage)),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    final resetFailed = context.l10n.pinResetFailed;
    try {
      if (_step == _PinResetStep.request) {
        await _requestOtp();
      } else if (_step == _PinResetStep.otp) {
        final verified = await ref
            .read(authRepositoryProvider)
            .verifyPinResetOtp(otp: _otp.text);
        setState(() {
          _otpToken = verified.verificationToken;
          _pin.clear();
          _pinConfirmation.clear();
          _confirmingResetPin = false;
          _step = _PinResetStep.pin;
        });
      } else if (_step == _PinResetStep.pin) {
        await _submitConfirmedResetPin();
      }
    } catch (error) {
      if (!mounted) return;
      final message = _errorMessage(error, resetFailed);
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

  Future<void> _requestOtp() async {
    setState(() => _submitting = true);
    try {
      final result =
          await ref.read(authRepositoryProvider).requestPinResetOtp();
      _otp.clear();
      if (!mounted) return;
      setState(() {
        _maskedPhone = result.phoneMasked;
        _resendAfter = result.resendAfterSeconds;
        _pin.clear();
        _pinConfirmation.clear();
        _confirmingResetPin = false;
        _step = _PinResetStep.otp;
      });
      _startTimer();
    } catch (error) {
      if (!mounted) return;
      final message = _errorMessage(error, context.l10n.pinResetSendFailed);
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

  void _startTimer() {
    _timer?.cancel();
    if (_resendAfter <= 0) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _resendAfter <= 1) {
        timer.cancel();
        if (mounted) setState(() => _resendAfter = 0);
        return;
      }
      setState(() => _resendAfter -= 1);
    });
  }

  String _title(CustomerLocalizations l10n) {
    return switch (_step) {
      _PinResetStep.otp => l10n.pinResetTitleOtp,
      _PinResetStep.pin => _confirmingResetPin
          ? l10n.pinResetConfirmPinLabel
          : l10n.pinResetTitlePin,
      _PinResetStep.done => l10n.pinResetTitleDone,
      _ => l10n.pinResetTitleRequest,
    };
  }

  String _description(CustomerLocalizations l10n) {
    return switch (_step) {
      _PinResetStep.otp => l10n.pinResetDescriptionOtp,
      _PinResetStep.pin => _confirmingResetPin
          ? l10n.pinResetDescriptionConfirmPin
          : l10n.pinResetDescriptionPin,
      _PinResetStep.done => l10n.pinResetDescriptionDone,
      _ => l10n.pinResetDescriptionRequest,
    };
  }

  String _buttonLabel(CustomerLocalizations l10n) {
    return switch (_step) {
      _PinResetStep.otp => l10n.pinResetSubmitOtp,
      _PinResetStep.pin => l10n.pinResetSavePin,
      _ => l10n.pinResetSendOtp,
    };
  }

  String? _otpValidator(String? value) {
    if (_step != _PinResetStep.otp) return null;
    if (!RegExp(r'^\d{6}$').hasMatch(value ?? '')) {
      return context.l10n.pinResetOtpRequired;
    }
    return null;
  }

  String get _activeResetPinDigits =>
      _confirmingResetPin ? _pinConfirmation.text : _pin.text;

  void _setActiveResetPinDigits(String value) {
    if (_confirmingResetPin) {
      _pinConfirmation.text = value;
    } else {
      _pin.text = value;
    }
  }

  void _resetPinDigit(String digit) {
    if (_submitting || _step != _PinResetStep.pin) return;
    final current = _activeResetPinDigits;
    if (current.length >= 6) return;
    final next = '$current$digit';
    setState(() => _setActiveResetPinDigits(next));
    if (next.length == 6) _handleResetPinComplete();
  }

  void _resetPinBackspace() {
    if (_submitting || _step != _PinResetStep.pin) return;
    final current = _activeResetPinDigits;
    if (current.isEmpty) return;
    setState(() {
      _setActiveResetPinDigits(current.substring(0, current.length - 1));
    });
  }

  void _handleResetPinComplete() {
    if (!_confirmingResetPin) {
      setState(() {
        _confirmingResetPin = true;
        _pinConfirmation.clear();
      });
      return;
    }

    if (_pin.text != _pinConfirmation.text) {
      setState(() {
        _pin.clear();
        _pinConfirmation.clear();
        _confirmingResetPin = false;
      });
      _showSnack(context.l10n.pinResetPinMismatch);
      return;
    }

    unawaited(_submitConfirmedResetPin());
  }

  Future<void> _submitConfirmedResetPin() async {
    if (_submitting ||
        !RegExp(r'^\d{6}$').hasMatch(_pin.text) ||
        _pinConfirmation.text != _pin.text) {
      _showSnack(context.l10n.pinResetPinRequired);
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref.read(authControllerProvider).confirmPinResetWithOtp(
            otpVerificationToken: _otpToken,
            pin: _pin.text,
            pinConfirmation: _pinConfirmation.text,
          );
      if (!mounted) return;
      setState(() => _step = _PinResetStep.done);
    } catch (error) {
      if (!mounted) return;
      final message = _errorMessage(error, context.l10n.pinResetFailed);
      if (await handleCustomerOperationalError(
        ref: ref,
        context: context,
        error: error,
      )) {
        return;
      }
      setState(() {
        _pin.clear();
        _pinConfirmation.clear();
        _confirmingResetPin = false;
      });
      _showSnack(message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _errorMessage(Object error, String fallback) {
    final info = ApiErrorInfo.fromObject(error);
    if (info.isSmsOtpProviderNotConfigured) {
      return context.l10n.pinResetOtpProviderUnavailable;
    }
    if (info.message.trim().isNotEmpty) return info.message;
    return fallback;
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

String _pinDots(int length) => '${'●' * length}${'○' * (6 - length)}';

class _PinIndicator extends StatelessWidget {
  const _PinIndicator({required this.length});

  final int length;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      label: _pinDots(length),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var index = 0; index < 6; index++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOutCubic,
              width: index < length ? 16 : 12,
              height: index < length ? 16 : 12,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: index < length
                    ? colorScheme.primary
                    : colorScheme.surfaceContainerHighest,
                border: Border.all(
                  color: index < length
                      ? colorScheme.primary
                      : colorScheme.outlineVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({
    required this.onDigit,
    required this.onBackspace,
    this.enabled = true,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', 'back'];
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 330),
      child: GridView.count(
        shrinkWrap: true,
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.36,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (final key in keys)
            if (key.isEmpty)
              const SizedBox.shrink()
            else
              Semantics(
                button: true,
                label: key == 'back' ? context.l10n.commonBack : key,
                child: FilledButton.tonal(
                  onPressed: !enabled
                      ? null
                      : key == 'back'
                          ? onBackspace
                          : () => onDigit(key),
                  style: FilledButton.styleFrom(
                    shape: const CircleBorder(),
                    backgroundColor:
                        colorScheme.primaryContainer.withValues(alpha: 0.56),
                    foregroundColor: colorScheme.primary,
                    disabledBackgroundColor:
                        colorScheme.surfaceContainerHighest,
                    disabledForegroundColor: colorScheme.outline,
                    textStyle:
                        Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                  ),
                  child: key == 'back'
                      ? const Icon(Icons.backspace_outlined)
                      : Text(key),
                ),
              ),
        ],
      ),
    );
  }
}
