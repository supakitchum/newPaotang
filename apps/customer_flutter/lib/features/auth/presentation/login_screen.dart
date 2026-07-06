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
import '../../../core/utils/api_errors.dart';
import '../../affiliate/data/affiliate_referral_repository.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _passwordSubmitting = false;
  bool _rememberMe = true;
  bool _showPassword = false;
  String? _socialSubmittingProvider;
  String _formError = '';

  bool get _busy => _passwordSubmitting || _socialSubmittingProvider != null;

  @override
  void initState() {
    super.initState();
    _username.addListener(_clearFormError);
    _password.addListener(_clearFormError);
  }

  @override
  void dispose() {
    _username.removeListener(_clearFormError);
    _password.removeListener(_clearFormError);
    _username.dispose();
    _password.dispose();
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
        decoration: BoxDecoration(
          color: colorScheme.surface,
        ),
        child: SafeArea(
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
                              busy: _busy,
                              passwordSubmitting: _passwordSubmitting,
                              rememberMe: _rememberMe,
                              showPassword: _showPassword,
                              formError: _formError,
                              onRememberMeChanged: (value) => setState(
                                () => _rememberMe = value,
                              ),
                              onTogglePassword: () => setState(
                                () => _showPassword = !_showPassword,
                              ),
                              socialProviders: socialProviders,
                              socialSubmittingProvider:
                                  _socialSubmittingProvider,
                              onLogin: _login,
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
      await ref
          .read(authControllerProvider)
          .loginWithPassword(_username.text.trim(), _password.text);
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
    } catch (error) {
      if (mounted) {
        final redirect = ApiErrorInfo.fromObject(error).operationalRedirectPath;
        if (redirect != null) {
          context.go(redirect);
        } else {
          _showFormError(_errorMessage(error, context.l10n.loginFailed));
        }
      }
    } finally {
      if (mounted) setState(() => _passwordSubmitting = false);
    }
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
      if (mounted) {
        final redirect = ApiErrorInfo.fromObject(error).operationalRedirectPath;
        if (redirect != null) {
          context.go(redirect);
        } else {
          _showFormError(_errorMessage(error, socialFailed));
        }
      }
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
                                    Icons.shield_outlined,
                                    color: colorScheme.onPrimary,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    context.l10n.loginHeroBadge,
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
                            context.l10n.loginTitle,
                            style: textTheme.headlineLarge?.copyWith(
                              color: colorScheme.onPrimary,
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            context.l10n.loginHeroDescription,
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
    required this.busy,
    required this.passwordSubmitting,
    required this.rememberMe,
    required this.showPassword,
    required this.formError,
    required this.onRememberMeChanged,
    required this.onTogglePassword,
    required this.socialProviders,
    required this.socialSubmittingProvider,
    required this.onLogin,
    required this.onSocialLogin,
    required this.onRegister,
    required this.onForgotPassword,
  });

  final TextEditingController username;
  final TextEditingController password;
  final bool busy;
  final bool passwordSubmitting;
  final bool rememberMe;
  final bool showPassword;
  final String formError;
  final ValueChanged<bool> onRememberMeChanged;
  final VoidCallback onTogglePassword;
  final List<SocialAuthProvider> socialProviders;
  final String? socialSubmittingProvider;
  final VoidCallback onLogin;
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
                    fontWeight: FontWeight.w900,
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
              obscureText: !showPassword,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                if (!busy) onLogin();
              },
              decoration: _loginInputDecoration(
                context,
                hintText: l10n.loginPasswordHint,
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  onPressed: busy ? null : onTogglePassword,
                  icon: Icon(
                    showPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
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
                onPressed: busy ? null : onLogin,
                child: passwordSubmitting
                    ? Text(l10n.loginSubmitting)
                    : Text(l10n.loginSubmit),
              ),
            ),
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
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: Checkbox(
                      value: rememberMe,
                      onChanged: enabled
                          ? (value) => onRememberMeChanged(value ?? false)
                          : null,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
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
            fontWeight: FontWeight.w800,
          ),
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
          border: Border.all(
            color: colorScheme.error.withValues(alpha: 0.14),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.error_outline,
                color: colorScheme.error,
                size: 20,
              ),
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
    disabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: colorScheme.outlineVariant.withValues(alpha: 0.72),
      ),
    ),
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
    final backgroundColor = provider.buttonBackgroundColor ??
        (normalizedProvider == 'line' ? brandColor : null);
    final foregroundColor = provider.buttonForegroundColor ??
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
            color: borderColor ??
                colorScheme.outlineVariant.withValues(alpha: 0.90),
          ),
          shape: const StadiumBorder(),
          textStyle: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w900,
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
