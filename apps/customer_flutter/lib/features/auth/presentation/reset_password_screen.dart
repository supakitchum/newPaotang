import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_repository.dart';
import '../../../core/i18n/customer_localizations.dart';

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
    final isLineSource = widget.source == 'line';
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.resetPasswordTitle),
        leading: IconButton(
          onPressed: () => context.go('/login'),
          icon: const Icon(Icons.arrow_back_ios_new),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.key_outlined,
                      size: 46,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.resetPasswordHeader,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isLineSource
                          ? l10n.resetPasswordLineDescription
                          : l10n.resetPasswordLinkDescription,
                      textAlign: TextAlign.center,
                    ),
                    if (widget.token.isEmpty) ...[
                      const SizedBox(height: 14),
                      _WarningBox(
                        title: l10n.resetPasswordInvalidTitle,
                        message: l10n.resetPasswordInvalidMessage,
                      ),
                    ],
                    const SizedBox(height: 18),
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
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed:
                          _saving || widget.token.isEmpty ? null : _submit,
                      child: _saving
                          ? const CircularProgressIndicator()
                          : Text(l10n.resetPasswordSave),
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
            source: widget.source == 'line' ? 'line_login' : 'admin_reset_link',
          );
      if (!mounted) return;
      _showSnack(successMessage);
      context.go('/login');
    } catch (error) {
      if (!mounted) return;
      final message = _errorMessage(error) ?? expiredMessage;
      _showSnack(message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _errorMessage(Object error) {
    final data = error is DioException ? error.response?.data : null;
    if (data is Map) {
      return (data['message'] ?? data['error']?['message'])?.toString();
    }
    return null;
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
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
