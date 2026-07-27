import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/auth_error_message.dart';
import '../../../core/auth/auth_repository.dart';
import '../../../core/i18n/customer_localizations.dart';
import '../../../core/navigation/customer_link_launcher.dart';
import '../../../core/navigation/customer_redirect.dart';
import '../../../core/tenant/mobile_bootstrap_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/utils/customer_operational_error.dart';
import '../../affiliate/data/affiliate_referral_repository.dart';
import 'auth_visual_tokens.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _otp = TextEditingController();
  bool _passwordSubmitting = false;
  bool _rememberMe = true;
  bool _showPassword = false;
  String? _socialSubmittingProvider;
  String _formError = '';
  LoginOtpChallenge? _loginOtpChallenge;
  int _resendAfter = 0;
  Timer? _resendTimer;

  bool get _busy => _passwordSubmitting || _socialSubmittingProvider != null;

  @override
  void initState() {
    super.initState();
    _username.addListener(_clearFormError);
    _password.addListener(_clearFormError);
    _otp.addListener(_clearFormError);
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _username.removeListener(_clearFormError);
    _password.removeListener(_clearFormError);
    _otp.removeListener(_clearFormError);
    _username.dispose();
    _password.dispose();
    _otp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bootstrap = ref.watch(mobileBootstrapProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final socialProviders = bootstrap.maybeWhen(
      data: (data) => data.authProviders,
      orElse: () => const <SocialAuthProvider>[],
    );

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      body: DecoratedBox(
        decoration: BoxDecoration(color: colorScheme.surface),
        child: SafeArea(
          key: const ValueKey('login-screen-safe-area'),
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return ListView(
                padding: EdgeInsets.zero,
                children: [
                  _LoginHeroSection(
                    minHeight: constraints.maxWidth >= 720 ? 300 : 258,
                  ),
                  _LoginSheet(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 520),
                            child: _LoginFormCard(
                              username: _username,
                              password: _password,
                              otp: _otp,
                              busy: _busy,
                              passwordSubmitting: _passwordSubmitting,
                              otpRequired: _loginOtpChallenge != null,
                              maskedPhone:
                                  _loginOtpChallenge?.phoneMasked ?? '',
                              resendAfter: _resendAfter,
                              rememberMe: _rememberMe,
                              showPassword: _showPassword,
                              formError: _formError,
                              onRememberMeChanged: (value) =>
                                  setState(() => _rememberMe = value),
                              onTogglePassword: () => setState(
                                () => _showPassword = !_showPassword,
                              ),
                              socialProviders: socialProviders,
                              socialSubmittingProvider:
                                  _socialSubmittingProvider,
                              onLogin: _login,
                              onResendOtp: _resendLoginOtp,
                              onChangeAccount: _cancelLoginOtp,
                              onSocialLogin: _socialLogin,
                              onRegister: () => context.go(
                                customerRegisterRouteForRedirect(
                                  _currentRedirect(),
                                ),
                              ),
                              onForgotPassword: () =>
                                  context.go('/forgot-password'),
                            ),
                          ),
                        ),
                      ],
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

  Future<void> _login() async {
    if (_busy) return;
    setState(() {
      _formError = '';
      _passwordSubmitting = true;
    });
    try {
      final challenge = _loginOtpChallenge;
      if (challenge == null) {
        await ref
            .read(authControllerProvider)
            .loginWithPassword(_username.text.trim(), _password.text);
      } else {
        final otp = _otp.text.trim();
        if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
          _showFormError(context.l10n.authOtpInvalid);
          return;
        }
        await ref
            .read(authControllerProvider)
            .verifyLoginOtp(challengeToken: challenge.challengeToken, otp: otp);
      }
      await ref.read(affiliateReferralServiceProvider).applyStored();
      if (mounted) {
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
    } on LoginOtpChallengeRequired catch (required) {
      _applyLoginOtpChallenge(required.challenge);
    } catch (error) {
      if (!mounted) return;
      final handled = await handleCustomerOperationalError(
        ref: ref,
        context: context,
        error: error,
        returnPathOverride: _currentRedirect(),
      );
      if (!mounted || handled) return;
      _showFormError(_errorMessage(error, context.l10n.loginFailed));
    } finally {
      if (mounted) setState(() => _passwordSubmitting = false);
    }
  }

  Future<void> _resendLoginOtp() async {
    final challenge = _loginOtpChallenge;
    if (_busy || challenge == null || _resendAfter > 0) return;
    setState(() {
      _formError = '';
      _passwordSubmitting = true;
    });
    try {
      final refreshed = await ref
          .read(authRepositoryProvider)
          .resendLoginOtp(challengeToken: challenge.challengeToken);
      _applyLoginOtpChallenge(refreshed);
    } catch (error) {
      if (!mounted) return;
      _showFormError(
        authOtpErrorMessage(
          error: error,
          fallback: context.l10n.authOtpVerificationFailed,
          otpProviderUnavailable: context.l10n.authOtpVerificationFailed,
        ),
      );
    } finally {
      if (mounted) setState(() => _passwordSubmitting = false);
    }
  }

  void _applyLoginOtpChallenge(LoginOtpChallenge challenge) {
    if (!mounted) return;
    _otp.clear();
    _resendTimer?.cancel();
    setState(() {
      _loginOtpChallenge = challenge;
      _resendAfter = challenge.resendAfterSeconds > 0
          ? challenge.resendAfterSeconds
          : 60;
      _formError = '';
    });
    _startResendTimer();
  }

  void _startResendTimer() {
    if (_resendAfter <= 0) return;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _resendAfter <= 1) {
        timer.cancel();
        if (mounted) setState(() => _resendAfter = 0);
        return;
      }
      setState(() => _resendAfter -= 1);
    });
  }

  void _cancelLoginOtp() {
    if (_busy) return;
    _resendTimer?.cancel();
    _otp.clear();
    setState(() {
      _loginOtpChallenge = null;
      _resendAfter = 0;
      _formError = '';
    });
  }

  Future<void> _socialLogin(String provider) async {
    final normalizedProvider = normalizeSocialAuthProvider(provider);
    if (_busy || normalizedProvider.isEmpty) return;
    setState(() {
      _formError = '';
      _socialSubmittingProvider = normalizedProvider;
    });
    final socialLinkMissing = context.l10n.socialLoginLinkMissing;
    final socialFailed = context.l10n.socialLoginFailed;
    try {
      final url = await ref
          .read(authRepositoryProvider)
          .socialLoginUrl(normalizedProvider, redirect: _currentRedirect());
      final uri = Uri.tryParse(url);
      if (!isSafeSocialLoginUri(uri)) {
        _showFormError(socialLinkMissing);
        return;
      }
      final opened = await ref
          .read(customerLinkLauncherProvider)
          .openSocialLogin(normalizedProvider, uri!);
      if (!opened) {
        _showFormError(socialFailed);
      }
    } catch (error) {
      if (!mounted) return;
      final handled = await handleCustomerOperationalError(
        ref: ref,
        context: context,
        error: error,
        returnPathOverride: _currentRedirect(),
      );
      if (!mounted || handled) return;
      _showFormError(_errorMessage(error, socialFailed));
    } finally {
      if (mounted) setState(() => _socialSubmittingProvider = null);
    }
  }

  String _errorMessage(Object error, String fallback) {
    return authErrorMessage(error, fallback);
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

  void _clearFormError() {
    if (_formError.isEmpty || !mounted || _busy) return;
    setState(() => _formError = '');
  }

  void _showFormError(String message) {
    if (!mounted) return;
    final normalized = message.trim();
    if (normalized.isEmpty) return;
    setState(() => _formError = normalized);
  }
}

class _LoginHeroSection extends StatelessWidget {
  const _LoginHeroSection({required this.minHeight});

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
              AppTheme.heroGradientEnd(colorScheme.primary),
            ],
          ),
        ),
        child: Stack(
          children: [
            const _LoginHeroAccents(),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 920),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    34 + MediaQuery.paddingOf(context).top,
                    20,
                    104,
                  ),
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
                              color: colorScheme.onPrimary.withValues(
                                alpha: 0.16,
                              ),
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
                                    Icons.shield_outlined,
                                    color: colorScheme.onPrimary,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    context.l10n.loginHeroBadge,
                                    style: textTheme.labelLarge?.copyWith(
                                      color: colorScheme.onPrimary,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            context.l10n.loginTitle,
                            style: textTheme.headlineLarge?.copyWith(
                              color: colorScheme.onPrimary,
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            context.l10n.loginHeroDescription,
                            style: textTheme.bodyLarge?.copyWith(
                              color: colorScheme.onPrimary.withValues(
                                alpha: 0.9,
                              ),
                              fontSize: 17,
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

class _LoginHeroAccents extends StatelessWidget {
  const _LoginHeroAccents();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            Positioned(
              right: -76,
              bottom: -126,
              child: Container(
                width: 344,
                height: 344,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorScheme.secondary.withValues(alpha: 0.34),
                ),
              ),
            ),
            Positioned(
              right: 34,
              bottom: 34,
              child: Container(
                width: 116,
                height: 116,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorScheme.tertiary.withValues(alpha: 0.86),
                ),
              ),
            ),
            Positioned(
              left: -78,
              top: 26,
              child: Transform.rotate(
                angle: -0.58,
                child: Container(
                  width: 360,
                  height: 88,
                  decoration: BoxDecoration(
                    color: colorScheme.onPrimary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(44),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 82,
              bottom: 40,
              child: Transform.rotate(
                angle: -0.58,
                child: Container(
                  width: 310,
                  height: 78,
                  decoration: BoxDecoration(
                    color: colorScheme.onPrimary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(42),
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

class _LoginSheet extends StatelessWidget {
  const _LoginSheet({required this.child});

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

class _LoginFormCard extends StatelessWidget {
  const _LoginFormCard({
    required this.username,
    required this.password,
    required this.otp,
    required this.busy,
    required this.passwordSubmitting,
    required this.otpRequired,
    required this.maskedPhone,
    required this.resendAfter,
    required this.rememberMe,
    required this.showPassword,
    required this.formError,
    required this.onRememberMeChanged,
    required this.onTogglePassword,
    required this.socialProviders,
    required this.socialSubmittingProvider,
    required this.onLogin,
    required this.onResendOtp,
    required this.onChangeAccount,
    required this.onSocialLogin,
    required this.onRegister,
    required this.onForgotPassword,
  });

  final TextEditingController username;
  final TextEditingController password;
  final TextEditingController otp;
  final bool busy;
  final bool passwordSubmitting;
  final bool otpRequired;
  final String maskedPhone;
  final int resendAfter;
  final bool rememberMe;
  final bool showPassword;
  final String formError;
  final ValueChanged<bool> onRememberMeChanged;
  final VoidCallback onTogglePassword;
  final List<SocialAuthProvider> socialProviders;
  final String? socialSubmittingProvider;
  final VoidCallback onLogin;
  final VoidCallback onResendOtp;
  final VoidCallback onChangeAccount;
  final ValueChanged<String> onSocialLogin;
  final VoidCallback onRegister;
  final VoidCallback onForgotPassword;

  @override
  Widget build(BuildContext context) {
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
              l10n.loginFormTitle,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: colorScheme.onSurface,
                fontSize: 23,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.loginFormDescription,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontSize: 15,
                height: 1.35,
              ),
            ),
            if (formError.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              _LoginErrorPanel(message: formError),
            ],
            const SizedBox(height: 22),
            _LoginFieldLabel(label: l10n.loginIdentifierLabel),
            const SizedBox(height: 8),
            TextField(
              controller: username,
              enabled: !busy && !otpRequired,
              autofillHints: const [AutofillHints.telephoneNumber],
              style: authInputTextStyle(context),
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              decoration: _loginInputDecoration(
                context,
                hintText: l10n.loginIdentifierHint,
                prefixIcon: const Icon(Icons.phone_android_outlined),
              ),
            ),
            const SizedBox(height: 16),
            _LoginFieldLabel(label: l10n.loginPasswordLabel),
            const SizedBox(height: 8),
            TextField(
              controller: password,
              enabled: !busy && !otpRequired,
              autofillHints: const [AutofillHints.password],
              style: authInputTextStyle(context),
              obscureText: !showPassword,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                if (!busy && !otpRequired) onLogin();
              },
              decoration: _loginInputDecoration(
                context,
                hintText: l10n.loginPasswordHint,
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: authInputActionButton(
                  context,
                  onPressed: busy ? null : onTogglePassword,
                  icon: showPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  tooltip: showPassword
                      ? l10n.loginHidePassword
                      : l10n.loginShowPassword,
                ),
              ),
            ),
            if (otpRequired) ...[
              const SizedBox(height: 16),
              _LoginOtpPanel(
                otp: otp,
                maskedPhone: maskedPhone,
                resendAfter: resendAfter,
                busy: busy,
                onSubmit: onLogin,
                onResend: onResendOtp,
                onChangeAccount: onChangeAccount,
              ),
            ] else ...[
              const SizedBox(height: 8),
              _LoginOptionsRow(
                rememberMe: rememberMe,
                enabled: !busy,
                onRememberMeChanged: onRememberMeChanged,
                onForgotPassword: onForgotPassword,
              ),
            ],
            const SizedBox(height: 12),
            authPrimaryActionButton(
              onPressed: busy ? null : onLogin,
              height: 54,
              fontSize: 18,
              label: otpRequired
                  ? passwordSubmitting
                        ? l10n.loginOtpSubmitting
                        : l10n.loginOtpSubmit
                  : passwordSubmitting
                  ? l10n.loginSubmitting
                  : l10n.loginSubmit,
            ),
            if (!otpRequired) ...[
              _SocialLoginPanel(
                providers: socialProviders,
                loading: busy,
                submittingProvider: socialSubmittingProvider,
                onLogin: onSocialLogin,
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      l10n.loginRegisterPrompt,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  TextButton(
                    onPressed: busy ? null : onRegister,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 36),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(l10n.loginRegister),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LoginOtpPanel extends StatelessWidget {
  const _LoginOtpPanel({
    required this.otp,
    required this.maskedPhone,
    required this.resendAfter,
    required this.busy,
    required this.onSubmit,
    required this.onResend,
    required this.onChangeAccount,
  });

  final TextEditingController otp;
  final String maskedPhone;
  final int resendAfter;
  final bool busy;
  final VoidCallback onSubmit;
  final VoidCallback onResend;
  final VoidCallback onChangeAccount;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          key: const ValueKey('login-otp-panel'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.loginOtpTitle,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.authOtpSentTo(maskedPhone),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            _LoginFieldLabel(label: l10n.authOtpLabel),
            const SizedBox(height: 8),
            TextField(
              controller: otp,
              key: const ValueKey('login-otp-input'),
              enabled: !busy,
              autofocus: true,
              autofillHints: const [AutofillHints.oneTimeCode],
              style: authInputTextStyle(context),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              onSubmitted: (_) {
                if (!busy) onSubmit();
              },
              decoration: _loginInputDecoration(
                context,
                hintText: l10n.loginOtpHint,
                prefixIcon: const Icon(Icons.chat_bubble_outline),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: busy ? null : onChangeAccount,
                    child: Text(l10n.loginOtpChangeAccount),
                  ),
                ),
                TextButton(
                  onPressed: busy || resendAfter > 0 ? null : onResend,
                  child: Text(
                    resendAfter > 0
                        ? l10n.authOtpResendIn(resendAfter)
                        : l10n.authOtpResend,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginOptionsRow extends StatelessWidget {
  const _LoginOptionsRow({
    required this.rememberMe,
    required this.enabled,
    required this.onRememberMeChanged,
    required this.onForgotPassword,
  });

  final bool rememberMe;
  final bool enabled;
  final ValueChanged<bool> onRememberMeChanged;
  final VoidCallback onForgotPassword;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: colorScheme.onSurfaceVariant,
      fontSize: 14,
      fontWeight: FontWeight.w700,
    );
    return Row(
      children: [
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: enabled ? () => onRememberMeChanged(!rememberMe) : null,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1.5),
                    child: _LoginRememberBox(
                      checked: rememberMe,
                      disabled: !enabled,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      context.l10n.loginRememberMe,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textStyle,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        TextButton(
          onPressed: enabled ? onForgotPassword : null,
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 36),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(context.l10n.loginForgotPassword),
        ),
      ],
    );
  }
}

class _LoginFieldLabel extends StatelessWidget {
  const _LoginFieldLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: Theme.of(context).colorScheme.onSurface,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _LoginRememberBox extends StatelessWidget {
  const _LoginRememberBox({required this.checked, required this.disabled});

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

class _LoginErrorPanel extends StatelessWidget {
  const _LoginErrorPanel({required this.message});

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
          border: Border.all(color: colorScheme.error.withValues(alpha: 0.14)),
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

InputDecoration _loginInputDecoration(
  BuildContext context, {
  required String hintText,
  required Widget prefixIcon,
  Widget? suffixIcon,
}) {
  return authInputDecoration(
    context,
    hintText: hintText,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
  );
}

class _SocialLoginPanel extends StatelessWidget {
  const _SocialLoginPanel({
    required this.providers,
    required this.loading,
    required this.submittingProvider,
    required this.onLogin,
  });

  final List<SocialAuthProvider> providers;
  final bool loading;
  final String? submittingProvider;
  final ValueChanged<String> onLogin;

  @override
  Widget build(BuildContext context) {
    final enabledProviders = _visibleSocialProviders(providers);
    if (enabledProviders.isEmpty) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(child: Divider(color: colorScheme.outlineVariant)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                context.l10n.loginDivider,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(child: Divider(color: colorScheme.outlineVariant)),
          ],
        ),
        const SizedBox(height: 18),
        for (var index = 0; index < enabledProviders.length; index++) ...[
          _SocialLoginButton(
            provider: enabledProviders[index],
            loading: loading,
            submittingProvider: submittingProvider,
            onPressed: () => onLogin(enabledProviders[index].provider),
          ),
          if (index < enabledProviders.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _SocialLoginButton extends StatelessWidget {
  const _SocialLoginButton({
    required this.provider,
    required this.loading,
    required this.submittingProvider,
    required this.onPressed,
  });

  final SocialAuthProvider provider;
  final bool loading;
  final String? submittingProvider;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final normalizedProvider = normalizeSocialAuthProvider(provider.provider);
    final isSubmitting = submittingProvider == normalizedProvider;
    final colorScheme = Theme.of(context).colorScheme;
    final brandColor = provider.brandColor ?? colorScheme.primary;
    final backgroundColor =
        provider.buttonBackgroundColor ??
        (normalizedProvider == 'line' ? brandColor : null);
    final foregroundColor =
        provider.buttonForegroundColor ??
        (backgroundColor == null
            ? colorScheme.onSurface
            : colorScheme.onPrimary);
    final borderColor = backgroundColor ?? provider.brandColor;
    return SizedBox(
      height: 54,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          side: BorderSide(
            color:
                borderColor ??
                colorScheme.outlineVariant.withValues(alpha: 0.90),
          ),
          shape: const StadiumBorder(),
          textStyle: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        onPressed: loading ? null : onPressed,
        icon: Icon(
          _providerIcon(normalizedProvider),
          size: normalizedProvider == 'line' ? 22 : 20,
        ),
        label: Text(
          isSubmitting
              ? context.l10n.socialLoginOpening(provider.label)
              : context.l10n.socialLoginLabel(provider.label),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

List<SocialAuthProvider> _visibleSocialProviders(
  List<SocialAuthProvider> providers,
) {
  final seen = <String>{};
  final visible = <SocialAuthProvider>[];
  for (final provider in providers) {
    final normalizedProvider = normalizeSocialAuthProvider(provider.provider);
    if (!provider.enabled ||
        normalizedProvider.isEmpty ||
        !provider.supported ||
        !seen.add(normalizedProvider)) {
      continue;
    }
    visible.add(provider);
  }
  return visible;
}

IconData _providerIcon(String provider) {
  if (provider == 'apple') return Icons.apple;
  if (provider == 'google') return Icons.mail_outline;
  return Icons.chat_bubble_outline;
}
