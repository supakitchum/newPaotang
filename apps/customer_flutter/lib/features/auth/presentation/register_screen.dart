import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/auth_repository.dart';
import '../../../core/i18n/customer_localizations.dart';
import '../../../core/navigation/customer_redirect.dart';
import '../../../core/utils/api_errors.dart';
import '../../affiliate/data/affiliate_referral_repository.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _otp = TextEditingController();

  bool _acceptedTerms = false;
  bool _otpSent = false;
  bool _submitting = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  String _otpToken = '';
  String _maskedPhone = '';
  String _formError = '';
  int _resendAfter = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _firstName.addListener(_clearFormError);
    _lastName.addListener(_clearFormError);
    _phone.addListener(_clearFormError);
    _password.addListener(_clearFormError);
    _confirmPassword.addListener(_clearFormError);
    _otp.addListener(_clearFormError);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _firstName.removeListener(_clearFormError);
    _lastName.removeListener(_clearFormError);
    _phone.removeListener(_clearFormError);
    _password.removeListener(_clearFormError);
    _confirmPassword.removeListener(_clearFormError);
    _otp.removeListener(_clearFormError);
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _otp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      body: DecoratedBox(
        decoration: BoxDecoration(color: colorScheme.surface),
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _RegisterHeroSection(
                      minHeight: constraints.maxWidth >= 720 ? 300 : 258,
                    ),
                    _RegisterSheet(
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: _buildFormCard(context),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormCard(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.10),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 24, 18, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.registerFormTitle,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: colorScheme.onSurface,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.registerFormDescription,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 15,
                    height: 1.35,
                  ),
            ),
            if (_formError.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              _RegisterErrorPanel(message: _formError),
            ],
            const SizedBox(height: 22),
            _buildNameFields(context),
            const SizedBox(height: 12),
            _RegisterFieldLabel(label: l10n.registerPhoneLabel),
            const SizedBox(height: 8),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              decoration: _registerInputDecoration(
                context,
                hintText: l10n.registerPhoneHint,
                prefixIcon: const Icon(Icons.phone_android_outlined),
              ),
              validator: _phoneValidator,
            ),
            const SizedBox(height: 12),
            _RegisterFieldLabel(label: l10n.registerPasswordLabel),
            const SizedBox(height: 8),
            TextFormField(
              controller: _password,
              obscureText: !_showPassword,
              textInputAction: TextInputAction.next,
              decoration: _registerInputDecoration(
                context,
                hintText: l10n.registerPasswordHint,
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  onPressed: () =>
                      setState(() => _showPassword = !_showPassword),
                  icon: Icon(
                    _showPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  tooltip: _showPassword
                      ? l10n.registerHidePassword
                      : l10n.registerShowPassword,
                ),
              ),
              validator: _required,
            ),
            const SizedBox(height: 12),
            _RegisterFieldLabel(label: l10n.registerConfirmPasswordLabel),
            const SizedBox(height: 8),
            TextFormField(
              controller: _confirmPassword,
              obscureText: !_showConfirmPassword,
              textInputAction: TextInputAction.done,
              decoration: _registerInputDecoration(
                context,
                hintText: l10n.registerConfirmPasswordHint,
                prefixIcon: const Icon(Icons.verified_user_outlined),
                suffixIcon: IconButton(
                  onPressed: () => setState(
                    () => _showConfirmPassword = !_showConfirmPassword,
                  ),
                  icon: Icon(
                    _showConfirmPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  tooltip: _showConfirmPassword
                      ? l10n.registerHidePassword
                      : l10n.registerShowPassword,
                ),
              ),
              validator: (value) {
                if ((value ?? '').isEmpty) {
                  return l10n.authConfirmPasswordRequired;
                }
                if (value != _password.text) {
                  return l10n.authPasswordMismatch;
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            _buildTermsTile(context),
            if (_otpSent) ...[
              const SizedBox(height: 14),
              _buildOtpCard(context),
            ],
            const SizedBox(height: 20),
            SizedBox(
              height: 54,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  shape: const StadiumBorder(),
                  textStyle: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                onPressed: _submitting ? null : _submit,
                child: Text(
                  _submitting
                      ? l10n.registerSubmitting
                      : _otpSent
                          ? l10n.registerSubmitWithOtp
                          : l10n.registerSubmit,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    l10n.registerLoginPrompt,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                const SizedBox(width: 7),
                TextButton(
                  onPressed: _submitting
                      ? null
                      : () => context.go(
                            customerLoginRouteForRedirect(_currentRedirect()),
                          ),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(l10n.loginTitle),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNameFields(BuildContext context) {
    final l10n = context.l10n;
    final firstNameField = _RegisterLabeledField(
      label: l10n.registerFirstNameLabel,
      child: TextFormField(
        controller: _firstName,
        decoration: _registerInputDecoration(
          context,
          hintText: l10n.registerFirstNameHint,
          prefixIcon: const Icon(Icons.person_outline),
        ),
        textInputAction: TextInputAction.next,
        validator: _required,
      ),
    );
    final lastNameField = _RegisterLabeledField(
      label: l10n.registerLastNameLabel,
      child: TextFormField(
        controller: _lastName,
        decoration: _registerInputDecoration(
          context,
          hintText: l10n.registerLastNameHint,
          prefixIcon: const Icon(Icons.badge_outlined),
        ),
        textInputAction: TextInputAction.next,
        validator: _required,
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 380) {
          return Column(
            children: [
              firstNameField,
              const SizedBox(height: 12),
              lastNameField,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: firstNameField),
            const SizedBox(width: 12),
            Expanded(child: lastNameField),
          ],
        );
      },
    );
  }

  Widget _buildTermsTile(BuildContext context) {
    return _RegisterConsentRow(
      checked: _acceptedTerms,
      disabled: _submitting,
      label: context.l10n.registerTerms,
      onChanged: (value) {
        setState(() {
          _acceptedTerms = value;
          _formError = '';
        });
      },
    );
  }

  Widget _buildOtpCard(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final sentTo = _maskedPhone.isEmpty ? _phone.text : _maskedPhone;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: colorScheme.primary.withValues(alpha: 0.12),
                  foregroundColor: colorScheme.primary,
                  child: const Icon(Icons.sms_outlined),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.registerOtpTitle,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.authOtpSentTo(sentTo),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
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
              decoration: _registerInputDecoration(
                context,
                hintText: l10n.registerOtpHint,
                prefixIcon: const Icon(Icons.chat_bubble_outline),
              ),
              validator: _otpValidator,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _resendAfter > 0 || _submitting
                    ? null
                    : _requestOtpFromResend,
                child: Text(
                  _resendAfter > 0
                      ? l10n.authOtpResendIn(_resendAfter)
                      : l10n.authOtpResend,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_acceptedTerms) {
      _showFormError(context.l10n.registerTermsRequired);
      return;
    }

    final failedMessage = context.l10n.registerFailed;
    setState(() {
      _formError = '';
      _submitting = true;
    });
    try {
      if (!_otpSent) {
        try {
          await _requestOtp();
        } catch (error) {
          if (!_canRegisterWithoutOtp(error)) rethrow;
          await _register();
          await ref
              .read(affiliateReferralServiceProvider)
              .applyStored(registered: true);
          if (mounted) _goAfterRegistration();
        }
        return;
      }
      if (_otpToken.isEmpty) {
        final otpVerificationFailed = context.l10n.authOtpVerificationFailed;
        final verified = await ref.read(authRepositoryProvider).verifyOtp(
              phone: _phone.text,
              purpose: 'register',
              otp: _otp.text,
            );
        final verificationToken = verified.verificationToken.trim();
        if (verificationToken.isEmpty) {
          _showFormError(otpVerificationFailed);
          return;
        }
        _otpToken = verificationToken;
      }

      await _register(otpVerificationToken: _otpToken);
      await ref
          .read(affiliateReferralServiceProvider)
          .applyStored(registered: true);
      if (mounted) _goAfterRegistration();
    } catch (error) {
      _showFormError(_registrationErrorMessage(error, failedMessage));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _register({String? otpVerificationToken}) {
    return ref.read(authControllerProvider).register(
          firstName: _firstName.text.trim(),
          lastName: _lastName.text.trim(),
          phone: _phone.text,
          password: _password.text,
          passwordConfirmation: _confirmPassword.text,
          otpVerificationToken: otpVerificationToken,
        );
  }

  Future<void> _requestOtp() async {
    final result = await ref.read(authRepositoryProvider).requestOtp(
          phone: _phone.text,
          purpose: 'register',
        );
    _otp.clear();
    _otpToken = '';
    if (!mounted) return;
    setState(() {
      _otpSent = true;
      _maskedPhone = result.phoneMasked;
      _resendAfter =
          result.resendAfterSeconds > 0 ? result.resendAfterSeconds : 60;
    });
    _startTimer();
  }

  Future<void> _requestOtpFromResend() async {
    final failedMessage = context.l10n.registerFailed;
    setState(() {
      _formError = '';
      _submitting = true;
    });
    try {
      await _requestOtp();
    } catch (error) {
      _showFormError(_registrationErrorMessage(error, failedMessage));
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
    if (!_otpSent) return null;
    if (!RegExp(r'^\d{6}$').hasMatch(value ?? '')) {
      return context.l10n.authOtpInvalid;
    }
    return null;
  }

  bool _canRegisterWithoutOtp(Object error) {
    final info = ApiErrorInfo.fromObject(error);
    return info.isOptionalSmsOtpProviderMissing;
  }

  String _registrationErrorMessage(Object error, String fallback) {
    final message = ApiErrorInfo.fromObject(error).message.trim();
    if (message.isEmpty) return fallback;
    if (error is DioException || error is Map) return message;
    return fallback;
  }

  void _clearFormError() {
    if (_formError.isEmpty || !mounted || _submitting) return;
    setState(() => _formError = '');
  }

  void _showFormError(String message) {
    if (!mounted) return;
    final normalized = message.trim();
    if (normalized.isEmpty) return;
    setState(() => _formError = normalized);
  }

  void _goAfterRegistration() {
    final auth = ref.read(authControllerProvider);
    final redirect = _currentRedirect();
    context.go(
      customerPostAuthRouteForRedirect(
        redirect: redirect,
        pinRequired: auth.pinRequired,
        pinSetupRequired: auth.pinSetupRequired,
      ),
    );
  }

  String _currentRedirect() {
    try {
      return safeCustomerRedirect(
        GoRouterState.of(context).uri.queryParameters['redirect'],
      );
    } catch (_) {
      return '/';
    }
  }
}

class _RegisterErrorPanel extends StatelessWidget {
  const _RegisterErrorPanel({required this.message});

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

class _RegisterHeroSection extends StatelessWidget {
  const _RegisterHeroSection({required this.minHeight});

  final double minHeight;

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
              Color.lerp(colorScheme.primary, colorScheme.secondary, 0.46) ??
                  colorScheme.primary,
            ],
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 920),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 34, 20, 104),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 430),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color:
                                  colorScheme.onPrimary.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 13,
                                vertical: 8,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.person_add_alt_1_outlined,
                                    color: colorScheme.onPrimary,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    context.l10n.registerHeroBadge,
                                    style: textTheme.labelLarge?.copyWith(
                                      color: colorScheme.onPrimary,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            context.l10n.registerTitle,
                            style: textTheme.headlineLarge?.copyWith(
                              color: colorScheme.onPrimary,
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            context.l10n.registerHeroDescription,
                            style: textTheme.bodyLarge?.copyWith(
                              color:
                                  colorScheme.onPrimary.withValues(alpha: 0.9),
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
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
}

class _RegisterSheet extends StatelessWidget {
  const _RegisterSheet({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Transform.translate(
      offset: const Offset(0, -78),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLowest,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(34)),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 420),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 24, 18, 44),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _RegisterLabeledField extends StatelessWidget {
  const _RegisterLabeledField({
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RegisterFieldLabel(label: label),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _RegisterFieldLabel extends StatelessWidget {
  const _RegisterFieldLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w800,
          ),
    );
  }
}

class _RegisterConsentRow extends StatelessWidget {
  const _RegisterConsentRow({
    required this.checked,
    required this.disabled,
    required this.label,
    required this.onChanged,
  });

  final bool checked;
  final bool disabled;
  final String label;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final enabled = !disabled;
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      checked: checked,
      enabled: enabled,
      label: label,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: enabled ? () => onChanged(!checked) : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 2, 0, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: _RegisterConsentBox(
                    checked: checked,
                    disabled: disabled,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ExcludeSemantics(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: enabled ? 1 : 0.58,
                            ),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            height: 1.45,
                          ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RegisterConsentBox extends StatelessWidget {
  const _RegisterConsentBox({
    required this.checked,
    required this.disabled,
  });

  final bool checked;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final borderColor = disabled
        ? colorScheme.outlineVariant
        : checked
            ? colorScheme.primary
            : colorScheme.outlineVariant;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      width: 17,
      height: 17,
      decoration: BoxDecoration(
        color: checked && !disabled ? colorScheme.primary : colorScheme.surface,
        border: Border.all(color: borderColor, width: 1.4),
        borderRadius: BorderRadius.circular(3),
      ),
      child: checked
          ? Icon(
              Icons.check,
              color: disabled
                  ? colorScheme.onSurfaceVariant
                  : colorScheme.onPrimary,
              size: 13,
            )
          : null,
    );
  }
}

InputDecoration _registerInputDecoration(
  BuildContext context, {
  required String hintText,
  required Widget prefixIcon,
  Widget? suffixIcon,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  return InputDecoration(
    hintText: hintText,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: colorScheme.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: colorScheme.outlineVariant.withValues(alpha: 0.86),
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: colorScheme.primary),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: colorScheme.error),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: colorScheme.error),
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: colorScheme.outlineVariant.withValues(alpha: 0.72),
      ),
    ),
  );
}
