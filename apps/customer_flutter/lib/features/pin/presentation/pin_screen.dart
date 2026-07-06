import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/auth_error_message.dart';
import '../../../core/auth/auth_repository.dart';
import '../../../core/i18n/customer_localizations.dart';
import '../../../core/navigation/customer_redirect.dart';
import '../../../core/tenant/mobile_bootstrap_controller.dart';
import '../../../core/tenant/mobile_runtime_policy.dart';
import '../../../shared/utils/customer_operational_error.dart';

class PinScreen extends ConsumerStatefulWidget {
  const PinScreen({super.key});

  @override
  ConsumerState<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends ConsumerState<PinScreen> {
  final _focusNode = FocusNode(debugLabel: 'customer-pin-keypad');
  String _pin = '';
  String _setupPin = '';
  String _pinError = '';
  bool _confirmingSetupPin = false;
  bool _verifying = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
    Future.microtask(_syncPinStatus);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
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
    final brand = ref.watch(mobileBootstrapProvider).maybeWhen(
          data: (data) => data.siteName.trim(),
          orElse: () => '',
        );

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxHeight < 660;
              return Padding(
                padding: EdgeInsets.fromLTRB(
                  constraints.maxWidth <= 360 ? 22 : 28,
                  12,
                  constraints.maxWidth <= 360 ? 22 : 28,
                  22,
                ),
                child: Column(
                  children: [
                    _PinTopBar(
                      brand: brand,
                      disabled: _verifying,
                      onBack: _handleBack,
                    ),
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 430),
                          child: _PinMainContent(
                            title: _title(l10n, setupRequired),
                            subtitle: _description(l10n, setupRequired),
                            helper: _helper(l10n, setupRequired),
                            error: _pinError,
                            pinLength: _pin.length,
                            verifying: _verifying,
                            compact: compact,
                            showBiometric: !setupRequired && biometricEnabled,
                            onBiometric: _unlockWithBiometric,
                            showForgotPin: !setupRequired,
                            onForgotPin: _showResetPinSheet,
                          ),
                        ),
                      ),
                    ),
                    _Keypad(
                      onDigit: _digit,
                      onBackspace: _backspace,
                      enabled: !_verifying,
                      compact: compact,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent || _verifying) return;
    final value = event.character ?? event.logicalKey.keyLabel;
    if (RegExp(r'^\d$').hasMatch(value)) {
      _digit(value);
      return;
    }
    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      _backspace();
    }
  }

  Future<void> _handleBack() async {
    if (_verifying) return;
    if (ref.read(authControllerProvider).pinSetupRequired &&
        _confirmingSetupPin) {
      setState(() {
        _pin = '';
        _setupPin = '';
        _pinError = '';
        _confirmingSetupPin = false;
      });
      return;
    }

    final redirect = _safeRedirect();
    await ref.read(authControllerProvider).logout();
    if (!mounted) return;
    context.go('/login?redirect=${Uri.encodeComponent(redirect)}');
  }

  Future<void> _syncPinStatus() async {
    final auth = ref.read(authControllerProvider);
    if (!auth.isAuthenticated) return;
    try {
      await auth.syncPinStatus();
    } catch (error) {
      if (!mounted) return;
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
    if (_verifying) {
      return setupRequired ? l10n.pinSetupSubmitting : l10n.pinVerifying;
    }
    if (!setupRequired) return l10n.pinDescription;
    return _confirmingSetupPin
        ? l10n.pinSetupConfirmDescription
        : l10n.pinSetupDescription;
  }

  String _helper(CustomerLocalizations l10n, bool setupRequired) {
    if (_pinError.isNotEmpty) return _pinError;
    if (setupRequired && _confirmingSetupPin) {
      return l10n.pinSetupConfirmHelper;
    }
    return '';
  }

  void _digit(String digit) {
    if (_verifying || _pin.length >= 6 || !RegExp(r'^\d$').hasMatch(digit)) {
      return;
    }
    setState(() {
      _pin += digit;
      _pinError = '';
    });
    if (_pin.length == 6) {
      if (ref.read(authControllerProvider).pinSetupRequired) {
        _handleSetupPinDigitComplete();
      } else {
        unawaited(_verifyPin());
      }
    }
  }

  void _backspace() {
    if (_verifying || _pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _pinError = '';
    });
  }

  Future<void> _showResetPinSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      barrierColor: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.48),
      clipBehavior: Clip.antiAlias,
      constraints: const BoxConstraints(maxWidth: 430),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      showDragHandle: false,
      useSafeArea: true,
      builder: (_) => _PinResetSheet(onComplete: _goAfterPinUnlock),
    );
    if (mounted) _focusNode.requestFocus();
  }

  Future<void> _unlockWithBiometric() async {
    setState(() {
      _verifying = true;
      _pinError = '';
    });
    try {
      final unlocked =
          await ref.read(authControllerProvider).unlockWithBiometric(
                localizedReason: mobileBiometricPromptReason(
                  ref.read(mobileBootstrapProvider).valueOrNull,
                  purpose: 'pin_unlock',
                  fallback: context.l10n.pinBiometricReason,
                ),
              );
      if (!mounted) return;
      if (unlocked) {
        _goAfterPinUnlock();
        return;
      }
      setState(() => _pinError = context.l10n.pinBiometricUnavailable);
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
      setState(() => _pinError = failedMessage);
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  void _handleSetupPinDigitComplete() {
    if (!_confirmingSetupPin) {
      setState(() {
        _setupPin = _pin;
        _pin = '';
        _pinError = '';
        _confirmingSetupPin = true;
      });
      return;
    }

    if (_pin != _setupPin) {
      setState(() {
        _pin = '';
        _setupPin = '';
        _pinError = context.l10n.pinSetupMismatch;
        _confirmingSetupPin = false;
      });
      return;
    }

    unawaited(_setupNewPin());
  }

  Future<void> _setupNewPin() async {
    final redirect = _safeRedirect();
    setState(() => _verifying = true);
    try {
      await ref.read(authControllerProvider).setupPin(
            pin: _setupPin,
            pinConfirmation: _pin,
          );
      if (mounted) _goAfterPinUnlock(redirect);
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
        _pinError = message;
        _confirmingSetupPin = false;
      });
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _verifyPin() async {
    final redirect = _safeRedirect();
    final pin = _pin;
    setState(() => _verifying = true);
    try {
      await ref.read(authControllerProvider).verifyPin(pin);
      if (mounted) _goAfterPinUnlock(redirect);
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
      setState(() {
        _pin = '';
        _pinError = message;
      });
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  String _errorMessage(Object error, String fallback) {
    return authOtpErrorMessage(
      error: error,
      fallback: fallback,
      otpProviderUnavailable: context.l10n.pinResetOtpProviderUnavailable,
    );
  }

  String _safeRedirect() {
    try {
      return safeCustomerRedirect(
        GoRouterState.of(context).uri.queryParameters['redirect'],
      );
    } catch (_) {
      return '/';
    }
  }

  void _goAfterPinUnlock([String? redirect]) {
    try {
      context.go(redirect ?? _safeRedirect());
    } catch (_) {
      // Tests can mount PinScreen without a GoRouter. In the real app this
      // path is always routed, so navigation resumes the original flow.
    }
  }
}

class _PinTopBar extends StatelessWidget {
  const _PinTopBar({
    required this.brand,
    required this.disabled,
    required this.onBack,
  });

  final String brand;
  final bool disabled;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 430),
      child: SizedBox(
        height: 42,
        child: Row(
          children: [
            SizedBox(
              width: 42,
              child: IconButton(
                alignment: Alignment.centerLeft,
                padding: EdgeInsets.zero,
                tooltip: context.l10n.commonBack,
                onPressed: disabled ? null : onBack,
                icon: const Icon(Icons.chevron_left, size: 30),
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            Expanded(
              child: Text(
                brand,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
              ),
            ),
            const SizedBox(width: 42),
          ],
        ),
      ),
    );
  }
}

class _PinMainContent extends StatelessWidget {
  const _PinMainContent({
    required this.title,
    required this.subtitle,
    required this.helper,
    required this.error,
    required this.pinLength,
    required this.verifying,
    required this.compact,
    required this.showBiometric,
    required this.onBiometric,
    required this.showForgotPin,
    required this.onForgotPin,
  });

  final String title;
  final String subtitle;
  final String helper;
  final String error;
  final int pinLength;
  final bool verifying;
  final bool compact;
  final bool showBiometric;
  final VoidCallback onBiometric;
  final bool showForgotPin;
  final VoidCallback onForgotPin;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final message = error.isNotEmpty ? error : helper;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: colorScheme.onSurface,
                fontSize: compact ? 26 : 30,
                fontWeight: FontWeight.w900,
                height: 1.2,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontSize: compact ? 17 : 20,
                fontWeight: FontWeight.w800,
                height: 1.35,
              ),
        ),
        SizedBox(height: compact ? 20 : 30),
        _PinIndicator(length: pinLength, hasError: error.isNotEmpty),
        AnimatedOpacity(
          opacity: message.isEmpty ? 0 : 1,
          duration: const Duration(milliseconds: 120),
          child: Container(
            constraints: BoxConstraints(
              minHeight: compact ? 22 : 30,
              maxWidth: 260,
            ),
            alignment: Alignment.center,
            margin: EdgeInsets.only(top: compact ? 10 : 14),
            child: Text(
              message.isEmpty ? ' ' : message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: error.isNotEmpty
                        ? colorScheme.error
                        : colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                  ),
            ),
          ),
        ),
        if (verifying) ...[
          const SizedBox(height: 10),
          const _PinProgressLine(
            key: Key('pin-verifying-progress'),
            width: 140,
          ),
        ],
        if (showBiometric) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: verifying ? null : onBiometric,
            icon: const Icon(Icons.face_retouching_natural),
            label: Text(context.l10n.pinUseBiometric),
          ),
        ],
        if (showForgotPin)
          TextButton(
            onPressed: verifying ? null : onForgotPin,
            style: TextButton.styleFrom(
              minimumSize: const Size(64, 32),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            child: Text(context.l10n.pinForgot),
          ),
      ],
    );
  }
}

enum _PinResetStep { request, otp, pin, done }

class _PinResetSheet extends ConsumerStatefulWidget {
  const _PinResetSheet({required this.onComplete});

  final VoidCallback onComplete;

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
  String _resetError = '';
  int _resendAfter = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _otp.addListener(_clearResetError);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otp.removeListener(_clearResetError);
    _otp.dispose();
    _pin.dispose();
    _pinConfirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.96,
        minChildSize: 0.60,
        maxChildSize: 0.98,
        builder: (context, scrollController) {
          return DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: Form(
              key: _formKey,
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      onPressed: _submitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      color: colorScheme.onSurfaceVariant,
                      tooltip:
                          MaterialLocalizations.of(context).closeButtonTooltip,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.10,
                        ),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Icon(
                        Icons.shield_outlined,
                        color: theme.colorScheme.primary,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _title(l10n),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: colorScheme.onSurface,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _description(l10n),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      height: 1.5,
                    ),
                  ),
                  if (_resetError.trim().isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _PinResetErrorPanel(message: _resetError),
                  ],
                  const SizedBox(height: 22),
                  if (_step == _PinResetStep.request) _requestCard(context),
                  if (_step == _PinResetStep.otp) _otpCard(context),
                  if (_step == _PinResetStep.pin) _pinFields(),
                  if (_step == _PinResetStep.done) _doneCard(context),
                  const SizedBox(height: 20),
                  if (_step != _PinResetStep.done && _step != _PinResetStep.pin)
                    FilledButton(
                      onPressed: _submitting ? null : _submit,
                      style: _primaryResetButtonStyle(context),
                      child: Text(
                        _submitting ? l10n.pinVerifying : _buttonLabel(l10n),
                      ),
                    )
                  else if (_step == _PinResetStep.done)
                    FilledButton(
                      onPressed: _finishReset,
                      style: _primaryResetButtonStyle(context),
                      child: Text(l10n.pinResetBackToApp),
                    ),
                  if (_step == _PinResetStep.otp) ...[
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: _resendAfter > 0 || _submitting
                          ? null
                          : _requestOtpFromResend,
                      style: _secondaryResetButtonStyle(context),
                      child: Text(
                        _resendAfter > 0
                            ? l10n.pinResetResendIn(_resendAfter)
                            : l10n.pinResetResend,
                      ),
                    ),
                    TextButton(
                      onPressed: _submitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      style: _secondaryResetButtonStyle(context),
                      child: Text(l10n.pinResetBackToPin),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _resetPanel(
    BuildContext context, {
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
    Color? backgroundColor,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor ??
            colorScheme.surfaceContainerHighest.withValues(alpha: 0.34),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.88),
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Padding(padding: padding, child: child),
    );
  }

  ButtonStyle _primaryResetButtonStyle(BuildContext context) {
    return FilledButton.styleFrom(
      elevation: 0,
      minimumSize: const Size.fromHeight(52),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      shape: const StadiumBorder(),
      textStyle: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
    );
  }

  ButtonStyle _secondaryResetButtonStyle(BuildContext context) {
    return TextButton.styleFrom(
      minimumSize: const Size.fromHeight(52),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      foregroundColor: Theme.of(context).colorScheme.primary,
      shape: const StadiumBorder(),
      textStyle: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
    );
  }

  InputDecoration _otpInputDecoration(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final borderColor = colorScheme.outlineVariant.withValues(alpha: 0.9);
    final focusedColor = colorScheme.primary;
    return InputDecoration(
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.36),
      labelText: context.l10n.pinResetOtpLabel,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: focusedColor, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
      ),
    );
  }

  Widget _loadingCopy(BuildContext context) {
    return Text(
      context.l10n.pinVerifying,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w900,
          ),
    );
  }

  Widget _pinDotRow(int length) {
    final colorScheme = Theme.of(context).colorScheme;
    final primary = colorScheme.primary;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(6, (index) {
        final filled = index < length;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.symmetric(horizontal: 5),
          width: filled ? 13 : 12,
          height: filled ? 13 : 12,
          decoration: BoxDecoration(
            color: filled ? primary : colorScheme.surface,
            shape: BoxShape.circle,
            border: Border.all(
              color: filled
                  ? primary
                  : colorScheme.outlineVariant.withValues(alpha: 0.9),
              width: 1.5,
            ),
          ),
        );
      }),
    );
  }

  Widget _requestCard(BuildContext context) {
    return _resetPanel(
      context,
      child: Padding(
        padding: EdgeInsets.zero,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.sms_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                context.l10n.pinResetRequestInfo,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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

  Widget _otpCard(BuildContext context) {
    return _resetPanel(
      context,
      child: Padding(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.pinResetOtpSentTo(
                _maskedPhone.isEmpty
                    ? context.l10n.accountPhoneFallback
                    : _maskedPhone,
              ),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                    height: 1.45,
                  ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _otp,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              decoration: _otpInputDecoration(context),
              validator: _otpValidator,
            ),
          ],
        ),
      ),
    );
  }

  Widget _pinFields() {
    final digits = _activeResetPinDigits;
    return _resetPanel(
      context,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          Text(
            _confirmingResetPin
                ? context.l10n.pinResetConfirmPinLabel
                : context.l10n.pinResetNewPinLabel,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w900,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          Semantics(
            label: _pinDots(digits.length),
            child: _pinDotRow(digits.length),
          ),
          const SizedBox(height: 12),
          Text(
            _confirmingResetPin
                ? context.l10n.pinResetDescriptionConfirmPin
                : context.l10n.pinResetDescriptionPin,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 10),
          _Keypad(
            onDigit: _resetPinDigit,
            onBackspace: _resetPinBackspace,
            compact: true,
          ),
          if (_submitting) ...[
            const SizedBox(height: 8),
            _loadingCopy(context),
            const SizedBox(height: 8),
            const _PinProgressLine(width: 118),
          ],
        ],
      ),
    );
  }

  Widget _doneCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return _resetPanel(
      context,
      backgroundColor: colorScheme.primary.withValues(alpha: 0.08),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.l10n.pinResetDoneMessage,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                    height: 1.45,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _resetError = '';
      _submitting = true;
    });
    final resetFailed = context.l10n.pinResetFailed;
    try {
      if (_step == _PinResetStep.request) {
        await _requestOtp();
      } else if (_step == _PinResetStep.otp) {
        final otpVerificationFailed = context.l10n.authOtpVerificationFailed;
        final verified = await ref
            .read(authRepositoryProvider)
            .verifyPinResetOtp(otp: _otp.text);
        final verificationToken = verified.verificationToken.trim();
        if (verificationToken.isEmpty) {
          _showResetError(otpVerificationFailed);
          return;
        }
        setState(() {
          _otpToken = verificationToken;
          _pin.clear();
          _pinConfirmation.clear();
          _confirmingResetPin = false;
          _resetError = '';
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
      _showResetError(message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _requestOtp() async {
    setState(() {
      _resetError = '';
      _submitting = true;
    });
    try {
      final result =
          await ref.read(authRepositoryProvider).requestPinResetOtp();
      _otp.clear();
      if (!mounted) return;
      setState(() {
        _maskedPhone = result.phoneMasked;
        _resendAfter =
            result.resendAfterSeconds > 0 ? result.resendAfterSeconds : 60;
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
      _showResetError(message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _requestOtpFromResend() async {
    await _requestOtp();
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
    setState(() {
      _resetError = '';
      _setActiveResetPinDigits(next);
    });
    if (next.length == 6) _handleResetPinComplete();
  }

  void _resetPinBackspace() {
    if (_submitting || _step != _PinResetStep.pin) return;
    final current = _activeResetPinDigits;
    if (current.isEmpty) return;
    setState(() {
      _resetError = '';
      _setActiveResetPinDigits(current.substring(0, current.length - 1));
    });
  }

  void _handleResetPinComplete() {
    if (!_confirmingResetPin) {
      setState(() {
        _confirmingResetPin = true;
        _pinConfirmation.clear();
        _resetError = '';
      });
      return;
    }

    if (_pin.text != _pinConfirmation.text) {
      setState(() {
        _pin.clear();
        _pinConfirmation.clear();
        _confirmingResetPin = false;
        _resetError = context.l10n.pinResetPinMismatch;
      });
      return;
    }

    unawaited(_submitConfirmedResetPin());
  }

  Future<void> _submitConfirmedResetPin() async {
    if (_submitting ||
        !RegExp(r'^\d{6}$').hasMatch(_pin.text) ||
        _pinConfirmation.text != _pin.text) {
      _showResetError(context.l10n.pinResetPinRequired);
      return;
    }

    setState(() {
      _resetError = '';
      _submitting = true;
    });
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
        _resetError = message;
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _errorMessage(Object error, String fallback) {
    return authOtpErrorMessage(
      error: error,
      fallback: fallback,
      otpProviderUnavailable: context.l10n.pinResetOtpProviderUnavailable,
    );
  }

  void _clearResetError() {
    if (_resetError.isEmpty || !mounted || _submitting) return;
    setState(() => _resetError = '');
  }

  void _showResetError(String message) {
    if (!mounted) return;
    final normalized = message.trim();
    if (normalized.isEmpty) return;
    setState(() => _resetError = normalized);
  }

  void _finishReset() {
    Navigator.of(context).pop();
    widget.onComplete();
  }
}

class _PinResetErrorPanel extends StatelessWidget {
  const _PinResetErrorPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.errorContainer.withValues(alpha: 0.62),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.error.withValues(alpha: 0.14),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline, color: colorScheme.error, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.error,
                        fontWeight: FontWeight.w800,
                        height: 1.35,
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

String _pinDots(int length) => '${'●' * length}${'○' * (6 - length)}';

class _PinProgressLine extends StatelessWidget {
  const _PinProgressLine({
    super.key,
    this.width = 132,
  });

  final double width;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: width,
      height: 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.10),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: 0.48,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.primary,
                      Color.lerp(
                            colorScheme.primary,
                            colorScheme.secondary,
                            0.34,
                          ) ??
                          colorScheme.primary,
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

class _PinIndicator extends StatelessWidget {
  const _PinIndicator({required this.length, required this.hasError});

  final int length;
  final bool hasError;

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
              key: ValueKey(
                'pin-dot-$index-${index < length ? 'active' : 'empty'}',
              ),
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOutCubic,
              width: 9,
              height: 9,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: index < length
                    ? hasError
                        ? colorScheme.error.withValues(alpha: 0.32)
                        : colorScheme.onSurface
                    : colorScheme.outlineVariant,
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
    this.compact = false,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final bool enabled;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', 'back'];
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: GridView.count(
        shrinkWrap: true,
        crossAxisCount: 3,
        mainAxisSpacing: compact ? 17 : 24,
        crossAxisSpacing: compact ? 24 : 30,
        childAspectRatio: compact ? 1.5 : 1.75,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (final key in keys)
            if (key.isEmpty)
              const SizedBox.shrink()
            else
              Semantics(
                button: true,
                label: key == 'back' ? context.l10n.commonBack : key,
                child: TextButton(
                  onPressed: !enabled
                      ? null
                      : key == 'back'
                          ? onBackspace
                          : () => onDigit(key),
                  style: TextButton.styleFrom(
                    foregroundColor: key == 'back'
                        ? colorScheme.onSurfaceVariant
                        : colorScheme.onSurface,
                    disabledForegroundColor:
                        colorScheme.onSurface.withValues(alpha: 0.42),
                    minimumSize: Size(54, compact ? 36 : 43),
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                  ),
                  child: key == 'back'
                      ? const Icon(Icons.backspace_outlined, size: 20)
                      : Text(key),
                ),
              ),
        ],
      ),
    );
  }
}
