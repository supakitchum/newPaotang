import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_repository.dart';
import '../../../core/i18n/customer_localizations.dart';
import '../../../core/navigation/customer_link_launcher.dart';
import '../../../core/tenant/mobile_bootstrap_controller.dart';
import '../../../core/utils/api_errors.dart';
import '../../../shared/widgets/tenant_brand_header.dart';

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
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _phone.dispose();
    _otp.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final lineResetEnabled = ref.watch(mobileBootstrapProvider).maybeWhen(
          data: (data) => data.authProviders.any(
            (provider) =>
                provider.enabled &&
                provider.provider.trim().toLowerCase() == 'line',
          ),
          orElse: () => false,
        );

    return Scaffold(
      backgroundColor: colorScheme.primary,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primary,
              Color.lerp(colorScheme.primary, colorScheme.secondary, 0.62) ??
                  colorScheme.primary,
            ],
          ),
        ),
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: (constraints.maxHeight - 48)
                          .clamp(0, double.infinity),
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const _ForgotPasswordBrandPanel(),
                            const SizedBox(height: 18),
                            _buildResetCard(context),
                            if (lineResetEnabled) ...[
                              const SizedBox(height: 14),
                              _LineResetCard(
                                submitting: _lineSubmitting,
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
                );
              },
            ),
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
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _title(l10n),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              _description(l10n),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
            ),
            const SizedBox(height: 22),
            if (_step == _ForgotStep.phone) _phoneField(),
            if (_step == _ForgotStep.otp) _otpField(),
            if (_step == _ForgotStep.password) _passwordFields(),
            if (_step == _ForgotStep.done) const _ResetDoneCard(),
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _submitting
                    ? null
                    : _step == _ForgotStep.done
                        ? () => context.go('/login')
                        : _submit,
                child: _submitting
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      )
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
    return TextFormField(
      controller: _phone,
      keyboardType: TextInputType.phone,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(10),
      ],
      decoration: InputDecoration(
        labelText: context.l10n.registerPhoneLabel,
        prefixIcon: const Icon(Icons.phone_android_outlined),
      ),
      textInputAction: TextInputAction.done,
      validator: _phoneValidator,
    );
  }

  Widget _otpField() {
    final colorScheme = Theme.of(context).colorScheme;
    final sentTo = _maskedPhone.isEmpty ? _phone.text : _maskedPhone;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  child: const Icon(Icons.sms_outlined),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.l10n.authOtpSentTo(sentTo),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _otp,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              decoration: InputDecoration(
                labelText: context.l10n.authOtpLabel,
                prefixIcon: const Icon(Icons.pin_outlined),
              ),
              validator: _otpValidator,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _resendAfter > 0 || _submitting ? null : _requestOtp,
                child: Text(
                  _resendAfter > 0
                      ? context.l10n.authOtpResendIn(_resendAfter)
                      : context.l10n.authOtpResend,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _passwordFields() {
    return Column(
      children: [
        TextFormField(
          controller: _password,
          obscureText: true,
          decoration: InputDecoration(
            labelText: context.l10n.forgotPasswordNewPassword,
            prefixIcon: const Icon(Icons.lock_outline),
          ),
          validator: _required,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _confirmPassword,
          obscureText: true,
          decoration: InputDecoration(
            labelText: context.l10n.forgotPasswordConfirmNewPassword,
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
    setState(() => _submitting = true);
    try {
      if (_step == _ForgotStep.phone) {
        await _requestOtp();
      } else if (_step == _ForgotStep.otp) {
        final verified = await ref.read(authRepositoryProvider).verifyOtp(
              phone: _phone.text,
              purpose: 'password_reset',
              otp: _otp.text,
            );
        setState(() {
          _otpToken = verified.verificationToken;
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
      _showSnack(_otpRecoveryErrorMessage(error, failedMessage));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _startLineReset() async {
    setState(() => _lineSubmitting = true);
    final linkMissing = context.l10n.socialLoginLinkMissing;
    final failed = context.l10n.forgotPasswordLineFailed;
    try {
      final url = await ref.read(authRepositoryProvider).socialLoginUrl(
            'line',
            purpose: 'password_reset',
          );
      final uri = Uri.tryParse(url);
      if (!isSafeExternalLinkUri(uri)) {
        _showSnack(linkMissing);
        return;
      }
      final opened =
          await ref.read(customerLinkLauncherProvider).openSocialLogin(
                'line',
                uri!,
              );
      if (!opened) _showSnack(linkMissing);
    } catch (error) {
      final message = ApiErrorInfo.fromObject(error).message;
      _showSnack(message.trim().isEmpty ? failed : message);
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
      _resendAfter = result.resendAfterSeconds;
      _step = _ForgotStep.otp;
    });
    _startTimer();
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
      _ForgotStep.otp => l10n.forgotPasswordDescriptionOtp,
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
    final info = ApiErrorInfo.fromObject(error);
    if (info.isSmsOtpProviderNotConfigured) {
      return context.l10n.forgotPasswordOtpProviderUnavailable;
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

class _ResetDoneCard extends StatelessWidget {
  const _ResetDoneCard();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.tertiaryContainer.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colorScheme.tertiary.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: colorScheme.tertiary,
              foregroundColor: colorScheme.onTertiary,
              child: const Icon(Icons.check_circle_outline),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(context.l10n.forgotPasswordDoneMessage)),
          ],
        ),
      ),
    );
  }
}

class _ForgotPasswordBrandPanel extends StatelessWidget {
  const _ForgotPasswordBrandPanel();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 18, vertical: 22),
        child: TenantBrandHeader(),
      ),
    );
  }
}

class _LineResetCard extends StatelessWidget {
  const _LineResetCard({required this.submitting, required this.onPressed});

  final bool submitting;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF06C755).withValues(
                    alpha: 0.12,
                  ),
                  child: const Icon(
                    Icons.chat_bubble_outline,
                    color: Color(0xFF06C755),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.forgotPasswordLineTitle,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.l10n.forgotPasswordLineDescription,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: onPressed,
                icon: submitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.chat_bubble_outline),
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
