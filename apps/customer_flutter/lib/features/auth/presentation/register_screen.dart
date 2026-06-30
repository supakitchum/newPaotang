import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/auth_repository.dart';
import '../../../core/i18n/customer_localizations.dart';
import '../../../core/navigation/customer_redirect.dart';
import '../../../core/utils/api_errors.dart';
import '../../../shared/widgets/tenant_brand_header.dart';
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
  String _otpToken = '';
  String _maskedPhone = '';
  int _resendAfter = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
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
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const _RegisterBrandPanel(),
                            const SizedBox(height: 18),
                            _buildFormCard(context),
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

  Widget _buildFormCard(BuildContext context) {
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
              l10n.registerHeaderTitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.registerHeaderSubtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
            ),
            const SizedBox(height: 22),
            _buildNameFields(context),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              decoration: InputDecoration(
                labelText: l10n.registerPhoneLabel,
                prefixIcon: const Icon(Icons.phone_android_outlined),
              ),
              validator: _phoneValidator,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              obscureText: !_showPassword,
              decoration: InputDecoration(
                labelText: l10n.registerPasswordLabel,
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  onPressed: () =>
                      setState(() => _showPassword = !_showPassword),
                  icon: Icon(
                    _showPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
              ),
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmPassword,
              obscureText: !_showPassword,
              decoration: InputDecoration(
                labelText: l10n.registerConfirmPasswordLabel,
                prefixIcon: const Icon(Icons.verified_user_outlined),
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
              height: 52,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      )
                    : Text(
                        _otpSent
                            ? l10n.registerSubmitWithOtp
                            : l10n.registerSubmit,
                      ),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: _submitting
                  ? null
                  : () => context.go(
                        customerLoginRouteForRedirect(_currentRedirect()),
                      ),
              child: Text(l10n.registerLoginLink),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNameFields(BuildContext context) {
    final l10n = context.l10n;
    final firstNameField = TextFormField(
      controller: _firstName,
      decoration: InputDecoration(
        labelText: l10n.registerFirstNameLabel,
        prefixIcon: const Icon(Icons.person_outline),
      ),
      textInputAction: TextInputAction.next,
      validator: _required,
    );
    final lastNameField = TextFormField(
      controller: _lastName,
      decoration: InputDecoration(
        labelText: l10n.registerLastNameLabel,
        prefixIcon: const Icon(Icons.badge_outlined),
      ),
      textInputAction: TextInputAction.next,
      validator: _required,
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
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.72),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: CheckboxListTile(
          contentPadding: const EdgeInsetsDirectional.only(start: 8, end: 10),
          value: _acceptedTerms,
          onChanged: _submitting
              ? null
              : (value) => setState(() => _acceptedTerms = value ?? false),
          title: Text(context.l10n.registerTerms),
          controlAffinity: ListTileControlAffinity.leading,
        ),
      ),
    );
  }

  Widget _buildOtpCard(BuildContext context) {
    final l10n = context.l10n;
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
              decoration: InputDecoration(
                labelText: l10n.authOtpLabel,
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
      _showSnack(context.l10n.registerTermsRequired);
      return;
    }

    final failedMessage = context.l10n.registerFailed;
    setState(() => _submitting = true);
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
        final verified = await ref.read(authRepositoryProvider).verifyOtp(
              phone: _phone.text,
              purpose: 'register',
              otp: _otp.text,
            );
        _otpToken = verified.verificationToken;
      }

      await _register(otpVerificationToken: _otpToken);
      await ref
          .read(affiliateReferralServiceProvider)
          .applyStored(registered: true);
      if (mounted) _goAfterRegistration();
    } catch (_) {
      _showSnack(failedMessage);
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
      _resendAfter = result.resendAfterSeconds;
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

  void _goAfterRegistration() {
    final auth = ref.read(authControllerProvider);
    final redirect = _currentRedirect();
    context.go(
      auth.pinRequired ? customerPinRouteForRedirect(redirect) : redirect,
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

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _RegisterBrandPanel extends StatelessWidget {
  const _RegisterBrandPanel();

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
