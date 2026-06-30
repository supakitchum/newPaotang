import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/auth_repository.dart';
import '../../../core/i18n/customer_localizations.dart';
import '../../../core/navigation/customer_link_launcher.dart';
import '../../../core/navigation/customer_redirect.dart';
import '../../../core/tenant/mobile_bootstrap_controller.dart';
import '../../../core/utils/api_errors.dart';
import '../../affiliate/data/affiliate_referral_repository.dart';
import '../../../shared/widgets/tenant_brand_header.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bootstrap = ref.watch(mobileBootstrapProvider);
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight:
                        (constraints.maxHeight - 48).clamp(0, double.infinity),
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const _LoginBrandPanel(),
                          const SizedBox(height: 18),
                          _LoginFormCard(
                            username: _username,
                            password: _password,
                            loading: _loading,
                            onLogin: _login,
                            onRegister: () => context.go(
                              customerRegisterRouteForRedirect(
                                _currentRedirect(),
                              ),
                            ),
                            onForgotPassword: () =>
                                context.go('/forgot-password'),
                          ),
                          const SizedBox(height: 14),
                          bootstrap.when(
                            data: (data) => _SocialLoginPanel(
                              providers: data.authProviders,
                              loading: _loading,
                              onLogin: _socialLogin,
                            ),
                            loading: () => const SizedBox.shrink(),
                            error: (_, __) => const SizedBox.shrink(),
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
      ),
    );
  }

  Future<void> _login() async {
    setState(() => _loading = true);
    try {
      await ref
          .read(authControllerProvider)
          .loginWithPassword(_username.text.trim(), _password.text);
      await ref.read(affiliateReferralServiceProvider).applyStored();
      if (mounted) {
        final auth = ref.read(authControllerProvider);
        final redirect = _currentRedirect();
        context.go(
          auth.pinRequired ? customerPinRouteForRedirect(redirect) : redirect,
        );
      }
    } catch (error) {
      if (mounted) {
        final redirect = ApiErrorInfo.fromObject(error).operationalRedirectPath;
        if (redirect != null) {
          context.go(redirect);
        } else {
          _showSnack(_errorMessage(error, context.l10n.loginFailed));
        }
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _socialLogin(String provider) async {
    setState(() => _loading = true);
    final normalizedProvider = normalizeSocialAuthProvider(provider);
    final socialLinkMissing = context.l10n.socialLoginLinkMissing;
    final socialFailed = context.l10n.socialLoginFailed;
    try {
      final url = await ref
          .read(authRepositoryProvider)
          .socialLoginUrl(normalizedProvider);
      final uri = Uri.tryParse(url);
      if (!isSafeExternalLinkUri(uri)) {
        _showSnack(socialLinkMissing);
        return;
      }
      final opened = await ref
          .read(customerLinkLauncherProvider)
          .openSocialLogin(normalizedProvider, uri!);
      if (!opened) {
        _showSnack(socialFailed);
      }
    } catch (error) {
      if (mounted) {
        final redirect = ApiErrorInfo.fromObject(error).operationalRedirectPath;
        if (redirect != null) {
          context.go(redirect);
        } else {
          _showSnack(_errorMessage(error, socialFailed));
        }
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _errorMessage(Object error, String fallback) {
    final message = ApiErrorInfo.fromObject(error).message;
    if (message.trim().isNotEmpty) {
      return message;
    }
    return fallback;
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
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _LoginBrandPanel extends StatelessWidget {
  const _LoginBrandPanel();

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

class _LoginFormCard extends StatelessWidget {
  const _LoginFormCard({
    required this.username,
    required this.password,
    required this.loading,
    required this.onLogin,
    required this.onRegister,
    required this.onForgotPassword,
  });

  final TextEditingController username;
  final TextEditingController password;
  final bool loading;
  final VoidCallback onLogin;
  final VoidCallback onRegister;
  final VoidCallback onForgotPassword;

  @override
  Widget build(BuildContext context) {
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
              l10n.loginTitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 22),
            TextField(
              controller: username,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: l10n.loginIdentifierLabel,
                prefixIcon: const Icon(Icons.phone_android_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: password,
              obscureText: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                if (!loading) onLogin();
              },
              decoration: InputDecoration(
                labelText: l10n.loginPasswordLabel,
                prefixIcon: const Icon(Icons.lock_outline),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: loading ? null : onLogin,
                child: loading
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      )
                    : Text(l10n.loginSubmit),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                TextButton(
                  onPressed: loading ? null : onRegister,
                  child: Text(l10n.loginRegister),
                ),
                TextButton(
                  onPressed: loading ? null : onForgotPassword,
                  child: Text(l10n.loginForgotPassword),
                ),
              ],
            ),
            Container(
              height: 1,
              margin: const EdgeInsets.only(top: 6),
              color: colorScheme.outlineVariant.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }
}

class _SocialLoginPanel extends StatelessWidget {
  const _SocialLoginPanel({
    required this.providers,
    required this.loading,
    required this.onLogin,
  });

  final List<SocialAuthProvider> providers;
  final bool loading;
  final ValueChanged<String> onLogin;

  @override
  Widget build(BuildContext context) {
    final enabledProviders = providers
        .where((provider) => provider.enabled && provider.provider.isNotEmpty)
        .toList(growable: false);
    if (enabledProviders.isEmpty) return const SizedBox.shrink();

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
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var index = 0; index < enabledProviders.length; index++) ...[
              _SocialLoginButton(
                provider: enabledProviders[index],
                loading: loading,
                onPressed: () => onLogin(enabledProviders[index].provider),
              ),
              if (index < enabledProviders.length - 1)
                const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _SocialLoginButton extends StatelessWidget {
  const _SocialLoginButton({
    required this.provider,
    required this.loading,
    required this.onPressed,
  });

  final SocialAuthProvider provider;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: loading ? null : onPressed,
        icon: Icon(_providerIcon(provider.provider)),
        label: Text(
          context.l10n.socialLoginLabel(provider.label),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

IconData _providerIcon(String provider) {
  final normalizedProvider = normalizeSocialAuthProvider(provider);
  if (normalizedProvider == 'apple') return Icons.apple;
  if (normalizedProvider == 'google') return Icons.mail_outline;
  return Icons.chat_bubble_outline;
}
