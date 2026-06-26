import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/auth_repository.dart';
import '../../../core/i18n/customer_localizations.dart';
import '../../../core/utils/api_errors.dart';

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
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.registerTitle)),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                l10n.registerHeaderTitle,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 8),
              Text(l10n.registerHeaderSubtitle),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _firstName,
                      decoration: InputDecoration(
                        labelText: l10n.registerFirstNameLabel,
                      ),
                      textInputAction: TextInputAction.next,
                      validator: _required,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _lastName,
                      decoration: InputDecoration(
                        labelText: l10n.registerLastNameLabel,
                      ),
                      textInputAction: TextInputAction.next,
                      validator: _required,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: InputDecoration(labelText: l10n.registerPhoneLabel),
                validator: _phoneValidator,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                obscureText: !_showPassword,
                decoration: InputDecoration(
                  labelText: l10n.registerPasswordLabel,
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
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _acceptedTerms,
                onChanged: (value) =>
                    setState(() => _acceptedTerms = value ?? false),
                title: Text(l10n.registerTerms),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              if (_otpSent) ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.registerOtpTitle,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.authOtpSentTo(
                            _maskedPhone.isEmpty ? _phone.text : _maskedPhone,
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
                            labelText: l10n.authOtpLabel,
                          ),
                          validator: _otpValidator,
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _resendAfter > 0 || _submitting
                                ? null
                                : _requestOtp,
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
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const CircularProgressIndicator()
                    : Text(
                        _otpSent
                            ? l10n.registerSubmitWithOtp
                            : l10n.registerSubmit,
                      ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _submitting ? null : () => context.go('/login'),
                child: Text(l10n.registerLoginLink),
              ),
            ],
          ),
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
          if (mounted) context.go('/');
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
      if (mounted) context.go('/');
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

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
