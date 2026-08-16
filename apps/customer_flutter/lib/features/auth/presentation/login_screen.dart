import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:passkeys/types.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/auth_error_message.dart';
import '../../../core/auth/auth_repository.dart';
import '../../../core/auth/customer_passkey_repository.dart';
import '../../../core/auth/native_line_auth_service.dart';
import '../../../core/i18n/customer_localizations.dart';
import '../../../core/navigation/customer_link_launcher.dart';
import '../../../core/navigation/customer_redirect.dart';
import '../../../core/tenant/mobile_bootstrap_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/utils/customer_operational_error.dart';
import '../../affiliate/data/affiliate_referral_repository.dart';
import 'auth_keyboard.dart';
import 'auth_visual_tokens.dart';
import 'login_otp_screen.dart';
import 'line_auth_screens.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

enum _LoginStep { phone, password }

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _phoneFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  bool _otpSubmitting = false;
  bool _passwordSubmitting = false;
  bool _passkeySubmitting = false;
  _LoginStep _loginStep = _LoginStep.phone;
  bool _rememberMe = true;
  bool _showPassword = false;
  String? _socialSubmittingProvider;
  String _formError = '';

  bool get _busy =>
      _otpSubmitting ||
      _passwordSubmitting ||
      _passkeySubmitting ||
      _socialSubmittingProvider != null;

  @override
  void initState() {
    super.initState();
    _username.addListener(_clearFormError);
    _password.addListener(_clearFormError);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final fallbackPhone = ref.read(loginPasswordFallbackPhoneProvider).trim();
      if (!mounted || fallbackPhone.isEmpty) return;
      ref.read(loginPasswordFallbackPhoneProvider.notifier).state = '';
      setState(() {
        _username.text = fallbackPhone;
        _loginStep = _LoginStep.password;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _passwordFocusNode.requestFocus();
      });
    });
  }

  @override
  void dispose() {
    _username.removeListener(_clearFormError);
    _password.removeListener(_clearFormError);
    _username.dispose();
    _password.dispose();
    _phoneFocusNode.dispose();
    _passwordFocusNode.dispose();
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
    final passkeyAvailable =
        ref.watch(customerPasskeyAvailabilityProvider).valueOrNull ?? false;

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
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
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
                              phoneFocusNode: _phoneFocusNode,
                              passwordFocusNode: _passwordFocusNode,
                              loginStep: _loginStep,
                              busy: _busy,
                              otpSubmitting: _otpSubmitting,
                              passwordSubmitting: _passwordSubmitting,
                              passkeySubmitting: _passkeySubmitting,
                              passkeyAvailable: passkeyAvailable,
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
                              onOtpLogin: _requestLoginOtp,
                              onPasswordLogin: _loginWithPassword,
                              onChangePhone: _changePhone,
                              onPasskeyLogin: _passkeyLogin,
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

  Future<void> _requestLoginOtp() async {
    if (_busy) return;
    final phone = _username.text.trim();
    if (!RegExp(r'^\d{9,10}$').hasMatch(phone)) {
      _showFormError(context.l10n.authPhoneInvalid);
      return;
    }

    final keyboardDismissal = dismissAuthKeyboard(
      context,
      waitForAnimation: true,
      finishAutofillContext: true,
    );
    ref.read(loginOtpFlowProvider.notifier).state = null;
    setState(() {
      _formError = '';
      _otpSubmitting = true;
    });
    await keyboardDismissal;
    if (!mounted) return;

    try {
      final challenge = await ref
          .read(authControllerProvider)
          .requestLoginOtp(phone);
      if (!mounted) return;
      final redirect = _currentRedirect();
      ref.read(loginOtpFlowProvider.notifier).state = LoginOtpFlowState(
        challenge: challenge,
        redirect: redirect,
        phone: phone,
      );
      context.go(customerLoginOtpRouteForRedirect(redirect));
    } catch (error) {
      if (!mounted) return;
      final handled = await handleCustomerOperationalError(
        ref: ref,
        context: context,
        error: error,
        returnPathOverride: _currentRedirect(),
      );
      if (!mounted || handled) return;
      _showFormError(
        loginErrorMessage(
          error,
          context.l10n,
          fallback: context.l10n.loginOtpRequestFailed,
        ),
      );
    } finally {
      if (mounted) setState(() => _otpSubmitting = false);
    }
  }

  Future<void> _loginWithPassword() async {
    if (_busy) return;
    final username = _username.text.trim();
    final password = _password.text;
    final keyboardDismissal = dismissAuthKeyboard(
      context,
      waitForAnimation: true,
      finishAutofillContext: true,
    );
    ref.read(loginOtpFlowProvider.notifier).state = null;
    setState(() {
      _formError = '';
      _passwordSubmitting = true;
    });
    await keyboardDismissal;
    if (!mounted) return;
    try {
      await ref
          .read(authControllerProvider)
          .loginWithPassword(username, password);
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
      if (!mounted) return;
      final redirect = _currentRedirect();
      ref.read(loginOtpFlowProvider.notifier).state = LoginOtpFlowState(
        challenge: required.challenge,
        redirect: redirect,
        phone: username,
      );
      context.go(customerLoginOtpRouteForRedirect(redirect));
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

  void _changePhone() {
    if (_busy || _loginStep == _LoginStep.phone) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _formError = '';
      _loginStep = _LoginStep.phone;
      _password.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _phoneFocusNode.requestFocus();
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
      if (normalizedProvider == 'line') {
        final nativeResult = await ref
            .read(nativeLineAuthServiceProvider)
            .authenticate(redirect: _currentRedirect());
        if (!mounted) return;
        if (nativeResult != null) {
          final completed = await completeSocialAuthentication(
            context: context,
            ref: ref,
            result: nativeResult,
            fallbackRedirect: _currentRedirect(),
          );
          if (!mounted || completed) return;
          _showFormError(
            nativeResult.message.isEmpty ? socialFailed : nativeResult.message,
          );
          return;
        }
      }

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
    } on NativeLineLoginCancelled {
      return;
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

  Future<void> _passkeyLogin() async {
    if (_busy) return;
    final keyboardDismissal = dismissAuthKeyboard(
      context,
      waitForAnimation: true,
      finishAutofillContext: true,
    );
    setState(() {
      _formError = '';
      _passkeySubmitting = true;
    });
    await keyboardDismissal;
    if (!mounted) return;

    try {
      await ref.read(authControllerProvider).loginWithPasskey();
      await ref.read(affiliateReferralServiceProvider).applyStored();
      if (!mounted) return;
      final auth = ref.read(authControllerProvider);
      context.go(
        customerPostAuthRouteForRedirect(
          redirect: _currentRedirect(),
          pinRequired: auth.pinRequired,
          pinSetupRequired: auth.pinSetupRequired,
        ),
      );
    } on PasskeyAuthCancelledException {
      // Cancelling the native account picker leaves the login form unchanged.
    } catch (error) {
      if (!mounted) return;
      final handled = await handleCustomerOperationalError(
        ref: ref,
        context: context,
        error: error,
        returnPathOverride: _currentRedirect(),
      );
      if (!mounted || handled) return;
      _showFormError(_passkeyErrorMessage(error));
    } finally {
      if (mounted) setState(() => _passkeySubmitting = false);
    }
  }

  String _passkeyErrorMessage(Object error) {
    final l10n = context.l10n;
    return switch (error) {
      NoCredentialsAvailableException() => l10n.passkeyNoCredentials,
      DomainNotAssociatedException() => l10n.passkeyDomainNotAssociated,
      DeviceNotSupportedException() ||
      PasskeyUnsupportedException() => l10n.passkeyUnsupported,
      MissingGoogleSignInException() ||
      SyncAccountNotAvailableException() => l10n.passkeyAccountUnavailable,
      TimeoutException() => l10n.passkeyTimeout,
      _ => authErrorMessage(error, l10n.passkeyLoginFailed),
    };
  }

  String _errorMessage(Object error, String fallback) {
    return loginErrorMessage(error, context.l10n, fallback: fallback);
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
    required this.phoneFocusNode,
    required this.passwordFocusNode,
    required this.loginStep,
    required this.busy,
    required this.otpSubmitting,
    required this.passwordSubmitting,
    required this.passkeySubmitting,
    required this.passkeyAvailable,
    required this.rememberMe,
    required this.showPassword,
    required this.formError,
    required this.onRememberMeChanged,
    required this.onTogglePassword,
    required this.socialProviders,
    required this.socialSubmittingProvider,
    required this.onOtpLogin,
    required this.onPasswordLogin,
    required this.onChangePhone,
    required this.onPasskeyLogin,
    required this.onSocialLogin,
    required this.onRegister,
    required this.onForgotPassword,
  });

  final TextEditingController username;
  final TextEditingController password;
  final FocusNode phoneFocusNode;
  final FocusNode passwordFocusNode;
  final _LoginStep loginStep;
  final bool busy;
  final bool otpSubmitting;
  final bool passwordSubmitting;
  final bool passkeySubmitting;
  final bool passkeyAvailable;
  final bool rememberMe;
  final bool showPassword;
  final String formError;
  final ValueChanged<bool> onRememberMeChanged;
  final VoidCallback onTogglePassword;
  final List<SocialAuthProvider> socialProviders;
  final String? socialSubmittingProvider;
  final VoidCallback onOtpLogin;
  final VoidCallback onPasswordLogin;
  final VoidCallback onChangePhone;
  final VoidCallback onPasskeyLogin;
  final ValueChanged<String> onSocialLogin;
  final VoidCallback onRegister;
  final VoidCallback onForgotPassword;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final isPhoneStep = loginStep == _LoginStep.phone;
    final isPasswordStep = loginStep == _LoginStep.password;
    final title = switch (loginStep) {
      _LoginStep.phone => l10n.loginFormTitle,
      _LoginStep.password => l10n.loginPasswordFormTitle,
    };
    final description = switch (loginStep) {
      _LoginStep.phone => l10n.loginFormDescription,
      _LoginStep.password => l10n.loginPasswordFormDescription,
    };
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
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: colorScheme.onSurface,
                fontSize: 23,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
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
              key: const ValueKey('login-phone-input'),
              controller: username,
              focusNode: phoneFocusNode,
              enabled: !busy,
              readOnly: !isPhoneStep,
              enableInteractiveSelection: isPhoneStep,
              autofillHints: const [AutofillHints.telephoneNumber],
              style: authInputTextStyle(context),
              keyboardType: TextInputType.phone,
              textInputAction: isPhoneStep
                  ? TextInputAction.done
                  : TextInputAction.none,
              onSubmitted: isPhoneStep
                  ? (_) {
                      if (busy) return;
                      FocusManager.instance.primaryFocus?.unfocus(
                        disposition: UnfocusDisposition.scope,
                      );
                      onOtpLogin();
                    }
                  : null,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              decoration: _loginInputDecoration(
                context,
                hintText: l10n.loginIdentifierHint,
                prefixIcon: const Icon(Icons.phone_android_outlined),
                suffixIcon: isPhoneStep
                    ? null
                    : authInputActionButton(
                        context,
                        onPressed: busy ? null : onChangePhone,
                        icon: Icons.edit_outlined,
                        tooltip: l10n.loginOtpChangePhone,
                      ),
              ),
            ),
            if (isPasswordStep) ...[
              const SizedBox(height: 16),
              _LoginFieldLabel(label: l10n.loginPasswordLabel),
              const SizedBox(height: 8),
              TextField(
                key: const ValueKey('login-password-input'),
                controller: password,
                focusNode: passwordFocusNode,
                enabled: !busy,
                autofillHints: const [AutofillHints.password],
                style: authInputTextStyle(context),
                obscureText: !showPassword,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) {
                  if (busy) return;
                  FocusManager.instance.primaryFocus?.unfocus(
                    disposition: UnfocusDisposition.scope,
                  );
                  onPasswordLogin();
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
              const SizedBox(height: 8),
              _LoginOptionsRow(
                rememberMe: rememberMe,
                enabled: !busy,
                onRememberMeChanged: onRememberMeChanged,
                onForgotPassword: onForgotPassword,
              ),
              const SizedBox(height: 12),
              authPrimaryActionButton(
                onPressed: busy ? null : onPasswordLogin,
                height: 54,
                fontSize: 18,
                label: passwordSubmitting
                    ? l10n.loginSubmitting
                    : l10n.loginSubmit,
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                key: const ValueKey('login-use-otp'),
                onPressed: busy ? null : onOtpLogin,
                icon: const Icon(Icons.sms_outlined),
                label: Text(
                  otpSubmitting ? l10n.loginPhoneSubmitting : l10n.loginUseOtp,
                ),
              ),
            ],
            if (isPhoneStep) ...[
              const SizedBox(height: 12),
              authPrimaryActionButton(
                onPressed: busy ? null : onOtpLogin,
                height: 54,
                fontSize: 18,
                label: otpSubmitting
                    ? l10n.loginPhoneSubmitting
                    : l10n.loginPhoneSubmit,
              ),
              _SocialLoginPanel(
                providers: socialProviders,
                loading: busy,
                submittingProvider: socialSubmittingProvider,
                passkeyAvailable: passkeyAvailable,
                passkeySubmitting: passkeySubmitting,
                onPasskeyLogin: onPasskeyLogin,
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
    required this.passkeyAvailable,
    required this.passkeySubmitting,
    required this.onPasskeyLogin,
    required this.onLogin,
  });

  final List<SocialAuthProvider> providers;
  final bool loading;
  final String? submittingProvider;
  final bool passkeyAvailable;
  final bool passkeySubmitting;
  final VoidCallback onPasskeyLogin;
  final ValueChanged<String> onLogin;

  @override
  Widget build(BuildContext context) {
    final enabledProviders = _visibleSocialProviders(providers);
    if (enabledProviders.isEmpty && !passkeyAvailable) {
      return const SizedBox.shrink();
    }
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
        const SizedBox(height: 14),
        Wrap(
          key: const ValueKey('login-social-provider-row'),
          alignment: WrapAlignment.center,
          runAlignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 10,
          children: [
            for (final provider in enabledProviders)
              _SocialLoginButton(
                provider: provider,
                loading: loading,
                submittingProvider: submittingProvider,
                onPressed: () => onLogin(provider.provider),
              ),
            if (passkeyAvailable)
              _PasskeyLoginButton(
                loading: loading,
                submitting: passkeySubmitting,
                onPressed: onPasskeyLogin,
              ),
          ],
        ),
      ],
    );
  }
}

class _PasskeyLoginButton extends StatelessWidget {
  const _PasskeyLoginButton({
    required this.loading,
    required this.submitting,
    required this.onPressed,
  });

  final bool loading;
  final bool submitting;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final label = submitting
        ? context.l10n.passkeyLoginSubmitting
        : context.l10n.passkeyLogin;

    return SizedBox.square(
      dimension: 48,
      child: IconButton(
        key: const ValueKey('login-passkey-button'),
        tooltip: label,
        style: IconButton.styleFrom(
          backgroundColor: colorScheme.surface,
          foregroundColor: colorScheme.primary,
          disabledBackgroundColor: colorScheme.surface.withValues(alpha: 0.62),
          disabledForegroundColor: colorScheme.primary.withValues(alpha: 0.48),
          side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.34)),
          shape: const CircleBorder(),
          padding: const EdgeInsets.all(12),
        ),
        onPressed: loading ? null : onPressed,
        icon: submitting
            ? SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: colorScheme.primary,
                ),
              )
            : const Icon(Icons.key_rounded, size: 22),
      ),
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
    final brandColor =
        provider.brandColor ??
        _defaultSocialProviderBrandColor(normalizedProvider, colorScheme);
    final backgroundColor =
        provider.buttonBackgroundColor ?? colorScheme.surface;
    final foregroundColor =
        provider.buttonForegroundColor ??
        (provider.buttonBackgroundColor == null
            ? brandColor
            : colorScheme.onPrimary);
    final label = context.l10n.socialLoginLabel(provider.label);

    return SizedBox.square(
      dimension: 48,
      child: IconButton(
        key: ValueKey('social-login-$normalizedProvider'),
        tooltip: label,
        style: IconButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          disabledBackgroundColor: backgroundColor.withValues(alpha: 0.62),
          disabledForegroundColor: foregroundColor.withValues(alpha: 0.48),
          side: BorderSide(color: brandColor.withValues(alpha: 0.42)),
          shape: const CircleBorder(),
          padding: const EdgeInsets.all(12),
        ),
        onPressed: loading ? null : onPressed,
        icon: isSubmitting
            ? SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: foregroundColor,
                ),
              )
            : Image.asset(
                _providerLogoAsset(normalizedProvider),
                width: 22,
                height: 22,
                color: foregroundColor,
                colorBlendMode: BlendMode.srcIn,
                filterQuality: FilterQuality.high,
                excludeFromSemantics: true,
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

String _providerLogoAsset(String provider) {
  return 'assets/images/social/$provider.png';
}

Color _defaultSocialProviderBrandColor(
  String provider,
  ColorScheme colorScheme,
) {
  return switch (provider) {
    'line' => const Color(0xFF06C755),
    'google' => const Color(0xFF4285F4),
    'apple' => const Color(0xFF000000),
    'facebook' => const Color(0xFF1877F2),
    _ => colorScheme.primary,
  };
}
