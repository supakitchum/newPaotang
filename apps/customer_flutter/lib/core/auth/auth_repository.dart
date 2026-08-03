import 'dart:convert' as convert;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/api_payload.dart';
import '../utils/idempotency_key.dart';
import '../network/api_client.dart';
import '../navigation/customer_redirect.dart';
import 'auth_token_store.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    api: ref.watch(apiClientProvider),
    tokenStore: ref.watch(authTokenStoreProvider),
  );
});

const _socialLoginPayloadWrapperKeys = [
  'login',
  'social_login',
  'socialLogin',
  'social_auth',
  'socialAuth',
  'auth',
  'resource',
  'data',
  'result',
  'payload',
  'authorization',
  'authorizationRequest',
  'authorization_request',
  'oauth',
  'oauth2',
  'providerPayload',
  'provider_payload',
  'providerData',
  'provider_data',
  'callbackData',
  'callback_data',
  'metadata',
  'meta',
  'context',
  'details',
  'detail',
  'attributes',
];

const _socialCallbackPayloadWrapperKeys = [
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

const _socialCallbackResponseWrapperKeys = [
  ..._socialCallbackPayloadWrapperKeys,
  'session',
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

class AuthRepository {
  AuthRepository({required ApiClient api, required AuthTokenStore tokenStore})
    : _api = api,
      _tokenStore = tokenStore;

  final ApiClient _api;
  final AuthTokenStore _tokenStore;

  Future<CustomerSession> login({
    required String username,
    required String password,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/customer/auth/login',
      auth: false,
      data: {
        'username': username,
        'password': password,
        'login_method': 'password',
      },
    );
    final payload = asMap(response.data);
    final challenge = LoginOtpChallenge.fromJson(payload);
    if (challenge.isRequired) {
      throw LoginOtpChallengeRequired(challenge);
    }
    final session = CustomerSession.fromJson(payload);
    await _saveSession(session);
    return session;
  }

  Future<LoginOtpChallenge> requestLoginOtp({required String phone}) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/customer/auth/login',
      auth: false,
      data: {'phone': phone, 'login_method': 'otp'},
    );
    final challenge = LoginOtpChallenge.fromJson(asMap(response.data));
    if (!challenge.isRequired) {
      throw StateError('Login OTP challenge was not returned.');
    }
    return challenge;
  }

  Future<LoginOtpChallenge> resendLoginOtp({
    required String challengeToken,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/customer/auth/login/otp/resend',
      auth: false,
      data: {'login_challenge_token': challengeToken},
    );
    return LoginOtpChallenge.fromJson(asMap(response.data));
  }

  Future<CustomerSession> verifyLoginOtp({
    required String challengeToken,
    required String otp,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/customer/auth/login/otp/verify',
      auth: false,
      data: {'login_challenge_token': challengeToken, 'otp': otp},
    );
    final session = CustomerSession.fromJson(asMap(response.data));
    await _saveSession(session);
    return session;
  }

  Future<CustomerSession> register({
    required String firstName,
    required String lastName,
    required String phone,
    required String password,
    required String passwordConfirmation,
    String? otpVerificationToken,
  }) async {
    final response = await _api.postWithHeaders<Map<String, dynamic>>(
      '/customer/auth/register',
      auth: false,
      headers: {'Idempotency-Key': newIdempotencyKey('customer_register')},
      data: {
        'first_name': firstName,
        'last_name': lastName,
        'name': '$firstName $lastName'.trim(),
        'phone': phone,
        'username': phone,
        'password': password,
        'password_confirmation': passwordConfirmation,
        'accepted_terms': true,
        if (otpVerificationToken != null && otpVerificationToken.isNotEmpty)
          'otp_verification_token': otpVerificationToken,
      },
    );
    final session = CustomerSession.fromJson(asMap(response.data));
    await _saveSession(session);
    return session;
  }

  Future<CustomerSession> refresh() async {
    final refreshToken = _tokenStore.refreshToken?.trim() ?? '';
    if (refreshToken.isEmpty) {
      throw StateError('Customer refresh token is unavailable.');
    }
    final response = await _api.post<Map<String, dynamic>>(
      '/customer/auth/refresh',
      auth: false,
      data: {'refresh_token': refreshToken},
    );
    final parsed = CustomerSession.fromJson(asMap(response.data));
    if (parsed.accessToken.isEmpty) {
      throw StateError('Customer refresh response has no access token.');
    }
    final session = CustomerSession(
      sessionId: parsed.sessionId,
      accessToken: parsed.accessToken,
      refreshToken: parsed.refreshToken.isEmpty
          ? refreshToken
          : parsed.refreshToken,
      pinRequired: parsed.pinRequired,
      pinSetupRequired: parsed.pinSetupRequired,
      customerId: parsed.customerId.isEmpty
          ? (_tokenStore.customerId?.trim() ?? '')
          : parsed.customerId,
      preferredLocale: parsed.preferredLocale,
    );
    await _saveSession(session);
    return session;
  }

  Future<CustomerAuthIdentity> currentIdentity() async {
    final response = await _api.get<Map<String, dynamic>>('/customer/profile');
    return CustomerAuthIdentity.fromJson(asMap(response.data));
  }

  Future<void> clearLocalSession() => _tokenStore.clear();

  Future<void> logout() async {
    try {
      if (_tokenStore.hasAccessToken) {
        await _api.postWithHeaders(
          '/customer/auth/logout',
          headers: {
            'Idempotency-Key': newIdempotencyKey('customer_auth_logout'),
          },
          data: const {},
        );
      }
    } finally {
      await _tokenStore.clear();
    }
  }

  Future<OtpRequestResult> requestOtp({
    required String phone,
    required String purpose,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/customer/auth/otp/request',
      auth: false,
      data: {'phone': phone, 'purpose': purpose},
    );
    return OtpRequestResult.fromJson(asMap(response.data));
  }

  Future<OtpVerifyResult> verifyOtp({
    required String phone,
    required String purpose,
    required String otp,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/customer/auth/otp/verify',
      auth: false,
      data: {'phone': phone, 'purpose': purpose, 'otp': otp},
    );
    return OtpVerifyResult.fromJson(asMap(response.data));
  }

  Future<void> resetPasswordWithOtp({
    required String phone,
    required String otpVerificationToken,
    required String password,
    required String passwordConfirmation,
  }) async {
    await _api.post<Map<String, dynamic>>(
      '/customer/auth/password/reset/otp',
      auth: false,
      data: {
        'phone': phone,
        'otp_verification_token': otpVerificationToken,
        'password': password,
        'password_confirmation': passwordConfirmation,
      },
    );
  }

  Future<void> resetPasswordWithToken({
    required String token,
    required String password,
    required String passwordConfirmation,
    String source = 'admin_reset_link',
  }) async {
    await _api.post<Map<String, dynamic>>(
      '/customer/auth/password/reset',
      auth: false,
      data: {
        'token': token,
        'password': password,
        'password_confirmation': passwordConfirmation,
        'source': source,
      },
    );
  }

  Future<OtpRequestResult> requestPinResetOtp() async {
    final response = await _api.post<Map<String, dynamic>>(
      '/customer/auth/pin/reset/request-otp',
    );
    return OtpRequestResult.fromJson(asMap(response.data));
  }

  Future<OtpVerifyResult> verifyPinResetOtp({required String otp}) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/customer/auth/pin/reset/verify-otp',
      data: {'otp': otp},
    );
    return OtpVerifyResult.fromJson(asMap(response.data));
  }

  Future<void> confirmPinResetWithOtp({
    required String otpVerificationToken,
    required String pin,
    required String pinConfirmation,
  }) async {
    await _api.post<Map<String, dynamic>>(
      '/customer/auth/pin/reset/confirm-otp',
      data: {
        'otp_verification_token': otpVerificationToken,
        'pin': pin,
        'pin_confirmation': pinConfirmation,
      },
    );
  }

  Future<SocialCallbackResult> lineCallback(Map<String, dynamic> query) async {
    return socialCallback(provider: 'line', query: query);
  }

  Future<SocialCallbackResult> nativeLineLogin({
    required String accessToken,
    String purpose = 'login',
    String? redirect,
    bool auth = false,
  }) async {
    final redirectPath = redirect?.trim() ?? '';
    final response = await _api.post<Map<String, dynamic>>(
      '/customer/auth/line/native',
      auth: auth,
      data: {
        'access_token': accessToken,
        'purpose': purpose,
        'client': 'customer_flutter_native',
        if (redirectPath.isNotEmpty)
          'redirect': safeCustomerRedirect(redirectPath),
      },
    );
    final result = SocialCallbackResult.fromJson(
      asMap(response.data),
      fallbackProvider: 'line',
    );
    if (result.session != null) await _saveSession(result.session!);
    return result;
  }

  Future<CustomerSession> lineLinkPhone({
    required String linkToken,
    required String phone,
    required String firstName,
    required String lastName,
    required String password,
    required String passwordConfirmation,
    required String otpVerificationToken,
    required bool acceptedTerms,
    String? redirect,
  }) async {
    return socialLinkPhone(
      provider: 'line',
      linkToken: linkToken,
      phone: phone,
      firstName: firstName,
      lastName: lastName,
      password: password,
      passwordConfirmation: passwordConfirmation,
      otpVerificationToken: otpVerificationToken,
      acceptedTerms: acceptedTerms,
      redirect: redirect,
    );
  }

  Future<SocialCallbackResult> socialCallback({
    required String provider,
    required Map<String, dynamic> query,
    bool? auth,
  }) async {
    final normalizedProvider = normalizeSocialAuthProvider(provider);
    final normalizedQuery = _normalizedSocialCallbackData(query);
    final callbackState = _socialCallbackState(normalizedQuery);
    final callbackContext = await _tokenStore.readSocialCallbackContext(
      callbackState,
    );
    final callbackAuth = auth ?? callbackContext?.auth ?? true;
    final response = await _api.post<Map<String, dynamic>>(
      '/customer/auth/social/$normalizedProvider/callback',
      auth: callbackAuth,
      data: normalizedQuery,
    );
    final result = SocialCallbackResult.fromJson(
      asMap(response.data),
      fallbackProvider: normalizedProvider,
    );
    if (result.session != null) await _saveSession(result.session!);
    if (callbackState.isNotEmpty) {
      await _tokenStore.takeSocialCallbackContext(callbackState);
    }
    return result.withRedirectFallback(callbackContext?.redirect);
  }

  Future<CustomerSession> socialLinkPhone({
    required String provider,
    required String linkToken,
    required String phone,
    required String firstName,
    required String lastName,
    required String password,
    required String passwordConfirmation,
    required String otpVerificationToken,
    required bool acceptedTerms,
    String? redirect,
  }) async {
    final normalizedProvider = normalizeSocialAuthProvider(provider);
    final requestedRedirect = redirect?.trim() ?? '';
    final redirectPath = requestedRedirect.isEmpty
        ? ''
        : safeCustomerRedirect(requestedRedirect);
    final response = await _api.post<Map<String, dynamic>>(
      '/customer/auth/social/$normalizedProvider/link-phone',
      auth: false,
      data: {
        'link_token': linkToken,
        'phone': phone,
        'first_name': firstName,
        'last_name': lastName,
        'name': '$firstName $lastName'.trim(),
        'password': password,
        'password_confirmation': passwordConfirmation,
        'otp_verification_token': otpVerificationToken,
        'accepted_terms': acceptedTerms,
        if (redirectPath.isNotEmpty) 'redirect': redirectPath,
      },
    );
    final session = CustomerSession.fromJson(asMap(response.data));
    await _saveSession(session);
    return session;
  }

  Future<void> _saveSession(CustomerSession session) async {
    await _tokenStore.save(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
      customerId: session.customerId,
    );
    await _tokenStore.saveSessionId(session.sessionId);
  }

  Future<PinStatus> verifyPin(String pin) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/customer/auth/pin/verify',
      data: {'pin': pin},
    );
    return PinStatus.fromJson(asMap(response.data));
  }

  Future<PinStatus> pinStatus() async {
    final response = await _api.get<Map<String, dynamic>>(
      '/customer/auth/pin/status',
    );
    return PinStatus.fromJson(asMap(response.data));
  }

  Future<PinStatus> setupPin({
    required String pin,
    required String pinConfirmation,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/customer/auth/pin/setup',
      data: {'pin': pin, 'pin_confirmation': pinConfirmation},
    );
    return PinStatus.fromJson(asMap(response.data));
  }

  Future<void> verifyPinAssertion(String pinAssertionToken) async {
    await _api.post(
      '/customer/auth/pin/verify',
      data: {'pin_assertion_token': pinAssertionToken},
    );
  }

  Future<String> socialLoginUrl(
    String provider, {
    String purpose = 'login',
    String? redirect,
    bool callbackUsesAuth = false,
  }) async {
    final normalizedProvider = normalizeSocialAuthProvider(provider);
    final effectivePurpose = callbackUsesAuth && purpose == 'login'
        ? 'link'
        : purpose;
    final redirectPath = redirect?.trim() ?? '';
    final response = await _api.post<Map<String, dynamic>>(
      '/customer/auth/social/$normalizedProvider/login',
      auth: callbackUsesAuth,
      data: {
        'purpose': effectivePurpose,
        'client': 'customer_flutter',
        'callback_path': '/social/$normalizedProvider/callback',
        if (redirectPath.isNotEmpty) 'redirect': redirectPath,
      },
    );

    final payload = _authPayload(
      asMap(response.data),
      _socialLoginPayloadWrapperKeys,
    );
    final stateFromPayload = _firstStringByKeys(
      payload,
      _socialCallbackStateKeys,
    );
    final url = _firstString([
      payload['url'],
      payload['login_url'],
      payload['loginUrl'],
      payload['redirect_url'],
      payload['redirectUrl'],
      payload['authorization_url'],
      payload['authorizationUrl'],
    ]);
    final state = _firstString([stateFromPayload, _oauthStateFromUrl(url)]);
    if (state.isNotEmpty) {
      await _tokenStore.rememberSocialCallbackContext(
        state: state,
        auth: callbackUsesAuth,
        redirect: redirectPath,
      );
    }
    return url;
  }
}

Map<String, dynamic> _normalizedSocialCallbackData(Map<String, dynamic> query) {
  final normalized = Map<String, dynamic>.from(query);
  final payload = _authPayload(normalized, _socialCallbackPayloadWrapperKeys);
  final code = _firstStringByKeys(payload, _socialCallbackCodeKeys);
  final state = _firstStringByKeys(payload, _socialCallbackStateKeys);
  if (code.isNotEmpty) normalized['code'] = code;
  if (state.isNotEmpty) normalized['state'] = state;
  return normalized;
}

String _socialCallbackState(Map<String, dynamic> query) {
  final payload = _authPayload(
    Map<String, dynamic>.from(query),
    _socialCallbackPayloadWrapperKeys,
  );
  return _firstStringByKeys(payload, _socialCallbackStateKeys);
}

String normalizeSocialAuthProvider(String provider) {
  final normalized = provider.trim().toLowerCase().replaceAll(
    RegExp(r'[\s\-.]+'),
    '_',
  );
  return switch (normalized) {
    'gmail' || 'google_login' || 'google_oauth' || 'google_oauth2' => 'google',
    'apple_id' || 'apple_login' || 'sign_in_with_apple' => 'apple',
    'fb' ||
    'facebook_login' ||
    'facebook_oauth' ||
    'meta' ||
    'meta_login' => 'facebook',
    'line_login' || 'line_oa' || 'line_oauth' => 'line',
    final value => value,
  };
}

String _oauthStateFromUrl(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null) return '';
  final state = _firstStringByKeys(
    uri.queryParameters,
    _socialCallbackStateKeys,
  );
  if (state.isNotEmpty) return state;

  final fragmentUri = Uri.tryParse('https://callback.local/?${uri.fragment}');
  if (fragmentUri == null) return '';
  return _firstStringByKeys(
    fragmentUri.queryParameters,
    _socialCallbackStateKeys,
  );
}

class CustomerSession {
  const CustomerSession({
    this.sessionId = '',
    required this.accessToken,
    required this.refreshToken,
    required this.pinRequired,
    required this.pinSetupRequired,
    required this.customerId,
    this.preferredLocale = '',
  });

  final String sessionId;
  final String accessToken;
  final String refreshToken;
  final bool pinRequired;
  final bool pinSetupRequired;
  final String customerId;
  final String preferredLocale;

  factory CustomerSession.fromJson(Map<String, dynamic> json) {
    final payload = _authPayload(json, const [
      'session',
      'customer_session',
      'customerSession',
      'auth_session',
      'authSession',
      'auth',
    ]);
    final user = asMap(payload['user']);
    final customer = asMap(payload['customer']);
    final setupRequired =
        _truthy(payload['pin_setup_required']) ||
        _truthy(payload['pinSetupRequired']) ||
        _truthy(payload['requires_pin_setup']) ||
        _truthy(payload['requiresPinSetup']) ||
        _truthy(user['pin_setup_required']) ||
        _truthy(user['pinSetupRequired']) ||
        _truthy(customer['pin_setup_required']) ||
        _truthy(customer['pinSetupRequired']);
    return CustomerSession(
      sessionId: _firstString([payload['session_id'], payload['sessionId']]),
      accessToken: _firstString([
        payload['access_token'],
        payload['accessToken'],
        payload['token'],
        payload['jwt'],
        user['access_token'],
        user['accessToken'],
        customer['access_token'],
        customer['accessToken'],
      ]),
      refreshToken: _firstString([
        payload['refresh_token'],
        payload['refreshToken'],
        user['refresh_token'],
        user['refreshToken'],
        customer['refresh_token'],
        customer['refreshToken'],
      ]),
      pinRequired:
          _truthy(payload['pin_required']) ||
          _truthy(payload['pinRequired']) ||
          _truthy(payload['requires_pin']) ||
          _truthy(payload['requiresPin']) ||
          _truthy(user['pin_required']) ||
          _truthy(user['pinRequired']) ||
          _truthy(customer['pin_required']) ||
          _truthy(customer['pinRequired']) ||
          setupRequired,
      pinSetupRequired: setupRequired,
      customerId: _firstString([
        payload['customer_id'],
        payload['customerId'],
        payload['id'],
        user['id'],
        user['customer_id'],
        user['customerId'],
        customer['id'],
        customer['customer_id'],
        customer['customerId'],
      ]),
      preferredLocale: _firstString([
        payload['preferred_locale'],
        payload['preferredLocale'],
        user['preferred_locale'],
        user['preferredLocale'],
        customer['preferred_locale'],
        customer['preferredLocale'],
      ]),
    );
  }
}

class LoginOtpChallengeRequired implements Exception {
  const LoginOtpChallengeRequired(this.challenge);

  final LoginOtpChallenge challenge;
}

class LoginOtpChallenge {
  const LoginOtpChallenge({
    required this.challengeToken,
    required this.phoneMasked,
    required this.resendAfterSeconds,
    required this.expiresInSeconds,
  });

  factory LoginOtpChallenge.fromJson(Map<String, dynamic> json) {
    final payload = _authPayload(json, const [
      'login_otp',
      'loginOtp',
      'otp_challenge',
      'otpChallenge',
      'login_challenge',
      'loginChallenge',
      'challenge',
    ]);
    return LoginOtpChallenge(
      challengeToken: _firstString([
        payload['login_challenge_token'],
        payload['loginChallengeToken'],
        payload['challenge_token'],
        payload['challengeToken'],
      ]),
      phoneMasked: _firstString([
        payload['phone_masked'],
        payload['phoneMasked'],
        payload['masked_phone'],
        payload['maskedPhone'],
      ]),
      resendAfterSeconds:
          _intFrom([
            payload['resend_after_seconds'],
            payload['resendAfterSeconds'],
            payload['retry_after_seconds'],
            payload['retryAfterSeconds'],
          ]) ??
          60,
      expiresInSeconds:
          _intFrom([
            payload['expires_in_seconds'],
            payload['expiresInSeconds'],
            payload['expires_in'],
            payload['expiresIn'],
          ]) ??
          600,
    );
  }

  final String challengeToken;
  final String phoneMasked;
  final int resendAfterSeconds;
  final int expiresInSeconds;

  bool get isRequired => challengeToken.trim().isNotEmpty;
}

class CustomerAuthIdentity {
  const CustomerAuthIdentity({
    required this.customerId,
    required this.hasPin,
    required this.pinRequired,
    required this.pinSetupRequired,
    required this.preferredLocale,
  });

  factory CustomerAuthIdentity.fromJson(Map<String, dynamic> json) {
    final payload = _authPayload(json, const [
      'profile',
      'customer_profile',
      'customerProfile',
      'customer',
      'member',
      'user',
      'account',
    ]);
    final explicitHasPin = _firstBoolean([
      payload['has_pin'],
      payload['hasPin'],
    ]);
    final explicitSetupRequired = _firstBoolean([
      payload['pin_setup_required'],
      payload['pinSetupRequired'],
      payload['requires_pin_setup'],
      payload['requiresPinSetup'],
    ]);
    final hasPin = explicitHasPin ?? !(explicitSetupRequired ?? false);
    final pinSetupRequired = explicitSetupRequired ?? !hasPin;
    final explicitPinRequired = _firstBoolean([
      payload['pin_required'],
      payload['pinRequired'],
      payload['requires_pin'],
      payload['requiresPin'],
    ]);
    return CustomerAuthIdentity(
      customerId: _firstString([
        payload['id'],
        payload['customer_id'],
        payload['customerId'],
        payload['member_id'],
        payload['memberId'],
      ]),
      hasPin: hasPin,
      pinRequired: explicitPinRequired ?? hasPin,
      pinSetupRequired: pinSetupRequired,
      preferredLocale: _firstString([
        payload['preferred_locale'],
        payload['preferredLocale'],
        payload['locale'],
      ]),
    );
  }

  final String customerId;
  final bool hasPin;
  final bool pinRequired;
  final bool pinSetupRequired;
  final String preferredLocale;
}

class PinStatus {
  const PinStatus({
    required this.hasPin,
    required this.pinVerified,
    required this.pinRequired,
    required this.pinSetupRequired,
    this.lockedUntil,
  });

  factory PinStatus.fromJson(Map<String, dynamic> json) {
    final payload = _authPayload(json, const [
      'pin_status',
      'pinStatus',
      'status',
    ]);
    return PinStatus(
      hasPin: _truthy(payload['has_pin']) || _truthy(payload['hasPin']),
      pinVerified:
          _truthy(payload['pin_verified']) || _truthy(payload['pinVerified']),
      pinRequired:
          _truthy(payload['pin_required']) ||
          _truthy(payload['pinRequired']) ||
          _truthy(payload['pin_setup_required']) ||
          _truthy(payload['pinSetupRequired']),
      pinSetupRequired:
          _truthy(payload['pin_setup_required']) ||
          _truthy(payload['pinSetupRequired']),
      lockedUntil: _firstString([
        payload['locked_until'],
        payload['lockedUntil'],
      ]),
    );
  }

  final bool hasPin;
  final bool pinVerified;
  final bool pinRequired;
  final bool pinSetupRequired;
  final String? lockedUntil;
}

class SocialCallbackResult {
  const SocialCallbackResult({
    required this.provider,
    required this.code,
    required this.lineLinkRequired,
    required this.linkToken,
    required this.displayName,
    required this.pictureUrl,
    required this.passwordResetReady,
    required this.passwordResetToken,
    required this.orderId,
    required this.message,
    this.redirectPath = '',
    this.session,
  });

  factory SocialCallbackResult.fromJson(
    Map<String, dynamic> json, {
    String fallbackProvider = 'line',
  }) {
    final payload = _authPayload(json, _socialCallbackResponseWrapperKeys);
    final link = _firstMap([
      payload['link'],
      payload['social_link'],
      payload['socialLink'],
      payload['line_link'],
      payload['lineLink'],
    ]);
    final profile = _firstMap([
      payload['line_profile'],
      payload['lineProfile'],
      payload['social_profile'],
      payload['socialProfile'],
      payload['profile'],
      link['line_profile'],
      link['lineProfile'],
      link['social_profile'],
      link['socialProfile'],
      link['profile'],
    ]);
    final passwordReset = _firstMap([
      payload['password_reset'],
      payload['passwordReset'],
      payload['reset_password'],
      payload['resetPassword'],
      payload['password_reset_link'],
      payload['passwordResetLink'],
      payload['reset'],
    ]);
    final session = CustomerSession.fromJson(payload);
    final linkToken = _firstString([
      payload['link_token'],
      payload['linkToken'],
      payload['social_link_token'],
      payload['socialLinkToken'],
      payload['line_link_token'],
      payload['lineLinkToken'],
      link['token'],
      link['link_token'],
      link['linkToken'],
      link['social_link_token'],
      link['socialLinkToken'],
      link['line_link_token'],
      link['lineLinkToken'],
    ]);
    final passwordResetToken = _firstString([
      payload['password_reset_token'],
      payload['passwordResetToken'],
      payload['reset_password_token'],
      payload['resetPasswordToken'],
      payload['reset_token'],
      payload['resetToken'],
      passwordReset['password_reset_token'],
      passwordReset['passwordResetToken'],
      passwordReset['reset_password_token'],
      passwordReset['resetPasswordToken'],
      passwordReset['reset_token'],
      passwordReset['resetToken'],
      passwordReset['token'],
    ]);
    return SocialCallbackResult(
      provider: normalizeSocialAuthProvider(
        _firstString([payload['provider'], fallbackProvider]),
      ),
      code: int.tryParse((payload['code'] ?? 0).toString()) ?? 0,
      session: session.accessToken.isEmpty ? null : session,
      lineLinkRequired:
          _truthy(payload['line_link_required']) ||
          _truthy(payload['lineLinkRequired']) ||
          _truthy(payload['social_link_required']) ||
          _truthy(payload['socialLinkRequired']) ||
          _truthy(payload['link_required']) ||
          _truthy(payload['linkRequired']) ||
          _truthy(link['required']) ||
          _truthy(link['link_required']) ||
          _truthy(link['linkRequired']) ||
          linkToken.isNotEmpty,
      linkToken: linkToken,
      displayName: _firstString([
        profile['display_name'],
        profile['displayName'],
        profile['name'],
        profile['full_name'],
        profile['fullName'],
      ]),
      pictureUrl: _firstString([
        profile['picture_url'],
        profile['pictureUrl'],
        profile['avatar_url'],
        profile['avatarUrl'],
      ]),
      passwordResetReady:
          _truthy(payload['password_reset_ready']) ||
          _truthy(payload['passwordResetReady']) ||
          _truthy(payload['password_reset_required']) ||
          _truthy(payload['passwordResetRequired']) ||
          _truthy(passwordReset['ready']) ||
          _truthy(passwordReset['enabled']) ||
          _truthy(passwordReset['required']) ||
          _truthy(passwordReset['password_reset_ready']) ||
          _truthy(passwordReset['passwordResetReady']) ||
          _truthy(passwordReset['password_reset_required']) ||
          _truthy(passwordReset['passwordResetRequired']) ||
          passwordResetToken.isNotEmpty,
      passwordResetToken: passwordResetToken,
      orderId: _firstString([payload['order_id'], payload['orderId']]),
      message: _firstString([payload['message'], payload['detail']]),
      redirectPath: _firstString([
        payload['redirect'],
        payload['redirect_path'],
        payload['redirectPath'],
        payload['redirect_uri'],
        payload['redirectUri'],
        payload['return_url'],
        payload['returnUrl'],
        payload['return_to'],
        payload['returnTo'],
      ]),
    );
  }

  final String provider;
  final int code;
  final CustomerSession? session;
  final bool lineLinkRequired;
  final String linkToken;
  final String displayName;
  final String pictureUrl;
  final bool passwordResetReady;
  final String passwordResetToken;
  final String orderId;
  final String message;
  final String redirectPath;

  SocialCallbackResult withRedirectFallback(String? redirect) {
    final fallback = redirect?.trim() ?? '';
    if (redirectPath.trim().isNotEmpty || fallback.isEmpty) return this;
    return SocialCallbackResult(
      provider: provider,
      code: code,
      lineLinkRequired: lineLinkRequired,
      linkToken: linkToken,
      displayName: displayName,
      pictureUrl: pictureUrl,
      passwordResetReady: passwordResetReady,
      passwordResetToken: passwordResetToken,
      orderId: orderId,
      message: message,
      redirectPath: fallback,
      session: session,
    );
  }
}

class OtpRequestResult {
  const OtpRequestResult({
    required this.phoneMasked,
    required this.resendAfterSeconds,
  });

  factory OtpRequestResult.fromJson(Map<String, dynamic> json) {
    final payload = _authPayload(json, const [
      'otp_request',
      'otpRequest',
      'otp_request_result',
      'otpRequestResult',
      'request',
      'otp',
      'pin_reset',
      'pinReset',
      'password_reset',
      'passwordReset',
      'registration',
      'register',
      'details',
      'detail',
    ]);
    final meta = _firstMap([
      payload['meta'],
      payload['metadata'],
      json['meta'],
      json['metadata'],
    ]);
    final recipient = _firstMap([
      payload['recipient'],
      payload['recipient_info'],
      payload['recipientInfo'],
      payload['contact'],
      payload['contact_info'],
      payload['contactInfo'],
      payload['customer'],
      payload['user'],
      payload['phone'],
      payload['mobile'],
      payload['msisdn'],
      meta['recipient'],
      meta['recipient_info'],
      meta['recipientInfo'],
      meta['contact'],
      meta['contact_info'],
      meta['contactInfo'],
    ]);
    final delivery = _firstMap([
      payload['delivery'],
      payload['delivery_info'],
      payload['deliveryInfo'],
      payload['channel'],
      payload['channel_info'],
      payload['channelInfo'],
      payload['sms'],
      payload['sms_otp'],
      payload['smsOtp'],
      payload['otp_delivery'],
      payload['otpDelivery'],
      payload['notification'],
      payload['send'],
      meta['delivery'],
      meta['delivery_info'],
      meta['deliveryInfo'],
      meta['channel'],
      meta['channel_info'],
      meta['channelInfo'],
      meta['sms'],
      meta['sms_otp'],
      meta['smsOtp'],
      meta['otp_delivery'],
      meta['otpDelivery'],
      meta['notification'],
      meta['send'],
    ]);
    final cooldown = _firstMap([
      payload['cooldown'],
      payload['resend'],
      payload['resend_after'],
      payload['resendAfter'],
      payload['throttle'],
      payload['rate_limit'],
      payload['rateLimit'],
      meta['cooldown'],
      meta['resend'],
      meta['throttle'],
      meta['rate_limit'],
      meta['rateLimit'],
      recipient['cooldown'],
      recipient['resend'],
      recipient['throttle'],
      recipient['rate_limit'],
      recipient['rateLimit'],
      delivery['cooldown'],
      delivery['resend'],
      delivery['throttle'],
      delivery['rate_limit'],
      delivery['rateLimit'],
    ]);
    return OtpRequestResult(
      phoneMasked: _firstScalarString([
        payload['phone_masked'],
        payload['phoneMasked'],
        payload['phone_number_masked'],
        payload['phoneNumberMasked'],
        payload['masked_phone'],
        payload['maskedPhone'],
        payload['mobile_masked'],
        payload['mobileMasked'],
        payload['mobile_number_masked'],
        payload['mobileNumberMasked'],
        payload['masked_mobile'],
        payload['maskedMobile'],
        payload['msisdn_masked'],
        payload['msisdnMasked'],
        payload['masked_msisdn'],
        payload['maskedMsisdn'],
        payload['recipient_masked'],
        payload['recipientMasked'],
        recipient['phone_masked'],
        recipient['phoneMasked'],
        recipient['phone_number_masked'],
        recipient['phoneNumberMasked'],
        recipient['masked_phone'],
        recipient['maskedPhone'],
        recipient['mobile_masked'],
        recipient['mobileMasked'],
        recipient['mobile_number_masked'],
        recipient['mobileNumberMasked'],
        recipient['masked_mobile'],
        recipient['maskedMobile'],
        recipient['msisdn_masked'],
        recipient['msisdnMasked'],
        recipient['masked_msisdn'],
        recipient['maskedMsisdn'],
        recipient['recipient_masked'],
        recipient['recipientMasked'],
        recipient['masked'],
        recipient['mask'],
        recipient['label'],
        recipient['display'],
        recipient['displayText'],
        recipient['value'],
        delivery['recipient_masked'],
        delivery['recipientMasked'],
        delivery['phone_masked'],
        delivery['phoneMasked'],
        delivery['masked'],
        delivery['label'],
      ]),
      resendAfterSeconds:
          _intFrom([
            payload['resend_after_seconds'],
            payload['resendAfterSeconds'],
            payload['resend_after'],
            payload['resendAfter'],
            payload['resend_seconds'],
            payload['resendSeconds'],
            payload['cooldown_seconds'],
            payload['cooldownSeconds'],
            payload['wait_seconds'],
            payload['waitSeconds'],
            payload['retry_after_seconds'],
            payload['retryAfterSeconds'],
            payload['retry_after'],
            payload['retryAfter'],
            payload['next_resend_in'],
            payload['nextResendIn'],
            cooldown['seconds'],
            cooldown['second'],
            cooldown['value'],
            cooldown['duration'],
            cooldown['resend_after_seconds'],
            cooldown['resendAfterSeconds'],
            cooldown['resend_after'],
            cooldown['resendAfter'],
            cooldown['cooldown_seconds'],
            cooldown['cooldownSeconds'],
            cooldown['wait_seconds'],
            cooldown['waitSeconds'],
            cooldown['retry_after_seconds'],
            cooldown['retryAfterSeconds'],
            cooldown['retry_after'],
            cooldown['retryAfter'],
            meta['resend_after_seconds'],
            meta['resendAfterSeconds'],
            meta['cooldown_seconds'],
            meta['cooldownSeconds'],
            meta['retry_after_seconds'],
            meta['retryAfterSeconds'],
            recipient['resend_after_seconds'],
            recipient['resendAfterSeconds'],
            recipient['cooldown_seconds'],
            recipient['cooldownSeconds'],
            recipient['retry_after_seconds'],
            recipient['retryAfterSeconds'],
            delivery['resend_after_seconds'],
            delivery['resendAfterSeconds'],
            delivery['cooldown_seconds'],
            delivery['cooldownSeconds'],
            delivery['retry_after_seconds'],
            delivery['retryAfterSeconds'],
          ]) ??
          60,
    );
  }

  final String phoneMasked;
  final int resendAfterSeconds;
}

class OtpVerifyResult {
  const OtpVerifyResult({required this.verificationToken});

  factory OtpVerifyResult.fromJson(Map<String, dynamic> json) {
    final payload = _authPayload(json, const [
      'otp_verification',
      'otpVerification',
      'otp_verify',
      'otpVerify',
      'otp_verification_result',
      'otpVerificationResult',
      'otp_verify_result',
      'otpVerifyResult',
      'verification',
      'verify',
      'otp',
      'pin_reset',
      'pinReset',
      'password_reset',
      'passwordReset',
      'registration',
      'register',
      'details',
      'detail',
    ]);
    final meta = _firstMap([
      payload['meta'],
      payload['metadata'],
      json['meta'],
      json['metadata'],
    ]);
    final token = _firstMap([
      payload['token'],
      payload['otp_token'],
      payload['otpToken'],
      payload['verification_token'],
      payload['verificationToken'],
      payload['verified_token'],
      payload['verifiedToken'],
      payload['verification'],
      payload['verify'],
      payload['credential'],
      payload['credentials'],
      payload['proof'],
      meta['token'],
      meta['otp_token'],
      meta['otpToken'],
      meta['verification_token'],
      meta['verificationToken'],
      meta['verified_token'],
      meta['verifiedToken'],
      meta['verification'],
      meta['verify'],
      meta['credential'],
      meta['credentials'],
      meta['proof'],
    ]);
    return OtpVerifyResult(
      verificationToken: _firstScalarString([
        payload['otp_verification_token'],
        payload['otpVerificationToken'],
        payload['otp_token'],
        payload['otpToken'],
        payload['otp_verify_token'],
        payload['otpVerifyToken'],
        payload['otp_verified_token'],
        payload['otpVerifiedToken'],
        payload['verification_token'],
        payload['verificationToken'],
        payload['otp_verification_id'],
        payload['otpVerificationId'],
        payload['verification_id'],
        payload['verificationId'],
        payload['verify_token'],
        payload['verifyToken'],
        payload['verified_token'],
        payload['verifiedToken'],
        payload['token'],
        meta['otp_verification_token'],
        meta['otpVerificationToken'],
        meta['verification_token'],
        meta['verificationToken'],
        meta['otp_verification_id'],
        meta['otpVerificationId'],
        meta['verification_id'],
        meta['verificationId'],
        token['otp_verification_token'],
        token['otpVerificationToken'],
        token['otp_token'],
        token['otpToken'],
        token['verification_token'],
        token['verificationToken'],
        token['otp_verification_id'],
        token['otpVerificationId'],
        token['verification_id'],
        token['verificationId'],
        token['verify_token'],
        token['verifyToken'],
        token['verified_token'],
        token['verifiedToken'],
        token['token'],
        token['value'],
        token['code'],
        token['key'],
        token['id'],
      ]),
    );
  }

  final String verificationToken;
}

Map<String, dynamic> _authPayload(
  Map<String, dynamic> json,
  List<String> wrapperKeys, [
  int depth = 0,
]) {
  if (depth >= 6 || json.isEmpty) return json;

  for (final key in [...wrapperKeys, 'resource', 'data', 'result', 'payload']) {
    final nested = _asAuthMap(json[key]);
    if (nested.isEmpty) continue;
    final resolved = _authPayload(nested, wrapperKeys, depth + 1);
    return _mergeAuthWrapper(json, key, resolved);
  }

  return json;
}

Map<String, dynamic> _mergeAuthWrapper(
  Map<String, dynamic> wrapper,
  String nestedKey,
  Map<String, dynamic> nested,
) {
  final merged = <String, dynamic>{...wrapper}..remove(nestedKey);
  return {...merged, ...nested};
}

Map<String, dynamic> _firstMap(Iterable<Object?> values) {
  for (final value in values) {
    final map = _asAuthMap(value);
    if (map.isNotEmpty) return map;
  }
  return const <String, dynamic>{};
}

Map<String, dynamic> _asAuthMap(Object? value) {
  final direct = asMap(value);
  if (direct.isNotEmpty) return direct;
  if (value is! String) return const <String, dynamic>{};
  final trimmed = value.trim();
  if (!trimmed.startsWith('{')) return const <String, dynamic>{};
  try {
    final decoded = convert.jsonDecode(trimmed);
    return asMap(decoded);
  } catch (_) {
    return const <String, dynamic>{};
  }
}

String _firstString(Iterable<Object?> values) {
  for (final value in values) {
    final stringValue = value?.toString().trim() ?? '';
    if (stringValue.isNotEmpty) return stringValue;
  }
  return '';
}

String _firstStringByKeys(Map<String, dynamic> source, Iterable<String> keys) {
  return _firstString(keys.map((key) => source[key]));
}

String _firstScalarString(Iterable<Object?> values) {
  for (final value in values) {
    final stringValue = _authScalarString(value);
    if (stringValue.isNotEmpty) return stringValue;
  }
  return '';
}

String _authScalarString(Object? value, [int depth = 0]) {
  if (value == null || depth > 3) return '';
  if (value is Map) {
    for (final key in const [
      'value',
      'code',
      'key',
      'id',
      'token',
      'label',
      'display',
      'displayText',
      'text',
    ]) {
      final nested = _authScalarString(value[key], depth + 1);
      if (nested.isNotEmpty) return nested;
    }
    return '';
  }
  if (value is Iterable) {
    for (final item in value) {
      final nested = _authScalarString(item, depth + 1);
      if (nested.isNotEmpty) return nested;
    }
    return '';
  }
  return value.toString().trim();
}

int? _intFrom(Iterable<Object?> values) {
  for (final value in values) {
    final parsed = int.tryParse(_authScalarString(value));
    if (parsed != null) return parsed;
  }
  return null;
}

bool _truthy(Object? value) {
  if (value is bool) return value;
  final normalized = value?.toString().trim().toLowerCase();
  return normalized == 'true' || normalized == '1' || normalized == 'yes';
}

bool? _firstBoolean(Iterable<Object?> values) {
  for (final value in values) {
    if (value == null) continue;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final normalized = value.toString().trim().toLowerCase();
    if (normalized.isEmpty) continue;
    if (const {
      'true',
      '1',
      'yes',
      'on',
      'enabled',
      'active',
    }.contains(normalized)) {
      return true;
    }
    if (const {
      'false',
      '0',
      'no',
      'off',
      'disabled',
      'inactive',
    }.contains(normalized)) {
      return false;
    }
  }
  return null;
}
