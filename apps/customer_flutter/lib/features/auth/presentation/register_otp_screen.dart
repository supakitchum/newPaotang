import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/auth_repository.dart';
import '../../../core/i18n/customer_localizations.dart';
import '../../../core/navigation/customer_back_navigation.dart';
import '../../../core/navigation/customer_redirect.dart';
import '../../../core/utils/api_errors.dart';
import '../../../shared/utils/customer_operational_error.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/customer_gradient_button.dart';
import '../../../shared/widgets/customer_page_body.dart';
import '../../affiliate/data/affiliate_referral_repository.dart';
import 'auth_keyboard.dart';
import 'auth_otp_widgets.dart';

@immutable
class RegisterOtpFlowState {
  const RegisterOtpFlowState({
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.password,
    required this.passwordConfirmation,
    required this.redirect,
    required this.otpRequest,
  });

  final String firstName;
  final String lastName;
  final String phone;
  final String password;
  final String passwordConfirmation;
  final String redirect;
  final OtpRequestResult otpRequest;

  RegisterOtpFlowState copyWith({OtpRequestResult? otpRequest}) {
    return RegisterOtpFlowState(
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      password: password,
      passwordConfirmation: passwordConfirmation,
      redirect: redirect,
      otpRequest: otpRequest ?? this.otpRequest,
    );
  }
}

final registerOtpFlowProvider = StateProvider<RegisterOtpFlowState?>(
  (_) => null,
);

class RegisterOtpScreen extends ConsumerStatefulWidget {
  const RegisterOtpScreen({super.key});

  @override
  ConsumerState<RegisterOtpScreen> createState() => _RegisterOtpScreenState();
}

class _RegisterOtpScreenState extends ConsumerState<RegisterOtpScreen> {
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
    final flow = ref.read(registerOtpFlowProvider);
    if (flow != null) {
      _setResendCountdown(flow.otpRequest.resendAfterSeconds);
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
    final flow = ref.watch(registerOtpFlowProvider);
    if (flow == null) return const SizedBox.shrink();

    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final sentTo = flow.otpRequest.phoneMasked.trim().isEmpty
        ? flow.phone
        : flow.otpRequest.phoneMasked;
    return AppShell(
      title: l10n.registerOtpTitle,
      currentPath: '/register/otp',
      onBack: _backToRegister,
      heroContent: const SizedBox.shrink(),
      heroMinHeight: customerReferenceCompactHeroHeight,
      heroSheetOverlap: 0,
      child: ColoredBox(
        color: colorScheme.surface,
        child: Column(
          key: const ValueKey('register-otp-screen'),
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
                                  l10n.registerOtpTitle,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(
                                        color: colorScheme.onSurface,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  l10n.authOtpSentTo(sentTo),
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
                                  label: l10n.registerOtpLabel,
                                  onSubmitted: _verify,
                                  inputKey: const ValueKey(
                                    'register-otp-input',
                                  ),
                                  boxKeyPrefix: 'register-otp-box',
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
                                TextButton(
                                  key: const ValueKey(
                                    'register-otp-change-details',
                                  ),
                                  onPressed: _submitting
                                      ? null
                                      : _backToRegister,
                                  child: Text(l10n.registerOtpChangeDetails),
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
                          ? l10n.registerSubmitting
                          : l10n.registerSubmitWithOtp,
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
    final flow = ref.read(registerOtpFlowProvider);
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
      final verified = await ref
          .read(authRepositoryProvider)
          .verifyOtp(phone: flow.phone, purpose: 'register', otp: otp);
      if (!mounted) return;
      final verificationToken = verified.verificationToken.trim();
      if (verificationToken.isEmpty) {
        _showFormError(context.l10n.authOtpVerificationFailed);
        restoreOtpFocus = true;
        return;
      }

      await ref
          .read(authControllerProvider)
          .register(
            firstName: flow.firstName,
            lastName: flow.lastName,
            phone: flow.phone,
            password: flow.password,
            passwordConfirmation: flow.passwordConfirmation,
            otpVerificationToken: verificationToken,
          );
      await ref
          .read(affiliateReferralServiceProvider)
          .applyStored(registered: true);
      if (!mounted) return;
      await dismissAuthKeyboard(
        context,
        waitForAnimation: true,
        finishAutofillContext: true,
      );
      if (!mounted) return;
      final auth = ref.read(authControllerProvider);
      final flowNotifier = ref.read(registerOtpFlowProvider.notifier);
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
        _registrationErrorMessage(error, context.l10n.registerFailed),
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
    final flow = ref.read(registerOtpFlowProvider);
    if (_submitting || flow == null || _resendAfter > 0) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _formError = '';
      _submitting = true;
    });
    try {
      final result = await ref
          .read(authRepositoryProvider)
          .requestOtp(phone: flow.phone, purpose: 'register');
      if (!mounted) return;
      ref.read(registerOtpFlowProvider.notifier).state = flow.copyWith(
        otpRequest: result,
      );
      _otp.clear();
      _setResendCountdown(result.resendAfterSeconds);
      _otpFocusNode.requestFocus();
    } catch (error) {
      if (!mounted) return;
      _showFormError(
        _registrationErrorMessage(error, context.l10n.registerFailed),
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

  Future<void> _backToRegister() async {
    if (_submitting) return;
    await dismissAuthKeyboard(
      context,
      waitForAnimation: true,
      finishAutofillContext: true,
    );
    if (!mounted) return;
    final redirect = ref.read(registerOtpFlowProvider)?.redirect ?? '/';
    navigateCustomerBack(
      context,
      fallbackPath: customerRegisterRouteForRedirect(redirect),
    );
  }

  void _handleOtpChanged() {
    if (!mounted) return;
    final otp = _otp.text.trim();
    if (otp.length < 6) _scheduledAutoVerifyOtp = null;
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
          ref.read(registerOtpFlowProvider) == null) {
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
        ref.read(registerOtpFlowProvider) == null ||
        !_otpFocusNode.canRequestFocus) {
      return;
    }

    _otpFocusNode.requestFocus();
    try {
      await SystemChannels.textInput.invokeMethod<void>('TextInput.show');
    } on MissingPluginException {
      // Widget tests do not install the native text input plugin.
    } on PlatformException {
      // Requesting focus remains sufficient while the platform is transitioning.
    }
  }

  String _registrationErrorMessage(Object error, String fallback) {
    final message = ApiErrorInfo.fromObject(error).message.trim();
    if (message.isEmpty) return fallback;
    if (error is DioException || error is Map) return message;
    return fallback;
  }

  void _showFormError(String message) {
    if (!mounted) return;
    final normalized = message.trim();
    if (normalized.isEmpty) return;
    setState(() => _formError = normalized);
  }
}
