import 'dart:convert' as convert;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/auth_error_message.dart';
import '../../../core/auth/auth_repository.dart';
import '../../../core/auth/auth_token_store.dart';
import '../../../core/i18n/customer_localizations.dart';
import '../../../core/navigation/customer_back_navigation.dart';
import '../../../core/navigation/customer_redirect.dart';
import '../../../core/tenant/mobile_bootstrap_controller.dart';
import '../../../core/utils/api_errors.dart';
import '../../../shared/utils/customer_operational_error.dart';
import '../../../shared/widgets/customer_page_body.dart';
import '../../affiliate/data/affiliate_referral_repository.dart';
import 'auth_visual_tokens.dart';

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
    final runtimeProvider = _runtimeSocialProvider(
      ref.watch(mobileBootstrapProvider),
      widget.provider,
    );
    return Scaffold(
      body: _SocialCallbackHero(
        provider: widget.provider,
        runtimeProvider: runtimeProvider,
        title: context.l10n.socialCallbackTitle,
        status: _status ??
            context.l10n.socialCallbackWaiting(
              _ProviderBrand.label(widget.provider, runtimeProvider),
            ),
      ),
    );
  }

  Future<void> _handleCallback() async {
    final provider = normalizeSocialAuthProvider(widget.provider);
    final query = _normalizedSocialCallbackQuery(widget.query);
    final code = query['code']?.trim() ?? '';
    final state = query['state']?.trim() ?? '';
    if (code.isEmpty || state.isEmpty) {
      final authController = ref.read(authControllerProvider);
      if (authController.isAuthenticated) {
        final callbackContext = await ref
            .read(authTokenStoreProvider)
            .takeLatestSocialCallbackContext();
        final queryRedirect = query['redirect']?.trim() ?? '';
        final redirect = safeCustomerRedirect(
          queryRedirect.isNotEmpty ? queryRedirect : callbackContext?.redirect,
        );
        await ref.read(affiliateReferralServiceProvider).applyStored();
        if (!mounted) return;
        context.go(
          customerPostAuthRouteForRedirect(
            redirect: redirect,
            pinRequired: authController.pinRequired,
            pinSetupRequired: authController.pinSetupRequired,
          ),
        );
        return;
      }
      final providerLabel = await _runtimeProviderLabel(provider);
      if (!mounted) return;
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
              : query['redirect'],
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
              : query['redirect'],
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

      final providerLabel = await _runtimeProviderLabel(provider);
      if (!mounted) return;
      setState(() {
        _status = result.message.isEmpty
            ? context.l10n.socialCallbackFailed(providerLabel)
            : result.message;
      });
    } catch (error) {
      if (!mounted) return;
      final operational =
          ApiErrorInfo.fromObject(error).operationalRedirectPath != null;
      final returnPathOverride =
          operational ? await _callbackReturnPath(query, state) : null;
      if (!mounted) return;
      final handled = await handleCustomerOperationalError(
        ref: ref,
        context: context,
        error: error,
        returnPathOverride: returnPathOverride,
      );
      if (!mounted || handled) return;
      final providerLabel = await _runtimeProviderLabel(provider);
      if (!mounted) return;
      setState(() {
        _status = authErrorMessage(
          error,
          context.l10n.socialCallbackConnectFailed(providerLabel),
        );
      });
    }
  }

  Future<String?> _callbackReturnPath(
    Map<String, String> query,
    String state,
  ) async {
    final queryRedirect = query['redirect']?.trim() ?? '';
    if (queryRedirect.isNotEmpty) {
      final safeRedirect = safeCustomerRedirect(queryRedirect);
      return safeRedirect == '/' ? null : safeRedirect;
    }

    if (state.isEmpty) return null;
    final callbackContext =
        await ref.read(authTokenStoreProvider).readSocialCallbackContext(state);
    final safeRedirect = safeCustomerRedirect(callbackContext?.redirect);
    return safeRedirect == '/' ? null : safeRedirect;
  }

  Future<String> _runtimeProviderLabel(String provider) async {
    final current = _runtimeSocialProvider(
      ref.read(mobileBootstrapProvider),
      provider,
    );
    if (current != null) return _ProviderBrand.label(provider, current);

    try {
      final bootstrap = await ref.read(mobileBootstrapProvider.future);
      final resolved = _runtimeSocialProvider(
        AsyncData<MobileBootstrap>(bootstrap),
        provider,
      );
      return _ProviderBrand.label(provider, resolved);
    } catch (_) {
      return _ProviderBrand.label(provider);
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
    final runtimeProvider = _runtimeSocialProvider(
      ref.watch(mobileBootstrapProvider),
      widget.provider,
    );
    final providerLabel = _ProviderBrand.label(
      widget.provider,
      runtimeProvider,
    );
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
                    onBack: () => navigateCustomerBack(
                      context,
                      fallbackPath: customerLoginRouteForRedirect(
                        widget.redirect,
                      ),
                    ),
                  ),
                  _SocialLinkSheet(
                    minHeight: sheetMinHeight,
                    viewportWidth: constraints.maxWidth,
                    child: _buildPhoneLinkCard(
                      context,
                      providerColor,
                      providerLabel,
                      constraints.maxWidth,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPhoneLinkCard(
    BuildContext context,
    Color providerColor,
    String providerLabel,
    double viewportWidth,
  ) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(viewportWidth <= 380 ? 16 : 18),
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
      child: Padding(
        padding: EdgeInsets.all(
          viewportWidth <= 380 ? 14 : (viewportWidth * 0.05).clamp(16.0, 24.0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _LineProfileCard(
              provider: widget.provider,
              providerLabel: providerLabel,
              providerColor: providerColor,
              name: widget.displayName,
              pictureUrl: widget.pictureUrl,
              viewportWidth: viewportWidth,
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
              style: authInputTextStyle(
                context,
                fontWeight: FontWeight.w800,
              ),
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.telephoneNumber],
              onSubmitted: (_) => FocusScope.of(context).nextFocus(),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              decoration: _socialInputDecoration(
                hintText: l10n.registerPhoneHint,
                icon: Icons.phone_android_outlined,
              ),
            ),
            const SizedBox(height: 18),
            _SocialLinkFieldLabel(label: l10n.registerPasswordLabel),
            const SizedBox(height: 8),
            TextField(
              controller: _password,
              style: authInputTextStyle(
                context,
                fontWeight: FontWeight.w800,
              ),
              obscureText: !_showPassword,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.password],
              onSubmitted: (_) => FocusScope.of(context).nextFocus(),
              decoration: _socialInputDecoration(
                hintText: l10n.socialLinkPasswordHint,
                icon: Icons.lock_outline,
                suffixIcon: authInputActionButton(
                  context,
                  onPressed: _saving
                      ? null
                      : () => setState(
                            () => _showPassword = !_showPassword,
                          ),
                  tooltip: _showPassword
                      ? l10n.registerHidePassword
                      : l10n.registerShowPassword,
                  icon: _showPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
            ),
            const SizedBox(height: 18),
            _SocialLinkFieldLabel(
              label: l10n.registerConfirmPasswordLabel,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _confirmPassword,
              style: authInputTextStyle(
                context,
                fontWeight: FontWeight.w800,
              ),
              obscureText: !_showPassword,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
              onSubmitted: (_) {
                if (!_saving) _submit();
              },
              decoration: _socialInputDecoration(
                hintText: l10n.socialLinkConfirmPasswordHint,
                icon: Icons.shield_outlined,
              ),
            ),
            const SizedBox(height: 18),
            _SocialLinkNote(
              text: l10n.socialLinkPhoneSubtitle(providerLabel),
            ),
            const SizedBox(height: 18),
            authPrimaryActionButton(
              onPressed: _saving ? null : _submit,
              height: 54,
              fontSize: 18,
              label:
                  _saving ? l10n.socialLinkSubmitting : l10n.socialLinkSubmit,
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _socialInputDecoration({
    required String hintText,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return authInputDecoration(
      context,
      hintText: hintText,
      prefixIcon: Icon(icon),
      suffixIcon: suffixIcon == null
          ? null
          : IconTheme(
              data: IconThemeData(color: colorScheme.onSurfaceVariant),
              child: suffixIcon,
            ),
      softFill: true,
      borderRadius: 14,
    );
  }

  Future<void> _submit() async {
    final phone = _phone.text.replaceAll(RegExp(r'\D'), '');
    final provider = normalizeSocialAuthProvider(widget.provider);
    final providerLabel = _ProviderBrand.label(
      provider,
      _runtimeSocialProvider(
        ref.read(mobileBootstrapProvider),
        provider,
      ),
    );
    if (widget.linkToken.trim().isEmpty) {
      _showFormError(context.l10n.socialLinkMissing(providerLabel));
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
      final handled = await handleCustomerOperationalError(
        ref: ref,
        context: context,
        error: error,
        returnPathOverride: redirect,
      );
      if (!mounted || handled) return;
      _showFormError(authErrorMessage(error, failedMessage));
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
  });

  final String provider;
  final SocialAuthProvider? runtimeProvider;
  final String title;
  final String status;

  @override
  Widget build(BuildContext context) {
    final brandLabel = _ProviderBrand.label(provider, runtimeProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final copy = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 430),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.38),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _ProviderBrand.icon(provider),
                    color: colorScheme.onPrimary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$brandLabel Login',
                    style: TextStyle(
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.start,
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: colorScheme.onPrimary,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            status,
            textAlign: TextAlign.start,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onPrimary.withValues(alpha: 0.9),
                  fontSize: 17,
                  fontWeight: FontWeight.w400,
                  height: 1.45,
                ),
          ),
        ],
      ),
    );

    return AuthLoginHeroBackdrop(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          authHeroTopPadding(context),
          20,
          104 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: customerContentMaxWidthFor(context),
            ),
            child: Align(
              alignment: AlignmentDirectional.topStart,
              child: copy,
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
    final colorScheme = Theme.of(context).colorScheme;
    return AuthBlueHeroBackdrop(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 268),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            authHeroTopPadding(context),
            20,
            24,
          ),
          child: Stack(
            children: [
              PositionedDirectional(
                start: 0,
                top: 0,
                child: authHeroBackButton(
                  context,
                  tooltip: context.l10n.commonBack,
                  onPressed: saving ? null : onBack,
                ),
              ),
              Align(
                alignment: Alignment.topCenter,
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
    required this.viewportWidth,
    required this.child,
  });

  final double minHeight;
  final double viewportWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final topPadding =
        viewportWidth >= 768 ? 32.0 : (viewportWidth * 0.05).clamp(18.0, 28.0);
    final horizontalPadding = viewportWidth <= 380 ? 12.0 : 16.0;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final colorScheme = Theme.of(context).colorScheme;
    return Transform.translate(
      offset: Offset(0, authContentSheetOverlap(viewportWidth)),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLowest,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              topPadding,
              horizontalPadding,
              40 + bottomInset,
            ),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: child,
              ),
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
    required this.providerLabel,
    required this.providerColor,
    required this.name,
    required this.pictureUrl,
    required this.viewportWidth,
  });

  final String provider;
  final String providerLabel;
  final Color providerColor;
  final String name;
  final String pictureUrl;
  final double viewportWidth;

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
        child: Builder(
          builder: (context) {
            final compact = viewportWidth <= 380;
            final wide = viewportWidth >= 768;
            final avatar = _LineProfileAvatar(
              provider: provider,
              providerColor: providerColor,
              pictureUrl: pictureUrl,
            );
            final copy = _LineProfileCopy(
              providerLabel: providerLabel,
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
          dimension: 72,
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
    required this.providerLabel,
    required this.providerColor,
    required this.name,
    this.centered = false,
  });

  final String providerLabel;
  final Color providerColor;
  final String name;
  final bool centered;

  @override
  Widget build(BuildContext context) {
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

SocialAuthProvider? _runtimeSocialProvider(
  AsyncValue<MobileBootstrap> bootstrapValue,
  String provider,
) {
  final normalizedProvider = normalizeSocialAuthProvider(provider);
  return bootstrapValue.maybeWhen(
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

  static String label(
    String provider, [
    SocialAuthProvider? runtimeProvider,
  ]) {
    final runtimeLabel = runtimeProvider?.label.trim() ?? '';
    if (runtimeLabel.isNotEmpty) return runtimeLabel;
    return switch (normalizeSocialAuthProvider(provider)) {
      'google' => 'Google',
      'apple' => 'Apple ID',
      'line' => 'LINE',
      final provider => provider,
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
    final providerColor =
        runtimeProvider?.brandColor ?? runtimeProvider?.buttonBackgroundColor;
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
