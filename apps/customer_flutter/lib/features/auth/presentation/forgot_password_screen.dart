import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_error_message.dart';
import '../../../core/auth/auth_repository.dart';
import '../../../core/i18n/customer_localizations.dart';
import '../../../core/navigation/customer_link_launcher.dart';
import '../../../core/tenant/mobile_bootstrap_controller.dart';

enum _ForgotStep { phone, otp, password, done }

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();

  _ForgotStep _step = _ForgotStep.phone;
  bool _submitting = false;
  String _maskedPhone = '';
  String _otpToken = '';
  int _resendAfter = 0;
  bool _lineSubmitting = false;
  String _resetError = '';
  String _lineError = '';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _phone.addListener(_clearResetError);
    _otp.addListener(_clearResetError);
    _password.addListener(_clearResetError);
    _confirmPassword.addListener(_clearResetError);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _phone.removeListener(_clearResetError);
    _otp.removeListener(_clearResetError);
    _password.removeListener(_clearResetError);
    _confirmPassword.removeListener(_clearResetError);
    _phone.dispose();
    _otp.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final lineProvider = ref.watch(mobileBootstrapProvider).maybeWhen(
          data: (data) {
            for (final provider in data.authProviders) {
              if (provider.enabled && isLineSocialProvider(provider.provider)) {
                return provider;
              }
            }
            return null;
          },
          orElse: () => null,
        );

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      body: ColoredBox(
        color: colorScheme.surface,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return ListView(
                padding: EdgeInsets.zero,
                children: [
                  _ForgotPasswordHeroSection(
                    minHeight: constraints.maxWidth >= 720 ? 260 : 220,
                    onBack: () => context.go('/login'),
                  ),
                  Form(
                    key: _formKey,
                    child: _ForgotPasswordSheet(
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildResetCard(context),
                              if (lineProvider != null) ...[
                                const SizedBox(height: 14),
                                _LineResetCard(
                                  provider: lineProvider,
                                  submitting: _lineSubmitting,
                                  errorMessage: _lineError,
                                  onPressed: _lineSubmitting || _submitting
                                      ? null
                                      : _startLineReset,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildResetCard(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.72),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.08),
            blurRadius: 36,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _title(l10n),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: colorScheme.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              _description(l10n),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                  ),
            ),
            if (_resetError.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              _ForgotPasswordErrorPanel(message: _resetError),
            ],
            const SizedBox(height: 18),
            if (_step == _ForgotStep.phone) _phoneField(),
            if (_step == _ForgotStep.otp) _otpField(),
            if (_step == _ForgotStep.password) _passwordFields(),
            if (_step == _ForgotStep.done) const _ResetDoneCard(),
            const SizedBox(height: 18),
            SizedBox(
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  shape: const StadiumBorder(),
                  textStyle: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                onPressed: _submitting
                    ? null
                    : _step == _ForgotStep.done
                        ? () => context.go('/login')
                        : _submit,
                child: _submitting
                    ? Text(l10n.forgotPasswordSubmitting)
                    : Text(
                        _step == _ForgotStep.done
                            ? l10n.forgotPasswordBackToLogin
                            : _buttonLabel(l10n),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _phoneField() {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ForgotPasswordFieldLabel(label: l10n.registerPhoneLabel),
        const SizedBox(height: 8),
        TextFormField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          decoration: _forgotInputDecoration(
            context,
            hintText: l10n.forgotPasswordPhoneHint,
            prefixIcon: const Icon(Icons.phone_android_outlined),
          ),
          textInputAction: TextInputAction.done,
          validator: _phoneValidator,
        ),
      ],
    );
  }

  Widget _otpField() {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final sentTo = _maskedPhone.isEmpty ? _phone.text : _maskedPhone;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (sentTo.isNotEmpty) ...[
          DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.14),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.authOtpSentTo(sentTo),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],
        _ForgotPasswordFieldLabel(label: l10n.authOtpLabel),
        const SizedBox(height: 8),
        TextFormField(
          controller: _otp,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          decoration: _forgotInputDecoration(
            context,
            hintText: l10n.forgotPasswordOtpHint,
            prefixIcon: const Icon(Icons.chat_bubble_outline),
          ),
          validator: _otpValidator,
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            onPressed:
                _resendAfter > 0 || _submitting ? null : _requestOtpFromResend,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.only(top: 10),
              foregroundColor: colorScheme.primary,
              textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            child: Text(
              _resendAfter > 0
                  ? l10n.authOtpResendIn(_resendAfter)
                  : l10n.authOtpResend,
            ),
          ),
        ),
      ],
    );
  }

  Widget _passwordFields() {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ForgotPasswordFieldLabel(label: l10n.forgotPasswordNewPassword),
        const SizedBox(height: 8),
        TextFormField(
          controller: _password,
          obscureText: true,
          decoration: _forgotInputDecoration(
            context,
            hintText: l10n.forgotPasswordPasswordHint,
            prefixIcon: const Icon(Icons.lock_outline),
          ),
          validator: _required,
        ),
        const SizedBox(height: 12),
        _ForgotPasswordFieldLabel(label: l10n.forgotPasswordConfirmNewPassword),
        const SizedBox(height: 8),
        TextFormField(
          controller: _confirmPassword,
          obscureText: true,
          decoration: _forgotInputDecoration(
            context,
            hintText: l10n.forgotPasswordConfirmPasswordHint,
            prefixIcon: const Icon(Icons.verified_user_outlined),
          ),
          validator: (value) {
            if ((value ?? '').isEmpty) {
              return context.l10n.authConfirmPasswordRequired;
            }
            if (value != _password.text) {
              return context.l10n.authPasswordMismatch;
            }
            return null;
          },
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final failedMessage = context.l10n.forgotPasswordFailed;
    setState(() {
      _resetError = '';
      _submitting = true;
    });
    try {
      if (_step == _ForgotStep.phone) {
        await _requestOtp();
      } else if (_step == _ForgotStep.otp) {
        final otpVerificationFailed = context.l10n.authOtpVerificationFailed;
        final verified = await ref.read(authRepositoryProvider).verifyOtp(
              phone: _phone.text,
              purpose: 'password_reset',
              otp: _otp.text,
            );
        final verificationToken = verified.verificationToken.trim();
        if (verificationToken.isEmpty) {
          _showResetError(otpVerificationFailed);
          return;
        }
        setState(() {
          _otpToken = verificationToken;
          _step = _ForgotStep.password;
        });
      } else if (_step == _ForgotStep.password) {
        await ref.read(authRepositoryProvider).resetPasswordWithOtp(
              phone: _phone.text,
              otpVerificationToken: _otpToken,
              password: _password.text,
              passwordConfirmation: _confirmPassword.text,
            );
        setState(() => _step = _ForgotStep.done);
      }
    } catch (error) {
      _showResetError(_otpRecoveryErrorMessage(error, failedMessage));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _startLineReset() async {
    setState(() {
      _lineError = '';
      _lineSubmitting = true;
    });
    final linkMissing = context.l10n.socialLoginLinkMissing;
    final failed = context.l10n.forgotPasswordLineFailed;
    try {
      final url = await ref.read(authRepositoryProvider).socialLoginUrl(
            'line',
            purpose: 'password_reset',
            redirect: '/forgot-password',
          );
      final uri = Uri.tryParse(url);
      if (!isSafeSocialLoginUri(uri)) {
        _showLineError(linkMissing);
        return;
      }
      final opened =
          await ref.read(customerLinkLauncherProvider).openSocialLogin(
                'line',
                uri!,
              );
      if (!opened) _showLineError(linkMissing);
    } catch (error) {
      _showLineError(authErrorMessage(error, failed));
    } finally {
      if (mounted) setState(() => _lineSubmitting = false);
    }
  }

  Future<void> _requestOtp() async {
    final result = await ref.read(authRepositoryProvider).requestOtp(
          phone: _phone.text,
          purpose: 'password_reset',
        );
    _otp.clear();
    if (!mounted) return;
    setState(() {
      _maskedPhone = result.phoneMasked;
      _resendAfter =
          result.resendAfterSeconds > 0 ? result.resendAfterSeconds : 60;
      _step = _ForgotStep.otp;
    });
    _startTimer();
  }

  Future<void> _requestOtpFromResend() async {
    final failedMessage = context.l10n.forgotPasswordFailed;
    setState(() {
      _resetError = '';
      _submitting = true;
    });
    try {
      await _requestOtp();
    } catch (error) {
      _showResetError(_otpRecoveryErrorMessage(error, failedMessage));
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
      _ForgotStep.otp => l10n.forgotPasswordTitleOtp,
      _ForgotStep.password => l10n.forgotPasswordTitlePassword,
      _ForgotStep.done => l10n.forgotPasswordTitleDone,
      _ => l10n.forgotPasswordTitlePhone,
    };
  }

  String _description(CustomerLocalizations l10n) {
    return switch (_step) {
      _ForgotStep.otp => l10n.forgotPasswordDescriptionOtpSentTo(
          _maskedPhone.isEmpty ? _phone.text : _maskedPhone,
        ),
      _ForgotStep.password => l10n.forgotPasswordDescriptionPassword,
      _ForgotStep.done => l10n.forgotPasswordDescriptionDone,
      _ => l10n.forgotPasswordDescriptionPhone,
    };
  }

  String _buttonLabel(CustomerLocalizations l10n) {
    return switch (_step) {
      _ForgotStep.otp => l10n.forgotPasswordButtonVerifyOtp,
      _ForgotStep.password => l10n.forgotPasswordButtonSave,
      _ => l10n.forgotPasswordButtonSendOtp,
    };
  }

  String? _required(String? value) =>
      (value ?? '').trim().isEmpty ? context.l10n.authFieldRequired : null;

  String? _phoneValidator(String? value) {
    final phone = value ?? '';
    if (!RegExp(r'^\d{9,10}$').hasMatch(phone)) {
      return context.l10n.authPhoneInvalid;
    }
    return null;
  }

  String? _otpValidator(String? value) {
    if (!RegExp(r'^\d{6}$').hasMatch(value ?? '')) {
      return context.l10n.authOtpInvalid;
    }
    return null;
  }

  String _otpRecoveryErrorMessage(Object error, String fallback) {
    return authOtpErrorMessage(
      error: error,
      fallback: fallback,
      otpProviderUnavailable: context.l10n.forgotPasswordOtpProviderUnavailable,
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

  void _showLineError(String message) {
    if (!mounted) return;
    final normalized = message.trim();
    if (normalized.isEmpty) return;
    setState(() => _lineError = normalized);
  }
}

class _ForgotPasswordErrorPanel extends StatelessWidget {
  const _ForgotPasswordErrorPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.errorContainer.withValues(alpha: 0.62),
          borderRadius: BorderRadius.circular(14),
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

class _ResetDoneCard extends StatelessWidget {
  const _ResetDoneCard();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.tertiaryContainer.withValues(alpha: 0.54),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.tertiary.withValues(alpha: 0.22),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.check_circle,
              color: colorScheme.tertiary,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                context.l10n.forgotPasswordDoneMessage,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onTertiaryContainer,
                      fontWeight: FontWeight.w800,
                      height: 1.4,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ForgotPasswordHeroSection extends StatelessWidget {
  const _ForgotPasswordHeroSection({
    required this.minHeight,
    required this.onBack,
  });

  final double minHeight;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primary,
              Color.lerp(colorScheme.primary, colorScheme.secondary, 0.48) ??
                  colorScheme.primary,
            ],
          ),
        ),
        child: Stack(
          children: [
            PositionedDirectional(
              start: 6,
              top: 6,
              child: IconButton(
                onPressed: onBack,
                color: colorScheme.onPrimary,
                tooltip: context.l10n.forgotPasswordBackToLogin,
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 34, 24, 84),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 330),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        color: colorScheme.onPrimary,
                        size: 34,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        context.l10n.forgotPasswordHeroTitle,
                        textAlign: TextAlign.center,
                        style: textTheme.headlineSmall?.copyWith(
                          color: colorScheme.onPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          height: 1.12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.l10n.forgotPasswordHeroDescription,
                        textAlign: TextAlign.center,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onPrimary.withValues(alpha: 0.92),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          height: 1.55,
                        ),
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
}

class _ForgotPasswordSheet extends StatelessWidget {
  const _ForgotPasswordSheet({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Transform.translate(
      offset: const Offset(0, -48),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLowest,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(34)),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 420),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 34),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _LineResetCard extends StatelessWidget {
  const _LineResetCard({
    required this.provider,
    required this.submitting,
    required this.errorMessage,
    required this.onPressed,
  });

  final SocialAuthProvider provider;
  final bool submitting;
  final String errorMessage;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final trimmedError = errorMessage.trim();
    final colorScheme = Theme.of(context).colorScheme;
    final providerColor = provider.brandColor ?? colorScheme.primary;
    final buttonColor = provider.buttonBackgroundColor ?? providerColor;
    final buttonForeground =
        provider.buttonForegroundColor ?? colorScheme.onPrimary;
    final lineTint = Color.lerp(providerColor, colorScheme.surface, 0.94) ??
        colorScheme.surface;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colorScheme.surface, lineTint],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.72),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.08),
            blurRadius: 36,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.forgotPasswordLineTitle,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: colorScheme.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              context.l10n.forgotPasswordLineDescription,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                  ),
            ),
            if (trimmedError.isNotEmpty) ...[
              const SizedBox(height: 14),
              _ForgotPasswordErrorPanel(message: trimmedError),
            ],
            const SizedBox(height: 18),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: buttonColor,
                  foregroundColor: buttonForeground,
                  shape: const StadiumBorder(),
                  textStyle: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                onPressed: onPressed,
                icon: const Icon(Icons.chat_bubble_outline, size: 22),
                label: Text(
                  submitting
                      ? context.l10n.forgotPasswordLineOpening
                      : context.l10n.forgotPasswordLineButton,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ForgotPasswordFieldLabel extends StatelessWidget {
  const _ForgotPasswordFieldLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w900,
          ),
    );
  }
}

InputDecoration _forgotInputDecoration(
  BuildContext context, {
  required String hintText,
  required Widget prefixIcon,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  return InputDecoration(
    hintText: hintText,
    prefixIcon: IconTheme(
      data: IconThemeData(color: colorScheme.primary, size: 22),
      child: prefixIcon,
    ),
    filled: true,
    fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.34),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(
        color: colorScheme.outlineVariant.withValues(alpha: 0.86),
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: colorScheme.primary),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: colorScheme.error),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: colorScheme.error),
    ),
  );
}
