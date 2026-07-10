import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_error_message.dart';
import '../../../core/auth/auth_repository.dart';
import '../../../core/i18n/customer_localizations.dart';
import '../../../core/theme/app_theme.dart';
import 'auth_visual_tokens.dart';

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
  bool _showConfirmPassword = false;
  bool _saving = false;
  String _formError = '';

  @override
  void initState() {
    super.initState();
    _password.addListener(_clearFormError);
    _confirmPassword.addListener(_clearFormError);
  }

  @override
  void dispose() {
    _password.removeListener(_clearFormError);
    _confirmPassword.removeListener(_clearFormError);
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
      backgroundColor: colorScheme.surfaceContainerLowest,
      body: ColoredBox(
        color: colorScheme.surface,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final description = isLineSource
                  ? l10n.resetPasswordLineDescription
                  : l10n.resetPasswordLinkDescription;
              return ListView(
                padding: EdgeInsets.zero,
                children: [
                  _ResetPasswordHeroSection(
                    minHeight: constraints.maxWidth >= 720 ? 280 : 250,
                    description: description,
                    onBack: _saving ? null : () => context.go('/login'),
                  ),
                  _ResetPasswordSheet(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: _buildResetCard(context),
                      ),
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

  Widget _buildResetCard(
    BuildContext context,
  ) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.72),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.08),
            blurRadius: 36,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.token.isEmpty) ...[
              _WarningBox(
                title: l10n.resetPasswordInvalidTitle,
                message: l10n.resetPasswordInvalidMessage,
              ),
              const SizedBox(height: 16),
            ],
            Text(
              l10n.resetPasswordHeader,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: colorScheme.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.resetPasswordCardDescription,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                  ),
            ),
            if (_formError.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              _ResetPasswordErrorPanel(message: _formError),
            ],
            const SizedBox(height: 18),
            _ResetPasswordFieldLabel(label: l10n.resetPasswordNewPassword),
            const SizedBox(height: 8),
            TextField(
              controller: _password,
              style: authInputTextStyle(context, fontWeight: FontWeight.w800),
              obscureText: !_showPassword,
              decoration: _resetPasswordInputDecoration(
                context,
                hintText: l10n.resetPasswordNewPasswordHint,
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: authInputActionButton(
                  context,
                  onPressed: _saving
                      ? null
                      : () => setState(
                            () => _showPassword = !_showPassword,
                          ),
                  icon: _showPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  tooltip: _showPassword
                      ? l10n.resetPasswordHidePassword
                      : l10n.resetPasswordShowPassword,
                ),
              ),
            ),
            const SizedBox(height: 18),
            _ResetPasswordFieldLabel(
              label: l10n.resetPasswordConfirmNewPassword,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _confirmPassword,
              style: authInputTextStyle(context, fontWeight: FontWeight.w800),
              obscureText: !_showConfirmPassword,
              decoration: _resetPasswordInputDecoration(
                context,
                hintText: l10n.resetPasswordConfirmNewPasswordHint,
                prefixIcon: const Icon(Icons.shield_outlined),
                suffixIcon: authInputActionButton(
                  context,
                  onPressed: _saving
                      ? null
                      : () => setState(
                            () => _showConfirmPassword = !_showConfirmPassword,
                          ),
                  icon: _showConfirmPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  tooltip: _showConfirmPassword
                      ? l10n.resetPasswordHidePassword
                      : l10n.resetPasswordShowPassword,
                ),
              ),
            ),
            const SizedBox(height: 22),
            authPrimaryActionButton(
              onPressed: _saving || widget.token.isEmpty ? null : _submit,
              label: _saving
                  ? l10n.resetPasswordSubmitting
                  : l10n.resetPasswordSave,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_password.text.isEmpty || _confirmPassword.text.isEmpty) {
      _showFormError(context.l10n.resetPasswordPasswordRequired);
      return;
    }
    if (_password.text != _confirmPassword.text) {
      _showFormError(context.l10n.authPasswordMismatch);
      return;
    }

    final expiredMessage = context.l10n.resetPasswordExpired;
    setState(() {
      _formError = '';
      _saving = true;
    });
    try {
      await ref.read(authRepositoryProvider).resetPasswordWithToken(
            token: widget.token,
            password: _password.text,
            passwordConfirmation: _confirmPassword.text,
            source: _isLineResetSource ? 'line_login' : 'admin_reset_link',
          );
      if (!mounted) return;
      context.go('/login');
    } catch (error) {
      if (!mounted) return;
      final message = authErrorMessage(error, expiredMessage);
      _showFormError(message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _clearFormError() {
    if (_formError.isEmpty || !mounted || _saving) return;
    setState(() => _formError = '');
  }

  void _showFormError(String message) {
    if (!mounted) return;
    final normalized = message.trim();
    if (normalized.isEmpty) return;
    setState(() => _formError = normalized);
  }

  bool get _isLineResetSource =>
      normalizeSocialAuthProvider(widget.source ?? '') == 'line';
}

class _ResetPasswordErrorPanel extends StatelessWidget {
  const _ResetPasswordErrorPanel({required this.message});

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

class _ResetPasswordHeroSection extends StatelessWidget {
  const _ResetPasswordHeroSection({
    required this.minHeight,
    required this.description,
    required this.onBack,
  });

  final double minHeight;
  final String description;
  final VoidCallback? onBack;

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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            authBlueHeroTopRow(
              context,
              title: context.l10n.resetPasswordTitle,
              tooltip: context.l10n.commonBack,
              onBack: onBack,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 42),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 330),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.key_outlined,
                      color: colorScheme.onPrimary,
                      size: 34,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      context.l10n.resetPasswordTitle,
                      textAlign: TextAlign.center,
                      style: textTheme.headlineSmall?.copyWith(
                        color: colorScheme.onPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description,
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onPrimary.withValues(alpha: 0.92),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.55,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResetPasswordSheet extends StatelessWidget {
  const _ResetPasswordSheet({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Transform.translate(
      offset: const Offset(0, -34),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 34),
          child: child,
        ),
      ),
    );
  }
}

class _ResetPasswordFieldLabel extends StatelessWidget {
  const _ResetPasswordFieldLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w900,
          ),
    );
  }
}

InputDecoration _resetPasswordInputDecoration(
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
    softFill: true,
  );
}

class _WarningBox extends StatelessWidget {
  const _WarningBox({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.tertiaryContainer.withValues(alpha: 0.54),
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(
          color: colorScheme.tertiary.withValues(alpha: 0.22),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: colorScheme.onTertiaryContainer,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: colorScheme.onTertiaryContainer,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onTertiaryContainer,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
