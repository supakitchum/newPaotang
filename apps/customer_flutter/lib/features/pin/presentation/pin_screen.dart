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
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/api_errors.dart';
import '../../../shared/utils/customer_operational_error.dart';
import '../../../shared/widgets/pin_confirmation_step.dart';

const _pinInk = Color(0xFF2F3337);
const _pinMuted = Color(0xFF9AA0A6);
const _pinBack = Color(0xFF8B9299);
const _pinBrand = Color(0xFF8487F8);
const _pinErrorColor = Color(0xFFD3455B);
const _pinDotEmpty = Color(0xFFDDDDDF);
const _pinDotError = Color(0xFFF2B6BD);
const _automaticBiometricPromptDelay = Duration(seconds: 2);
const _automaticBiometricRetryDelay = Duration(milliseconds: 650);
const _automaticBiometricMaxEligibilityChecks = 3;

Color _pinActionColor(BuildContext context) =>
    AppTheme.pinAction(Theme.of(context).colorScheme.primary);

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
  bool _resettingPin = false;
  bool _pinStatusChecked = false;
  bool _autoBiometricScheduled = false;
  bool _autoBiometricAttempted = false;
  bool _autoBiometricEligibilityCheckInFlight = false;
  int _autoBiometricEligibilityChecks = 0;
  Timer? _autoBiometricTimer;

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
    _autoBiometricTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final auth = ref.watch(authControllerProvider);
    final setupRequired = auth.pinSetupRequired;
    final platformKey = ref.watch(customerPlatformKeyProvider);
    final bootstrap = ref.watch(mobileBootstrapProvider);
    final biometricEnabled = bootstrap.maybeWhen(
      data: (data) => mobileBiometricAllowedForPlatform(data, platformKey),
      orElse: () => false,
    );
    final brand = customerPinBrandLabel(context, bootstrap.valueOrNull);
    _scheduleAutomaticBiometricUnlock(
      enabled:
          _pinStatusChecked &&
          auth.isAuthenticated &&
          auth.pinRequired &&
          !setupRequired &&
          biometricEnabled,
    );

    if (_resettingPin) {
      return _PinResetScreen(
        brand: brand,
        onBack: _closePinReset,
        onComplete: _completePinReset,
      );
    }

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
              final horizontal = constraints.maxWidth <= 360 ? 22.0 : 28.0;
              final mainVerticalPadding = (constraints.maxHeight * 0.05)
                  .clamp(10.0, 58.0)
                  .toDouble();
              return Padding(
                key: const ValueKey('pin-screen-frame'),
                padding: EdgeInsets.fromLTRB(horizontal, 12, horizontal, 22),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.topCenter,
                      child: _PinTopBar(brand: brand),
                    ),
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 430),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: mainVerticalPadding,
                            ),
                            child: Center(
                              child: _PinMainContent(
                                title: _title(l10n, setupRequired),
                                subtitle: _description(l10n, setupRequired),
                                helper: _helper(l10n, setupRequired),
                                error: _pinError,
                                pinLength: _pin.length,
                                verifying: _verifying,
                                compact: compact,
                                showBiometric:
                                    !setupRequired && biometricEnabled,
                                onBiometric: _requestManualBiometricUnlock,
                                showForgotPin: !setupRequired,
                                onForgotPin: _startPinReset,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: _Keypad(
                        pinLength: _pin.length,
                        onDigit: _digit,
                        onBackspace: _backspace,
                        enabled: !_verifying,
                        compact: compact,
                      ),
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

  Future<void> _syncPinStatus() async {
    final auth = ref.read(authControllerProvider);
    if (!auth.isAuthenticated) {
      _markPinStatusChecked();
      return;
    }
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
    } finally {
      _markPinStatusChecked();
    }
  }

  void _markPinStatusChecked() {
    if (mounted && !_pinStatusChecked) {
      setState(() => _pinStatusChecked = true);
    }
  }

  void _scheduleAutomaticBiometricUnlock({required bool enabled}) {
    if (!enabled ||
        _autoBiometricScheduled ||
        _autoBiometricAttempted ||
        _resettingPin ||
        _verifying) {
      return;
    }
    _autoBiometricScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _autoBiometricTimer = Timer(_automaticBiometricPromptDelay, () {
        _autoBiometricTimer = null;
        if (mounted) unawaited(_tryAutomaticBiometricUnlock());
      });
    });
  }

  Future<void> _tryAutomaticBiometricUnlock() async {
    if (_autoBiometricAttempted || _autoBiometricEligibilityCheckInFlight) {
      return;
    }
    final auth = ref.read(authControllerProvider);
    if (!_automaticBiometricContextReady(auth)) return;

    _autoBiometricEligibilityCheckInFlight = true;
    var canUnlock = false;
    try {
      canUnlock = await auth.canUnlockWithBiometric();
    } catch (_) {
      canUnlock = false;
    } finally {
      _autoBiometricEligibilityCheckInFlight = false;
    }
    if (!mounted || _autoBiometricAttempted) return;
    _autoBiometricEligibilityChecks += 1;
    if (!_automaticBiometricContextReady(auth)) return;

    if (!canUnlock) {
      if (_autoBiometricEligibilityChecks <
          _automaticBiometricMaxEligibilityChecks) {
        _autoBiometricTimer = Timer(_automaticBiometricRetryDelay, () {
          _autoBiometricTimer = null;
          if (mounted) unawaited(_tryAutomaticBiometricUnlock());
        });
      } else {
        _autoBiometricAttempted = true;
      }
      return;
    }

    _autoBiometricAttempted = true;
    await _unlockWithBiometric(showFailure: false);
  }

  bool _automaticBiometricContextReady(AuthController auth) {
    return mounted &&
        auth.isAuthenticated &&
        auth.pinRequired &&
        !auth.pinSetupRequired &&
        !_resettingPin &&
        !_verifying &&
        _pin.isEmpty;
  }

  void _requestManualBiometricUnlock() {
    _cancelAutomaticBiometricUnlock();
    unawaited(_unlockWithBiometric());
  }

  void _cancelAutomaticBiometricUnlock() {
    _autoBiometricTimer?.cancel();
    _autoBiometricTimer = null;
    _autoBiometricAttempted = true;
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
    if (_pin.isEmpty) _cancelAutomaticBiometricUnlock();
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

  void _startPinReset() {
    if (_verifying) return;
    _cancelAutomaticBiometricUnlock();
    setState(() {
      _pin = '';
      _pinError = '';
      _resettingPin = true;
    });
  }

  void _closePinReset() {
    if (!_resettingPin) return;
    setState(() => _resettingPin = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _completePinReset() {
    if (mounted) setState(() => _resettingPin = false);
    _goAfterPinUnlock();
  }

  Future<void> _unlockWithBiometric({bool showFailure = true}) async {
    if (_verifying) return;
    setState(() {
      _verifying = true;
      _pinError = '';
    });
    try {
      final unlocked = await ref
          .read(authControllerProvider)
          .unlockWithBiometric(
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
      if (showFailure) {
        setState(() => _pinError = context.l10n.pinBiometricUnavailable);
      }
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
      if (showFailure) {
        setState(() => _pinError = failedMessage);
      }
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
      await ref
          .read(authControllerProvider)
          .setupPin(pin: _setupPin, pinConfirmation: _pin);
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
  const _PinTopBar({required this.brand});

  final String brand;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      key: const ValueKey('pin-topbar'),
      constraints: const BoxConstraints(maxWidth: 430),
      child: SizedBox(
        height: 42,
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              brand,
              maxLines: 1,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: _pinBrand,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ),
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
    final message = error.isNotEmpty ? error : helper;
    final height = MediaQuery.sizeOf(context).height;
    final dotGap = (height * 0.05).clamp(21.0, 34.0).toDouble();
    final messageTop = (height * 0.03).clamp(12.0, 17.0).toDouble();
    final messageMinHeight = compact
        ? 18.0
        : (height * 0.04).clamp(18.0, 33.0).toDouble();
    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: _pinInk,
            fontSize: 30,
            fontWeight: FontWeight.w900,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: _pinMuted,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            height: 1.35,
          ),
        ),
        SizedBox(height: dotGap),
        _PinIndicator(length: pinLength, hasError: error.isNotEmpty),
        AnimatedOpacity(
          opacity: message.isEmpty ? 0 : 1,
          duration: const Duration(milliseconds: 120),
          child: Container(
            constraints: BoxConstraints(
              minHeight: messageMinHeight,
              maxWidth: 260,
            ),
            alignment: Alignment.center,
            margin: EdgeInsets.only(top: messageTop),
            child: Text(
              message.isEmpty ? ' ' : message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _pinErrorColor,
                fontSize: 12,
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
          const SizedBox(height: 4),
          SizedBox(
            height: 32,
            child: Center(
              child: TextButton.icon(
                onPressed: verifying ? null : onBiometric,
                icon: const Icon(Icons.face_retouching_natural, size: 18),
                label: Text(context.l10n.pinUseBiometric),
                style:
                    TextButton.styleFrom(
                      foregroundColor: _pinActionColor(context),
                      minimumSize: const Size(64, 32),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: Theme.of(context).textTheme.labelLarge
                          ?.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                    ).copyWith(
                      overlayColor: const WidgetStatePropertyAll(
                        Colors.transparent,
                      ),
                    ),
              ),
            ),
          ),
        ],
        if (showForgotPin)
          SizedBox(
            height: 32,
            child: Center(
              child: TextButton(
                onPressed: verifying ? null : onForgotPin,
                style:
                    TextButton.styleFrom(
                      foregroundColor: _pinActionColor(context),
                      minimumSize: const Size(64, 32),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: Theme.of(context).textTheme.labelLarge
                          ?.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                    ).copyWith(
                      overlayColor: const WidgetStatePropertyAll(
                        Colors.transparent,
                      ),
                    ),
                child: Text(context.l10n.pinForgot),
              ),
            ),
          ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedHeight || constraints.maxHeight.isInfinite) {
          return content;
        }
        final contentWidth =
            constraints.hasBoundedWidth && constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 430.0;
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          child: SizedBox(width: contentWidth, child: content),
        );
      },
    );
  }
}

enum _PinResetStep { request, otp, pin }

class _PinResetScreen extends ConsumerStatefulWidget {
  const _PinResetScreen({
    required this.brand,
    required this.onBack,
    required this.onComplete,
  });

  final String brand;
  final VoidCallback onBack;
  final VoidCallback onComplete;

  @override
  ConsumerState<_PinResetScreen> createState() => _PinResetScreenState();
}

class _PinResetScreenState extends ConsumerState<_PinResetScreen> {
  final _otp = TextEditingController();
  final _pin = TextEditingController();
  final _pinConfirmation = TextEditingController();
  final _keypadFocusNode = FocusNode(debugLabel: 'pin-reset-keypad');

  _PinResetStep _step = _PinResetStep.request;
  bool _confirmingResetPin = false;
  bool _submitting = false;
  String _otpToken = '';
  String _resetError = '';
  int _resendAfter = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _otp.addListener(_handleOtpChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_requestOtp());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otp.removeListener(_handleOtpChanged);
    _otp.dispose();
    _pin.dispose();
    _pinConfirmation.dispose();
    _keypadFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_step == _PinResetStep.pin) return _buildPinScreen(context);
    return _buildOtpScreen(context);
  }

  Widget _buildOtpScreen(BuildContext context) {
    final l10n = context.l10n;
    final width = MediaQuery.sizeOf(context).width;
    final horizontal = width <= 360 ? 22.0 : 28.0;
    final canSubmit =
        _step == _PinResetStep.otp &&
        !_submitting &&
        RegExp(r'^\d{6}$').hasMatch(_otp.text);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Padding(
          key: const ValueKey('pin-reset-screen'),
          padding: EdgeInsets.fromLTRB(horizontal, 12, horizontal, 24),
          child: Column(
            children: [
              _PinResetTopBar(
                brand: widget.brand,
                enabled: !_submitting,
                onBack: _handleBack,
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final vertical = (constraints.maxHeight * 0.08)
                        .clamp(18.0, 58.0)
                        .toDouble();
                    final minHeight = (constraints.maxHeight - vertical * 2)
                        .clamp(0.0, double.infinity);
                    return SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.symmetric(vertical: vertical),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: minHeight),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 390),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Center(
                                  child: Container(
                                    width: 64,
                                    height: 64,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: AppTheme.pinActionFill(
                                        Theme.of(context).colorScheme.primary,
                                      ),
                                      borderRadius: BorderRadius.circular(22),
                                    ),
                                    child: Icon(
                                      Icons.shield_outlined,
                                      color: _pinActionColor(context),
                                      size: 28,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  l10n.pinResetScreenTitle,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(
                                        color: _pinInk,
                                        fontSize: 30,
                                        fontWeight: FontWeight.w900,
                                        height: 1.18,
                                      ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  l10n.pinResetScreenDescription,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: const Color(0xFF8A929D),
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        height: 1.5,
                                      ),
                                ),
                                const SizedBox(height: 22),
                                Text(
                                  l10n.pinResetOtpLabel,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: _pinInk,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                      ),
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  height: 54,
                                  child: TextField(
                                    key: const ValueKey('pin-reset-otp-input'),
                                    controller: _otp,
                                    enabled:
                                        _step == _PinResetStep.otp &&
                                        !_submitting,
                                    autofocus: _step == _PinResetStep.otp,
                                    autofillHints: const [
                                      AutofillHints.oneTimeCode,
                                    ],
                                    enableSuggestions: false,
                                    keyboardType: TextInputType.number,
                                    textInputAction: TextInputAction.done,
                                    onSubmitted: (_) {
                                      if (canSubmit) unawaited(_verifyOtp());
                                    },
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(6),
                                    ],
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          color: const Color(0xFF172B4D),
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                        ),
                                    decoration: _otpInputDecoration(context),
                                  ),
                                ),
                                Semantics(
                                  liveRegion: true,
                                  child: AnimatedOpacity(
                                    opacity: _resetError.isEmpty ? 0 : 1,
                                    duration: const Duration(milliseconds: 120),
                                    child: Container(
                                      constraints: const BoxConstraints(
                                        minHeight: 18,
                                      ),
                                      alignment: Alignment.center,
                                      padding: const EdgeInsets.only(top: 3),
                                      child: Text(
                                        _resetError.isEmpty ? ' ' : _resetError,
                                        textAlign: TextAlign.center,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: _pinErrorColor,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                              height: 1.35,
                                            ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                _PinResetPrimaryAction(
                                  key: const ValueKey(
                                    'pin-reset-primary-action',
                                  ),
                                  label: _submitting
                                      ? l10n.pinVerifying
                                      : l10n.pinResetSubmitOtp,
                                  enabled: canSubmit,
                                  onPressed: _verifyOtp,
                                ),
                                const SizedBox(height: 10),
                                _PinResetTextAction(
                                  key: const ValueKey('pin-reset-resend'),
                                  label: _resendAfter > 0
                                      ? l10n.pinResetResendIn(_resendAfter)
                                      : l10n.pinResetResend,
                                  enabled: !_submitting && _resendAfter <= 0,
                                  onPressed: _requestOtp,
                                ),
                                const SizedBox(height: 10),
                                _PinResetTextAction(
                                  key: const ValueKey('pin-reset-back-to-pin'),
                                  label: l10n.pinResetBackToPin,
                                  enabled: !_submitting,
                                  onPressed: widget.onBack,
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPinScreen(BuildContext context) {
    final l10n = context.l10n;
    final digits = _activeResetPinDigits;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: KeyboardListener(
        focusNode: _keypadFocusNode,
        autofocus: true,
        onKeyEvent: _handlePinKeyEvent,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxHeight < 660;
              final horizontal = constraints.maxWidth <= 360 ? 22.0 : 28.0;
              final mainVerticalPadding = (constraints.maxHeight * 0.05)
                  .clamp(10.0, 58.0)
                  .toDouble();
              return Padding(
                key: const ValueKey('pin-reset-keypad-screen'),
                padding: EdgeInsets.fromLTRB(horizontal, 12, horizontal, 22),
                child: Column(
                  children: [
                    _PinResetTopBar(
                      brand: widget.brand,
                      enabled: !_submitting,
                      onBack: _handleBack,
                    ),
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 430),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: mainVerticalPadding,
                            ),
                            child: Center(
                              child: _PinMainContent(
                                title: _confirmingResetPin
                                    ? l10n.pinResetConfirmPinLabel
                                    : l10n.pinResetTitlePin,
                                subtitle: _submitting
                                    ? l10n.pinSetupSubmitting
                                    : _confirmingResetPin
                                    ? l10n.pinResetDescriptionConfirmPin
                                    : l10n.pinResetDescriptionPin,
                                helper: _confirmingResetPin
                                    ? l10n.pinResetConfirmPinHelper
                                    : l10n.pinResetNewPinHelper,
                                error: _resetError,
                                pinLength: digits.length,
                                verifying: _submitting,
                                compact: compact,
                                showBiometric: false,
                                onBiometric: _noop,
                                showForgotPin: false,
                                onForgotPin: _noop,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: KeyedSubtree(
                        key: const ValueKey('pin-reset-keypad'),
                        child: _Keypad(
                          pinLength: digits.length,
                          onDigit: _resetPinDigit,
                          onBackspace: _resetPinBackspace,
                          enabled: !_submitting,
                          compact: compact,
                        ),
                      ),
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

  InputDecoration _otpInputDecoration(BuildContext context) {
    const borderColor = Color(0xFFDCE4EF);
    OutlineInputBorder border(Color color, [double width = 1]) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return InputDecoration(
      filled: true,
      fillColor: const Color(0xFFF6F8FB),
      hintText: context.l10n.pinResetOtpHint,
      hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: _pinMuted,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      enabledBorder: border(borderColor),
      disabledBorder: border(borderColor),
      focusedBorder: border(_pinActionColor(context), 1.4),
    );
  }

  Future<void> _requestOtp() async {
    if (_submitting) return;
    setState(() {
      _resetError = '';
      _submitting = true;
    });
    try {
      final result = await ref
          .read(authRepositoryProvider)
          .requestPinResetOtp();
      if (!mounted) return;
      _otp.clear();
      setState(() {
        _resendAfter = result.resendAfterSeconds > 0
            ? result.resendAfterSeconds
            : 60;
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
      setState(() {
        _step = _PinResetStep.otp;
        _resetError = message;
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _verifyOtp() async {
    if (_submitting || !RegExp(r'^\d{6}$').hasMatch(_otp.text)) {
      _showResetError(context.l10n.pinResetOtpRequired);
      return;
    }
    setState(() {
      _resetError = '';
      _submitting = true;
    });
    try {
      final verified = await ref
          .read(authRepositoryProvider)
          .verifyPinResetOtp(otp: _otp.text);
      final verificationToken = verified.verificationToken.trim();
      if (!mounted) return;
      if (verificationToken.isEmpty) {
        _showResetError(context.l10n.authOtpVerificationFailed);
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _keypadFocusNode.requestFocus();
      });
    } catch (error) {
      if (!mounted) return;
      final message = _errorMessage(
        error,
        context.l10n.authOtpVerificationFailed,
      );
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
    if (current.length >= 6 || !RegExp(r'^\d$').hasMatch(digit)) return;
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

  void _handlePinKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent || _submitting) return;
    final value = event.character ?? event.logicalKey.keyLabel;
    if (RegExp(r'^\d$').hasMatch(value)) {
      _resetPinDigit(value);
      return;
    }
    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      _resetPinBackspace();
    }
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
      await ref
          .read(authControllerProvider)
          .confirmPinResetWithOtp(
            otpVerificationToken: _otpToken,
            pin: _pin.text,
            pinConfirmation: _pinConfirmation.text,
          );
      if (!mounted) return;
      widget.onComplete();
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
      final code = ApiErrorInfo.fromObject(error).code;
      if (code == 'otp_invalid' || code == 'otp_required') {
        _otp.clear();
        setState(() {
          _otpToken = '';
          _pin.clear();
          _pinConfirmation.clear();
          _confirmingResetPin = false;
          _resetError = context.l10n.pinResetOtpAgain;
          _step = _PinResetStep.otp;
        });
      } else {
        setState(() {
          _pin.clear();
          _pinConfirmation.clear();
          _confirmingResetPin = false;
          _resetError = message;
        });
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _handleBack() {
    if (_submitting) return;
    if (_step != _PinResetStep.pin) {
      widget.onBack();
      return;
    }
    setState(() {
      _resetError = '';
      if (_confirmingResetPin) {
        _pinConfirmation.clear();
        _confirmingResetPin = false;
      } else {
        _pin.clear();
        _pinConfirmation.clear();
        _step = _PinResetStep.otp;
      }
    });
  }

  String _errorMessage(Object error, String fallback) {
    return authOtpErrorMessage(
      error: error,
      fallback: fallback,
      otpProviderUnavailable: context.l10n.pinResetOtpProviderUnavailable,
    );
  }

  void _handleOtpChanged() {
    if (!mounted) return;
    setState(() {
      if (_resetError.isNotEmpty && !_submitting) _resetError = '';
    });
  }

  void _showResetError(String message) {
    if (!mounted) return;
    final normalized = message.trim();
    if (normalized.isEmpty) return;
    setState(() => _resetError = normalized);
  }

  static void _noop() {}
}

class _PinResetTopBar extends StatelessWidget {
  const _PinResetTopBar({
    required this.brand,
    required this.enabled,
    required this.onBack,
  });

  final String brand;
  final bool enabled;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      key: const ValueKey('pin-reset-topbar'),
      constraints: const BoxConstraints(maxWidth: 430),
      child: SizedBox(
        height: 42,
        child: Row(
          children: [
            Semantics(
              button: true,
              enabled: enabled,
              label: MaterialLocalizations.of(context).backButtonTooltip,
              child: MouseRegion(
                cursor: enabled
                    ? SystemMouseCursors.click
                    : SystemMouseCursors.basic,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: enabled ? onBack : null,
                  child: SizedBox(
                    key: const ValueKey('pin-reset-back'),
                    width: 42,
                    height: 42,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Opacity(
                        opacity: enabled ? 1 : 0.45,
                        child: const Icon(
                          Icons.chevron_left_rounded,
                          color: _pinBack,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  brand,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: _pinBrand,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 42, height: 42),
          ],
        ),
      ),
    );
  }
}

class _PinResetPrimaryAction extends StatelessWidget {
  const _PinResetPrimaryAction({
    super.key,
    required this.label,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? onPressed : null,
          child: Opacity(
            opacity: enabled ? 1 : 0.52,
            child: Container(
              height: 52,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.pinGradientStart(
                      Theme.of(context).colorScheme.primary,
                    ),
                    AppTheme.pinGradientEnd(
                      Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ),
                boxShadow: enabled
                    ? [
                        BoxShadow(
                          color: AppTheme.pinGradientEnd(
                            Theme.of(context).colorScheme.primary,
                          ).withValues(alpha: 0.20),
                          blurRadius: 28,
                          offset: const Offset(0, 14),
                        ),
                      ]
                    : const [],
              ),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PinResetTextAction extends StatelessWidget {
  const _PinResetTextAction({
    super.key,
    required this.label,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? onPressed : null,
          child: Opacity(
            opacity: enabled ? 1 : 0.52,
            child: SizedBox(
              height: 52,
              child: Center(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: _pinActionColor(context),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    height: 1,
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

String _pinDots(int length) => '${'●' * length}${'○' * (6 - length)}';

class _PinProgressLine extends StatelessWidget {
  const _PinProgressLine({super.key, this.width = 132});

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
                          ? _pinDotError
                          : _pinInk
                    : _pinDotEmpty,
              ),
            ),
        ],
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({
    required this.pinLength,
    required this.onDigit,
    required this.onBackspace,
    this.enabled = true,
    this.compact = false,
  });

  final int pinLength;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final bool enabled;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', 'back'];
    final horizontalGap = MediaQuery.sizeOf(context).width <= 360 ? 24.0 : 30.0;
    final height = MediaQuery.sizeOf(context).height;
    final verticalGap = (height * 0.05).clamp(17.0, 26.0).toDouble();
    return ConstrainedBox(
      key: const ValueKey('pin-keypad'),
      constraints: const BoxConstraints(maxWidth: 340),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = (constraints.maxWidth - horizontalGap * 2) / 3;
          final itemHeight = (height * 0.085).clamp(36.0, 43.0).toDouble();
          return Wrap(
            spacing: horizontalGap,
            runSpacing: verticalGap,
            children: [
              for (final key in keys)
                SizedBox(
                  width: itemWidth,
                  height: itemHeight,
                  child: key.isEmpty
                      ? const SizedBox.shrink()
                      : Semantics(
                          button: true,
                          label: key == 'back'
                              ? MaterialLocalizations.of(
                                  context,
                                ).deleteButtonTooltip
                              : key,
                          enabled: enabled && (key != 'back' || pinLength > 0),
                          child: TextButton(
                            onPressed: !enabled
                                ? null
                                : key == 'back'
                                ? pinLength > 0
                                      ? onBackspace
                                      : null
                                : () => onDigit(key),
                            style:
                                TextButton.styleFrom(
                                  foregroundColor: key == 'back'
                                      ? _pinBack
                                      : _pinInk,
                                  disabledForegroundColor:
                                      (key == 'back' ? _pinBack : _pinInk)
                                          .withValues(alpha: 0.42),
                                  minimumSize: Size(54, itemHeight),
                                  padding: EdgeInsets.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  textStyle: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        height: 1,
                                      ),
                                ).copyWith(
                                  overlayColor: const WidgetStatePropertyAll(
                                    Colors.transparent,
                                  ),
                                ),
                            child: key == 'back'
                                ? const Icon(Icons.backspace_outlined, size: 17)
                                : Text(key),
                          ),
                        ),
                ),
            ],
          );
        },
      ),
    );
  }
}
