import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/auth_repository.dart';
import '../../../core/i18n/customer_localizations.dart';
import '../../../core/navigation/customer_link_launcher.dart';
import '../../../core/tenant/mobile_bootstrap_controller.dart';
import '../../../core/utils/api_errors.dart';
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
    final l10n = context.l10n;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 32),
            const TenantBrandHeader(),
            const SizedBox(height: 24),
            Text(
              l10n.loginTitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _username,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: l10n.loginIdentifierLabel),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: InputDecoration(labelText: l10n.loginPasswordLabel),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _loading ? null : _login,
              child: _loading
                  ? const CircularProgressIndicator()
                  : Text(l10n.loginSubmit),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: _loading ? null : () => context.go('/register'),
                  child: Text(l10n.loginRegister),
                ),
                TextButton(
                  onPressed:
                      _loading ? null : () => context.go('/forgot-password'),
                  child: Text(l10n.loginForgotPassword),
                ),
              ],
            ),
            const SizedBox(height: 8),
            bootstrap.when(
              data: (data) => Column(
                children: [
                  for (final provider in data.authProviders)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: OutlinedButton.icon(
                        onPressed: _loading
                            ? null
                            : () => _socialLogin(provider.provider),
                        icon: Icon(_providerIcon(provider.provider)),
                        label: Text(l10n.socialLoginLabel(provider.label)),
                      ),
                    ),
                ],
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
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
      if (mounted) context.go('/');
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
    final socialLinkMissing = context.l10n.socialLoginLinkMissing;
    final socialFailed = context.l10n.socialLoginFailed;
    try {
      final url =
          await ref.read(authRepositoryProvider).socialLoginUrl(provider);
      final uri = Uri.tryParse(url);
      if (uri == null) {
        _showSnack(socialLinkMissing);
        return;
      }
      final opened = await ref
          .read(customerLinkLauncherProvider)
          .openSocialLogin(provider, uri);
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

  IconData _providerIcon(String provider) {
    if (provider == 'apple') return Icons.apple;
    if (provider == 'google') return Icons.mail_outline;
    return Icons.chat_bubble_outline;
  }

  String _errorMessage(Object error, String fallback) {
    final message = ApiErrorInfo.fromObject(error).message;
    if (message.trim().isNotEmpty) {
      return message;
    }
    return fallback;
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
