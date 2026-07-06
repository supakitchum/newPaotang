import 'dart:convert' as convert;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/auth_error_message.dart';
import '../../../core/auth/auth_repository.dart';
import '../../../core/i18n/customer_localizations.dart';
import '../../../core/navigation/customer_redirect.dart';
import '../../../core/tenant/mobile_bootstrap_controller.dart';
import '../../../core/utils/api_errors.dart';
import '../../affiliate/data/affiliate_referral_repository.dart';

const _socialCallbackWrapperKeys = [
  'social_callback',
  'socialCallback',
  'social_callback_result',
  'socialCallbackResult',
  'callback',
  'callbackData',
  'callback_data',
  'callback_result',
  'callbackResult',
  'social',
  'auth',
  'resource',
  'data',
  'result',
  'payload',
  'authorization',
  'authorizationResponse',
  'authorization_response',
  'oauth',
  'oauth2',
  'providerPayload',
  'provider_payload',
  'providerData',
  'provider_data',
  'metadata',
  'meta',
  'context',
  'details',
  'detail',
  'attributes',
  'credentials',
];

const _socialCallbackCodeKeys = [
  'code',
  'authorization_code',
  'authorizationCode',
  'auth_code',
  'authCode',
  'oauth_code',
  'oauthCode',
  'provider_code',
  'providerCode',
  'callback_code',
  'callbackCode',
  'social_code',
  'socialCode',
];

const _socialCallbackStateKeys = [
  'state',
  'oauth_state',
  'oauthState',
  'auth_state',
  'authState',
  'callback_state',
  'callbackState',
  'provider_state',
  'providerState',
  'request_state',
  'requestState',
  'return_state',
  'returnState',
  'launch_state',
  'launchState',
  'social_state',
  'socialState',
];

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
    final runtimeProvider = _runtimeSocialProvider(ref, widget.provider);
    final query = _normalizedSocialCallbackQuery(widget.query);
    final redirect = safeCustomerRedirect(query['redirect']);
    return Scaffold(
      body: _SocialCallbackHero(
        provider: widget.provider,
        runtimeProvider: runtimeProvider,
        title: context.l10n.socialCallbackTitle,
        status: _status ?? context.l10n.socialCallbackWaiting(providerLabel),
        actionLabel:
            _status == null ? '' : context.l10n.forgotPasswordBackToLogin,
        onAction: _status == null
            ? null
            : () => context.go(customerLoginRouteForRedirect(redirect)),
      ),
    );
  }

  Future<void> _handleCallback() async {
    final provider = normalizeSocialAuthProvider(widget.provider);
    final providerLabel = _ProviderBrand.label(provider);
    final query = _normalizedSocialCallbackQuery(widget.query);
    final code = query['code']?.trim() ?? '';
    final state = query['state']?.trim() ?? '';
    if (code.isEmpty || state.isEmpty) {
      setState(() {
        _status = context.l10n.socialCallbackMissingCode(providerLabel);
      });
      return;
    }

    try {
      final result = await ref.read(authRepositoryProvider).socialCallback(
            provider: widget.provider,
            query: Map<String, dynamic>.from(query),
          );
      if (!mounted) return;

      if (result.passwordResetReady && result.passwordResetToken.isNotEmpty) {
        context.go(
          Uri(
            path: '/reset-password',
            queryParameters: {
              'token': result.passwordResetToken,
              'source': result.provider,
            },
          ).toString(),
        );
        return;
      }

      if (result.lineLinkRequired && result.linkToken.isNotEmpty) {
        final redirect = safeCustomerRedirect(
          result.redirectPath.isNotEmpty
              ? result.redirectPath
              : widget.query['redirect'],
        );
        context.go(
          Uri(
            path: '/social/${result.provider}/link-phone',
            queryParameters: {
              'token': result.linkToken,
              'name': result.displayName,
              'picture_url': result.pictureUrl,
              'redirect': redirect,
            },
          ).toString(),
        );
        return;
      }

      if (result.session != null) {
        ref.read(authControllerProvider).applySession(result.session!);
        await ref.read(affiliateReferralServiceProvider).applyStored();
        if (!mounted) return;
        final redirect = safeCustomerRedirect(
          result.redirectPath.isNotEmpty
              ? result.redirectPath
              : widget.query['redirect'],
        );
        final postAuthRoute = result.orderId.trim().isEmpty
            ? redirect
            : customerCheckoutPendingRouteForOrder(result.orderId);
        context.go(
          customerPostAuthRouteForRedirect(
            redirect: postAuthRoute,
            pinRequired: result.session!.pinRequired,
            pinSetupRequired: result.session!.pinSetupRequired,
          ),
        );
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
        _status = authErrorMessage(
          error,
          context.l10n.socialCallbackConnectFailed(providerLabel),
        );
      });
    }
  }
}

Map<String, String> _normalizedSocialCallbackQuery(
  Map<String, String> query,
) {
  final normalized = Map<String, String>.from(query);
  final wrapped = _wrappedSocialCallbackQuery(normalized);
  if (wrapped.isNotEmpty) normalized.addAll(wrapped);
  final code = _firstNonBlankByKeys(normalized, _socialCallbackCodeKeys);
  final state = _firstNonBlankByKeys(normalized, _socialCallbackStateKeys);
  if (code.isNotEmpty) normalized['code'] = code;
  if (state.isNotEmpty) normalized['state'] = state;
  return normalized;
}

Map<String, String> _wrappedSocialCallbackQuery(
  Map<String, String> query, [
  int depth = 0,
]) {
  if (depth >= 5 || query.isEmpty) return const <String, String>{};

  for (final key in _socialCallbackWrapperKeys) {
    final nested = _jsonStringMap(query[key]);
    if (nested.isEmpty) continue;
    final resolved = _wrappedSocialCallbackQuery(nested, depth + 1);
    return {...nested, ...resolved};
  }

  return const <String, String>{};
}

Map<String, String> _jsonStringMap(String? value) {
  final trimmed = value?.trim() ?? '';
  if (!trimmed.startsWith('{')) return const <String, String>{};
  try {
    final decoded = convert.jsonDecode(trimmed);
    if (decoded is! Map) return const <String, String>{};
    return decoded.map(
      (key, value) => MapEntry(key.toString(), _socialQueryValue(value)),
    );
  } catch (_) {
    return const <String, String>{};
  }
}

String _socialQueryValue(Object? value) {
  if (value == null) return '';
  if (value is Map || value is Iterable) return convert.jsonEncode(value);
  return value.toString();
}

String _firstNonBlank(Iterable<String?> values) {
  for (final value in values) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isNotEmpty) return trimmed;
  }
  return '';
}

String _firstNonBlankByKeys(Map<String, String> source, Iterable<String> keys) {
  return _firstNonBlank(keys.map((key) => source[key]));
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
  String _formError = '';

  @override
  void initState() {
    super.initState();
    _phone.addListener(_clearFormError);
    _password.addListener(_clearFormError);
    _confirmPassword.addListener(_clearFormError);
    if (widget.linkToken.trim().isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.go(customerLoginRouteForRedirect(widget.redirect));
      });
    }
  }

  @override
  void dispose() {
    _phone.removeListener(_clearFormError);
    _password.removeListener(_clearFormError);
    _confirmPassword.removeListener(_clearFormError);
    _phone.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final providerLabel = _ProviderBrand.label(widget.provider);
    final runtimeProvider = _runtimeSocialProvider(ref, widget.provider);
    final providerColor = _ProviderBrand.color(
      context,
      widget.provider,
      runtimeProvider,
    );
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final sheetMinHeight =
              constraints.maxHeight > 156 ? constraints.maxHeight - 156 : 0.0;
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SocialLinkHero(
                    provider: widget.provider,
                    runtimeProvider: runtimeProvider,
                    title: l10n.socialLinkTitle(providerLabel),
                    subtitle: l10n.socialLinkHeroSubtitle(providerLabel),
                    saving: _saving,
                    onBack: () => context.go(
                      customerLoginRouteForRedirect(widget.redirect),
                    ),
                  ),
                  _SocialLinkSheet(
                    minHeight: sheetMinHeight,
                    child: _buildPhoneLinkCard(context, providerColor),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPhoneLinkCard(BuildContext context, Color providerColor) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.72),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.10),
            blurRadius: 42,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 380;
          return Padding(
            padding: EdgeInsets.all(compact ? 14 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _LineProfileCard(
                  provider: widget.provider,
                  providerColor: providerColor,
                  name: widget.displayName,
                  pictureUrl: widget.pictureUrl,
                ),
                if (_formError.trim().isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _SocialLinkErrorPanel(message: _formError),
                ],
                const SizedBox(height: 18),
                _SocialLinkFieldLabel(label: l10n.registerPhoneLabel),
                const SizedBox(height: 8),
                TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: _socialInputDecoration(
                    hintText: l10n.registerPhoneHint,
                    icon: Icons.phone_android_outlined,
                    color: providerColor,
                  ),
                ),
                const SizedBox(height: 16),
                _SocialLinkFieldLabel(label: l10n.registerPasswordLabel),
                const SizedBox(height: 8),
                TextField(
                  controller: _password,
                  obscureText: !_showPassword,
                  decoration: _socialInputDecoration(
                    hintText: l10n.socialLinkPasswordHint,
                    icon: Icons.lock_outline,
                    color: providerColor,
                    suffixIcon: IconButton(
                      onPressed: () => setState(
                        () => _showPassword = !_showPassword,
                      ),
                      tooltip: _showPassword
                          ? l10n.registerHidePassword
                          : l10n.registerShowPassword,
                      icon: Icon(
                        _showPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _SocialLinkFieldLabel(
                  label: l10n.registerConfirmPasswordLabel,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _confirmPassword,
                  obscureText: !_showPassword,
                  decoration: _socialInputDecoration(
                    hintText: l10n.socialLinkConfirmPasswordHint,
                    icon: Icons.shield_outlined,
                    color: providerColor,
                  ),
                ),
                const SizedBox(height: 18),
                _SocialLinkNote(text: l10n.socialLinkPhoneSubtitle),
                const SizedBox(height: 18),
                SizedBox(
                  height: 54,
                  child: FilledButton(
                    onPressed: _saving ? null : _submit,
                    style: FilledButton.styleFrom(
                      shape: const StadiumBorder(),
                      textStyle:
                          Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                    ),
                    child: Text(
                      _saving
                          ? l10n.socialLinkSubmitting
                          : l10n.socialLinkSubmit,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  InputDecoration _socialInputDecoration({
    required String hintText,
    required IconData icon,
    required Color color,
    Widget? suffixIcon,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    const radius = BorderRadius.all(Radius.circular(14));
    return InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.34),
      prefixIcon: Icon(icon, color: color),
      suffixIcon: suffixIcon == null
          ? null
          : IconTheme(
              data: IconThemeData(color: colorScheme.onSurfaceVariant),
              child: suffixIcon,
            ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.86),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.86),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: color, width: 1.6),
      ),
    );
  }

  Future<void> _submit() async {
    final phone = _phone.text.replaceAll(RegExp(r'\D'), '');
    final provider = normalizeSocialAuthProvider(widget.provider);
    final providerLabel = _ProviderBrand.label(provider);
    if (widget.linkToken.trim().isEmpty) {
      _showFormError(context.l10n.socialLinkMissing(providerLabel));
      return;
    }
    if (!RegExp(r'^\d{9,10}$').hasMatch(phone)) {
      _showFormError(context.l10n.authPhoneInvalid);
      return;
    }
    if (_password.text != _confirmPassword.text) {
      _showFormError(context.l10n.authPasswordMismatch);
      return;
    }

    final failedMessage = context.l10n.socialLinkFailed(providerLabel);
    final redirect = safeCustomerRedirect(widget.redirect);
    setState(() {
      _formError = '';
      _saving = true;
    });
    try {
      final session = await ref.read(authRepositoryProvider).socialLinkPhone(
            provider: provider,
            linkToken: widget.linkToken,
            phone: phone,
            password: _password.text,
            passwordConfirmation: _confirmPassword.text,
            redirect: redirect,
          );
      ref.read(authControllerProvider).applySession(session);
      await ref.read(affiliateReferralServiceProvider).applyStored();
      if (!mounted) return;
      context.go(
        customerPostAuthRouteForRedirect(
          redirect: redirect,
          pinRequired: session.pinRequired,
          pinSetupRequired: session.pinSetupRequired,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      final redirect = ApiErrorInfo.fromObject(error).operationalRedirectPath;
      if (redirect != null) {
        context.go(redirect);
      } else {
        _showFormError(authErrorMessage(error, failedMessage));
      }
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
}

class _SocialLinkErrorPanel extends StatelessWidget {
  const _SocialLinkErrorPanel({required this.message});

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

class _SocialCallbackHero extends StatelessWidget {
  const _SocialCallbackHero({
    required this.provider,
    required this.runtimeProvider,
    required this.title,
    required this.status,
    this.actionLabel = '',
    this.onAction,
  });

  final String provider;
  final SocialAuthProvider? runtimeProvider;
  final String title;
  final String status;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final brandColor = _ProviderBrand.color(context, provider, runtimeProvider);
    final brandLabel = _ProviderBrand.label(provider);
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary,
            Color.lerp(colorScheme.primary, colorScheme.secondary, 0.7) ??
                colorScheme.primary,
          ],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: colorScheme.onPrimary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: colorScheme.onPrimary.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _ProviderBrand.icon(provider),
                            color: brandColor,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$brandLabel Login',
                            style: TextStyle(
                              color: colorScheme.onPrimary,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          color: colorScheme.onPrimary,
                          fontWeight: FontWeight.w900,
                          height: 1.05,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    status,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: colorScheme.onPrimary.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w700,
                          height: 1.45,
                        ),
                  ),
                  if (onAction != null && actionLabel.trim().isNotEmpty) ...[
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: onAction,
                      style: FilledButton.styleFrom(
                        backgroundColor: colorScheme.onPrimary,
                        foregroundColor: colorScheme.primary,
                        minimumSize: const Size(168, 46),
                        shape: const StadiumBorder(),
                        textStyle:
                            Theme.of(context).textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                      ),
                      child: Text(actionLabel),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SocialLinkHero extends StatelessWidget {
  const _SocialLinkHero({
    required this.provider,
    required this.runtimeProvider,
    required this.title,
    required this.subtitle,
    required this.saving,
    required this.onBack,
  });

  final String provider;
  final SocialAuthProvider? runtimeProvider;
  final String title;
  final String subtitle;
  final bool saving;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final heroHeight = viewportWidth < 390 ? 292.0 : 276.0;
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary,
            Color.lerp(colorScheme.primary, colorScheme.secondary, 0.64) ??
                colorScheme.primary,
          ],
        ),
      ),
      child: SizedBox(
        height: topPadding + heroHeight,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, topPadding + 12, 16, 24),
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  onPressed: saving ? null : onBack,
                  color: colorScheme.onPrimary,
                  disabledColor: colorScheme.onPrimary.withValues(alpha: 0.42),
                  icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                ),
              ),
              Align(
                alignment: Alignment.center,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color:
                                colorScheme.onPrimary.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color:
                                  colorScheme.onPrimary.withValues(alpha: 0.2),
                            ),
                          ),
                          child: SizedBox.square(
                            dimension: 58,
                            child: Icon(
                              _ProviderBrand.icon(provider),
                              color: _ProviderBrand.color(
                                context,
                                provider,
                                runtimeProvider,
                              ),
                              size: 32,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                color: colorScheme.onPrimary,
                                fontWeight: FontWeight.w900,
                                height: 1.12,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          subtitle,
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onPrimary
                                        .withValues(alpha: 0.9),
                                    fontWeight: FontWeight.w700,
                                    height: 1.45,
                                  ),
                        ),
                      ],
                    ),
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

class _SocialLinkSheet extends StatelessWidget {
  const _SocialLinkSheet({
    required this.minHeight,
    required this.child,
  });

  final double minHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final topPadding = width >= 768 ? 32.0 : 18.0;
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(color: colorScheme.surfaceContainerLowest),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, topPadding, 16, 40),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _SocialLinkFieldLabel extends StatelessWidget {
  const _SocialLinkFieldLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w900,
          ),
    );
  }
}

class _SocialLinkNote extends StatelessWidget {
  const _SocialLinkNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.tertiaryContainer.withValues(alpha: 0.54),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.tertiary.withValues(alpha: 0.22),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onTertiaryContainer,
                fontWeight: FontWeight.w800,
                height: 1.45,
              ),
        ),
      ),
    );
  }
}

class _LineProfileCard extends StatelessWidget {
  const _LineProfileCard({
    required this.provider,
    required this.providerColor,
    required this.name,
    required this.pictureUrl,
  });

  final String provider;
  final Color providerColor;
  final String name;
  final String pictureUrl;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            providerColor.withValues(alpha: 0.08),
            colorScheme.primary.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: providerColor.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 360;
            final wide = constraints.maxWidth >= 492;
            final avatar = _LineProfileAvatar(
              provider: provider,
              providerColor: providerColor,
              pictureUrl: pictureUrl,
            );
            final copy = _LineProfileCopy(
              provider: provider,
              providerColor: providerColor,
              name: name,
              centered: compact,
            );
            final status = _LineProfileStatus(providerColor: providerColor);
            if (compact) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  avatar,
                  const SizedBox(height: 12),
                  copy,
                  const SizedBox(height: 12),
                  status,
                ],
              );
            }

            if (!wide) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      avatar,
                      const SizedBox(width: 12),
                      Expanded(child: copy),
                    ],
                  ),
                  const SizedBox(height: 12),
                  status,
                ],
              );
            }

            return Row(
              children: [
                avatar,
                const SizedBox(width: 12),
                Expanded(child: copy),
                const SizedBox(width: 12),
                status,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LineProfileAvatar extends StatelessWidget {
  const _LineProfileAvatar({
    required this.provider,
    required this.providerColor,
    required this.pictureUrl,
  });

  final String provider;
  final Color providerColor;
  final String pictureUrl;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: providerColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.surface, width: 4),
        boxShadow: [
          BoxShadow(
            color: providerColor.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox.square(
          dimension: 64,
          child: pictureUrl.isEmpty
              ? Icon(
                  _ProviderBrand.icon(provider),
                  color: colorScheme.onPrimary,
                  size: 28,
                )
              : Image.network(
                  pictureUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    _ProviderBrand.icon(provider),
                    color: colorScheme.onPrimary,
                    size: 28,
                  ),
                ),
        ),
      ),
    );
  }
}

class _LineProfileCopy extends StatelessWidget {
  const _LineProfileCopy({
    required this.provider,
    required this.providerColor,
    required this.name,
    this.centered = false,
  });

  final String provider;
  final Color providerColor;
  final String name;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final providerLabel = _ProviderBrand.label(provider);
    final colorScheme = Theme.of(context).colorScheme;
    final profileName = name.isEmpty
        ? context.l10n.socialProfileFallbackName(providerLabel)
        : name;
    return Column(
      crossAxisAlignment:
          centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.socialProfileAccount(providerLabel),
          textAlign: centered ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            color: providerColor,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          profileName,
          textAlign: centered ? TextAlign.center : TextAlign.start,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w900,
              ),
        ),
        Text(
          context.l10n.socialProfileReady,
          textAlign: centered ? TextAlign.center : TextAlign.start,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
                height: 1.35,
              ),
        ),
      ],
    );
  }
}

class _LineProfileStatus extends StatelessWidget {
  const _LineProfileStatus({required this.providerColor});

  final Color providerColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: providerColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, color: providerColor, size: 15),
            const SizedBox(width: 5),
            Text(
              context.l10n.socialProfileStatus,
              style: TextStyle(
                color: providerColor,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

SocialAuthProvider? _runtimeSocialProvider(WidgetRef ref, String provider) {
  final normalizedProvider = normalizeSocialAuthProvider(provider);
  return ref.watch(mobileBootstrapProvider).maybeWhen(
        data: (bootstrap) {
          for (final candidate in bootstrap.authProviders) {
            if (candidate.provider == normalizedProvider) return candidate;
          }
          return null;
        },
        orElse: () => null,
      );
}

class _ProviderBrand {
  const _ProviderBrand._();

  static String label(String provider) {
    return switch (normalizeSocialAuthProvider(provider)) {
      'google' => 'Google',
      'apple' => 'Apple ID',
      _ => 'LINE',
    };
  }

  static IconData icon(String provider) {
    return switch (normalizeSocialAuthProvider(provider)) {
      'google' => Icons.mail_outline,
      'apple' => Icons.apple,
      _ => Icons.chat_bubble_outline,
    };
  }

  static Color color(
    BuildContext context,
    String provider, [
    SocialAuthProvider? runtimeProvider,
  ]) {
    final providerColor = runtimeProvider?.brandColor;
    if (providerColor != null) return providerColor;

    final colorScheme = Theme.of(context).colorScheme;
    return switch (normalizeSocialAuthProvider(provider)) {
      'apple' => colorScheme.onSurface,
      'google' => colorScheme.primary,
      _ => Color.lerp(colorScheme.primary, colorScheme.tertiary, 0.24) ??
          colorScheme.primary,
    };
  }
}
