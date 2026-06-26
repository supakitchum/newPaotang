import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/auth_repository.dart';
import '../../../core/i18n/customer_localizations.dart';
import '../../../core/utils/api_errors.dart';

class LineCallbackScreen extends ConsumerStatefulWidget {
  const LineCallbackScreen({
    super.key,
    required this.query,
    this.provider = 'line',
  });

  final Map<String, String> query;
  final String provider;

  @override
  ConsumerState<LineCallbackScreen> createState() => _LineCallbackScreenState();
}

class _LineCallbackScreenState extends ConsumerState<LineCallbackScreen> {
  String? _status;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleCallback());
  }

  @override
  Widget build(BuildContext context) {
    final providerLabel = _ProviderBrand.label(widget.provider);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor:
                          _ProviderBrand.color(widget.provider).withValues(
                        alpha: 0.12,
                      ),
                      child: Icon(
                        _ProviderBrand.icon(widget.provider),
                        color: _ProviderBrand.color(widget.provider),
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.l10n.socialCallbackTitle,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _status ??
                          context.l10n.socialCallbackWaiting(providerLabel),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 18),
                    const CircularProgressIndicator(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleCallback() async {
    final providerLabel = _ProviderBrand.label(widget.provider);
    if (widget.query['code']?.isEmpty ?? true) {
      setState(() {
        _status = context.l10n.socialCallbackMissingCode(providerLabel);
      });
      return;
    }

    try {
      final result = await ref.read(authRepositoryProvider).socialCallback(
            provider: widget.provider,
            query: Map<String, dynamic>.from(widget.query),
          );
      if (!mounted) return;

      if (result.passwordResetReady && result.passwordResetToken.isNotEmpty) {
        context.go(
          Uri(
            path: '/reset-password',
            queryParameters: {
              'token': result.passwordResetToken,
              'source': 'line',
            },
          ).toString(),
        );
        return;
      }

      if (result.lineLinkRequired && result.linkToken.isNotEmpty) {
        context.go(
          Uri(
            path: '/social/${result.provider}/link-phone',
            queryParameters: {
              'token': result.linkToken,
              'name': result.displayName,
              'picture_url': result.pictureUrl,
              'redirect': '/',
            },
          ).toString(),
        );
        return;
      }

      if (result.session != null) {
        ref.read(authControllerProvider).applySession(result.session!);
        context.go(result.session!.pinRequired ? '/pin' : '/');
        return;
      }

      setState(() {
        _status = result.message.isEmpty
            ? context.l10n.socialCallbackFailed(providerLabel)
            : result.message;
      });
    } catch (error) {
      if (!mounted) return;
      final redirect = ApiErrorInfo.fromObject(error).operationalRedirectPath;
      if (redirect != null) {
        context.go(redirect);
        return;
      }
      setState(() {
        _status = context.l10n.socialCallbackConnectFailed(providerLabel);
      });
    }
  }
}

class LineLinkPhoneScreen extends ConsumerStatefulWidget {
  const LineLinkPhoneScreen({
    super.key,
    required this.linkToken,
    this.provider = 'line',
    this.displayName = '',
    this.pictureUrl = '',
    this.redirect = '/',
  });

  final String linkToken;
  final String provider;
  final String displayName;
  final String pictureUrl;
  final String redirect;

  @override
  ConsumerState<LineLinkPhoneScreen> createState() =>
      _LineLinkPhoneScreenState();
}

class _LineLinkPhoneScreenState extends ConsumerState<LineLinkPhoneScreen> {
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _showPassword = false;
  bool _saving = false;

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final providerLabel = _ProviderBrand.label(widget.provider);
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.socialLinkTitle(providerLabel)),
        leading: IconButton(
          onPressed: () => context.go('/login'),
          icon: const Icon(Icons.arrow_back_ios_new),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _LineProfileCard(
              provider: widget.provider,
              name: widget.displayName,
              pictureUrl: widget.pictureUrl,
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.socialLinkPhoneTitle,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    Text(l10n.socialLinkPhoneSubtitle),
                    const SizedBox(height: 16),
                    TextField(
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
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _password,
                      obscureText: !_showPassword,
                      decoration: InputDecoration(
                        labelText: l10n.registerPasswordLabel,
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
                        labelText: l10n.registerConfirmPasswordLabel,
                        prefixIcon: const Icon(Icons.shield_outlined),
                      ),
                    ),
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: _saving ? null : _submit,
                      child: _saving
                          ? const CircularProgressIndicator()
                          : Text(l10n.socialLinkSubmit),
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
    final phone = _phone.text.replaceAll(RegExp(r'\D'), '');
    final providerLabel = _ProviderBrand.label(widget.provider);
    if (widget.linkToken.isEmpty) {
      _showSnack(context.l10n.socialLinkMissing(providerLabel));
      return;
    }
    if (!RegExp(r'^\d{9,10}$').hasMatch(phone)) {
      _showSnack(context.l10n.authPhoneInvalid);
      return;
    }
    if (_password.text != _confirmPassword.text) {
      _showSnack(context.l10n.authPasswordMismatch);
      return;
    }

    final failedMessage = context.l10n.socialLinkFailed(providerLabel);
    setState(() => _saving = true);
    try {
      final session = await ref.read(authRepositoryProvider).socialLinkPhone(
            provider: widget.provider,
            linkToken: widget.linkToken,
            phone: phone,
            password: _password.text,
            passwordConfirmation: _confirmPassword.text,
          );
      ref.read(authControllerProvider).applySession(session);
      if (!mounted) return;
      final redirect = _safeRedirect(widget.redirect);
      context.go(session.pinRequired ? '/pin' : redirect);
    } catch (error) {
      if (!mounted) return;
      final redirect = ApiErrorInfo.fromObject(error).operationalRedirectPath;
      if (redirect != null) {
        context.go(redirect);
      } else {
        _showSnack(_errorMessage(error) ?? failedMessage);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _safeRedirect(String value) {
    return value.startsWith('/') && !value.startsWith('//') ? value : '/';
  }

  String? _errorMessage(Object error) {
    final message = ApiErrorInfo.fromObject(error).message;
    return message.trim().isEmpty ? null : message;
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _LineProfileCard extends StatelessWidget {
  const _LineProfileCard({
    required this.provider,
    required this.name,
    required this.pictureUrl,
  });

  final String provider;
  final String name;
  final String pictureUrl;

  @override
  Widget build(BuildContext context) {
    final providerLabel = _ProviderBrand.label(provider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: _ProviderBrand.color(provider),
              backgroundImage:
                  pictureUrl.isEmpty ? null : NetworkImage(pictureUrl),
              child: pictureUrl.isEmpty
                  ? Icon(_ProviderBrand.icon(provider), color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.socialProfileAccount(providerLabel),
                    style: TextStyle(
                      color: _ProviderBrand.color(provider),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    name.isEmpty
                        ? context.l10n.socialProfileFallbackName(providerLabel)
                        : name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  Text(context.l10n.socialProfileReady),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProviderBrand {
  const _ProviderBrand._();

  static String label(String provider) {
    return switch (provider.trim().toLowerCase()) {
      'google' => 'Google',
      'apple' => 'Apple ID',
      _ => 'LINE',
    };
  }

  static IconData icon(String provider) {
    return switch (provider.trim().toLowerCase()) {
      'google' => Icons.mail_outline,
      'apple' => Icons.apple,
      _ => Icons.chat_bubble_outline,
    };
  }

  static Color color(String provider) {
    return switch (provider.trim().toLowerCase()) {
      'google' => const Color(0xff4285f4),
      'apple' => Colors.black,
      _ => const Color(0xff06c755),
    };
  }
}
