import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_error_message.dart';
import '../../../core/auth/auth_repository.dart';
import '../../../core/i18n/customer_localizations.dart';
import '../../../shared/widgets/tenant_brand_header.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, required this.token, this.source});

  final String token;
  final String? source;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _showPassword = false;
  bool _saving = false;

  @override
  void dispose() {
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLineSource = _isLineResetSource;
    final l10n = context.l10n;
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
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight:
                        (constraints.maxHeight - 42).clamp(0, double.infinity),
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: IconButton.filledTonal(
                              onPressed:
                                  _saving ? null : () => context.go('/login'),
                              icon: const Icon(Icons.arrow_back_ios_new),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const _ResetPasswordBrandPanel(),
                          const SizedBox(height: 18),
                          _buildResetCard(
                            context,
                            description: isLineSource
                                ? l10n.resetPasswordLineDescription
                                : l10n.resetPasswordLinkDescription,
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

  Widget _buildResetCard(
    BuildContext context, {
    required String description,
  }) {
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
            CircleAvatar(
              radius: 30,
              backgroundColor: colorScheme.primaryContainer,
              foregroundColor: colorScheme.primary,
              child: const Icon(Icons.key_outlined, size: 34),
            ),
            const SizedBox(height: 14),
            Text(
              l10n.resetPasswordHeader,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
            ),
            if (widget.token.isEmpty) ...[
              const SizedBox(height: 14),
              _WarningBox(
                title: l10n.resetPasswordInvalidTitle,
                message: l10n.resetPasswordInvalidMessage,
              ),
            ],
            const SizedBox(height: 20),
            TextField(
              controller: _password,
              obscureText: !_showPassword,
              decoration: InputDecoration(
                labelText: l10n.resetPasswordNewPassword,
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  onPressed: () => setState(
                    () => _showPassword = !_showPassword,
                  ),
                  icon: Icon(
                    _showPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmPassword,
              obscureText: !_showPassword,
              decoration: InputDecoration(
                labelText: l10n.resetPasswordConfirmNewPassword,
                prefixIcon: const Icon(Icons.shield_outlined),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _saving || widget.token.isEmpty ? null : _submit,
                child: _saving
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      )
                    : Text(l10n.resetPasswordSave),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_password.text.isEmpty || _confirmPassword.text.isEmpty) {
      _showSnack(context.l10n.resetPasswordPasswordRequired);
      return;
    }
    if (_password.text != _confirmPassword.text) {
      _showSnack(context.l10n.authPasswordMismatch);
      return;
    }

    final successMessage = context.l10n.resetPasswordSuccess;
    final expiredMessage = context.l10n.resetPasswordExpired;
    setState(() => _saving = true);
    try {
      await ref.read(authRepositoryProvider).resetPasswordWithToken(
            token: widget.token,
            password: _password.text,
            passwordConfirmation: _confirmPassword.text,
            source: _isLineResetSource ? 'line_login' : 'admin_reset_link',
          );
      if (!mounted) return;
      _showSnack(successMessage);
      context.go('/login');
    } catch (error) {
      if (!mounted) return;
      final message = authErrorMessage(error, expiredMessage);
      _showSnack(message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  bool get _isLineResetSource =>
      normalizeSocialAuthProvider(widget.source ?? '') == 'line';
}

class _ResetPasswordBrandPanel extends StatelessWidget {
  const _ResetPasswordBrandPanel();

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

class _WarningBox extends StatelessWidget {
  const _WarningBox({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 2),
                  Text(message),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
