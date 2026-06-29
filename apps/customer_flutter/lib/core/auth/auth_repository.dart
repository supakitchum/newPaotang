import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/api_payload.dart';
import '../utils/idempotency_key.dart';
import 'auth_token_store.dart';
import '../network/api_client.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    api: ref.watch(apiClientProvider),
    tokenStore: ref.watch(authTokenStoreProvider),
  );
});

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
      data: {'username': username, 'password': password},
    );
    final session = CustomerSession.fromJson(unwrapPayload(response.data));
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
    final session = CustomerSession.fromJson(unwrapPayload(response.data));
    await _saveSession(session);
    return session;
  }

  Future<CustomerSession> refresh() async {
    final refreshToken = _tokenStore.refreshToken ?? '';
    final response = await _api.post<Map<String, dynamic>>(
      '/customer/auth/refresh',
      auth: false,
      data: {'refresh_token': refreshToken},
    );
    final session = CustomerSession.fromJson(unwrapPayload(response.data));
    await _saveSession(session);
    return session;
  }

  Future<void> logout() async {
    try {
      if (_tokenStore.hasAccessToken) {
        await _api.post('/customer/auth/logout');
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
    return OtpRequestResult.fromJson(unwrapPayload(response.data));
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
    return OtpVerifyResult.fromJson(unwrapPayload(response.data));
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
    return OtpRequestResult.fromJson(unwrapPayload(response.data));
  }

  Future<OtpVerifyResult> verifyPinResetOtp({required String otp}) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/customer/auth/pin/reset/verify-otp',
      data: {'otp': otp},
    );
    return OtpVerifyResult.fromJson(unwrapPayload(response.data));
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

  Future<SocialCallbackResult> lineCallback(
    Map<String, dynamic> query,
  ) async {
    return socialCallback(provider: 'line', query: query);
  }

  Future<CustomerSession> lineLinkPhone({
    required String linkToken,
    required String phone,
    required String password,
    required String passwordConfirmation,
  }) async {
    return socialLinkPhone(
      provider: 'line',
      linkToken: linkToken,
      phone: phone,
      password: password,
      passwordConfirmation: passwordConfirmation,
    );
  }

  Future<SocialCallbackResult> socialCallback({
    required String provider,
    required Map<String, dynamic> query,
  }) async {
    final normalizedProvider = normalizeSocialAuthProvider(provider);
    final response = await _api.post<Map<String, dynamic>>(
      '/customer/auth/social/$normalizedProvider/callback',
      data: query,
    );
    final result = SocialCallbackResult.fromJson(
      unwrapPayload(response.data),
      fallbackProvider: normalizedProvider,
    );
    if (result.session != null) await _saveSession(result.session!);
    return result;
  }

  Future<CustomerSession> socialLinkPhone({
    required String provider,
    required String linkToken,
    required String phone,
    required String password,
    required String passwordConfirmation,
  }) async {
    final normalizedProvider = normalizeSocialAuthProvider(provider);
    final response = await _api.post<Map<String, dynamic>>(
      '/customer/auth/social/$normalizedProvider/link-phone',
      auth: false,
      data: {
        'link_token': linkToken,
        'phone': phone,
        'password': password,
        'password_confirmation': passwordConfirmation,
      },
    );
    final session = CustomerSession.fromJson(unwrapPayload(response.data));
    await _saveSession(session);
    return session;
  }

  Future<void> _saveSession(CustomerSession session) async {
    await _tokenStore.save(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
      customerId: session.customerId,
    );
  }

  Future<void> verifyPin(String pin) async {
    await _api.post('/customer/auth/pin/verify', data: {'pin': pin});
  }

  Future<PinStatus> pinStatus() async {
    final response = await _api.get<Map<String, dynamic>>(
      '/customer/auth/pin/status',
    );
    return PinStatus.fromJson(unwrapPayload(response.data));
  }

  Future<PinStatus> setupPin({
    required String pin,
    required String pinConfirmation,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/customer/auth/pin/setup',
      data: {
        'pin': pin,
        'pin_confirmation': pinConfirmation,
      },
    );
    return PinStatus.fromJson(unwrapPayload(response.data));
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
  }) async {
    final normalizedProvider = normalizeSocialAuthProvider(provider);
    final response = await _api.post<Map<String, dynamic>>(
      '/customer/auth/social/$normalizedProvider/login',
      auth: false,
      data: {
        'purpose': purpose,
        'client': 'customer_flutter',
        'callback_path': '/social/$normalizedProvider/callback',
      },
    );

    return unwrapPayload(response.data)['url']?.toString() ?? '';
  }
}

String normalizeSocialAuthProvider(String provider) {
  return switch (provider.trim().toLowerCase()) {
    'gmail' || 'google_login' || 'google_oauth' || 'google_oauth2' => 'google',
    'apple_id' || 'apple_login' || 'sign_in_with_apple' => 'apple',
    'line_login' || 'line_oa' || 'line_oauth' => 'line',
    final value => value,
  };
}

class CustomerSession {
  const CustomerSession({
    required this.accessToken,
    required this.refreshToken,
    required this.pinRequired,
    required this.pinSetupRequired,
    required this.customerId,
  });

  final String accessToken;
  final String refreshToken;
  final bool pinRequired;
  final bool pinSetupRequired;
  final String customerId;

  factory CustomerSession.fromJson(Map<String, dynamic> json) {
    final user = asMap(json['user']);
    final setupRequired = json['pin_setup_required'] == true ||
        user['pin_setup_required'] == true;
    return CustomerSession(
      accessToken:
          (json['access_token'] ?? json['token'] ?? user['access_token'])
                  ?.toString() ??
              '',
      refreshToken:
          (json['refresh_token'] ?? user['refresh_token'])?.toString() ?? '',
      pinRequired: json['pin_required'] == true ||
          user['pin_required'] == true ||
          setupRequired,
      pinSetupRequired: setupRequired,
      customerId: (json['customer_id'] ??
                  json['customerId'] ??
                  user['id'] ??
                  user['customer_id'] ??
                  user['customerId'])
              ?.toString()
              .trim() ??
          '',
    );
  }
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
    return PinStatus(
      hasPin: json['has_pin'] == true,
      pinVerified: json['pin_verified'] == true,
      pinRequired:
          json['pin_required'] == true || json['pin_setup_required'] == true,
      pinSetupRequired: json['pin_setup_required'] == true,
      lockedUntil: json['locked_until']?.toString(),
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
    this.session,
  });

  factory SocialCallbackResult.fromJson(
    Map<String, dynamic> json, {
    String fallbackProvider = 'line',
  }) {
    final profile = asMap(json['line_profile'] ?? json['profile']);
    final token = (json['token'] ?? json['access_token'])?.toString() ?? '';
    return SocialCallbackResult(
      provider: normalizeSocialAuthProvider(
        json['provider']?.toString() ?? fallbackProvider,
      ),
      code: int.tryParse((json['code'] ?? 0).toString()) ?? 0,
      session: token.isEmpty ? null : CustomerSession.fromJson(json),
      lineLinkRequired: json['line_link_required'] == true ||
          json['social_link_required'] == true,
      linkToken:
          (json['link_token'] ?? json['social_link_token'])?.toString() ?? '',
      displayName:
          (profile['display_name'] ?? profile['name'])?.toString() ?? '',
      pictureUrl:
          (profile['picture_url'] ?? profile['avatar_url'])?.toString() ?? '',
      passwordResetReady: json['password_reset_ready'] == true,
      passwordResetToken: json['password_reset_token']?.toString() ?? '',
      orderId: json['order_id']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
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
}

class OtpRequestResult {
  const OtpRequestResult({
    required this.phoneMasked,
    required this.resendAfterSeconds,
  });

  factory OtpRequestResult.fromJson(Map<String, dynamic> json) {
    final details = asMap(json['details']);
    return OtpRequestResult(
      phoneMasked:
          (json['phone_masked'] ?? details['phone_masked'])?.toString() ?? '',
      resendAfterSeconds: int.tryParse(
            (json['resend_after_seconds'] ?? details['resend_after_seconds'])
                    ?.toString() ??
                '',
          ) ??
          60,
    );
  }

  final String phoneMasked;
  final int resendAfterSeconds;
}

class OtpVerifyResult {
  const OtpVerifyResult({required this.verificationToken});

  factory OtpVerifyResult.fromJson(Map<String, dynamic> json) {
    return OtpVerifyResult(
      verificationToken:
          (json['otp_verification_token'] ?? json['verification_token'])
                  ?.toString() ??
              '',
    );
  }

  final String verificationToken;
}
