import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/auth_error_message.dart';
import '../../../core/auth/auth_repository.dart';
import '../../../core/i18n/customer_localizations.dart';
import '../../../core/navigation/customer_back_navigation.dart';
import '../../../core/navigation/customer_redirect.dart';
import '../../../shared/utils/customer_operational_error.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/customer_gradient_button.dart';
import '../../../shared/widgets/customer_page_body.dart';
import '../../affiliate/data/affiliate_referral_repository.dart';
import 'auth_keyboard.dart';
import 'auth_otp_widgets.dart';

@immutable
class LoginOtpFlowState {
  const LoginOtpFlowState({
    required this.challenge,
    required this.redirect,
    this.phone = '',
  });

  final LoginOtpChallenge challenge;
  final String redirect;
  final String phone;

  LoginOtpFlowState copyWith({LoginOtpChallenge? challenge}) {
    return LoginOtpFlowState(
      challenge: challenge ?? this.challenge,
      redirect: redirect,
      phone: phone,
    );
  }
}

final loginOtpFlowProvider = StateProvider<LoginOtpFlowState?>((_) => null);
final loginPasswordFallbackPhoneProvider = StateProvider<String>((_) => '');

class LoginOtpScreen extends ConsumerStatefulWidget {
  const LoginOtpScreen({super.key});

  @override
  ConsumerState<LoginOtpScreen> createState() => _LoginOtpScreenState();
}

class _LoginOtpScreenState extends ConsumerState<LoginOtpScreen> {
  final _otp = TextEditingController();
  final _otpFocusNode = FocusNode();
  Timer? _resendTimer;
  int _resendAfter = 0;
  bool _submitting = false;
  String _formError = '';
  String? _scheduledAutoVerifyOtp;

  @override
  void initState() {
    super.initState();
    _otp.addListener(_handleOtpChanged);
    _otpFocusNode.addListener(_handleOtpFocusChanged);
    final challenge = ref.read(loginOtpFlowProvider)?.challenge;
    if (challenge != null) {
      _setResendCountdown(challenge.resendAfterSeconds);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_activateOtpInput());
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _otp.removeListener(_handleOtpChanged);
    _otpFocusNode.removeListener(_handleOtpFocusChanged);
    _otp.dispose();
    _otpFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final flow = ref.watch(loginOtpFlowProvider);
    if (flow == null) {
      return const SizedBox.shrink();
    }

    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return AppShell(
      title: l10n.loginOtpTitle,
      currentPath: '/login/otp',
      onBack: _backToLogin,
      heroContent: const SizedBox.shrink(),
      heroMinHeight: customerReferenceCompactHeroHeight,
      heroSheetOverlap: 0,
      child: ColoredBox(
        color: colorScheme.surface,
        child: Column(
          key: const ValueKey('login-otp-screen'),
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: CustomerPageBody(
                        top: 24,
                        bottom: 24,
                        includeBottomSafeArea: false,
                        alignment: Alignment.center,
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 520),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Center(
                                  child: Container(
                                    width: 72,
                                    height: 72,
                                    decoration: BoxDecoration(
                                      color: colorScheme.primary.withValues(
                                        alpha: 0.10,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.sms_outlined,
                                      color: colorScheme.primary,
                                      size: 34,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  l10n.loginOtpTitle,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(
                                        color: colorScheme.onSurface,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  l10n.authOtpSentTo(
                                    flow.challenge.phoneMasked,
                                  ),
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                        height: 1.45,
                                      ),
                                ),
                                const SizedBox(height: 30),
                                AuthOtpCodeField(
                                  controller: _otp,
                                  focusNode: _otpFocusNode,
                                  enabled: !_submitting,
                                  label: l10n.authOtpLabel,
                                  onSubmitted: _verify,
                                  inputKey: const ValueKey('login-otp-input'),
                                  boxKeyPrefix: 'login-otp-box',
                                ),
                                if (_formError.isNotEmpty) ...[
                                  const SizedBox(height: 14),
                                  AuthOtpErrorPanel(message: _formError),
                                ],
                                const SizedBox(height: 14),
                                if (_resendAfter > 0)
                                  Text(
                                    l10n.authOtpResendIn(_resendAfter),
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                  )
                                else
                                  Center(
                                    child: TextButton(
                                      onPressed: _submitting ? null : _resend,
                                      child: Text(l10n.authOtpResend),
                                    ),
                                  ),
                                const SizedBox(height: 4),
                                TextButton.icon(
                                  key: const ValueKey('login-otp-use-password'),
                                  onPressed: _submitting
                                      ? null
                                      : _switchToPassword,
                                  icon: const Icon(Icons.lock_outline),
                                  label: Text(l10n.loginUsePassword),
                                ),
                                TextButton(
                                  onPressed: _submitting ? null : _backToLogin,
                                  child: Text(l10n.loginOtpChangePhone),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: SizedBox(
                    width: double.infinity,
                    child: CustomerGradientButton.text(
                      onPressed: _submitting ? null : _verify,
                      height: 54,
                      fontSize: 18,
                      label: _submitting
                          ? l10n.loginOtpSubmitting
                          : l10n.loginOtpSubmit,
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

  Future<void> _verify() async {
    final flow = ref.read(loginOtpFlowProvider);
    if (_submitting || flow == null) return;
    final otp = _otp.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
      _showFormError(context.l10n.authOtpInvalid);
      _otpFocusNode.requestFocus();
      return;
    }

    final keyboardDismissal = dismissAuthKeyboard(
      context,
      finishAutofillContext: true,
    );
    setState(() {
      _formError = '';
      _submitting = true;
    });
    await keyboardDismissal;
    if (!mounted) return;
    var restoreOtpFocus = false;
    try {
      await ref
          .read(authControllerProvider)
          .verifyLoginOtp(
            challengeToken: flow.challenge.challengeToken,
            otp: otp,
          );
      await ref.read(affiliateReferralServiceProvider).applyStored();
      if (!mounted) return;
      await dismissAuthKeyboard(
        context,
        waitForAnimation: true,
        finishAutofillContext: true,
      );
      if (!mounted) return;
      final auth = ref.read(authControllerProvider);
      final flowNotifier = ref.read(loginOtpFlowProvider.notifier);
      context.go(
        customerPostAuthRouteForRedirect(
          redirect: flow.redirect,
          pinRequired: auth.pinRequired,
          pinSetupRequired: auth.pinSetupRequired,
        ),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (identical(flowNotifier.state, flow)) {
          flowNotifier.state = null;
        }
      });
    } catch (error) {
      if (!mounted) return;
      final handled = await handleCustomerOperationalError(
        ref: ref,
        context: context,
        error: error,
        returnPathOverride: flow.redirect,
      );
      if (!mounted || handled) return;
      _showFormError(
        loginErrorMessage(
          error,
          context.l10n,
          fallback: context.l10n.authOtpVerificationFailed,
        ),
      );
      restoreOtpFocus = true;
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
        if (restoreOtpFocus) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            unawaited(_activateOtpInput());
          });
        }
      }
    }
  }

  Future<void> _resend() async {
    final flow = ref.read(loginOtpFlowProvider);
    if (_submitting || flow == null || _resendAfter > 0) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _formError = '';
      _submitting = true;
    });
    try {
      final challenge = await ref
          .read(authRepositoryProvider)
          .resendLoginOtp(challengeToken: flow.challenge.challengeToken);
      if (!mounted) return;
      ref.read(loginOtpFlowProvider.notifier).state = flow.copyWith(
        challenge: challenge,
      );
      _otp.clear();
      _setResendCountdown(challenge.resendAfterSeconds);
      _otpFocusNode.requestFocus();
    } catch (error) {
      if (!mounted) return;
      _showFormError(
        loginErrorMessage(
          error,
          context.l10n,
          fallback: context.l10n.authOtpVerificationFailed,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _setResendCountdown(int seconds) {
    _resendTimer?.cancel();
    _resendAfter = seconds > 0 ? seconds : 60;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _resendAfter <= 1) {
        timer.cancel();
        if (mounted) setState(() => _resendAfter = 0);
        return;
      }
      setState(() => _resendAfter -= 1);
    });
  }

  Future<void> _backToLogin() async {
    if (_submitting) return;
    await dismissAuthKeyboard(
      context,
      waitForAnimation: true,
      finishAutofillContext: true,
    );
    if (!mounted) return;
    final redirect = ref.read(loginOtpFlowProvider)?.redirect ?? '/';
    ref.read(loginOtpFlowProvider.notifier).state = null;
    navigateCustomerBack(
      context,
      fallbackPath: customerLoginRouteForRedirect(redirect),
    );
  }

  Future<void> _switchToPassword() async {
    if (_submitting) return;
    await dismissAuthKeyboard(
      context,
      waitForAnimation: true,
      finishAutofillContext: true,
    );
    if (!mounted) return;
    final flow = ref.read(loginOtpFlowProvider);
    final redirect = flow?.redirect ?? '/';
    ref.read(loginPasswordFallbackPhoneProvider.notifier).state =
        flow?.phone.trim() ?? '';
    ref.read(loginOtpFlowProvider.notifier).state = null;
    context.go(customerLoginRouteForRedirect(redirect));
  }

  void _handleOtpChanged() {
    if (!mounted) return;
    final otp = _otp.text.trim();
    if (otp.length < 6) {
      _scheduledAutoVerifyOtp = null;
    }
    setState(() {
      if (!_submitting) _formError = '';
    });
    if (_submitting ||
        !RegExp(r'^\d{6}$').hasMatch(otp) ||
        _scheduledAutoVerifyOtp == otp) {
      return;
    }

    _scheduledAutoVerifyOtp = otp;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _submitting ||
          _otp.text.trim() != otp ||
          ref.read(loginOtpFlowProvider) == null) {
        return;
      }
      unawaited(_verify());
    });
  }

  void _handleOtpFocusChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _activateOtpInput() async {
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      await Future<void>.delayed(const Duration(milliseconds: 180));
    }
    if (!mounted ||
        _submitting ||
        ref.read(loginOtpFlowProvider) == null ||
        !_otpFocusNode.canRequestFocus) {
      return;
    }

    _otpFocusNode.requestFocus();
    try {
      await SystemChannels.textInput.invokeMethod<void>('TextInput.show');
    } on MissingPluginException {
      // Widget tests do not install the native text input plugin.
    } on PlatformException {
      // Requesting focus remains sufficient when the platform is transitioning.
    }
  }

  void _showFormError(String message) {
    if (!mounted) return;
    final normalized = message.trim();
    if (normalized.isEmpty) return;
    setState(() => _formError = normalized);
  }
}
